@preconcurrency import AVFoundation
import CoreImage
import AppKit
import os

/// Powers the front camera briefly to grab one compact, readable JPEG of whoever is at the
/// device, then releases it. Optimized for the smallest file that still clearly shows a face:
/// the first few frames are discarded so exposure settles, then the frame is downscaled and
/// JPEG-compressed. Cheap to store and fast to push.
@MainActor
final class EvidenceCaptureManager: NSObject {
    private let captureSession = AVCaptureSession()
    private let sampleQueue = DispatchQueue(label: "dev.djabari.LurkAway.evidence")

    private nonisolated static let settleFrames = 3
    private nonisolated static let targetLongEdge: CGFloat = 800
    private nonisolated static let jpegQuality = 0.5
    private nonisolated static let timeout: TimeInterval = 2.5

    // Accessed only on the serial capture queue.
    private nonisolated let ciContext = CIContext()
    private nonisolated(unsafe) var frameCount = 0
    private nonisolated(unsafe) var continuation: CheckedContinuation<Data?, Never>?

    /// Grabs one settled, compact JPEG. Returns nil if the camera is unauthorized/unavailable
    /// or no frame arrives within the timeout. Releases the camera before returning.
    func snapshot() async -> Data? {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            log.notice("Evidence capture skipped — camera not authorized")
            return nil
        }
        guard configure() else {
            teardown()
            return nil
        }

        return await withCheckedContinuation { cont in
            sampleQueue.async { [weak self] in
                guard let self else { cont.resume(returning: nil); return }
                self.frameCount = 0
                self.continuation = cont
            }
            captureSession.startRunning()
            sampleQueue.asyncAfter(deadline: .now() + Self.timeout) { [weak self] in
                self?.finish(with: nil)
            }
        }
    }

    private func configure() -> Bool {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            log.error("Evidence capture — camera unavailable")
            captureSession.commitConfiguration()
            return false
        }
        captureSession.addInput(input)
        CameraTuning.throttle(device, toFPS: 8)   // settle quickly at low power

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        captureSession.commitConfiguration()
        return true
    }

    /// Resumes the pending continuation exactly once and releases the camera.
    /// Must be called on `sampleQueue`.
    private nonisolated func finish(with data: Data?) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: data)
        Task { @MainActor [weak self] in self?.teardown() }
    }

    private func teardown() {
        if captureSession.isRunning { captureSession.stopRunning() }
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }
    }

    /// Downscale to `targetLongEdge` (aspect-preserving) and JPEG-encode, stripping metadata.
    private nonisolated func encode(_ sampleBuffer: CMSampleBuffer) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let longEdge = max(image.extent.width, image.extent.height)
        let scale = longEdge > Self.targetLongEdge ? Self.targetLongEdge / longEdge : 1.0
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: Self.jpegQuality])
    }
}

extension EvidenceCaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard continuation != nil else { return }   // already finished/timed out
        frameCount += 1
        guard frameCount > Self.settleFrames else { return }
        finish(with: encode(sampleBuffer))
    }
}
