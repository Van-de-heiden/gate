import Charts
import SwiftUI

struct GateStatisticsView: View {
    @ObservedObject var controller: ScreenTimeController
    @ObservedObject var learning: LearningStore
    private var recent: [LearningResult] {
        learning.progress.results.filter { $0.completedAt > Date().addingTimeInterval(-7 * 86400) }
    }
    private var days: [GateUsageDay] {
        let calendar = Calendar.current
        return (-6...0).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date())) else { return nil }
            return controller.state.history.first { $0.id == day } ?? GateUsageDay(id: day)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Eyebrow(text: "Letzte sieben Tage")
                Text("Weniger zerstreut.\nMehr mitgenommen.").font(.system(.largeTitle, design: .serif))
                HStack(alignment: .top, spacing: 24) {
                    metric("\(recent.filter(\.passed).count)", "bestandene Runden")
                    metric("\(recent.reduce(0) { $0 + $1.activeSeconds } / 60)", "aktive Lernminuten")
                }
                GateSection(title: "Bestätigte Konsumzeit") {
                    Chart(days) { day in
                        BarMark(x: .value("Tag", day.id, unit: .day), y: .value("Minuten", day.confirmedMinutes))
                            .foregroundStyle(Color.primary.opacity(0.75))
                    }.frame(height: 160).chartYAxisLabel("Minuten").chartLegend(.hidden)
                    Text("Nur ausgewählte Apps und Websites. iOS meldet Nutzungsschwellen, deshalb sind dies bestätigte Mindestwerte, keine vollständige Bildschirmzeit. Eine leere Säule kann auch fehlende Messdaten bedeuten.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                GateSection(title: "Was hängen bleibt") {
                    HStack(alignment: .top, spacing: 24) {
                        metric("\(learning.progress.completedLessonIDs.count)", "Kapitel erarbeitet")
                        metric("\(learning.progress.memories.values.filter { $0.streak >= 3 }.count)", "Fragen wiederholt gefestigt")
                    }
                    Text("„Erarbeitet“ bedeutet: Kapitel gelesen und alle Fragen dazu über eine oder mehrere bestandene Runden richtig gelöst. Frühere Kapitelabschlüsse bleiben erhalten. „Gefestigt“ verlangt mindestens drei über Zeit verteilte richtige Antworten pro Frage.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if recent.isEmpty {
                    Text("Deine erste Lektion ist der Anfang dieser Bilanz. Keine erfundenen Erfolgszahlen.")
                        .font(.system(.body, design: .serif)).foregroundStyle(.secondary)
                } else {
                    GateSection(title: "Zuletzt gelernt") {
                        ForEach(Array(recent.suffix(8).reversed())) { result in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(result.completedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                    Text(result.passed ? "Bestanden" : "Wird wiederholt").font(.subheadline)
                                }
                                Spacer()
                                Text("\(result.correct)/\(result.total)").monospacedDigit()
                            }
                            Divider()
                        }
                    }
                }
                Text("Deine Lernhistorie bleibt auf diesem Gerät. Kein Konto, keine Werbung, kein Ranking.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(.system(size: 40, weight: .light, design: .serif)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
