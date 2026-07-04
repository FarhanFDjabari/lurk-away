import AVFoundation
import Combine

@MainActor
final class AlarmController: ObservableObject {
    @Published var isPlaying = false

    private var player: AVAudioPlayer?
    private var originalVolume: Float?

    func play() {
        guard !isPlaying else { return }

        originalVolume = SystemVolume.get()
        SystemVolume.set(1.0)

        do {
            player = try AVAudioPlayer(data: SirenGenerator.makeWAV(), fileTypeHint: AVFileType.wav.rawValue)
            player?.numberOfLoops = -1
            player?.volume = 1.0
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
        } catch {
            print("[LurkAway] Failed to play alarm: \(error.localizedDescription)")
            if let original = originalVolume { SystemVolume.set(original) }
        }
    }

    func stop() {
        guard isPlaying else { return }
        player?.stop()
        player = nil
        if let original = originalVolume { SystemVolume.set(original) }
        originalVolume = nil
        isPlaying = false
    }
}
