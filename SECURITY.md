# Security Policy

## 취약점 신고

공개 이슈 대신 저장소의 [Security Advisories](https://github.com/waylake/four-eight/security/advisories/new)로 알려 주세요. 확인 후 회신하고, 수정 릴리스 노트에 신고자를 크레딧합니다(원치 않으시면 생략합니다).

## 이 앱이 다루는 데이터

- 생년월일시와 출생지는 `~/Library/Application Support/FourEight/people.json`에 평문 JSON으로 저장되며 전송되지 않습니다.
- 네트워크는 Hugging Face에서 모델 파일을 내려받을 때만 사용됩니다.
- 해석 생성은 전부 로컬에서 수행됩니다. 프롬프트와 응답이 외부로 나가지 않습니다.
- 앱 샌드박스에서 켠 권한은 `network.client`와 사용자 선택 파일 접근입니다.

생년월일시는 민감한 개인정보입니다. 이 데이터가 앱 밖으로 나가는 경로를 발견하셨다면 취약점으로 신고해 주세요.
