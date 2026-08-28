import SwiftUI

/// Shared motion tokens. One easing curve, short durations.
enum GaugeMotion {
    static let duration: Double = 0.28

    static var curve: Animation {
        .easeInOut(duration: duration)
    }

    static func fade(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : curve
    }
}

enum GaugeSpace {
    static let unit: CGFloat = 8
    static let tap: CGFloat = 44
    static let radius: CGFloat = 0

    static func n(_ multiples: CGFloat) -> CGFloat {
        unit * multiples
    }
}

enum GaugeLinks {
    static let contact = URL(string: "https://grammeter.pro/contact-us")!
    static let userAgent = "GramMeter/1.0 (iOS; +https://grammeter.pro)"
    static let demoFlag = "gmt.demo.v1"
}

enum GaugeFormat {
    private static func formatter(fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = 0
        return formatter
    }

    static func energy(_ value: Double) -> String {
        formatter(fractionDigits: 0).string(from: NSNumber(value: value.rounded())) ?? "0"
    }

    static func macro(_ value: Double?) -> String {
        guard let value else { return "—" }
        return formatter(fractionDigits: 1).string(from: NSNumber(value: value)) ?? "—"
    }

    static func unknownMacro(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        return formatter(fractionDigits: 1).string(from: NSNumber(value: value)) ?? "unknown"
    }

    static func mass(_ value: Double) -> String {
        formatter(fractionDigits: 1).string(from: NSNumber(value: value)) ?? "0"
    }

    static func decimal(from raw: String) -> Double? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        return formatter.number(from: raw)?.doubleValue
    }

    static func sanitizeDecimal(_ raw: String) -> String {
        let separator = Locale.current.decimalSeparator ?? "."
        var output = ""
        var seenSeparator = false
        for character in raw {
            if character.isNumber {
                output.append(character)
            } else if String(character) == separator || character == "." || character == "," {
                if !seenSeparator {
                    output.append(contentsOf: separator)
                    seenSeparator = true
                }
            }
        }
        return output
    }
}
