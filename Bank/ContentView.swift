import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var showLog = false
    @State private var showAppPicker = false
    @State private var showAddActivity = false
    @State private var newActivityName = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Bank Balance
                VStack(spacing: 12) {
                    Text("bank")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(white: 0.35))
                        .tracking(2)

                    Text(formatSigned(store.bankDisplay))
                        .font(.system(size: 34, weight: .regular, design: .monospaced))
                        .foregroundColor(store.bankDisplay < 0 ? Color(white: 0.38) : Color(white: 0.55))
                        .tracking(4)

                    if store.unlocked {
                        if store.balance <= 0 && !store.scrolling {
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
                }
                .padding(.top, 60)

                Spacer()

                // MARK: - Focus Timer
                VStack(spacing: 20) {
                    // MARK: - Activity Picker
                    HStack(spacing: 10) {
                        Text("Activity")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(white: 0.35))
                            .tracking(2)

                        Picker("", selection: Binding(
                            get: { store.selectedActivity ?? "" },
                            set: { store.selectActivity($0.isEmpty ? nil : $0) }
                        )) {
                            Text("None").tag("")
                            ForEach(store.activities, id: \.self) { activity in
                                Text(activity).tag(activity)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 14, design: .monospaced))

                        Button(action: { showAddActivity = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.35))
                        }
                    }

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
                LogOverlay(
                    sessions: store.log,
                    activities: store.activities,
                    onClose: { showLog = false },
                    onUpdateActivity: { id, activity in store.updateSessionActivity(sessionId: id, activity: activity) },
                    onAddActivity: { name in store.addActivity(name) }
                )
            }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $store.selectedApps)
        .onChange(of: store.selectedApps) { _ in
            store.saveSelectedApps()
        }
        .alert("New Activity", isPresented: $showAddActivity) {
            TextField("Activity name", text: $newActivityName)
            Button("Add") {
                store.addActivity(newActivityName)
                newActivityName = ""
            }
            Button("Cancel", role: .cancel) {
                newActivityName = ""
            }
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func formatSigned(_ totalSeconds: Int) -> String {
        let abs = Swift.abs(totalSeconds)
        let m = abs / 60
        let s = abs % 60
        let base = String(format: "%02d:%02d", m, s)
        return totalSeconds < 0 ? "-\(base)" : base
    }
}

struct LogOverlay: View {
    let sessions: [Session]
    let activities: [String]
    let onClose: () -> Void
    let onUpdateActivity: (UUID, String?) -> Void
    let onAddActivity: (String) -> Void

    @State private var showAddActivityForSession: UUID? = nil
    @State private var newActivityName = ""

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
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(session.formattedDate)
                                        Spacer()
                                        Text(session.formattedDuration)
                                    }
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(Color(white: 0.53))

                                    Picker("", selection: Binding(
                                        get: { session.activity ?? "" },
                                        set: { newValue in
                                            if newValue == "__new__" {
                                                showAddActivityForSession = session.id
                                            } else {
                                                onUpdateActivity(session.id, newValue.isEmpty ? nil : newValue)
                                            }
                                        }
                                    )) {
                                        Text("—").tag("")
                                        ForEach(activities, id: \.self) { activity in
                                            Text(activity).tag(activity)
                                        }
                                        Divider()
                                        Text("+ New Activity").tag("__new__")
                                    }
                                    .pickerStyle(.menu)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(white: 0.4))
                                }
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
                .alert("New Activity", isPresented: Binding(
                    get: { showAddActivityForSession != nil },
                    set: { if !$0 { showAddActivityForSession = nil } }
                )) {
                    TextField("Activity name", text: $newActivityName)
                    Button("Add") {
                        if let sessionId = showAddActivityForSession {
                            onAddActivity(newActivityName)
                            onUpdateActivity(sessionId, newActivityName.trimmingCharacters(in: .whitespaces))
                        }
                        newActivityName = ""
                        showAddActivityForSession = nil
                    }
                    Button("Cancel", role: .cancel) {
                        newActivityName = ""
                        showAddActivityForSession = nil
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
