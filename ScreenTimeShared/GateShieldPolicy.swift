import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum GateShieldPolicy {
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
