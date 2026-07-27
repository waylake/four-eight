import SwiftUI
import AppKit
import SajuKit

/// README용 스크린샷 생성기.
///
/// 화면 캡처(`screencapture`)는 화면 기록 권한을 요구하고 창 상태에 따라
/// 결과가 흔들린다. 대신 SwiftUI `ImageRenderer`로 실제 뷰 트리를 직접
/// 렌더링한다. 권한이 필요 없고, 같은 입력에 같은 이미지가 나온다.
///
/// 렌더링되는 것은 진짜 앱 화면이다. 창 테두리만 macOS 표준 형태로
/// 합성한다 — ImageRenderer는 OS가 그리는 타이틀바를 포함하지 않는다.
///
/// 실행: FOUREIGHT_CAPTURE=<출력 디렉터리> 로 앱을 띄우면 이미지를 쓰고 종료한다.
@MainActor
enum ScreenshotRunner {
    static var requestedPath: String? {
        ProcessInfo.processInfo.environment["FOUREIGHT_CAPTURE"]
    }

    /// 스크린샷에 쓰는 예시 인물. 저장소의 골든 케이스와 같은 값이라
    /// 이미지에 보이는 명식을 테스트로 검증할 수 있다.
    ///
    /// 반드시 저장 프로퍼티여야 한다. 계산 프로퍼티로 두면 접근할 때마다
    /// 새 UUID가 생겨 선택이 어긋난다.
    static let demoPerson = Person(
        name: "예시",
        birth: BirthInput(
            year: 2003, month: 2, day: 22, hour: 13, minute: 13,
            gender: .male, place: .seoul
        )
    )

    struct Shot {
        let name: String
        let size: CGSize
        let view: AnyView
    }

