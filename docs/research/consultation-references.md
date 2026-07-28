# 조사 — 상담·저널링 챗봇과 운세 앱의 제품 레퍼런스

- 조사일: 2026-07-28
- 목적: "고민을 듣고 근거로 답하는" 기능이 이미 어떻게 만들어져 있는지 확인한다.
- 결정은 [ADR 0010](../adr/0010-consultation-over-open-chat.md), 기획은 [docs/consultation.md](../consultation.md)에 있다.

제품 34개(상담·저널링 챗봇 13, 점성술·사주 앱 12, 한국 신생 서비스 7)와 UX 가이드라인·측정 자료를 조사했다. 아래는 **이 저장소의 결정에 실제로 쓰인 사실**만 남긴 것이다. 조사 원본에는 제품별 기능 목록과 불일치 19건이 더 있었으나, 확인 강도가 스토어 문구 수준인 항목은 옮기지 않았다.

---

## 1. 근거 표시 — 이 시장에서 거의 없는 기능

조사한 점성술·사주 앱 **12개 중 AI 답변에 근거(원국 배치·트랜짓·행성 도표)를 붙이는 것을 확인한 것은 Co-Star의 The Void 하나**였다. 그것도 유료 질문에 한정되고 일일 운세에는 없다.

반대 방향의 명시적 전략도 있다.

- **The Pattern**은 점성술 용어와 근거를 **의도적으로 제거**하는 것을 제품 전략으로 밝힌다.
- **CHANI**는 **AI 생성 콘텐츠가 없다는 것**을 공개적 약속으로 내세운다.

## 2. 근거 UI에 대한 측정 자료 세 건

근거를 붙이는 것이 곧 신뢰로 이어지지 않는다는 점을 보여주는 값들이다.

| 출처 | 값 |
|---|---|
| Pew Research (2025-07-22) | AI 요약이 결과에 있을 때 **인용 링크 클릭은 전체 방문의 1%** 수준 |
| Tow Center / CJR (2025-03-06) | 8개 AI 검색엔진의 **뉴스 인용 오류율 60% 이상** |
| Answer Bubbles (arXiv 2603.16138) | 검색 그라운딩이 **hedging 언어를 최대 60% 감소**시키면서 confidence marker는 유지 |

두 번째 값은 방향이 중요하다. **인용 오류는 모델이 인용을 생성하기 때문에 생긴다.** 이 앱은 반대 방향이다 — 규칙을 먼저 고르고 그 규칙으로 답을 만들므로 인용과 답이 어긋날 구조가 없다.

첫 번째 값은 근거 칩을 답변 뒤에만 두면 대부분 읽히지 않는다는 뜻으로 읽었다. 이 앱은 **풀이를 받기 전에** 상담 헤더에 쓰일 근거를 보여준다.

## 3. 한국 서비스

- **포스텔러 만세력**은 진태양시·야자시/조자시·동경시 보정을 **이미 사용자 설정으로 노출**하고 있다. 2026년 5월 v2.0에서 AI 상담을 추가했다. — 유파 차이를 설정으로 드러내는 것(ADR 0005)이 이 시장에서 낯선 선택이 아니라는 뜻이다.
- **도사**(2025 출시)는 "진태양시·절기·자시 보정을 적용한 과학적 사주 계산", "±1분 정밀 만세력", "NASA 천문 데이터와 GPT-5"를 스토어와 공식 사이트 문구로 쓴다. 서버 GPT 의존형이며 **계산까지 LLM에 맡기는지는 미확인**이다.
- **헬로우봇**(크래프톤 인수)이 LLM을 쓰는지는 스토어 문구로 확인되지 않았다(미확인).

한국 앱의 길흉 UI 형태와 문장별 근거 표시 여부는 스토어 텍스트만으로 확인할 수 없어 미확인으로 남긴다. 실기 확인이 필요하다.

## 4. 상담·저널링 챗봇에서 가져온 것

**Ash (Slingshot AI)** — 파인튜닝 목표에 **"when to stay silent"**와 **"appropriate opportunities to end a conversation"**을 명시한 유일한 사례다. 베이스 모델은 Qwen3-235B 파인튜닝임을 공개했다.

→ 말하지 않는 것과 끝내는 것을 품질 목표로 두는 것이 이 앱의 "모른다고 말하는 것이 품질 기준"과 같은 방향이다.

**메모리 UX에서 반복 확인된 사용자 요구는 삭제가 아니라 스코프였다.** Simon Willison의 지적 → OpenAI의 project-only memory → Claude의 프로젝트별 기본 격리로 이어지는 흐름이다.

