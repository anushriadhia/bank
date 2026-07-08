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

                }
                .padding(.top, 60)

                Spacer()

                // MARK: - Focus Timer
                VStack(spacing: 20) {
                    // MARK: - Activity Picker
                    Menu {
                        Picker("", selection: Binding(
                            get: { store.selectedActivity ?? "" },
                            set: { newValue in
                                if newValue == "__new__" {
                                    showAddActivity = true
                                } else {
                                    store.selectActivity(newValue.isEmpty ? nil : newValue)
                                }
                            }
                        )) {
                            Text("Select activity").tag("")
                            ForEach(store.activities, id: \.self) { activity in
                                Text(activity).tag(activity)
                            }
                            Divider()
                            Text("+ New Activity").tag("__new__")
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Activity")
                                .foregroundColor(Color(white: 0.45))
                                .tracking(2)

                            Text(store.selectedActivity ?? "Select activity")
                                .foregroundColor(Color(white: 0.7))

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.45))
                        }
                        .font(.system(size: 14, design: .monospaced))
                    }
                    .id(store.selectedActivity ?? "")

                    Text(formatTime(store.focusElapsed))
                        .font(.system(size: 64, weight: .regular, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(4)

                    Button(store.focusRunning ? "Stop" : "Start", action: store.toggleFocus)
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .font(.system(size: 16, design: .monospaced))
                }

                Spacer()

                // MARK: - Bottom buttons
                VStack(spacing: 24) {
                    if store.authorized {
                        Button(store.selectedApps.applicationTokens.isEmpty ? "Select Apps to Block" : "Change Blocked Apps") {
                            showAppPicker = true
                        }
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                    }

                    Button(action: { showLog = true }) {
                        VStack(spacing: 6) {
                            Text("Show Log")
                                .font(.system(size: 14, design: .monospaced))
                            Image(systemName: "chevron.compact.down")
                                .font(.system(size: 18))
                        }
                        .foregroundColor(Color(white: 0.4))
                    }
                }
                .padding(.bottom, 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.height < -40 {
                                showLog = true
                            }
                        }
                )
            }
            .padding(.horizontal, 32)
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $store.selectedApps)
        .onChange(of: store.selectedApps) { _ in
            store.saveSelectedApps()
        }
        .sheet(isPresented: $showLog) {
            LogSheet(
                sessions: store.log,
                activities: store.activities,
                onUpdateActivity: { id, activity in store.updateSessionActivity(sessionId: id, activity: activity) },
                onAddActivity: { name in store.addActivity(name) }
            )
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

struct LogSheet: View {
    let sessions: [Session]
    let activities: [String]
    let onUpdateActivity: (UUID, String?) -> Void
    let onAddActivity: (String) -> Void

    @State private var showAddActivityForSession: UUID? = nil
    @State private var newActivityName = ""

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    Text("No sessions yet")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color(white: 0.53))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
                            GridRow {
                                Text("date / time")
                                Text("duration")
                                Text("activity")
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(white: 0.35))
                            .padding(.vertical, 8)
                            .gridCellAnchor(.leading)

                            Divider().gridCellColumns(3)

                            ForEach(sessions) { session in
                                GridRow {
                                    Text(session.formattedDateTime)
                                    Text(session.formattedDuration)
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
                                    .font(.system(size: 14, design: .monospaced))
                                    .tint(session.activity == nil ? Color(white: 0.35) : Color(white: 0.53))
                                }
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(Color(white: 0.53))
                                .padding(.vertical, 12)
                                .gridCellAnchor(.leading)

                                Divider().gridCellColumns(3)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
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
    }
}
