import SwiftUI
import WidgetKit

struct GateWidgetEntry: TimelineEntry {
    let date: Date
    let state: GateState?
}

struct GateWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GateWidgetEntry { GateWidgetEntry(date: Date(), state: GateState()) }
    func getSnapshot(in context: Context, completion: @escaping (GateWidgetEntry) -> Void) {
        completion(GateWidgetEntry(date: Date(), state: try? GateSharedStore.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GateWidgetEntry>) -> Void) {
        let now = Date()
        let state = try? GateSharedStore.read()
        let dates = [now] + (state?.grants.map(\.expiresAt).filter { $0 > now } ?? [])
        let entries = dates.sorted().map { date -> GateWidgetEntry in
            var snapshot = state
            snapshot?.rollDay(at: date)
            snapshot?.expireGrants(at: date)
            return GateWidgetEntry(date: date, state: snapshot)
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

struct GateWidgetView: View {
    let entry: GateWidgetEntry
    @Environment(\.widgetFamily) private var family
    private var count: Int { family == .systemLarge ? 8 : 4 }
    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 14 : 6) {
            HStack {
                Link("gate · Pause", destination: URL(string: "gate://pause")!)
                    .font(.system(.subheadline, design: .serif))
                    .accessibilityLabel("Gate-Pause öffnen")
                Spacer()
                Text(status).font(.system(size: 9, weight: .medium)).tracking(1)
            }.foregroundStyle(.secondary)
            if let state = entry.state {
                ForEach(Array(state.launcher.filter(\.enabled).prefix(count))) { item in
                    Link(destination: URL(string: "gate://launch/\(item.id.uuidString)")!) {
                        Text(item.title).font(.system(size: family == .systemLarge ? 24 : 19, weight: .regular, design: .serif))
                            .lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if family == .systemLarge {
                    Spacer(minLength: 0)
                    Link("Einfach etwas lernen", destination: URL(string: "gate://learn")!)
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Gate einmal öffnen\nund Textliste einrichten.").font(.subheadline)
            }
        }.padding(18)
            .foregroundStyle(.primary)
            .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
            .widgetURL(URL(string: "gate://home"))
    }

    private var status: String {
        guard let state = entry.state else { return "EINRICHTEN" }
        guard state.monitoringEnabled else { return "PAUSE" }
        return state.limitReached ? "\(state.activeGrants(at: entry.date).count) FREIGABEN" : "FREIE PHASE"
    }
}

@main
struct GateLauncherWidget: Widget {
    let kind = "GateLauncher"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GateWidgetProvider()) { entry in
            GateWidgetView(entry: entry)
        }
        .configurationDisplayName("Gate · Das Wesentliche")
        .description("Deine wichtigsten Apps als ruhige Textliste. Sperren bleiben wirksam.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
