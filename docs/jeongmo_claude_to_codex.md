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

### [2026-09-28 #5] M4 구체 생성
- 상태: 대기
- 근거: [technical_design.md](technical_design.md) §4 (M4 필드), §5.3 `spawn_line`, §5.9 `Spawner`, §6 (`_on_settled`의 SPAWNING 분기), §11.3 (1~3단계), §12 M4
- 요구:
  - `GameConfig` M4 필드: `enum SpawnPositionMode { RANDOM, CENTER }`, `spawn_level_weights`([0.9, 0.1]), `spawn_color_weights`([1, 1, 1]), `spawn_position_mode`(RANDOM), `spawn_margin`(4.0), `rng_seed`(0), `initial_orb_count`(2)
  - **M1 임시 코드 삭제**: `debug_test_orb_count` 필드, `Main`의 `_test_rng`·`_spawn_test_orbs()`·`DEBUG_LEVEL_VARIANTS`. `test_board_physics.gd`가 쓰던 `debug_test_orb_count`는 테스트 내부 상수 `5`로 바꾼다 (물리 회귀 수치가 그대로 나와야 한다)
  - `Board.spawn_line(gravity, radius) -> Dictionary` — §5.3 공식 그대로. `is_circle_free()`는 **M7에서 만든다** (이번엔 막혀도 선호 위치에 생성)
  - `scripts/core/Spawner.gd` (`%Spawner`) — §5.9. 이번 공개: `signal next_changed(color, level)`, `seed_used`, `init_rng(seed) -> int`, `spawn_initial(board, gravity)`, `try_spawn(board, gravity) -> Orb` (M4에선 항상 생성, null 없음), `peek_next() -> Dictionary`
    - **RNG 소비 순서 고정**: 구체 1개당 정확히 `level(rand_weighted) → color(rand_weighted) → position(randf)` 3회. CENTER 모드여도 position을 뽑고 버린다
    - "다음 구체"는 뽑을 때 3개 값을 함께 저장해 두고, 생성 시 그 값을 쓴다 (position도 미리 뽑힌 값)
    - 선호 위치: RANDOM `s = lerpf(-extent, extent, t)`, CENTER `s = 0`. 생성 좌표 `origin + axis * s`, 초기 속도 0
    - `init_rng(0)`이면 `randomize()` 후 실제 `seed`를 `seed_used`에 저장하고 반환
  - **초기 구체** `spawn_initial`: `initial_orb_count`개를 일반 구체와 같은 3회 뽑기로 만들되 위치는 **바닥(중력 DOWN)에 등간격** — `i`번째(0부터) `x = lerpf(-half, half, (i + 1) / (n + 1))`, `y = half - r - spawn_margin`. 뽑은 position 값은 버린다. 초기 구체 뒤에 "다음 구체" 1개를 뽑아 `next_changed` 발신
  - `TurnManager`: settle 루프를 `SPAWNING`에서도 돌린다. `SIMULATING` 안정 → `Spawner.try_spawn(board, gravity)` → `_begin_settle()` → `SPAWNING` 안정 → `CHECK_GAMEOVER` → `WAITING_INPUT` (§6). 초기 settle은 여전히 생성 단계를 건너뛴다
  - `Main`: `Spawner` 노드 추가. `_ready`에서 `init_rng(Config.data.rng_seed)` → `spawn_initial()` → `start_game()`
  - **다음 구체 미리보기**: `UI.tscn`에 `Hud`(Control, 전체 화면, `mouse_filter = IGNORE`) + `scripts/ui/Hud.gd`. 상단 HUD 오른쪽(대략 (900, 240))에 "NEXT" 라벨과 `OrbVisual` 1개. `Spawner.next_changed`로 갱신. 모든 Control `mouse_filter = IGNORE`
  - 디버그 라벨에 `Seed: <seed_used>` 줄 추가
  - 테스트 `tests/test_spawner.gd`, `tests/scenarios/test_spawn_flow.gd`, 기존 `test_turn_manager.gd`·`test_board_physics.gd` 갱신
- 수치: 위 필드 기본값 그대로. 임의 변경 금지
- 건드리지 말 것: `docs/` (회신 파일 제외), 물리 설정, `InputRouter`, 입력 잠금 규칙, 전역 난수(`randf/randi/shuffle/pick_random` — `Spawner` 외 사용 금지)
- Done-when:
  - [ ] 아래로 스와이프하면 위쪽 벽에서, 왼쪽이면 오른쪽 벽에서 생성된다 (4방향 모두)
  - [ ] 미리보기와 실제 생성 구체가 일치한다
  - [ ] 같은 시드로 시작하면 같은 순서로 생성된다
  - [ ] `grep -rn "randf\|randi\|shuffle\|pick_random\|RandomNumberGenerator" scripts --include=*.gd` 결과가 `Spawner.gd`뿐이다
  - [ ] 아래 테스트 전부 통과, 물리 회귀 22시드 수치 변동 없음 (이탈 0, 8.623px)
  - [ ] §10.1 명령 3종 에러 0 (`--fixed-fps 240` 허용)
