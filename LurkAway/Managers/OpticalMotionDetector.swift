@preconcurrency import AVFoundation
import CoreVideo

/// Detects gross scene changes from the front camera — the view lurches when the
/// laptop is picked up, tilted, or the lens is covered. Fully documented AVFoundation
/// path; no motion sensor required. Compares a coarse luminance grid frame-to-frame.
@MainActor
final class OpticalMotionDetector: NSObject {
    var onMotion: (() -> Void)?
    var sensitivity: Double = 0.5 {   // 0 = least sensitive, 1 = most sensitive
        didSet { updateThreshold() }
    }

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "dev.djabari.LurkAway.optical")
    private var isRunning = false

    private nonisolated static let gridSize = 8
    private nonisolated static let sampleInterval: TimeInterval = 0.2

    // Accessed only on the serial capture queue.
    private nonisolated(unsafe) var previousSignature: [Float]?
    private nonisolated(unsafe) var lastSampleTime = Date.distantPast
    private nonisolated(unsafe) var didFire = false
    // Set on MainActor when sensitivity changes, read on the capture queue (float snapshot).
    private nonisolated(unsafe) var currentThreshold: Float = 0.13

    private func updateThreshold() {
        currentThreshold = Float(0.23 - 0.20 * max(0, min(1, sensitivity)))
    }

    func start() {
        guard !isRunning else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                guard granted else { return }
                Task { @MainActor [weak self] in self?.configureAndRun() }
            }
        case .denied, .restricted:
            print("[LurkAway] Camera denied — optical motion disabled (power monitor still active)")
        @unknown default:
            break
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        session.stopRunning()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        // Session is stopped, so no further delegate callbacks race these queue-only fields.
        previousSignature = nil
        didFire = false
        lastSampleTime = .distantPast
    }

    private func configureAndRun() {
        guard !isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .cif352x288

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            print("[LurkAway] Camera not available for optical motion")
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        CameraTuning.throttle(device, toFPS: 5)   // responsive enough for grab/tilt

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()

        isRunning = true
        session.startRunning()
    }

    private nonisolated func signature(from pixelBuffer: CVPixelBuffer) -> [Float]? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        guard width > 0, height > 0,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return nil
        }
        let luma = base.assumingMemoryBound(to: UInt8.self)

        let grid = Self.gridSize
        var sig = [Float](repeating: 0, count: grid * grid)
        let sub = 4   // average a 4×4 block of samples per cell

        for cellY in 0..<grid {
            for cellX in 0..<grid {
                var sum = 0
                for sy in 0..<sub {
                    let py = min(height - 1, (cellY * height) / grid + (sy * height) / (grid * sub))
                    for sx in 0..<sub {
                        let px = min(width - 1, (cellX * width) / grid + (sx * width) / (grid * sub))
                        sum += Int(luma[py * bytesPerRow + px])
                    }
                }
                sig[cellY * grid + cellX] = Float(sum) / Float(sub * sub) / 255.0
            }
        }
        return sig
    }
}

extension OpticalMotionDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !didFire,
              Date().timeIntervalSince(lastSampleTime) >= Self.sampleInterval,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let current = signature(from: pixelBuffer) else {
            return
        }
        lastSampleTime = Date()

        defer { previousSignature = current }
        guard let previous = previousSignature, previous.count == current.count else { return }

        var total: Float = 0
        for i in 0..<current.count {
            total += abs(current[i] - previous[i])
        }
        let meanDiff = total / Float(current.count)

        if meanDiff > currentThreshold {
            didFire = true
            Task { @MainActor [weak self] in self?.onMotion?() }
        }
    }
}
