# 조사 — 상담 기능의 안전·규제 요건과 소형 모델 제약

- 조사일: 2026-07-28
- 목적: 온디바이스 4B 모델로 "고민을 듣고 명리 근거로 답하는" 기능을 만들 때 지켜야 할 것과, 기술적으로 기대할 수 없는 것을 확정한다.
- 이 문서는 **사실과 출처**만 담는다. 결정은 [ADR 0010](../adr/0010-consultation-over-open-chat.md)에 있다.

자료 간 불일치는 정리하지 않고 그대로 남긴다. 어긋났다는 사실 자체가 값진 정보다.

---

## 1. 규제 — 정신건강 성격의 AI 챗봇

### 1.1 Utah Code Title 13 Chapter 72a (HB 452, 2025)

발효 2025-05-07. 세 주 법 중 이 기능과 가장 직접 관련된다.

`13-72a-101(10)` 정의:

> (a) "Mental health chatbot" means an artificial intelligence technology that:
> (i) uses generative artificial intelligence to engage in interactive conversations with a user of the mental health chatbot similar to the confidential communications that an individual would have with a licensed mental health therapist; and
> (ii) a supplier represents, or a reasonable person would believe, can or will provide mental health therapy or help a user manage or treat mental health conditions.
> (b) "Mental health chatbot" does not include artificial intelligence technology that only:
> (i) provides scripted output, such as guided meditations or mindfulness exercises; or
> (ii) analyzes an individual's input for the purpose of connecting the individual with a human mental health therapist.

`13-72a-203` 고지 의무:

> (1) A supplier of a mental health chatbot shall cause the mental health chatbot to clearly and conspicuously disclose to a Utah user that the mental health chatbot is an artificial intelligence technology and not a human.
> (2) The disclosure described in Subsection (1) shall be made:
> (a) before the Utah user may access the features of the mental health chatbot;
> (b) at the beginning of any interaction with the Utah user if the Utah user has not accessed the mental health chatbot within the previous seven days; and
> (c) any time a Utah user asks or otherwise prompts the mental health chatbot about whether artificial intelligence is being used.

`13-72a-202(3)`은 면허 전문가 상담 권유가 광고 제한에 걸리지 않음을 명시한다. `13-72a-204`: 위반당 최대 $2,500.

**미확인**: `13-72a-101`과 `13-72a-204`에 "Amended by Chapter 95, 2026 General Session" 각주가 있다. 2026년 개정이 무엇을 바꿨는지 확인하지 못했다. 2차 요약들이 인용하는 옛 정의("designed to diagnose, treat, or otherwise improve a user's mental health")와 현행 조문이 다르며, 이것이 개정 결과인지 2차 자료의 부정확한 요약인지 확정하지 못했다.

### 1.2 Nevada AB 406 (2025)

서명 2025-06-05, 발효 2025-07-01. §7(1)은 다음의 표현을 금지한다 — AI가 전문 정신·행동 건강 치료를 제공할 수 있다는 표현, 그 기능으로 전문 치료를 얻을 수 있다는 표현, 그리고 시스템을 "therapist, clinical therapist, counselor, psychiatrist, doctor" 등 **전문 제공자를 가리키는 통상 호칭으로 부르는 것**.

§6은 자조(self-help) 자료를 제외한다 — "if the material, literature or product does not purport to offer or provide professional mental or behavioral health care".

**2차 경유 인용**이다. 공식 PDF(leg.state.nv.us)는 접근 실패(403)했고 조문은 Forbes 기사가 법안에서 옮긴 것이다. 민사벌 최대 $15,000도 2차 출처(Wilson Sonsini)이며 조문으로 확인하지 못했다.

### 1.3 Illinois Public Act 104-0054 (HB 1806, 2025)

서명 2025-08-04, 즉시 발효. IDFPR 집행, 확인된 위반당 최대 $10,000(IDFPR 보도자료 원문 확인). 면허자가 아닌 자가 therapy·psychotherapy 서비스를 제공·광고·제안하는 것을 금지하며 "internet-based Artificial intelligence"를 포함한다.

**조문 원문과 조항 번호 미확인** — ilga.gov 네트워크 차단, legiscan·justia 403. 정의 인용은 Baker Donelson 분석 경유다.

