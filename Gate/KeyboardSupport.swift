import SwiftUI
import UIKit

@MainActor
enum GateKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct KeyboardSupport: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { GateKeyboard.dismiss() }.fontWeight(.semibold)
                }
            }
            .onDisappear { GateKeyboard.dismiss() }
    }
}
extension View {
    func gateKeyboardDismissal() -> some View { modifier(KeyboardSupport()) }
}
