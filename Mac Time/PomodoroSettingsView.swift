import Combine
import AppKit
import SwiftUI

struct PomodoroSettingsView: View {
    @EnvironmentObject private var appContext: AppContext
    @ObservedObject var settingsStore: PomodoroSettingsStore

    @State private var tapCount: Int = 0
    @State private var isDevMode: Bool = false

    init(settingsStore: PomodoroSettingsStore) {
        self.settingsStore = settingsStore
    }

    var body: some View {
        SettingsPane(title: "") {
            SettingsSection {
                SettingsToggleRow(
                    title: L10n.Pomodoro.enabled,
                    description: L10n.Pomodoro.enabledDescription,
                    isOn: draftBinding(\.isEnabled)
                )

                SettingsDivider()

                SettingsStepperRow(
                    title: L10n.Pomodoro.duration,
                    value: draftBinding(\.durationMinutes),
                    range: 1...240,
                    step: 5,
                    description: "专注时间的目标值，达成后会发送通知提醒"
                )

                SettingsDivider()

                SettingsStepperRow(
                    title: L10n.Pomodoro.interruptionGrace,
                    value: draftBinding(\.interruptionGraceMinutes),
                    range: 0...120,
                    step: 1,
                    description: "离开工作应用的容忍时间，超出后专注计时将重置"
                )

                SettingsDivider()

                SettingsStepperRow(
                    title: L10n.Pomodoro.reminderInterval,
                    value: draftBinding(\.reminderIntervalMinutes),
                    range: 1...240,
                    step: 5,
                    description: "达成目标后若继续工作，将每隔此时间再次提醒"
                )
            }

            SettingsSection {
                SettingsNavigationRow(
                    title: L10n.Pomodoro.workApps,
                    description: L10n.Pomodoro.workAppsDescription,
                    detail: detailText
                ) {
                    appContext.openWorkAppsSettings?()
                }

                SettingsDivider()

                SettingsToggleRow(
                    title: L10n.Pomodoro.showStatusBarWorkTime,
                    isOn: draftBinding(\.showsStatusBarWorkTime)
                )
            }

            HStack(alignment: .center) {
                Text(versionText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        tapCount += 1
                        if tapCount >= 6 {
                            isDevMode = true
                        }
                    }

                Spacer()

                if isDevMode {
                    Button("测试通知") {
                        appContext.pomodoroController.sendTestNotification()
                    }
                }

                Button(L10n.Sessions.cancel) {
                    appContext.settingsDraft = nil
                    closeWindow()
                }
                Button(L10n.Sessions.save) {
                    saveDraft()
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .frame(width: 560)
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2"
        #if DEBUG
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2"
        return "版本 \(version) (\(build))"
        #else
        return "版本 \(version)"
        #endif
    }

    private var detailText: String {
        guard let draft = appContext.settingsDraft else { return "" }
        return L10n.Pomodoro.workAppCount(draft.settings.workApps.count)
    }

    private func draftBinding<Value>(_ keyPath: WritableKeyPath<PomodoroSettings, Value>) -> Binding<Value> {
        Binding(
            get: { appContext.settingsDraft?.settings[keyPath: keyPath] ?? settingsStore.settings[keyPath: keyPath] },
            set: {
                appContext.settingsDraft?.settings[keyPath: keyPath] = $0
                appContext.objectWillChange.send()
            }
        )
    }

    private func saveDraft() {
        guard let draft = appContext.settingsDraft else { return }
        settingsStore.update { settings in
            settings = draft.settings
        }
        appContext.settingsDraft = nil
        closeWindow()
    }

    private func closeWindow() {
        NSApp.windows.first(where: { $0.title == L10n.Pomodoro.settingsTitle })?.close()
    }
}


struct PomodoroWorkAppsView: View {
    @EnvironmentObject private var appContext: AppContext

    @State private var knownApps: [KnownApp] = []

    var body: some View {
        SettingsPane(title: "", scrollable: false) {
            VStack(spacing: 18) {
                ScrollView {
                    if knownApps.isEmpty {
                        ContentUnavailableView(
                            L10n.Pomodoro.noKnownApps,
                            systemImage: "clock.badge.questionmark"
                        )
                        .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        SettingsSection {
                            ForEach(Array(knownApps.enumerated()), id: \.element.id) { index, app in
                                WorkAppCheckboxRow(
                                    app: app,
                                    isSelected: isSelected(app),
                                    onToggle: { toggle(app) }
                                )

                                if index < knownApps.count - 1 {
                                    SettingsDivider()
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                HStack {
                    Spacer()
                    Button(L10n.Sessions.cancel) {
                        appContext.workAppsDraft = appContext.settingsStore.settings.workApps
                        closeWindow()
                    }
                    Button(L10n.Sessions.save) {
                        appContext.saveWorkAppsSelection()
                        closeWindow()
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
        }
        .frame(width: 560, height: 620)
        .onAppear {
            loadKnownApps()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDataDidUpdate)) { _ in
            loadKnownApps()
        }
    }

    private func isSelected(_ app: KnownApp) -> Bool {
        appContext.workAppsDraft.contains { $0.bundleId == app.bundleId }
    }

    private func toggle(_ app: KnownApp) {
        if isSelected(app) {
            appContext.workAppsDraft.removeAll { $0.bundleId == app.bundleId }
        } else {
            let newApp = PomodoroWorkApp(bundleId: app.bundleId, appName: app.appName)
            appContext.workAppsDraft.append(newApp)
            appContext.workAppsDraft.sort {
                $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
            }
        }
    }

    private func closeWindow() {
        NSApp.windows.first(where: { $0.title == L10n.Pomodoro.workApps })?.close()
    }

    private func loadKnownApps() {
        appContext.sessionStore.fetchKnownAppsWithMonthlyDuration { databaseApps in
            DispatchQueue.global(qos: .userInitiated).async {
                let installedApps = Self.fetchAllInstalledApps()
                let combined = databaseApps + installedApps.filter { installed in
                    !databaseApps.contains { db in db.bundleId == installed.bundleId }
                }
                DispatchQueue.main.async {
                    knownApps = mergedKnownApps(from: combined)
                }
            }
        }
    }

    private static func fetchAllInstalledApps() -> [KnownApp] {
        let fileManager = FileManager.default
        let appDirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        var apps: [KnownApp] = []
        var seenBundleIds = Set<String>()

        for dir in appDirs {
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                if url.pathExtension == "app" {
                    enumerator.skipDescendants()

                    guard let bundle = Bundle(url: url) else { continue }
                    let bundleId = bundle.bundleIdentifier ?? ""
                    guard !bundleId.isEmpty else { continue }

                    let appName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? url.deletingPathExtension().lastPathComponent

                    if !seenBundleIds.contains(bundleId) {
                        seenBundleIds.insert(bundleId)
                        apps.append(KnownApp(bundleId: bundleId, appName: appName, totalDuration: 0))
                    }
                }
            }
        }
        return apps
    }

    private func mergedKnownApps(from apps: [KnownApp]) -> [KnownApp] {
        var resultByBundleId = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleId, $0) })

        for app in appContext.workAppsDraft {
            if resultByBundleId[app.bundleId] == nil {
                resultByBundleId[app.bundleId] = KnownApp(
                    bundleId: app.bundleId,
                    appName: app.appName
                )
            }
        }

        return resultByBundleId.values.sorted { a, b in
            if a.totalDuration != b.totalDuration {
                return a.totalDuration > b.totalDuration
            }
            return a.appName.localizedCaseInsensitiveCompare(b.appName) == .orderedAscending
        }
    }
}



private struct SettingsPane<Content: View>: View {
    let title: String
    var scrollable: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        if scrollable {
            ScrollView {
                paneContent
            }
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            paneContent
                .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var paneContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .padding(.bottom, 4)
            }

            content
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Color(nsColor: .separatorColor)
            .opacity(0.5)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    var description: String = ""
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundColor(.primary)
                if !description.isEmpty {
                    Text(description)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }
}

private struct SettingsStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var description: String = ""

    @FocusState private var isFocused: Bool
    @State private var inputText: String = ""

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundColor(.primary)
                if !description.isEmpty {
                    Text(description)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Stepper(value: $value, in: range, step: step) {
                HStack(spacing: 0) {
                    TextField("", text: $inputText, onCommit: {
                        finishEditing()
                    })
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .focused($isFocused)
                    .frame(width: 50)
                    .onChange(of: inputText) { newValue in
                        let filtered = newValue.filter { "0123456789".contains($0) }
                        if filtered != newValue {
                            inputText = filtered
                        }
                    }
                    .onChange(of: isFocused) { focused in
                        if focused {
                            inputText = "\(value)"
                        } else {
                            finishEditing()
                        }
                    }
                    .onChange(of: value) { newValue in
                        inputText = "\(newValue)"
                    }

                    Text(" 分钟")
                        .font(.body)
                }
                .frame(width: 92, alignment: .trailing)
                .contentShape(Rectangle())
                .onTapGesture {
                    isFocused = true
                }
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.iBeam.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .onAppear {
            inputText = "\(value)"
        }
    }

    private func finishEditing() {
        if let parsed = Int(inputText) {
            value = min(max(parsed, range.lowerBound), range.upperBound)
        }
        inputText = "\(value)"
        isFocused = false
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    var description: String = ""
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundColor(.primary)
                    if !description.isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(detail)
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct WorkAppCheckboxRow: View {
    let app: KnownApp
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                if let icon = icon(for: app.bundleId) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.appName)
                        .foregroundColor(.primary)
                    Text(app.bundleId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(minHeight: 52)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func icon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }

        return NSWorkspace.shared.icon(forFile: url.path)
    }
}


final class SettingsDraft: ObservableObject {
    @Published var settings: PomodoroSettings

    init(from settings: PomodoroSettings) {
        self.settings = settings
    }
}
