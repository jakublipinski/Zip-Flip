import SwiftUI
import ZipFlipCore

/// The cards: front, tap to flip, back with Again and Got it, then the done
/// screen. In practice mode nothing is written (README decision 15).
struct SessionView: View {
    @Environment(Library.self) private var library
    let deck: Deck
    let mode: SessionRoute
    /// Back to the deck list.
    let onDecks: () -> Void
    /// A fresh session of the same deck.
    let onContinue: () -> Void
    /// Debug screenshots only: start with the back showing.
    var debugShowBack = false

    @State private var cards: [Card] = []
    @State private var session = Session(cards: [])
    @State private var showingBack = false
    @State private var missed = Set<String>()
    @State private var started = false

    var body: some View {
        Group {
            if !started {
                Color.clear
            } else if session.isFinished {
                DoneView(deck: deck, mode: mode, reviewed: cards.count, gotIt: cards.count - missed.count,
                         onDecks: onDecks, onContinue: onContinue, onPractice: restartAsPractice)
            } else if let card = session.current {
                cardScreen(card)
            }
        }
        .navigationTitle(session.isFinished ? (deck.name.isEmpty ? "Cards" : deck.name) : "\(min(session.completed + 1, cards.count)) of \(cards.count)")
        .toolbarForegroundStyle(session.isFinished ? Design.teal : Design.secondary, for: .navigationBar)
        .onAppear(perform: start)
    }

    private func start() {
        guard !started else { return }
        switch mode {
        case .study: cards = library.plan(for: deck).cards
        case .practice: cards = SessionPlanner.practice(deck: deck)
        }
        session = Session(cards: cards)
        missed = []
        showingBack = debugShowBack
        started = true
    }

    private func restartAsPractice() {
        cards = SessionPlanner.practice(deck: deck)
        session = Session(cards: cards)
        missed = []
        showingBack = false
    }

    @ViewBuilder
    private func cardScreen(_ card: Card) -> some View {
        if showingBack {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    Text(card.front)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Design.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(card.back)
                        .font(.system(size: 23, weight: .semibold))
                        .lineLimit(5)
                        .minimumScaleFactor(0.4)
                    Spacer(minLength: 0)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)
                HStack(spacing: 8) {
                    PillButton(title: "Again", look: .grey) { answer(.again, card) }
                    PillButton(title: "Got it", look: .teal) { answer(.gotIt, card) }
                }
                .padding(.bottom, 2)
            }
        } else {
            Button {
                showingBack = true
            } label: {
                VStack(spacing: 10) {
                    Spacer(minLength: 0)
                    Text(card.front)
                        .font(.system(size: 24, weight: .semibold))
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Text("Tap to flip")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Design.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(card.front). Tap to flip"))
        }
    }

    private func answer(_ answer: Answer, _ card: Card) {
        library.tap()
        if mode == .study {
            library.record(answer, for: card, in: deck)
        }
        if answer == .again { missed.insert(card.key) }
        session.answer(answer)
        showingBack = false
    }
}

struct DoneView: View {
    @Environment(Library.self) private var library
    let deck: Deck
    let mode: SessionRoute
    let reviewed: Int
    let gotIt: Int
    let onDecks: () -> Void
    let onContinue: () -> Void
    let onPractice: () -> Void

    var body: some View {
        let summary = library.summary(for: deck)
        ScrollView {
            VStack(spacing: 8) {
                Text(mode == .study ? "Done for today" : "Practice done")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.top, 6)
                Text("\(reviewed) reviewed · \(gotIt) got it")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Design.secondary)
                if mode == .study {
                    Text(summary.isDone ? nextLine(summary) : "More cards are waiting")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Design.secondary)
                }
                VStack(spacing: 8) {
                    if mode == .study, !summary.isDone {
                        PillButton(title: "Continue", look: .teal, action: onContinue)
                    }
                    PillButton(title: "Decks", look: .grey, action: onDecks)
                    PillButton(title: mode == .study ? "Practice" : "Practice again",
                               look: mode == .study && !summary.isDone ? .grey : .teal, action: onPractice)
                }
                .padding(.top, 6)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        }
    }

    private func nextLine(_ s: DeckSummary) -> LocalizedStringKey {
        guard let next = s.nextDue else {
            return s.unseenCount > 0 ? "More new cards tomorrow" : "Every card is learned"
        }
        if next == library.today.adding(days: 1) { return "Next cards due tomorrow" }
        return "Next cards due \(next.start(), format: .dateTime.day().month(.abbreviated))"
    }
}
