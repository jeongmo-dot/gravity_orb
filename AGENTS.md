# AGENTS.md — Gravity Orb

Godot 4 / GDScript 기반 턴제 물리 퍼즐 프로토타입. 이 파일은 구현 에이전트(Codex)의 작업 규칙이다.

## 문서

| 문서 | 역할 |
|---|---|
| [`docs/technical_design.md`](docs/technical_design.md) | **구현 기준.** 구조, API 시그니처, 수치, 알고리즘, 마일스톤별 구현 명세 |
| [`docs/reference/gravity_orb_design.md`](docs/reference/gravity_orb_design.md) | 기획서 (게임 규칙의 원본) |
| [`docs/reference/gravity_orb_roadmap.md`](docs/reference/gravity_orb_roadmap.md) | 마일스톤 목표·완료 조건 |
| `docs/progress.md` | 진행 기록. 에이전트가 생성·갱신한다 |

충돌 시 우선순위: 기획서 > technical_design.md > 로드맵. 문서에 없는 결정을 내렸다면 `docs/progress.md`의 해당 마일스톤 "결정 사항"에 기록한다.

## 작업 방식

1. **한 번에 한 마일스톤만** 구현한다 (M0 → M1 → …). 요청받은 마일스톤 외의 기능·config 필드를 미리 넣지 않는다.
2. 시작 전 `technical_design.md` 12장의 해당 마일스톤 항목과 로드맵의 완료 조건을 읽는다.
3. 마일스톤 완료 시 `docs/progress.md`를 갱신한다:
   - 완료 조건 체크리스트 (자동 검증 / 수동 확인 구분)
   - 자동화하지 못한 항목의 **수동 확인 절차** (무엇을 누르고 무엇을 봐야 하는지)
   - 결정 사항, 알려진 문제
4. 공개 API·신호 이름을 설계서와 다르게 바꿔야 하면 `technical_design.md`도 같은 변경에서 수정한다.

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

`godot` 실행 파일 경로가 다르면 `GODOT` 환경변수를 사용한다.

```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
godot --headless --path . --quit-after 300
```

마일스톤 완료 전 세 명령 모두 에러 없이 통과해야 한다 (`SCRIPT ERROR`, `Parse Error` 출력 없음, 테스트 종료 코드 0).

규칙 점검용:

```bash
grep -rn "Input\.\|InputEvent" scripts --include=*.gd      # InputRouter.gd, Haptics.gd 외 없어야 함
grep -rn "randf\|randi\|shuffle\|pick_random" scripts --include=*.gd   # Spawner.gd 외 없어야 함
```

## 커밋

- 마일스톤 단위 브랜치 권장: `m1-board-physics`, `m2-input-router` …
- 커밋 메시지 접두어: `[M1] 보드 벽과 구체 중력 구현` 형식.
- `docs/progress.md` 갱신은 해당 마일스톤 커밋에 함께 포함한다.
- `docs/reference/`는 원본 기획 문서의 사본이다. 에이전트는 수정하지 않는다 (원본 갱신 시 사람이 다시 복사한다).
