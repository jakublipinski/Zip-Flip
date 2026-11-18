import SwiftUI
import ZipFlipCore

/// Shown when the last refresh failed. The cached cards stay usable
/// (README decision 6), and the screen says how old they are.
/// The three problem screens, as a value a route can carry.
enum ProblemKind: Hashable {
    case notReadable
    case offline
    case other

    init(_ failure: FetchFailure) {
        switch failure {
        case .notReadable: self = .notReadable
        case .offline: self = .offline
        case .other: self = .other
        }
    }
}

struct ProblemView: View {
    @Environment(Library.self) private var library
    let kind: ProblemKind

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(Design.secondary)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
                Text(headline)
                    .font(.system(size: 16.5, weight: .semibold))
                Text(advice)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Design.body)
                if let date = library.updatedAt {
                    Text("Showing cards saved \(date, format: .dateTime.day().month(.abbreviated))")
                        .font(.system(size: 11))
                        .foregroundStyle(Design.secondary)
                }
                PillButton(title: "Try again", look: .grey) {
                    library.refresh(reason: .manual)
                }
                .padding(.top, 6)
                .disabled(library.refreshState == .refreshing)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        }
        .navigationTitle(library.title ?? "Zip Flip")
        .toolbarForegroundStyle(Design.teal, for: .navigationBar)
    }

    private var icon: String {
        switch kind {
        case .notReadable: return "lock.doc"
        case .offline: return "wifi.slash"
        case .other: return "exclamationmark.triangle"
        }
    }

    private var headline: LocalizedStringKey {
        switch kind {
        case .notReadable: return "Can't read the sheet"
        case .offline: return "No connection"
        case .other: return "Couldn't refresh"
        }
    }

    private var advice: LocalizedStringKey {
        switch kind {
        case .notReadable: return "Make sure it is shared as Anyone with the link, then try again."
        case .offline: return "The watch needs Wi‑Fi or cellular to fetch new cards."
        case .other: return "Google did not answer. Try again in a moment."
        }
    }
}
