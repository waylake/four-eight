import SwiftUI
import RemoteLLM

/// 이 Mac을 벗어나기 전에 무엇이 나가는지 보여주는 관문.
///
/// ## 왜 설정 화면이 아니라 여기인가
///
/// Pew 조사에서 AI 요약이 있을 때 인용 링크 클릭은 전체 방문의 1%
/// 수준이다. 답 아래에 붙인 근거는 읽히지 않는다는 뜻이고, 설정 화면
/// 각주에 적은 프라이버시 고지도 같은 운명이다. 그래서 이 앱은 상담에서
/// 근거를 답 **앞에** 보여준다.
///
/// 같은 이유로 이 화면은 **보내기 직전**에 나온다. "동의합니다" 체크박스가
/// 아니라 실제로 나갈 글자를 보여준다. 요약이 아니라 원문이다 — 사용자가
/// 검증할 수 있는 것은 원문뿐이고, 요약을 보여주면서 "이것이 전부입니다"라고
/// 말하는 것은 확인이 아니라 확인의 연기다.
///
/// ## 왜 한 번만 묻는가
///
/// 매번 물으면 사용자는 읽지 않고 누르는 법을 배운다. 그러면 관문이 있는
/// 것이 없는 것보다 나쁘다 — 물었다는 기록만 남고 알린 것은 없다.
/// 그래서 **호스트마다 한 번**이다. 호스트가 프라이버시 경계이므로,
/// 같은 곳에 모델만 바꾸는 것은 다시 묻지 않고 주소를 바꾸면 다시 묻는다.
///
/// ## 왜 이 Mac 안에는 묻지 않는가
///
/// `localhost`의 Ollama에 보내는 것은 글이 기기를 벗어나지 않는다. 거기에도
/// 같은 경고를 띄우면 경고가 두 번째 의미를 잃고, 진짜 나가는 경우에
/// 사용자가 이미 무감해져 있다.
struct OutboundDisclosure: View {
    /// 어디로 가는가.
    let destination: Destination
    /// 모델 이름.
    let model: String
    /// 실제로 나갈 글자. 요약이 아니라 원문이다.
    let system: String
    let user: String
    /// 사용자가 무엇을 보내는지 알아보게 돕는 한 줄. 원문을 대신하지 않는다.
    let summary: [String]

    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var showsRawText = false

    private var host: String { destination.host ?? "?" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    whatLeaves
                    whatDoesNot
                    rawTextSection
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 620, height: 560)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.forward.square")
                .font(.title2)
                .foregroundStyle(Ink.cinnabar)
            VStack(alignment: .leading, spacing: 2) {
                Text("이 글이 \(host)로 갑니다")
                    .font(.headline)
                Text("보내기 전에 무엇이 나가는지 보여 드립니다. 이 주소에 대해 한 번만 묻습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var whatLeaves: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("나가는 것", systemImage: "arrow.up.forward")
                .font(.callout.weight(.semibold))
            ForEach(summary, id: \.self) { line in
                HStack(alignment: .top, spacing: 6) {
                    Text("·").foregroundStyle(.tertiary)
                    Text(line).font(.callout)
                }
            }
            Text("받는 곳: \(host) · 모델: \(model)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.cinnabar.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    /// 나가지 않는 것을 함께 적는다.
    ///
    /// "무엇이 나가는가"만 적으면 사용자는 나머지도 나가는지 모른다.
    /// 경계는 양쪽을 말해야 경계다.
    private var whatDoesNot: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("나가지 않는 것", systemImage: "lock")
                .font(.callout.weight(.semibold))
            Group {
                Text("· 인물의 이름 — 프롬프트에 들어가지 않습니다")
                Text("· 생년월일시 원본 — 계산이 끝난 명식과 근거만 나갑니다")
                Text("· 출생지 좌표, 적용된 시간 보정값")
                Text("· 다른 인물, 다른 상담, 지난 해석")
            }
            .font(.callout)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    private var rawTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showsRawText.toggle()
            } label: {
                Label(
                    showsRawText ? "보낼 글자 접기" : "보낼 글자를 그대로 보기",
                    systemImage: showsRawText ? "chevron.down" : "chevron.right"
                )
                .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Ink.cinnabar)

            if showsRawText {
                // 요약이 아니라 원문이다. 사용자가 검증할 수 있는 것은
                // 원문뿐이고, 여기서 요약을 보여주면 확인이 아니라 확인의
                // 연기가 된다.
                ScrollView {
                    Text(system + "\n\n---\n\n" + user)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 200)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이 주소를 운영하는 곳이 보낸 글을 어떻게 다루는지는 이 앱이 알 수 없습니다. 학습에 쓰지 않는다는 보장도, 보관 기간도 제공자의 정책에 달려 있습니다. 확인하고 쓰실 주소를 넣으셨기를 전제합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("보내지 않기", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("이 내용을 \(host)로 보냅니다") { onConfirm() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
    }
}

/// 확인을 기다리는 전송 하나.
///
/// 뷰의 `@State`에 두어도 되는 값이다 — 확인 대화상자가 살아 있는 동안만
/// 존재하고, 사라지면 아무것도 잃지 않는다. 비용을 치른 산출물이 아니다.
struct PendingSend: Identifiable {
    let id = UUID()
    let destination: Destination
    let model: String
    let system: String
    let user: String
    let summary: [String]
    /// 확인되면 실제로 할 일.
    let run: () -> Void
}
