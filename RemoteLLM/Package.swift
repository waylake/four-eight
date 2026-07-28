// swift-tools-version:6.0
import PackageDescription

// RemoteLLM — OpenAI 호환 엔드포인트와 말을 주고받는 층.
//
// SajuKit과 별개의 패키지다. SajuKit은 명리 엔진이고 Foundation만 쓴다는
// 것이 그 패키지의 가치이므로, HTTP와 SSE를 거기 넣지 않는다. 앱 타깃에
// 직접 넣지도 않는다 — 이 층에서 틀리기 쉬운 것들(줄 경계, 멀티바이트
// 분할, 오류 매핑, 키 유출)은 Xcode 없이 `swift test`로 고정할 수 있어야
// 한다. 앱 타깃에 두면 테스트할 방법이 사라진다.
let package = Package(
    name: "RemoteLLM",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "RemoteLLM", targets: ["RemoteLLM"]),
    ],
    targets: [
        .target(name: "RemoteLLM"),
        .testTarget(
            name: "RemoteLLMTests",
            dependencies: ["RemoteLLM"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