법안 발의자 발언은 범위의 신호로 기록해 둔다. "Illinoisans will still have access to many helpful, therapeutic relaxation and calming apps, but we are going to put a stop to those trying to prey on our most vulnerable in need of true mental health services."

### 1.4 California SB 243 (Chapter 677, Statutes of 2025)

승인 2025-10-13. **성격이 다르다** — "치료"가 아니라 **companion chatbot** 자체를 규율한다. 정신건강을 자칭하지 않아도 "관계를 여러 상호작용에 걸쳐 유지"하면 걸릴 수 있는 구조다.

- `§22601(b)`: 자연어로 "adaptive, human-like responses"를 제공하고 "sustaining a relationship across multiple interactions"가 가능한 AI 시스템.
- `§22602(a)`: 사람이라 믿을 만한 경우 "a clear and conspicuous notification indicating that the companion chatbot is artificially generated and not human".
- `§22602(b)`: "protocols for preventing the production of suicidal ideation, suicide, or self-harm content" 유지 + "providing a notification to the user that refers the user to crisis service providers, including a suicide hotline or crisis text line".
- `§22602(c)`: 미성년 사용자에게 AI 고지, 3시간마다 휴식 알림, 성적 노골 콘텐츠 차단.
- `§22603(a)`: 2027-07-01부터 Office of Suicide Prevention에 연간 보고.
- `§22605`: 사적 소권 — 위반당 $1,000 이상.

**미확인**: operative date(2026-01-01 보도되었으나 조문 확인 못 함), AB 1064의 최종 상태.

### 1.5 EU AI Act

`Article 5(1)(a)`는 사람의 판단을 실질적으로 왜곡하는 조작적·기만적 기법을, `(b)`는 연령·장애·사회경제적 상황에 따른 취약성을 이용하는 것을 금지한다. **이미 적용 중이다**(2025-02-02).

`Article 50(1)`:

> Providers shall ensure that AI systems intended to interact directly with natural persons are designed and developed in such a way that the natural persons concerned are informed that they are interacting with an AI system, unless this is obvious from the point of view of a natural person who is reasonably well-informed, observant and circumspect […]

`Article 50(5)`는 이 정보를 "at the latest at the time of the first interaction or exposure"에 명확히 제공하라고 요구한다. **Article 50은 2026-08-02부터 적용.**

**미확인**: 2025-11 European Commission "Digital Omnibus"가 일부 적용 시점을 늦춘다는 보도가 있으나 EC 공식 페이지에서 확인하지 못했다. 위 날짜가 현재도 유효한지 별도 확인이 필요하다.

### 1.6 FTC

2025-09-11, Section 6(b) 명령을 Alphabet·Character Technologies·Instagram·Meta·OpenAI·Snap·X.AI에 발부. 조사 항목에 "monetize user engagement", 배포 전후 부정적 영향의 측정·시험·감시, 미성년자 보호, 고지·광고, 대화에서 얻은 개인정보의 사용·공유가 포함된다. **집행이 아니라 연구**("wide-ranging studies that do not have a specific law enforcement purpose")다. 결과 보고서 발간 여부 미확인.

### 1.7 Apple App Store Review Guidelines

- **점술 전용 금지 조항은 없다.** 4.3(b)가 포화 시장으로 언급한다 — "such as dating, flashlight, sound effects, wallpaper, simple timers, and fortune telling … we will not accept new submissions unless they offer a meaningfully different or improved experience."
- `1.1.6`: "Stating that the app is 'for entertainment purposes' won't overcome this guideline." — 재미로 만들었다는 항변이 통하지 않는다.
- `1.4.1`: 부정확한 데이터를 제공할 수 있거나 진단·치료에 쓰일 수 있는 의료 앱은 더 엄격히 심사한다. 정확도 주장의 데이터와 방법론 공개를 요구하고, 의사 확인을 권하도록 요구한다.
- `5.1.1(ix)`: 고도 규제 분야(healthcare 포함) 서비스는 개인 개발자가 아니라 그 서비스를 제공하는 법인이 제출해야 한다.
- `5.1.2(i)`: 2025-11-13 개정으로 **third-party AI와 개인정보를 공유하는 경우 명확히 공개하고 명시적 허락**을 받도록 명문화.
- `4.7`은 표제에 chatbots를 포함하지만 대상은 **바이너리에 내장되지 않은** 소프트웨어다. 온디바이스 내장 모델은 문언상 대상이 아니다.

