import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum GateShieldPolicy {
    static func protectedSelection(from state: GateState) -> FamilyActivitySelection {
        guard let data = state.protectedSelectionData,
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    static func isProtected(_ target: GateTarget, in state: GateState) -> Bool {
        let selected = protectedSelection(from: state)
        let decoder = PropertyListDecoder()
        switch target.kind {
        case .application:
            guard let token = try? decoder.decode(ApplicationToken.self, from: target.tokenData) else { return false }
            return selected.applicationTokens.contains(token)
        case .webDomain:
            guard let token = try? decoder.decode(WebDomainToken.self, from: target.tokenData) else { return false }
            return selected.webDomainTokens.contains(token)
        case .category: return false
        }
    }

    static func retaining(_ saved: FamilyActivitySelection, adding proposed: FamilyActivitySelection) -> FamilyActivitySelection {
        var result = proposed
        result.applicationTokens = AdditiveSelection.retaining(saved.applicationTokens, adding: proposed.applicationTokens)
        result.webDomainTokens = AdditiveSelection.retaining(saved.webDomainTokens, adding: proposed.webDomainTokens)
        result.categoryTokens = AdditiveSelection.retaining(saved.categoryTokens, adding: proposed.categoryTokens)
        return result
    }
    static func selection(from state: GateState) -> FamilyActivitySelection {
        guard let data = state.selectionData,
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    /// Called inside the shared transaction: an expiring A cannot overwrite a newly granted B.
    static func apply(_ state: GateState, at now: Date = Date()) {
        let store = ManagedSettingsStore()
        store.webContent.blockedByFilter = .auto()
        store.media.denyExplicitContent = true
        store.media.denyBookstoreErotica = true
        // Separate store: neither the free daily budget nor a consumption grant can lift these shields.
        let permanent = ManagedSettingsStore(named: ManagedSettingsStore.Name("gate.content"))
        let protected = protectedSelection(from: state)
        permanent.shield.webDomains = protected.webDomainTokens.isEmpty ? nil : protected.webDomainTokens
        permanent.shield.applications = protected.applicationTokens.isEmpty ? nil : protected.applicationTokens
        // URL rules require no opaque picker token. Keep them outside all budget/grant stores.
        permanent.webContent.blockedByFilter = .specific(Set(GatePermanentWebPolicy.domains.map { WebDomain(domain: $0) }))
        guard state.monitoringEnabled && state.limitReached else {
            store.shield.applications = nil
            store.shield.webDomains = nil
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
            return
        }
        let selected = selection(from: state)
        var exemptApps = Set<ApplicationToken>()
        var exemptDomains = Set<WebDomainToken>()
        let decoder = PropertyListDecoder()
        for grant in state.activeGrants(at: now) {
            switch grant.target.kind {
            case .application:
                if let token = try? decoder.decode(ApplicationToken.self, from: grant.target.tokenData) { exemptApps.insert(token) }
            case .webDomain:
                if let token = try? decoder.decode(WebDomainToken.self, from: grant.target.tokenData) { exemptDomains.insert(token) }
            case .category: break
            }
        }
        let apps = selected.applicationTokens.subtracting(exemptApps)
        let domains = selected.webDomainTokens.subtracting(exemptDomains)
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.webDomains = domains.isEmpty ? nil : domains
        store.shield.applicationCategories = selected.categoryTokens.isEmpty ? nil : .specific(selected.categoryTokens, except: exemptApps)
        store.shield.webDomainCategories = selected.categoryTokens.isEmpty ? nil : .specific(selected.categoryTokens, except: exemptDomains)
    }

    static func isSelected(_ target: GateTarget, in state: GateState) -> Bool {
        guard !isProtected(target, in: state) else { return false }
        let selected = selection(from: state)
        let decoder = PropertyListDecoder()
        switch target.kind {
        case .application:
            guard let token = try? decoder.decode(ApplicationToken.self, from: target.tokenData) else { return false }
            return selected.applicationTokens.contains(token) || !selected.categoryTokens.isEmpty
        case .webDomain:
            guard let token = try? decoder.decode(WebDomainToken.self, from: target.tokenData) else { return false }
            return selected.webDomainTokens.contains(token) || !selected.categoryTokens.isEmpty
        case .category: return false
        }
    }
}
