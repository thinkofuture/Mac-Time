import Foundation
import Testing
@testable import Mac_Time

struct Mac_TimeTests {
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
}
