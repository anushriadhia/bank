import SwiftUI
import FamilyControls

@main
struct BankApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onAppear {
                    store.requestAuthorization()
                }
        }
    }
}
