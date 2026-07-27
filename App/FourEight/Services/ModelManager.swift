import Foundation
import Observation
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

/// 온디바이스 모델 수명주기 — 다운로드·활성화·해제.
///
/// 모델 파일은 Hugging Face Hub 캐시(앱 샌드박스 컨테이너 내부)에 저장된다.
/// API 근거: mlx-swift-lm 3.31.x — docs/research/on-device-llm.md.
@MainActor
@Observable
final class ModelManager {
    enum State: Equatable {
        case notInstalled
        case downloading(Double)
        case installed
        case loading
        case loaded
        case failed(String)
    }

    private(set) var states: [String: State] = [:]
    private(set) var activeModelID: String?
    private(set) var container: ModelContainer?

    /// 완료된 다운로드 기록 (UserDefaults).
    private var installedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "installedModels") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "installedModels") }
    }

    init() {
        for model in ModelCatalog.models {
            states[model.id] = installedIDs.contains(model.id) ? .installed : .notInstalled
        }
        activeModelID = UserDefaults.standard.string(forKey: "activeModel")
    }

    var isReady: Bool { container != nil }

    var activeModel: CatalogModel? {
        ModelCatalog.models.first { $0.id == activeModelID }
    }

    /// 다운로드(이미 있으면 캐시 사용) 후 메모리에 적재하고 활성화.
    func activate(_ model: CatalogModel) async {
        if activeModelID == model.id, container != nil { return }
        // 기존 모델 해제.
        container = nil
        states[model.id] = installedIDs.contains(model.id) ? .loading : .downloading(0)
        do {
            let configuration = ModelConfiguration(
                id: model.hfRepo,
                extraEOSTokens: ["<turn|>"]
            )
            let loaded = try await #huggingFaceLoadModelContainer(
                configuration: configuration
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if case .downloading = self.states[model.id] {
                        self.states[model.id] = .downloading(progress.fractionCompleted)
                    }
                }
            }
            container = loaded
            states[model.id] = .loaded
            var ids = installedIDs
            ids.insert(model.id)
            installedIDs = ids
            activeModelID = model.id
            UserDefaults.standard.set(model.id, forKey: "activeModel")
            // 다른 모델의 loaded 표기 정리.
            for other in ModelCatalog.models where other.id != model.id {
                if states[other.id] == .loaded {
                    states[other.id] = installedIDs.contains(other.id) ? .installed : .notInstalled
                }
            }
        } catch {
            states[model.id] = .failed(error.localizedDescription)
        }
    }

    /// 메모리에서 내리기 (파일은 유지).
    func unload() {
        container = nil
        if let id = activeModelID, states[id] == .loaded {
            states[id] = .installed
        }
        activeModelID = nil
        UserDefaults.standard.removeObject(forKey: "activeModel")
    }

    /// 설치 기록 제거 + 캐시 파일 삭제(탐색 가능한 위치에 한해).
    func delete(_ model: CatalogModel) {
        if activeModelID == model.id { unload() }
        var ids = installedIDs
        ids.remove(model.id)
        installedIDs = ids
        states[model.id] = .notInstalled
        // Hub 캐시 베스트에포트 삭제 — "models--org--repo" 디렉터리 규약.
        let fm = FileManager.default
        let dirName = "models--" + model.hfRepo.replacingOccurrences(of: "/", with: "--")
        let roots = [
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".cache/huggingface/hub"),
            fm.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("huggingface/models"),
            fm.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("huggingface/hub"),
        ].compactMap(\.self)
        for root in roots {
            let candidate = root.appendingPathComponent(dirName)
            if fm.fileExists(atPath: candidate.path) {
                try? fm.removeItem(at: candidate)
            }
            // swift-huggingface 스타일: <root>/<org>/<repo> 경로도 시도.
            let alt = root.deletingLastPathComponent()
                .appendingPathComponent("models")
                .appendingPathComponent(model.hfRepo)
            if fm.fileExists(atPath: alt.path) {
                try? fm.removeItem(at: alt)
            }
        }
    }
}
