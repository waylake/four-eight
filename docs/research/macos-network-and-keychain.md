# 조사: 원격 엔드포인트를 부르는 데 필요한 플랫폼 사실

조사일 2026-07-28. 이 문서는 **사실만** 기록합니다. 무엇을 하기로 했는지는
[ADR 0011](../adr/0011-remote-provider-as-a-destination.md)에 있습니다.

실측 환경은 macOS 26.4.1 (25E253), Swift 6.2.3입니다. 이 앱의 최소 지원
버전은 15.0이므로, **15에서 재측정하지 않은 값은 15의 사실로 확정할 수
없습니다.** 아래에서 문서와 실측이 어긋나는 항목이 실제로 있습니다.

실측 대상은 이 앱과 같은 조건의 최소 번들입니다 — `codesign --force
--sign -`(ad-hoc, `TeamIdentifier=not set`), App Sandbox 켬, Hardened
Runtime 끔.

---

## 1. 키체인

### 1-1. macOS에는 키체인 구현이 둘이고 `SecItem`이 어디로 가는지는 속성이 정한다

Apple TN3137이 직접 적습니다.

> The `SecItem` API talks to either implementation—specifically the data
> protection keychain if you supply either the
> `kSecUseDataProtectionKeychain` or `kSecAttrSynchronizable` attribute,
> otherwise it talks to the file-based keychain.

> ACLs are only relevant to file-based keychains... The data protection
> keychain also supports macOS, and ACLs are irrelevant there.

출처: <https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains>

즉 `kSecClassGenericPassword`를 옵션 없이 쓰면 legacy(file-based)입니다.

### 1-2. data protection 키체인은 provisioning profile을 요구한다

TN3137:

> macOS builds the list of data protection keychain access groups available
> to your program from its code signing entitlements... **These entitlements
> must be authorized by a provisioning profile.**

Apple DTS(Quinn): "On macOS, a macOS app can only use an AGI keychain access
group if all of its entitlement claims are validated by a provisioning
profile." — <https://developer.apple.com/forums/thread/706128>

**실측** (ad-hoc + 샌드박스):

| 연산 | 결과 |
|---|---|
| `SecItemAdd`, DP 옵션 없음 | `0` errSecSuccess |
| `SecItemCopyMatching`, DP 옵션 없음 | `0`, 값 정상, 프롬프트 없음 |
| `SecItemAdd` + `kSecUseDataProtectionKeychain: true` | **`-34018` errSecMissingEntitlement** |
| `SecItemDelete` + `kSecUseDataProtectionKeychain: true` | **`-34018`** |
| `SecItemCopyMatching` + `kSecUseDataProtectionKeychain: true` | `-25300` errSecItemNotFound (읽기만 not-found로 떨어짐 — 비대칭) |

`com.apple.application-identifier`를 단독으로 넣어도 `-34018`은 그대로였고
앱은 정상 실행되었습니다.

### 1-3. `keychain-access-groups`를 ad-hoc 서명에 넣으면 앱이 실행되지 않는다

**실측**:

| entitlements (모두 ad-hoc) | 실행 결과 |
|---|---|
| sandbox + network.client (기준) | exit 0 |
| + `keychain-access-groups: ["com.example.kctest"]` | **exit 137 (SIGKILL), 출력 없음** |
| + `keychain-access-groups: ["ABCDE12345.com.example.kctest"]` | **exit 137 (SIGKILL)** |
| + `com.apple.application-identifier` 단독 | exit 0 |

원인은 팀 ID 접두사의 형태가 아니라 **profile 없이 이 entitlement를
주장하는 것 자체**입니다. Quinn은 restricted entitlement가 인가되지 않으면
Gatekeeper가 launch를 막고 `Unsatisfied entitlements:`가 로그에 남는다고
적습니다 — <https://developer.apple.com/forums/thread/777639>.
크래시 리포트 형태는 `EXC_CRASH (Code Signature Invalid)` /
`Namespace CODESIGNING, Code 0x1` — <https://developer.apple.com/forums/thread/725757>

