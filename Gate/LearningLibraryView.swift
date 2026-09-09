import SwiftUI

struct LearningLibraryView: View {
    @ObservedObject var controller: ScreenTimeController
    @ObservedObject var learning: LearningStore
    @State private var query = ""
    @State private var category = "Alle"
    private var categories: [String] { ["Alle", "Denken & Wissen", "Geld & Wirtschaft", "Mensch & Gesellschaft", "Alltag & Entwicklung", "Natur & Technik"] }
    private var paths: [LearningPath] {
        (learning.catalog?.paths ?? []).filter { category == "Alle" || $0.category == category }
    }
    private var matches: [LearningLesson] {
        let ids = Set(paths.map(\.id))
        return (learning.catalog?.lessons ?? []).filter {
            ids.contains($0.pathID) && (query.isEmpty || ($0.title + " " + $0.objective + " " + $0.cards.map(\.text).joined(separator: " ")).localizedStandardContains(query))
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                Eyebrow(text: "Deine Bibliothek")
                Text("Mehr verstehen.\nBesser leben.").font(.system(.largeTitle, design: .serif))
                Text("\(learning.catalog?.paths.count ?? 0) Lernwege · \(learning.catalog?.lessons.count ?? 0) Kapitel\nWähle eine Frage, die dich wirklich interessiert.")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Thema oder Kapitel suchen", text: $query)
                        .submitLabel(.search).onSubmit { GateKeyboard.dismiss() }
                    if !query.isEmpty { Button { query = ""; GateKeyboard.dismiss() } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Suche löschen") }
                }.padding(14).background(GateDesign.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { item in
                            Button { category = item; GateKeyboard.dismiss() } label: {
                                Text(item).font(.caption.weight(.medium)).padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(category == item ? Color.primary : GateDesign.surface)
                                    .foregroundStyle(category == item ? GateDesign.paper : Color.primary)
                                    .clipShape(Capsule())
                            }.buttonStyle(.plain).accessibilityAddTraits(category == item ? .isSelected : [])
                        }
                    }
                }
                if let error = learning.error { Text(error).font(.footnote) }
                if learning.dueCount > 0 {
                    Button { GateKeyboard.dismiss(); controller.beginPractice(reviewOnly: true) } label: {
                        HStack { Text("Wissen auffrischen"); Spacer(); Text("\(learning.dueCount) fällig") }
                    }.buttonStyle(GateButtonStyle())
                }
                if query.isEmpty {
                    ForEach(paths) { path in
                        NavigationLink { pathDetail(path) } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                LessonArtwork(name: path.artwork ?? "learning")
                                HStack { Eyebrow(text: "Weg \(path.number)"); Spacer(); Eyebrow(text: progressLabel(path)) }
                                Text(path.title).font(.system(.title2, design: .serif))
                                Text(path.subtitle).font(.subheadline).foregroundStyle(.secondary)
                                GateProgressLine(value: progressValue(path))
                                HStack { Text("Kapitel entdecken"); Spacer(); Image(systemName: "arrow.right") }
                                    .font(.caption.weight(.medium)).padding(.top, 4)
                            }.padding(.bottom, 14).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                } else {
                    Eyebrow(text: "\(matches.count) passende Kapitel")
                    ForEach(matches) { lesson in chapterButton(lesson) }
                    if matches.isEmpty { Text("Versuche einen weiteren Begriff, etwa Zins, Schlaf oder Gespräch.").font(.subheadline).foregroundStyle(.secondary) }
                }
                Text("Wissen wird nach 1, 3, 7, 14 und 30 Tagen wieder aufgerufen. Fehler kommen früher zurück. Bildmotive sind eigens erstellte Illustrationsfotos; historische Quellen sind separat gekennzeichnet.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.gateKeyboardDismissal()
    }

    private func progressValue(_ path: LearningPath) -> Double {
        let lessons = learning.catalog?.orderedLessons(in: path.id) ?? []
        return Double(lessons.filter { learning.progress.completedLessonIDs.contains($0.id) }.count) / Double(max(1, lessons.count))
    }
    private func progressLabel(_ path: LearningPath) -> String {
        let lessons = learning.catalog?.orderedLessons(in: path.id) ?? []
        return "\(lessons.filter { learning.progress.completedLessonIDs.contains($0.id) }.count) / \(lessons.count) erarbeitet"
    }
    private func chapterButton(_ lesson: LearningLesson) -> some View {
        Button { GateKeyboard.dismiss(); controller.beginPractice(path: lesson.pathID, lesson: lesson.id) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow(text: "Kapitel \(lesson.order)" + (learning.progress.completedLessonIDs.contains(lesson.id) ? " · erarbeitet" : ""))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption)
                }
                Text(lesson.title).font(.system(.title3, design: .serif))
                Text(lesson.objective).font(.subheadline).foregroundStyle(.secondary)
                Text("Ca. \(max(2, (lesson.readingSeconds + lesson.questions.count * 20 + 59) / 60)) min · \(lesson.questions.count) Aufgaben")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(GateDesign.surface).clipShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }
    private func pathDetail(_ path: LearningPath) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                LessonArtwork(name: path.artwork ?? "learning")
                Eyebrow(text: "Weg \(path.number) · " + progressLabel(path))
                Text(path.title).font(.system(.largeTitle, design: .serif))
                Text(path.subtitle).foregroundStyle(.secondary)
                Button("An meinem Lernstand weiter") { controller.beginPractice(path: path.id) }.buttonStyle(GateButtonStyle())
                Text("Du kannst jedes Kapitel direkt öffnen. Eine Kapitelrunde vermittelt den Stoff und prüft ihn mit verschiedenen Aufgaben.")
                    .font(.subheadline).foregroundStyle(.secondary)
                ForEach(learning.catalog?.orderedLessons(in: path.id) ?? []) { lesson in chapterButton(lesson) }
                Text("Freiwilliges Lernen vergibt keine Bildschirmzeit. Freigabe-Lektionen wechseln weiterhin zwischen den Wegen und berücksichtigen fällige Wiederholungen.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.background(GateDesign.paper).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}
