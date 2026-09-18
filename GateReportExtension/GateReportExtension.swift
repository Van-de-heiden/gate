import DeviceActivity
import ManagedSettings
import SwiftUI

@main
struct GateReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        GateUsageReport(scope: .consumption) { GateReportView(configuration: $0) }
        GateUsageReport(scope: .allApps) { GateReportView(configuration: $0) }
    }
}

struct GateReportDevice: Identifiable {
    let id: Int
    let name: String
    let updatedAt: Date
    let timeline: GateReportTimeline
}

struct GateReportConfiguration {
    let scope: GateReportScope
    let devices: [GateReportDevice]
}

struct GateUsageReport: DeviceActivityReportScene {
    let scope: GateReportScope
    var context: DeviceActivityReport.Context { .init(scope.contextID) }
    let content: (GateReportConfiguration) -> GateReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> GateReportConfiguration {
        var devices: [GateReportDevice] = []
        let now = Date()
        for await entry in data {
            var timeline = GateReportTimeline(ending: now)
            for await segment in entry.activitySegments {
                var applications: [Application: TimeInterval] = [:]
                var websites: [WebDomain: TimeInterval] = [:]
                for await category in segment.categories {
                    for await app in category.applications {
                        applications[app.application, default: 0] += app.totalActivityDuration
                    }
                    for await website in category.webDomains {
                        websites[website.webDomain, default: 0] += website.totalActivityDuration
                    }
                }
                let appItems = applications.map { app, seconds in
                    GateReportItem(id: UUID().uuidString, title: name(app.localizedDisplayName, fallback: "App"),
                                   isWebsite: false, seconds: seconds)
                }
                let webItems = websites.map { website, seconds in
                    GateReportItem(id: UUID().uuidString, title: name(website.domain, fallback: "Website"),
                                   isWebsite: true, seconds: seconds)
                }
                timeline.record(date: segment.dateInterval.start, seconds: segment.totalActivityDuration,
                                items: appItems + webItems)
            }
            // Never silently add different devices together. The user chooses the
            // device inside this private report before comparing it with Settings.
            devices.append(GateReportDevice(id: devices.count, name: name(entry.device.name, fallback: "iPhone"),
                                            updatedAt: entry.lastUpdatedDate, timeline: timeline))
        }
        return GateReportConfiguration(scope: scope, devices: devices)
    }

    private func name(_ value: String?, fallback: String) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return fallback }
        return value
    }
}
