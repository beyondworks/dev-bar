import SwiftUI
import AppKit

struct AppPickerView: View {
    @ObservedObject var store: BarStore
    @Binding var isPresented: Bool

    @State private var apps: [NSRunningApplication] = []
    @State private var selectedAppPID: pid_t?
    @State private var windowTitles: [String] = []
    @State private var search: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("창 추가").font(.headline)
            TextField("앱 검색", text: $search)
                .textFieldStyle(.roundedBorder)

            HStack(alignment: .top, spacing: 8) {
                appsList
                Divider()
                windowsList
            }
        }
        .padding(12)
        .frame(width: 520, height: 320)
        .onAppear { reloadApps() }
    }

    private var appsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(visibleApps, id: \.processIdentifier) { app in
                    Button(action: { selectApp(app) }) {
                        HStack(spacing: 6) {
                            if let icon = app.icon {
                                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                            }
                            Text(app.localizedName ?? "Unknown").font(.system(size: 12))
                            Spacer()
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedAppPID == app.processIdentifier ? Color.accentColor.opacity(0.25) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 220)
    }

    private var windowsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("창 목록").font(.subheadline).foregroundColor(.secondary)
            if selectedAppPID == nil {
                Text("앱을 선택하세요").font(.caption).foregroundColor(.secondary)
            } else if availableWindowTitles.isEmpty {
                Text("추가 가능한 창이 없습니다. (모두 등록되었거나 Accessibility 권한이 필요)")
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(availableWindowTitles, id: \.self) { title in
                            Button(action: { add(title: title) }) {
                                HStack {
                                    Text(title).font(.system(size: 11)).lineLimit(2)
                                    Spacer()
                                    Image(systemName: "plus")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visibleApps: [NSRunningApplication] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return apps.filter { app in
            if !q.isEmpty, !(app.localizedName ?? "").lowercased().contains(q) { return false }
            // hide app entirely if every one of its windows is already added
            let titles = WindowManager.listWindowTitles(pid: app.processIdentifier)
            if titles.isEmpty { return true } // keep visible — picker will explain
            return titles.contains { !isAlreadyAdded(pid: app.processIdentifier, title: $0) }
        }
    }

    private var availableWindowTitles: [String] {
        guard let pid = selectedAppPID else { return [] }
        return windowTitles.filter { !isAlreadyAdded(pid: pid, title: $0) }
    }

    private func isAlreadyAdded(pid: pid_t, title: String) -> Bool {
        store.slots.contains { $0.pid == pid && $0.windowTitle == title }
    }

    private func reloadApps() {
        apps = AppMonitor.shared.runningAppsWithUI()
    }

    private func selectApp(_ app: NSRunningApplication) {
        selectedAppPID = app.processIdentifier
        windowTitles = WindowManager.listWindowTitles(pid: app.processIdentifier)
    }

    private func add(title: String) {
        guard let pid = selectedAppPID else { return }
        let app = NSRunningApplication(processIdentifier: pid)
        let windowID = WindowManager.cgWindowID(pid: pid, windowTitle: title)
        let slot = BarSlot(
            label: title,
            pid: pid,
            bundleIdentifier: app?.bundleIdentifier,
            appName: app?.localizedName ?? "App",
            windowTitle: title,
            cgWindowID: windowID
        )
        store.addSlot(slot)
        isPresented = false
    }
}
