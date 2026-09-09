import AVFoundation
import Combine
import SwiftUI

@MainActor
final class LessonNarrator: ObservableObject {
    private let speaker = AVSpeechSynthesizer()
    func read(_ lesson: LearningLesson) {
        speaker.stopSpeaking(at: .immediate)
        let text = ([lesson.title, lesson.objective] + lesson.cards.map { $0.title + ". " + $0.text } + [lesson.takeaway]).joined(separator: "\n\n")
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        speaker.speak(utterance)
    }
    func stop() { speaker.stopSpeaking(at: .immediate) }
}

struct LessonView: View {
    @ObservedObject var controller: ScreenTimeController
    @ObservedObject var learning: LearningStore
    @StateObject private var narrator = LessonNarrator()
    @Environment(\.scenePhase) private var scenePhase
    @State private var page = 0
    @State private var confirmLeave = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    if let session = learning.session {
                        VStack(alignment: .leading, spacing: 26) {
                            Color.clear.frame(height: 1).id("top")
                            header(session)
                            if let error = learning.error { Text(error).font(.footnote) }
                            if session.phase == "result" { resultView(session) }
                            else if session.phase == "quiz" { quiz(session) }
                            else { reading(session) }
                        }.padding(24).padding(.bottom, 30)
                    }
                }.background(GateDesign.paper)
                    .onChange(of: page) { _, _ in reader.scrollTo("top"); narrator.stop() }
                    .onChange(of: learning.session?.phase) { _, _ in page = 0; reader.scrollTo("top"); narrator.stop() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schliessen") { confirmLeave = true }.foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) { Text("gate / lernen").font(.system(.subheadline, design: .serif)) }
            }
        }
        .tint(.primary)
        .interactiveDismissDisabled()
        .confirmationDialog("Lektion unterbrechen?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Speichern & schliessen") { narrator.stop(); learning.suspend() }
            Button("Weiterlernen", role: .cancel) {}
        } message: { Text("Dein Stand bleibt erhalten. Ohne bestandenen Test gibt es keine Freigabe.") }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if scenePhase == .active { learning.tick() }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { narrator.stop(); learning.checkpoint() } }
        .onDisappear { narrator.stop() }
    }

    private func header(_ session: LearningSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: session.isPractice ? "Freiwillig lernen · keine Konsumfreigabe" : "Lernen für \(session.grantMinutes) aktive Minuten")
            if let target = session.target {
                GateTargetLabel(target: target).font(.subheadline).foregroundStyle(.secondary)
            }
            let title = learning.catalog?.paths.first { $0.id == session.pathID }?.title ?? "Wissen"
            Text(title).font(.system(.largeTitle, design: .serif))
            let progress = session.phase == "result" ? 1.0 : session.phase == "quiz"
                ? 0.5 + 0.5 * Double(session.responses.count) / Double(max(1, session.questions.count))
                : 0.5 * Double(session.readLessonIDs.count) / Double(max(1, session.lessonIDs.count))
            GateProgressLine(value: progress)
            Text(session.phase == "learn"
                 ? "\(session.lessonIDs.count) kurze Kapitel · \(session.questions.count) Fragen · ca. \(max(1, session.estimatedSeconds / 60))–\(max(2, session.estimatedSeconds / 60 + 1)) min"
                 : session.phase == "quiz" ? "Ohne Vorlage abrufen. Mindestens 80 % richtig." : "Dein Ergebnis")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func reading(_ session: LearningSession) -> some View {
        let safePage = min(page, max(0, session.lessonIDs.count - 1))
        if let id = session.lessonIDs[safe: safePage],
           let lesson = learning.catalog?.lessons.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Eyebrow(text: "Kapitel \(safePage + 1) / \(session.lessonIDs.count)")
                    Spacer()
                    Button("Anhören") { narrator.read(lesson) }.font(.caption).underline()
                    Button("Stopp") { narrator.stop() }.font(.caption).foregroundStyle(.secondary)
                }
                Text(lesson.title).font(.system(.title, design: .serif))
                Text(lesson.objective).font(.subheadline.weight(.medium))
                ForEach(Array(lesson.cards.enumerated()), id: \.offset) { _, card in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.title).font(.headline)
                        Text(card.text).font(.body).lineSpacing(5)
                    }
                }
                if let photo = lesson.photo { LessonPhotoView(photo: photo) }
                LessonDiagram(visual: lesson.visual)
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Denkpause · ohne Vorlage")
                    Text(lesson.reflection).font(.system(.body, design: .serif))
                    TextField("Deine Erklärung in eigenen Worten (optional)", text: Binding(
                        get: { learning.session?.reflectionNotes[id] ?? "" },
                        set: { learning.note($0, for: id) }), axis: .vertical)
                        .lineLimit(2...5).padding(12).background(GateDesign.paper)
                    Text("Die Notiz wird nicht automatisch bewertet. Die Prüfung folgt danach.")
                        .font(.caption2).foregroundStyle(.secondary)
                }.padding(18).background(GateDesign.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Das bleibt")
                    Text(lesson.takeaway).font(.subheadline.weight(.medium))
                }
                if let url = URL(string: lesson.source.url) {
                    Link("Vertiefen: \(lesson.source.title)", destination: url).font(.caption).underline()
                }
                HStack {
                    if page > 0 {
                        Button("Zurück") { page -= 1 }.buttonStyle(GateButtonStyle(prominent: false))
                    }
                    Button(safePage + 1 < session.lessonIDs.count ? "Verstanden · weiter" : "Zur Prüfung") {
                        learning.markRead(id)
                        if safePage + 1 < session.lessonIDs.count { page += 1 }
                        else { learning.setPhase("quiz") }
                    }.buttonStyle(GateButtonStyle())
                }
            }
        }
    }

    private func quiz(_ session: LearningSession) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(Array(session.questions.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Frage \(index + 1)" + (item.isReview ? " · Wiederholung" : " · Anwenden"))
                    Text(item.question.prompt).font(.headline)
                    ForEach(item.optionOrder, id: \.self) { option in
                        Button { learning.answer(option, for: item.id) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Circle().fill(session.responses[item.id] == option ? Color.primary : .clear)
                                    .overlay(Circle().stroke(GateDesign.line)).frame(width: 14, height: 14).padding(.top, 3)
                                Text(item.question.options[option]).font(.subheadline).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(session.responses[item.id] == option ? Color.primary.opacity(0.09) : GateDesign.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                            .accessibilityAddTraits(session.responses[item.id] == option ? .isSelected : [])
                    }
                }
            }
            Button("Antworten prüfen") { controller.submitLesson() }.buttonStyle(GateButtonStyle())
                .disabled(!session.readyForQuiz || session.responses.count != session.questions.count)
            Button("Noch einmal nachlesen") { learning.setPhase("learn") }
                .font(.footnote).frame(maxWidth: .infinity).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func resultView(_ session: LearningSession) -> some View {
        if let result = session.result {
            VStack(alignment: .leading, spacing: 24) {
                Text("\(result.correct) / \(result.total)")
                    .font(.system(size: 64, weight: .light, design: .serif)).monospacedDigit()
                Text(result.passed ? "Gut erarbeitet." : "Hier liegt noch eine Lücke.")
                    .font(.system(.title2, design: .serif))
                Text(result.passed
                     ? "Richtige Antworten kommen später wieder – mit wachsendem Abstand. Falsche Antworten werden früher wiederholt."
                     : "Noch keine Freigabe. Lies die Erklärungen; der nächste Versuch enthält etwas mehr Stoff.")
                    .font(.subheadline).foregroundStyle(.secondary)
                ForEach(session.questions) { item in
                    let correct = session.responses[item.id] == item.question.correctIndex
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: correct ? "Richtig" : "Noch einmal ansehen")
                        Text(item.question.prompt).font(.subheadline.weight(.semibold))
                        Text(item.question.options[item.question.correctIndex]).font(.subheadline)
                        Text(item.question.explanation).font(.footnote).foregroundStyle(.secondary).lineSpacing(3)
                    }.padding(16).background(GateDesign.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if result.passed {
                    Button(session.isPractice ? "Für heute mitgenommen" : "\(session.grantMinutes) Minuten freigeben") {
                        controller.finishLesson()
                    }.buttonStyle(GateButtonStyle()).disabled(learning.error != nil)
                } else if let target = session.target,
                          let until = controller.state.attempts[target.id]?.cooldownUntil, until > Date() {
                    Text("Neue Runde für diese App ab \(until.formatted(date: .omitted, time: .shortened)). Andere Apps bleiben unabhängig.")
                        .font(.footnote)
                    Button("Zur Übersicht") { learning.suspend() }.buttonStyle(GateButtonStyle())
                } else {
                    Button("Erneut lernen") { controller.retryLesson() }.buttonStyle(GateButtonStyle())
                }
            }
        }
    }
}

struct LessonPhotoView: View {
    let photo: LessonPhoto
    @State private var showPhoto = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showPhoto {
                AsyncImage(url: URL(string: photo.url)) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 10))
                    case .failure: Text("Foto gerade nicht verfügbar. Die Lektion und das Diagramm funktionieren auch ohne Verbindung.").font(.footnote).padding(16)
                    default: ProgressView().tint(.primary).frame(maxWidth: .infinity).frame(height: 140)
                    }
                }
            } else {
                Button("Quellenfoto laden") { showPhoto = true }.buttonStyle(GateButtonStyle(prominent: false))
                Text("Lädt dieses Bild direkt von NASA; dabei erhält der Anbieter deine IP-Adresse.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text(photo.caption).font(.footnote)
            if let url = URL(string: photo.sourceURL) {
                Link(photo.credit, destination: url).font(.caption2).foregroundStyle(.secondary).underline()
            }
        }
    }
}

