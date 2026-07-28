# Architecture Decision Records

구조를 바꾸는 결정과 그 이유를 남깁니다. 나중에 "왜 이렇게 했지"라는 질문에 커밋 로그를 뒤지지 않아도 되게 하는 것이 목적입니다.

## 언제 쓰는가

되돌리기 어렵거나, 대안이 여럿이었거나, 나중 사람이 뒤집고 싶어질 결정에 씁니다. 일상적인 구현 선택은 코드와 주석으로 충분합니다.

## 형식

[MADR](https://adr.github.io/madr/)을 따릅니다. 파일명은 `NNNN-kebab-case-title.md`이며 번호는 순차 증가합니다. 한 번 부여한 번호는 재사용하지 않습니다.

```markdown
# NNNN. 제목

- 상태: proposed | accepted | superseded by ADR-NNNN
- 날짜: YYYY-MM-DD

## 맥락

## 결정

## 결과
```

상태가 `superseded`가 되어도 파일을 지우지 않습니다. 뒤집힌 결정도 기록입니다.

## 조사 노트와의 관계

[docs/research/](../research/)의 조사 노트가 먼저이고 ADR이 나중입니다. 조사로 사실을 모으고, 그 사실이 결정을 낳으면 ADR로 승격합니다. ADR은 결론과 근거 링크만 담고 조사 과정은 노트에 남겨 둡니다.

## 목록

| # | 제목 | 상태 |
|---|---|---|
| [0001](./0001-record-architecture-decisions.md) | 아키텍처 결정을 기록한다 | accepted |
| [0002](./0002-separate-deterministic-engine-from-llm.md) | 계산 엔진과 언어 모델을 분리한다 | accepted |
| [0003](./0003-compute-astronomy-in-process.md) | 천문 계산을 앱 안에서 직접 수행한다 | accepted |
| [0004](./0004-rule-index-over-vector-retrieval.md) | 벡터 검색 대신 룰 인덱스를 쓴다 | accepted |
| [0005](./0005-expose-school-differences-as-settings.md) | 유파 차이를 설정으로 드러낸다 | accepted |
| [0006](./0006-generation-state-belongs-to-the-document.md) | 생성 상태는 뷰가 아니라 문서에 둔다 | accepted |
| [0007](./0007-describe-days-do-not-rank-them.md) | 날을 서술하되 등급을 매기지 않는다 | accepted |
| [0008](./0008-ship-arm64-only.md) | arm64 전용으로 배포한다 | accepted |
