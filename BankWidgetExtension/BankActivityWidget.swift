import ActivityKit
import SwiftUI
import WidgetKit

struct BankActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BankActivityAttributes.self) { context in
            BankLockScreenView(state: context.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.kind == .focus ? "focus" : "bank")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BankTimerText(state: context.state)
                        .font(.system(size: 20, design: .monospaced))
                }
            } compactLeading: {
                Image(systemName: context.state.kind == .focus ? "timer" : "hourglass")
            } compactTrailing: {
                BankTimerText(state: context.state)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 44)
            } minimal: {
                Image(systemName: context.state.kind == .focus ? "timer" : "hourglass")
            }
        }
    }
}

private struct BankTimerText: View {
    let state: BankActivityAttributes.ContentState

    var body: some View {
        switch state.kind {
        case .focus:
            // Focus time really is continuous wall-clock time, so a count-up is accurate.
            Text(state.startDate, style: .timer)
        case .scrolling:
            // Spending now drains based on actual app usage, which this widget has no way
            // to observe live (only "session active" / "session ended" ever gets reported)
            // — a wall-clock count-up here would look like a countdown tied to balance but
            // keep climbing even while the blocked app is closed, which is actively
            // misleading. Show a plain status instead of a number implying precision we
            // don't have.
            Image(systemName: "hourglass")
        }
    }
}

private struct BankLockScreenView: View {
    let state: BankActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.kind == .focus ? "focusing" : "spending balance")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.gray)
                .tracking(2)
            BankTimerText(state: state)
                .font(.system(size: 34, weight: .regular, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(4)
        }
        .padding()
    }
}