- 테스트:

| 파일 | 조건 | 기대 |
|---|---|---|
| test_spawner | 시드 1234로 Spawner 2개, 각각 50개 뽑기 | (level, color, t) 시퀀스 50개 완전 일치 |
| test_spawner | 시드 1234 vs 1235 | 시퀀스 불일치 |
| test_spawner | 시드 42, 10000개 뽑기 | 레벨1 비율 0.90 ± 0.02, 각 색 1/3 ± 0.02 |
| test_spawner | 같은 시드, RANDOM 모드 vs CENTER 모드 50개 | (level, color) 시퀀스 일치 (position 소비 확인) |
| test_spawner | `init_rng(0)` | `seed_used != 0`이고 반환값과 같다 |
| test_spawn_flow | 4방향 `spawn_line` (레벨1 반지름) | DOWN→ y = −(half − r − margin), UP→ y = +(…), LEFT→ x = +(…), RIGHT→ x = −(…) (오차 0.001) |
| test_spawn_flow | 초기 구체 2개 | 2개, 바닥 등간격 좌표, 서로·벽과 겹침 0 |
| test_spawn_flow | `peek_next()` 기록 → 스와이프 1턴 | 새로 생긴 구체의 color·level이 기록값과 같고, 생성 좌표가 생성 벽 선분 위 |
| test_spawn_flow | 시드 777로 2회 독립 실행, 각 5턴 (DOWN, LEFT, UP, RIGHT, DOWN) | 매 턴 생성 구체의 (color, level)과 생성 좌표가 두 실행에서 일치 |
| test_spawn_flow | 스와이프 3턴 | 구체 수 = 초기 2 + 3, 상태 순서에 SPAWNING settle 포함 |
| test_turn_manager | T1~T7 | 생성 단계가 추가된 흐름에 맞게 갱신 후 전부 통과 (T4·T5 타이밍 기준 유지) |

- QA: 테스트별 결과, 4방향 생성 좌표 표. 수동 확인 절차(시작 시 구체 2개·NEXT 표시, 스와이프마다 반대편 벽 생성, NEXT와 실제 일치, `rng_seed`를 고정값으로 바꿔 2회 실행 비교)를 회신에 적는다

---

## 처리 완료

