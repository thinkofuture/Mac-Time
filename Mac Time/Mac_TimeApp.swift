import SwiftUI
import Combine

@main
struct MacTimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var settingsWindow: NSWindow?
    var workAppsWindow: NSWindow?
    var statusItem: NSStatusItem?
    var appContext: AppContext!
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = SessionStore()
        appContext = AppContext(store: store)
        appContext.openSettings = { [weak self] in
            self?.showSettingsWindow()
        }
        appContext.openWorkAppsSettings = { [weak self] in
            self?.showWorkAppsWindow()
        }
        
        let contentView = ContentView(
            viewModel: TimelineViewModel(sessionStore: store)
        )
        .environmentObject(appContext)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.center()
        window.title = "Mac Time"
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self
        
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "ring", accessibilityDescription: "Mac Time")
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12.0, weight: .regular)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(menuBarClickHandler(_:))
        }

        appContext.pomodoroController.$statusBarText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.updateStatusItemText(text)
            }
            .store(in: &cancellables)
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == window {
            window.orderOut(nil)
            return false
        }
        
        if sender == workAppsWindow {
            if appContext.hasUnsavedWorkAppsChanges {
                let alert = NSAlert()
                alert.messageText = "有未保存的修改"
                alert.informativeText = "您修改了工作应用列表，是否保存这些修改？"
                alert.addButton(withTitle: "保存")
                alert.addButton(withTitle: "舍弃")
                alert.addButton(withTitle: "取消")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    appContext.saveWorkAppsSelection()
                    return true
                } else if response == .alertSecondButtonReturn {
                    appContext.workAppsDraft = appContext.settingsStore.settings.workApps
                    return true
                } else {
                    return false
                }
            }
        }
        return true
    }
    
    @objc func menuBarClickHandler(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            
            if appContext.pomodoroController.settingsStore.settings.isEnabled &&
               appContext.pomodoroController.state.accumulatedWorkDuration > 0 {
                let discardItem = NSMenuItem(title: L10n.Pomodoro.discard, action: #selector(discardCurrentPomodoro), keyEquivalent: "")
                discardItem.target = self
                menu.addItem(discardItem)
                menu.addItem(.separator())
            }
            
            let settingsItem = NSMenuItem(title: L10n.Pomodoro.settingsMenu, action: #selector(showSettingsWindow), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)
            menu.addItem(.separator())
            let quitItem = NSMenuItem(title: L10n.App.quit, action: #selector(quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            toggleApp()
        }
    }

    @objc func discardCurrentPomodoro() {
        appContext.pomodoroController.discard()
    }

    @objc func showSettingsWindow() {
        settingsWindow?.close()
        settingsWindow = nil

        appContext.settingsDraft = SettingsDraft(from: appContext.settingsStore.settings)

        let view = PomodoroSettingsView(settingsStore: appContext.settingsStore)
            .environmentObject(appContext)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()
        window.title = L10n.Pomodoro.settingsTitle
        
        let contentView = NSHostingView(rootView: view)
        window.contentView = contentView
        window.setContentSize(contentView.fittingSize)
        
        window.delegate = self
        settingsWindow = window

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showWorkAppsWindow() {
        workAppsWindow?.close()
        workAppsWindow = nil

        appContext.workAppsDraft = appContext.settingsStore.settings.workApps

        let view = PomodoroWorkAppsView()
            .environmentObject(appContext)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()
        window.title = L10n.Pomodoro.workApps
        window.contentView = NSHostingView(rootView: view)
        window.delegate = self
        workAppsWindow = window

        workAppsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateStatusItemText(_ text: String) {
        guard let button = statusItem?.button else {
            return
        }

        if text.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 12.0, weight: .regular)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .baselineOffset: -0.5
            ]
            button.attributedTitle = NSAttributedString(string: " \(text)", attributes: attributes)
        }
    }
    
    @objc func toggleApp() {
        if window.isVisible {
            if window.isKeyWindow {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        if closingWindow == settingsWindow {
            settingsWindow = nil
            appContext.settingsDraft = nil
        } else if closingWindow == workAppsWindow {
            workAppsWindow = nil
        }
    }
}

final class AppContext: ObservableObject {
    let sessionStore: SessionStore
    let tracker: ActivityTracker
    let settingsStore: PomodoroSettingsStore
    let pomodoroController: PomodoroController
    var openSettings: (() -> Void)?
    var openWorkAppsSettings: (() -> Void)?

    @Published var settingsDraft: SettingsDraft?
    @Published var workAppsDraft: [PomodoroWorkApp] = []

    var hasUnsavedWorkAppsChanges: Bool {
        workAppsDraft != settingsStore.settings.workApps
    }

    func saveWorkAppsSelection() {
        settingsStore.update { settings in
            settings.workApps = workAppsDraft
        }
        settingsDraft?.settings.workApps = workAppsDraft
    }

    private var draftCancellable: AnyCancellable?
    private var contextCancellables = Set<AnyCancellable>()

    init(store: SessionStore) {
        let settingsStore = PomodoroSettingsStore()

        self.sessionStore = store
        self.settingsStore = settingsStore
        self.pomodoroController = PomodoroController(settingsStore: settingsStore)
        self.tracker = ActivityTracker(sessionStore: store)
        self.tracker.start()

        $settingsDraft
            .sink { [weak self] draft in
                self?.draftCancellable = draft?.objectWillChange
                    .sink { [weak self] _ in
                        Task { @MainActor [weak self] in
                            self?.objectWillChange.send()
                        }
                    }
            }
            .store(in: &contextCancellables)
    }
}