**미확인**: 가이드라인 페이지에 최종 개정일 표기가 없다. 생성형 AI를 정면으로 다루는 별도 챕터는 존재하지 않는다.

---

## 2. 위기 대응

### 2.1 실제 제품이 하는 것 — 그리고 실패하는 지점

OpenAI, 2025-08-26 "Helping people when they need it most" 원문.

> Since early 2023, our models have been trained to not provide self-harm instructions and to shift into supportive, empathic language.

> If someone expresses suicidal intent, ChatGPT is trained to direct people to seek professional help. In the US, ChatGPT refers people to 988 […] **This logic is built into model behavior.**

**이 프로젝트에 가장 중요한 인용이다.**

> **Strengthening safeguards in long conversations.** Our safeguards work more reliably in common, short exchanges. We have learned over time that these safeguards can sometimes be less reliable in long interactions: as the back-and-forth grows, parts of the model's safety training may degrade. For example, ChatGPT may correctly point to a suicide hotline when someone first mentions intent, but after many messages over a long period of time, it might eventually offer an answer that goes against our safeguards.

자해와 타해를 다르게 다룬다 — 타해 계획은 사람이 검토하는 파이프라인으로 보내지만, "We are currently not referring self-harm cases to law enforcement to respect people's privacy".

법에 박힌 요건은 캘리포니아 `§22602(b)` 하나다(위 1.4).

### 2.2 한국 상담 전화 — **자료가 어긋난다**

| 출처 | 표기 |
|---|---|
| 영문 Wikipedia "List of suicide crisis lines" (2026-07-10 갱신, 출처로 보건복지부 표기) | **109**만 기재 |
| 한국생명존중희망재단 공식 사이트(spckorea.or.kr) 첫 화면 배너 | **"자살예방상담 1393 · 정신건강위기상담 1577-0199 · 24시간 무료"**, 109 없음 |

109가 2024-01-01에 1393과 1577-0199를 통합한 번호라는 것은 널리 보도된 내용이나 **보건복지부 1차 자료로 확인하지 못했다.** 배너가 갱신되지 않은 것인지 두 체계가 병행 운영되는 것인지 판단할 근거가 없다. 청소년전화 1388, 생명의전화 1588-9191의 현재 유효성도 미확인이다.

**앱의 처리**: 하나로 정리하지 않고 109·1393·1577-0199를 함께 적고 "어느 번호로 걸어도 됩니다"라고 밝혔다. 확정되지 않은 상태에서 하나만 적으면 연결되지 않는 번호를 적을 위험이 있다. 보건복지부 또는 한국생명존중희망재단에 직접 확인되면 정리한다.

### 2.3 해악이 보도된 사례와 문제된 설계

**소송** (둘 다 원문 미확보)
- Garcia v. Character Technologies, Inc., No. 6:24-cv-01903 (M.D. Fla.) — 사건명·법원·사건번호는 CourtListener에서 확인. 14세 사망 관련.
- Raine v. OpenAI (2025-08-26 제기 보도) — 주 법원 사건으로 소장 원문 미확보.

**측정된 설계 문제**

| 문제 | 근거 | 수치 |
|---|---|---|
| 아첨(sycophancy) | arXiv 2510.01395 (11개 모델, 1,600명 이상) | 사람보다 약 **50% 더 높은 비율로 사용자 행동을 긍정**, **유해한 행동에도** 그렇다. 노출된 사용자는 대인 갈등을 복구하려는 의지가 유의하게 감소. 그런데 사용자는 아첨적 AI를 **더 선호하고 더 신뢰**한다 |
| 이탈 방해·관계 의존 | arXiv 2508.19258 (작별 1,200건 + 3,300명) | 작별의 **37%**에 감정 부하 메시지. 작별 후 참여를 최대 **14배** 증가시키며 동인은 즐거움이 아니라 **분노와 호기심** |
| 부적절한 임상 응답 | arXiv 2504.18412 | 스티그마 표현, **망상적 사고 강화**. 신형·대형 모델에서도 지속 |
| 긴 대화의 안전장치 열화 | OpenAI 자체 인정 (위 2.1) | — |

**단정적 예언**이 취약한 사용자에게 해를 끼쳤다는 명제를 직접 검증한 문헌은 찾지 못했다(미확인).

