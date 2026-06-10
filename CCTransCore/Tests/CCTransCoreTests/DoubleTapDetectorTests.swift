import Testing
@testable import CCTransCore

@Suite struct DoubleTapDetectorTests {
    @Test func secondTapWithinThresholdTriggers() {
        var detector = DoubleTapDetector(threshold: 0.4)
        #expect(detector.register(at: 0.0) == false)
        #expect(detector.register(at: 0.3) == true)
    }

    @Test func secondTapBeyondThresholdDoesNotTrigger() {
        var detector = DoubleTapDetector(threshold: 0.4)
        #expect(detector.register(at: 0.0) == false)
        #expect(detector.register(at: 0.6) == false)
    }

    @Test func tripleTapTriggersOnlyOnce() {
        var detector = DoubleTapDetector(threshold: 0.4)
        #expect(detector.register(at: 0.0) == false)
        #expect(detector.register(at: 0.1) == true)
        #expect(detector.register(at: 0.2) == false)
    }
}
