import AVFoundation
import Foundation
import Testing

@testable import ConsoleKit
@testable import PK4Skin

@Suite struct SkinLogicTests {

    func at(_ fraction: Double, period: Double = 0.5) -> Date {
        // A moment `fraction` of the way through a flash period.
        let base = (Date().timeIntervalSinceReferenceDate / period).rounded(.down) * period
        return Date(timeIntervalSinceReferenceDate: base + fraction * period)
    }

    /// Rise 80 ms, hold to 250, decay 200, dark 50: one 500 ms period.
    @Test func theFlashFollowsItsFourSegments() {
        #expect(abs(Flash.level(at: at(0.08), reduceMotion: false) - 0.5) < 0.01)
        #expect(Flash.level(at: at(0.3), reduceMotion: false) == 1)
        #expect(abs(Flash.level(at: at(0.7), reduceMotion: false) - 0.5) < 0.01)
        #expect(Flash.level(at: at(0.95), reduceMotion: false) == 0)
        #expect(Flash.inkLit(at: at(0.3), reduceMotion: false))
        #expect(!Flash.inkLit(at: at(0.7), reduceMotion: false))
    }

    @Test func reduceMotionSlowsTheFlashToOneHertz() {
        #expect(Flash.period(reduceMotion: true) == 1)
        #expect(Flash.level(at: at(0.3, period: 1), reduceMotion: true) == 1)
    }

    @Test func instrumentsSpeakInWords() {
        #expect(PK4Words.lamp(.flash) == "alarm, unacknowledged")
        #expect(PK4Words.meter(0.62) == "62 percent")
        #expect(PK4Words.meter(Needle.leftStop) == "at the stop")
        #expect(PK4Words.digits("        ") == "dark")
        #expect(
            PK4Words.alarm(PK4.annunciator(.wait, slot: 2), selector: 1)
                == "Waiting for operator, session 2, alarm")
        #expect(PK4Words.alarm(PK4.warning(.stale), selector: 3) == "Data stale, session 3, alarm")
        #expect(PK4Words.alarm(PK4.annunciator(.run, slot: 1), selector: 1) == nil)
    }

    @Test func theSynthesisedSoundsAreTheSpecifiedLengths() {
        let format = AVAudioFormatShim.mono
        #expect(
            PK4Sound.burst(milliseconds: 18, frequency: 2600, gain: 0.5, format: format).frameLength
                == 793)
        #expect(
            PK4Sound.burst(milliseconds: 70, frequency: 320, gain: 0.9, format: format).frameLength
                == 3087)
        // A whole number of 420 Hz periods, so the loop has no seam.
        #expect(PK4Sound.square(frequency: 420, gain: 0.04, format: format).frameLength % 105 == 0)
    }
}

enum AVAudioFormatShim {
    static let mono = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
}