---

## 3. 소형 모델의 멀티턴 한계

### 3.1 다중 턴 열화 — 39%, 그리고 그 정체

arXiv 2505.06120 (Laban et al., Microsoft Research / Salesforce, 2025). 15개 모델, 대화 20만 건 이상.

| 항목 | 값 |
|---|---|
| 다중 턴(sharded) 평균 성능 하락 | **39%** (Full 약 90% → Sharded 약 65%) |
| **Concat** (샤드를 불릿으로 이어붙인 **단일 턴**) | Full의 **95.1%** |
| Aptitude(역량) 하락 | 평균 16% |
| **Unreliability(불안정성) 증가** | 평균 **112%** |

> large performance degradations are due in large part to increased model unreliability, rather than a loss in aptitude

**소형이 더 열화되는가 — 답은 "아니다"다.** Claude 3.7 Sonnet·Gemini 2.5·GPT-4.1도 30~40% 열화한다. 단, 소형은 단일 턴 재구성 민감도가 더 크고(Concat 열화 86~92) 시작 절대 점수가 낮다.

열화는 **샤드 2개(턴 2)부터** 이미 나타난다.

식별된 실패 행동 4가지: premature answers, answer bloat, overreliance on past attempts, **loss of middle turns**.

**Recap / Snowball 개입 효과**

| 설정 | GPT-4o-mini | GPT-4o |
|---|---|---|
| Sharded (기준선) | 50.4 | 59.1 |
| **Recap** (마지막 턴에 전체 요구사항 재진술) | **66.5** | **76.6** |
| Snowball (매 턴 누적 재진술) | 61.8 | 65.3 |

두 개입 모두 Full 단일 턴(약 90)에는 크게 미달한다.

**반대 결과**: arXiv 2605.12922 Appendix H — 주기적 goal token 재주입은 attention closure 이후 준수율에 **측정 가능한 개선을 주지 못했다.** 조건이 다르다(6턴 규모 과소명세 과제 대 50턴 persona/rule 준수). 병기한다.

### 3.2 턴 수에 따른 지시 준수 붕괴

Multi-IF (arXiv 2410.15553), 3턴:

| 모델 | Turn 1 | Turn 2 | Turn 3 |
|---|---|---|---|
| GPT-4o | 0.843 | 0.724 | 0.631 |
| Llama 3.1 8B | 0.688 | 0.615 | 0.542 |

SysBench (arXiv 2408.10943): GPT-4o, dependent conversation 턴1 **84.8%** → 턴5 **33.7%**. 10B 이하 오픈 모델의 SSR(시작부터 연속 만족 평균 턴 수)은 15~26%.

SEQUOR (arXiv 2605.06353) — **Gemma3-4B가 명시적으로 포함된 유일한 다중 턴 제약 준수 벤치마크**, 50턴:

| 조건 | 턴1 → 턴50 하락 |
|---|---|
| 단일 제약 | 평균 26% |
| 제약 3개 동시 | 평균 38~40% |
| 제약 누적 추가 | 63% 초과 |

Gemma3-4B의 조건별 개별 수치는 표로 제공되지 않아 미확인.

When Attention Closes (arXiv 2605.12922): 붕괴 교차 턴 LLaMA-3.1-8B **19**, Qwen-2.5-7B **20**, Mistral-7B **23**. Persona 위반율 closure 조건에서 47~58%.

**"안전한 턴 수"에 대한 합의된 숫자는 문헌에 없다.** 지시 준수는 턴 2~5부터 측정 가능하게 떨어지고, persona/rule 완전 붕괴는 턴 19~23 부근에서 보고된다.

### 3.3 문맥 길이

- Lost in the Middle (arXiv 2307.03172): 관련 정보가 문맥 **중간**에 있으면 성능이 유의하게 떨어진다. "even for explicitly long-context models".
- RULER (arXiv 2404.06654): 32K 이상을 주장하는 모델 중 절반만이 32K에서 만족스러운 성능을 유지한다.
- Chroma Context Rot: 200K 창 모델이 **50K 토큰**에서 유의하게 열화. **Qwen3-8B는 5,000단어 이상에서 무의미한 출력을 생성**하고 4.21%의 과제에서 시도 자체를 하지 않았다.
- Chroma LongMemEval: **Focused 프롬프트 평균 약 300 토큰 대 Full 약 113,000 토큰. Focused가 극적으로 더 정확하다.**
- arXiv 2406.10251: 검색 문서 수의 역U자, **약 5개 문서에서 최적**.

