import SwiftUI
import ZipFlipCore

/// Every screen the stack can show. One path, owned by `RootView`, so any
/// screen can pop back to the deck list.
enum Route: Hashable {
    case deck(String)
    /// The UUID makes each session a fresh push, so Continue starts over.
    case session(String, SessionRoute, UUID)
    case problem(ProblemKind)
    case about
}

/// First run until a link has been opened, then the deck list.
struct RootView: View {
    @Environment(Library.self) private var library
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { library.refreshIfStale() }
        }
        .onChange(of: library.spreadsheetID) {
            path.removeAll()
        }
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
        if let screen = DebugScreen.requested, library.hasSpreadsheet {
            DebugScreenView(screen: screen)
        } else if library.hasSpreadsheet {
            DecksView()
        } else {
            FirstRunView()
        }
        #else
        if library.hasSpreadsheet {
            DecksView()
        } else {
            FirstRunView()
        }
        #endif
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .deck(let gid):
            if let deck = library.deck(gid) {
                DeckView(deck: deck)
            } else {
                DeckGoneView()
            }
        case .session(let gid, let mode, _):
            if let deck = library.deck(gid) {
                SessionView(deck: deck, mode: mode,
                            onDecks: { path.removeAll() },
                            onContinue: { path = [.deck(gid), .session(gid, .study, UUID())] })
            } else {
                DeckGoneView()
            }
        case .problem(let kind):
            ProblemView(kind: kind)
        case .about:
            AboutView()
        }
    }
}

/// The tab vanished from the sheet between two refreshes.
struct DeckGoneView: View {
    var body: some View {
        Text("This deck is no longer in the sheet.")
            .font(.system(size: 13))
            .foregroundStyle(Design.secondary)
            .multilineTextAlignment(.center)
            .padding()
    }
}

struct FirstRunView: View {
    @Environment(Library.self) private var library

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                FlipGlyph()
                    .frame(width: 44, height: 44)
                    .padding(.top, 4)
                Text("No cards yet")
                    .font(.system(size: 18, weight: .semibold))
                Text("Open a Zip Flip link on this watch, for example from Messages.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Design.body)
                Text("Make a link at zip-flip.app")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Design.secondary)
                #if DEBUG
                // Debug builds only: the project's test sheet, without a link.
                PillButton(title: "Use the test sheet", look: .grey) {
                    library.use(spreadsheetID: "1gqG1A6OSHIcWcxnPhfF7ouWymoo5u67F6eJLOPTXHSI")
                }
                .padding(.top, 6)
                #endif
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
        }
        .navigationTitle("Zip Flip")
        .toolbarForegroundStyle(Design.teal, for: .navigationBar)
    }
}
