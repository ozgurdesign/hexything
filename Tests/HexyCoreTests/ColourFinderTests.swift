import CoreGraphics
import Testing
@testable import HexyCore

private func hexes(_ s: String) -> [String] {
    ColourFinder.candidates(in: s).map(\.text)
}

@Test func findsSixDigitWithHash() {
    #expect(hexes("--brand-blue: #3A7BD5;") == ["#3A7BD5"])
}

@Test func uppercasesLowercaseInput() {
    #expect(hexes("color: #ff6b6b") == ["#FF6B6B"])
}

@Test func findsEightDigit() {
    #expect(hexes("#A1B2C3D4") == ["#A1B2C3D4"])
}

@Test func expandsThreeDigitWithHash() {
    #expect(hexes("#0F0") == ["#00FF00"])
}

@Test func rejectsThreeDigitWithoutHash() {
    #expect(hexes("use 0F0 here") == [])
}

@Test func acceptsBareSixDigitWithADigit() {
    #expect(hexes("Fill 1E1E1E 100%") == ["#1E1E1E"])
}

@Test func rejectsBareWordWithoutDigits() {
    #expect(hexes("added facade") == [])
}

@Test func acceptsLetterOnlyWithHash() {
    #expect(hexes("#facade") == ["#FACADE"])
}

@Test func rejectsBareWordThatOnlyBecomesHexAfterFixes() {
    #expect(hexes("coffee") == [])
}

@Test func rejectsPartOfLongerToken() {
    #expect(hexes("#3A7BD5Z abc1234567") == [])
}

@Test func rejectsFiveAndSevenLengths() {
    #expect(hexes("#12345 #1234567") == [])
}

@Test func appliesOcrFixesInsideToken() {
    #expect(hexes("#O0l1aa") == ["#0011AA"])
    #expect(hexes("#AIB2C3") == ["#A1B2C3"])
}

@Test func findsMultipleInOrder() {
    #expect(hexes("#FFF and #000000") == ["#FFFFFF", "#000000"])
}

// Each character occupies 0.1 of width on a line at y 0.4…0.6.
private func line(_ text: String, y: CGFloat = 0.4) -> RecognizedLine {
    RecognizedLine(text: text) { range in
        let start = CGFloat(text.distance(from: text.startIndex, to: range.lowerBound))
        let len = CGFloat(text.distance(from: range.lowerBound, to: range.upperBound))
        return CGRect(x: start * 0.1, y: y, width: len * 0.1, height: 0.2)
    }
}

@Test func nearestPicksClosestToPoint() {
    // "#111111 #222222": first spans x 0…0.7, second x 0.8…1.5
    let l = line("#111111 #222222")
    #expect(ColourFinder.nearest(in: [l], to: CGPoint(x: 0.1, y: 0.5))?.text == "#111111")
    #expect(ColourFinder.nearest(in: [l], to: CGPoint(x: 1.2, y: 0.5))?.text == "#222222")
}

@Test func nearestAcrossLines() {
    let top = line("#AAAAAA", y: 0.8)
    let bottom = line("#BBBBBB", y: 0.0)
    #expect(ColourFinder.nearest(in: [top, bottom], to: CGPoint(x: 0.3, y: 0.1))?.text == "#BBBBBB")
}

@Test func nearestReturnsBox() {
    let m = ColourFinder.nearest(in: [line("x #123456")], to: CGPoint(x: 0.5, y: 0.5))
    #expect(m?.text == "#123456")
    #expect(m?.box == CGRect(x: 2 * 0.1, y: 0.4, width: 7 * 0.1, height: 0.2))
    #expect(m?.colour == RGBA(r: 0x12, g: 0x34, b: 0x56))
}

@Test func nearestNilWhenNoHex() {
    #expect(ColourFinder.nearest(in: [line("no colours")], to: .zero) == nil)
}

// MARK: rgb() and hsl() functions

@Test func findsRgbFunctionAsWritten() {
    #expect(hexes("color: rgb(58, 123, 213);") == ["rgb(58, 123, 213)"])
}

@Test func tidiesOcrSpacingInFunctions() {
    #expect(hexes("rgb(58,123,  213)") == ["rgb(58, 123, 213)"])
}

@Test func findsModernRgbaWithSlashAlpha() {
    let c = ColourFinder.candidates(in: "rgba(58 123 213 / 50%)")
    #expect(c.map(\.text) == ["rgba(58 123 213 / 50%)"])
    #expect(c.first?.colour == RGBA(r: 58, g: 123, b: 213, a: 0.5))
}

@Test func findsHslFunctionAndConvertsColour() {
    let c = ColourFinder.candidates(in: "hsl(210, 64%, 53%)")
    #expect(c.map(\.text) == ["hsl(210, 64%, 53%)"])
    #expect(c.first?.colour == RGBA(r: 58, g: 135, b: 212))
}

@Test func findsModernHslWithDegAndAlpha() {
    let c = ColourFinder.candidates(in: "hsl(210deg 64% 53% / 0.5)")
    #expect(c.map(\.text) == ["hsl(210deg 64% 53% / 0.5)"])
    #expect(c.first?.colour == RGBA(r: 58, g: 135, b: 212, a: 0.5))
}

