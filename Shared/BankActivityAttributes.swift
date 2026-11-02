import ActivityKit
import Foundation

struct BankActivityAttributes: ActivityAttributes {
    enum SessionKind: String, Codable, Hashable {
        case focus
        case scrolling
    }

    struct ContentState: Codable, Hashable {
        var kind: SessionKind
        var startDate: Date   // count-up anchor for both kinds — neither has a known end:
                               // spending now drains based on actual app usage (tracked by
                               // DeviceActivityMonitorExtension), not a fixed wall-clock deadline.
    }
}
