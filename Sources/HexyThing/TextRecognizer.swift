import CoreGraphics
import HexyCore
import Vision

enum TextRecognizer {
    /// The first Vision request is slow (~180 ms in the spike); pay it at launch, not on first hover.
    static func warmUp() {
        DispatchQueue.global(qos: .utility).async {
            let ctx = CGContext(data: nil, width: 64, height: 16, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 16))
            _ = recognize(ctx.makeImage()!)
        }
    }

    static func recognize(_ image: CGImage) -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedLine(text: candidate.string) { range in
                (try? candidate.boundingBox(for: range))?.boundingBox ?? observation.boundingBox
            }
        }
    }
}
