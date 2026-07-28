import Foundation
import Observation
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

/// 온디바이스 모델 수명주기 — 다운로드·선택·적재·해제.
///
/// 세 층을 구분해서 말한다. 예전에는 셋이 한 슬롯에 있었고, 그래서 앱을
/// 껐다 켜면 "모델을 다시 설정하라"고 보였다. 사용자는 설정이 풀렸다고
/// 읽었지만 실제로는 파일도 선택도 그대로였고 메모리에만 없었다.
///
/// | 층 | 뜻 | 수명 |
/// |---|---|---|
/// | 설치됨 | 파일이 이 Mac에 있다 | 영구 (`installedIDs`) |
/// | 쓰기로 함 | 사용자가 이 모델을 골랐다 | 영구 (`preferredModelID`) |
/// | 적재됨 | 지금 메모리에 있다 | 세션 (`container`) |
///
/// UI가 "AI를 쓸 수 있는가"를 판단할 때 보는 것은 앞의 두 층이다. 적재는
/// 생성 버튼의 첫 단계이지 사용자가 관리할 일이 아니다. 실행할 때 미리
/// 올려두지도 않는다 — 오늘 AI를 안 쓸 사용자에게 3.6GB를 물릴 이유가 없다.
///
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
    /// 사용자가 쓰기로 한 모델. 메모리에서 내려도, 앱을 껐다 켜도 남는다.
    private(set) var preferredModelID: String?
    /// 지금 메모리에 있는 모델. 여기부터는 세션 수명이다.
    private(set) var container: ModelContainer?
    private(set) var loadedModelID: String?

    /// 완료된 다운로드 기록 (UserDefaults).
    private var installedIDs: Set<String> {
        get { capturedInstalled ?? Set(UserDefaults.standard.stringArray(forKey: "installedModels") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "installedModels") }
    }

    init() {
        for model in ModelCatalog.models {
            states[model.id] = installedIDs.contains(model.id) ? .installed : .notInstalled
        }
        preferredModelID = UserDefaults.standard.string(forKey: "preferredModel")
            // 0.1.x 키 이름. 한 번 옮겨 오면 사용자는 선택을 잃지 않는다.
            ?? UserDefaults.standard.string(forKey: "activeModel")
    }

    /// 스크린샷 캡처용. **UserDefaults를 건드리지 않는다.**
    ///
    /// 캡처가 사용자 설정을 바꾸면 안 되고, 그렇다고 모델이 없는 상태로
    /// 찍으면 대표 이미지가 스스로 모순된다 — 풀이에는 모델 이름이 적혀
    /// 있는데 컴포저에는 "모델을 고르지 않았습니다"가 뜬다.
    func seedForCapture() {
        guard let model = ModelCatalog.models.first(where: \.recommended)
            ?? ModelCatalog.models.first
        else { return }
        preferredModelID = model.id
        states[model.id] = .installed
        capturedInstalled = [model.id]
    }

    /// 캡처에서만 채운다. 비어 있으면 UserDefaults를 본다.
    private var capturedInstalled: Set<String>?

    var preferredModel: CatalogModel? {
        ModelCatalog.models.first { $0.id == preferredModelID }
    }

    func isInstalled(_ model: CatalogModel) -> Bool {
        installedIDs.contains(model.id)
    }

    /// 지금 메모리에 있는가. **"AI를 쓸 수 있는가"의 답이 아니다.**
    var isLoaded: Bool { container != nil }

    /// AI 기능을 제시해도 되는가 — 파일이 있고 사용자가 골라 두었는가.
    /// 적재 여부는 묻지 않는다. 필요하면 그때 올린다.
    var isAvailable: Bool {
        guard let model = preferredModel else { return false }
        return installedIDs.contains(model.id)
    }

    /// 첫 문장까지 몇 초 더 걸린다는 사실을 UI가 미리 말할 수 있게.
    var needsLoadBeforeUse: Bool { isAvailable && container == nil }

    // MARK: - 생성 경로에서 부르는 적재

    /// 골라 둔 모델을 메모리에 올린다. 이미 있으면 그대로 돌려준다.
    /// 생성 버튼을 누른 뒤에만 불린다.
    func prepare() async -> ModelContainer? {
        if let container { return container }
        guard let model = preferredModel, installedIDs.contains(model.id) else { return nil }
        return await load(model)
    }

    // MARK: - 설정 화면에서 부르는 조작

    /// 사용자가 이 모델을 쓰기로 한다. 파일이 없으면 내려받고, 곧바로
    /// 올려서 실제로 되는지 그 자리에서 확인시킨다.
    func choose(_ model: CatalogModel) async {
        preferredModelID = model.id
        UserDefaults.standard.set(model.id, forKey: "preferredModel")
        if loadedModelID == model.id, container != nil { return }
        _ = await load(model)
    }

    /// 메모리에서 내리기. **선택은 지우지 않는다.**
    /// 예전에는 여기서 선택까지 지웠고, 그래서 잠깐 메모리를 비운 사용자가
    /// 설정을 처음부터 다시 하게 됐다.
    func unload() {
        container = nil
        if let id = loadedModelID, states[id] == .loaded {
            states[id] = installedIDs.contains(id) ? .installed : .notInstalled
        }
        loadedModelID = nil
    }

    /// 이 모델을 쓰지 않기로 한다. 파일은 남는다.
    func stopUsing() {
        unload()
        preferredModelID = nil
        UserDefaults.standard.removeObject(forKey: "preferredModel")
        UserDefaults.standard.removeObject(forKey: "activeModel")
    }

    /// 설치 기록 제거 + 캐시 파일 삭제(탐색 가능한 위치에 한해).
    func delete(_ model: CatalogModel) {
        if loadedModelID == model.id { unload() }
        if preferredModelID == model.id { stopUsing() }
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

    // MARK: - 적재

    private func load(_ model: CatalogModel) async -> ModelContainer? {
        container = nil
        loadedModelID = nil
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
            loadedModelID = model.id
            states[model.id] = .loaded
            var ids = installedIDs
            ids.insert(model.id)
            installedIDs = ids
            // 다른 모델의 loaded 표기 정리.
            for other in ModelCatalog.models where other.id != model.id {
                if states[other.id] == .loaded {
                    states[other.id] = installedIDs.contains(other.id) ? .installed : .notInstalled
                }
            }
            return loaded
        } catch {
            states[model.id] = .failed(error.localizedDescription)
            return nil
        }
    }
}
