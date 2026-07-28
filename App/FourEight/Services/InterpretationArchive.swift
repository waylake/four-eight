import Foundation
import CryptoKit

/// 생성물의 디스크 보관소.
///
/// 뷰 밖에 두는 것으로는 부족하다. **프로세스 밖에 두어야 한다.**
/// 30초와 배터리를 들여 만든 문장이 앱 종료로 사라지면 "사용자가 시키지
/// 않으면 재생성하지 않는다"는 원칙이 무의미해진다. 종료가 곧 강제
/// 재생성이 되기 때문이다.
///
/// 기준선(근거 원문 조립)은 여기에 저장하지 않는다. 계산은 공짜이므로
/// 매번 다시 만들면 된다. 저장 대상은 비용을 치른 것뿐이다.
enum InterpretationArchive {
    /// 봉투 — 파일 하나에 키와 문서를 함께 담는다.
    ///
    /// 키를 파일명 해시로만 두면 정리(인물 삭제·보존 기한)를 할 때 어느
    /// 파일이 무엇인지 알 수 없다. 파일이 스스로를 설명해야 한다.
    struct Envelope: Codable, Sendable {
        let subject: String
        let signature: String
        var document: InterpretationStore.Document
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FourEight/interpretations", isDirectory: true)
    }

    /// 파일명은 키의 SHA-256이다.
    ///
    /// `hashValue`를 쓰면 안 된다. Swift의 Hasher는 프로세스마다 시드가
    /// 달라서 다음 실행에서 같은 키가 다른 파일명이 된다 — 정확히 이
    /// 저장소가 고치려는 증상(껐다 켜면 다시 생성)을 다시 만든다.
    static func filename(subject: String, signature: String) -> String {
        let digest = SHA256.hash(data: Data("\(subject)|\(signature)".utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(32) + ".json"
    }

    static func url(subject: String, signature: String) -> URL {
        directory.appendingPathComponent(filename(subject: subject, signature: signature))
    }

    // MARK: - 읽기·쓰기

    static func load(subject: String, signature: String) -> InterpretationStore.Document? {
        let url = url(subject: subject, signature: signature)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(Envelope.self, from: data).document
    }

    static func save(subject: String, signature: String, document: InterpretationStore.Document) {
        let envelope = Envelope(subject: subject, signature: signature, document: document)
        let url = url(subject: subject, signature: signature)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(envelope)
            // 원자적 교체. 쓰는 중에 앱이 죽어도 반쪽 JSON이 남지 않는다.
            try data.write(to: url, options: .atomic)
        } catch {
            // 보관 실패는 기능 실패가 아니다. 화면의 문장은 그대로 있고,
            // 다음 실행에서 다시 생성할 수 있다.
            NSLog("해석 보관 실패: \(error.localizedDescription)")
        }
    }

    static func remove(subject: String, signature: String) {
        try? FileManager.default.removeItem(at: url(subject: subject, signature: signature))
    }

    // MARK: - 정리

    /// 인물 삭제 시. 서명(유파 옵션)에 관계없이 그 인물의 것을 모두 지운다.
    static func removeAll(subjectPrefix: String) {
        for (url, envelope) in envelopes() where envelope.subject.hasPrefix(subjectPrefix) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// 보존 기한 정리.
    ///
    /// 명식 해석은 평생 한 벌이므로 영구 보관한다. 날짜별 풀이는 매일
    /// 쌓이므로 지난 것부터 정리한다 — 3개월 전 오늘의 기운을 다시 읽을
    /// 사람은 없고, 다시 필요하면 다시 만들면 된다.
    static func prune(dayReadingsOlderThan days: Int = 120, now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

        for (url, envelope) in envelopes() {
            // 날짜별 풀이의 subject는 "<인물 UUID>#YYYY-MM-DD" 규약이다.
            guard let mark = envelope.subject.split(separator: "#").last,
                  let date = formatter.date(from: String(mark)),
                  date < cutoff
            else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func envelopes() -> [(URL, Envelope)] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }
        return files.compactMap { url in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let envelope = try? decoder.decode(Envelope.self, from: data)
            else { return nil }
            return (url, envelope)
        }
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