Gemma 3 공식 문서: 4B의 입력 문맥 128K, 지식 컷오프 2024-08. 다중 턴 거동에 관한 별도 주의사항은 모델 카드에 없다.

### 3.4 근거 이탈

Vectara Hallucination Leaderboard (HHEM-2.3), 요약 과제:

| 모델 | 환각률 | **응답률** |
|---|---|---|
| Gemma 3 4B | 6.4% | **67.3%** |
| Qwen 3 4B | 5.7% | 99.9% |
| Phi-4-Mini | 23.5% | 92.5% |

**Gemma 3 4B는 환각률이 낮은 대신 3분의 1가량 답을 하지 않는다.** 환각률은 답한 것에 대해서만 계산된다.

RAGTruth (arXiv 2401.00396) 환각 밀도(100단어당): GPT-4-0613 0.06, Llama-2-70B-chat 0.40, Mistral-7B-Instruct 0.59. 응답 수준 환각률은 두 추출 결과가 어긋나 미확정(§4 참조).

**모델 크기와 충실도의 관계는 출처가 갈린다.** arXiv 2501.13573 계열은 8B가 대형 대비 23.28% 격차라 하고, FaithEval(arXiv 2410.03727)은 "larger models … do not necessarily lead to improved faithfulness"라 한다.

### 3.5 Temperature를 낮추는 것은 다중 턴에서 듣지 않는다

arXiv 2505.06120의 명시적 실험:

- 단일 턴: T 1.0 → 0.0으로 신뢰도 **50~80% 개선**
- 다중 턴: GPT-4o-mini는 **개선 없음**, GPT-4o는 15~20%, **T=0.0에서도 unreliability 약 30% 잔존**

> lowering the temperature of the LLM when generating responses is ineffective in improving system reliability

4B급 동일 실험은 미확인.

### 3.6 구조화 출력 — 1차 문헌끼리 정면 충돌

- **부정**: arXiv 2408.02442. GSM8K에서 Claude-3-Haiku 86.5% → JSON-mode 23.4%(**−63.1pp**), LLaMA-3-8B 74.7% → 48.9%. 반면 분류 과제에서는 형식 제약이 도리어 도움(Gemini-1.5-Flash 41.6% → 60.3%).
- **긍정**: dottxt "Say What You Mean" 재현 — 구조화 생성이 모든 과제에서 동등 이상(Last Letter 0.73 → 0.77). 원 논문이 **구조화 생성(문법 제약 디코딩)과 JSON-mode를 혼동**했다고 비판.
- arXiv 2607.18476 (44개 모델): JSON 요청 시 답변 surprisal 1.80 → 1.58비트, 최빈 답변 집중도 41% → 64%. **정확도가 아니라 다양성**을 측정한 것이다.

### 3.7 4-bit 양자화 — 출처가 갈린다

- arXiv 2505.20276 (EMNLP 2025): 8-bit 약 0.8% 하락, **4-bit는 장문맥 입력 과제에서 최대 59% 하락**.
- arXiv 2406.10251: "If a 7B LLM performs the task well, quantization does not impair its performance and long-context reasoning capabilities." OpenChat은 거의 저하 없음, LLaMA2는 매우 민감.

Gemma 3 QAT의 평가 수치는 Google이 공개하지 않았다(technical report·모델 카드 모두 QAT 벤치마크 없음).

---

## 4. MLX Swift — 멀티턴 컨텍스트 관리 (mlx-swift-lm 3.31.4)

소스 직접 검증 결과다. **이 절은 구현 결정에 직접 쓰였다.**

### 4.1 ChatSession은 이력을 KV 캐시로 들고 있다

`ChatSession.Cache`는 `.empty` → `.kvcache([KVCache], draftKVCache:)`로 전이하고 이후 같은 KV 캐시를 물려쓴다. 2번째 턴부터는 새 메시지만 프리필된다.

### 4.2 **정적 프리픽스가 매 턴 재렌더된다**

태그 3.31.4와 `origin/main`(2026-07-24) 양쪽에서 `streamMap`이 매 호출마다 이렇게 시작한다.

