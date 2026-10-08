import CoreGraphics
import Testing
@testable import HexyCore

// A fragment whose characters each take 0.02 of width, on a row at y…y+0.2.
private func fragment(_ text: String, x: CGFloat, y: CGFloat = 0.4) -> RecognizedLine {
    RecognizedLine(text: text) { range in
        let start = CGFloat(text.distance(from: text.startIndex, to: range.lowerBound))
        let len = CGFloat(text.distance(from: range.lowerBound, to: range.upperBound))
        return CGRect(x: x + start * 0.02, y: y, width: len * 0.02, height: 0.2)
    }
}

// Image is 4× wider than tall, so 0.2 of height equals 0.05 of width.
private let aspect: CGFloat = 4

@Test func mergesFragmentsOnTheSameRowLeftToRight() {
    let lines = [fragment("213", x: 0.24), fragment("58", x: 0.02), fragment("123", x: 0.12)]
    let merged = LineMerger.merge(lines, aspect: aspect)
    #expect(merged.map(\.text) == ["58 123 213"])
}

@Test func mergedLineMapsRangesBackToFragmentBoxes() {
    let merged = LineMerger.merge([fragment("58", x: 0.02), fragment("123", x: 0.12)], aspect: aspect)[0]
    let r = merged.text.range(of: "123")!
    #expect(merged.boxForRange(r) == CGRect(x: 0.12, y: 0.4, width: 3 * 0.02, height: 0.2))
    let all = merged.text.startIndex..<merged.text.endIndex
    let first = CGRect(x: 0.02, y: 0.4, width: 2 * 0.02, height: 0.2)
    let second = CGRect(x: 0.12, y: 0.4, width: 3 * 0.02, height: 0.2)
    #expect(merged.boxForRange(all) == first.union(second))
}

@Test func keepsDifferentRowsApart() {
    let merged = LineMerger.merge([fragment("58", x: 0.02, y: 0.7), fragment("123", x: 0.12, y: 0.1)], aspect: aspect)
    #expect(Set(merged.map(\.text)) == ["58", "123"])
}

@Test func keepsDistantFragmentsApart() {
    // Gap of 0.5 width = 2.0 in height units, i.e. 10 line heights.
    let merged = LineMerger.merge([fragment("58", x: 0.02), fragment("123", x: 0.56)], aspect: aspect)
    #expect(Set(merged.map(\.text)) == ["58", "123"])
}
