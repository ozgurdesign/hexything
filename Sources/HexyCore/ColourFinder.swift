import CoreGraphics
import Foundation

public struct RecognizedLine {
    public let text: String
    /// Bounding box for a substring, in normalized image coordinates (origin bottom-left).
    public let boxForRange: (Range<String.Index>) -> CGRect

    public init(text: String, boxForRange: @escaping (Range<String.Index>) -> CGRect) {
        self.text = text
        self.boxForRange = boxForRange
    }
}

public struct ColourMatch: Equatable {
    /// What gets copied and saved: normalized hex, a CSS function as written, or bare/labelled values as CSS.
    public let text: String
    public let colour: RGBA
    public let box: CGRect
    /// Unlabelled values like `6, 93, 71`, which could be RGB or HSL.
    public let isBare: Bool

    public init(text: String, colour: RGBA, box: CGRect, isBare: Bool = false) {
        self.text = text
        self.colour = colour
        self.box = box
        self.isBare = isBare
    }
}

public enum ColourFinder {
    public typealias Candidate = (text: String, colour: RGBA, range: Range<String.Index>, isBare: Bool)

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static let num = #"(\d{1,3}(?:\.\d+)?)"#
    private static let sep = #"(?:\s*,\s*|\s+)"#
    // Bare triplets must not touch other numbers, words, or a function's parentheses.
    private static let bareStart = #"(?<![\w.%/#(-])"#
    private static let bareEnd = #"(?![\w.%)])"#

    // Optional '#', 3–8 alphanumerics, not touching other alphanumerics or '#'.
    private static let hexToken = regex("(?<![A-Za-z0-9#])#?[A-Za-z0-9]{3,8}(?![A-Za-z0-9])")
    private static let function = regex(#"(?<![A-Za-z])(rgba?|hsla?)\(([^()]*)\)"#)
    private static let bareRGB = regex(bareStart + #"(\d{1,3})"# + sep + #"(\d{1,3})"# + sep + #"(\d{1,3})"# + bareEnd)
    private static let bareHSL = regex(bareStart + num + "(?:deg)?" + sep + num + "%" + sep + num + "%" + bareEnd)
    private static let labelledRGB = regex(
        #"(?<![A-Za-z])R\s*:?\s*(\d{1,3})\s*,?\s*G\s*:?\s*(\d{1,3})\s*,?\s*B\s*:?\s*(\d{1,3})(?![\w.%])"#
    )
    // Requires an L, so HSB values (H S B) never match.
    private static let labelledHSL = regex(
        #"(?<![A-Za-z])H\s*:?\s*"# + num + #"\s*(?:°|deg)?\s*,?\s*S\s*:?\s*"# + num + #"\s*%?\s*,?\s*L\s*:?\s*"# + num + #"\s*%?(?![\w.])"#
    )

    private static let ocrFixes: [Character: Character] = ["O": "0", "o": "0", "l": "1", "I": "1"]

    /// - Parameter bareAsHSL: read unlabelled triplets without `%` (`6, 93, 71`) as HSL, falling back to RGB
    ///   when the values cannot be HSL.
    public static func candidates(in text: String, bareAsHSL: Bool = false) -> [Candidate] {
        var all: [Candidate] = []
        all += matches(hexToken, in: text) { m in
            normalizeHex(m[0]).flatMap { hex in ColourParser.parse(hex).map { (hex, $0) } }
        }
        all += matches(function, in: text) { m in
            let fixedArgs = String(m[2].map { ocrFixes[$0] ?? $0 })
            let tidied = m[1] + "(" + tidy(fixedArgs) + ")"
            return ColourParser.parse(tidied).map { (tidied, $0) }
        }
        all += matches(bareRGB, in: text, bare: true) { m in
            let rgb = "rgb(\(m[1]), \(m[2]), \(m[3]))"
            return bareAsHSL ? css("hsl(\(m[1]), \(m[2])%, \(m[3])%)") ?? css(rgb) : css(rgb)
        }
        all += matches(labelledRGB, in: text) { m in css("rgb(\(m[1]), \(m[2]), \(m[3]))") }
        all += matches(bareHSL, in: text) { m in css("hsl(\(m[1]), \(m[2])%, \(m[3])%)") }
        all += matches(labelledHSL, in: text) { m in css("hsl(\(m[1]), \(m[2])%, \(m[3])%)") }

        // Where matches overlap (a bare triplet inside rgb(…)), the longest wins.
        let longestFirst = all.sorted { text.distance(from: $0.range.lowerBound, to: $0.range.upperBound)
            > text.distance(from: $1.range.lowerBound, to: $1.range.upperBound) }
        var kept: [Candidate] = []
        for c in longestFirst where !kept.contains(where: { $0.range.overlaps(c.range) }) {
            kept.append(c)
        }
        return kept.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    public static func nearest(in lines: [RecognizedLine], to point: CGPoint, bareAsHSL: Bool = false) -> ColourMatch? {
        var best: (match: ColourMatch, distance: CGFloat)?
        for line in lines {
            for c in candidates(in: line.text, bareAsHSL: bareAsHSL) {
                let box = line.boxForRange(c.range)
                let d = distance(from: point, to: box)
                if best == nil || d < best!.distance {
                    best = (ColourMatch(text: c.text, colour: c.colour, box: box, isBare: c.isBare), d)
                }
            }
        }
        return best?.match
    }

    /// Runs a regex and maps each match's capture groups (index 0 is the whole match) to a candidate.
    private static func matches(
        _ re: NSRegularExpression, in text: String, bare: Bool = false, _ make: ([String]) -> (String, RGBA)?
    ) -> [Candidate] {
        re.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { m in
            guard let range = Range(m.range, in: text) else { return nil }
            let groups = (0..<m.numberOfRanges).map { i in
                Range(m.range(at: i), in: text).map { String(text[$0]) } ?? ""
            }
            return make(groups).map { ($0.0, $0.1, range, bare) }
        }
    }

    private static func css(_ s: String) -> (String, RGBA)? {
        ColourParser.parse(s).map { (s, $0) }
    }

    /// Collapses OCR spacing: `58,123,  213` → `58, 123, 213`, `213/ 50%` → `213 / 50%`.
    private static func tidy(_ args: String) -> String {
        var s = args.replacingOccurrences(of: #"\s*,\s*"#, with: ", ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s*/\s*"#, with: " / ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    static func normalizeHex(_ raw: String) -> String? {
        let hasHash = raw.hasPrefix("#")
        let body = hasHash ? String(raw.dropFirst()) : raw
        guard [3, 4, 6, 8].contains(body.count) else { return nil }
        if !hasHash {
            // Bare tokens need a digit, or must be all uppercase (hex tables), so words like "facade" stay out.
            guard body.count != 3 && body.count != 4,
                  body.contains(where: \.isNumber) || body == body.uppercased() else { return nil }
        }
        let fixed = String(body.map { ocrFixes[$0] ?? $0 }).uppercased()
        guard fixed.allSatisfy(\.isHexDigit) else { return nil }
        let full = (fixed.count == 3 || fixed.count == 4) ? fixed.map { "\($0)\($0)" }.joined() : fixed
        return "#" + full
    }

    private static func distance(from p: CGPoint, to r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
