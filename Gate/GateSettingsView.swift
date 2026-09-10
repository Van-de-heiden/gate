import FamilyControls
import SwiftUI
import UIKit
import UserNotifications

struct GateSettingsView: View {
    @ObservedObject var controller: ScreenTimeController
    @State private var picker = false
    @State private var protectedPicker = false
    @State private var showOnboarding = false
    @State private var notificationsAllowed: Bool?
    @State private var confirmTest = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Eyebrow(text: "Dein Rahmen")
                Text("Dein Gate.").font(.largeTitle.bold())
                GateSection(title: "Tagesbudget") {
                    HStack(alignment: .firstTextBaseline) {
                        Text(controller.state.isTestMode ? "Testmodus" : "Alltag").font(.title2.bold())
                        Spacer()
                        Text("\(controller.state.freeMinutes) min").font(.title2.weight(.semibold)).monospacedDigit()
                    }
                    Text(controller.state.isTestMode ? "Der Test sperrt schon nach zwei Minuten. Er gilt nur heute – du kannst sofort auf die freie Alltagsstunde wechseln." : "Eine freie Stunde pro Tag, gemeinsam für deine ausgewählten Konsum-Apps und Websites.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if controller.state.isTestMode {
                        Button("Auf Alltag wechseln · 60 Minuten") { controller.useEverydayMode() }
                            .buttonStyle(GateButtonStyle()).disabled(!controller.isAuthorized)
                    }
                    Text("Von iOS bestätigt: \(controller.state.confirmedMinutes) Minuten heute. Beim Moduswechsel wird dieser Verbrauch nicht gelöscht.")
                        .font(.caption).foregroundStyle(.secondary)
                }.gateCard()
                GateSection(title: "Nutzungsmessung") {
                    MonitoringStatusView(controller: controller, detailed: true)
                }.gateCard()
                GateSection(title: "Berechtigungen") {
                    HStack { Text("Bildschirmzeit"); Spacer(); Text(controller.isAuthorized ? "Erlaubt" : "Fehlt").foregroundStyle(.secondary) }
                    if !controller.isAuthorized {
                        Button("Bildschirmzeit erlauben") { Task { await controller.requestAuthorization() } }
                            .buttonStyle(GateButtonStyle()).disabled(controller.isRequestingAuthorization)
                    }
                    Text(notificationsAllowed == true ? "Mitteilungen erlaubt. Auf iOS 26 öffnest du damit die passende Anfrage."
                         : "Mitteilungen erlauben, damit du von einer gesperrten App zu Gate kommst. Alternativ Gate selbst öffnen.")
                        .font(.caption).foregroundStyle(.secondary)
                    Link("iOS-Einstellungen öffnen", destination: URL(string: UIApplication.openSettingsURLString)!).font(.footnote).underline()
                }.gateCard()
                GateSection(title: "Deine Ablenkungen") {
                    Text(controller.selectionSummary).font(.headline)
                    Text("Nur einzelne Konsum-Apps und Websites markieren. Telefon, WhatsApp, Karten und Lernwerkzeuge unmarkiert lassen. Die freie Stunde zählt für diesen gemeinsamen Pool.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button(controller.state.isSelectionLocked ? "Apps & Websites ergänzen" : "Apps & Websites auswählen") { picker = true }.buttonStyle(GateButtonStyle(prominent: false)).disabled(!controller.isAuthorized)
                    Button(controller.state.monitoringEnabled ? "Auswahl übernehmen" : "Gate aktivieren") {
                        Task { await controller.startGate() }
                    }.buttonStyle(GateButtonStyle()).disabled(controller.isCheckingMonitor || !controller.isAuthorized || (!controller.hasSelection && controller.state.selectionData == nil))
                    Text("Nach dem ersten Aktivieren bleibt die Auswahl fest. Neue Apps und Websites kannst du jederzeit ergänzen. Bereits gespeicherte Einträge bleiben auch dann erhalten, wenn du sie im Apple-Auswahlfenster abwählst.")
                        .font(.caption).foregroundStyle(.secondary)
                    #if DEBUG
                    DisclosureGroup("Entwickleroptionen") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nur zum Prüfen der Sperre: Das gemeinsame Tagesbudget sinkt auf zwei Minuten. Bereits gezählte Nutzung bleibt angerechnet; eine Sperre kann deshalb sofort greifen.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Zwei-Minuten-Test vorbereiten") { confirmTest = true }
                                .font(.subheadline).disabled(!controller.isAuthorized)
                        }.padding(.top, 12)
                    }.font(.footnote)
                    #endif
                }.gateCard()
                GateSection(title: "Homescreen") {
                    NavigationLink { LauncherSettingsView(controller: controller) } label: {
                        HStack { Text("Textliste bearbeiten"); Spacer(); Text("\(controller.state.launcher.count) Einträge").foregroundStyle(.secondary) }
                    }.buttonStyle(.plain)
                    Text("Homescreen gedrückt halten → Bearbeiten → Widget hinzufügen → Gate. Medium zeigt vier Einträge, Gross bis zu acht. App-Icons kannst du danach manuell vom Homescreen entfernen; Apps bleiben in der App-Mediathek.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Das Widget öffnet Links über Gate. Es ersetzt nicht den iOS-Homescreen und hebt keine Sperre auf. App-Links benötigen die jeweilige installierte App.")
                        .font(.caption).foregroundStyle(.secondary)
                }.gateCard()
                GateSection(title: "Dauerhaft geschützte Websites") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Wenn Safari „Website nicht erlaubt“ zeigt", systemImage: "hand.raised")
                            .font(.headline)
                        Text("Das ist Apples Filterseite. Gate kann sie weder gestalten noch von dort automatisch seine Pause öffnen. Schliess den Browser-Tab und öffne die Gate-Pause über dein Widget oder oben unter Heute.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Gate-Pause öffnen") { controller.requestPause() }
                            .buttonStyle(GateButtonStyle(prominent: false))
                    }
                    Divider()
                    Text("Hier stehen Websites, für die es keine Lernfreigabe gibt – auch nicht in der freien Stunde. Nur einzelne Websites markieren. Gespeicherte Einträge lassen sich erweitern, nicht entfernen.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("\(GateShieldPolicy.protectedSelection(from: controller.state).webDomainTokens.count) Websites geschützt").font(.headline)
                    Button("Schutz-Websites ergänzen") { protectedPicker = true }
                        .buttonStyle(GateButtonStyle(prominent: false)).disabled(!controller.isAuthorized)
                    Button("Dauerhaft übernehmen") { controller.saveProtectedWebsites() }
                        .buttonStyle(GateButtonStyle()).disabled(!controller.isAuthorized)
                    Text("Für diese zusätzlich ausgewählten Websites zeigt Gate seinen Hinweis, wenn iOS die Gate-Sperre aufruft. Der automatische Apple-Filter bleibt aktiv und kann Vorrang haben.")
                        .font(.caption).foregroundStyle(.secondary)
                }.gateCard()
                GateSection(title: "Inhalte & Privatsphäre") {
                    Text("Der iOS-Erwachsenenfilter und die Einschränkungen für explizit markierte Apple-Medien bleiben auch während Freigaben gesetzt.")
                        .font(.subheadline)
                    Text("Eine normale iPhone-App kann nicht jeden Inhalt in Snapchat, WhatsApp oder anderen Apps prüfen. Auch das Widerrufen der Berechtigung ist bei Selbstkontrolle möglich. Absolute Inhalts- oder Umgehungssicherheit ist damit nicht gegeben.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Lernstand, Notizen, Auswahl und Nutzungswerte werden lokal gespeichert. Die Bildmotive der Lernwege sind offline enthalten. Externe Quellenfotos werden nur auf Wunsch vom angegebenen Anbieter geladen. Es gibt keine Konten und keine Analyse-Tracker.")
                        .font(.caption).foregroundStyle(.secondary)
                }.gateCard()
                GateSection(title: "Gate · Open Source") {
                    Text("Kostenlos nutzen, verändern und weitergeben. Code und eigene Lerntexte unter MIT; externe Fotos behalten ihre eigenen Nutzungsbedingungen.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Link("Projekt auf GitHub", destination: URL(string: "https://github.com/Van-de-heiden/gate")!).underline()
                    Button("Einführung noch einmal ansehen") { showOnboarding = true }.font(.footnote)
                    Text("Version 0.3 · Produkt-Alpha").font(.caption2).foregroundStyle(.secondary)
                }.gateCard()
            }.padding(24)
        }
        .familyActivityPicker(isPresented: $picker, selection: $controller.selection)
        .familyActivityPicker(isPresented: $protectedPicker, selection: $controller.protectedSelection)
        .sheet(isPresented: $showOnboarding) { GateOnboardingView(controller: controller) }
        .confirmationDialog("Zwei-Minuten-Test aktivieren?", isPresented: $confirmTest, titleVisibility: .visible) {
            Button("Testmodus für heute starten") { Task { await controller.startGate(testMode: true) } }
            Button("Abbrechen", role: .cancel) {}
        } message: { Text("Danach sperrt Gate bereits ab zwei Minuten bestätigter Nutzung. Über „Auf Alltag wechseln“ erhältst du wieder das normale 60-Minuten-Budget.") }
        .task {
            notificationsAllowed = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
        }
    }
}

