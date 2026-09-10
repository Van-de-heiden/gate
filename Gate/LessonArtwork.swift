import SwiftUI

struct LessonArtwork: View {
    let name: String
    var caption: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image("Path-" + name).resizable().aspectRatio(1.5, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityLabel(description)
            if let caption {
                Text(caption).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
    private var description: String {
        switch name {
        case "history": return "Stille Bibliothek mit Steinbogen und einer klassischen Büste."
        case "business": return "Werkstatt mit Werkzeugen und mechanischen Bauteilen."
        case "money": return "Münzstapel, eine Waage und eine Sanduhr."
        case "health": return "Frühstück, Gehschuhe und Blick in einen Garten."
        case "science": return "Gewächshaus mit Pflanzen und Glasgefässen."
        case "digital": return "Geschlossener Laptop, Sicherheitsschlüssel und abgelegtes Telefon."
        case "communication": return "Zwei Stühle und eine ruhige Gelegenheit zum Gespräch."
        default: return "Offenes Buch, Notizzettel und ein Prisma im Sonnenlicht."
        }
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
    @State private var showImage = false
    private var revealed: Bool { learning.session?.revealedCardIDs?.contains(cardID) == true }
    private var response: QuestionResponse? { card.probe.flatMap { learning.session?.probeResponses?[$0.id] } }
    private var label: String {
        switch card.kind {
        case "scene": return "Mittendrin"
        case "decision": return "Deine Entscheidung"
        case "evidence": return "Die Spur prüfen"
        case "lab": return "Gedankenlabor"
        case "reveal": return "Erst überlegen"
        case "dialogue": return "Zwei Perspektiven"
        case "transfer": return "Du bist dran"
        default: return "Genauer hinsehen"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Eyebrow(text: label)
            Text(card.title).font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
            if let name = card.image {
                Button { showImage = true } label: {
                    Image(name).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain).accessibilityLabel((card.imageDescription ?? "Szenenbild") + " · Vergrössern")
                Text(card.caption ?? "KI-Illustration, keine historische Quelle.").font(.caption2).foregroundStyle(.secondary)
            }
            Text(card.text).font(.body).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
            if let visual = card.visual { LessonDiagram(visual: visual) }
            if let question = card.probe {
                let indices = Array(question.options.indices)
                let offset = indices.isEmpty ? 0 : question.id.utf8.reduce(0) { ($0 + Int($1)) % indices.count }
                let order = Array(indices.dropFirst(offset)) + Array(indices.prefix(offset))
                QuestionView(item: SessionQuestion(question: question, lessonID: cardID, isReview: false, optionOrder: order),
                             response: response) { learning.probe($0, for: question.id) }
                    .disabled(revealed)
                Text("Lernversuch, keine Prüfungsnote. Eine falsche Vermutung kostet keine Freigabe.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if card.reveal != nil || card.probe != nil {
                if revealed {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(card.probe == nil ? "Auflösung" : card.probe!.isCorrect(response) ? "Gut begründet" : "Ein wichtiger Unterschied", systemImage: "lightbulb")
                            .font(.subheadline.weight(.semibold))
                        if let question = card.probe { Text(question.explanation).font(.body).lineSpacing(5) }
                        if let reveal = card.reveal { Text(reveal).font(.body).lineSpacing(5) }
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 18))
                        .accessibilityElement(children: .combine)
                } else {
                    Button(card.probe == nil ? "Gedanken vergleichen" : "Begründung ansehen") {
                        GateKeyboard.dismiss(); learning.reveal(cardID)
                    }.buttonStyle(GateButtonStyle(prominent: false))
                        .disabled(card.probe != nil && !(card.probe?.isComplete(response) ?? false))
                }
            }
        }
        .sheet(isPresented: $showImage) {
            NavigationStack {
                ScrollView {
                    if let name = card.image {
                        Image(name).resizable().scaledToFit().accessibilityLabel(card.imageDescription ?? "Szenenbild")
                        Text(card.caption ?? "KI-Illustration").font(.subheadline).padding()
                    }
                }.navigationTitle("Im Detail").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { showImage = false } } }
            }
        }
    }
}
