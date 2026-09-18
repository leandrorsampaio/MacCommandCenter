import AVFoundation
import Foundation

/// The sound a sprung key makes.
///
/// Synthesised rather than shipped as an asset: a decaying square burst is a few lines,
/// and it keeps the app free of audio files it would otherwise have to license and load.
@MainActor
public enum KeyClick {

    private static var players: [Double: AVAudioPlayer] = [:]
    private static var filePlayers: [URL: AVAudioPlayer] = [:]

    /// Plays a sound a skin shipped. Falls back to the synthesised click when the file
    /// cannot be read, so a bad path costs the skin its click and nothing more.
    public static func play(file url: URL?, pitch: Double = 620) {
        guard let url else {
            play(pitch: pitch)
            return
        }
        if let player = filePlayers[url] {
            player.currentTime = 0
            player.play()
            return
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            play(pitch: pitch)
            return
        }
        player.volume = 0.5
        player.prepareToPlay()
        filePlayers[url] = player
        player.play()
    }

    /// `pitch` in hertz. A key is bright and short; something heavier wants a lower one.
    public static func play(pitch: Double = 620, seconds: Double = 0.045) {
        guard let player = players[pitch] ?? make(pitch: pitch, seconds: seconds) else { return }
        players[pitch] = player
        player.currentTime = 0
        player.play()
    }

    private static func make(pitch: Double, seconds: Double) -> AVAudioPlayer? {
        guard let data = waveform(pitch: pitch, seconds: seconds) else { return nil }
        let player = try? AVAudioPlayer(data: data)
        player?.volume = 0.22
        player?.prepareToPlay()
        return player
    }

    private static func waveform(pitch: Double, seconds: Double) -> Data? {
        let rate = 44100.0
        let frames = Int(rate * seconds)
        guard frames > 0 else { return nil }

        var samples = Data(capacity: frames * 2)
        for frame in 0..<frames {
            let time = Double(frame) / rate
            // Square wave for the snap, a little noise for the mechanism, both decaying fast.
            let square = sin(2 * .pi * pitch * time) >= 0 ? 1.0 : -1.0
            let noise = Double.random(in: -1...1) * 0.35
            let envelope = exp(-time * 90)
            let value = (square * 0.65 + noise) * envelope
            let scaled = Int16(max(-1, min(1, value)) * 26000)
            withUnsafeBytes(of: scaled.littleEndian) { samples.append(contentsOf: $0) }
        }

        return wav(pcm: samples, rate: Int(rate))
    }

    private static func wav(pcm: Data, rate: Int) -> Data {
        var header = Data()
        func append(_ string: String) { header.append(contentsOf: Array(string.utf8)) }
        func append32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { header.append(contentsOf: $0) }
        }
        func append16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { header.append(contentsOf: $0) }
        }

        append("RIFF")
        append32(UInt32(36 + pcm.count))
        append("WAVE")
        append("fmt ")
        append32(16)
        append16(1)  // PCM
        append16(1)  // mono
        append32(UInt32(rate))
        append32(UInt32(rate * 2))
        append16(2)
        append16(16)
        append("data")
        append32(UInt32(pcm.count))
        return header + pcm
    }
}
