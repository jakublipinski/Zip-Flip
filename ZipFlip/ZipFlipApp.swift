import SwiftUI

@main
struct ZipFlipApp: App {
    @WKApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var library = Library()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .tint(Design.teal)
                // Universal Links (README decision 3): https://zip-flip.app/s/?id=<id>.
                // The delegate is the route watchOS uses (see LinkInbox); the two
                // SwiftUI routes stay in case a later system prefers them. The same
                // link arriving twice is harmless.
                .onAppear {
                    LinkInbox.shared.attach { url, route in library.open(url, via: route) }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { library.open(url, via: "activity") }
                }
                .onOpenURL { url in library.open(url, via: "onOpenURL") }
        }
    }
}
