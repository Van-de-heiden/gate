import SwiftUI

struct LessonArtwork: View {
    let name: String
    var caption: String?
    private var symbol: String {
        switch name {
        case "history": return "globe.europe.africa.fill"
        case "business": return "building.2.fill"
        case "money": return "chart.line.uptrend.xyaxis"
        case "health": return "leaf.fill"
        case "science": return "sparkles"
        case "digital": return "network"
        case "communication": return "bubble.left.and.bubble.right.fill"
        default: return "book.closed.fill"
        }
    }
    private var color: Color {
        switch name {
        case "money", "health": return GateDesign.accent
        case "history", "business": return GateDesign.caution
        default: return GateDesign.blue
        }
    }
    var body: some View {
        HStack {
            Image(systemName: symbol).font(.system(size: 25, weight: .medium))
                .frame(width: 60, height: 60).background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 21))
            Spacer()
        }.foregroundStyle(color).accessibilityHidden(true)
    }
}

struct LessonReadingStep: Identifiable {
    let lesson: LearningLesson
    let index: Int
    var id: String { lesson.id + ".step.\(index)" }
    var card: LessonCard { lesson.cards[index] }
    var isLast: Bool { index == lesson.cards.count - 1 }
}

struct LessonStoryCard: View {
    let card: LessonCard
    let cardID: String
    @ObservedObject var learning: LearningStore
    private var item: SessionQuestion? {
        card.probe.flatMap { probe in learning.session?.questions.first { $0.id == probe.id } }
    }
    private var locked: Bool {
        item.map { learning.session?.lockedQuestionIDs?.contains($0.id) == true } ?? false
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if card.probe == nil {
                Text(card.title).font(.system(.title, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.text).font(.body).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
            }
            if let media = card.media { LessonMediaView(media: media) }
            if let item {
                Eyebrow(text: "Deine Entscheidung · zählt zum Ergebnis")
                QuestionView(item: item, response: learning.session?.response(for: item)) {
                    learning.answer($0, for: item.id)
                }.disabled(locked)
                if locked {
                    let correct = learning.session?.isCorrect(item) == true
                    VStack(alignment: .leading, spacing: 12) {
                        Label(correct ? "Richtig eingeordnet" : "Hier liegt der Unterschied",
                              systemImage: correct ? "checkmark.circle.fill" : "arrow.clockwise")
                            .font(.headline).foregroundStyle(correct ? GateDesign.success : GateDesign.caution)
                        Text(item.question.explanation).font(.body).lineSpacing(5)
                        Text("Antwort gewertet. Diese Frage erscheint im Abschluss nicht nochmals.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background((correct ? GateDesign.success : GateDesign.caution).opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .accessibilityElement(children: .combine)
                } else {
                    Button("Antwort abgeben") {
                        GateKeyboard.dismiss(); learning.submitProbe(item.id, cardID: cardID)
                    }.buttonStyle(GateButtonStyle())
                        .disabled(!item.question.isComplete(learning.session?.response(for: item)))
                    Text("Nach dem Abgeben siehst du die Begründung. Deine erste Antwort zählt.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if let probe = card.probe {
                // A due-only review may not include this chapter's inline question.
                Text("Mitnehmen").font(.title2.bold())
                Text(probe.explanation).font(.body).lineSpacing(6)
            }
        }.gateCard()
    }
}
