import SwiftUI
import AppKit
import SajuKit

/// 디자인 토큰 — "만세력 원전의 활자 조판".
///
/// 오행 잉크 팔레트는 dataviz 6종 검사(명도 밴드·채도 하한·CVD 분리·
/// 정상 시각 하한·표면 대비)를 라이트/다크 각각 통과했다.
/// 동방 목(木)은 오방색 고증대로 청(靑) — 청록으로 표현한다.
enum Ink {
    /// 오행 잉크색 (라이트/다크 검증 쌍).
    static func element(_ element: Element) -> Color {
        switch element {
        case .wood: dynamic(light: 0x00876B, dark: 0x0F9078)
        case .fire: dynamic(light: 0xEE7038, dark: 0xE56636)
        case .earth: dynamic(light: 0x7F5502, dark: 0x95670A)
        case .metal: dynamic(light: 0x8898EC, dark: 0x379FC4)
        case .water: dynamic(light: 0x2E4E9C, dark: 0x6866D4)
        }
    }

    /// 오행 배경 워시 — 잉크의 저채도 판.
    static func wash(_ element: Element) -> Color {
        Ink.element(element).opacity(0.10)
    }

    /// 한지 카드 표면.
    static let paper = dynamic(light: 0xFAF7F0, dark: 0x262320)
    /// 주사(朱砂) 액센트.
    static let cinnabar = dynamic(light: 0xB43A2E, dark: 0xD05A48)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// 치수 토큰.
enum Measure {
    /// 읽기 열의 최대 폭. 좌우 패딩 18을 포함한다.
    ///
    /// 본문 524pt ≈ 한글 40 글리프다. WCAG 2.2 SC 1.4.8의 상한이
    /// "80 characters or glyphs (**40 if CJK**)"이고, 근거는 CJK 글자가
    /// 라틴 글자의 약 두 배 폭이라는 것이다.
    ///
    /// 세 계산이 같은 값으로 수렴해서 고른 값이다.
    /// - 한글 40 글리프 × 13pt(`.body`, 전각) = 520pt
    /// - 라틴 80자 × 약 0.5em × 13pt = 520pt
    /// - ChatGPT의 실측 `--thread-content-max-width: 40rem` = 40em × 13pt = 520pt
    ///
    /// 고치기 전 상담 화면은 본문이 632pt ≈ 48.6 글리프로 상한을 21%
    /// 넘었다. 눈으로 고른 값이 아니라 재서 나온 값이다.
    /// 근거는 docs/research/consultation-ux.md.
    static let reading: CGFloat = 560
}

extension Font {
    /// 한자 전용 명조 활자. AppleMyungjo가 없으면 시스템 세리프로.
    static func hanja(size: CGFloat) -> Font {
        if NSFont(name: "AppleMyungjo", size: size) != nil {
            return .custom("AppleMyungjo", size: size)
        }
        return .system(size: size, design: .serif)
    }
}

/// 한지 카드 배경 스타일.
struct PaperCard: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Ink.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 1)
            )
    }
}

extension View {
    func paperCard(padding: CGFloat = 16) -> some View {
        modifier(PaperCard(padding: padding))
    }
}
