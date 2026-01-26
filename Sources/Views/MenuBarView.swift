import SwiftUI

/// The main view displayed when the menu bar icon is clicked.
struct MenuBarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Commander")
                .font(.headline)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 200)
    }
}

#Preview {
    MenuBarView()
}
