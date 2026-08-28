import SwiftUI

/// Single colour accessor. Tokens live in the asset catalog; no hex literals here.
enum GaugePalette {
    static let background = Color("gmt_background")
    static let surface = Color("gmt_surface")
    static let ink = Color("gmt_ink")
    static let accent = Color("gmt_accent")
    static let muted = Color("gmt_muted")
}
