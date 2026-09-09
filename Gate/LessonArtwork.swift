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
