import AppKit
import Foundation

final class ActivityTracker {
    private let sessionStore: SessionStore
    private var currentAppBundleId: String?
    private var currentAppName: String?
    private var sessionStart: Date?

    private var observers: [Any] = []
    
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
            self?.endCurrentSession()
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
            self?.endCurrentSession()
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncWithFrontmostApp()
        })

        syncWithFrontmostApp()
    }

    func stop() {
        endCurrentSession()
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
              let bundleId = app.bundleIdentifier,
              let name = app.localizedName else {
            endCurrentSession()
            return
        }

        if ignoredBundleIds.contains(bundleId) || bundleId == Bundle.main.bundleIdentifier {
            endCurrentSession()
            return
        }

        // End previous session if needed.
        if let currentBundle = currentAppBundleId,
           currentBundle != bundleId {
            endCurrentSession()
        }

        // Start new if none active.
        if sessionStart == nil {
            currentAppBundleId = bundleId
            currentAppName = name
            sessionStart = Date()
        }
    }

    private func endCurrentSession() {
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
                    windowTitle: nil,
                    start: start,
                    end: end
                )
            }
        }
        sessionStart = nil
        currentAppBundleId = nil
        currentAppName = nil
    }
}
