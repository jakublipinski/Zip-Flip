import SwiftUI

@main
struct ZipFlipApp: App {
    @State private var library = Library()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .tint(Design.teal)
                // Universal Links (README decision 3): https://zip-flip.app/s/?id=<id>
                .onOpenURL { url in library.open(url) }
        }
    }
}
