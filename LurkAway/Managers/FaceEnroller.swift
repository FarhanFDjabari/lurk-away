@preconcurrency import AVFoundation
import Vision
import os

/// Briefly runs the camera to capture the owner's face feature prints for enrollment.
@MainActor
final class FaceEnroller: NSObject {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "dev.djabari.LurkAway.enroll")
    private var completion: ((Bool) -> Void)?
    private var finished = false

    private nonisolated(unsafe) var collected: [VNFeaturePrintObservation] = []
    private nonisolated static let target = 5

    func enroll(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        self.finished = false
        collected = []

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in granted ? self?.run() : self?.finish(false) }
            }
        default:
            finish(false)
        }
    }

    private func run() {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480   // enough detail for a good feature print
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            finish(false)
            return
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        session.startRunning()

        // Give ~3s to gather samples, then finish.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.complete()
        }
    }

    private func complete() {
        guard !finished else { return }
        let prints = collected
        if prints.count >= 2 {
            FaceRecognizer.save(Array(prints.prefix(Self.target)))
            log.notice("Face enrollment saved \(prints.count) samples")
            finish(true)
        } else {
            log.error("Face enrollment failed — only \(prints.count) face samples")
            finish(false)
        }
    }

    private func finish(_ success: Bool) {
        guard !finished else { return }
        finished = true
        session.stopRunning()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        let done = completion
        completion = nil
        done?(success)
    }
}

extension FaceEnroller: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard collected.count < Self.target,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let print = FaceRecognizer.featurePrint(from: pixelBuffer) else {
            return
        }
        collected.append(print)
    }
}
