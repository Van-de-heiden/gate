import Combine
import SwiftUI

struct LessonView: View {
    @ObservedObject var controller: ScreenTimeController
    @ObservedObject var learning: LearningStore
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
                }.background(GateDesign.paper).gateKeyboardDismissal()
                    .onChange(of: page) { _, value in GateKeyboard.dismiss(); learning.setPosition(value); reader.scrollTo("top") }
                    .onChange(of: learning.session?.phase) { _, _ in restorePosition(); GateKeyboard.dismiss(); reader.scrollTo("top") }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schliessen") { GateKeyboard.dismiss(); confirmLeave = true }.foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) { Text("gate / lernen").font(.system(.subheadline, design: .serif)) }
            }
        }
        .tint(.primary)
        .interactiveDismissDisabled()
        .confirmationDialog("Lektion unterbrechen?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Speichern & schliessen") { learning.suspend() }
            Button("Weiterlernen", role: .cancel) {}
        } message: { Text("Dein Stand bleibt erhalten. Ohne bestandenen Test gibt es keine Freigabe.") }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if scenePhase == .active { learning.tick() }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { learning.checkpoint() } }
        .onAppear { restorePosition() }
    }

    private func restorePosition() {
        guard let session = learning.session else { page = 0; return }
        if session.phase == "quiz" {
            let saved = session.quizIndex ?? session.questions.firstIndex { !$0.question.isComplete(session.response(for: $0)) } ?? 0
            page = min(max(0, saved), max(0, session.questions.count - 1))
        } else {
            let steps = session.lessonIDs.flatMap { id in learning.catalog?.lessons.first { $0.id == id }?.cards ?? [] }
            page = min(max(0, session.readerIndex ?? 0), max(0, steps.count - 1))
        }
    }

    private func header(_ session: LearningSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: session.isPractice ? "Freiwillig lernen · keine Konsumfreigabe" : "Lernen für \(session.grantMinutes) aktive Minuten")
            if let target = session.target {
                GateTargetLabel(target: target).font(.subheadline).foregroundStyle(.secondary)
            }
            let title = session.topicID.flatMap { learning.catalog?.topic($0)?.title }
                ?? learning.catalog?.paths.first { $0.id == session.pathID }?.title ?? "Wissen"
            Text(title).font(.title2.weight(.semibold))
            let stepCount = session.lessonIDs.reduce(0) { count, id in
                count + (learning.catalog?.lessons.first { $0.id == id }?.cards.count ?? 0)
            }
            let progress = session.phase == "result" ? 1.0 : session.phase == "quiz"
                ? 0.5 + 0.5 * Double(session.answeredCount) / Double(max(1, session.questions.count))
                : 0.5 * Double(session.readerIndex ?? 0) / Double(max(1, stepCount))
            GateProgressLine(value: progress)
            Text(session.phase == "learn"
                 ? "\(session.topicID == nil ? "Gespeicherte Runde" : "Ein Thema") · \(session.lessonIDs.count) Kapitel · \(session.questions.count) Prüfungsfragen · ca. \(max(1, session.estimatedSeconds / 60))–\(max(2, session.estimatedSeconds / 60 + 1)) min"
                 : session.phase == "quiz" ? "Ohne Vorlage abrufen. Mindestens 80 % richtig." : "Dein Ergebnis")
                .font(.caption).foregroundStyle(.secondary)
            if session.topicID == nil {
                Text("Gespeicherte Runde aus der vorherigen Version. Dein Stand bleibt erhalten; neue Runden bleiben bei einem einzigen Thema.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func reading(_ session: LearningSession) -> some View {
        let lessons = session.lessonIDs.compactMap { id in learning.catalog?.lessons.first { $0.id == id } }
        let steps = lessons.flatMap { lesson in lesson.cards.indices.map { LessonReadingStep(lesson: lesson, index: $0) } }
        let safePage = min(max(0, page), max(0, steps.count - 1))
        if let step = steps[safe: safePage] {
            let lesson = step.lesson
            let revealed = session.revealedCardIDs?.contains(step.id) == true
            let requiresReveal = step.card.reveal != nil || step.card.probe != nil
            VStack(alignment: .leading, spacing: 22) {
                Eyebrow(text: "\(lesson.title) · \(step.index + 1)/\(lesson.cards.count)")
                LessonStoryCard(card: step.card, cardID: step.id, learning: learning).id(step.id)
                if step.isLast {
                    if lesson.topicID == nil {
                        if let photo = lesson.photo { LessonPhotoView(photo: photo) }
                        LessonDiagram(visual: lesson.visual)
                    }
                    Text(lesson.takeaway).font(.subheadline.weight(.medium))
                    DisclosureGroup("Mitnehmen & eigene Notiz") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(lesson.mission ?? lesson.reflection).font(.subheadline)
                            TextField("Deine Erklärung – optional, nicht bewertet", text: Binding(
                                get: { learning.session?.reflectionNotes[lesson.id] ?? "" },
                                set: { learning.note($0, for: lesson.id) }), axis: .vertical)
                                .lineLimit(2...5).padding(12).background(GateDesign.surface)
                            Button("Eingabe fertig") { GateKeyboard.dismiss() }.font(.caption)
                            if let url = URL(string: lesson.source.url) {
                                Link("Quelle / Vertiefung: \(lesson.source.title)", destination: url).font(.caption)
                            }
                        }.padding(.top, 12)
                    }.font(.subheadline)
                }
                HStack {
                    if page > 0 {
                        Button("Zurück") { page -= 1 }.buttonStyle(GateButtonStyle(prominent: false))
                    }
                    Button(safePage + 1 < steps.count ? "Weiter" : "Jetzt selbst prüfen") {
                        GateKeyboard.dismiss()
                        if step.isLast { learning.markRead(lesson.id) }
                        if safePage + 1 < steps.count { page = safePage + 1 }
                        else { learning.setPhase("quiz") }
                    }.buttonStyle(GateButtonStyle()).disabled(requiresReveal && !revealed)
                }
                Text("\(safePage + 1) von \(steps.count) Lernschritten · dein Stand wird gespeichert")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func quiz(_ session: LearningSession) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(Array(session.questions.enumerated()).filter { $0.offset == min(page, session.questions.count - 1) }, id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Frage \(index + 1) / \(session.questions.count)" + (item.isReview ? " · Wiederholung" : " · " + item.question.kind.title))
                    QuestionView(item: item, response: session.response(for: item)) {
                        learning.answer($0, for: item.id)
                    }
                }
            }
            HStack(spacing: 12) {
                if page > 0 {
                    Button("Zurück") { GateKeyboard.dismiss(); page -= 1 }.buttonStyle(GateButtonStyle(prominent: false))
                }
                if page + 1 < session.questions.count {
                    Button("Nächste Aufgabe") { GateKeyboard.dismiss(); page += 1 }.buttonStyle(GateButtonStyle())
                        .disabled(!session.questions[min(page, session.questions.count - 1)].question.isComplete(session.response(for: session.questions[min(page, session.questions.count - 1)])))
                } else {
                    Button("Antworten prüfen") { GateKeyboard.dismiss(); controller.submitLesson() }.buttonStyle(GateButtonStyle())
                        .disabled(!session.readyForQuiz || !session.allAnswered)
                }
            }
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
                     : "Noch keine Freigabe. Der nächste Versuch bleibt bei diesem Thema und übt die Lücken weiter.")
                    .font(.subheadline).foregroundStyle(.secondary)
                ForEach(session.questions) { item in
                    let correct = session.isCorrect(item)
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: correct ? "Richtig" : "Noch einmal ansehen")
                        Text(item.question.prompt).font(.subheadline.weight(.semibold))
                        Text(item.question.correctAnswer).font(.subheadline)
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
