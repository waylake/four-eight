import SwiftUI

/// 스트리밍 중 바닥을 따라가되, **사용자가 올라가면 놓아준다.**
///
/// 예전 판은 `.defaultScrollAnchor(.bottom, for: .sizeChanges)` 하나에
/// 기대고 있었다. Apple 문서의 표현이 정확히 그 한계를 말한다 — 콘텐츠
/// 크기가 바뀌면 스크롤 뷰가 앵커를 "**may** consult"한다. 보장이 아니다.
/// 실제로 macOS 15의 SwiftUI 채팅 앱에서 스트리밍 중 목록이 위로 밀려
/// 답이 가려지는 사례가 보고되어 있다.
///
/// 그래서 직접 판정한다. 어려운 부분은 스크롤이 아니라 **왜 움직였는지를
/// 구분하는 것**이다.
///
/// 순진한 구현은 매 기하 변화마다 `거리 < 임계값`으로 "바닥 근처인가"를
/// 다시 계산한다. 그것이 깨지는 자리가 있다. 긴 문단이 한 프레임에 통째로
/// 들어오면 콘텐츠 높이가 먼저 자라고 보이는 영역은 아직 따라오지 않았다.
/// 그 한 프레임 동안 거리가 임계값을 넘고, 앱은 **사용자가 올라간 적이
/// 없는데 올라갔다고 판정한다.** 그 뒤로는 따라가기를 멈추고, 사용자는
/// 자기가 아무것도 안 했는데 답이 화면 밖에서 써지는 것을 본다.
///
/// 판정을 두 갈래로 나눈다.
///
/// - **콘텐츠가 자랐을 때**는 바닥 여부를 다시 계산하지 않는다. 직전 판정을
///   그대로 믿고 따라간다. 글이 자란 것은 사용자의 의사가 아니다.
/// - **높이가 그대로일 때만** 다시 계산한다. 높이가 안 변했는데 보이는
///   영역이 움직였다면 그것은 사용자가 스크롤한 것이다.
///
/// 이것이 앵커를 뗄 수 있는 유일한 경로다.
///
/// **구조체가 아니라 클래스인 이유가 있다.** 이 값은 스크롤하는 동안 매
/// 프레임 갱신된다. `@State`에 든 구조체로 두면 그 갱신 하나하나가 SwiftUI
/// 상태 변경이 되어 **기록 전체를 다시 그린다.** Apple 문서도
/// `onScrollGeometryChange`에 대해 "avoid updating large parts of your app
/// whenever the scroll geometry changes"라고 적는다. 장부는 뷰 밖에 두고,
/// 화면에 실제로 영향을 주는 한 가지(따라가기를 놓쳤는가)만 뷰 상태로
/// 올린다.
@MainActor
final class BottomFollow {
    /// 이 거리 안이면 "바닥에 있다"고 본다. 한 줄 남짓.
    private let threshold: CGFloat = 44

    private var lastContentHeight: CGFloat = 0
    private var seeded = false
    private var isDragging = false
    /// 사용자가 바닥에 머물러 있는가. 따라갈지 말지를 이 값 하나가 정한다.
    private(set) var isNearBottom = true

    enum Decision { case none, scrollToBottom }

    /// 사용자가 손을 대고 있는 동안에는 자라도 따라가지 않는다. 읽으려고
    /// 잡은 화면을 앱이 끌어내리는 것은 마찰이 아니라 방해다.
    func setDragging(_ dragging: Bool) { isDragging = dragging }

    func apply(contentHeight: CGFloat, visibleMaxY: CGFloat) -> Decision {
        let nowNearBottom = max(0, contentHeight - visibleMaxY) < threshold

        guard seeded else {
            seeded = true
            lastContentHeight = contentHeight
            isNearBottom = nowNearBottom
            return .none
        }

        // 서브픽셀 지터를 성장으로 오인하지 않는다.
        let grew = contentHeight > lastContentHeight + 0.5
        let wasNearBottom = isNearBottom
        lastContentHeight = contentHeight

        if grew {
            return wasNearBottom && !isDragging ? .scrollToBottom : .none
        }
        isNearBottom = nowNearBottom
        return .none
    }

    /// 사용자가 스스로 내려왔거나, 방금 말을 걸었다. 다시 따라간다.
    func resume() { isNearBottom = true }
}

/// 기하 변화를 한 값으로 묶는다.
///
/// `onScrollGeometryChange`는 변환한 값이 **`Equatable`하게 달라질 때만**
/// 콜백한다. 두 값을 따로 보면 콜백이 두 번 오고 그 사이의 반쪽 상태로
/// 판정하게 된다.
private struct ScrollSample: Equatable {
    var contentHeight: CGFloat
    var visibleMaxY: CGFloat
}

extension View {
    /// 이 스크롤 뷰가 바닥을 따라가게 한다.
    ///
    /// `ScrollPosition`이 아니라 `ScrollViewReader` + 고정 앵커 id를 쓴다.
    /// `scrollPosition(_:anchor:)`의 anchor 인자가 무시된다는 보고가 있고,
    /// 이 화면은 "가장 아래"만 필요하므로 바닥에 빈 앵커 하나를 두는 편이
    /// 흔들릴 자리가 적다.
    ///
    /// `isAway`는 이 경로가 건드리는 **유일한 뷰 상태**다. 임계값을 넘나들
    /// 때만 쓰이므로 스크롤 중 재구성이 프레임마다 일어나지 않는다.
    func followsBottom(
        _ follow: BottomFollow,
        anchorID: some Hashable,
        proxy: ScrollViewProxy,
        isAway: Binding<Bool>
    ) -> some View {
        self
            .onScrollPhaseChange { _, phase in
                // `.decelerating`을 사용자 조작으로 보지 않는다. 데스크톱에서는
                // 프로그램 스크롤 애니메이션도 이 상태를 지나가므로, 여기서
                // 놓아 버리면 따라가기가 스스로를 취소한다.
                follow.setDragging(phase == .interacting || phase == .tracking)
            }
            .onScrollGeometryChange(for: ScrollSample.self) { geometry in
                ScrollSample(
                    contentHeight: geometry.contentSize.height,
                    visibleMaxY: geometry.visibleRect.maxY
                )
            } action: { _, sample in
                let decision = follow.apply(
                    contentHeight: sample.contentHeight, visibleMaxY: sample.visibleMaxY
                )
                // 애니메이션을 걸지 않는다. 토큰마다 애니메이션이 겹치면
                // 서로를 취소하면서 화면이 떨린다.
                if decision == .scrollToBottom {
                    proxy.scrollTo(anchorID, anchor: .bottom)
                }
                // 실제로 달라졌을 때만 쓴다. 같은 값을 다시 쓰면 그것만으로
                // 재구성이 돈다.
                if isAway.wrappedValue == follow.isNearBottom {
                    isAway.wrappedValue = !follow.isNearBottom
                }
            }
    }
}
