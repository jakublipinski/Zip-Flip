import SwiftUI

/// Placeholder for step 2 of the plan: proves the app builds, signs,
/// installs and reads its own version. Replaced by the real screens in step 5.
struct ContentView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            FlipGlyph()
                .frame(width: 72, height: 72)
            Text("Zip Flip")
                .font(.title2.weight(.semibold))
            Text(version)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .tint(Design.teal)
    }
}

#Preview {
    ContentView()
}