    /// 앱은 샌드박스에서 돈다. 저장소 경로에 직접 쓸 수 없으므로 컨테이너
    /// 안에 쓰고 scripts/shots.sh가 꺼내 간다. 요청 경로는 무시하고
    /// 실제로 쓴 경로를 로그로 알린다.
    static var containerOutput: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FourEight/screenshots", isDirectory: true)
    }

    static func run(outputPath: String) {
        let directory = containerOutput
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("스크린샷: 디렉터리 생성 실패 \(directory.path) — \(error.localizedDescription)")
            NSApp.terminate(nil)
            return
        }

        let state = AppState()
        state.store.replaceAllForCapture([demoPerson])
        // select()는 UserDefaults에 쓴다. 캡처가 사용자 설정을 건드리면 안 된다.
        state.selectedPersonID = demoPerson.id
        state.options = .default
        let modelManager = ModelManager()
        let interpretations = InterpretationStore()

        guard let reading = state.reading else {
            NSLog("스크린샷: 명식 계산 실패")
            NSApp.terminate(nil)
            return
        }

        // 규칙 엔진으로 해석을 미리 채운다. 모델 없이도 화면이 완성된 상태로 보인다.
        interpretations.regenerate(
            key: .init(
                subject: reading.person.id.uuidString,
                signature: reading.chart.signature,
                engine: "template"
            ),
            sections: reading.sections,
            interpreter: TemplateInterpreter()
        )
        let fortune = SajuService.fortune(on: Date(), reading: reading)
        interpretations.regenerate(
            key: .init(
                subject: "\(reading.person.id.uuidString)#\(fortune.date.formatted(.iso8601.year().month().day()))",
                signature: reading.chart.signature,
                engine: "template"
            ),
            sections: fortune.sections,
            interpreter: TemplateInterpreter()
        )

        func wrap<V: View>(_ view: V) -> AnyView {
            AnyView(
                view
                    .environment(state)
                    .environment(modelManager)
                    .environment(interpretations)
                    .background(Color(nsColor: .windowBackgroundColor))
            )
        }

        let shots: [Shot] = [
            Shot(name: "today", size: CGSize(width: 1180, height: 760),
                 view: wrap(CaptureShell { TodayView(reading: reading) })),
            Shot(name: "chart", size: CGSize(width: 1180, height: 760),
                 view: wrap(CaptureShell { ChartWorkspace(reading: reading) })),
            Shot(name: "calendar", size: CGSize(width: 1180, height: 760),
                 view: wrap(CaptureShell { FortuneCalendarView(reading: reading) })),
        ]

        Task { @MainActor in
            // 창을 닫으면 마지막 창일 때 앱이 종료된다. 전부 찍은 뒤 한꺼번에 닫는다.
            var windows: [NSWindow] = []
            var written = 0
            for shot in shots {
                if let window = await render(shot, to: directory) {
                    windows.append(window)
                    written += 1
                }
            }
            windows.forEach { $0.close() }
            NSLog("스크린샷: \(written)/\(shots.count)장 저장 → \(directory.path)")
            NSApp.terminate(nil)
        }
    }

    /// 실제 NSWindow에 뷰를 올리고 뷰 계층을 비트맵으로 뜬다.
    ///
    /// SwiftUI `ImageRenderer`는 순수 SwiftUI 드로잉만 그린다. List나
    /// ScrollView처럼 AppKit이 뒤를 받치는 뷰는 빈 자리로 나온다.
    /// `cacheDisplay(in:to:)`는 뷰 계층을 직접 그리므로 그것들도 담기고,
    /// 화면 버퍼를 읽지 않으니 화면 기록 권한도 필요 없다.
    @MainActor
    private static func render(_ shot: Shot, to directory: URL) async -> NSWindow? {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: shot.size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let hosting = NSHostingView(rootView: shot.view)
        hosting.frame = NSRect(origin: .zero, size: shot.size)
        window.contentView = hosting
        // 화면 밖에 두어 사용자 화면을 가리지 않게 한다.
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()

        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        // 스크롤 뷰와 비동기 레이아웃이 자리 잡을 시간.
        try? await Task.sleep(for: .milliseconds(700))
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        let bounds = hosting.bounds
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: bounds) else {
            NSLog("스크린샷: \(shot.name) 비트맵 생성 실패")
            return window
        }
        hosting.cacheDisplay(in: bounds, to: rep)

        let content = NSImage(size: shot.size)
        content.addRepresentation(rep)

        guard let framed = windowFrame(around: content, contentSize: shot.size),
              let tiff = framed.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            NSLog("스크린샷: \(shot.name) 합성 실패")
            return window
        }

        let url = directory.appendingPathComponent("screenshot-\(shot.name).png")
        do {
            try png.write(to: url)
        } catch {
            NSLog("스크린샷: \(shot.name) 쓰기 실패 — \(error.localizedDescription)")
        }
        return window
    }

    /// macOS 창 테두리 합성 — 둥근 모서리, 타이틀바, 신호등.
    private static func windowFrame(around content: NSImage, contentSize: CGSize) -> NSImage? {
        let scale = 2.0
        let titlebar = 28.0
        let radius = 10.0
        let pad = 24.0
        let total = CGSize(
            width: (contentSize.width + pad * 2) * scale,
            height: (contentSize.height + titlebar + pad * 2) * scale
        )

        guard let ctx = CGContext(
            data: nil, width: Int(total.width), height: Int(total.height),
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.scaleBy(x: scale, y: scale)
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
            CGColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: a
            )
        }

        // 배경.
        ctx.setFillColor(color(isDark ? 0x1B1917 : 0xF2EDE4))
        ctx.fill(CGRect(origin: .zero, size: CGSize(width: total.width / scale, height: total.height / scale)))

        let window = CGRect(
            x: pad, y: pad,
            width: contentSize.width, height: contentSize.height + titlebar
        )
        let windowPath = CGPath(roundedRect: window, cornerWidth: radius, cornerHeight: radius, transform: nil)

        // 그림자.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 22, color: color(0x000000, 0.24))
        ctx.addPath(windowPath)
        ctx.setFillColor(color(isDark ? 0x2A2724 : 0xFFFFFF))
        ctx.fillPath()
        ctx.restoreGState()

        // 콘텐츠.
        ctx.saveGState()
        ctx.addPath(windowPath)
        ctx.clip()
        if let cg = content.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            ctx.draw(cg, in: CGRect(x: pad, y: pad, width: contentSize.width, height: contentSize.height))
        }
        // 타이틀바.
        let bar = CGRect(x: pad, y: pad + contentSize.height, width: contentSize.width, height: titlebar)
        ctx.setFillColor(color(isDark ? 0x322E2A : 0xEDE7DC))
        ctx.fill(bar)
        ctx.setFillColor(color(isDark ? 0x45403A : 0xD8D0C2))
        ctx.fill(CGRect(x: bar.minX, y: bar.minY, width: bar.width, height: 1))
        ctx.restoreGState()

        // 신호등.
        let lights: [UInt32] = [0xFF5F57, 0xFEBC2E, 0x28C840]
        for (i, hex) in lights.enumerated() {
            let dot = CGRect(
                x: pad + 14 + Double(i) * 20, y: bar.midY - 6,
                width: 12, height: 12
            )
            ctx.setFillColor(color(hex))
            ctx.fillEllipse(in: dot)
        }

        // 테두리.
        ctx.addPath(windowPath)
        ctx.setStrokeColor(color(isDark ? 0x000000 : 0x000000, 0.16))
        ctx.setLineWidth(1)
        ctx.strokePath()

        guard let out = ctx.makeImage() else { return nil }
        return NSImage(cgImage: out, size: NSSize(width: total.width / scale, height: total.height / scale))
    }
}

/// 캡처용 껍데기. NavigationSplitView는 ImageRenderer에서 사이드바를
/// 접어버리므로, 사이드바를 직접 배치해 실제 창과 같은 구성을 만든다.
struct CaptureShell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 236)
                .background(Color(nsColor: .controlBackgroundColor))
            Divider()
            content
        }
    }
}

extension PersonStore {
    /// 스크린샷 생성 전용. 디스크에 쓰지 않는다.
    func replaceAllForCapture(_ people: [Person]) {
        setPeopleWithoutPersisting(people)
    }
}
