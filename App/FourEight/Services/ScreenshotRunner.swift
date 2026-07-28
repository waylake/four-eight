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
        // 캡처는 사용자의 제공자 설정을 읽지 않는다. 빈 UserDefaults를 준다.
        let remoteProvider = RemoteProviderStore(
            defaults: UserDefaults(suiteName: "com.waylake.FourEight.capture") ?? .standard
        )
        let writers = Writers(local: modelManager, remote: remoteProvider)
        // 캡처는 사용자의 보관 파일을 건드리지 않는다. 보존 기한 정리도 돌리지 않는다.
        let interpretations = InterpretationStore(prunesArchive: false)
        let consultations = ConsultationStore()

        guard let reading = state.reading else {
            NSLog("스크린샷: 명식 계산 실패")
            NSApp.terminate(nil)
            return
        }

        // 해석을 미리 채우는 코드가 필요 없어졌다. 기준선 문장은 계산
        // 결과의 일부이므로 화면을 그리는 순간 이미 거기 있다. 스크린샷이
        // 보여주는 것이 첫 실행 사용자가 실제로 보는 화면과 같아졌다.
        //
        // 상담은 예외다. 답변이 있는 화면은 사용자가 버튼을 눌러야 생기므로
        // 캡처 시점에 존재하지 않는다. 그래서 대표 이미지가 빈 폼이었다 —
        // 이 기능의 이미지에 답이 없다는 사실 자체가 신호였다. 완성된 턴을
        // 주입한다. 디스크에는 쓰지 않는다.
        let seeded = demoConsultation(reading: reading)
        consultations.seedForCapture([seeded])
        state.selectedConsultationID = seeded.id

        // 선택 상태가 다른 화면은 **AppState를 따로 만든다.**
        //
        // 처음에는 한 state를 공유하고 `.onAppear`에서 선택을 바꿨는데,
        // 캡처는 렌더 직후 비트맵을 뜨므로 onAppear의 상태 변경이 레이아웃에
        // 반영되기 전에 찍혔다. 결과는 **화면이 통째로 빈 PNG**였다.
        // 스크린샷이 그것을 잡았다. 캡처는 결정론적이어야 한다.
        let newPaneState = AppState()
        newPaneState.store.replaceAllForCapture([demoPerson])
        newPaneState.selectedPersonID = demoPerson.id
        newPaneState.options = .default
        newPaneState.selectedConsultationID = nil

        func wrap<V: View>(_ view: V, state: AppState = state) -> AnyView {
            AnyView(
                view
                    .environment(state)
                    .environment(modelManager)
                    .environment(remoteProvider)
                    .environment(writers)
                    .environment(interpretations)
                    .environment(consultations)
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
            // 답변이 있는 화면이 이 기능의 대표 이미지다. 예전에는 빈 폼만
            // 찍혀 있었고, 이 기능의 이미지에 답이 없다는 사실 자체가
            // 신호였다.
            Shot(name: "consultation", size: CGSize(width: 1180, height: 760),
                 view: wrap(CaptureShell { ConsultationView(reading: reading) })),
            Shot(name: "consultation-new", size: CGSize(width: 1180, height: 760),
                 view: wrap(
                     CaptureShell { ConsultationView(reading: reading) },
                     state: newPaneState
                 )),
        ]

        Task { @MainActor in
            // 창을 닫으면 마지막 창일 때 앱이 종료된다. 전부 찍은 뒤 한꺼번에 정리한다.
            var windows: [NSWindow] = []
            var written = 0
            for shot in shots {
                if let window = await render(shot, to: directory) {
                    windows.append(window)
                    written += 1
                }
            }
            // close()는 창 해제 애니메이션을 태운다. 곧바로 terminate하면
            // 진행 중인 애니메이션이 해제된 객체를 건드려 크래시가 난다.
            // orderOut은 애니메이션 없이 화면에서만 뺀다.
            windows.forEach { $0.orderOut(nil) }
            NSLog("스크린샷: \(written)/\(shots.count)장 저장 → \(directory.path)")
            try? await Task.sleep(for: .milliseconds(200))
            windows.removeAll()
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
    /// 캡처용 상담 하나. 근거 ID는 실제 룰셋에서 고른다 — 없는 ID를 넣으면
    /// 근거 칩이 비어 대표 이미지가 이 앱의 정체성을 보여주지 못한다.
    private static func demoConsultation(reading: Reading) -> Consultation {
        let topic: ConsultationTopic = .career
        let picked = ConsultationRouter.evidence(
            for: topic, facts: reading.facts, ruleSet: SajuService.ruleSet
        )
        let ids = picked.map(\.id)
        let stamp = Date(timeIntervalSince1970: 1_785_000_000)
        return Consultation(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!,
            personID: reading.person.id,
            signature: reading.chart.signature,
            openedAt: stamp,
            concern: "지금 회사를 계속 다녀야 할지 몇 달째 마음이 왔다 갔다 합니다. 옮길 자리가 아주 좋은 것도 아닌데 자꾸 눈이 갑니다.",
            topic: topic,
            matchedTerms: ["회사", "옮길"],
            evidenceIDs: ids,
            includesToday: false,
            turns: [
                .init(speaker: .app, text: topic.clarifier, writtenAt: stamp),
                .init(
                    speaker: .counselor,
                    text: """
                    지금 자리를 계속 지킬지 옮길지를 몇 달째 재고 계신 상황으로 읽었습니다. 명식에서는 정관이 자리를 잡고 있어 맡은 일과 그 안의 질서를 중히 여기는 편이고, 그래서 자리를 옮기는 일 자체가 가볍게 넘어가지 않는 성향입니다.

                    한편 식신이 함께 서 있어 만들고 내보내는 쪽으로도 힘이 흐릅니다. 이 둘이 같이 있으면 지금 자리에서 답답함을 느끼는 지점이 대우나 조건보다 \"내가 만든 것이 내 이름으로 남는가\"에 가까운 편입니다. 옮길 자리가 특별히 좋지 않은데도 눈이 가는 이유가 여기 있을 수 있습니다.

                    한 가지만 스스로 살펴보시면 좋겠습니다. 지금 걸리는 것이 자리인지, 그 자리에서 내 몫으로 남는 것이 없다는 느낌인지. 앞이라면 조건을 견주는 일이고, 뒤라면 옮겨도 같은 답답함이 따라올 수 있습니다.
                    """,
                    isComplete: true,
                    evidenceIDs: ids,
                    writtenAt: stamp,
                    provenance: .init(
                        modelID: "gemma-4-e2b",
                        modelName: "Gemma 4 E2B",
                        writtenAt: stamp,
                        appVersion: AppVersion.marketing,
                        ruleSetVersion: SajuService.ruleSet.version,
                        destination: .inProcess
                    )
                ),
            ],
            provenance: nil
        )
    }

    private static func render(_ shot: Shot, to directory: URL) async -> NSWindow? {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: shot.size),
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
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
