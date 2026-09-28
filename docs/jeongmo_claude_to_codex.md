# Claude → Codex 인수인계

**Claude만 이 파일을 쓴다.** Codex는 읽기만 하고, 답변은 `jeongmo_codex_to_claude.md`에 적는다.
서로의 파일을 고치지 않는 것이 이 창구의 유일한 규칙이다.

## 작성 규칙

- 새 항목은 **「대기 중」 맨 위**에 추가한다. 번호는 계속 증가하며 **재사용하지 않는다**
- 상태는 **Claude가** 갱신한다. Codex의 회신을 확인한 뒤 `완료`로 바꾸고 「처리 완료」로 옮긴다
- **긴 명세는 여기에 붙여넣지 않는다.** `technical_design.md` 또는 별도 문서에 두고 **링크와 요약만** 적는다
- Codex는 「대기 중」에서 **번호가 가장 낮은 항목 하나만** 처리한다
- 완료 항목이 30건을 넘으면 `docs/archive/`로 옮긴다

## 항목 양식

```
### [YYYY-MM-DD #N] 제목
- 상태: 대기 | 진행중 | 완료
- 근거: docs/technical_design.md §X.Y  (또는 별도 명세 파일 링크)
- 앵커: path/to/File.gd `func_name()`  (기존 코드 수정 시)
- 요구: 무엇을 어떻게 바꿔야 하는가
- 수치: 값은 Claude가 정해서 여기에 못박는다
- 건드리지 말 것:
- Done-when:
  - [ ] 검증 가능한 조건
- QA: 실행할 명령·시드·확인할 로그
```

---

## 대기 중

### [2026-09-28 #3] M2 입력 추상화
- 상태: 대기
- 근거: [technical_design.md](technical_design.md) §1.2 (입력 액션), §3.4-1 (입력 격리), §4 (M2 필드), §5.4 `SwipeDetector`, §5.5 `InputRouter`, §12 M2, §13 (이중 이벤트)
- 요구:
  - `GameConfig`에 M2 필드 `swipe_min_distance`(80.0), `swipe_dominance_ratio`(1.5) 추가, `default_config.tres` 기록
  - Input Map에 `gravity_up/down/left/right` 등록 (↑↓←→ + WASD). `restart`·`debug_*` 액션은 **이번에 넣지 않는다**
  - `scripts/core/SwipeDetector.gd` — §5.4. `static func classify(delta, min_distance, dominance_ratio) -> Vector2i`. `InputEvent` 타입을 참조하지 않는 순수 함수
  - `scripts/autoload/InputRouter.gd` — §5.5, 오토로드 등록. 이번 공개 API는 `signal swipe(direction: Vector2i)`, `set_locked()`, `is_locked()`만 (`restart_requested`·`debug_*`는 M7·M9)
    - `_unhandled_input`에서 받는다. 이벤트 처리 본문은 `_handle_event(event: InputEvent) -> void`로 분리해 테스트가 직접 호출할 수 있게 한다
    - 포인터 제스처: 누름 시 활성 제스처가 없을 때만 시작, **시작한 source(MOUSE/TOUCH)의 뗌만** 종료·판정. 터치는 index 0만, 마우스는 좌클릭만
    - 잠금 중 시작한 제스처는 잠금이 풀린 뒤 떼어도 무시 (`started_locked`)
    - 키보드는 `is_action_pressed(..., false)`(에코 제외)로 즉시 발신
  - `Main.gd`: `# TEMP(M1)` 방향키 처리 제거 → `InputRouter.swipe`를 `Board.set_gravity`에 연결 (M3에서 `TurnManager`로 교체). `# TEMP(M1): M4에서 Spawner로 교체` 테스트 구체는 유지
  - 테스트 `tests/test_swipe.gd`, `tests/test_input_router.gd`
- 수치: `swipe_min_distance` 80.0 (기준 해상도 px), `swipe_dominance_ratio` 1.5. 임의 변경 금지
- 건드리지 말 것: `docs/` (회신 파일 제외), 물리 설정(240 tick·접촉 설정), `Board`·`Orb` 공개 API, `project.godot`의 `emulate_touch_from_mouse`(기본값 false 유지, 검증 때만 임시로 켠다)
- Done-when:
  - [ ] 키보드(방향키·WASD)와 마우스 드래그 모두로 중력 전환이 된다
  - [ ] "마우스로 터치 에뮬레이션"을 켜도 드래그 1회에 `swipe`가 **정확히 1회** 발신된다
  - [ ] 짧은 클릭·대각선 애매한 드래그는 무시된다
  - [ ] `grep -rn "Input\.\|InputEvent" scripts --include=*.gd` 결과가 `InputRouter.gd`뿐이다
  - [ ] `test_swipe.gd`: 아래 표 전부
  - [ ] `test_input_router.gd`: 아래 표 전부 (`_handle_event`에 합성 이벤트 주입, `swipe` 발신 횟수·방향 기록)
  - [ ] §10.1 명령 3종 에러 0, 테스트 종료 코드 0 (`--fixed-fps 240` 허용)
