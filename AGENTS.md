# AGENTS.md — Gravity Orb

Godot 4 / GDScript 기반 턴제 물리 퍼즐 프로토타입. 이 파일은 구현 에이전트(Codex)의 작업 규칙이다.

## 역할 분담

| 담당 | 역할 | 편집 대상 |
|---|---|---|
| **Claude** | 설계·명세 작성, 코드 리뷰, QA 결과 판정 | `docs/technical_design.md`, `docs/jeongmo_claude_to_codex.md`, `config/default_config.tres`의 **기존 값** |
| **Codex** | 구현, 테스트 작성·실행, QA 관측 | `.gd`, `.tscn`, `.tres`, `project.godot`, `tests/`, `GameConfig` **새 필드**, `docs/jeongmo_codex_to_claude.md` |

- 수치는 기획이다. 명세에 적힌 값은 Claude가 정한다. Codex는 **임의로 값을 바꾸지 않고** `상태: 질문`으로 올린다.
- 합격·불합격 판정은 Claude가 한다. Codex는 관측값만 보고한다.

## 문서

| 문서 | 역할 |
|---|---|
| [`docs/jeongmo_claude_to_codex.md`](docs/jeongmo_claude_to_codex.md) | **작업 지시 인박스.** 무엇을 할지는 여기서 시작한다 |
| [`docs/jeongmo_codex_to_claude.md`](docs/jeongmo_codex_to_claude.md) | **회신 인박스.** 결과·QA 관측값·질문을 여기에 쓴다 |
| [`docs/technical_design.md`](docs/technical_design.md) | **구현 기준.** 구조, API 시그니처, 수치, 알고리즘, 마일스톤별 구현 명세 |
| [`docs/reference/gravity_orb_design.md`](docs/reference/gravity_orb_design.md) | 기획서 (게임 규칙의 원본) |
| [`docs/reference/gravity_orb_roadmap.md`](docs/reference/gravity_orb_roadmap.md) | 마일스톤 목표·완료 조건 |

충돌 시 우선순위: 인박스 지시 > 기획서 > technical_design.md > 로드맵. `docs/reference/`는 원본 사본이므로 수정하지 않는다.

## 핸드오프 창구 — 고정 파일 2개

| 파일 | 쓰는 쪽 | 읽는 쪽 |
|---|---|---|
| `docs/jeongmo_claude_to_codex.md` | **Claude** | Codex |
| `docs/jeongmo_codex_to_claude.md` | **Codex** | Claude |

- **각자 자기 파일만 쓴다.** 상대 파일은 절대 고치지 않는다. (로컬에서는 워킹트리를, 클라우드에서는 브랜치 병합을 공유하므로 같은 파일을 양쪽이 쓰면 충돌·손실이 난다)
- 새 항목은 맨 위에 추가한다. 인수인계 번호(#N)는 Claude가 매기며 재사용하지 않는다.
- **긴 명세는 인박스에 붙여넣지 않는다.** `technical_design.md` 또는 별도 문서에 두고 링크와 요약만 적는다.
- 모호하면 `상태: 질문`으로 올리고 멈춘다. 추측으로 진행하지 않는다.
- 완료 항목이 30건을 넘으면 `docs/archive/`로 옮긴다.
- 새 `handoff_*.md` 같은 파일을 따로 만들지 않는다.

## 작업 방식

1. `jeongmo_claude_to_codex.md`의 「대기 중」 항목 중 **가장 번호가 낮은 것 하나만** 처리한다. 항목에 없는 기능·config 필드를 미리 넣지 않는다.
2. 항목의 `근거` 링크(보통 `technical_design.md` 12장 해당 마일스톤)와 로드맵의 완료 조건을 읽는다.
3. 구현 → 검증 명령 실행 → `jeongmo_codex_to_claude.md`에 회신을 쓴다. 회신에는:
   - Done-when 대조 (자동 검증 / 수동 확인 구분)
   - 자동화하지 못한 항목의 **수동 확인 절차** (무엇을 누르고 무엇을 봐야 하는지)
   - 문서에 없던 결정 사항, 알려진 문제
4. 공개 API·신호 이름을 설계서와 다르게 바꿔야 하면 **먼저 질문으로 올린다.** (`technical_design.md`는 Claude가 고친다)
5. 회신 파일 갱신은 구현과 같은 커밋·PR에 포함한다.

## 코딩 규칙 (요약 — 상세는 technical_design.md 3.4, 13장)

- GDScript **타입 명시 필수** (변수·인자·반환값).
- 밸런스 수치는 `Config.data.*`에서 읽는다. 하드코딩 금지.
- `Input` / `InputEvent*`는 `scripts/autoload/InputRouter.gd`에서만 사용한다. (예외: `scripts/platform/Haptics.gd`의 진동)
- 물리 콜백(`body_entered` 등)에서 노드 생성·삭제 금지. 기록 후 `CollisionResolver.flush()`에서 처리.
- 난수는 `Spawner`의 `RandomNumberGenerator`만 사용. 전역 `randf/randi/shuffle/pick_random` 금지.
- RigidBody2D·CollisionShape2D를 스케일하지 않는다. 연출은 `Visual` 자식 노드로.
- 새 파일은 설계서 1.3 폴더 구조를 따른다. 파일명 PascalCase = `class_name`.
- 외부 애드온을 추가하지 않는다.

## 검증 명령

엔진은 **Godot 4.8**이다 (로컬: `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe`). 다른 버전으로 검증했다면 회신에 버전을 적는다.
`godot` 실행 파일 경로가 다르면 `GODOT` 환경변수를 사용한다.

```bash
godot --headless --path . --import
godot --headless --fixed-fps 120 --path . -s res://tests/run_tests.gd -- --test-suite=general
godot --headless --fixed-fps 120 --path . -s res://tests/run_tests.gd -- --test-suite=long
godot --headless --path . --quit-after 300
godot --headless --path . --quit-after 300 -- --mode=blitz
```

항목 완료 전 위 명령 모두 에러 없이 통과해야 한다 (`SCRIPT ERROR`, `Parse Error` 출력 없음, 테스트 종료 코드 0). 일반·장기 테스트 묶음은 **반드시 각각 새 프로세스**로 돌린다 (설계서 §10.1). **권장: `.\tests\run_tests.ps1`** — 일반·장기·성능 세 묶음을 각각 새 프로세스로 `--fixed-fps 120` 실행 (약 40초).
Godot를 실행할 수 없는 환경이면 회신에 **"미실행"과 사유**를 명시한다. 실행하지 않은 검증을 통과했다고 적지 않는다.
**화면에 보이는 것을 바꾸는 항목**(HUD·연출·배치)은 #50 이후 `tests/capture_screens.ps1`로 장면을 찍어 직접 보고, 회신에 찍은 장면 목록과 확인한 내용을 적는다. 헤드리스 테스트만으로 화면 항목을 완료라고 하지 않는다.

규칙 점검용:

```bash
grep -rn "Input\.\|InputEvent" scripts --include=*.gd      # InputRouter.gd, Haptics.gd 외 없어야 함
grep -rn "randf\|randi\|shuffle\|pick_random" scripts --include=*.gd   # Spawner.gd 외 없어야 함
```

## 브랜치·커밋

- 항목 단위 브랜치: `m0-project-setup`, `m1-board-physics` …
- 커밋 메시지 접두어: `[#1 M0] 프로젝트 셋업` 형식.
- `main`에 직접 push하지 않는다. PR로 올리고 병합은 Claude(또는 사용자)가 한다.
