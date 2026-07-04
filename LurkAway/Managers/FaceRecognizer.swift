import Vision
import CoreImage
import CoreVideo
import Foundation

/// On-device owner recognition. Vision has no public face-identity API, so we detect the
/// face, crop it, and compare Vision image feature prints of the crop. No model is bundled
/// (Vision ships with macOS); enrollment stores a few small feature prints locally.
enum FaceRecognizer {
    /// Lower distance = more similar. Tuned for cropped-face image feature prints.
    nonisolated static let matchThreshold: Float = 18.0

    private nonisolated static let ciContext = CIContext()

    private nonisolated static var storeURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LurkAway", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("owner-face.dat")
    }

    nonisolated static var isEnrolled: Bool {
        FileManager.default.fileExists(atPath: storeURL.path)
    }

    /// A feature print of the largest face in a frame, or nil if no face is present.
    nonisolated static func featurePrint(from pixelBuffer: CVPixelBuffer) -> VNFeaturePrintObservation? {
        let faceRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        guard (try? handler.perform([faceRequest])) != nil else { return nil }

        guard let face = largest(of: faceRequest.results ?? []) else { return nil }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        var rect = VNImageRectForNormalizedRect(face.boundingBox,
                                                Int(image.extent.width), Int(image.extent.height))
        rect = rect.insetBy(dx: -rect.width * 0.15, dy: -rect.height * 0.15).intersection(image.extent)
        guard !rect.isNull, rect.width > 20, rect.height > 20,
              let cgImage = ciContext.createCGImage(image, from: rect) else { return nil }

        let printRequest = VNGenerateImageFeaturePrintRequest()
        let printHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? printHandler.perform([printRequest])) != nil else { return nil }
        return printRequest.results?.first as? VNFeaturePrintObservation
    }

    nonisolated static func matches(_ probe: VNFeaturePrintObservation,
                                    against enrolled: [VNFeaturePrintObservation]) -> Bool {
        for reference in enrolled {
            var distance = Float.greatestFiniteMagnitude
            if (try? probe.computeDistance(&distance, to: reference)) != nil, distance < matchThreshold {
                return true
            }
        }
        return false
    }

    nonisolated static func load() -> [VNFeaturePrintObservation] {
        guard let data = try? Data(contentsOf: storeURL),
              let prints = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(
                ofClass: VNFeaturePrintObservation.self, from: data) else {
            return []
        }
        return prints
    }

    nonisolated static func save(_ prints: [VNFeaturePrintObservation]) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: prints, requiringSecureCoding: true) else {
            return
        }
        try? data.write(to: storeURL)
    }

    nonisolated static func clear() {
        try? FileManager.default.removeItem(at: storeURL)
    }

    private nonisolated static func largest(of faces: [VNFaceObservation]) -> VNFaceObservation? {
        var best: VNFaceObservation?
        var bestArea: CGFloat = 0
        for face in faces {
            let area = face.boundingBox.width * face.boundingBox.height
            if area > bestArea { bestArea = area; best = face }
        }
        return best
    }
}
