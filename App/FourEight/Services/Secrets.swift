import Foundation
import Security

/// API 키 보관. 키체인에만 둔다.
///
/// ## 규칙 하나: 키체인이 안 되면 대신 저장하지 않는다
///
/// 실패했을 때 UserDefaults나 앱 컨테이너의 파일로 흘리는 구현을 만들기가
/// 쉽고, 그러면 기능은 항상 동작한다. 하지만 그 순간 사용자의 API 키는
/// 백업에 평문으로 들어가고, 이 저장소의 보관 파일들은 사용자가 열어 볼
/// 수 있는 JSON이므로 언젠가 스크린샷에도 들어간다. **키를 잃는 것은
/// 되돌릴 수 있고, 키가 새는 것은 되돌릴 수 없다.**
///
/// ## 이 앱의 서명 구성에서 키체인이 실제로 어떻게 동작하는가
///
/// 이 앱은 ad-hoc 서명이고 Sparkle과 Homebrew로 업데이트된다. 이 조합에서
/// 키체인은 **완전하게 동작하지 않으며, 그 사실을 숨기지 않는다.** 실측
/// 근거는 docs/research/macos-network-and-keychain.md에 있다.
///
/// - macOS에는 키체인 구현이 둘이다. `kSecUseDataProtectionKeychain`이나
///   `kSecAttrSynchronizable`을 주면 data protection 쪽, 아니면 file-based
///   (legacy) 쪽에 말한다 (Apple TN3137).
/// - data protection 키체인은 provisioning profile로 검증된 entitlement를
///   요구한다. ad-hoc 서명에서는 `-34018 errSecMissingEntitlement`가 난다.
///   **그래서 이 앱은 legacy 키체인밖에 쓸 수 없다.**
/// - `kSecAttrAccessible`(WhenUnlocked 등)은 data protection 키체인에서만
///   쓸 수 있다. legacy에 주면 의미가 없다. 그래서 이 파일에는 없다 —
///   처음에는 넣어 두었는데, 넣어도 아무 일도 하지 않으면서 "접근 범위를
///   좁혀 두었다"는 착각을 만든다.
/// - `keychain-access-groups` entitlement를 ad-hoc 서명에 추가하면 앱이
///   **실행 시점에 SIGKILL된다.** 절대 추가하지 말 것.
/// - legacy 키체인의 ACL은 쓴 프로세스의 **코드 해시**에 묶인다. 비트가
///   같은 바이너리를 재서명하는 것은 괜찮지만, 다시 빌드하면 해시가 바뀌고
///   기존 항목 읽기가 `-25293 errSecAuthFailed`로 떨어진다. 즉 **앱을
///   업데이트하면 키 접근 승인이 무효화된다.** "항상 허용"을 눌러 두어도
///   다음 릴리스에서 다시 물어본다.
///
/// 마지막 항목은 이 앱에서 반드시 일어나는 일이다. 그래서 그것을 오류로
/// 뭉개지 않고 `needsReentry`라는 이름을 붙였다. 사용자에게 "생성에
/// 실패했습니다"라고 말하면 앱이 고장 난 것처럼 보이지만, "업데이트되어
/// 키를 다시 넣어야 합니다"라고 말하면 무엇을 하면 되는지 알 수 있다.
/// 원인은 사용자가 아니라 이 앱이 Developer ID 인증서가 없다는 것이며,
/// 그때가 오면 이 문제는 사라진다.
enum Secrets {
    /// 이 앱의 키체인 항목 서비스 이름. 바꾸면 사용자가 이미 넣은 키를
    /// 찾지 못한다.
    private static let service = "com.waylake.FourEight.provider"

    /// 키를 읽으려 한 결과.
    ///
    /// "없다"와 "있는데 못 읽는다"를 반드시 구분한다. 앞은 정상 상태이고
    /// (키가 필요 없는 로컬 엔드포인트가 있다), 뒤는 사용자가 조치할 일이 있다.
    enum Lookup: Equatable {
        case found(String)
        /// 이 주소에 키를 넣은 적이 없다. 오류가 아니다.
        case absent
        /// 항목은 있지만 이 바이너리가 읽을 권한을 잃었다.
        /// 앱 업데이트 후의 정상적인 상태다.
        case needsReentry(status: OSStatus)
        /// 그 밖의 키체인 실패.
        case failed(status: OSStatus)
    }

