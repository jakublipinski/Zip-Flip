import SwiftUI
import ZipFlipCore

/// Version, where the cards come from, and the two actions that live behind
/// the deck list: Refresh and Forget this sheet. URLs are plain text: watchOS
/// has no browser.
struct AboutView: View {
    @Environment(Library.self) private var library
    @State private var confirmingForget = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                FlipGlyph()
                    .frame(width: 36, height: 36)
                Text("Zip Flip")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Design.teal)
                Text(verbatim: version)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Design.secondary)

                para("Cards come from a Google Sheet shared by link, one tab per deck, column A front, column B back.")
                para("Got it moves a card up the ladder: 1, 2, 4, 8, 16, 32, 64, 128 days. Again sends it back to the bottom.")
                para("Progress stays on this watch. Nothing is sent anywhere.")

                Text(verbatim: "zip-flip.app/support")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Design.teal)

                VStack(spacing: 8) {
                    PillButton(title: "Refresh", look: .grey) {
                        library.refresh(reason: .manual)
                    }
                    .disabled(library.refreshState == .refreshing)
                    PillButton(title: "Forget this sheet", look: .grey) {
                        confirmingForget = true
                    }
                }
                .padding(.top, 6)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        }
        .navigationTitle("About")
        .toolbarForegroundStyle(Design.teal, for: .navigationBar)
        .confirmationDialog("Forget this sheet?", isPresented: $confirmingForget, titleVisibility: .visible) {
            Button("Forget", role: .destructive) { library.forgetSpreadsheet() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The cards leave the watch. Progress is kept in case the sheet comes back.")
        }
    }

    private func para(_ s: LocalizedStringKey) -> some View {
        Text(s)
            .font(.system(size: 12.5))
            .foregroundStyle(Design.body)
            .fixedSize(horizontal: false, vertical: true)
    }
}
