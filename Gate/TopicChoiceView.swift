import SwiftUI

struct TopicChoiceView: View {
    @ObservedObject var learning: LearningStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Eyebrow(text: "Deine nächste Entdeckung")
                    Text("Was willst du\nverstehen?").font(.largeTitle.bold())
                    Text("Ein Thema am Stück. Mehr Freigabezeit vertieft denselben Gedanken.")
                        .font(.body).foregroundStyle(.secondary)
                    if let offer = learning.choice?.offer, let catalog = learning.catalog {
                        if offer.isReview == true {
                            Text("Du hast alle Kapitel abgeschlossen. Diese Vorschläge sind Wiederholungen.")
                                .font(.body).foregroundStyle(GateDesign.accent)
                        }
                        ForEach(offer.topicIDs, id: \.self) { id in
                            if let topic = catalog.topic(id) {
                                let chapters = learning.offeredChapters(for: id)
                                let questionCount = chapters.reduce(0) { $0 + $1.assessmentCount }
                                let minutes = max(2, (chapters.reduce(0) { $0 + $1.readingSeconds + $1.assessmentCount * 20 } + 59) / 60)
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: symbol(topic.pathID)).font(.title2)
                                            .foregroundStyle(GateDesign.accent)
                                        Spacer()
                                        Text("\(chapters.count) Kapitel").font(.caption.weight(.semibold))
                                    }
                                    Text(topic.title).font(.title2.bold())
                                    Text(topic.hook).font(.body).foregroundStyle(.secondary)
                                    Text(chapters.map(\.title).joined(separator: "\n"))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Text("\(chapters.count) Kapitel · etwa \(minutes) min · \(questionCount) Prüfungsaufgaben")
                                        .font(.caption).foregroundStyle(.secondary)
                                    let reviews = chapters.filter { learning.progress.hasFinished($0) }.count
                                    if reviews > 0 {
                                        Text("Davon \(reviews) Kapitel zum Auffrischen.")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Button { learning.choose(id) } label: {
                                        HStack { Text(offer.isReview == true ? "Wissen auffrischen" : "Diese Vertiefung beginnen"); Spacer(); Image(systemName: "arrow.right") }
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
