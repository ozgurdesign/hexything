import Foundation

public struct RGBA: Equatable {
    /// Channels 0–255.
    public let r: Int
    public let g: Int
    public let b: Int
    /// Opacity 0–1.
    public let a: Double

    public init(r: Int, g: Int, b: Int, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

/// Parses saved colour strings: `#RRGGBB`, `#RRGGBBAA`, and CSS `rgb()`, `rgba()`, `hsl()`, `hsla()`.
public enum ColourParser {
    public static func parse(_ string: String) -> RGBA? {
        let s = string.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { return hex(String(s.dropFirst())) }
        guard let open = s.firstIndex(of: "("), s.hasSuffix(")") else { return nil }
        let args = String(s[s.index(after: open)..<s.index(before: s.endIndex)])
        switch s[..<open].lowercased() {
        case "rgb", "rgba": return rgb(args)
        case "hsl", "hsla": return hsl(args)
        default: return nil
        }
    }

    static func hex(_ body: String) -> RGBA? {
        let expanded = (body.count == 3 || body.count == 4) ? body.map { "\($0)\($0)" }.joined() : body
        guard expanded.count == 6 || expanded.count == 8, expanded.allSatisfy(\.isHexDigit),
              let v = UInt64(expanded, radix: 16) else { return nil }
        let hasAlpha = expanded.count == 8
        let shift: UInt64 = hasAlpha ? 8 : 0
        return RGBA(
            r: Int((v >> (16 + shift)) & 0xFF),
            g: Int((v >> (8 + shift)) & 0xFF),
            b: Int((v >> shift) & 0xFF),
            a: hasAlpha ? Double(v & 0xFF) / 255 : 1
        )
    }

    /// Splits `58, 123, 213`, `58 123 213 / 50%` or `58, 123, 213, 0.5` into three channels and an optional alpha.
    private static func split(_ args: String) -> (channels: [String], alpha: String?)? {
        let parts = args.components(separatedBy: "/")
        guard parts.count <= 2 else { return nil }
        let tokens = parts[0].split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init)
        if parts.count == 2 {
            let alpha = parts[1].trimmingCharacters(in: .whitespaces)
            guard tokens.count == 3, !alpha.isEmpty else { return nil }
            return (tokens, alpha)
        }
        switch tokens.count {
        case 3: return (tokens, nil)
        case 4: return (Array(tokens.prefix(3)), tokens[3])
        default: return nil
        }
    }

    private static func number(_ token: String, max: Double) -> Double? {
        guard let v = Double(token), v >= 0, v <= max else { return nil }
        return v
    }

    private static func percent(_ token: String) -> Double? {
        guard token.hasSuffix("%") else { return nil }
        return number(String(token.dropLast()), max: 100)
    }

    private static func alpha(_ token: String?) -> Double? {
        guard let token else { return 1 }
        if token.hasSuffix("%") { return percent(token).map { $0 / 100 } }
        return number(token, max: 1)
    }

    private static func rgb(_ args: String) -> RGBA? {
        guard let (channels, a) = split(args), let a = alpha(a) else { return nil }
        let values = channels.compactMap { token -> Int? in
            if token.hasSuffix("%") { return percent(token).map { Int(($0 * 2.55).rounded()) } }
            return number(token, max: 255).map { Int($0.rounded()) }
        }
        guard values.count == 3 else { return nil }
        return RGBA(r: values[0], g: values[1], b: values[2], a: a)
    }

    private static func hsl(_ args: String) -> RGBA? {
        guard let (channels, a) = split(args), let a = alpha(a) else { return nil }
        let hueToken = channels[0].lowercased().hasSuffix("deg") ? String(channels[0].dropLast(3)) : channels[0]
        guard let h = number(hueToken, max: 360), let s = percent(channels[1]), let l = percent(channels[2])
        else { return nil }
        return hslToRGB(h: h, s: s / 100, l: l / 100, a: a)
    }

    static func hslToRGB(h: Double, s: Double, l: Double, a: Double) -> RGBA {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = h.truncatingRemainder(dividingBy: 360) / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let (r1, g1, b1): (Double, Double, Double)
        switch hp {
        case ..<1: (r1, g1, b1) = (c, x, 0)
        case ..<2: (r1, g1, b1) = (x, c, 0)
        case ..<3: (r1, g1, b1) = (0, c, x)
        case ..<4: (r1, g1, b1) = (0, x, c)
        case ..<5: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        let m = l - c / 2
        func byte(_ v: Double) -> Int { Int(((v + m) * 255).rounded()) }
        return RGBA(r: byte(r1), g: byte(g1), b: byte(b1), a: a)
    }
}