### [2026-09-28 #4] M3 턴 상태 머신 — 완료
- 상태: 완료 (2026-09-28 Claude 검수 통과 · [PR #4](https://github.com/jeongmo-dot/gravity_orb/pull/4) 병합 `cdebea3`)
- 검수: 26/26, T4 0.333초/80틱, T5 3.000초/720틱 Claude 재실행 일치. 입력 잠금·재개·라벨 표시는 사용자 수동 확인 완료. 비차단 메모: `DebugHud`·테스트가 `_settle_elapsed` 비공개 필드 참조 → M9에서 정리
- 근거: [technical_design.md](technical_design.md) §3.2~3.3 (노드 트리·신호), §4 (M3 필드), §5.6 `TurnManager`, §6 (턴 처리 알고리즘), §11.1, §12 M3
- 요구:
  - `GameConfig`에 M3 필드 추가: `stable_linear_speed`(12.0), `stable_angular_speed`(1.0), **`stable_duration`(0.33, 초)**, `max_settle_time`(3.0), `allow_same_direction_swipe`(true). 프레임 수 기반 `stable_frames`는 **만들지 않는다** (§4 갱신 내용)
  - `scripts/core/TurnManager.gd` — §5.6·§6. 이번 범위:
    - `enum State { WAITING_INPUT, SIMULATING, SPAWNING, CHECK_GAMEOVER, GAME_OVER }` (GAME_OVER는 정의만, 진입 경로 없음)
    - 신호: `state_changed`, `gravity_changed`, `turn_started`, `turn_finished` (이번엔 `max_chain`에 항상 0). `chain_changed`·`warning_changed`·`game_over`는 **M5·M7**
    - 공개: `state`, `gravity`, `turn_index`, `start_game()`, `on_swipe(dir)`. `on_reaction()`은 M5
    - settle 루프는 `_physics_process(delta)`에서 **스케일된 delta**로 `stable_time`·`settle_elapsed` 누적. `flush`/`sweep`/`try_spawn` 호출은 넣지 않는다
    - `SPAWNING`·`CHECK_GAMEOVER`는 **각각 1회 `_set_state()`를 거쳐** 즉시 통과 (신호 순서가 관측되도록)
    - 강제 안정 시 `push_warning("forced settle ...")`에 턴 번호·경과 시간 포함
    - 상태 전이는 `_set_state()` 한 곳에서만. 입력 잠금은 `TurnManager`가 `InputRouter.set_locked()` 직접 호출
    - `start_game()`: 중력 DOWN → 초기 settle(`SIMULATING` 재사용, `_is_initial_settle`) → 생성 단계 건너뛰고 `WAITING_INPUT`. 초기 settle 동안 입력 잠금
  - `Main`: `TurnManager` 노드 추가(`%TurnManager`). `InputRouter.swipe` → `TurnManager.on_swipe` 로 **교체** (M2의 `Board.set_gravity` 직결 제거). `Board.set_gravity`는 `TurnManager`만 호출. 테스트 구체 배치 후 `start_game()`
  - `scenes/UI.tscn`(CanvasLayer) + 임시 디버그 `Label` — 상태 이름, 중력 방향, `turn_index`, settle 경과(소수 2자리). 상단 HUD 영역(y 0~480)에 배치, **`mouse_filter = IGNORE`** (§5.5). 신호 구독으로 갱신, TurnManager를 폴링하지 않는다 (settle 경과만 `_process`에서 읽어도 됨)
  - 테스트 `tests/scenarios/test_turn_manager.gd`
- 수치: 위 5개 필드 기본값 그대로. 임의 변경 금지
- 건드리지 말 것: `docs/` (회신 파일 제외), 물리 설정, `InputRouter`·`SwipeDetector` 판정 로직, `Board`·`Orb` 공개 API
- Done-when:
  - [x] 구체가 굴러가는 동안 입력이 무시된다
  - [x] 멈추면 다시 입력이 받아진다
  - [x] 계속 흔들리는 상황에서도 최대 대기 시간 후 턴이 넘어간다
  - [x] 디버그 텍스트로 현재 상태가 화면에 표시된다
  - [x] 아래 시나리오 테스트 전부 통과
  - [x] §10.1 명령 3종 에러 0 (`--fixed-fps 240` 허용), 기존 테스트 18개 회귀 없음
- 시나리오 테스트 (`Main.tscn`이 아니라 `Board` + `TurnManager`를 직접 조립, 고정 시드 구체 배치). **`Config.data`를 바꾼 테스트는 끝에 원래 값으로 복구**:

| # | 조건 | 기대 |
|---|---|---|
| T1 | `start_game()` | 초기 settle 후 `WAITING_INPUT`, 잠금 해제. `turn_index` 0 |
| T2 | 스와이프 RIGHT | 상태 순서 `SIMULATING → SPAWNING → CHECK_GAMEOVER → WAITING_INPUT` (state_changed 기록), `turn_started(1, RIGHT)`·`turn_finished(1, 0)` 각 1회, `gravity == RIGHT` |
| T3 | `SIMULATING` 중 `on_swipe(UP)` | 무시 — `turn_index`·`gravity` 불변. 이 동안 `InputRouter.is_locked()` true |
| T4 | 속도 임계값을 매우 크게(1e9) 설정 후 스와이프 | settle 시간 = `stable_duration` (±1 물리 tick) |
| T5 | `stable_linear_speed = 0.0`으로 안정 불가 후 스와이프 | **강제 안정** — settle 시간 = `max_settle_time` (±1 tick), 턴 완료 |
| T6 | `allow_same_direction_swipe = false`, 현재 중력과 같은 방향 스와이프 | 무시, 잠금 안 걸림, `turn_index` 불변 |
| T7 | `allow_same_direction_swipe = true`, 같은 방향 스와이프 | 턴 진행 (`turn_index` +1) |

- QA: 테스트별 결과와 T4·T5의 실측 settle 시간(초·tick). 수동 확인 절차(구르는 중 키 연타 → 무시, 멈춘 뒤 입력 → 반응, 디버그 라벨 상태 변화)를 회신에 적는다

### [2026-09-28 #3] M2 입력 추상화 — 완료
- 상태: 완료 (2026-09-28 Claude 검수 통과 · [PR #3](https://github.com/jeongmo-dot/gravity_orb/pull/3) 병합 `2657670`)
- 검수: 테스트 18/18·물리 회귀 동일 수치 Claude 재실행 일치, 입력 격리 grep `InputRouter.gd`만. 키보드·마우스·터치 에뮬레이션·무시 조건은 사용자 수동 확인 완료. 리뷰 중 §5.5에 GUI `mouse_filter`·터치 취소(M10) 주의 추가
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
  - [x] 키보드(방향키·WASD)와 마우스 드래그 모두로 중력 전환이 된다
  - [x] "마우스로 터치 에뮬레이션"을 켜도 드래그 1회에 `swipe`가 **정확히 1회** 발신된다
  - [x] 짧은 클릭·대각선 애매한 드래그는 무시된다
  - [x] `grep -rn "Input\.\|InputEvent" scripts --include=*.gd` 결과가 `InputRouter.gd`뿐이다
  - [x] `test_swipe.gd`: 아래 표 전부
  - [x] `test_input_router.gd`: 아래 표 전부 (`_handle_event`에 합성 이벤트 주입, `swipe` 발신 횟수·방향 기록)
  - [x] §10.1 명령 3종 에러 0, 테스트 종료 코드 0 (`--fixed-fps 240` 허용)
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
