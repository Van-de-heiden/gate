import Foundation

enum GateReportScope: String, CaseIterable, Identifiable {
    case consumption, allApps
    var id: String { rawValue }
    var title: String { self == .consumption ? "Konsum-Auswahl" : "Alle Apps" }
    var contextID: String { "gate.report.\(rawValue)" }

    func canRequest(applicationCount: Int, domainCount: Int) -> Bool {
        // An empty DeviceActivityFilter means ALL activity, never an empty pool.
        self == .allApps || applicationCount > 0 || domainCount > 0
    }
}

struct GateReportItem: Identifiable {
    let id: String
    let title: String
    let isWebsite: Bool
    let seconds: TimeInterval
}

struct GateReportDay: Identifiable {
    let id: Date
    var seconds: TimeInterval?
    var items: [GateReportItem] = []
}

/// Pure presentation arithmetic. Instances containing real usage only live in
/// the report extension; they are never saved or passed back to the parent app.
struct GateReportTimeline {
    private(set) var days: [GateReportDay]
    let calendar: Calendar

    init(ending now: Date, calendar: Calendar = .current) {
        self.calendar = calendar
        let today = calendar.startOfDay(for: now)
        days = (-6...0).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).map { GateReportDay(id: $0) }
        }
    }

    var interval: DateInterval {
        let start = days.first!.id
        let end = calendar.date(byAdding: .day, value: 1, to: days.last!.id)!
        return DateInterval(start: start, end: end)
    }

    mutating func record(date: Date, seconds: TimeInterval, items: [GateReportItem]) {
        guard seconds.isFinite, seconds >= 0,
              let index = days.firstIndex(where: { calendar.isDate($0.id, inSameDayAs: date) }) else { return }
        // The system's segment total is authoritative. Adding application and
        // website breakdowns to it would count the same activity more than once.
        days[index].seconds = (days[index].seconds ?? 0) + seconds
        days[index].items += items.filter { $0.seconds.isFinite && $0.seconds > 0 }
        days[index].items.sort { $0.seconds > $1.seconds }
    }
}

enum GateReportDuration {
    static func minutes(_ seconds: TimeInterval) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int(min(seconds / 60, Double(Int.max / 2)).rounded(.down))
    }

    static func text(_ seconds: TimeInterval) -> String {
        if seconds > 0 && seconds < 60 { return "< 1 min" }
        let minutes = minutes(seconds)
        return "\(minutes / 60) h \(minutes % 60) min"
    }
}
