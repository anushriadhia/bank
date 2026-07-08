import ActivityKit
import Foundation

struct BankActivityAttributes: ActivityAttributes {
    enum SessionKind: String, Codable, Hashable {
        case focus
        case scrolling
    }

    struct ContentState: Codable, Hashable {
        var kind: SessionKind
        var startDate: Date   // focus: count-up anchor. scrolling: countdown range start.
        var endDate: Date?    // scrolling only — fixed countdown end; nil for focus.
    }
}