**자료 간 불일치**: `keychain-access-groups` 문서 자체는 값 형식이 "Array of
strings"이고 macOS 10.7+라고만 적으며 **Team ID 접두사나 profile 요구를
명시하지 않습니다** —
<https://developer.apple.com/documentation/bundleresources/entitlements/keychain-access-groups>.
Microsoft(MSAL) 문서는 `$(AppIdentifierPrefix)` 확장에 의존하지 말고 Team ID를
하드코딩하라고 적을 뿐, 팀 ID가 없는 경우를 다루지 않습니다 —
<https://learn.microsoft.com/en-us/entra/msal/objc/howto-v2-keychain-objc>

### 1-4. legacy 키체인 ACL은 코드 해시에 묶이고, 재빌드하면 깨진다

`SecKeychainSetUserInteractionAllowed(false)`로 프롬프트를 오류로 바꿔
측정한 통제 실험:

| 단계 | 읽기 결과 |
|---|---|
| 생성 직후 | `0` errSecSuccess |
| 같은 바이너리 재실행 | `0` errSecSuccess |
| **비트 동일한 바이너리를 재서명**한 뒤 | `0` errSecSuccess (깨지지 않음 — CDHash 동일) |
| **재빌드**(CDHash 변경) + 재서명한 뒤 | **`-25293` errSecAuthFailed** |

즉 파손 조건은 재서명이 아니라 **코드 해시 변경**입니다. 상호작용을
허용한 상태에서는 이 값이 키체인 승인 대화상자로 나타납니다.

같은 증상의 외부 보고 — 둘 다 이 저장소와 같은 배포 구성입니다.

- gogcli: "The macOS binary shipped via Homebrew is adhoc, linker-signed, so
  its **code hash changes on every release**. macOS keychain ACLs are bound
  to the Designated Requirement of the writing process, so every
  `brew upgrade` invalidates the ACLs of every keychain item... even after
  clicking 'Always Allow' the previous time."
  — <https://github.com/openclaw/gogcli/issues/569>
- CodexBar: "the legacy login keychain validates access permissions against
  the **binary's code directory hash**. Since Sparkle replaces the binary
  during updates, the hash changes, invalidating all previous access
  grants." — <https://github.com/steipete/CodexBar/issues/585>,
  <https://github.com/steipete/CodexBar/issues/340>

