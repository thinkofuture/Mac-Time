import Foundation
import UserNotifications
import AppKit

final class PomodoroNotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                print("Failed to request notification authorization: \(error)")
            }
        }
    }

    func sendReminder(workMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Mac Time"
        content.body = L10n.Pomodoro.reminderBody(minutes: workMinutes)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "pomodoro-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                print("Failed to schedule pomodoro notification: \(error)")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func sendTestNotification() {
        print("[Mac Time Test Notification] Starting sendTestNotification...")
        
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .denied || settings.authorizationStatus == .notDetermined {
                    print("[Mac Time Test Notification] WARNING: Notification authorization is DENIED.")
                    
                    let alert = NSAlert()
                    alert.messageText = "通知权限受限"
                    alert.informativeText = "Mac Time 无法发送通知。请前往 macOS「系统设置 -> 通知 -> Mac Time」中允许通知权限。"
                    alert.addButton(withTitle: "前往设置")
                    alert.addButton(withTitle: "取消")
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                } else {
                    self?.triggerTestNotification()
                }
            }
        }
    }

    private func triggerTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "测试通知"
        content.body = "这是一条测试通知，发送时间: \(Date())"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "test-notification-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        print("[Mac Time Test Notification] Adding request \(request.identifier)...")
        center.add(request) { error in
            if let error {
                print("[Mac Time Test Notification] ERROR: \(error)")
            } else {
                print("[Mac Time Test Notification] SUCCESS: Test notification scheduled.")
            }
        }
    }
}