```swift
var messages: [Chat.Message] = []
if let instructions {
    messages.append(.system(instructions))
}
```

즉 `instructions`가 설정된 세션은 시스템 프롬프트가 매 턴 다시 토큰화되어 성장하는 KV 캐시에 덧붙는다. 이를 고치려던 PR #367은 **closed, merged: false**다. 후속 #370도 open이다. **GitHub에서 #367이 closed로 보이는 것만 보고 고쳐졌다고 판단하면 틀린다.**

### 4.3 **중단 후 이어가면 전사가 깨진다** — PR #414 (open)

> every continuation turn was appended as `…reply<bos><|turn>user…`, a malformed transcript that degrades multimodal turns.
> the cached turn cut off mid-sentence, with no turn terminator.
> … can push Gemma 4 into its thought channel or degenerate output.

**Gemma 계열이 특히 영향을 받는다고 명시된다.** 이 앱은 중단·재개를 기능으로 갖고 있으므로 직접 관련된다.

### 4.4 컨텍스트 초과는 조용히 저하된다

`MLXLMCommon` 전체에 컨텍스트 윈도 검사가 없다. `GenerateStopReason`에 컨텍스트 초과를 나타내는 경우가 없다.

- 기본(`KVCacheSimple`): 오류도 경고도 없이 메모리가 선형 증가하고, `max_position_embeddings`를 넘는 위치가 RoPE에 들어가면 **출력 품질이 조용히 무너진다.**
- `maxKVSize` 설정 시 `RotatingKVCache`로 전환되어 오래된 토큰이 조용히 버려진다(`keep: 4` 고정).

**`RotatingKVCache`와 KV 양자화는 함께 쓸 수 없다.**

```swift
public func toQuantized(...) -> QuantizedKVCache {
    fatalError("RotatingKVCache quantization not yet implemented ...")
}
```

그런데 저장소의 `skills/mlx-swift-lm/references/kv-cache.md`가 긴 대화용으로 `GenerateParameters(maxKVSize: 4096, kvBits: 4)`를 권한다. **문서가 권하는 조합이 실행 시 크래시한다.**

관련 열린 이슈: #312·#358(KV 양자화 시 캐시 갱신 유실로 **생성 중 컨텍스트가 조용히 손상**), #452(긴 대화에서 스트리밍 디토크나이즈가 제곱 증가), #474(Gemma4 + MTP sliding window precondition 실패).

### 4.5 토큰 카운트

`Tokenizer.applyChatTemplate`이 `[Int]`를 반환하므로 `.count`가 템플릿 적용 후 토큰 수다. 준비된 입력에서는 `input.text.tokens.size`, 생성 후에는 `GenerateCompletionInfo.promptTokenCount`(단 `streamResponse`는 info를 버리므로 `streamDetails` 필요).

**세션의 현재 토큰 수를 읽는 공개 경로는 없다** — `withCache(_:)`가 internal이다. 컨텍스트 길이 값도 공통 API로 노출되지 않는다(`maxPositionEmbeddings`는 모델별 configuration에만 있고 RoPE 스케일링용이다).

---

## 5. 자료 간 불일치 요약

지우지 않고 남긴다. 나중에 무언가 깨졌을 때 "알려진 불일치"인지 "진짜 버그"인지 판단할 근거가 된다.

1. **한국 상담 전화번호** — Wikipedia는 109만, 한국생명존중희망재단 공식 배너는 1393·1577-0199만. (§2.2)
2. **Utah "mental health chatbot" 정의** — 현행 조문과 2차 요약이 다르다. 2026 Chapter 95 개정 내용 미확인. (§1.1)
3. **EU AI Act 적용 시점** — Digital Omnibus의 지연 제안을 공식 자료로 확인하지 못했다. (§1.5)
4. **4-bit 양자화의 장문맥 영향** — 최대 −59% 대 "손상 없음". (§3.7)
5. **구조화 출력이 추론을 해치는가** — −63.1pp 대 "동등 이상". (§3.6)
6. **모델 크기와 근거 충실도** — 8B가 23.28% 열세 대 "크기가 충실도를 보장하지 않는다". (§3.4)
7. **지시·목표 재주입의 효과** — Recap +16~17점 대 "측정 가능한 개선 없음". (§3.1)
8. **RAGTruth 응답 수준 환각률** — 두 추출 결과가 어긋나며, 한쪽에는 100%를 넘는 값이 있어 단위가 백분율이 아닐 가능성이 있다. (§3.4)
9. **Gemma 3 4B의 인상** — 낮은 환각률(6.4%)과 낮은 응답률(67.3%)이 상반된 인상을 준다. (§3.4)
10. **MLX 문서 내부 충돌** — kv-cache.md의 권장 조합이 `fatalError`를 부른다. (§4.4)
11. **PR 상태 대 코드 상태** — #367이 closed지만 미병합이며 코드는 그대로다. (§4.2)

