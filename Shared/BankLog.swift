import os

// Unified-logging channels shared by the app and its extensions. Extensions run in their own
// processes, so their output never reaches Xcode's console — view it in Console.app on a Mac
// with the iPhone connected, filtered to subsystem "com.anushriadhia.bank".
enum BankLog {
    static let monitoring = Logger(subsystem: "com.anushriadhia.bank", category: "monitoring")
}
