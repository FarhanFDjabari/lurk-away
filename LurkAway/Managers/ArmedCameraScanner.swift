@preconcurrency import AVFoundation
import Vision
import CoreVideo

/// While armed, pulse-scans the front camera at a low frame rate (power-friendly) and, from
/// the same frames, does two things:
/// - coarse global-motion detection (laptop moved / lens covered) -> `onMotion`
/// - owner face recognition -> `onOwnerReturn` (pre-alarm auto-disarm)
@MainActor
final class ArmedCameraScanner: NSObject {
    var onMotion: (() -> Void)?
    var onOwnerReturn: (() -> Void)?
    var sensitivity: Double = 0.5 { didSet { updateThreshold() } }

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "dev.djabari.LurkAway.armedscan")
    private var isRunning = false

    private nonisolated static let gridSize = 8
    private nonisolated static let motionInterval: TimeInterval = 0.5   // ~2 fps
    private nonisolated static let faceInterval: TimeInterval = 1.5     // recognize less often (costly)
    private nonisolated static let perCellDelta: Float = 0.11

    private nonisolated(unsafe) var scanMotion = false
    private nonisolated(unsafe) var scanFace = false
    private nonisolated(unsafe) var enrolled: [VNFeaturePrintObservation] = []

    private nonisolated(unsafe) var previousSignature: [Float]?
    private nonisolated(unsafe) var lastMotionTime = Date.distantPast
    private nonisolated(unsafe) var lastFaceTime = Date.distantPast
    private nonisolated(unsafe) var didFireMotion = false
    private nonisolated(unsafe) var didFireReturn = false
    private nonisolated(unsafe) var requiredCoverage: Float = 0.525

    private func updateThreshold() {
        requiredCoverage = Float(0.75 - 0.45 * max(0, min(1, sensitivity)))
    }

    func start(motion: Bool, faceReturn: Bool) {
        guard !isRunning, motion || faceReturn else { return }
        scanMotion = motion
        scanFace = faceReturn
        enrolled = faceReturn ? FaceRecognizer.load() : []
        if faceReturn && enrolled.isEmpty { scanFace = false }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                guard granted else { return }
                Task { @MainActor [weak self] in self?.configureAndRun() }
            }
        case .denied, .restricted:
            print("[LurkAway] Camera denied — armed camera scan disabled")
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
        previousSignature = nil
        didFireMotion = false
        didFireReturn = false
        lastMotionTime = .distantPast
        lastFaceTime = .distantPast
    }

    private func configureAndRun() {
        guard !isRunning else { return }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480   // enough for both motion and face crops
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        CameraTuning.throttle(device, toFPS: 2)   // pulse: low frame rate to save power

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
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
        guard width > 0, height > 0, let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
        let luma = base.assumingMemoryBound(to: UInt8.self)
        let grid = Self.gridSize
        var sig = [Float](repeating: 0, count: grid * grid)
        let sub = 4
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

extension ArmedCameraScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = Date()

        if scanMotion, !didFireMotion, !didFireReturn, now.timeIntervalSince(lastMotionTime) >= Self.motionInterval,
           let current = signature(from: pixelBuffer) {
            lastMotionTime = now
            if let previous = previousSignature, previous.count == current.count {
                var changed = 0
                for i in 0..<current.count where abs(current[i] - previous[i]) > Self.perCellDelta { changed += 1 }
                if Float(changed) / Float(current.count) > requiredCoverage {
                    // A big change could be the owner returning — recognize before alarming.
                    if scanFace, let probe = FaceRecognizer.featurePrint(from: pixelBuffer),
                       FaceRecognizer.matches(probe, against: enrolled) {
                        didFireReturn = true
                        Task { @MainActor [weak self] in self?.onOwnerReturn?() }
                    } else {
                        didFireMotion = true
                        Task { @MainActor [weak self] in self?.onMotion?() }
                    }
                }
            }
            previousSignature = current
        }

        // Also recognize the owner returning calmly (no big motion).
        if scanFace, !didFireReturn, !didFireMotion, now.timeIntervalSince(lastFaceTime) >= Self.faceInterval {
            lastFaceTime = now
            if let probe = FaceRecognizer.featurePrint(from: pixelBuffer),
               FaceRecognizer.matches(probe, against: enrolled) {
                didFireReturn = true
                Task { @MainActor [weak self] in self?.onOwnerReturn?() }
            }
        }
    }
}
