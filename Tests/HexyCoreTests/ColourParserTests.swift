import Testing
@testable import HexyCore

@Test func parsesHex() {
    #expect(ColourParser.parse("#3A7BD5") == RGBA(r: 58, g: 123, b: 213))
}

@Test func parsesHexWithAlpha() {
    #expect(ColourParser.parse("#3A7BD580") == RGBA(r: 58, g: 123, b: 213, a: 128.0 / 255))
}

@Test func parsesRgbFunctions() {
    #expect(ColourParser.parse("rgb(58, 123, 213)") == RGBA(r: 58, g: 123, b: 213))
    #expect(ColourParser.parse("rgba(58 123 213 / 50%)") == RGBA(r: 58, g: 123, b: 213, a: 0.5))
    #expect(ColourParser.parse("rgb(100%, 0%, 0%)") == RGBA(r: 255, g: 0, b: 0))
}

@Test func parsesHslFunctions() {
    #expect(ColourParser.parse("hsl(210, 64%, 53%)") == RGBA(r: 58, g: 135, b: 212))
    #expect(ColourParser.parse("hsla(0, 100%, 50%, 0.25)") == RGBA(r: 255, g: 0, b: 0, a: 0.25))
}

@Test func rejectsGarbage() {
    #expect(ColourParser.parse("hello") == nil)
    #expect(ColourParser.parse("rgb(1, 2)") == nil)
    #expect(ColourParser.parse("#12345") == nil)
}

@Test func parsesShortHexForms() {
    #expect(ColourParser.parse("#F00") == RGBA(r: 255, g: 0, b: 0))
    #expect(ColourParser.parse("#F00A") == RGBA(r: 255, g: 0, b: 0, a: 170.0 / 255))
}
