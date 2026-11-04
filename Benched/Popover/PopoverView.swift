import SwiftUI

struct PopoverView: View {
    let store: UsageStore
    // The ones that need AppKit: quitting and the open panel
    var chooseClaude: () -> Void
    var quit: () -> Void

    var body: some View {
        PopoverContent(
            state: store.popoverState,
            isRefreshing: store.isRefreshing,
            menu: FooterMenuModel(
                claudePath: store.claudePath,
                claudeVersion: store.claudeVersion,
                backgroundRefreshMinutes: store.backgroundRefreshMinutes,
                menuBarMeter: store.menuBarMeter,
                hasChosenClaude: store.chosenClaudePath != nil,
            ),
            actions: PopoverActions(
                refresh: { store.refresh() },
                setBackgroundRefresh: { store.setBackgroundRefresh(minutes: $0) },
                setMenuBarMeter: { store.setMenuBarMeter($0) },
                chooseClaude: chooseClaude,
                useDetectedClaude: { store.setChosenClaude(path: nil) },
                quit: quit,
            ),
        )
    }
}

struct PopoverContent: View {
    var state: PopoverState
    var isRefreshing: Bool
    // Fixed in previews and snapshot tests, so the countdowns don't move
    var now: Date?
    var menu = FooterMenuModel()
    var actions = PopoverActions()

    var body: some View {
        if let now {
            content(now: now)
        } else {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                content(now: context.date)
            }
        }
    }

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            switch state {
            case .loading:
                Text("Checking usage…")
                    .foregroundStyle(.secondary)
            case let .usage(snapshot, problem, _):
                if let problem {
                    ProblemBanner(problem: problem)
                        .padding(.bottom, 12)
                }
                UsageView(snapshot: snapshot, now: now)
                    .opacity(freshness(now: now) == .cached ? 0.5 : 1)
            case let .problem(problem):
                ProblemView(problem: problem)
            }
            Divider()
                .padding(.vertical, 10)
            Footer(
                updatedAt: snapshot?.observedAt,
                isStale: freshness(now: now) == .stale,
                isRefreshing: isRefreshing,
                now: now,
                menu: menu,
                actions: actions,
            )
        }
        // Inside the padding, so a UI test screenshot of it stays clear of the
        // popover's rounded corners and arrow, where the screen behind shows
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("popoverContent")
        .padding(16)
        .frame(width: 300)
    }

    private var snapshot: UsageSnapshot? {
        if case let .usage(snapshot, _, _) = state { snapshot } else { nil }
    }

    private func freshness(now: Date) -> Freshness? {
        guard case let .usage(snapshot, problem, isFromCache) = state else { return nil }
        return Freshness.make(observedAt: snapshot.observedAt, problem: problem, isFromCache: isFromCache, now: now)
    }
}

struct UsageView: View {
    let snapshot: UsageSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if snapshot.meters.isEmpty {
                Text("No limits reported for this plan")
                    .foregroundStyle(.secondary)
            }
            // By index, because nothing stops the server sending two rows of the same kind
            ForEach(snapshot.meters.indices, id: \.self) { index in
                MeterRow(meter: snapshot.meters[index], now: now)
            }
            if snapshot.droppedRows > 0 {
                Label("Some rows couldn't be read", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
    #Preview("Usage") {
        PopoverContent(state: .usage(PreviewData.normal, problem: nil), isRefreshing: false, now: PreviewData.now)
    }

    #Preview("Warning and critical") {
        PopoverContent(state: .usage(PreviewData.warningAndCritical, problem: nil), isRefreshing: false, now: PreviewData.now)
    }

    #Preview("From cache") {
        PopoverContent(state: .usage(PreviewData.normal, isFromCache: true), isRefreshing: true, now: PreviewData.now)
    }

    #Preview("Loading") {
        PopoverContent(state: .loading, isRefreshing: true, now: PreviewData.now)
    }
#endif
