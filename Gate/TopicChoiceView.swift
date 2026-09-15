import SwiftUI

struct TopicChoiceView: View {
    @ObservedObject var learning: LearningStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Eyebrow(text: "Deine nächste Entdeckung")
                    Text("Was willst du\nverstehen?").font(.largeTitle.bold())
                    Text("Zwei Vorschläge. Eine neue Entdeckung pro Runde. Du wählst, was dich interessiert. Die Aufgaben zählen mit.")
                        .font(.body).foregroundStyle(.secondary)
                    if let offer = learning.choice?.offer, let catalog = learning.catalog {
                        if offer.isReview == true {
                            Text("Du hast alle Kapitel abgeschlossen. Diese Vorschläge sind Wiederholungen.")
                                .font(.body).foregroundStyle(GateDesign.accent)
                        }
                        ForEach(offer.topicIDs, id: \.self) { id in
                            if let topic = catalog.topic(id) {
                                let chapters = catalog.chapters(in: id).filter { $0.id == offer.chapterIDs?[id] }
                                let minutes = max(2, (chapters.reduce(0) { $0 + $1.readingSeconds + $1.questions.count * 20 } + 59) / 60)
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: symbol(topic.pathID)).font(.title2)
                                            .foregroundStyle(GateDesign.accent)
                                        Spacer()
                                        Text(topic.title).font(.caption.weight(.semibold))
                                    }
                                    Text(chapters.first?.title ?? topic.title).font(.title2.bold())
                                    Text(chapters.first?.objective ?? topic.hook).font(.body).foregroundStyle(.secondary)
                                    Text("\(chapters.count) Kapitel · etwa \(minutes) min · \(chapters.flatMap(\.questions).count) Aufgaben")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Button { learning.choose(id) } label: {
                                        HStack { Text(offer.isReview == true ? "Kapitel wiederholen" : "Kapitel entdecken"); Spacer(); Image(systemName: "arrow.right") }
                                    }.buttonStyle(GateButtonStyle())
                                        .accessibilityLabel("\(topic.title) lernen")
                                }.gateCard()
                            }
                        }
                    }
                    Text("Du kannst später fortsetzen. Diese beiden Vorschläge bleiben für deine Anfrage gespeichert.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }.gateBackground()
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Später") { learning.suspend() } } }
        }
    }

    private func symbol(_ path: String) -> String {
        switch path {
        case "industries": "cpu"
        case "health": "moon.stars"
        case "history": "books.vertical"
        case "philosophy": "bubble.left.and.bubble.right"
        case "business": "building.2"
        case "earth": "globe.europe.africa"
        case "digital": "lock.shield"
        case "learn": "brain.head.profile"
        default: "eye"
        }
    }
}
