import AVFoundation
import Combine

@MainActor
final class AlarmController: ObservableObject {
    @Published var isPlaying = false

    private var player: AVAudioPlayer?
    private let audioGuard = LockAudioGuard()

    func play() {
        guard !isPlaying else { return }

        // Force built-in output, unmute, and enforce an audible floor before blasting.
        audioGuard.begin()
        if let device = SystemVolume.defaultOutputDevice() { SystemVolume.setVolume(1.0, of: device) }

        do {
            player = try AVAudioPlayer(data: SirenGenerator.makeWAV(), fileTypeHint: AVFileType.wav.rawValue)
            player?.numberOfLoops = -1
            player?.volume = 1.0
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
        } catch {
            print("[LurkAway] Failed to play alarm: \(error.localizedDescription)")
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
