import Charts
import SwiftUI

struct GateStatisticsView: View {
    @ObservedObject var controller: ScreenTimeController
    @ObservedObject var learning: LearningStore
    @State private var showLearning = false
    @State private var showCheckpoints = false
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
        VStack(spacing: 16) {
            Picker("Bilanz", selection: $showLearning) {
                Text("Bildschirmzeit").tag(false)
                Text("Lernbilanz").tag(true)
            }.pickerStyle(.segmented).padding(.horizontal, 20).padding(.top, 12)
            if showLearning { learningBody }
            else { SystemUsageView(controller: controller) { showCheckpoints = true } }
        }
        .sheet(isPresented: $showCheckpoints) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Nur deine Konsum-Auswahl").font(.title3.weight(.semibold))
                        Text("Dieser Zähler steuert das freie Tagesbudget und die Freigaben. Er enthält nur bereits eingetroffene iOS-Nutzungsmeldungen und kann hinter dem Nutzungsbericht liegen. Er ist keine gesamte Bildschirmzeit.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        GateUsageChart(days: days)
                        MonitoringStatusView(controller: controller, detailed: true)
                    }.padding(24)
                }
                .navigationTitle("Freigabezähler").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { showCheckpoints = false } } }
            }
        }
    }

    private var learningBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Eyebrow(text: "Letzte sieben Tage")
                Text("Weniger zerstreut.\nMehr mitgenommen.").font(.system(.largeTitle, design: .serif))
                HStack(alignment: .top, spacing: 24) {
                    metric("\(recent.filter(\.passed).count)", "bestandene Runden")
                    metric("\(recent.reduce(0) { $0 + $1.activeSeconds } / 60)", "aktive Lernminuten")
                }
                Divider()
                GateSection(title: "Was hängen bleibt") {
                    HStack(alignment: .top, spacing: 24) {
                        metric("\(learning.progress.completedLessonIDs.count)", "Kapitel erarbeitet")
                        metric("\(learning.progress.memories.values.filter { $0.streak >= 3 }.count)", "Fragen wiederholt gefestigt")
                    }
                    DisclosureGroup("Was zählt?") {
                        Text("Erarbeitet: gelesen und alle Fragen richtig gelöst. Gefestigt: mindestens drei zeitversetzte richtige Antworten.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
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

private struct GateUsageChart: View {
    let days: [GateUsageDay]
    @State private var selectedDate: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 230

    private var selectedDay: GateUsageDay? {
        guard let selectedDate else { return nil }
        return days.first { Calendar.current.isDate($0.id, inSameDayAs: selectedDate) }
    }

    private var maximumHours: Double {
        // Leave room for the callout above even the tallest bar.
        max(1, ceil(Double(days.map(\.confirmedMinutes).max() ?? 0) / 60 * 1.7))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "EEEE, dd.MM.yyyy"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chart
                .frame(height: chartHeight)
                .chartYScale(domain: 0...maximumHours)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text("\(hours, format: .number.precision(.fractionLength(0...2))) h")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: days.map(\.id)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(Date.FormatStyle().weekday(.abbreviated).locale(Locale(identifier: "de_CH"))))
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartXSelection(value: Binding(get: { selectedDate }, set: { date in
                    if let date, let selectedDate, Calendar.current.isDate(date, inSameDayAs: selectedDate) {
                        self.selectedDate = nil
                    } else { selectedDate = date }
                }))
                .chartGesture { proxy in
                    // A tap keeps the detail visible after lifting the finger and
                    // leaves vertical swipes available to the surrounding ScrollView.
                    SpatialTapGesture().onEnded { value in
                        proxy.selectXValue(at: value.location.x)
                    }
                }
                .environment(\.locale, Locale(identifier: "de_CH"))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selectedDay?.id)
                .accessibilityRepresentation {
                    VStack {
                        ForEach(days) { day in
                            Button { selectedDate = day.id } label: {
                                Text("\(Self.dateFormatter.string(from: day.id)): \(accessibleDuration(day))")
                            }
                            .accessibilityAddTraits(selectedDay?.id == day.id ? .isSelected : [])
                        }
                    }
                }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(days) { day in
                BarMark(x: .value("Tag", day.id, unit: .day),
                        y: .value("Stunden", Double(max(0, day.confirmedMinutes)) / 60),
                        width: .ratio(0.6))
                    .cornerRadius(5)
                    .foregroundStyle(selectedDay?.id == day.id ? Color.blue : Color.primary.opacity(selectedDay == nil ? 0.65 : 0.2))
            }
            if let day = selectedDay {
                RuleMark(x: .value("Ausgewählter Tag", day.id, unit: .day))
                    .foregroundStyle(Color.blue.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .zIndex(-1)
                PointMark(x: .value("Ausgewählter Tag", day.id, unit: .day),
                          y: .value("Stunden", Double(max(0, day.confirmedMinutes)) / 60))
                    .symbolSize(24).foregroundStyle(Color.blue)
                    .annotation(position: .top, spacing: 10,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        detail(day)
                    }
            }
        }
    }

    private func detail(_ day: GateUsageDay) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if day.confirmedMinutes > 0 {
                Text("\(day.confirmedMinutes / 60) h \(day.confirmedMinutes % 60) min")
                    .font(.title3.weight(.semibold)).monospacedDigit()
            } else {
                Text("Keine Messung bestätigt").font(.subheadline.weight(.semibold))
            }
            Text(Self.dateFormatter.string(from: day.id))
                .font(.caption).foregroundStyle(.secondary)
            if day.confirmedMinutes > 0 {
                Text("Bestätigter Mindestwert").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 220, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(GateDesign.line))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    private func accessibleDuration(_ day: GateUsageDay) -> String {
        guard day.confirmedMinutes > 0 else { return "Keine Messung bestätigt" }
        return "mindestens \(day.confirmedMinutes / 60) Stunden und \(day.confirmedMinutes % 60) Minuten"
    }
}