    enum Failure: Error, Equatable {
        case keychain(status: OSStatus)

        var message: String {
            switch self {
            case .keychain(let status):
                let detail = SecCopyErrorMessageString(status, nil) as String?
                return """
                이 Mac의 키체인에 키를 저장하지 못했습니다 (\(status)\(detail.map { ": \($0)" } ?? "")).
                키를 다른 곳에 대신 저장하지는 않았습니다 — 평문으로 남는 것이 잃는 것보다 나쁘기 때문입니다.
                """
            }
        }
    }

    /// 계정 이름은 엔드포인트 주소다. 제공자를 여러 개 두게 되면 키도
    /// 각각이어야 하고, 주소가 그 자연스러운 구분이다.
    private static func query(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func store(_ key: String, account: String) throws(Failure) {
        // 빈 문자열을 넣는 것은 지우는 것과 같은 뜻으로 다룬다.
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { try remove(account: account); return }

        // 업데이트 후에는 기존 항목을 **읽지 못하지만 지울 수는 있다.**
        // 먼저 지우고 새로 넣으면 새 바이너리의 코드 해시로 ACL이 다시
        // 만들어진다. `SecItemUpdate`로 덮어쓰려 하면 읽기 권한이 필요해
        // `-25293`으로 실패한다 — 키를 다시 넣으려는 사용자가 다시
        // 실패하는 자리다.
        try? remove(account: account)

        var attributes = query(account: account)
        attributes[kSecValueData as String] = Data(trimmed.utf8)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw .keychain(status: status) }
    }

    /// 키를 읽는다.
    ///
    /// 사용자 상호작용을 막지 않는다. 업데이트 후 첫 읽기에서는 macOS가
    /// 승인 대화상자를 띄우며, 그것이 이 상황의 정상적인 흐름이다.
    /// 대화상자가 생성 중간에 뜨지 않도록 **생성을 시작하기 전에** 부른다.
    static func lookup(account: String) -> Lookup {
        var attributes = query(account: account)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let key = String(data: data, encoding: .utf8)
            else { return .failed(status: status) }
            return .found(key)
        case errSecItemNotFound:
            return .absent
        // -25293: 코드 해시가 바뀌어 ACL이 이 바이너리를 다른 프로그램으로 본다.
        // -25308: 사용자가 승인 대화상자를 거절했거나 상호작용이 불가능했다.
        case errSecAuthFailed, errSecInteractionNotAllowed:
            return .needsReentry(status: status)
        default:
            return .failed(status: status)
        }
    }

    /// 항목이 존재하는지만 본다. **값을 읽지 않으므로 승인 대화상자를
    /// 띄우지 않는다.** 설정 화면이 "키가 있음"을 표시할 때 쓴다 — 화면을
    /// 여는 것만으로 암호를 묻는 앱이 되지 않으려는 것이다.
    static func exists(account: String) -> Bool {
        var attributes = query(account: account)
        attributes[kSecReturnData as String] = false
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = SecItemCopyMatching(attributes as CFDictionary, nil)
        // 권한이 없어도 "있다"는 사실은 알 수 있다.
        return status == errSecSuccess || status == errSecAuthFailed
            || status == errSecInteractionNotAllowed
    }

    static func remove(account: String) throws(Failure) {
        let status = SecItemDelete(query(account: account) as CFDictionary)
        // 없는 것을 지우는 것은 성공이다.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .keychain(status: status)
        }
    }
}

extension Secrets.Lookup {
    /// 사용자에게 보여줄 말. `found`와 `absent`에는 할 말이 없다.
    var message: String? {
        switch self {
        case .found, .absent:
            return nil
        case .needsReentry:
            return """
            앱이 업데이트된 뒤로 이 Mac의 키체인이 저장된 키를 내주지 않습니다. \
            이 앱은 아직 Apple 개발자 인증서로 서명되지 않았고, 그런 경우 키체인은 \
            업데이트된 앱을 다른 프로그램으로 봅니다. 설정에서 키를 다시 넣어 주세요. \
            다른 곳에 사본을 두지 않았기 때문에 이 앱이 대신 복구할 방법은 없습니다.
            """
        case .failed(let status):
            let detail = SecCopyErrorMessageString(status, nil) as String?
            return "키체인에서 키를 읽지 못했습니다 (\(status)\(detail.map { ": \($0)" } ?? ""))."
        }
    }
}
