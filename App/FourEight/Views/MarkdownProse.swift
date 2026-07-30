import SwiftUI

/// 모델이 쓴 글을 그린다.
///
/// 지시문은 산문을 요구한다(`CounselBrief.instructions`: "제목이나 목록 없이
/// 본문만 씁니다"). 그런데 **모델은 지시를 어긴다.** 4B 모델은 자주 어기고,
/// 원격의 큰 모델도 가끔 어긴다. 어겼을 때 순수 `Text`는 `**신강**`을 그대로
/// 보여 준다 — 앱이 고장 난 것처럼 보인다.
///
/// 이 저장소는 같은 사고를 이미 한 번 겪었다. 업데이트 대화상자의 릴리스
/// 노트에 `**`가 그대로 나갔고, appcast는 append-only여서 되돌릴 수 없었다.
/// 여기서는 되돌릴 수 있지만, 사용자가 보는 화면인 것은 같다.
///
/// **렌더링은 지시문의 대체가 아니다.** 산문을 요구하는 지시는 그대로 두고,
/// 어겼을 때 화면이 깨지지 않게만 한다. 톤 규약은 프롬프트의 일이고 이것은
/// 표시의 일이다.
///
/// 스트리밍 중에도 부른다. 그래서 두 가지를 지킨다.
///
/// - **블록 단위로 자르고 블록 단위로 캐시한다.** 청크마다 글 전체를 다시
///   파싱하면 O(n²)이다. 마지막 블록만 자라므로 앞 블록은 캐시가 받는다.
/// - **닫히지 않은 코드 울타리를 코드로 그린다.** 스트리밍 중에는 여는
///   울타리가 먼저 오고 닫는 울타리가 아직 안 왔다. 이때 원문을 그대로
///   흘리면 문단이 갑자기 코드 블록으로 바뀌었다가 되돌아온다.
struct MarkdownProse: View {
    let text: String
    /// 본문 글꼴. 답변은 `.body`, 앱이 말한 것은 `.callout`.
    var font: Font = .body
    var lineSpacing: CGFloat = 4
    /// 아직 쓰는 중인가. 참이면 **마지막 블록만** 짝이 맞게 고쳐서 그린다.
    var isStreaming = false

