import Combine
import Foundation

final class PomodoroController: ObservableObject {
    @Published private(set) var state: PomodoroState
    @Published private(set) var statusBarText: String = ""

    let settingsStore: PomodoroSettingsStore
    private let notificationService: PomodoroNotificationService
    private var engine: PomodoroEngine
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?

    init(
        settingsStore: PomodoroSettingsStore,
        notificationService: PomodoroNotificationService = PomodoroNotificationService()
    ) {
        self.settingsStore = settingsStore
        self.notificationService = notificationService
        self.engine = PomodoroEngine(settings: settingsStore.settings)
        self.state = engine.state

        notificationService.requestAuthorization()
        bind()
        startTimer()
        publishState()
    }

    deinit {
        timer?.invalidate()
    }

    private func bind() {
        settingsStore.$settings
            .dropFirst()
            .sink { [weak self] settings in
                guard let self else { return }
                self.engine.updateSettings(settings, at: Date())
                self.publishState()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .activityDidUpdate)
            .compactMap { $0.object as? ActivityEvent }
            .sink { [weak self] event in
                guard let self else { return }
                self.engine.handleActivity(event)
                self.publishState()
            }
            .store(in: &cancellables)
    }

    private func startTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        if let reminderMinutes = engine.tick(at: Date()) {
            notificationService.sendReminder(workMinutes: reminderMinutes)
        }

        publishState()
    }

    private func publishState() {
        state = engine.state

        guard settingsStore.settings.showsStatusBarWorkTime,
              settingsStore.settings.isEnabled,
              state.accumulatedWorkDuration > 0 else {
            statusBarText = ""
            return
        }

        statusBarText = Self.statusText(for: state.accumulatedWorkDuration)
    }

    private static func statusText(for duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration), 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    func sendTestNotification() {
        notificationService.sendTestNotification()
    }

    func discard() {
        engine.discard()
        publishState()
    }
}
