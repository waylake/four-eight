import Foundation

/// 다운로드 가능한 온디바이스 모델 카탈로그 항목.
struct CatalogModel: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let hfRepo: String
    let quantization: String
    let sizeBytes: Int64
    let variant: String
    let recommended: Bool
    let notes: String?

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

enum ModelCatalog {
    /// 번들 카탈로그 (검증일: 2026-07-27, docs/research/on-device-llm.md 참조).
    static let models: [CatalogModel] = load()

    private static func load() -> [CatalogModel] {
        guard let url = Bundle.main.url(forResource: "model-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        struct File: Codable { let models: [CatalogModel] }
        return (try? JSONDecoder().decode(File.self, from: data))?.models ?? []
    }
}