    private var blocks: [MarkdownBlock] {
        let parsed = MarkdownBlock.parse(text)
        guard isStreaming, let last = parsed.last else { return parsed }
        return Array(parsed.dropLast()) + [last.balancingUnclosedMarkers()]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                row(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func row(_ block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let raw):
            Text(MarkdownInline.parse(raw))
                .font(font)
                .lineSpacing(lineSpacing)
                .fixedSize(horizontal: false, vertical: true)

        case .heading(let level, let raw):
            // 지시문은 제목을 금지한다. 그래도 나오면 **본문보다 아주 조금만**
            // 크게 그린다. 크게 그리면 어긴 결과가 화면의 주 신호가 된다(§7).
            Text(MarkdownInline.parse(raw))
                .font(level <= 2 ? .headline : .subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

        case .bullet(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    marker("·", item)
                }
            }

        case .ordered(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    marker("\(String(index + 1)).", item)
                }
            }

        case .quote(let raw):
            HStack(alignment: .top, spacing: 9) {
                Rectangle().fill(.tertiary).frame(width: 2)
                Text(MarkdownInline.parse(raw))
                    .font(font)
                    .lineSpacing(lineSpacing)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .code(let raw):
            ScrollView(.horizontal) {
                Text(raw)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(9)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))

        case .rule:
            Divider()
        }
    }

    /// 목록 한 줄. 글머리를 고정 폭으로 잡아 본문 왼쪽이 흔들리지 않게 한다.
    private func marker(_ symbol: String, _ raw: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(symbol)
                .font(font)
                .foregroundStyle(.tertiary)
                .frame(minWidth: 13, alignment: .trailing)
            Text(MarkdownInline.parse(raw))
                .font(font)
                .lineSpacing(lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 블록

/// 글을 블록으로 자른다. 인라인 문법은 건드리지 않는다.
enum MarkdownBlock: Hashable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case bullet([String])
    case ordered([String])
    case quote(String)
    case code(String)
    case rule

    /// 자르기는 순수 문자열 주사이므로 캐시하지 않는다. 비싼 것은 인라인
    /// 파싱이고 그쪽만 캐시한다.
    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var ordered: [String] = []
        var quote: [String] = []
        var code: [String]?

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph = []
        }
        func flushBullets() {
            guard !bullets.isEmpty else { return }
            blocks.append(.bullet(bullets))
            bullets = []
        }
        func flushOrdered() {
            guard !ordered.isEmpty else { return }
            blocks.append(.ordered(ordered))
            ordered = []
        }
        func flushQuote() {
            guard !quote.isEmpty else { return }
            blocks.append(.quote(quote.joined(separator: "\n")))
            quote = []
        }
        func flushAll() {
            flushParagraph(); flushBullets(); flushOrdered(); flushQuote()
        }

        for line in text.components(separatedBy: "\n") {
            // 코드 울타리 안에서는 어떤 문법도 해석하지 않는다.
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if let open = code {
                    blocks.append(.code(open.joined(separator: "\n")))
                    code = nil
                } else {
                    flushAll()
                    code = []
                }
                continue
            }
            if code != nil {
                code?.append(line)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushAll()
                continue
            }
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushAll()
                blocks.append(.rule)
                continue
            }
            if let level = headingLevel(trimmed) {
                flushAll()
                blocks.append(.heading(
                    level: level,
                    text: String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                ))
                continue
            }
            if let item = bulletBody(trimmed) {
                flushParagraph(); flushOrdered(); flushQuote()
                bullets.append(item)
                continue
            }
            if let item = orderedBody(trimmed) {
                flushParagraph(); flushBullets(); flushQuote()
                ordered.append(item)
                continue
            }
            if trimmed.hasPrefix(">") {
                flushParagraph(); flushBullets(); flushOrdered()
                quote.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                continue
            }
            // 목록 항목의 이어지는 줄은 그 항목에 붙인다. 새 문단으로 떼면
            // 글머리 없이 튀어나온 줄이 생긴다.
            if !bullets.isEmpty {
                bullets[bullets.count - 1] += " " + trimmed
                continue
            }
            if !ordered.isEmpty {
                ordered[ordered.count - 1] += " " + trimmed
                continue
            }
            if !quote.isEmpty {
                quote.append(trimmed)
                continue
            }
            paragraph.append(line)
        }

        // 아직 닫히지 않은 울타리. 스트리밍 중에는 정상이다.
        if let code, !code.isEmpty {
            blocks.append(.code(code.joined(separator: "\n")))
        }
        flushAll()
        return blocks
    }

    /// 짝이 안 맞는 강조 기호를 닫아 준다. **스트리밍 중인 마지막 블록에만**
    /// 쓴다.
    ///
    /// 토큰이 한 자씩 오므로 `**신강`이 잠깐 화면에 그대로 뜬다. 닫는 `**`가
    /// 도착하면 굵게로 바뀐다 — 사용자에게는 별표가 깜빡였다가 사라지는 것으로
    /// 보인다. 원문은 그대로 두고 **그리는 사본만** 닫는다.
    ///
    /// 완성된 글에는 쓰지 않는다. 완성된 글의 홀수 별표는 모델이 실제로 쓴
    /// 별표이고, 그것을 닫으면 뒤 문장이 통째로 굵어진다.
    func balancingUnclosedMarkers() -> MarkdownBlock {
        switch self {
        case .paragraph(let raw): .paragraph(Self.balanced(raw))
        case .heading(let level, let raw): .heading(level: level, text: Self.balanced(raw))
        case .quote(let raw): .quote(Self.balanced(raw))
        case .bullet(let items): .bullet(Self.balancingLast(items))
        case .ordered(let items): .ordered(Self.balancingLast(items))
        // 코드 블록은 파서가 원문 그대로 그리므로 손대지 않는다.
        case .code, .rule: self
        }
    }

    private static func balancingLast(_ items: [String]) -> [String] {
        guard let last = items.last else { return items }
        return Array(items.dropLast()) + [balanced(last)]
    }

    /// 인라인 코드 안의 기호는 세지 않는다. 백틱이 열려 있으면 그 안의 `**`는
    /// 강조가 아니라 글자다.
    private static func balanced(_ raw: String) -> String {
        var out = raw
        var inCode = false
        var strong = 0
        var strike = 0
        let characters = Array(raw)
        var index = 0
        while index < characters.count {
            if characters[index] == "`" {
                inCode.toggle()
                index += 1
                continue
            }
            if inCode {
                index += 1
                continue
            }
            if index + 1 < characters.count, characters[index] == "*", characters[index + 1] == "*" {
                strong += 1
                index += 2
                continue
            }
            if index + 1 < characters.count, characters[index] == "~", characters[index + 1] == "~" {
                strike += 1
                index += 2
                continue
            }
            index += 1
        }
        if inCode { out += "`" }
        if strong % 2 == 1 { out += "**" }
        if strike % 2 == 1 { out += "~~" }
        return out
    }

    /// `#`이 1~3개이고 그다음이 공백일 때만 제목이다. `#태그`는 제목이 아니다.
    private static func headingLevel(_ line: String) -> Int? {
        var level = 0
        for character in line {
            if character == "#" { level += 1 } else { break }
        }
        guard (1...3).contains(level), level < line.count else { return nil }
        let next = line[line.index(line.startIndex, offsetBy: level)]
        return next == " " ? level : nil
    }

    /// `- `, `* `, `+ `. 뒤에 공백이 있어야 한다 — `*강조*`가 글머리로
    /// 읽히면 문단 하나가 통째로 목록이 된다.
    private static func bulletBody(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    /// `1. ` 또는 `1) `.
    private static func orderedBody(_ line: String) -> String? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 2 else { return nil }
        let rest = line.dropFirst(digits.count)
        for marker in [". ", ") "] where rest.hasPrefix(marker) {
            return String(rest.dropFirst(marker.count))
        }
        return nil
    }
}

