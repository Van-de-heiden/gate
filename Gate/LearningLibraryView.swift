import SwiftUI

struct LearningLibraryView: View {
    @ObservedObject var controller: ScreenTimeController
    @ObservedObject var learning: LearningStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Eyebrow(text: "Deine Bibliothek")
                Text("Wissen,\ndas bleibt.").font(.system(.largeTitle, design: .serif))
                Text("Acht Wege. Kurze Kapitel. Echte Wiederholung.\nFreigabe-Lektionen werden gemischt; hier lernst du freiwillig.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let error = learning.error { Text(error).font(.footnote) }
                if learning.dueCount > 0 {
                    Button { controller.beginPractice() } label: {
                        HStack { Text("Wissen auffrischen"); Spacer(); Text("\(learning.dueCount) fällig") }
                    }.buttonStyle(GateButtonStyle())
                }
                ForEach(learning.catalog?.paths ?? []) { path in
                    NavigationLink {
                        pathDetail(path)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Eyebrow(text: "Weg \(path.number)"); Spacer(); Eyebrow(text: progressLabel(path)) }
                            Text(path.title).font(.system(.title2, design: .serif))
                            Text(path.subtitle).font(.subheadline).foregroundStyle(.secondary)
                            GateProgressLine(value: progressValue(path))
                        }.padding(.vertical, 12)
                    }.buttonStyle(.plain)
                    Divider()
                }
                Text("Wiederholungen nach 1, 3, 7, 14 und 30 Tagen sind die Startregel. Fehler werden früher eingeplant. Keine Lernwirksamkeitsgarantie und kein Ersatz für einen vollständigen Fachkurs.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
    }

    private func progressValue(_ path: LearningPath) -> Double {
        let lessons = learning.catalog?.orderedLessons(in: path.id) ?? []
        return Double(lessons.filter { learning.progress.completedLessonIDs.contains($0.id) }.count) / Double(max(1, lessons.count))
    }
    private func progressLabel(_ path: LearningPath) -> String {
        let lessons = learning.catalog?.orderedLessons(in: path.id) ?? []
        return "\(lessons.filter { learning.progress.completedLessonIDs.contains($0.id) }.count) / \(lessons.count) erarbeitet"
    }

    private func pathDetail(_ path: LearningPath) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Eyebrow(text: "Weg \(path.number)")
                Text(path.title).font(.system(.largeTitle, design: .serif))
                Text(path.subtitle).foregroundStyle(.secondary)
                ForEach(learning.catalog?.orderedLessons(in: path.id) ?? []) { lesson in
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Kapitel \(lesson.order)" + (learning.progress.completedLessonIDs.contains(lesson.id) ? " · erarbeitet" : " · offen"))
                        Text(lesson.title).font(.system(.title2, design: .serif))
                        Text(lesson.objective).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Divider()
                }
                Button("Diesen Weg lernen") { controller.beginPractice(path: path.id) }.buttonStyle(GateButtonStyle())
                Text("Freiwilliges Lernen vergibt keine Bildschirmzeit. Die nächste Freigabe bleibt an die angeforderte App gebunden.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.navigationBarTitleDisplayMode(.inline)
    }
}
