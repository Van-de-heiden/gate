import Charts
import SwiftUI

struct GateReportView: View {
    let configuration: GateReportConfiguration
    @State private var deviceID: Int?
    @State private var selectedDate: Date?
    @State private var showAllItems = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 200

    private var device: GateReportDevice? {
        configuration.devices.first { $0.id == deviceID } ?? configuration.devices.first
    }
    private var activeDay: GateReportDay? {
        guard let device else { return nil }
        if let selectedDate {
            return device.timeline.days.first { Calendar.current.isDate($0.id, inSameDayAs: selectedDate) }
        }
        return device.timeline.days.last
    }
    private static func dateText(_ date: Date, short: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = short ? "EE" : "EEEE, dd.MM.yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let device {
                    deviceSelector(device)
                    if let day = activeDay {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(configuration.scope.title).font(.subheadline).foregroundStyle(.secondary)
                            Text(day.seconds.map(GateReportDuration.text) ?? "Keine Daten")
                                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                                .monospacedDigit().foregroundStyle(selectedDate == nil ? Color.primary : Color.blue)
                            Text(Self.dateText(day.id)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    usageChart(device.timeline)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("iOS-Datenstand: \(device.updatedAt.formatted(date: .numeric, time: .shortened))")
                        Text("Der Datenstand stammt von iOS. Erneutes Laden garantiert keine sofortige Aktualisierung.")
                    }.font(.caption2).foregroundStyle(.secondary)
                    if let day = activeDay { breakdown(day) }
                } else {
                    ContentUnavailableView("Noch keine iOS-Berichtsdaten", systemImage: "chart.bar.xaxis",
                        description: Text("iOS hat für diesen Umfang keine Daten geliefert. Prüfe die Berechtigung unter Mehr und lade den Bericht erneut. Das bedeutet nicht null Minuten Nutzung."))
                }
            }.padding(.vertical, 16).padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .environment(\.locale, Locale(identifier: "de_CH"))
        .onChange(of: deviceID) { _, _ in selectedDate = nil; showAllItems = false }
        .onChange(of: selectedDate) { _, _ in showAllItems = false }
    }

    @ViewBuilder private func deviceSelector(_ device: GateReportDevice) -> some View {
        if configuration.devices.count > 1 {
            Picker("iOS-Gerät", selection: Binding(get: { device.id }, set: { deviceID = $0 })) {
                ForEach(configuration.devices) { Text($0.name).tag($0.id) }
            }.pickerStyle(.menu)
            Text("Mehrere iPhones liefern Daten. Wähle für den Vergleich dasselbe Gerät wie in Apples Bildschirmzeit.")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            Label(device.name, systemImage: "iphone").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func usageChart(_ timeline: GateReportTimeline) -> some View {
        let maximum = max(1, ceil((timeline.days.compactMap(\.seconds).max() ?? 0) / 3600 * 1.4))
        return VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(timeline.days) { day in
                    if let seconds = day.seconds {
                        BarMark(x: .value("Tag", day.id, unit: .day), y: .value("Stunden", seconds / 3600), width: .ratio(0.6))
                            .cornerRadius(5)
                            .foregroundStyle(activeDay?.id == day.id ? Color.blue : Color.primary.opacity(selectedDate == nil ? 0.35 : 0.18))
                    }
                }
                if selectedDate != nil, let day = activeDay {
                    RuleMark(x: .value("Tag", day.id, unit: .day))
                        .foregroundStyle(Color.blue.opacity(0.25)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    PointMark(x: .value("Tag", day.id, unit: .day), y: .value("Stunden", (day.seconds ?? 0) / 3600))
                        .foregroundStyle(Color.blue).symbolSize(20)
                        .annotation(position: .top, spacing: 8,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.seconds.map(GateReportDuration.text) ?? "Keine Berichtsdaten").font(.headline).monospacedDigit()
                                Text(Self.dateText(day.id)).font(.caption).foregroundStyle(.secondary)
                            }.padding(12)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                }
            }
            .frame(height: chartHeight)
            .chartXScale(domain: timeline.interval.start...timeline.interval.end)
            .chartYScale(domain: 0...maximum)
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let hours = value.as(Double.self) {
                            Text("\(hours, format: .number.precision(.fractionLength(0...1))) h")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: timeline.days.map(\.id)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) { Text(Self.dateText(date, short: true)) }
                    }
                }
            }
            .chartXSelection(value: Binding(get: { selectedDate }, set: { date in
                if let date, let selectedDate, Calendar.current.isDate(date, inSameDayAs: selectedDate) {
                    self.selectedDate = nil
                } else { selectedDate = date }
            }))
            .chartGesture { proxy in SpatialTapGesture().onEnded { proxy.selectXValue(at: $0.location.x) } }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selectedDate)
            .accessibilityRepresentation {
                VStack {
                    ForEach(timeline.days) { day in
                        Button { selectedDate = day.id } label: {
                            Text("\(Self.dateText(day.id)): \(day.seconds.map(GateReportDuration.text) ?? "Keine Berichtsdaten")")
                        }.accessibilityAddTraits(activeDay?.id == day.id ? .isSelected : [])
                    }
                }
            }
            Text("Tippe auf einen Tag für Details. Fehlende Berichtsdaten werden nicht als gemessene null Minuten gewertet.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func breakdown(_ day: GateReportDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apps & Websites an diesem Tag").font(.headline)
            if day.seconds == nil {
                Text("Für diesen Tag hat iOS noch keine Berichtsdaten geliefert.").font(.subheadline).foregroundStyle(.secondary)
            } else if day.items.isEmpty {
                Text("iOS liefert für diesen Tag keine einzelnen App- oder Website-Einträge.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(showAllItems ? day.items : Array(day.items.prefix(8))) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.subheadline)
                            if item.isWebsite { Text("Website").font(.caption2).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Text(GateReportDuration.text(item.seconds)).font(.subheadline).monospacedDigit()
                    }
                    Divider()
                }
                if day.items.count > 8 {
                    Button(showAllItems ? "Weniger anzeigen" : "Alle \(day.items.count) Einträge anzeigen") { showAllItems.toggle() }
                        .font(.subheadline)
                }
                Text("Die Gesamtzeit stammt aus dem iOS-Bericht. App- und Website-Zeiten können sich überschneiden und werden nicht nochmals zur Gesamtzeit addiert. Angezeigte Minuten sind abgerundet.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
