@preconcurrency import AVFoundation

/// Caps a capture device's frame rate to the lowest the active format allows at or below
/// the requested rate, so the camera pipeline burns as little CPU/power as the feature needs.
enum CameraTuning {
    static func throttle(_ device: AVCaptureDevice, toFPS fps: Double) {
        let ranges = device.activeFormat.videoSupportedFrameRateRanges
        guard let range = ranges.first else { return }

        let target = min(max(fps, range.minFrameRate), range.maxFrameRate)
        guard target > 0, (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }

        let duration = CMTime(value: 1, timescale: CMTimeScale(target.rounded()))
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
    }
}
