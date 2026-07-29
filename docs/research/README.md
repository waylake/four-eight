# 조사 노트

구현 결정의 근거가 된 조사 기록을 출처와 함께 보관하는 디렉터리.

조사일: 2026-07-27

## 이 디렉터리에 두는 것

날짜가 찍힌 조사 노트를 둔다. 판단의 근거가 외부 사실(공표된 절기 시각, 패키지 버전, 라이선스 표기, 고전 전거)에 있고,
그 사실을 나중에 다시 확인해야 할 가능성이 있는 경우가 대상이다.

- 모든 사실 주장에는 출처 URL이 붙는다. 파일마다 Sources 절을 둔다.
- 출처끼리 어긋난 대목은 지우지 않고 불일치인 채로 남긴다. 어느 쪽을 채택했는지와 그 이유를 적는다.
  미해소로 남은 것은 미해소라고 적는다. 조사 노트에서 가장 값이 나가는 부분이 대개 여기다.
- 조사 시점에 따라 변하는 값(다운로드 수, 패키지 최신 버전, 파일 크기)은 스냅샷으로 취급하고 조사일을 함께 적는다.
- 각 파일은 H1, 한 줄 요약, `조사일: YYYY-MM-DD` 순으로 시작한다.

여기에 두지 않는 것도 명확하다. API 사용법 안내는 `docs/`의 해당 문서로, 확정된 아키텍처 결정은 `docs/adr/`로 간다.
조사 노트는 "무엇이 사실인가"를 다루고, 결정 문서는 "그래서 무엇을 하기로 했는가"를 다룬다.

## 이름 규칙

`<주제>-<성격>.md` 형태의 소문자 케밥 케이스를 쓴다. 주제가 먼저 오고 조사 성격이 뒤에 온다
(`manseryeok-validation`, `on-device-llm`, `interpretation-content`).
파일 이름에 날짜를 넣지 않는다. 날짜는 본문 머리의 `조사일`에 적는다.
같은 주제를 다시 조사하면 새 파일을 만들지 말고 기존 파일을 갱신하며 조사일을 올린다.

## 승격 흐름

조사 노트의 결론이 되돌리기 어려운 결정으로 굳으면 `docs/adr/`로 승격한다.

1. 조사 노트가 사실과 선택지를 정리한다.
2. 선택이 이루어지고 그것이 코드 구조나 의존성에 반영된다.
3. ADR을 작성한다. 맥락, 결정, 결과를 적고 근거는 조사 노트로 링크한다.
4. 조사 노트는 지우지 않고 남긴다. ADR은 결정을, 조사 노트는 그 결정을 지탱하는 사실을 보관한다.
   사실이 바뀌면(패키지 major 변경, 라이선스 정정) 조사 노트를 먼저 갱신하고, 결정까지 흔들리면 ADR을 새로 쓴다.

승격 사례로 [ADR-0004 벡터 검색 대신 룰 인덱스를 쓴다](../adr/0004-rule-index-over-vector-retrieval.md)가 있다.
근거가 되는 사실은 [interpretation-content.md](./interpretation-content.md)에 남아 있다.

## 노트 목록

| 문서 | 내용 |
|---|---|
| [manseryeok-validation.md](./manseryeok-validation.md) | 절기 시각·표준시 연혁·공개 사주 사례 7건의 골든 데이터. 값은 `SajuKit`의 `SolarTermReferenceTests.swift`와 `PublishedCaseTests.swift`에 테스트로 고정되어 있다 |
| [on-device-llm.md](./on-device-llm.md) | Gemma 4와 mlx-swift-lm 3.31.4의 검증된 스펙, 모델 ID와 크기, Apache 2.0 라이선스 확인, chat template |
| [interpretation-content.md](./interpretation-content.md) | `rules.json` 해석 룰 60개의 집필 원칙, 스키마와 태그 규약, 태그 매칭을 벡터 검색으로 만들지 않은 이유 |
| [consultation-ux.md](./consultation-ux.md) | 상담 화면의 사용성 진단(행 길이가 WCAG의 CJK 상한 초과, 죽은 근거 칩, retopic이 인용을 어긋나게 하는 경로 등 정합성 결함 5건)과 웹 AI 채팅 UI의 실제 관례. 근거 등급 표기, 미확인 19건 보존 |
| [chat-composer.md](./chat-composer.md) | Return 전송·Shift+Return 줄바꿈을 한글 입력기와 충돌 없이 구현하는 자리(Cocoa 텍스트 입력 순서, `hasMarkedText()` 가드), 실기 확인 9건, 미확인 4건. `insertLineBreak:`가 U+2028을 넣는다는 실측 포함 |
| [reasoning-model-budgets.md](./reasoning-model-budgets.md) | 추론 모델에서 출력 상한이 생각과 답변을 합쳐 세는 문제의 실측, 성숙한 도구 12개의 예산 정책, 같은 모델의 상한이 라우트마다 32배 갈리는 측정, `finish_reason: length`가 뭉갠 네 원인. 불일치 6건 보존 |
| [remote-llm-providers.md](./remote-llm-providers.md) | OpenAI 호환을 자칭하는 구현 11곳의 실제 분기, 401 응답 실측, 한도 헤더 두 계열의 형식 차이, opencode Zen·Go의 규격 라우팅. 자료 간 불일치 7건과 미확인 항목을 그대로 보존 |
| [macos-network-and-keychain.md](./macos-network-and-keychain.md) | ad-hoc 서명 + 샌드박스에서 키체인·ATS·로컬 네트워크 권한이 실제로 어떻게 동작하는지 실측. `.lines`가 SSE의 빈 줄을 버린다는 측정, 취소가 `URLError(.cancelled)`로 오는 측정. 문서와 실측이 어긋나는 지점을 양쪽 다 기록 |
| [consultation-safety.md](./consultation-safety.md) | 정신건강 성격 AI 챗봇의 규제 조문(Utah·Nevada·Illinois·California·EU AI Act·Apple), 위기 대응 관행, 4B 모델의 멀티턴 한계 측정치, MLX Swift 컨텍스트 관리의 알려진 결함 |
