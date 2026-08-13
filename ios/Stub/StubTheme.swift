import SwiftUI

struct StubPalette {
    let canvas: Color
    let surface: Color
    let elevated: Color
    let sunken: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let brand: Color
    let brandPressed: Color
    let brandSoft: Color
    let brandOnSoft: Color
    let memory: Color
    let memorySoft: Color
    let border: Color
    let strongBorder: Color
    let success: Color

    init(_ scheme: ColorScheme) {
        if scheme == .dark {
            canvas = Color(hex: 0x171410)
            surface = Color(hex: 0x24201B)
            elevated = Color(hex: 0x2D2822)
            sunken = Color(hex: 0x100E0C)
            primaryText = Color(hex: 0xF6F0E5)
            secondaryText = Color(hex: 0xC6BCAF)
            tertiaryText = Color(hex: 0xAAA094)
            brand = Color(hex: 0xB94738)
            brandPressed = Color(hex: 0x96372B)
            brandSoft = Color(hex: 0x4A2721)
            brandOnSoft = Color(hex: 0xFFB6A5)
            memory = Color(hex: 0xE6BE70)
            memorySoft = Color(hex: 0x493B23)
            border = Color(hex: 0x4D443B)
            strongBorder = Color(hex: 0x776B60)
            success = Color(hex: 0x71B78F)
        } else {
            canvas = Color(hex: 0xF6F1E7)
            surface = Color(hex: 0xFFFDF8)
            elevated = Color(hex: 0xFFFFFC)
            sunken = Color(hex: 0xEEE7DC)
            primaryText = Color(hex: 0x282421)
            secondaryText = Color(hex: 0x6D6258)
            tertiaryText = Color(hex: 0x756A60)
            brand = Color(hex: 0xB94738)
            brandPressed = Color(hex: 0x96372B)
            brandSoft = Color(hex: 0xF2D9D1)
            brandOnSoft = Color(hex: 0x8F3329)
            memory = Color(hex: 0x8B5F12)
            memorySoft = Color(hex: 0xF3E5C5)
            border = Color(hex: 0xD6CBBC)
            strongBorder = Color(hex: 0x9D9183)
            success = Color(hex: 0x35674F)
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

struct StubLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .zh
}

extension EnvironmentValues {
    var stubLanguage: AppLanguage {
        get { self[StubLanguageKey.self] }
        set { self[StubLanguageKey.self] = newValue }
    }
}

extension View {
    func stubPaperCard(_ palette: StubPalette, radius: CGFloat = 16) -> some View {
        padding(16)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(palette.border, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.08), radius: 14, y: 7)
    }

    func stubScreenBackground(_ palette: StubPalette) -> some View {
        background(palette.canvas.ignoresSafeArea())
    }

    @ViewBuilder
    func stubNavigationBarHidden() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func stubInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

enum StubDateFormatter {
    static func monthEyebrow(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM · yyyy"
        return formatter.string(from: date).uppercased()
    }

    static func month(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = language == .zh ? "M月" : "LLLL"
        return formatter.string(from: date)
    }

    static func short(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = language == .zh ? "yyyy/MM/dd" : "MMM d, yyyy"
        return formatter.string(from: date)
    }

    static func year(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
}
