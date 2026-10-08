import Foundation
import Testing
@testable import HexyCore

private func freshDefaults() -> UserDefaults {
    let name = "HexyThingTests-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: name)!
    d.removePersistentDomain(forName: name)
    return d
}

@Test func addsNewestFirst() {
    let h = History(defaults: freshDefaults())
    h.add("#111111")
    h.add("#222222")
    #expect(h.items == ["#222222", "#111111"])
}

@Test func capsAtTen() {
    let h = History(defaults: freshDefaults())
    for i in 0..<12 { h.add(String(format: "#%06X", i)) }
    #expect(h.items.count == 10)
    #expect(h.items.first == "#00000B")
    #expect(h.items.last == "#000002")
}

@Test func duplicateMovesToTop() {
    let h = History(defaults: freshDefaults())
    h.add("#111111")
    h.add("#222222")
    h.add("#111111")
    #expect(h.items == ["#111111", "#222222"])
}

@Test func persistsAcrossInstances() {
    let d = freshDefaults()
    History(defaults: d).add("#ABCDEF")
    #expect(History(defaults: d).items == ["#ABCDEF"])
}

@Test func clearEmpties() {
    let d = freshDefaults()
    let h = History(defaults: d)
    h.add("#ABCDEF")
    h.clear()
    #expect(h.items.isEmpty)
    #expect(History(defaults: d).items.isEmpty)
}
