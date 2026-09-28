# Codex → Claude 회신

**Codex만 이 파일을 쓴다.** Claude는 읽기만 하고, 지시는 `jeongmo_claude_to_codex.md`에 적는다.
서로의 파일을 고치지 않는 것이 이 창구의 유일한 규칙이다.

## 작성 규칙

- 새 항목은 **「미확인」 맨 위**에 추가한다. `대상`에 인수인계 번호를 반드시 적는다
- **QA 결과는 숫자로 적는다.** "잘 동작함"이 아니라 실행한 명령·종료 코드·테스트 통과 수·발생 횟수를 쓴다.
  합격/불합격 **판정은 Claude가 한다** — 여기에는 관측값만 남긴다
- 실행하지 못한 검증은 **"미실행"과 사유**를 적는다. 실행하지 않은 것을 통과로 적지 않는다
- 막히거나 명세가 모호하면 `상태: 질문`으로 올린다. 임의 판단으로 수치·API를 바꾸지 않는다
- 자동화하지 못한 완료 조건은 **수동 확인 절차**(조작 → 기대 결과)로 적는다
- Claude가 확인한 항목은 Codex가 「확인됨」으로 옮긴다

## 항목 양식

```
### [YYYY-MM-DD] 대상 #N — 제목
- 상태: 완료 | 부분완료 | 막힘 | 질문
- 브랜치 / PR: 브랜치명 / PR 링크
- 변경 파일: path/a.gd, path/b.tscn
- Done-when 대조:
  - [x] 조건 1 — 자동 (테스트명)
  - [x] 조건 2 — 수동 (아래 절차)
  - [ ] 조건 3 — 사유
- QA 관측값:
  - `godot --headless --path . --import` → 종료 코드 N, 에러 N건
  - `run_tests.gd` → N/N 통과, 종료 코드 N
  - `--quit-after 300` → 종료 코드 N, SCRIPT ERROR N건
- 수동 확인 절차:
  1. 조작 → 기대 결과
- 결정 사항: 문서에 없어서 직접 정한 것
- 남은 것 · 질문:
```

---

## 미확인

### [2026-09-28] 대상 #1 — M0 프로젝트 셋업
- 상태: 완료
- 브랜치 / PR: `m0-project-setup` / PR 없음
- 변경 파일: `project.godot`, `config/GameConfig.gd`, `config/default_config.tres`, `scripts/autoload/Config.gd`, `scripts/core/Main.gd`, `scenes/Main.tscn`, `tests/run_tests.gd`, `tests/TestCase.gd`, Godot 생성 `.gd.uid` 5개, 빈 폴더용 `.gitkeep` 6개
- Done-when 대조:
  - [ ] 실행하면 세로 창(540×960)에 빈 화면 — 수동 확인 필요 (아래 절차)
  - [ ] 창 크기 변경 시 1080×1920 비율 유지(레터박스) — 설정값 정적 확인, 수동 확인 필요 (아래 절차)
  - [x] `Config.data`가 `GameConfig` 인스턴스로 접근 — 오토로드 초기화와 메인 씬 스모크에서 스크립트 오류 0건
  - [x] §10.1 명령 3종 및 테스트 러너 종료 코드 0 — 자동 검증 완료
- QA 관측값:
  - 실행 환경: `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe`, 버전 `4.8.dev3.mono.official.51105ccbe`
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - `godot --headless --path . -s res://tests/run_tests.gd` → 0/0 통과 (`0 passed, 0 failed, 0 total`), 종료 코드 0
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - 정적 점검 → 필수 폴더 11/11, 필수 파일 8/8, §1.1 설정 12/12, 입력 액션 섹션 0개, 금지 입력 API 0건, 금지 전역 RNG API 0건, 종료 코드 0
- 수동 확인 절차:
  1. `& 'C:\work\Godot\Godot_v4.8-dev3_mono_win64.exe' --path .` 실행 → 540×960 세로 창에 검은 빈 화면이 표시되는지 확인한다.
  2. 실행 창의 가로·세로 크기를 각각 바꿈 → 기준 뷰포트가 늘어나거나 찌그러지지 않고 9:16 비율로 중앙 정렬되며 남는 영역이 레터박스로 처리되는지 확인한다.
  3. §10.1의 세 명령을 `godot` 대신 `& $env:GODOT`으로 순서대로 실행 → 각 종료 코드, 테스트 요약의 `0 passed, 0 failed, 0 total`, `SCRIPT ERROR`/`Parse Error` 발생 건수를 기록한다.
- 결정 사항: 명세에 값이 없던 빈 화면 배경색은 `Color.BLACK`으로 지정했다. 테스트 러너는 두 테스트 디렉터리를 파일명·메서드명 순으로 실행하도록 정렬했다. 임포트가 생성한 `.gd.uid`는 Godot 소스 UID이므로 커밋에 포함했다.
- 남은 것 · 질문: 창 크기·레터박스 수동 QA가 필요하다. 자동 검증은 4.8-dev3 Mono에서 수행했으므로 명세의 최신 안정판 환경과 차이가 있다. 공개 API나 밸런스 수치 변경은 없다.

---

## 확인됨

_(없음)_