- 테스트 케이스 (min 80, ratio 1.5):

| 파일 | 입력 | 기대 |
|---|---|---|
| test_swipe | delta (200, 0) / (−200, 0) / (0, 200) / (0, −200) | RIGHT / LEFT / DOWN / UP |
| test_swipe | (79.9, 0) | ZERO (짧음) |
| test_swipe | (80, 0) | RIGHT (경계 포함) |
| test_swipe | (150, 100) | RIGHT (150 ≥ 100×1.5 경계 포함) |
| test_swipe | (149, 100) | ZERO (대각선) |
| test_swipe | (100, 100) | ZERO |
| test_input_router | 마우스 좌클릭 누름 (100,100) → 뗌 (300,110) | RIGHT 1회 |
| test_input_router | 터치 index 0 누름 → 뗌 (위로 200) | UP 1회 |
| test_input_router | 에뮬레이션 재현: 마우스 누름·터치 누름 → 마우스 뗌·터치 뗌 (같은 좌표, 아래로 200) | DOWN **1회** |
| test_input_router | 터치 index 1 누름·뗌 | 0회 |
| test_input_router | 마우스 우클릭 드래그 | 0회 |
| test_input_router | 짧은 클릭 (이동 30) | 0회 |
| test_input_router | `set_locked(true)` 상태 드래그 | 0회 |
| test_input_router | 잠금 중 누름 → `set_locked(false)` → 뗌 | 0회 |
| test_input_router | 키 이벤트 `gravity_left` 액션 (A) / 에코 | LEFT 1회 / 0회 |

- QA: 테스트 결과 요약. 수동 확인 절차(키보드 8키, 마우스 드래그 4방향, 에뮬레이션 켜고 드래그, 짧은 클릭·대각선)를 회신에 적는다

---

## 처리 완료

