import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var showLog = false
    @State private var showAppPicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: - Balance
                VStack(spacing: 20) {
                    Text(formatBalance(store.balance))
                        .font(.system(size: 64, weight: .regular, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(4)

                    if !store.unlocked {
                        Text("\(formatTime(store.secondsToUnlock)) to first unlock")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color(white: 0.4))
                    } else if store.balance <= 0 && !store.scrolling {
                        Text("Bank empty")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color(white: 0.4))
                    } else {
                        Button(action: store.toggleScrolling) {
                            Text(store.scrolling ? "Stop Scrolling" : "Start Scrolling")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(white: 0.2), lineWidth: 1)
                                )
                        }
                    }
                }

                Spacer()

                // MARK: - Focus Timer
                VStack(spacing: 20) {
                    Text(formatTime(store.focusElapsed))
                        .font(.system(size: 64, weight: .regular, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(4)

                    Button(action: store.toggleFocus) {
                        Text(store.focusRunning ? "Stop" : "Start")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(white: 0.2), lineWidth: 1)
                            )
                    }
                }

                Spacer()

                // MARK: - Bottom buttons
                VStack(spacing: 24) {
                    if store.authorized {
                        Button(action: { showAppPicker = true }) {
                            Text(store.selectedApps.applicationTokens.isEmpty ? "Select Apps to Block" : "Change Blocked Apps")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(Color(white: 0.4))
                        }
                    }

                    Button(action: { showLog = true }) {
                        Text("Show Log")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color(white: 0.4))
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 32)

            // MARK: - Log overlay
            if showLog {
                LogOverlay(sessions: store.log, onClose: { showLog = false })
            }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $store.selectedApps)
        .onChange(of: store.selectedApps) { _ in
            store.saveSelectedApps()
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func formatBalance(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct LogOverlay: View {
    let sessions: [Session]
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                ScrollView {
                    if sessions.isEmpty {
                        Text("No sessions yet")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color(white: 0.53))
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(sessions) { session in
                                HStack {
                                    Text(session.formattedDate)
                                    Spacer()
                                    Text(session.formattedDuration)
                                    Spacer()
                                    Text("+\(session.earnedMinutes)m")
                                }
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(Color(white: 0.53))
                                .padding(.vertical, 12)
                                .overlay(
                                    Rectangle()
                                        .frame(height: 0.5)
                                        .foregroundColor(Color(white: 0.13)),
                                    alignment: .bottom
                                )
                            }
                        }
                    }
                }

                Button(action: onClose) {
                    Text("Close")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(white: 0.2), lineWidth: 1)
                        )
                }
                .padding(.top, 16)
            }
            .padding(24)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.067))
            )
        }
    }
}
