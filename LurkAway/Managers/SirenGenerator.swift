import Foundation

/// Synthesizes a loud two-tone siren as an in-memory WAV, so the app ships no binary audio asset.
enum SirenGenerator {
    private static let sampleRate = 44_100.0
    private static let cycleSeconds = 1.2   // one full low→high→low sweep; loops seamlessly

    static func makeWAV() -> Data {
        let frameCount = Int(sampleRate * cycleSeconds)
        var samples = [Int16](repeating: 0, count: frameCount)

        let lowFreq = 600.0
        let highFreq = 1_500.0
        var phase = 0.0

        for i in 0..<frameCount {
            let t = Double(i) / Double(frameCount)
            // Triangle sweep between low and high so the loop endpoint matches the start.
            let sweep = t < 0.5 ? (t * 2.0) : (2.0 - t * 2.0)
            let freq = lowFreq + (highFreq - lowFreq) * sweep
            phase += 2.0 * .pi * freq / sampleRate
            let value = sin(phase)
            samples[i] = Int16(value * Double(Int16.max) * 0.9)
        }

        return wrapWAV(samples: samples)
    }

    private static func wrapWAV(samples: [Int16]) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)

        var data = Data()
        func append(_ string: String) { data.append(contentsOf: string.utf8) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF")
        append32(36 + dataSize)
        append("WAVE")
        append("fmt ")
        append32(16)
        append16(1)                 // PCM
        append16(channels)
        append32(UInt32(sampleRate))
        append32(byteRate)
        append16(blockAlign)
        append16(bitsPerSample)
        append("data")
        append32(dataSize)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}