→ 상담 한 건이 곧 스코프인 구조가 이 요구에 대한 답이다. 무엇을 기억할지 사용자가 관리하게 하는 대신, **기억의 범위를 상담 단위로 못 박았다.**

**Woebot**은 2025년 6월 소비자 앱을 종료했다. LLM을 쓰지 않는 임상 스크립트 방식이었고, 기사의 진술은 "clinical evidence alone does not guarantee a sustainable consumer business"다.

## 5. 디자인 가이드라인

| 출처 | 관련 내용 |
|---|---|
| NN/G "Less Chat, More Answer" (2026-04-17) | 채팅 형식 자체가 기본값이 되는 것에 대한 비판 |
| NN/G "10 Guidelines for AI Chatbots" (2026-04-24) | — |
| NN/G "Prompt Controls" (2024-08-02) | 자유 입력 대신 제어를 주는 패턴 |
| Google PAIR — Explainability + Trust | 설명 가능성과 신뢰의 관계, 멘탈 모델 워크시트 |
| Microsoft HAX — 18 guidelines | "Make clear how well the system can do what it can do" |
| Shape of AI | Citations · Memory · Suggestions · Branches 패턴 |
| Apple HIG — Generative AI / Machine Learning | 본문 미확인 |

HAX의 "시스템이 얼마나 잘할 수 있는지를 분명히 하라"가 이 앱에서 "이 상담은 근거 N개와 최근 발언 4개를 봅니다"로 구현됐다.

---

## 6. 미확인으로 남은 것

- 한국 앱들의 길흉 UI 형태, 문장별 근거 표시 여부 — 스토어 문구로 확인 불가, 실기 필요
- 도사의 계산·생성 경계(만세력 계산까지 LLM인지)
- 헬로우봇의 LLM 사용 여부
- Apple HIG의 Generative AI 챕터 본문

조사 제약: WebSearch 예산이 소진되었고 주요 도메인 11개가 403이었다.

---

## 7. 출처

### 근거 UI 측정
- https://www.pewresearch.org/short-reads/2025/07/22/google-users-are-less-likely-to-click-on-links-when-an-ai-summary-appears-in-the-results/
- https://www.cjr.org/tow_center/we-compared-eight-ai-search-engines-theyre-all-bad-at-citing-news.php
- https://arxiv.org/abs/2603.16138 (Answer Bubbles)

### 점성술·사주 앱
- https://apps.apple.com/us/app/co-star-personalized-astrology/id1264782561 · https://www.bustle.com/life/co-star-astrology-app-ai-feature (The Void)
- https://www.thepattern.com/ · https://thepattern.zendesk.com/hc/en-us/articles/42545042932628-In-Depth-AI-Conversation-Feature
- https://www.chani.com/ · https://chaninicholas.zendesk.com/hc/en-us/articles/1500001732281-App-Pricing
- https://www.sanctuaryworld.co/ · https://www.asknebula.com/faq · https://play.google.com/store/apps/details?id=com.astrotalk

### 한국 서비스
- https://apps.apple.com/kr/app/id6480584804 (포스텔러 만세력) · https://apps.apple.com/kr/app/id1262949138 (포스텔러)
- https://apps.apple.com/kr/app/id6741585416 · https://dosa.gkuer.com/ (도사)
- https://apps.apple.com/kr/app/id960571015 (점신) · https://apps.apple.com/kr/app/id1294957719 (헬로우봇)
- https://www.mediatoday.co.kr/news/articleView.html?idxno=213775 (헬로우봇 인터뷰) · https://www.venturesquare.net/831757 (크래프톤 인수)

### 상담·저널링 챗봇
- Ash (Slingshot AI), Woebot 종료, Rosebud·Stoic·Sonia·Youper·Wysa·Replika·Pi·Reflectly·Day One·Apple Journal·ChatGPT memory/Projects
- https://bestaitherapy.ai/reviews/woebot-review/ · https://dayoneapp.com/guides/ai-features/ai-features/ · https://developer.apple.com/documentation/journalingsuggestions
- https://simonwillison.net/2025/Aug/22/project-memory/ · https://claude.com/blog/memory

### 디자인 가이드라인
- https://www.nngroup.com/articles/less-chat-more-answer/ · https://www.nngroup.com/articles/ai-chatbots-design-guidelines/ · https://www.nngroup.com/articles/prompt-controls-genai/
- https://pair.withgoogle.com/chapter/explainability-trust/ · https://www.microsoft.com/en-us/haxtoolkit/ai-guidelines/ · https://www.shapeof.ai/
