@preconcurrency import AVFoundation
import Vision
import Combine

/// Pulse-samples the front camera (~one frame per 1.5s) and arms theft protection
/// when no face is seen for several consecutive cycles (~5s), i.e. the owner walked away.
@MainActor
final class FaceDetectionManager: NSObject, ObservableObject {
    @Published var facePresent = true

    var onWalkAway: (() -> Void)?

    private let captureSession = AVCaptureSession()
    private let sampleQueue = DispatchQueue(label: "dev.djabari.LurkAway.camera")
    private var isRunning = false

    private nonisolated static let sampleInterval: TimeInterval = 1.5
    private nonisolated static let noFaceThreshold = 3   // 3 × 1.5s ≈ 5 seconds

    // Accessed only on the serial capture queue.
    private nonisolated(unsafe) var consecutiveNoFaceCount = 0
    private nonisolated(unsafe) var lastSampleTime = Date.distantPast
    private nonisolated(unsafe) var didTrigger = false

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
            print("[LurkAway] Camera access denied — walk-away detection disabled")
        @unknown default:
            break
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        captureSession.stopRunning()
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }
        // Session stopped — no delegate callbacks race these queue-only fields.
        consecutiveNoFaceCount = 0
        didTrigger = false
        lastSampleTime = .distantPast
    }

    private func configureAndRun() {
        guard !isRunning else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .cif352x288

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            print("[LurkAway] Camera not available")
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)
        CameraTuning.throttle(device, toFPS: 2)   // we only sample every 1.5s

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        captureSession.commitConfiguration()

        isRunning = true
        didTrigger = false
        lastSampleTime = Date()
        consecutiveNoFaceCount = 0
        captureSession.startRunning()
    }

    private func handleFaceResult(faceFound: Bool) {
        facePresent = faceFound
    }

    private func walkAwayDetected() {
        stop()
        facePresent = false
        onWalkAway?()
    }
}

extension FaceDetectionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !didTrigger,
              Date().timeIntervalSince(lastSampleTime) >= Self.sampleInterval,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        lastSampleTime = Date()

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        let faceFound: Bool
        do {
            try handler.perform([request])
            faceFound = !(request.results ?? []).isEmpty
        } catch {
            print("[LurkAway] Face detection error: \(error.localizedDescription)")
            return
        }

        if faceFound {
            consecutiveNoFaceCount = 0
        } else {
            consecutiveNoFaceCount += 1
        }

        let walkAway = consecutiveNoFaceCount >= Self.noFaceThreshold
        if walkAway { didTrigger = true }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if walkAway {
                self.walkAwayDetected()
            } else {
                self.handleFaceResult(faceFound: faceFound)
            }
        }
    }
}
