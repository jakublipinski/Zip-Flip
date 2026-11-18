import SwiftUI
import ZipFlipCore

/// One deck: what is waiting, Start and Practice.
struct DeckView: View {
    @Environment(Library.self) private var library
    let deck: Deck

    var body: some View {
        let summary = library.summary(for: deck)
        ScrollView {
            VStack(spacing: 8) {
                if summary.isDone {
                    Text(summary.totalCount == 0 ? "No cards" : "Done for today")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.top, 6)
                    Text(nextDueLine(summary))
                        .font(.system(size: 13))
                        .foregroundStyle(Design.secondary)
                } else {
                    Text(summary.dueCount > 0 ? "\(summary.dueCount) due" : "\(summary.newCount) new")
                        .font(.system(size: 30, weight: .semibold))
                        .padding(.top, 2)
                    Text(detailLine(summary))
                        .font(.system(size: 13))
                        .foregroundStyle(Design.secondary)
                }

                VStack(spacing: 8) {
                    if !summary.isDone {
                        NavigationLink(value: Route.session(deck.gid, .study, UUID())) {
                            PillLabel(title: "Start", look: .teal)
                        }
                        .buttonStyle(.plain)
                    }
                    if summary.totalCount > 0 {
                        NavigationLink(value: Route.session(deck.gid, .practice, UUID())) {
                            PillLabel(title: "Practice", look: summary.isDone ? .teal : .grey)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 6)

                if let date = library.updatedAt {
                    UpdatedLabel(date: date)
                        .padding(.top, 4)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        }
        .navigationTitle(deck.name.isEmpty ? "Cards" : deck.name)
        .toolbarForegroundStyle(Design.teal, for: .navigationBar)
    }

    private func detailLine(_ s: DeckSummary) -> LocalizedStringKey {
        if s.dueCount > 0 && s.newCount > 0 {
            return "\(s.newCount) new · ^[\(s.totalCount) card](inflect: true)"
        }
        return "^[\(s.totalCount) card](inflect: true)"
    }

    private func nextDueLine(_ s: DeckSummary) -> LocalizedStringKey {
        guard let next = s.nextDue else {
            return s.unseenCount > 0 ? "More new cards tomorrow" : "^[\(s.totalCount) card](inflect: true)"
        }
        if next == library.today.adding(days: 1) { return "Next cards due tomorrow" }
        return "Next cards due \(next.start(), format: .dateTime.day().month(.abbreviated))"
    }
}

enum SessionRoute: Hashable {
    case study
    case practice
}
