import AVFoundation
import Combine
import os

@MainActor
final class AlarmController: ObservableObject {
    @Published var isPlaying = false

    private var player: AVAudioPlayer?
    private let audioGuard = LockAudioGuard()

    func play(volume: Double = 1.0) {
        guard !isPlaying else { return }
        let level = min(max(volume, 0.0), 1.0)

        // Force built-in output and unmute before blasting.
        audioGuard.begin()

        do {
            player = try AVAudioPlayer(data: SirenGenerator.makeWAV(amplitude: 0.9 * level), fileTypeHint: AVFileType.wav.rawValue)
            player?.numberOfLoops = -1
            player?.volume = Float(level)
            player?.prepareToPlay()
            // Enforce an audible floor only once the player is ready to sound.
            if let device = SystemVolume.defaultOutputDevice() { SystemVolume.setVolume(1.0, of: device) }
            player?.play()
            isPlaying = true
        } catch {
            log.error("Failed to play alarm: \(error.localizedDescription, privacy: .public)")
            audioGuard.end()
        }
    }

    func stop() {
        guard isPlaying else { return }
        player?.stop()
        player = nil
        audioGuard.end()
        isPlaying = false
    }
}
