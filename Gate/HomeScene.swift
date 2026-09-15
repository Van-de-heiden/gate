import SwiftUI

/// A single fixed landscape behind the scrolling home content. The background
/// extends beneath the system bars; the controls retain the native safe areas.
struct GateHomeSurface<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) { content }
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 32)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { GateLandscape().ignoresSafeArea() }
    }
}

struct GateHomeHeader: View {
    @Environment(\.gateDayPhase) private var phase
    var pause: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Text("gate").font(.system(.title2, design: .rounded)).tracking(-1)
                Spacer()
                Button(action: pause) {
                    Label("Pause", systemImage: "pause.circle")
                        .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                }.buttonStyle(.plain).accessibilityLabel("Gate-Pause öffnen")
            }
            Text(phase.greeting).font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

struct GateHomeBudget: View {
    let remainingMinutes: Int
    let totalMinutes: Int
    var status: String? = nil
    var details: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Heute frei").font(.subheadline.weight(.medium))
                Spacer()
                Button(action: details) {
                    Image(systemName: "info.circle").font(.body)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tagesbudget und Messstatus anzeigen")
            }.frame(maxWidth: 280)
            AllowanceGauge(remainingMinutes: remainingMinutes, totalMinutes: totalMinutes)
            if let status {
                Text(status).font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center).padding(.top, 8)
            }
        }.frame(maxWidth: .infinity)
    }
}

// The previews share the shipping landscape, safe-area layout, header and dial.
// No preview changes Screen Time authorization or writes to the app group.
#if DEBUG
struct GateHomeScenePreview: View {
    var phase: GateDayPhase = .day
    var remaining = 21
    var body: some View {
        TabView {
            NavigationStack {
                GateHomeSurface {
                    GateHomeHeader(pause: {})
                    GateHomeBudget(remainingMinutes: remaining, totalMinutes: 30, details: {})
                    Button("Etwas lernen", action: {})
                        .buttonStyle(GateButtonStyle()).frame(maxWidth: 280)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Das Wesentliche").font(.subheadline.weight(.semibold))
                        ForEach(["WhatsApp", "Lesen", "Kalender", "Karten"], id: \.self) { title in
                            HStack {
                                Text(title).font(.title3.weight(.medium))
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                            }.frame(minHeight: 55)
                            Divider()
                        }
                    }
                }.toolbar(.hidden, for: .navigationBar)
            }.tabItem { Label("Heute", systemImage: "house") }
            Text("Lernen").tabItem { Label("Lernen", systemImage: "books.vertical") }
            Text("Bilanz").tabItem { Label("Bilanz", systemImage: "chart.bar.xaxis") }
            Text("Mehr").tabItem { Label("Mehr", systemImage: "slider.horizontal.3") }
        }
        .environment(\.gateDayPhase, phase)
        .preferredColorScheme(phase.isDark ? .dark : .light)
        .fontDesign(.rounded).tint(GateDesign.accent)
    }
}

#Preview("Tag · frei in der Landschaft") { GateHomeScenePreview() }
#Preview("Nacht · Budget aufgebraucht") { GateHomeScenePreview(phase: .night, remaining: 0) }
#endif