CodexBar가 제시하는 해법은 `kSecUseDataProtectionKeychain: true`("validates
access by team ID, not binary hash")입니다. **그 해법은 §1-2 실측에 따라
ad-hoc 서명에서는 쓸 수 없습니다.** 두 보고 모두 최종 해법으로 Developer ID
Application 인증서를 지목합니다.

Sierra 이후 legacy ACL에는 partition list라는 추가 파라미터가 있고
"limits access to the key based on an application's code signature"이며
변경에 키체인 암호가 필요합니다 —
<https://developer.apple.com/forums/thread/666107>

### 1-5. `kSecAttrAccessible`은 ad-hoc에서 쓸 경로가 없다

Apple 문서: `kSecAttrAccessible`은 **`kSecUseDataProtectionKeychain = true`
또는 `kSecAttrSynchronizable = true`일 때만** macOS에서 사용할 수 있습니다
(macOS 10.9+) — <https://developer.apple.com/documentation/security/ksecattraccessible>.
`kSecUseDataProtectionKeychain`은 macOS 10.15+이고 macOS에서만 동작에
영향을 줍니다 —
<https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain>

§1-2에 따라 ad-hoc에서 data protection 경로가 막혀 있으므로,
`kSecAttrAccessible`을 넣어도 아무 일도 하지 않습니다.

### 1-6. 오류 코드 (로컬 `SecCopyErrorMessageString` 실측)

| 값 | 상수 | 메시지 |
|---|---|---|
| `-25291` | `errSecNotAvailable` | No keychain is available. |
| `-25293` | `errSecAuthFailed` | The user name or passphrase you entered is not correct. |
| `-25299` | `errSecDuplicateItem` | The specified item already exists in the keychain. |
| `-25300` | `errSecItemNotFound` | The specified item could not be found in the keychain. |
| `-25308` | `errSecInteractionNotAllowed` | User interaction is not allowed. |
| `-34018` | `errSecMissingEntitlement` | A required entitlement isn't present. |

**자료 간 불일치**: 웹 자료 하나는 `-25291`을 errSecMissingEntitlement로,
다른 하나는 errSecMissingEntitlement를 `-67018`로 적습니다. 로컬 Security
프레임워크 실측은 위 표대로입니다.

`-34018`이 실제 원인과 다른 곳을 가리킨 사례도 보고되어 있습니다 —
<https://www.nathanfox.net/p/flutter-secure-storage-on-macos>

---

## 2. 샌드박스 네트워크와 ATS

### 2-1. `com.apple.security.network.client`가 없을 때의 증상

Apple: "A Boolean value indicating whether your app may open outgoing
network connections." —
<https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client>

**실측** (`URLSessionConfiguration.ephemeral`):

| 대상 | entitlement 있음 | 없음 |
|---|---|---|
| `http://127.0.0.1:8792/` | 200 | `NSPOSIXErrorDomain 1` Operation not permitted |
| `http://192.168.0.64:8792/` | 200 | `NSPOSIXErrorDomain 1` |
| `https://example.com/` | 200 | **`NSURLErrorDomain -1003`** hostname could not be found |

**함정**: entitlement가 없을 때 공개 호스트명은 **DNS 실패로 위장합니다.**
권한 문제가 이름 해석 실패로 보이므로 오진하기 쉽습니다. IP 리터럴일 때만
EPERM으로 드러납니다.

임의의 HTTPS 호스트에 추가 entitlement는 필요하지 않았습니다.

### 2-2. ATS와 `http://localhost`

Apple `NSAllowsLocalNetworking` 문서:

> In iOS 17, iPadOS 17, and macOS 14, ATS no longer allows connections to IP
> addresses by default. Add individual IP addresses and classless
> inter-domain routing (CIDR) ranges in the `NSExceptionDomains` dictionary.

> While ATS doesn't block local loads by default in newer versions of the
> OS, consider setting `NSAllowsLocalNetworking` to `YES` as a declaration
> of intent, if appropriate, even if you don't support older OS versions.

출처: <https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking>

**실측** (`NSAppTransportSecurity` 키를 전혀 넣지 않은 상태):

| URL | 결과 |
|---|---|
| `http://127.0.0.1:8792/` | **200** |
| `http://localhost:8792/` | **200** |
| `http://192.168.0.64:8792/` (사설 IPv4) | **200** |
| `http://10.1.2.3:8792/` | `-1001` timeout (ATS 차단 아님) |
| `http://172.16.5.5:8792/` | `-1001` timeout |
| `http://intranet:8792/` (unqualified) | `-1003` DNS not found (ATS 차단 아님) |
| `http://neverssl.com/` (공개 호스트명) | **`-1022`** ATS 차단 |
| `http://93.184.215.14/` (공개 IP) | **`-1022`** |
| `http://8.8.8.8/` (공개 IP) | **`-1022`** |

즉 ATS는 이 앱에서 활성이며, **loopback·unqualified 호스트명·사설 IPv4
리터럴은 예외 키 없이 통과**했고 공개 호스트/공개 IP만 차단되었습니다.

**자료 간 불일치 — 지우지 말 것.**

1. Apple 현행 문서는 "macOS 14부터 ATS는 **IP 주소로의 연결**을 기본
   허용하지 않는다"고 통칭합니다. macOS 26.4.1 실측에서 사설 IP는 `-1022`가
   나지 않고 **공개 IP만** 났습니다. 문서에는 이 구분이 없습니다.
2. 2015년 Quinn의 스레드(iOS 9 시기)는 "ATS does apply to localhost and
   local network addresses by default"이며 `localhost`는 `NSExceptionDomains`로
   예외가 되지만 IP는 "do not work reliably"라고 적습니다 —
   <https://developer.apple.com/forums/thread/6205>
3. 3자 자료들은 "ATS applies only to connections made to public host names,
   and the system does not provide ATS protection to connections made to IP
   addresses"라고 적습니다 —
   <https://developer.apple.com/forums/thread/66417>,
   <https://www.nowsecure.com/blog/2017/08/31/security-analysts-guide-nsapptransportsecurity-nsallowsarbitraryloads-app-transport-security-ats-exceptions/>.
   공개 IP에 대해서는 이 서술이 macOS 26 실측과 어긋납니다.
4. "IP를 plist에 쓰는 것을 막는 iOS 버그가 있어 테스트에는 `127.0.0.1`보다
   `localhost`를 쓰라"는 보고도 있습니다. macOS 26에서는 둘 다 키 없이
   통과했습니다.

버전 규칙: iOS 9/macOS 10.11은 `NSAllowsArbitraryLoads`만 보고, iOS 10+/
macOS 10.12+는 그것을 무시하고 나머지 예외 키를 따릅니다 —
<https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity>

---

## 3. macOS 15의 로컬 네트워크 프라이버시

권위 문서는 TN3179입니다 —
<https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy>

### 3-1. 무엇이 권한을 요구하는가 (TN3179 표)

| 연산 | 권한 필요 |
|---|---|
| 나가는 TCP 연결 | **예** |
| 들어오는 TCP 연결 수락 | 아니오 |
| UDP unicast 전송 | **예** |
| UDP multicast/broadcast 전송 | **예** |
| 들어오는 UDP unicast 수신 | 아니오 |

정의: "A local network is an IP network associated with a
**broadcast-capable network interface**. Such interfaces include Wi-Fi and
Ethernet, but not cellular (WWAN) or VPN." `.local` 해석과 모든 Bonjour
연산은 권한이 필요하고, 비-local DNS 해석은 필요 없습니다. macOS 도입
시점은 **15**입니다. multicast entitlement는 iOS 전용입니다.

### 3-2. 루프백은 예외다

Quinn (Apple Staff):

> **Loopback addresses (127.0.0.1 and ::1) are exceptions to the local
> network restrictions, as they do not allow traffic to leave the device.**
> Use of multicast and broadcast addresses, as well as unicast to addresses
> on the local network's subnet are restricted.

<https://developer.apple.com/forums/thread/650810>

TN3179 본문은 루프백을 예외 목록에 명시하지 않지만, "local network"를
broadcast-capable 인터페이스로 한정하므로 정의상 포함되지 않습니다. 두
서술의 결론은 같습니다. 실측에서도 `127.0.0.1`·`localhost`에는 프롬프트가
없었습니다(macOS 26).

### 3-3. LAN의 다른 기기는 프롬프트 대상이다

TN3179 표에 따라 나가는 TCP 연결은 권한이 필요하므로,
`http://192.168.1.50:11434`는 대상입니다.

**실측 한계**: 자기 자신의 LAN IP로의 연결은 프롬프트 없이 성공했습니다.
같은 호스트로 라우팅되므로 **타 기기 케이스의 검증이 아닙니다.** 타 기기는
미검증입니다.

### 3-4. ad-hoc 서명에서는 신원 추적이 불안정하다

TN3179:

> **Local network privacy tracks the identity of your program using its code
> signature. This presents a challenge on macOS, which allows for unsigned
> code and ad hoc signed code (Xcode displays this as Sign to Run Locally).
> To ensure that local network privacy reliably tracks the identity of your
> macOS program, sign it with an Apple-issued code-signing identity.**

요구되는 것은 entitlement가 아니라 Info.plist의
`NSLocalNetworkUsageDescription`입니다. 거부 시 macOS에서는 "Operation is
blocked immediately"이며 시스템 설정에서 바꿉니다.

Eclectic Light: "**No reset mechanism exists.** Users cannot clear an app's
Local Network permission once set. Short-lived processes that fail
immediately may never trigger permission prompts, creating perpetual
failures." —
<https://eclecticlight.co/2026/01/14/how-local-network-privacy-could-affect-you/>

재부팅 후 허용이 무시되는 보고가 다수 있습니다 —
<https://www.rogue-research.com/2025/05/local-network-access-on-macos-15-sequoia/>,
<https://developer.apple.com/forums/thread/792453>,
<https://mjtsai.com/blog/2024/10/02/local-network-privacy-on-sequoia/>

**자료 간 불일치**: Xojo 포럼은 "macOS 15부터 IP 입력을 허용하는 모든 앱에
새 entitlement가 **필요하다**"고 적은 뒤, 같은 문서에서 "at the moment that
isn't enforced as a requirement, **nor is there a required entitlement**"라고
적습니다 — <https://forum.xojo.com/t/sequoia-new-security-entitlement-s/81329>.
TN3179도 entitlement가 아니라 Info.plist 키만 요구합니다.

---

## 4. Foundation만으로 SSE를 소비할 때

### 4-1. `.lines`는 빈 줄을 버린다 — SSE의 이벤트 경계가 사라진다

임의의 `AsyncSequence<UInt8>`를 바이트 단위로 흘려보내 `.lines`로 받은
**실측**:

| 입력 | 출력 |
|---|---|
| `"data: a\r\n\r\ndata: b\r\n\r\n"` | **2줄**: `"data: a"`, `"data: b"` |
| `"data: a\n\ndata: b\n\n"` | **2줄** |
| `"data: a\rdata: b\r"` (CR 단독) | 2줄 |
| `"a\n\n\n\nb\n"` | **2줄**: `"a"`, `"b"` |
| `"한글 테스트\n두번째 줄\n"` | 2줄, 정상 |
| `"x\ny"` (끝 개행 없음) | 2줄 (마지막 부분 줄도 방출) |
| `"a\u{2028}b\n"` (LINE SEPARATOR) | **2줄** |
| `"a\u{0085}b\n"` (NEL) | **2줄** |
| `"a\u{0B}b\u{0C}c\n"` (VT, FF) | **3줄** |

확정되는 사실:

1. `\r\n`, `\r`, `\n`을 모두 줄 종결자로 인식합니다.
2. **빈 줄을 전부 버립니다.** SSE 규격의 이벤트 구분자가 사라집니다.
   `"data: a\r\n\r\n"`이 1줄로 나옵니다.
3. `U+000B`, `U+000C`, `U+0085`, `U+2028`도 종결자로 취급합니다. SSE 규격은
   이들을 종결자로 규정하지 않으므로 **`data:` 페이로드 안에 이 코드포인트가
   있으면 줄이 쪼개집니다.**
4. 멀티바이트 UTF-8은 바이트 경계에 걸쳐도 깨지지 않았습니다. `.lines`는
   UTF-8을 가정합니다 (Swift 팀 David Smith: "lines assumes the data is
   UTF8") — <https://forums.swift.org/t/urlsession-asyncbytes-lines-for-utf16/56318>

빈 줄 문제의 1차 출처: "The iterator actually skips empty lines entirely,
which seems destructive and therefore can't be the only way?" —
`.lines`에는 `split`의 `omittingEmptySubsequences: false`에 해당하는 옵션이
없고, Apple 직원 응답도 없습니다 —
<https://developer.apple.com/forums/thread/725162>

SSE 규격이 요구하는 것: "If the line is empty (a blank line) — Dispatch the
event" — <https://html.spec.whatwg.org/multipage/server-sent-events.html#event-stream-interpretation>

### 4-2. 버퍼링·지연은 관측되지 않았다

로컬 chunked `text/event-stream` 서버(250ms 간격 flush)에
`URLSession.shared.bytes(for:)` + `.lines`:

```
+0.030s response 200
+0.031s line[1]   +0.285s line[2]   +0.545s line[3]
+0.796s line[4]   +1.051s line[5]   +1.306s line[6]
```

서버 flush 간격 그대로 도달했습니다. 다만 `.lines`는 설계상 줄 단위로
버퍼링합니다. 프록시/서버 측 버퍼링이 SSE 정지의 가장 흔한 원인으로
보고됩니다.

미실측 항목: `URLSession`은 `Accept-Encoding`을 자동 추가하고 응답을 자동
압축 해제하며, gzip 응답에서 `countOfBytesExpectedToReceive`가 `-1`이
됩니다 — <https://alastaircoote.github.io/urlsession-and-gzip/>

### 4-3. 취소는 `CancellationError`가 아니라 `URLError(.cancelled)`로 온다

`for try await line in bytes.lines` 진행 중 감싼 `Task`를 `cancel()`한
**실측**:

```
+1.385s -> Task.cancel()
+1.387s THREW: NSURLError domain=NSURLErrorDomain code=-999
        isCancellationError=false   urlErrorCancelled=true
```

서버 측에는 `BrokenPipeError` / `ConnectionResetError`가 남았습니다 —
TCP 연결이 실제로 즉시 끊깁니다. 반영까지 2ms.

`error is CancellationError == false`인 것이 핵심입니다. 관련 논의와 해법
(`URLError.cancelled`를 잡아 변환) —
<https://forums.swift.org/t/urlsession-implicit-cancellation-using-async-await-helper/69230>,
<https://forums.swift.org/t/cancellationerror/60009>

`AsyncBytes.task`가 public이므로 Task 취소 없이 URLSession 태스크만 끊는
경로도 있습니다(선언 실측, 동작 미실측).

### 4-4. 선언 실측

```swift
extension URLSession {
  public struct AsyncBytes : AsyncSequence, Sendable {
    public var task: URLSessionDataTask { get }
    public typealias Element = UInt8
    @frozen public struct Iterator : AsyncIteratorProtocol, Sendable { ... }
  }
}
```

`AsyncBytes`와 그 `Iterator`는 `Sendable`이고, `AsyncLineSequence`는
`Base: Sendable`일 때 `Sendable`입니다. 내부는 바이트 단위 소비이므로
`for try await b in bytes`는 바이트마다 async call입니다.

`AsyncBytes`/`AsyncLineSequence`는 **Linux(corelibs-foundation)에
없습니다** — <https://forums.swift.org/t/asyncbytes-and-asynclinesequence-not-available-on-linux/73601>

---

## 5. Swift 6 strict concurrency

### 5-1. Sendable 여부 (실측, `-swift-version 6` typecheck)

`URLSession`, `URLRequest`, `URLSessionDataTask`, `URLSession.AsyncBytes`,
`any URLSessionTaskDelegate` — **모두 Sendable**입니다. SDK 헤더에
`NS_SWIFT_SENDABLE`로 표시되어 있습니다.

**자료 간 불일치(시점 차)**: 2023년경 스레드는 actor 안에서
`URLSession.data(from:delegate:)`를 부르면 "Non-sendable type `(any
URLSessionTaskDelegate)?` exiting actor-isolated context" 경고가 난다고
기록하며 `@preconcurrency import Foundation`을 제시합니다 —
<https://developer.apple.com/forums/thread/727823>. 현재 SDK(macOS 26 /
Swift 6.2.3)에서는 **재현되지 않았습니다.**

### 5-2. 실행 위치 (SE-0338)

> async functions that are not actor-isolated should formally run on a
> generic executor associated with no actor.

<https://github.com/swiftlang/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md>

귀결: `URLSession.bytes(for:)`와 스트림 순회는 nonisolated async이므로
네트워크·디코딩은 main actor를 벗어나 실행되고, `for try await` **본문**은
`@MainActor` 격리로 되돌아옵니다. 즉 `@MainActor` 클래스에서 조각마다
상태를 갱신하는 형태가 컴파일도 되고 의미도 맞습니다.

관련 컴파일러 이슈: `async let` + `AsyncSequence` 조합에서 "Pattern that the
region based isolation checker does not understand" —
<https://github.com/swiftlang/swift/issues/75861>

---

## 6. 이 저장소 구성과 직접 부딪히는 것

- 이 앱은 ad-hoc 서명 + 자체 Homebrew tap + Sparkle입니다. §1-4에 따라 이
  조합에서 **legacy 키체인 항목은 매 릴리스마다 접근 승인이 무효화**됩니다.
  §1-2에 따라 그 회피 수단으로 보고된 data protection 키체인은 ad-hoc에서
  쓸 수 없고, §1-3에 따라 `keychain-access-groups`를 추가하면 **앱이 실행
  시점에 죽습니다.**
- 위 키체인 실측은 Hardened Runtime을 끈 상태에서 했습니다 — 이 저장소의
  현재 구성과 같은 조건입니다.
- TN3179는 로컬 네트워크 프라이버시가 ad-hoc 서명에서 신원 추적이
  불안정하다고 명시합니다. 사용자가 다른 기기의 Ollama를 가리키는 경로가
  여기에 의존합니다.
- `network.client`가 없으면 공개 호스트명이 `-1003` DNS 실패로 위장합니다.
