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
                        }.padding(20).padding(.bottom, 30)
                    }
                }.gateBackground().gateKeyboardDismissal()
                    .onChange(of: page) { _, value in GateKeyboard.dismiss(); learning.setPosition(value); reader.scrollTo("top") }
                    .onChange(of: learning.session?.phase) { _, _ in restorePosition(); GateKeyboard.dismiss(); reader.scrollTo("top") }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schliessen") { GateKeyboard.dismiss(); confirmLeave = true }.foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) { Text("gate / lernen").font(.system(.subheadline, design: .rounded)) }
            }
        }
        .tint(GateDesign.accent)
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
            let saved = session.quizIndex ?? session.finalQuestions.firstIndex { !$0.question.isComplete(session.response(for: $0)) } ?? 0
            page = min(max(0, saved), max(0, session.finalQuestions.count - 1))
        } else {
            let steps = session.readingSteps(in: learning.catalog)
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
            let stepCount = session.readingSteps(in: learning.catalog).count
            let progress = session.phase == "result" ? 1.0 : session.phase == "quiz"
                ? 0.5 + 0.5 * Double(session.answeredCount) / Double(max(1, session.questions.count))
                : 0.5 * Double(session.readerIndex ?? 0) / Double(max(1, stepCount))
            GateProgressLine(value: progress)
            Text(session.phase == "learn"
                 ? "\(session.lessonIDs.count) Kapitel · \(session.questions.count) Prüfungsaufgaben · etwa \(max(1, (session.estimatedSeconds + 59) / 60)) min"
                 : session.phase == "quiz" ? "80 % insgesamt; mindestens zwei Drittel je Kapitel." : "Dein Ergebnis")
                .font(.caption).foregroundStyle(.secondary)
            if session.phase == "learn", let reviews = session.reviewLessonIDs, !reviews.isEmpty {
                Text("\(reviews.count) Kapitel davon festigen bereits Gelerntes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if session.topicID == nil {
                Text("Gespeicherte Runde aus der vorherigen Version. Dein Stand bleibt erhalten; neue Runden bleiben bei einem einzigen Thema.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func reading(_ session: LearningSession) -> some View {
        let steps = session.readingSteps(in: learning.catalog)
        let safePage = min(max(0, page), max(0, steps.count - 1))
        if let step = steps[safe: safePage] {
            let lesson = step.lesson
            let revealed = session.revealedCardIDs?.contains(step.id) == true
            let requiresReveal = (step.card.probe.map { session.inlineQuestionIDs?.contains($0.id) == true } ?? false)
                || session.requiredRevealCardIDs?.contains(step.id) == true
            VStack(alignment: .leading, spacing: 22) {
                Eyebrow(text: step.repair == nil ? "\(lesson.title) · \(step.index + 1)/\(lesson.cards.count)" : "Gezielte Wiederholung")
                if step.card.probe != nil, let media = lesson.cards.compactMap(\.media).first {
                    DisclosureGroup("Abbildung nochmals ansehen") { LessonMediaView(media: media) }
                        .font(.subheadline.weight(.semibold)).gateCard()
                }
                LessonStoryCard(card: step.card, cardID: step.id, learning: learning).id(step.id)
                if step.isLast {

                    DisclosureGroup("Mitnehmen & eigene Notiz") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(lesson.mission ?? lesson.reflection).font(.subheadline)
                            TextField("Deine Erklärung – optional, nicht bewertet", text: Binding(
                                get: { learning.session?.reflectionNotes[lesson.id] ?? "" },
                                set: { learning.note($0, for: lesson.id) }), axis: .vertical)
                                .lineLimit(2...5).padding(12).background(GateDesign.surface)
                            Button("Eingabe fertig") { GateKeyboard.dismiss() }.font(.caption)
                        }.padding(.top, 12)
                    }.font(.subheadline)
                    DisclosureGroup("Originalquellen & Vertiefung") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach([lesson.source] + (lesson.additionalSources ?? []), id: \.url) { source in
                                if let url = URL(string: source.url) {
                                    Link(source.title, destination: url).font(.subheadline).padding(.vertical, 6)
                                }
                            }
                        }.padding(.top, 12)
                    }.font(.subheadline)
                }
                HStack {
                    if page > 0 {
                        Button("Zurück") { page -= 1 }.buttonStyle(GateButtonStyle(prominent: false))
                    }
                    Button(safePage + 1 < steps.count ? "Weiter" : "Zum Abschluss") {
                        GateKeyboard.dismiss()
                        learning.markCardRead(step.id)
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
        let questions = session.finalQuestions
        let index = min(max(0, page), max(0, questions.count - 1))
        return VStack(alignment: .leading, spacing: 24) {
            if let item = questions[safe: index] {
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow(text: "Abschluss · \(index + 1) von \(questions.count)" + (item.isReview ? " · Wiederholung" : ""))
                    QuestionView(item: item, response: session.response(for: item)) {
                        learning.answer($0, for: item.id)
                    }.id(item.id)
                }.gateCard()
            } else {
                Text("Alle Antworten sind abgegeben.").font(.title2.bold())
                Text("Du kannst deine Runde jetzt auswerten.").foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                if page > 0 {
                    Button("Zurück") { GateKeyboard.dismiss(); page -= 1 }.buttonStyle(GateButtonStyle(prominent: false))
                }
                if index + 1 < questions.count {
                    Button("Weiter") { GateKeyboard.dismiss(); page += 1 }.buttonStyle(GateButtonStyle())
                        .disabled(!questions[index].question.isComplete(session.response(for: questions[index])))
                } else {
                    Button("Runde auswerten") { GateKeyboard.dismiss(); controller.submitLesson() }.buttonStyle(GateButtonStyle())
                        .disabled(!session.readyForQuiz || !session.allAnswered)
                }
            }
            Button("Noch einmal nachlesen") { learning.setPhase("learn") }
                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(GateDesign.accent)
        }
    }

    @ViewBuilder
    private func resultView(_ session: LearningSession) -> some View {
        if let result = session.result {
            VStack(alignment: .leading, spacing: 24) {
                Text("\(result.correct) / \(result.total)")
                    .font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(result.passed ? GateDesign.success : GateDesign.caution)
                Text(result.passed ? "Gut erarbeitet." : "Hier liegt noch eine Lücke.")
                    .font(.system(.title2, design: .rounded))
                Text(result.passed
                     ? "Richtige Antworten kommen später wieder – mit wachsendem Abstand. Falsche Antworten werden früher wiederholt."
                     : "Noch keine Freigabe. Der nächste Versuch bleibt bei diesem Thema und übt die Lücken weiter.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if !result.passed, (session.catalogVersion ?? 0) >= 8,
                   LessonLoad.passes(correct: result.correct, total: result.total) {
                    Text("Die Gesamtquote reicht, aber in mindestens einem Kapitel fehlen noch zwei Drittel richtige Antworten.")
                        .font(.subheadline)
                }
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

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
