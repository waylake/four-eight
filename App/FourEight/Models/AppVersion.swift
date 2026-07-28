import Foundation

/// 앱 버전 정보.
///
/// 값은 빌드 설정(`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`)에서
/// Info.plist로 주입된다. 릴리스 워크플로가 태그에서 계산해 넘긴다.
/// 규칙은 docs/release.md에 있다.
enum AppVersion {
    /// 사람이 읽는 버전. "0.2.0".
    static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// 단조 증가 빌드 번호. 업데이트 비교의 기준이 된다.
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// 표시용. "버전 0.2.0 (43)".
    static var display: String {
        "버전 \(marketing) (\(build))"
    }

    /// 이 빌드가 개발 중 빌드인가. 릴리스 워크플로는 빌드 번호를 크게 잡는다.
    static var isDevelopmentBuild: Bool {
        (Int(build) ?? 0) < 100
    }
}
