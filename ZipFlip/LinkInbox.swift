import Foundation
import WatchKit

/// Where a Universal Link enters the app.
///
/// watchOS hands a tapped link to the application delegate as a browsing-web
/// activity (Apple, "Supporting universal links in your app"). SwiftUI's
/// `onOpenURL` alone did not receive it on a Series 12 with watchOS 27: the
/// app opened and stayed on the first-run screen (2026-11-18). The delegate
/// can be called before the first view exists, so links wait here until the
/// library is attached.
@MainActor
final class LinkInbox {
    static let shared = LinkInbox()

    private var waiting: [(url: URL, route: String)] = []
    private var deliver: ((URL, String) -> Void)?

    /// `route` names the entry point, for the Debug link line only.
    func receive(_ url: URL, via route: String) {
        if let deliver {
            deliver(url, route)
        } else {
            waiting.append((url, route))
        }
    }

    func attach(_ deliver: @escaping (URL, String) -> Void) {
        self.deliver = deliver
        let queued = waiting
        waiting = []
        for link in queued { deliver(link.url, link.route) }
    }
}

final class AppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            #if DEBUG
            DebugLinkLog.shared.record("delegate: activity \(userActivity.activityType) without a web address")
            #endif
            return
        }
        LinkInbox.shared.receive(url, via: "delegate")
    }
}