struct LessonDiagram: View {
    let visual: LessonVisual
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: visual.title)
            if visual.kind == "bars", let values = visual.values, values.count == visual.labels.count {
                let maxValue = max(1, values.max() ?? 1)
                ForEach(visual.labels.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(visual.labels[i])
                            Spacer()
                            Text(values[i], format: .number.precision(.fractionLength(0...2))).monospacedDigit()
                        }.font(.caption)
                        GateProgressLine(value: values[i] / maxValue)
                    }
                }
            } else if visual.kind == "compare" {
                ForEach(visual.labels.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 14) {
                        Text(String(format: "%02d", i + 1)).font(.caption.monospaced()).foregroundStyle(.secondary)
                        Text(visual.labels[i]).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    }.padding(.vertical, 8)
                    if i + 1 < visual.labels.count { Divider() }
                }
            } else {
                ForEach(visual.labels.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(visual.labels[i]).font(.subheadline.weight(.medium))
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(GateDesign.paper)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(GateDesign.line))
                        if i + 1 < visual.labels.count {
                            Image(systemName: "arrow.down").font(.caption).foregroundStyle(.secondary).padding(.leading, 16).accessibilityHidden(true)
                        }
                    }
                }
            }
            Text(visual.caption).font(.caption).foregroundStyle(.secondary)
        }.padding(18).background(GateDesign.surface).clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
