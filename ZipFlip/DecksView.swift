import SwiftUI
import ZipFlipCore

/// The home screen: one row per deck with what is waiting, the problem row
/// when the last refresh failed, and the About entry at the end.
struct DecksView: View {
    @Environment(Library.self) private var library

    var body: some View {
        List {
            if case .failed(let failure, _) = library.refreshState {
                NavigationLink(value: Route.problem(ProblemKind(failure))) {
                    Label {
                        Text(failure.isNotReadable ? "Can't read the sheet" : "Couldn't refresh")
                            .font(.system(size: 13, weight: .semibold))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                    }
                }
            }

            if library.decks.isEmpty && library.refreshState == .refreshing {
                HStack {
                    ProgressView()
                    Text("Loading…")
                        .font(.system(size: 13))
                        .foregroundStyle(Design.secondary)
                }
            } else if library.decks.isEmpty, library.refreshState == .idle {
                Text("The sheet has no tabs with cards.")
                    .font(.system(size: 13))
                    .foregroundStyle(Design.secondary)
            }

            ForEach(library.decks, id: \.gid) { deck in
                NavigationLink(value: Route.deck(deck.gid)) {
                    DeckRow(deck: deck, summary: library.summary(for: deck))
                }
            }

            Section {
                NavigationLink(value: Route.about) {
                    Label("About", systemImage: "info.circle")
                        .font(.system(size: 13))
                }
            } footer: {
                if let date = library.updatedAt {
                    UpdatedLabel(date: date)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(library.title ?? "Zip Flip")
        .toolbarForegroundStyle(Design.teal, for: .navigationBar)
    }
}

struct DeckRow: View {
    let deck: Deck
    let summary: DeckSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(deck.name.isEmpty ? "Cards" : deck.name)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if summary.isDone {
                Text(summary.totalCount == 0 ? "No cards" : "Done for today")
                    .font(.system(size: 11.5))
                    .foregroundStyle(summary.totalCount == 0 ? Design.secondary : Design.teal)
            } else {
                Text(Counts.dueAndNew(summary))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Design.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// "Updated 2 hr. ago", from the time of the last successful download.
struct UpdatedLabel: View {
    let date: Date

    var body: some View {
        Text("Updated \(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))")
            .font(.system(size: 11))
            .foregroundStyle(Design.secondary)
            .multilineTextAlignment(.center)
    }
}

/// The short count lines from the boards: "12 due · 3 new", "4 due", "3 new".
enum Counts {
    static func dueAndNew(_ s: DeckSummary) -> LocalizedStringKey {
        switch (s.dueCount > 0, s.newCount > 0) {
        case (true, true): return "\(s.dueCount) due · \(s.newCount) new"
        case (true, false): return "\(s.dueCount) due"
        case (false, true): return "\(s.newCount) new"
        case (false, false): return "Done for today"
        }
    }
}

extension FetchFailure {
    var isNotReadable: Bool {
        if case .notReadable = self { return true }
        return false
    }
}
