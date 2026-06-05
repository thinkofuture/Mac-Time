import AppKit
import ApplicationServices
import Foundation

final class ActivityTracker {
    private let sessionStore: SessionStore
    private var currentAppBundleId: String?
    private var currentAppName: String?
    private var currentWindowTitle: String?
    private var sessionStart: Date?
    private var pollTimer: Timer?
    private var hasRequestedAccessibilityAccess = false

    private var observers: [Any] = []
    private let pollInterval: TimeInterval = 5.0
    
    private let ignoredBundleIds: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.ScreenSaver.Engine",
        "com.apple.SecurityAgent" // Password prompts
    ]

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    func start() {
        // Observe foreground app changes.
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self.handleAppSwitch(to: app)
        })

        // Sleep / wake handling.
        observers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endCurrentSession(publishInactive: true)
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncWithFrontmostApp()
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endCurrentSession(publishInactive: true)
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncWithFrontmostApp()
        })

        syncWithFrontmostApp()
        startPolling()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        endCurrentSession(publishInactive: true)
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    deinit {
        stop()
    }

    // MARK: - Private

    private func syncWithFrontmostApp() {
        let app = NSWorkspace.shared.frontmostApplication
        handleAppSwitch(to: app)
    }

    private func handleAppSwitch(to app: NSRunningApplication?) {
        guard let app,
              let identity = resolveActivityIdentity(for: app) else {
            endCurrentSession(publishInactive: true)
            return
        }

        if ignoredBundleIds.contains(identity.bundleId) || identity.bundleId == Bundle.main.bundleIdentifier {
            endCurrentSession(publishInactive: true)
            return
        }

        // End previous session if needed.
        if let currentBundle = currentAppBundleId,
           currentBundle != identity.bundleId {
            endCurrentSession(publishInactive: false)
        }

        // Start new if none active.
        if sessionStart == nil {
            currentAppBundleId = identity.bundleId
            currentAppName = identity.appName
            currentWindowTitle = identity.windowTitle
            sessionStart = Date()
        } else {
            currentAppName = identity.appName
            currentWindowTitle = identity.windowTitle
        }

        publishActivity(
            bundleId: identity.bundleId,
            appName: identity.appName,
            windowTitle: identity.windowTitle
        )
    }

    private func endCurrentSession(publishInactive: Bool = false) {
        defer {
            sessionStart = nil
            currentAppBundleId = nil
            currentAppName = nil
            currentWindowTitle = nil

            if publishInactive {
                publishActivity(bundleId: nil, appName: nil, windowTitle: nil)
            }
        }

        guard let start = sessionStart,
              let bundleId = currentAppBundleId,
              let appName = currentAppName else { return }
        let end = Date()
        if end > start {
            let duration = end.timeIntervalSince(start)
            if duration > 10.0 {
                sessionStore.appendSession(
                    appName: appName,
                    bundleId: bundleId,
                    windowTitle: currentWindowTitle,
                    start: start,
                    end: end
                )
            }
        }
    }

    private func publishActivity(bundleId: String?, appName: String?, windowTitle: String?) {
        NotificationCenter.default.post(
            name: .activityDidUpdate,
            object: ActivityEvent(
                bundleId: bundleId,
                appName: appName,
                windowTitle: windowTitle,
                happenedAt: Date()
            )
        )
    }

    private func startPolling() {
        guard pollTimer == nil else { return }

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.syncWithFrontmostApp()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func resolveActivityIdentity(for app: NSRunningApplication) -> ActivityIdentity? {
        let appName = normalizedText(
            app.localizedName ?? app.executableURL?.deletingPathExtension().lastPathComponent
        )
        let bundleId = normalizedText(app.bundleIdentifier)

        guard let appName else {
            return nil
        }

        if let bundleId,
           ignoredBundleIds.contains(bundleId) || bundleId == Bundle.main.bundleIdentifier {
            return nil
        }

        let fallbackBundleId = bundleId ?? fallbackBundleId(for: app, appName: appName)
        let fallback = ActivityIdentity(
            bundleId: fallbackBundleId,
            appName: appName,
            windowTitle: nil
        )

        guard isCompatibilityRuntime(app: app, appName: appName, bundleId: bundleId),
              let title = activeWindowTitle(for: app),
              !shouldIgnoreCompatibilityWindowTitle(title, appName: appName) else {
            return bundleId == nil && !isCompatibilityRuntime(app: app, appName: appName, bundleId: bundleId)
                ? nil
                : fallback
        }

        let virtualBundleId = "virtual.crossover.\(stableHashHex("\(fallbackBundleId)\n\(title.lowercased())"))"
        return ActivityIdentity(
            bundleId: virtualBundleId,
            appName: title,
            windowTitle: title
        )
    }

    private func fallbackBundleId(for app: NSRunningApplication, appName: String) -> String {
        let source = app.executableURL?.path ?? appName
        return "virtual.process.\(stableHashHex(source.lowercased()))"
    }

    private func isCompatibilityRuntime(
        app: NSRunningApplication,
        appName: String,
        bundleId: String?
    ) -> Bool {
        let text = [
            appName,
            bundleId,
            app.executableURL?.path,
            app.bundleURL?.path
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
        .lowercased()

        if text.contains("crossover") || text.contains("codeweavers") {
            return true
        }

        if text.contains("wine") || text.contains("wine64") || text.contains("wineserver") {
            return true
        }

        return text.contains("steam") &&
            (text.contains("crossover") || text.contains("codeweavers") || text.contains("wine"))
    }

    private func activeWindowTitle(for app: NSRunningApplication) -> String? {
        if let title = accessibilityWindowTitle(for: app.processIdentifier) {
            return title
        }

        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        var firstCompatibilityTitle: String?
        var firstCompatibilityPID: pid_t?

        for info in windowInfo {
            guard isUserWindow(info) else {
                continue
            }

            let ownerPID = intValue(info[kCGWindowOwnerPID as String]).map(pid_t.init)
            let ownerName = normalizedText(info[kCGWindowOwnerName as String] as? String)?.lowercased()
            let title = normalizedText(info[kCGWindowName as String] as? String)

            if firstCompatibilityPID == nil,
               let ownerName,
               isCompatibilityWindowOwner(ownerName) {
                firstCompatibilityPID = ownerPID
            }

            guard let title else {
                continue
            }

            if ownerPID == app.processIdentifier {
                return title
            }

            if firstCompatibilityTitle == nil,
               let ownerName,
               isCompatibilityWindowOwner(ownerName) {
                firstCompatibilityTitle = title
            }
        }

        if let firstCompatibilityPID,
           let title = accessibilityWindowTitle(for: firstCompatibilityPID) {
            return title
        }

        return firstCompatibilityTitle
    }

    private func accessibilityWindowTitle(for pid: pid_t) -> String? {
        requestAccessibilityAccessIfNeeded()

        guard AXIsProcessTrusted() else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindowValue: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )

        guard windowResult == .success,
              let focusedWindowValue,
              CFGetTypeID(focusedWindowValue) == AXUIElementGetTypeID() else {
            return nil
        }

        let focusedWindow = focusedWindowValue as! AXUIElement
        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            focusedWindow,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        guard titleResult == .success else {
            return nil
        }

        return normalizedText(titleValue as? String)
    }

    private func requestAccessibilityAccessIfNeeded() {
        guard !hasRequestedAccessibilityAccess,
              !AXIsProcessTrusted() else {
            return
        }

        hasRequestedAccessibilityAccess = true
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func isUserWindow(_ info: [String: Any]) -> Bool {
        let layer = intValue(info[kCGWindowLayer as String]) ?? 0
        guard layer == 0 else { return false }

        if let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool,
           !isOnScreen {
            return false
        }

        let alpha = doubleValue(info[kCGWindowAlpha as String]) ?? 1.0
        guard alpha > 0 else { return false }

        guard let bounds = info[kCGWindowBounds as String] as? [String: Any],
              let width = doubleValue(bounds["Width"]),
              let height = doubleValue(bounds["Height"]) else {
            return true
        }

        return width >= 80 && height >= 40
    }

    private func isCompatibilityWindowOwner(_ ownerName: String) -> Bool {
        ownerName.contains("crossover")
            || ownerName.contains("codeweavers")
            || ownerName.contains("wine")
            || ownerName.contains("steam")
    }

    private func shouldIgnoreCompatibilityWindowTitle(_ title: String, appName: String) -> Bool {
        let lowercasedTitle = title.lowercased()
        let lowercasedAppName = appName.lowercased()

        return lowercasedTitle == lowercasedAppName && isGenericCompatibilityName(lowercasedAppName)
            || lowercasedTitle == "crossover"
            || lowercasedTitle == "wine"
            || lowercasedTitle == "wineserver"
    }

    private func isGenericCompatibilityName(_ name: String) -> Bool {
        name == "crossover"
            || name == "crossOver".lowercased()
            || name == "steam"
            || name == "wine"
            || name == "wineserver"
            || name.contains("wine64")
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }

        let normalized = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return normalized.isEmpty ? nil : normalized
    }

    private func stableHashHex(_ text: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037

        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        let hex = String(hash, radix: 16)
        let padding = max(16 - hex.count, 0)
        return String(repeating: "0", count: padding) + hex
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }

        if let value = value as? NSNumber {
            return value.intValue
        }

        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }

        if let value = value as? NSNumber {
            return value.doubleValue
        }

        return nil
    }
}

private struct ActivityIdentity {
    let bundleId: String
    let appName: String
    let windowTitle: String?
}
