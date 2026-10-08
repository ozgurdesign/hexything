import Foundation

public final class History {
    public static let limit = 10

    private let defaults: UserDefaults
    private let key: String
    public private(set) var items: [String]

    public init(defaults: UserDefaults = .standard, key: String = "history") {
        self.defaults = defaults
        self.key = key
        self.items = defaults.stringArray(forKey: key) ?? []
    }

    public func add(_ hex: String) {
        items.removeAll { $0 == hex }
        items.insert(hex, at: 0)
        if items.count > Self.limit { items.removeLast(items.count - Self.limit) }
        defaults.set(items, forKey: key)
    }

    public func clear() {
        items = []
        defaults.set(items, forKey: key)
    }
}