struct LauncherSettingsView: View {
    @ObservedObject var controller: ScreenTimeController
    @State private var items: [LauncherItem] = []
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section {
                Text("Deine Textliste ist gleichzeitig die Widget-Liste. Gespeicherte Einträge bleiben bestehen. Du kannst sie umsortieren und weitere hinzufügen. App-Namen aus Bildschirmzeit lassen sich aus Datenschutzgründen nicht automatisch in Start-Links umwandeln.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Einträge") {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        if controller.state.launcher.contains(where: { $0.id == item.id }) {
                            HStack { Text(item.title); Spacer(); Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary) }
                            Text(item.url).font(.caption).foregroundStyle(.secondary)
                        } else {
                            TextField("Name", text: $item.title).submitLabel(.done).onSubmit { GateKeyboard.dismiss() }
                            TextField("https://… oder App-Link", text: $item.url)
                                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).font(.caption)
                                .submitLabel(.done).onSubmit { GateKeyboard.dismiss() }
                            Button("Eingabe fertig") { GateKeyboard.dismiss() }.font(.caption).underline()
                        }
                    }.padding(.vertical, 4)
                }
                .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                if items.count < 12 {
                    Button("Eintrag hinzufügen") { items.append(LauncherItem(title: "Neuer Eintrag", url: "https://")) }
                }
            }
            Section {
                Text("Für einen bestimmten Telefonkontakt kann ein tel:-Link verwendet werden. Gate schränkt Telefonate nicht ein, solange die Telefon-App nicht in deiner Sperrauswahl steht.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.gateKeyboardDismissal().navigationTitle("Textliste").navigationBarTitleDisplayMode(.inline).tint(.primary)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sichern") {
                        GateKeyboard.dismiss()
                        controller.saveLauncher(items)
                        if controller.errorMessage == nil { dismiss() }
                    }
                }
            }.onAppear { items = controller.state.launcher }
    }
}

