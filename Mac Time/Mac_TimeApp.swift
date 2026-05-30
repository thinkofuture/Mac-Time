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
    var statusItem: NSStatusItem?
    var appContext: AppContext!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = SessionStore()
        appContext = AppContext(store: store)
        
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
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(menuBarClickHandler(_:))
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window.orderOut(nil)
        return false 
    }
    
    @objc func menuBarClickHandler(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: L10n.App.quit, action: #selector(quitApp), keyEquivalent: "q"))
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            toggleApp()
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
}

final class AppContext: ObservableObject {
    let sessionStore: SessionStore
    let tracker: ActivityTracker

    init(store: SessionStore) {
        self.sessionStore = store
        self.tracker = ActivityTracker(sessionStore: store)
        self.tracker.start()
    }
}
