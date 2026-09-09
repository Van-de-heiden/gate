import Combine
import SwiftUI

struct IntentionalPauseView: View {
    @ObservedObject var controller: ScreenTimeController
    @Environment(\.scenePhase) private var scenePhase
    @State private var seconds = 60
    @State private var running = false
    @State private var trigger = ""
    @State private var nextStep: String?
    private let triggers = ["Langeweile", "Stress", "Einsamkeit", "Gewohnheit", "Neugier"]
    private let steps = ["Handy ausser Reichweite legen", "Kurz aufstehen und bewegen", "Jemandem schreiben oder anrufen", "Eine kleine Aufgabe beginnen"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Text("gate").font(.system(.title2, design: .serif)).tracking(-1)
                        Spacer()
                        Eyebrow(text: "Ein Moment für dich")
                    }
                    Text("Ein Impuls ist\nkein Auftrag.").font(.system(.largeTitle, design: .serif))
                    Text("Du hast entschieden, explizite Inhalte aus deinem Alltag herauszuhalten. Diese Grenze gilt auch jetzt.")
                        .font(.title3).lineSpacing(4)
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Was du gerade aufs Spiel setzt")
                        Text("Vielleicht wird aus einem kurzen Besuch wieder eine längere Sitzung. Diese Zeit fehlt dann für Schlaf, Begegnungen oder ein Vorhaben, das dir wichtig ist. Wenn du gegen deinen eigenen Plan handelst, kann dich das hinterher belasten.")
                            .font(.subheadline).lineSpacing(4)
                        Text("Du kannst hier abbrechen. Ein einzelner Impuls bestimmt weder deinen Charakter noch deinen nächsten Schritt.")
                            .font(.subheadline.weight(.medium))
                    }.padding(20).background(GateDesign.surface).clipShape(RoundedRectangle(cornerRadius: 14))
                    GateSection(title: "01 · Abstand schaffen") {
                        Text("Schliess den Browser-Tab. Lass die Schultern locker und atme ruhig. Beobachte den Drang, ohne ihn sofort umzusetzen.")
                            .font(.subheadline)
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(seconds)").font(.system(size: 60, weight: .light, design: .serif)).monospacedDigit()
                            Text("Sekunden für dich").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Button(seconds == 0 ? "Noch eine ruhige Minute" : running ? "Pause unterbrechen" : "Ruhige Minute starten") {
                            if seconds == 0 { seconds = 60; running = true } else { running.toggle() }
                        }.buttonStyle(GateButtonStyle(prominent: false))
                    }
                    GateSection(title: "02 · Was steckt dahinter?") {
                        Text("Eine Vermutung reicht. Du musst dich nicht rechtfertigen.").font(.subheadline).foregroundStyle(.secondary)
                        ForEach(triggers, id: \.self) { value in
                            Button { trigger = value } label: {
                                HStack { Text(value); Spacer(); Image(systemName: trigger == value ? "checkmark.circle.fill" : "circle") }
                                    .padding(.vertical, 9)
                            }.buttonStyle(.plain).accessibilityAddTraits(trigger == value ? .isSelected : [])
                        }
                        if !trigger.isEmpty { Text(suggestion).font(.subheadline).padding(14).background(GateDesign.surface) }
                    }
                    GateSection(title: "03 · Eine Handlung wählen") {
                        ForEach(steps, id: \.self) { step in
                            Button { nextStep = step } label: {
                                HStack { Text(step).multilineTextAlignment(.leading); Spacer(); if nextStep == step { Image(systemName: "checkmark") } }
                                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(GateDesign.surface)
                            }.buttonStyle(.plain)
                        }
                        if let nextStep { Text("Dein nächster Schritt: \(nextStep).").font(.subheadline.weight(.medium)) }
                        Button("Zurück zu meinem Tag") { controller.closePause() }.buttonStyle(GateButtonStyle())
                    }
                    Text("Die geschützte Website bleibt gesperrt. Die Pause ist keine Freischaltaufgabe. Deine Antworten hier werden nicht gespeichert.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Wenn sich der Konsum wiederholt deiner Kontrolle entzieht oder dich belastet, kann ein Gespräch mit einer qualifizierten Beratungsstelle oder Fachperson helfen.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }.background(GateDesign.paper).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Schliessen") { controller.closePause() } } }
        }.tint(.primary)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                guard running, scenePhase == .active, seconds > 0 else { return }
                seconds -= 1
                if seconds == 0 { running = false }
            }
    }

    private var suggestion: String {
        switch trigger {
        case "Stress": return "Wähle eine kleine entlastende Handlung: Wasser holen, kurz gehen oder den nächsten Arbeitsschritt notieren."
        case "Einsamkeit": return "Suche eine echte Verbindung: eine kurze Nachricht oder ein Anruf kann ein Anfang sein."
        case "Gewohnheit": return "Ändere den Ort: Steh auf und lege das Handy dorthin, wo du es nicht automatisch wieder greifst."
        case "Neugier": return "Du darfst neugierig sein und diesen Inhalt trotzdem geschlossen lassen. Wähle bewusst etwas anderes."
        default: return "Nimm eine kleine greifbare Aufgabe: ein paar Seiten lesen, etwas aufräumen oder frische Luft holen."
        }
    }
}
