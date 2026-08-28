import SwiftUI

/// Single type-scale accessor. DIN Alternate Bold for readouts; system for body.
enum GaugeType {
    static func readout(_ style: Font.TextStyle) -> Font {
        .custom("DINAlternate-Bold", size: readoutSize(style), relativeTo: style)
    }

    static let body = Font.body
    static let callout = Font.callout
    static let footnote = Font.footnote
    static let headline = Font.headline
    static let caption = Font.caption

    private static func readoutSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 44
        case .title: 34
        case .title2: 28
        case .title3: 22
        default: 20
        }
    }
}