// MARK: - 인라인

/// 굵게·기울임·인라인 코드·링크. **블록 문법은 여기 오지 않는다.**
///
/// `@MainActor`인 이유는 캐시다. `NSCache`는 Sendable이 아니므로 전역으로
/// 두면 Swift 6에서 막힌다. 부르는 곳이 뷰의 `body`뿐이므로 격리로 푼다 —
/// 자물쇠를 새로 만드는 것보다 부르는 자리를 좁히는 편이 낫다.
@MainActor
enum MarkdownInline {
    /// `.inlineOnlyPreservingWhitespace`를 쓴다. 기본값
    /// (`.full`)은 블록 문법까지 먹어 치우면서 줄바꿈을 지우므로,
    /// 문단 안의 줄바꿈이 사라져 두 문장이 한 줄에 붙는다.
    private static let options = AttributedString.MarkdownParsingOptions(
        allowsExtendedAttributes: false,
        interpretedSyntax: .inlineOnlyPreservingWhitespace,
        failurePolicy: .returnPartiallyParsedIfPossible
    )

    /// 스트리밍 중에는 같은 앞 블록이 청크마다 다시 들어온다. 값 하나로
    /// 캐시하면 마지막 블록만 계속 갈리고 앞 블록은 그대로 맞는다.
    ///
    /// `NSCache`를 쓰는 이유는 상한이 필요해서다. 긴 상담을 여러 개 열면
    /// 블록 수가 계속 는다.
    private static let cache: NSCache<NSString, NSAttributedString> = {
        let cache = NSCache<NSString, NSAttributedString>()
        cache.countLimit = 512
        return cache
    }()

    static func parse(_ raw: String) -> AttributedString {
        let key = raw as NSString
        if let hit = cache.object(forKey: key) {
            return AttributedString(hit)
        }
        let parsed = (try? AttributedString(markdown: raw, options: options))
            ?? AttributedString(raw)
        cache.setObject(NSAttributedString(parsed), forKey: key)
        return parsed
    }
}