@Test func rejectsOutOfRangeFunctions() {
    #expect(hexes("rgb(300, 0, 0) hsl(400, 50%, 50%) hsl(210, 120%, 50%)") == [])
}

@Test func rejectsHslFunctionWithoutPercents() {
    #expect(hexes("hsl(210, 64, 53)") == [])
}

// MARK: bare triplets

@Test func findsBareRgbTripletAsCss() {
    #expect(hexes("58, 123, 213") == ["rgb(58, 123, 213)"])
    #expect(hexes("58 123 213") == ["rgb(58, 123, 213)"])
    #expect(hexes("58,123, 213") == ["rgb(58, 123, 213)"])
}

@Test func rejectsBareTripletOutOfRange() {
    #expect(hexes("300 20 20") == [])
}

@Test func rejectsBareTripletInsideLongerNumbers() {
    #expect(hexes("2026 10 08") == [])
    #expect(hexes("1.5 2 3") == [])
}

@Test func findsBareHslTripletWhenPercents() {
    let c = ColourFinder.candidates(in: "210 64% 53%")
    #expect(c.map(\.text) == ["hsl(210, 64%, 53%)"])
    #expect(c.first?.colour == RGBA(r: 58, g: 135, b: 212))
}

@Test func functionWinsOverBareTripletInside() {
    #expect(hexes("rgb(58 123 213)") == ["rgb(58 123 213)"])
}

// MARK: labelled values

@Test func findsLabelledRgb() {
    #expect(hexes("R 58 G 123 B 213") == ["rgb(58, 123, 213)"])
    #expect(hexes("R: 58, G: 123, B: 213") == ["rgb(58, 123, 213)"])
}

@Test func findsLabelledHslWithOrWithoutPercents() {
    #expect(hexes("H 210 S 64% L 53%") == ["hsl(210, 64%, 53%)"])
    #expect(hexes("H 210 S 64 L 53") == ["hsl(210, 64%, 53%)"])
}

@Test func ignoresHsbLabels() {
    #expect(hexes("H 210 S 64% B 53%") == [])
}

// MARK: bare triplets read as HSL (⌥ held)

private func hslMode(_ s: String) -> [String] {
    ColourFinder.candidates(in: s, bareAsHSL: true).map(\.text)
}

@Test func bareTripletReadsAsHslWhenAsked() {
    let c = ColourFinder.candidates(in: "6, 93, 71", bareAsHSL: true)
    #expect(c.map(\.text) == ["hsl(6, 93%, 71%)"])
    #expect(c.first?.colour == RGBA(r: 250, g: 126, b: 112))
}

@Test func bareTripletFallsBackToRgbWhenNotValidHsl() {
    #expect(hslMode("240, 128, 128") == ["rgb(240, 128, 128)"])
}

@Test func hslModeLeavesUnambiguousFormsAlone() {
    #expect(hslMode("R 58 G 123 B 213") == ["rgb(58, 123, 213)"])
    #expect(hslMode("rgb(6, 93, 71)") == ["rgb(6, 93, 71)"])
    #expect(hslMode("210 64% 53%") == ["hsl(210, 64%, 53%)"])
    #expect(hslMode("#3A7BD5") == ["#3A7BD5"])
}

@Test func marksOnlyBareTriplets() {
    #expect(ColourFinder.candidates(in: "6, 93, 71").first?.isBare == true)
    #expect(ColourFinder.candidates(in: "rgb(6, 93, 71)").first?.isBare == false)
    #expect(ColourFinder.candidates(in: "R 6 G 93 B 71").first?.isBare == false)
}

@Test func nearestPassesHslModeThrough() {
    let m = ColourFinder.nearest(in: [line("6, 93, 71")], to: CGPoint(x: 0.3, y: 0.5), bareAsHSL: true)
    #expect(m?.text == "hsl(6, 93%, 71%)")
    #expect(m?.isBare == true)
}

// MARK: 4-digit #RGBA

@Test func expandsFourDigitWithHash() {
    let c = ColourFinder.candidates(in: "#f00a")
    #expect(c.map(\.text) == ["#FF0000AA"])
    #expect(c.first?.colour == RGBA(r: 255, g: 0, b: 0, a: 170.0 / 255))
}

@Test func rejectsFourDigitWithoutHash() {
    #expect(hexes("f00a 1a2b") == [])
}

// MARK: bare letter-only hex

@Test func acceptsBareUppercaseLetterOnlyHex() {
    #expect(hexes("FFFFFF") == ["#FFFFFF"])
    #expect(hexes("Hex code DEFACE") == ["#DEFACE"])
}

@Test func rejectsBareLowercaseOrMixedCaseWords() {
    #expect(hexes("ffffff Facade deface") == [])
}

// MARK: OCR misreads of function names

@Test func repairsMisreadRgbFunctionName() {
    #expect(hexes("round: Igb(250, 128, 114);") == ["rgb(250, 128, 114)"])
    #expect(hexes("lgba(0, 0, 0, 0.5)") == ["rgba(0, 0, 0, 0.5)"])
    #expect(hexes("RGB(1, 2, 3)") == ["RGB(1, 2, 3)"])
}