### [2026-09-28 #2] M1 보드와 구체 물리 — 완료
- 상태: 완료 (2026-09-28 Claude 검수 통과 · [PR #2](https://github.com/jeongmo-dot/gravity_orb/pull/2) 병합 `1df430d`)
- 검수: 22시드 × 방향당 2초 × 4바퀴 이탈 0건·최대 관통 8.623px, Claude 재실행 일치. 방향키 중력 전환·레벨별 크기 차이는 사용자 수동 확인 완료. 확정 설정: 물리 240 tick/s + `contact_max_allowed_penetration=0.1`
- 근거: [technical_design.md](technical_design.md) §2 (좌표·레이아웃), §4 (M1 필드·`radius_for_level`·`mass_for_level`), §5.1~5.3 (`OrbTypes`·`Orb`·`Board`), §12 M1, §13
- 요구:
  - `GameConfig`에 §4 표의 **M1 필드만** 추가하고 `default_config.tres`에 기본값 기록. 도우미 `radius_for_level()`, `mass_for_level()` 추가
  - `OrbTypes.gd` — §5.1 (`OrbColor`, `DIRECTIONS`, `dir_name()`, `perpendicular()`)
  - `Orb.tscn` + `Orb.gd` + `OrbVisual.gd` — §5.2. `setup()`에서 `CircleShape2D.new()`, 중력은 `constant_force`, `can_sleep = false`, CCD `CAST_SHAPE`. `contact_monitor`·`generation`·`consumed`는 **M5에서 넣으므로 지금 넣지 않는다**. 시각은 `color_display` 단색 원
  - `Board.tscn` + `Board.gd` — §5.3 트리. 이번 항목의 공개 API는 `half_size()`, `set_gravity()`, `spawn_orb()`, `remove_orb()`, `get_orbs()`, `clear()`만. 벽 4개 크기·위치는 `_ready`에서 config로 설정. `Frame`은 보드 경계선만 그린다
  - `Main.tscn`에 `Board` 배치 (position 540, 960)
  - **임시 입력**: `Main.gd`에서 방향키로 `Board.set_gravity()` 호출. 주석 `# TEMP(M1): M2에서 InputRouter로 교체`. 이 임시 코드에 한해 `Input`/`InputEvent` 사용을 허용한다
  - **임시 테스트 구체**: 시작 시 `debug_test_orb_count`개를 레벨 1~4·3색 섞어 **서로·벽과 겹치지 않게** 배치. 임시 `RandomNumberGenerator` 사용 허용, 주석 `# TEMP(M1): M4에서 Spawner로 교체`
  - 초기 중력 DOWN
  - 테스트 `tests/test_config.gd`
- 수치: §4 M1 행 기본값 그대로 (board_size 960, r₀ 50, growth 1.25, gravity 2400, 마찰 0.3, 반발 0.15 등). 임의 변경 금지
- 건드리지 말 것: `docs/` (회신 파일 제외), `.gitattributes`, M2 이후 필드·신호·API
- 참고: 워킹트리의 `project.godot`에 에디터(4.8 mono)가 자동으로 다시 쓴 변경이 있다 (기본값 항목 제거, `features` 4.8, `[dotnet]` 추가). 되돌리지 말고 이 항목 커밋에 그대로 포함한다. 그 외 설정은 §1.1과 동등해야 한다
- Done-when:
  - [x] 방향키 4개로 중력이 바뀌고 모든 구체가 그 벽으로 굴러간다
  - [x] 구체가 벽을 뚫거나 보드 밖으로 나가지 않는다
  - [x] 레벨이 다른 구체의 크기가 눈에 띄게 다르다
  - [x] `test_config.gd`: `radius_for_level(1..7)`이 50 × {1.00, 1.25, 1.5625, 1.953125, 2.44140625, 3.0517578125, 3.814697265625} (오차 1e-3), `mass_for_level(2)` = 1.5625
  - [x] §10.1 명령 3종 에러 0, 테스트 종료 코드 0
- QA:
  - 자동: §10.1 명령 3종. 가능하면 헤드리스 시나리오로 **보드 밖 이탈 0건**을 수치로 확인 — 테스트 구체 배치 후 중력을 DOWN→RIGHT→UP→LEFT 순으로 각 120 물리 프레임씩 바꿔가며 4바퀴, 매 프레임 모든 구체 중심이 `|x|,|y| <= half`인지 검사. 이탈 건수·최대 속도를 회신
  - 수동: 방향키 조작·크기 차이 확인 절차를 회신에 적는다

**추가 요구 1 (2026-09-28) — 보드 이탈 간헐 발생**

Claude 재실행 결과 `run_tests.gd` **15회 중 1회 실패**: `departures=1 max_speed=1973.854` (나머지 14회 0건, max_speed 1573~1952).
테스트 구체 RNG가 `randomize()`라 실패 배치를 재현할 수 없다.

1. **재현 가능하게** — 시나리오 테스트는 `Main.tscn`의 무작위 배치에 의존하지 않는다. 테스트가 `Board.tscn`을 직접 붙이고, 고정 시드 RNG로 M1과 같은 규칙(레벨 1~4·3색·겹침 없음)의 구체를 직접 배치한다
   - 시드 **1000~1019 (20개)** 각각 DOWN→RIGHT→UP→LEFT × 120프레임 × 4바퀴
   - 추가로 **최악 조건** 1건: 레벨 4 구체 4개 + 레벨 1 구체 4개, 시드 2000
   - `Main.gd`의 임시 배치는 그대로 둔다 (M4에서 교체)
2. **판정 강화** — 중심 이탈만이 아니라 **벽 관통 깊이** `max(|x|, |y|) + r − half`의 최대값을 기록한다
3. **원인 진단 후 수정** — 이탈이 재현되면 해당 시드·프레임·구체(레벨, 위치, 속도, 중력 방향)를 회신에 적고 원인을 관측값으로 설명한다. 수정 수단은 Codex 판단 (예: `physics/2d/solver/solver_iterations`, 벽·구체 CCD, 물리 틱). **밸런스 필드(§4 M1 값)는 바꾸지 않는다.** 바꾼 설정과 수정 전·후 수치를 회신한다
4. 20개 시드 모두 원인 불명으로 재현되지 않으면 시드 범위를 **1000~1099**로 넓혀 한 번 더 확인한다

- Done-when (추가):
  - [x] 시드 20개 + 최악 조건 1건에서 중심 이탈 **0건**
  - [x] 전체 최대 관통 깊이 **10px 이하**
  - [x] `run_tests.gd` **연속 10회** 전부 종료 코드 0
- QA: 시드별 `departures / 최대 관통 깊이 / max_speed` 표, 연속 10회 실행 결과
- 커밋: 같은 브랜치 `m1-board-physics`에 추가 커밋 (PR #2 갱신)

**추가 요구 2 (2026-09-28) — 시나리오 시간 보정 + 접촉 설정**

추가 요구 1 회신 검수: 진단(60Hz 틱 해상도 부족, solver 반복 무효)은 타당하다. 단 **테스트가 방향당 120프레임 고정**이라
240Hz에서는 방향당 0.5초만 시뮬레이션된다 (60Hz 때 2초). 수정 전·후 비교 조건이 달랐다.
Claude가 스크래치 복사본에서 방향당 **2초**로 맞춰 재측정한 결과 (22시드, `--fixed-fps`):

| 설정 | 이탈 | 최대 관통 |
|---|---:|---:|
| 240Hz (현재 브랜치) | 0 | **11.399px** (시드 1003) — 기준 초과 |
| 240Hz + `2d/solver/contact_max_allowed_penetration=0.1` | 0 | **8.623px** |
| 240Hz + `2d/solver/default_contact_bias=0.95` | 0 | 16.069px |
| 120Hz + `contact_max_allowed_penetration=0.1` | 0 | 27.394px |

1. 시나리오 길이를 **방향당 2.0 시뮬레이션 초**로 바꾼다. 프레임 수는 `Engine.physics_ticks_per_second × 2.0`으로 계산하고 상수로 박지 않는다 ([technical_design.md](technical_design.md) §10.3 아래 규약)
2. `project.godot`에 `physics/2d/solver/contact_max_allowed_penetration = 0.1` 추가. 물리 틱 240 유지
3. 시나리오 테스트는 결정적이므로 「연속 10회」 조건은 **3회**로 줄인다. `--fixed-fps 240` 사용 허용

- 설계서 반영 (Claude, 이 브랜치): §1 물리 240 tick·접촉 설정, §4 `stable_frames` → **`stable_duration` (초, 0.33)** (M3에서 이 이름으로 구현), §10 시나리오 규약, §13 함정
- Done-when (추가 요구 1 대체):
  - [x] 22시드(1000~1019, 1047, 2000) × 방향당 2초 × 4바퀴에서 중심 이탈 **0건**
  - [x] 전체 최대 관통 깊이 **10px 이하**
  - [x] `run_tests.gd` 3회 종료 코드 0, §10.1 `--import`·`--quit-after 300` 에러 0
- QA: 시드별 `departures / 최대 관통 / max_speed` 표 (Claude 수치와 대조용)
- 커밋: 같은 브랜치 `m1-board-physics`

### [2026-09-28 #1] M0 프로젝트 셋업 — 완료
- 상태: 완료 (2026-09-28 Claude 검수 통과 · [PR #1](https://github.com/jeongmo-dot/gravity_orb/pull/1) 병합 `29c9d1e`)
- 검수: 헤드리스 명령 3종 Claude 재실행 결과 회신과 동일. 창 540×960·레터박스는 사용자 수동 확인 완료
- 근거: [technical_design.md](technical_design.md) §1 (설정·입력·폴더), §3.1 (`Config` 오토로드), §10.1~10.2 (테스트 러너), §12 M0
- 요구:
  - `project.godot` 생성 — §1.1 표의 설정 전부. 입력 액션(§1.2)은 **M2에서 등록하므로 지금 넣지 않는다**
  - §1.3 폴더 구조 생성, 빈 폴더는 `.gitkeep`
  - `config/GameConfig.gd` (`class_name GameConfig extends Resource`, **필드 없음**), `config/default_config.tres`
  - `scripts/autoload/Config.gd` — `default_config.tres`를 `duplicate(true)`해 `Config.data`로 보관. 오토로드 등록
  - `scenes/Main.tscn` + `scripts/core/Main.gd`: Main(Node2D) + Camera2D(position 540, 960). 배경색은 `RenderingServer.set_default_clear_color`
  - `tests/run_tests.gd`, `tests/TestCase.gd` — §10.2 규약. 테스트 0개로 통과하고 종료 코드 0
  - `.gitignore`는 이미 있다. 필요한 항목만 추가
- 수치: 기준 해상도 1080×1920, 창 540×960, 물리 60 tick/s (§1.1 그대로)
- 건드리지 말 것: `docs/` 전체 (회신 파일 제외), `.gitattributes`
- Done-when:
  - [x] 실행하면 세로 창(540×960)에 빈 화면이 뜬다
  - [x] 창 크기를 바꿔도 1080×1920 비율이 유지된다 (레터박스)
  - [x] `Config.data`가 `GameConfig` 인스턴스로 접근된다
  - [x] §10.1 명령 3종이 에러 없이 끝나고 테스트 러너 종료 코드 0
- QA: §10.1 명령 3종의 종료 코드와 출력 요약. 창 비율 확인은 수동 확인 절차로 회신에 적는다
