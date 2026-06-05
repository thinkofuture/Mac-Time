import Foundation
import Testing
@testable import Mac_Time

struct Mac_TimeTests {
    @Test func pomodoroKeepsShortInterruptionsButDoesNotCountThem() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var engine = PomodoroEngine(settings: makePomodoroSettings())

        engine.handleActivity(makeActivity(bundle: "com.example.editor", appName: "Editor", at: base))
        _ = engine.tick(at: base.addingTimeInterval(600))
        engine.handleActivity(makeActivity(bundle: "com.example.chat", appName: "Chat", at: base.addingTimeInterval(600)))
        _ = engine.tick(at: base.addingTimeInterval(840))
        engine.handleActivity(makeActivity(bundle: "com.example.editor", appName: "Editor", at: base.addingTimeInterval(840)))
        _ = engine.tick(at: base.addingTimeInterval(1_200))

        #expect(engine.state.accumulatedWorkDuration == 960)
        #expect(engine.state.isWorking)
    }

    @Test func pomodoroResetsAfterLongInterruption() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var engine = PomodoroEngine(settings: makePomodoroSettings())

        engine.handleActivity(makeActivity(bundle: "com.example.editor", appName: "Editor", at: base))
        _ = engine.tick(at: base.addingTimeInterval(600))
        engine.handleActivity(makeActivity(bundle: "com.example.chat", appName: "Chat", at: base.addingTimeInterval(600)))
        _ = engine.tick(at: base.addingTimeInterval(901))

        #expect(engine.state.accumulatedWorkDuration == 0)
        #expect(!engine.state.isWorking)
    }

    @Test func pomodoroCountsSwitchesBetweenWorkAppsAsContinuous() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var settings = makePomodoroSettings()
        settings.workApps.append(PomodoroWorkApp(bundleId: "com.example.terminal", appName: "Terminal"))
        var engine = PomodoroEngine(settings: settings)

        engine.handleActivity(makeActivity(bundle: "com.example.editor", appName: "Editor", at: base))
        _ = engine.tick(at: base.addingTimeInterval(100))
        engine.handleActivity(makeActivity(bundle: "com.example.terminal", appName: "Terminal", at: base.addingTimeInterval(100)))
        _ = engine.tick(at: base.addingTimeInterval(200))

        #expect(engine.state.accumulatedWorkDuration == 200)
        #expect(engine.state.currentWorkAppBundleId == "com.example.terminal")
    }

    @Test func pomodoroReminderThresholdUsesConfiguredInterval() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var settings = makePomodoroSettings()
        settings.durationMinutes = 1
        settings.reminderIntervalMinutes = 2
        var engine = PomodoroEngine(settings: settings)

        engine.handleActivity(makeActivity(bundle: "com.example.editor", appName: "Editor", at: base))

        let firstReminder = engine.tick(at: base.addingTimeInterval(60))
        let secondReminder = engine.tick(at: base.addingTimeInterval(180))

        #expect(firstReminder == 1)
        #expect(secondReminder == 3)
    }

    @Test func pomodoroStopsCountingWhenCurrentAppIsRemovedFromSettings() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var settings = makePomodoroSettings()
        var engine = PomodoroEngine(settings: settings)

        engine.handleActivity(makeActivity(bundle: "com.example.editor", appName: "Editor", at: base))
        _ = engine.tick(at: base.addingTimeInterval(120))

        settings.workApps = [
            PomodoroWorkApp(bundleId: "com.example.terminal", appName: "Terminal")
        ]
        engine.updateSettings(settings, at: base.addingTimeInterval(120))
        _ = engine.tick(at: base.addingTimeInterval(180))

        #expect(engine.state.accumulatedWorkDuration == 120)
        #expect(!engine.state.isWorking)
    }

    @Test func pomodoroDiscardResetsAccumulatedDurationAndState() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var engine = PomodoroEngine(settings: makePomodoroSettings())

        engine.handleActivity(makeActivity(bundle: "com.example.editor", appName: "Editor", at: base))
        _ = engine.tick(at: base.addingTimeInterval(60))

        #expect(engine.state.accumulatedWorkDuration == 60)
        #expect(engine.state.isWorking)

        engine.discard()

        #expect(engine.state.accumulatedWorkDuration == 0)
        #expect(!engine.state.isWorking)
        #expect(engine.state.currentWorkAppBundleId == nil)
    }

    @Test func mergeSessionsBridgesShortInterruptions() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [
            makeSession(id: 1, bundle: "com.example.editor", appName: "Editor", start: base, duration: 600),
            makeSession(id: 2, bundle: "com.example.chat", appName: "Chat", start: base.addingTimeInterval(600), duration: 120),
            makeSession(id: 3, bundle: "com.example.editor", appName: "Editor", start: base.addingTimeInterval(720), duration: 600)
        ]

        let blocks = TimelineViewModel.mergeSessions(sessions)

        #expect(blocks.count == 1)
        #expect(blocks.first?.bundleId == "com.example.editor")
        #expect(blocks.first?.segments.count == 3)
        #expect(blocks.first?.duration == 1_320)
    }

    @Test func mergeSessionsKeepsLongInterruptionsSeparate() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [
            makeSession(id: 1, bundle: "com.example.editor", appName: "Editor", start: base, duration: 600),
            makeSession(id: 2, bundle: "com.example.chat", appName: "Chat", start: base.addingTimeInterval(600), duration: 360),
            makeSession(id: 3, bundle: "com.example.editor", appName: "Editor", start: base.addingTimeInterval(960), duration: 600)
        ]

        let blocks = TimelineViewModel.mergeSessions(sessions)

        #expect(blocks.count == 3)
        #expect(blocks.map(\.bundleId) == [
            "com.example.editor",
            "com.example.chat",
            "com.example.editor"
        ])
    }

    @Test func mergeSessionsFiltersTinyBlocks() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [
            makeSession(id: 1, bundle: "com.example.noise", appName: "Noise", start: base, duration: 10),
            makeSession(id: 2, bundle: "com.example.editor", appName: "Editor", start: base.addingTimeInterval(20), duration: 60)
        ]

        let blocks = TimelineViewModel.mergeSessions(sessions)

        #expect(blocks.count == 1)
        #expect(blocks.first?.bundleId == "com.example.editor")
    }

    @Test func usageStatsClipsSessionsToRange() {
        let range = DateInterval(
            start: Date(timeIntervalSince1970: 1_700_000_000),
            end: Date(timeIntervalSince1970: 1_700_003_600)
        )
        let sessions = [
            makeSession(
                id: 1,
                bundle: "com.example.editor",
                appName: "Editor",
                start: range.start.addingTimeInterval(-600),
                duration: 1_200
            ),
            makeSession(
                id: 2,
                bundle: "com.example.editor",
                appName: "Editor",
                start: range.end.addingTimeInterval(-300),
                duration: 900
            ),
            makeSession(
                id: 3,
                bundle: "com.example.chat",
                appName: "Chat",
                start: range.start.addingTimeInterval(-1_200),
                duration: 300
            )
        ]

        let stats = TimelineViewModel.usageStats(from: sessions, in: range)

        #expect(stats.count == 1)
        #expect(stats.first?.bundleId == "com.example.editor")
        #expect(stats.first?.duration == 900)
    }

    @Test func usageStatsSortsByDurationDescending() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let range = DateInterval(start: base, end: base.addingTimeInterval(3_600))
        let sessions = [
            makeSession(id: 1, bundle: "com.example.chat", appName: "Chat", start: base, duration: 600),
            makeSession(id: 2, bundle: "com.example.editor", appName: "Editor", start: base, duration: 1_200)
        ]

        let stats = TimelineViewModel.usageStats(from: sessions, in: range)

        #expect(stats.map(\.bundleId) == [
            "com.example.editor",
            "com.example.chat"
        ])
    }

    private func makeSession(
        id: Int64,
        bundle: String,
        appName: String,
        start: Date,
        duration: TimeInterval
    ) -> Session {
        Session(
            id: id,
            bundleId: bundle,
            appName: appName,
            windowTitle: nil,
            startAt: start,
            endAt: start.addingTimeInterval(duration),
            duration: duration
        )
    }

    private func makePomodoroSettings() -> PomodoroSettings {
        var settings = PomodoroSettings.defaults
        settings.workApps = [
            PomodoroWorkApp(bundleId: "com.example.editor", appName: "Editor")
        ]
        return settings
    }

    private func makeActivity(bundle: String, appName: String, at date: Date) -> ActivityEvent {
        ActivityEvent(
            bundleId: bundle,
            appName: appName,
            windowTitle: nil,
            happenedAt: date
        )
    }
}
