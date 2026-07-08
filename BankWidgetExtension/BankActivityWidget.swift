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
            Text(state.startDate, style: .timer)
        case .scrolling:
            if let endDate = state.endDate {
                Text(timerInterval: state.startDate...endDate, countsDown: true)
            }
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