struct GateOnboardingView: View {
    @ObservedObject var controller: ScreenTimeController
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var picker = false
    private let titles = ["Dein Handy.\nDeine Absicht.", "Ein klarer\nRahmen.", "Ein kleiner\nWissensgewinn.", "Weniger auf\ndem Homescreen."]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Eyebrow(text: "Willkommen bei Gate · \(step + 1) / 4")
                    Text(titles[step]).font(.system(.largeTitle, design: .serif))
                    GateProgressLine(value: Double(step + 1) / 4)
                    if step == 0 {
                        Text("Die erste Stunde deiner ausgewählten Konsum-Apps bleibt frei. Danach verdienst du kurze Freigaben durch Lernen und Verstehen. Nach dem Aktivieren kannst du die Auswahl nur noch erweitern.")
                            .font(.title3).lineSpacing(5)
                        Text("Telefon, WhatsApp und wichtige Werkzeuge bleiben ausserhalb deiner Sperrauswahl. Es gibt keine Werbung und kein Konto.")
                            .foregroundStyle(.secondary)
                    } else if step == 1 {
                        Text("Erlaube Bildschirmzeit und wähle einzelne Apps und Websites. Ganze Kategorien sind für diesen Modus nicht vorgesehen.")
                        Button(controller.isAuthorized ? "Bildschirmzeit erlaubt" : "Bildschirmzeit erlauben") {
                            Task { await controller.requestAuthorization() }
                        }.buttonStyle(GateButtonStyle()).disabled(controller.isAuthorized || controller.isRequestingAuthorization)
                        Button("Konsum-Apps auswählen") { picker = true }.buttonStyle(GateButtonStyle(prominent: false)).disabled(!controller.isAuthorized)
                        Text(controller.selectionSummary).font(.footnote).foregroundStyle(.secondary)
                        Text("Der Inhaltsfilter hilft gegen Erwachsenen-Websites und explizit markierte Apple-Medien. Inhalte innerhalb jeder fremden App kann Gate nicht vollständig kontrollieren.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if step == 2 {
                        LessonDiagram(visual: LessonVisual(kind: "flow", title: "Dein Lernrhythmus",
                            labels: ["Verstehen · kurze Lektion", "Abrufen · mindestens 80 % richtig", "Wiederholen · später erneut"], values: nil,
                            caption: "Die Wege wechseln. Wiederholungen und Fehler werden beim nächsten Lernplan berücksichtigt."))
                        Text("5, 10 oder 15 Minuten Zugang. Mehr Konsum bedeutet etwas mehr Lernstoff. Drei Fehlversuche führen für diese App zu einer Pause; andere Apps bleiben unabhängig.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Text("Füge das Gate-Widget zum Homescreen hinzu und entferne ablenkende Icons manuell. Deine wichtigsten Einträge stehen dann als ruhige Textliste bereit.")
                            .font(.title3)
                        Text("Home gedrückt halten → Bearbeiten → Widget hinzufügen → Gate. Telefon und WhatsApp bleiben erreichbar. Gate ersetzt nicht die iOS-App-Mediathek.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let error = controller.errorMessage { Text(error).font(.footnote) }
                    Button(step == 3 ? "Gate starten" : "Weiter") {
                        if step < 3 { step += 1 }
                        else {
                            Task {
                                await controller.startGate()
                                if controller.errorMessage == nil && controller.monitorReady && controller.state.monitoringEnabled {
                                    controller.completeOnboarding(); dismiss()
                                }
                            }
                        }
                    }.buttonStyle(GateButtonStyle()).disabled(step == 3 && controller.isCheckingMonitor)
                    if step == 3 {
                        Button("Zuerst die Lernwege ansehen") { controller.completeOnboarding(); dismiss() }
                            .font(.footnote).frame(maxWidth: .infinity)
                    }
                    if step > 0 { Button("Zurück") { step -= 1 }.font(.footnote).foregroundStyle(.secondary) }
                }.padding(28)
            }.background(GateDesign.paper).toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Später") { controller.completeOnboarding(); dismiss() }.foregroundStyle(.secondary) }
            }
        }.tint(.primary).familyActivityPicker(isPresented: $picker, selection: $controller.selection)
    }
}
