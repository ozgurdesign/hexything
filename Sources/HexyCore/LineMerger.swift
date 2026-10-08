import CoreGraphics

/// OCR splits widely spaced text (`58      123      213`) into separate fragments.
/// Joins fragments that share a row, left to right, so values can be matched as one line.
public enum LineMerger {
    /// Fragments further apart than this many line heights stay separate.
    static let maxGapInLineHeights: CGFloat = 3

    /// - Parameter aspect: image width ÷ height, to compare horizontal gaps with line heights.
    public static func merge(_ lines: [RecognizedLine], aspect: CGFloat) -> [RecognizedLine] {
        let items = lines
            .map { (line: $0, box: $0.boxForRange($0.text.startIndex..<$0.text.endIndex)) }
            .sorted { $0.box.minX < $1.box.minX }
        var groups: [[(line: RecognizedLine, box: CGRect)]] = []
        for item in items {
            if let i = groups.firstIndex(where: { sameRow($0.last!.box, item.box, aspect: aspect) }) {
                groups[i].append(item)
            } else {
                groups.append([item])
            }
        }
        return groups.map { $0.count == 1 ? $0[0].line : join($0.map(\.line)) }
    }

    private static func sameRow(_ a: CGRect, _ b: CGRect, aspect: CGFloat) -> Bool {
        let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        let shorter = min(a.height, b.height)
        guard shorter > 0, overlap >= shorter / 2 else { return false }
        let gap = (b.minX - a.maxX) * aspect
        return gap <= maxGapInLineHeights * max(a.height, b.height)
    }

    private static func join(_ parts: [RecognizedLine]) -> RecognizedLine {
        let text = parts.map(\.text).joined(separator: " ")
        var offsets: [Int] = []
        var cursor = 0
        for p in parts {
            offsets.append(cursor)
            cursor += p.text.count + 1
        }
        return RecognizedLine(text: text) { range in
            let lo = text.distance(from: text.startIndex, to: range.lowerBound)
            let hi = text.distance(from: text.startIndex, to: range.upperBound)
            var box: CGRect?
            for (part, start) in zip(parts, offsets) {
                let from = max(lo, start) - start
                let to = min(hi, start + part.text.count) - start
                guard from < to else { continue }
                let sub = part.text.index(part.text.startIndex, offsetBy: from)..<part.text.index(part.text.startIndex, offsetBy: to)
                let b = part.boxForRange(sub)
                box = box.map { $0.union(b) } ?? b
            }
            return box ?? parts.map { $0.boxForRange($0.text.startIndex..<$0.text.endIndex) }.reduce(CGRect.null) { $0.union($1) }
        }
    }
}