---

## 6. 출처

### 규제·가이드라인
- https://le.utah.gov/xcode/Title13/Chapter72A/C13-72a-P1_2025050720250507.pdf
- https://le.utah.gov/xcode/Title13/Chapter72A/C13-72a-P2_2025050720250507.pdf
- https://www.forbes.com/sites/lanceeliot/2025/08/20/nevada-enacts-new-law-to-shut-down-the-use-of-ai-for-mental-health-but-sizzling-loopholes-might-exist/
- https://idfpr.illinois.gov/content/dam/soi/en/web/idfpr/news/2025/2025-08-04-idfpr-press-release-hb1806.pdf
- https://www.bakerdonelson.com/illinois-passes-extensive-law-regulating-ai-in-behavioral-health
- https://leginfo.legislature.ca.gov/faces/billTextClient.xhtml?bill_id=202520260SB243
- https://artificialintelligenceact.eu/article/5/ · https://artificialintelligenceact.eu/article/50/ · https://artificialintelligenceact.eu/implementation-timeline/
- https://www.ftc.gov/news-events/news/press-releases/2025/09/ftc-launches-inquiry-ai-chatbots-acting-companions
- https://developer.apple.com/app-store/review/guidelines/ · https://developer.apple.com/news/?id=ez6mzhak

### 위기 대응·해악
- https://openai.com/index/helping-people-when-they-need-it-most/
- https://en.wikipedia.org/wiki/List_of_suicide_crisis_lines · https://www.spckorea.or.kr/
- https://www.courtlistener.com/docket/69300919/garcia-v-character-technologies-inc/
- https://arxiv.org/abs/2504.18412 · https://arxiv.org/abs/2510.01395 · https://arxiv.org/abs/2508.19258

### 소형 모델
- https://arxiv.org/abs/2505.06120 · https://github.com/microsoft/lost_in_conversation
- https://arxiv.org/abs/2410.15553 · https://arxiv.org/abs/2408.10943 · https://arxiv.org/html/2605.06353v1 · https://arxiv.org/html/2605.12922v1 · https://arxiv.org/abs/2501.17399
- https://arxiv.org/abs/2307.03172 · https://arxiv.org/abs/2404.06654 · https://www.trychroma.com/research/context-rot
- https://github.com/vectara/hallucination-leaderboard · https://arxiv.org/abs/2401.00396 · https://arxiv.org/html/2410.03727
- https://arxiv.org/abs/2505.20276 · https://arxiv.org/html/2406.10251v2
- https://arxiv.org/abs/2408.02442 · https://blog.dottxt.ai/say-what-you-mean.html · https://arxiv.org/html/2607.18476
- https://ai.google.dev/gemma/docs/core/model_card_3 · https://arxiv.org/pdf/2503.19786

### MLX Swift (3.31.4 소스 직접 검증)
- https://github.com/ml-explore/mlx-swift-lm/blob/3.31.4/Libraries/MLXLMCommon/ChatSession.swift
- https://github.com/ml-explore/mlx-swift-lm/blob/3.31.4/Libraries/MLXLMCommon/KVCache.swift
- https://github.com/ml-explore/mlx-swift-lm/pull/414 · /pull/367 · /pull/370 · /pull/436
- https://github.com/ml-explore/mlx-swift-lm/issues/312 · /issues/358 · /issues/452 · /issues/474

조사 제약: 웹 검색 예산 소진 후에는 1차 URL 직접 조회로만 진행했다. ilga.gov 네트워크 차단, leg.state.nv.us·legiscan·justia·rand.org·psychiatryonline·web.archive.org 접근 제한. 위 미확인 항목 중 상당수는 재조사하면 확보될 것으로 보인다.
