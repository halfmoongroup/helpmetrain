import SwiftUI

enum AppTheme {
    static let background = Color(hex: 0x000000)
    static let primaryAccent = Color(hex: 0x59BEF7)
    static let chartAccent = Color(hex: 0x77CDE9)
    static let dialTrack = Color(hex: 0x212121)
    static let guideLine = Color(hex: 0x3E3E40)
    static let topBarIcon = Color(hex: 0x85BFD1)
    static let selectedTabText = Color(hex: 0xEDEDED)
    static let unselectedTabText = Color(hex: 0x808083)
    static let secondaryText = Color(hex: 0x808083)
    static let dayLabel = Color(hex: 0xA3ACAE)
    static let capsuleBorder = Color(hex: 0xF4F8FD)
    static let capsuleFill = Color(hex: 0x1C2022)
    static let pointMarker = Color(hex: 0xFFFFFF)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
