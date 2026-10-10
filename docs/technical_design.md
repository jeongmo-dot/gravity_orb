# 기술 설계서 — 「그래비티 오브」 프로토타입

> 버전 1.0 · 2026-09-28
> 입력 문서: [`reference/gravity_orb_design.md`](reference/gravity_orb_design.md) (기획서 v0.1), [`reference/gravity_orb_roadmap.md`](reference/gravity_orb_roadmap.md) (구현 로드맵)
> 대상 독자: 구현 에이전트(Codex) 및 리뷰어

이 문서는 기획서와 로드맵을 **구현 가능한 수준의 구조·API·수치·알고리즘**으로 구체화한다.
기획서가 "무엇을", 로드맵이 "어떤 순서로"를 정한다면, 이 문서는 "어떻게"를 정한다.

- 문서 간 충돌 시 우선순위: **기획서 > 이 문서 > 로드맵**. 단, 11장 "설계 해석"은 기획서의 빈칸을 채운 결정이므로 기획서가 갱신되기 전까지 이 문서를 따른다.
- 모든 수치는 가안이며 `GameConfig`로 조정 가능해야 한다.

---

## 목차

1. 기술 스택과 프로젝트 설정
2. 좌표계·레이아웃
3. 아키텍처 개요 (씬 트리, 오토로드, 신호 흐름)
4. `GameConfig` 명세
5. 모듈 명세
6. 턴 처리 알고리즘
7. 충돌 반응(합체·소멸) 알고리즘
8. 점수·연쇄
9. 저장 데이터
10. 테스트 전략
11. 설계 해석 (기획서 빈칸을 채운 결정)
12. 마일스톤별 구현 명세
13. 알려진 함정 (Godot 4)

---

## 1. 기술 스택과 프로젝트 설정

| 항목 | 값 |
|---|---|
| 엔진 | **Godot 4.8** (현재 `4.8.dev3.mono`, 4.8 정식판 출시 시 교체). C#은 쓰지 않으며 mono 에디터가 추가하는 `[dotnet]` 섹션은 그대로 둔다 |
| 언어 | GDScript, **모든 변수·인자·반환값 타입 명시** |
| 렌더러 | `gl_compatibility` (저사양 Android 대응) |
| 물리 | 기본 GodotPhysics2D, **240 tick/s** (13장 "벽 관통" 참조) |
| 외부 애드온 | 사용하지 않음 (테스트 프레임워크 포함) |

### 1.1 `project.godot` 필수 설정

| 키 | 값 |
|---|---|
| `application/run/main_scene` | `res://scenes/Main.tscn` |
| `display/window/size/viewport_width` | `1080` |
| `display/window/size/viewport_height` | `1920` |
| `display/window/size/window_width_override` | `540` |
| `display/window/size/window_height_override` | `960` |
| `display/window/stretch/mode` | `canvas_items` |
| `display/window/stretch/aspect` | `keep` |
| `display/window/handheld/orientation` | `1` (portrait) |
| `rendering/renderer/rendering_method` | `gl_compatibility` |
| `rendering/renderer/rendering_method.mobile` | `gl_compatibility` |
| `physics/common/physics_ticks_per_second` | `240` |
| `physics/2d/solver/contact_max_allowed_penetration` | `0.1` |

> 에디터는 기본값과 같은 항목을 `project.godot`에서 지운다 (`aspect=keep`, `emulate_touch_from_mouse=false`). 파일에 없어도 값이 같으면 준수한 것으로 본다.
| `input_devices/pointing/emulate_touch_from_mouse` | `false` (M2 검증 시 `true`로도 확인) |

### 1.2 입력 액션 (Input Map)

| 액션 | 키 | 도입 |
|---|---|---|
| `gravity_up` | ↑, W | M2 |
| `gravity_down` | ↓, S | M2 |
| `gravity_left` | ←, A | M2 |
| `gravity_right` | →, D | M2 |
| `restart` | R | M7 |
| `debug_toggle` | F1 | M9 |
| `debug_step` | N | M9 |

### 1.3 폴더 구조

로드맵의 권장 구조를 확장한다. 파일명은 PascalCase, `class_name`은 파일명과 동일.

```
res://
├─ project.godot
├─ config/
│   ├─ GameConfig.gd            # class_name GameConfig extends Resource
│   └─ default_config.tres
├─ scenes/
│   ├─ Main.tscn                # 조립 루트
│   ├─ Board.tscn
│   ├─ Orb.tscn
│   ├─ UI.tscn                  # HUD + 게임오버 화면
│   └─ DebugOverlay.tscn        # M9
├─ scripts/
│   ├─ autoload/
│   │   ├─ Config.gd            # 오토로드 "Config"
│   │   └─ InputRouter.gd       # 오토로드 "InputRouter" (로드맵의 scripts/input/ 대신 여기)
│   ├─ core/
│   │   ├─ Main.gd
│   │   ├─ Board.gd
│   │   ├─ Orb.gd
│   │   ├─ OrbVisual.gd
│   │   ├─ OrbTypes.gd          # 색 enum, 방향 유틸 (정적)
│   │   ├─ TurnManager.gd
│   │   ├─ CollisionResolver.gd
│   │   ├─ ReactionRules.gd     # 순수 로직 (정적 함수)
│   │   ├─ Spawner.gd
│   │   ├─ ScoreManager.gd
│   │   └─ SwipeDetector.gd     # 순수 로직 (RefCounted)
│   ├─ fx/
│   │   └─ Effects.gd           # M8
│   ├─ ui/
│   │   ├─ Hud.gd
│   │   └─ GameOverPanel.gd     # M7
│   ├─ platform/
│   │   └─ Haptics.gd           # M10
│   └─ debug/
│       ├─ DebugOverlay.gd      # M9
│       └─ PlayLogger.gd        # M9
├─ tests/
│   ├─ run_tests.gd             # extends SceneTree, 헤드리스 러너
│   ├─ TestCase.gd              # 최소 assert 헬퍼
│   ├─ test_*.gd                # 단위 테스트
│   └─ scenarios/               # 물리 시나리오 테스트 (M5~)
└─ assets/
```

---

## 2. 좌표계·레이아웃

- 모든 좌표·거리 단위는 **기준 해상도(1080×1920) 픽셀**이다. `canvas_items` 스트레치이므로 `InputEvent`의 위치도 이 좌표계로 들어온다.
- 방향은 `Vector2i`로 표현하며 Godot 화면 좌표(y 아래가 +)를 그대로 쓴다. `Vector2i.DOWN == (0, 1)`.
- **스와이프 방향 = 중력 방향**. 아래로 스와이프 → 중력 `(0,1)` → 생성 벽은 반대편인 위쪽 벽.

### 2.1 화면 배치 (월드 좌표 = 뷰포트 좌표, Camera2D 중심 (540, 960))

```
y=0     ┌──────────────────────┐
        │ HUD 상단 (0~480)      │  점수 / 최고점수 / 다음 구체
y=480   ├──┬────────────────┬──┤
        │  │  보드 960×960   │  │  Board.position = (540, 960)
        │  │  (x 60~1020)    │  │  보드 로컬 좌표: 중심 원점, -480~+480
y=1440  ├──┴────────────────┴──┤
        │ HUD 하단 (1440~1920)  │  중력 방향 화살표
y=1920  └──────────────────────┘
```

- `Board` 노드는 **보드 중심이 로컬 원점**이다. `half := board_size / 2`.
- 벽은 보드 경계 밖에 두께 `wall_thickness`로 배치한다 (안쪽 면이 정확히 `±half`).
- HUD는 `CanvasLayer`에 두어 카메라 기울기 연출(M8)의 영향을 받지 않게 한다.

---

## 3. 아키텍처 개요

### 3.1 오토로드

| 이름 | 스크립트 | 역할 |
|---|---|---|
| `Config` | `scripts/autoload/Config.gd` | 런타임 `GameConfig` 인스턴스 보관 (`Config.data`). 씬 재시작에도 유지 |
| `InputRouter` | `scripts/autoload/InputRouter.gd` | 모든 사용자 입력의 유일한 진입점 (M2) |

- `Config.data`는 `default_config.tres`를 `duplicate(true)`한 복사본이다. 디버그 패널에서 바꾼 값은 디스크에 쓰지 않는다.
- 그 외 전역 상태는 두지 않는다. RNG도 오토로드가 아니라 `Spawner`가 소유한다.

### 3.2 `Main.tscn` 노드 트리

```
Main (Node2D) ── Main.gd                       # 조립 루트: 신호 연결, 재시작
├─ Camera2D                                    # position (540,960), 기울기 연출용 (M8)
├─ Board (Board.tscn) ── Board.gd
│   ├─ Walls (Node2D)
│   │   └─ WallTop / WallBottom / WallLeft / WallRight (StaticBody2D + RectangleShape2D)
│   ├─ Frame (Node2D)                          # 보드 테두리·중력 강조·경고 점멸 그리기
│   └─ Orbs (Node2D)                           # 모든 Orb의 부모
├─ TurnManager (Node)          (M3)
├─ CollisionResolver (Node)    (M5)
├─ Spawner (Node)              (M4)
├─ ScoreManager (Node)         (M7)
├─ Effects (Node2D)            (M8)
├─ UI (UI.tscn, CanvasLayer)
└─ DebugOverlay (CanvasLayer)  (M9, 디버그 빌드에서만 인스턴스)
```

- 형제 노드 참조는 씬 고유 이름(`%TurnManager` 등)을 쓴다. `get_parent().get_node(...)` 체인 금지.
- 모듈 간 결합은 **신호 우선**. 직접 호출은 "지휘하는 쪽 → 지휘받는 쪽"(`TurnManager → Board/Spawner/CollisionResolver`, `CollisionResolver → Board`) 방향만 허용한다.

### 3.3 신호 흐름

```
InputRouter.swipe(dir) ───────────────▶ TurnManager.on_swipe(dir)
Board.orb_contact(a, b) ──────────────▶ CollisionResolver.report_contact(a, b)
CollisionResolver.reaction_applied(r) ─▶ ScoreManager / Effects / TurnManager(연쇄·안정 카운터)
TurnManager.state_changed(s) ─────────▶ UI / DebugOverlay   (입력 잠금은 TurnManager가 직접 호출)
TurnManager.gravity_changed(dir) ─────▶ UI / Effects        (Board.set_gravity는 직접 호출)
TurnManager.warning_changed(walls) ───▶ Board.Frame / Effects          (보류 — 11.4)
TurnManager.game_over() ──────────────▶ ScoreManager.commit / UI(게임오버 패널) / PlayLogger  (보류 — 11.2)
Spawner.next_changed(color, level) ───▶ UI(다음 구체 미리보기)
ScoreManager.score_changed(...) ──────▶ UI
InputRouter.restart_requested ────────▶ Main.restart()
```

### 3.4 공통 규칙 (로드맵 0장 구체화)

1. **입력 격리**: `Input` 싱글턴과 `InputEvent*` 타입은 `InputRouter.gd`에서만 참조한다. 예외: `Haptics.gd`의 `Input.vibrate_handheld()` (출력이므로 허용). M1의 임시 입력은 M2에서 제거한다.
2. **하드코딩 금지**: 밸런스 수치는 `Config.data.*`에서 읽는다. 레이아웃·연출용 고정값(폰트 크기 등)만 스크립트 상단 `const`로 허용.
3. **물리 콜백에서 트리 변경 금지**: `body_entered` 등에서는 기록만 하고, 생성·삭제는 `TurnManager._physics_process` 처리 단계(7장)에서 한다.
4. **단일 RNG**: `Spawner`가 가진 `RandomNumberGenerator` 하나만 쓴다. 전역 `randi()`, `randf()`, `Array.shuffle()`, `pick_random()` 금지.
5. **타입 명시**: `var x := ...` 또는 `var x: T`, 반환 타입(`-> void` 포함) 필수.

---

## 4. `GameConfig` 명세

`config/GameConfig.gd` — `class_name GameConfig extends Resource`. 모든 필드는 `@export`.
필드는 **해당 마일스톤에서 추가**한다. "M" 열이 추가 시점이다.

```gdscript
enum SpawnPositionMode { RANDOM, CENTER }                     # M4
enum AnnihilationRule { A_BOTH, B_SAME_LEVEL, C_REMAINDER }   # M6
```

| M | 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|---|
| M1 | `board_size` | float | 960.0 | 보드 한 변 (px) |
| M1 | `wall_thickness` | float | 256.0 | 터널링 방지용으로 두껍게 |
| ~~M1~~ | ~~`orb_base_radius`, `orb_radius_growth`~~ | | | **#14에서 제거** → `level_radii` |
| #14 | `level_radii` | PackedFloat32Array | [25, 40, 60, 85, 115, 150, 190] → **[25, 40, 60, 85, 100, 120, 140]** (기획서 0.6.2. #18은 보류, **#22 추가 요구 1 측정으로 2026-10-05 확정, #27 적용**) | 레벨별 반지름 |
| #45~#48 | `fx_score_popups_enabled` 등 연출 필드 | | §12-P | M8 연출 2차 (§12-P) |
| #38 | `orb_symbols_enabled` | bool | **true** | 색각 문양 표시 (§12-U.2) |
| #36 | `blitz_min_spawn_per_swipe` / `blitz_max_spawn_per_swipe` | int | **1 / 8** | BLITZ 스와이프당 생성 = 없어진 만큼 (§12-B.5) |
| #35 | `fx_*`, `sfx_*` | | §12-F 표 | 대폭발 VFX·뽁뽁이 사운드 (§12-F) |
| #34 | `blitz_spawn_color_weights` | PackedFloat32Array | **[1, 1, 1, 1, 1, 1]** | BLITZ 생성 색 확률 (§12-B.4). 턴제 `spawn_color_weights`는 [1, 1, 1, 1, 0, 0] |
| #33 | `blitz_spawn_on_swipe` | bool | **true** | BLITZ에서 스와이프마다 생성 (§12-B.3) |
| #31 | `game_mode`, `blitz_*` | | §12-B 표 | 타임어택 모드 스파이크 (§12-B) |
| #29 | `blast_enabled` 외 5개 | | §7.7 표 | 대폭발 BLAST (§7.7) |
| #25 | `color_effects_enabled` 외 5개 | | §7.6 표 | 색별 합체 효과 (§7.6) |
| #23 | `chain_reaction_delay` | float | 0.2 (가안, 플레이 체감으로 조정) | 합체 결과의 반응 잠금 시간 (초, §7.5) |
| #21 | `combo_multiplier_base` | float | 2.0 | 콤보 배수 밑 (§8.2) |
| #21 | `danger_start` / `danger_doubling` | float | 0.30 / 0.20 | 위험 배수 시작 점유율 / 2배가 되는 점유율 간격 (§8.2) |
| #21 | `gravity_level_scale` | float | **0.1** (#21: L7 낙하 0.65초 vs L1 1.04초) | 레벨별 중력 배율 = 1 + 값 × (레벨 − 1). 큰 구체가 더 빨리 떨어진다 (기획서 0.8) |
| #14 | `mass_exponent` | float | **1.0** (#14 측정: 지수 2는 L1 관통 14.8px, 1은 8.2px) | 질량 = base × (r / r_L1)^지수. **#21에서 2로 확정** (L7이 L1에 밀리는 거리 47 → 12px) |
| M1 | `orb_max_level` | int | 7 | |
| M1 | `orb_base_mass` | float | 1.0 | L1 질량 |
| M1 | `gravity_strength` | float | 2400.0 → **1800.0** (#17: 고밀도 40%+ 사전 복구 910 → 13, 발산 0) | 중력 가속도 (px/s²) |
| M1 | `orb_friction` | float | 0.3 | |
| M1 | `orb_bounce` | float | 0.15 | |
| M1 | `wall_friction` | float | 0.3 | |
| M1 | `wall_bounce` | float | 0.1 | |
| M1 | `orb_linear_damp` | float | 0.1 | |
| M1 | `orb_angular_damp` | float | 1.0 | |
| M1 | `color_display` | PackedColorArray | 빨 `#E5484D`, 파 `#3E7BFA`, 초 `#30A46C`, **노 `#F5C542`** (#15) | 인덱스 = `OrbTypes.OrbColor` |
| M1 | `debug_test_orb_count` | int | 5 | M1 전용. M4에서 삭제 |
| M2 | `swipe_min_distance` | float | 80.0 | 스와이프 최소 이동 거리 (기준 해상도 px) |
| M2 | `swipe_dominance_ratio` | float | 1.5 | 주 방향 성분 ≥ 보조 성분 × 이 값 |
| M3 | `stable_linear_speed` | float | 12.0 → #8에서 30.0 | 안정 판정 선속도 임계값 (px/s) |
| M3 | `stable_angular_speed` | float | 1.0 → #8에서 3.0 | 안정 판정 각속도 임계값 (rad/s) |
| M3 | `stable_duration` | float | 0.33 | 임계값 이하가 연속 유지되어야 하는 시간 (초, 스케일된 시간). 물리 틱 수와 무관하게 초 단위로 정한다 |
| M3 | `max_settle_time` | float | 3.0 → **1.5** (기획서 0.3) | 턴 최대 길이 (초, 스케일된 시간). 도달하면 움직임이 남아도 턴 종료 — 정상 동작 |
| M3 | `allow_same_direction_swipe` | bool | true | 11.1 참조 |
| M4 | `spawn_level_weights` | PackedFloat32Array | [0.9, 0.1] | 인덱스 0 = 레벨1 |
| M4 | `spawn_color_weights` | PackedFloat32Array | [1, 1, 1] → **[1, 1, 1, 1]** (#15) | 인덱스 = 색. 가중치 0인 색은 생성되지 않는다 |
| #15 | `spawn_count_per_turn` | int | 2 (기획서 0.6) → **1 (#26, 기획서 0.9.4: 상극 폐지 후 게임 길이 258 → 136턴)** | 턴당 생성 구체 수 |
| #26 | `preview_turns` | int | **2** | 미리보기로 보여 줄 앞으로의 턴 수 (§11.10) |
| #15 | `spawn_count_ramp_turns` / `spawn_count_max` | int | 0 → 100 (#55) → **50** (#56, 기획서 0.10.10) / 3 → **0 = 상한 없음** (#56) | 턴제 점진 증가: **50턴마다 +1개, 상한 없음** (1~50턴 1개, 51~100턴 2개, 101~150턴 3개, 151~200턴 4개 …). `spawn_count_max ≤ 0`이면 상한 없음. BLITZ는 쓰지 않음 |
| M4 | `spawn_position_mode` | SpawnPositionMode | RANDOM | |
| M4 | `spawn_margin` | float | 4.0 | 생성 벽 안쪽 면과 구체 사이 여백 |
| M4 | `rng_seed` | int | 0 | 0이면 시작 시 무작위 시드를 뽑아 기록 |
| M4 | `initial_orb_count` | int | 2 | |
| M5 | `contact_max_reported` | int | 6 | `Orb.max_contacts_reported` |
| M5+ | `rolling_resistance` | float | **0.0** (#8 결론: 비활성) | 바닥(중력 쪽 벽) 접촉 구체의 중력 수직 속도 감속 = 값 × `gravity_strength`. 힘으로 건다 |
| M5+ | `rest_speed` / `rest_damp` | float | 0 / 0 | 저속 제동 (0이면 비활성) |
| M5+ | `floor_contact_tolerance` | float | 2.0 | 바닥 접촉 기하 판정 여유 (px) |
| M5+ | `grow_duration` / `grow_start_ratio` | float | 0.06 / 0.3 | 새 구체 충돌·표시 반지름을 시작 비율에서 최종까지 선형 성장 (질량은 즉시 최종) |
| M5+ | `ghost_exit_overlap` | float | 4.0 | 유령 상태 해제 조건: 모든 구체와의 겹침 깊이가 이 값 이하 (px) |
| M5+ | `ghost_max_time` | float | 0.6 | 유령 상태 최대 시간 (초). 넘으면 겹쳐 있어도 해제하고 통계로 센다 |
| M5+ | `ghost_alpha` | float | 0.55 | 유령 상태 표시 불투명도 |
| M5+ | `wall_penetration_limit` | float | 16.0 | 사전 벽 복구: 관통이 이 값을 넘으면 25px 안전장치 전에 경계로 복구 (#11, 사용자 승인). 회귀 테스트는 발동 0 요구 (#12) |
| M5+ | `escape_guard_depth` | float | 25.0 | 벽 관통이 이 깊이를 넘으면 경계로 되돌리는 안전장치 (회귀 테스트는 발동 0 요구) |
| M6 | `opposite_pairs` | Array[Vector2i] | [(RED, BLUE)] → **[] (#25, 기획서 0.9.3: 상극 소멸 폐지)**. 0.5의 (GREEN, YELLOW)는 0.6에서 철회 | 상극 쌍 (순서 무관). 비어 있으면 소멸 없음. ANNIHILATE 코드·규칙 A/B/C·점수는 지우지 않고 남긴다 (되살릴 때 값만 넣는다) |
| M6 | `annihilation_rule` | AnnihilationRule | A_BOTH → **B_SAME_LEVEL** (2026-09-30 플레이테스트, 기획서 0.4.1) | |
| M7 | `level_scores` | PackedInt32Array | [2,4,8,16,32,64,128] | 인덱스 0 = 레벨1 |
| M7 | `annihilation_score_factor` | float | 0.5 | |
| M7 | `max_merge_bonus_factor` | float | 5.0 | |
| ~~M7~~ | ~~`spawn_candidate_count`, `spawn_fallback_to_free_slot`~~ | | | **폐기** (기획서 0.2: 빈자리와 무관하게 생성) |
| 보류 | `warning_distance` | | | 게임오버 조건 재설계 후 결정 (11.4) |
| M8 | `hitstop_duration` | float | 0.06 | 실시간 초 |
| M8 | `hitstop_time_scale` | float | 0.05 | |
| M8 | `tilt_angle_deg` | float | 3.0 | |
| M8 | `tilt_duration` | float | 0.25 | |
| M8 | `merge_pop_scale` | float | 1.2 | |
| M8 | `chain_pitch_step` | float | 0.08 | 연쇄당 `pitch_scale` 증가량 |
| M10 | `vibration_enabled` | bool | true | |
| M10 | `vibration_ms` | int | 20 | |

`GameConfig` 도우미 함수 (해당 필드와 같은 마일스톤에 추가):

```gdscript
func radius_for_level(level: int) -> float:      # #14부터
    return level_radii[level - 1]

func mass_for_level(level: int) -> float:        # #14부터
    return orb_base_mass * pow(radius_for_level(level) / radius_for_level(1), mass_exponent)

func score_for_level(level: int) -> int:        # M7
    return level_scores[level - 1]

func is_opposite(c1: int, c2: int) -> bool:     # M6
    for p: Vector2i in opposite_pairs:
        if (p.x == c1 and p.y == c2) or (p.x == c2 and p.y == c1):
            return true
    return false
```

---

## 5. 모듈 명세

아래 시그니처는 계약이다. 내부 구현은 자유지만 공개 API·신호 이름을 바꾸려면 이 문서도 함께 수정한다.

### 5.1 `OrbTypes` (정적 유틸)

```gdscript
class_name OrbTypes
enum OrbColor { RED, BLUE, GREEN, YELLOW }   # YELLOW는 #15 (기획서 0.5)
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
static func dir_name(d: Vector2i) -> String          # "UP" 등, 디버그 표시용
static func perpendicular(d: Vector2i) -> Vector2i   # 벽을 따라가는 축
```

색은 정수 인덱스로 다룬다. 색 추가(기획서 9장) 시 enum·`color_display`·`spawn_color_weights`만 늘리면 되도록, 코드에서 색 개수를 3으로 가정하지 않는다.

### 5.2 `Orb` (`Orb.tscn`, RigidBody2D)

```
Orb (RigidBody2D) ── Orb.gd
├─ CollisionShape2D (CircleShape2D — 인스턴스마다 새로 생성)
└─ Visual (Node2D) ── OrbVisual.gd    # 원 + 문양 그리기, 스케일 애니메이션 대상
```

```gdscript
class_name Orb extends RigidBody2D
var color: int
var level: int
var generation: int = 0     # 연쇄 세대 (8장, M5)
var consumed: bool = false  # 반응 처리 예정/완료. true면 이후 모든 반응에서 제외 (M5)

func setup(p_color: int, p_level: int, cfg: GameConfig) -> void
func get_radius() -> float
func set_gravity(dir: Vector2i, strength: float) -> void   # constant_force = Vector2(dir) * strength * mass
```

`setup()`에서 설정할 속성:

| 속성 | 값 |
|---|---|
| `gravity_scale` | 0.0 |
| `can_sleep` | false (안정 판정은 직접 한다) |
| `continuous_cd` | `CCD_MODE_CAST_SHAPE` |
| `contact_monitor` | true (M5부터) |
| `max_contacts_reported` | `cfg.contact_max_reported` (M5부터) |
| `mass` | `cfg.mass_for_level(level)` |
| `physics_material_override` | 새 PhysicsMaterial(friction, bounce) |
| `linear_damp` / `angular_damp` | config 값 |
| `collision_layer` / `collision_mask` | 레이어 2 / 마스크 1+2 |

- 중력은 로드맵의 "매 물리 프레임 힘"과 동등한 **`constant_force`** 로 구현한다. 방향이 바뀔 때와 생성 시에만 갱신한다.
- 크기 변화 연출은 **`Visual` 노드의 scale만** 바꾼다. RigidBody2D·CollisionShape2D는 절대 스케일하지 않는다.

**충돌 레이어**: 1 = 벽, 2 = 구체, 3 = 유령 구체 (기획서 0.4). 유령은 레이어 3 / 마스크 1 — 벽과만 충돌하고, 일반 구체의 마스크(1+2)에도 3이 없어 서로 통과한다.

### 5.3 `Board`

```gdscript
class_name Board extends Node2D
signal orb_contact(a: Orb, b: Orb)   # 구체-구체 접촉 시작 (M5)

func half_size() -> float
func set_gravity(dir: Vector2i) -> void                  # 모든 Orb에 전파, 이후 생성 Orb에도 적용
func spawn_orb(color: int, level: int, pos: Vector2, vel: Vector2 = Vector2.ZERO, generation: int = 0) -> Orb
func remove_orb(orb: Orb) -> void
func get_orbs() -> Array[Orb]                            # consumed가 아닌 Orb만
func clear() -> void
func spawn_line(gravity: Vector2i, radius: float) -> Dictionary  # {origin: Vector2, axis: Vector2, extent: float} (M4)
```

- `Board`는 `_orbs: Array[Orb]` 목록을 직접 관리한다(`get_children()`에 의존하지 않음).
- `spawn_orb`에서 `orb.body_entered`를 연결한다: 상대가 `Orb`이고 `orb.get_instance_id() < other.get_instance_id()`일 때만 `orb_contact(orb, other)` 발신 (양쪽 중복 신호 제거).
- `remove_orb`는 즉시 `consumed = true`, `_orbs`에서 제거, `collision_layer = 0`, `collision_mask = 0`, `freeze = true`로 만든 뒤 `queue_free()`. 같은 프레임에 다른 반응이 이 구체를 다시 잡지 않게 한다.
- `spawn_line`: 중력 `g`일 때 생성 벽은 `-g` 쪽 벽.
  - `origin = -Vector2(g) * (half - radius - spawn_margin)`
  - `axis = Vector2(OrbTypes.perpendicular(g))`
  - `extent = half - radius` (선분은 `origin + axis * s`, `s ∈ [-extent, extent]`)

### 5.4 `SwipeDetector` (순수 로직)

```gdscript
class_name SwipeDetector extends RefCounted
static func classify(delta: Vector2, min_distance: float, dominance_ratio: float) -> Vector2i
    # 조건 미달이면 Vector2i.ZERO
```

판정 규칙 (손을 뗄 때 1회):
1. `delta.length() < min_distance` → 무시
2. `major = max(|x|, |y|)`, `minor = min(|x|, |y|)`; `major < minor * dominance_ratio` → 무시 (대각선)
3. 우세 축의 부호로 방향 결정

### 5.5 `InputRouter` (오토로드)

```gdscript
extends Node
signal swipe(direction: Vector2i)
signal restart_requested                 # M7
signal debug_toggle_requested            # M9
signal debug_step_requested              # M9
signal debug_click(world_pos: Vector2)   # M9, 디버그 모드에서만

func set_locked(locked: bool) -> void    # swipe만 막는다. restart/debug는 막지 않음
func is_locked() -> bool
```

- `_unhandled_input`에서 처리한다 (UI 버튼 클릭이 스와이프로 새지 않게).
- 키보드: `event.is_action_pressed("gravity_*")` (에코 제외) → 즉시 `swipe` 발신.
- 포인터 제스처 상태: `{active, source: MOUSE|TOUCH, start: Vector2, started_locked: bool}`.
  - 누름: 활성 제스처가 없을 때만 시작. `InputEventScreenTouch`(index 0만) 또는 `InputEventMouseButton`(좌클릭).
  - 뗌: **시작한 source와 같은 source의 이벤트일 때만** 종료하고 `SwipeDetector.classify(end - start, ...)` 판정.
  - 이 source 고정 규칙이 "마우스로 터치 에뮬레이션"/"터치로 마우스 에뮬레이션"에서 생기는 이중 이벤트를 제거한다.
- 잠금 중에 시작된 제스처는 잠금이 풀린 뒤 떼어도 무시한다 (`started_locked`).
- 이벤트 좌표는 이미 기준 해상도 좌표다. 추가 변환하지 않는다.
- `_unhandled_input`은 GUI가 소비한 이벤트를 받지 못한다. 기획서 6.1 "보드 밖에서도 스와이프 인식"을 지키려면 **HUD·패널의 Control은 `mouse_filter = MOUSE_FILTER_IGNORE`** 로 두고, 클릭을 받아야 하는 버튼만 `STOP`으로 둔다. UI를 추가하는 마일스톤(M4 미리보기, M7 게임오버, M9 디버그)에서 HUD 영역 드래그가 `swipe`로 들어오는지 확인한다.
- 터치 취소(`InputEventScreenTouch.canceled`)·포커스 상실 시 활성 제스처가 남을 수 있다. M10에서 `canceled` 처리와 `NOTIFICATION_APPLICATION_FOCUS_OUT` 시 제스처 초기화를 추가한다.

### 5.6 `TurnManager`

```gdscript
class_name TurnManager extends Node
enum State { WAITING_INPUT, SIMULATING, SPAWNING, CHECK_GAMEOVER, GAME_OVER }
signal state_changed(state: State)
signal gravity_changed(dir: Vector2i)
signal turn_started(turn_index: int, dir: Vector2i)
signal turn_finished(turn_index: int, max_chain: int)
signal chain_changed(chain: int)                    # M5, 턴 내 최대 연쇄 갱신 시
signal warning_changed(walls: Array[Vector2i])      # 보류 (11.4)
signal game_over                                    # 보류 (11.2)

var state: State
var gravity: Vector2i = Vector2i.DOWN
var turn_index: int = 0
var turn_max_chain: int = 0

func start_game() -> void
func on_swipe(dir: Vector2i) -> void
func on_reaction(reaction: Dictionary) -> void      # M5, 안정 카운터 리셋 + 연쇄 갱신
```

알고리즘은 6장.

### 5.7 `CollisionResolver` (M5)

```gdscript
class_name CollisionResolver extends Node
signal reaction_applied(reaction: Dictionary)
    # {type: ReactionRules.Type, chain: int, levels: Array[int], colors: Array[int],
    #  position: Vector2, result_level: int (없으면 0), result_color: int, result_orb: Orb (없으면 null)}

func report_contact(a: Orb, b: Orb) -> void   # 기록만. 트리 변경 금지
func flush() -> int                            # 기록된 쌍 처리, 적용된 반응 수 반환
func sweep_resting_contacts() -> int           # 안정 직전 안전망 (7.3, M6)
```

### 5.8 `ReactionRules` (순수 로직, M5~M6)

```gdscript
class_name ReactionRules
enum Type { NONE, MERGE, MAX_CLEAR, ANNIHILATE }

static func classify(color_a: int, level_a: int, color_b: int, level_b: int, cfg: GameConfig) -> Dictionary
    # 반환: {type: Type, result_level: int, result_color: int, survivor: int (0=없음, 1=a, 2=b)}
```

| 조건 (위에서부터 먼저 맞는 것) | type | 결과 |
|---|---|---|
| 같은 색, 같은 레벨, 레벨 == max | MAX_CLEAR | 둘 다 제거 |
| 같은 색, 같은 레벨 | MERGE | 레벨+1, 같은 색, 중간 지점 |
| 상극 쌍, 규칙 A | ANNIHILATE | 둘 다 제거 |
| 상극 쌍, 규칙 B, 같은 레벨 | ANNIHILATE | 둘 다 제거 |
| 상극 쌍, 규칙 B, 다른 레벨 | NONE | |
| 상극 쌍, 규칙 C, 같은 레벨 | ANNIHILATE | 둘 다 제거 |
| 상극 쌍, 규칙 C, 다른 레벨 | ANNIHILATE | 큰 쪽 색으로 레벨 `|La − Lb|` 구체 1개가 큰 쪽 위치에 남음 (`survivor` 지정) |
| 그 외 | NONE | |

`classify`는 호출 시점의 `cfg`를 읽으므로 디버그에서 규칙을 바꾸면 다음 충돌부터 즉시 반영된다 (M6 완료 조건).

### 5.9 `Spawner` (M4)

```gdscript
class_name Spawner extends Node
signal next_changed(color: int, level: int)

var seed_used: int
func init_rng(seed: int) -> int          # 0이면 무작위 시드 생성, 실제 시드 반환·보관
func spawn_initial(board: Board, gravity: Vector2i) -> void
func try_spawn(board: Board, gravity: Vector2i) -> Orb   # 항상 생성 (겹침 무관, 기획서 0.2)
func peek_next() -> Dictionary           # {color, level}
```

**RNG 소비 순서 고정** (같은 시드 → 같은 생성 순서 보장):
구체 1개를 뽑을 때마다 항상 `level → color → position(randf)` 순으로 정확히 3회 소비한다. `CENTER` 모드나 대체 위치를 쓸 때도 position 값은 뽑고 버린다.

- 가중치 선택은 `rng.rand_weighted(weights)` 사용.
- "다음 구체"는 항상 1개 미리 뽑혀 있다. 생성 성공 시 다음 것을 새로 뽑고 `next_changed` 발신.
- 생성 실패(게임오버) 시 "다음 구체"는 소비하지 않는다.
- 물리 결과(구체 위치)는 시드로 재현되지 않는다. 보장 범위는 **(레벨, 색, 선호 위치) 시퀀스**까지다.
- 위치 결정은 11.3.

### 5.10 `ScoreManager` (M7)

```gdscript
class_name ScoreManager extends Node
signal score_changed(score: int, best: int)
signal max_chain_changed(max_chain: int)

var score: int
var best_score: int
var max_chain: int
var max_level_reached: int

func reset() -> void
func on_reaction(reaction: Dictionary) -> void
func commit() -> void   # 게임오버 시 최고 점수 저장
static func points_for(reaction: Dictionary, cfg: GameConfig) -> int  # 순수 계산, 테스트 대상
```

---

## 6. 턴 처리 알고리즘

모든 상태 처리는 `TurnManager._physics_process(delta)`에서 한다. 상태 전이는 반드시 `_set_state()` 한 곳을 거치며 여기서 `state_changed`를 발신한다.

```
WAITING_INPUT
  on_swipe(dir):
    if state != WAITING_INPUT: return
    if dir == gravity and not cfg.allow_same_direction_swipe: return   # 잠그지 않고 무시
    turn_index += 1; turn_max_chain = 0
    모든 Orb.generation = 0
    InputRouter.set_locked(true)
    gravity = dir; Board.set_gravity(dir); emit gravity_changed, turn_started
    → SPAWNING

SPAWNING (1 물리 프레임):                  # 기획서 0.2: 스와이프 순간 생성
    Spawner.try_spawn(board, gravity)       # 새 중력의 반대편 벽, 무작위 위치, 겹침 검사 없음
    _begin_settle(); → SIMULATING

모든 상태 공통 (매 물리 프레임, 기획서 0.3):
    CollisionResolver.flush()               # 입력 대기 중에도 반응을 즉시 처리 (남은 움직임이 턴을 넘어 이어짐)

SIMULATING settle 루프 (매 물리 프레임):
    if 이번 프레임 flush 적용 수 > 0: stable_time = 0.0
    settle_elapsed += delta                 # 스케일된 시간
    if _all_below_threshold(): stable_time += delta else: stable_time = 0.0
    if stable_time >= cfg.stable_duration:
        if CollisionResolver.sweep_resting_contacts() > 0: stable_time = 0.0; return
        _on_settled()
    elif settle_elapsed >= cfg.max_settle_time:
        _on_settled()                       # 시간 상한 도달 — 정상 동작, 경고 없음. 횟수는 통계로만 센다

_on_settled():
    → CHECK_GAMEOVER

CHECK_GAMEOVER (1프레임):
    (게임오버·경고 판정 보류 — 11.2·11.4. 조건이 정해지면 여기서 판정)
    emit turn_finished(turn_index, turn_max_chain)
    InputRouter.set_locked(false); → WAITING_INPUT
```

- `_all_below_threshold()`: 모든 Orb에 대해 `linear_velocity.length() <= stable_linear_speed` 그리고 `absf(angular_velocity) <= stable_angular_speed`. Orb가 0개면 true.
- `_begin_settle()`: `stable_time = 0.0`, `settle_elapsed = 0.0`.
- **연쇄의 턴 귀속** (기획서 0.3): 입력 재개 후 일어난 반응은 `generation`이 다음 스와이프까지 유지되므로 직전 턴의 연쇄로 이어서 센다. `turn_max_chain`은 다음 `on_swipe`에서 0으로 초기화되기 전까지 갱신될 수 있다 (`turn_finished`에 실린 값보다 커질 수 있음). 점수(M7)는 반응 시점에 즉시 더하므로 귀속 문제가 없다.
- `start_game()`: 중력 DOWN → 초기 구체 생성 → settle(`SIMULATING` 재사용, `_is_initial_settle = true`면 `_on_settled`에서 생성 단계를 건너뛰고 바로 `WAITING_INPUT`).
- **M3 시점**: `SPAWNING`, `CHECK_GAMEOVER`는 즉시 통과. `flush`/`sweep`/`try_spawn` 호출은 해당 마일스톤에서 추가.
- **변경 이력**: M4(PR #5)는 "안정 후 생성 → SPAWNING settle" 순서로 구현됐다. 기획서 0.2에서 스와이프 순간 생성으로 바뀌어 인박스 #6에서 위 흐름으로 교체한다. SPAWNING은 이제 1프레임 상태다.

---

## 7. 충돌 반응 알고리즘 (M5~M6)

### 7.1 접촉 수집

1. `Board`가 `body_entered`를 받아 id 순서로 정리된 쌍을 `orb_contact(a, b)`로 발신 (5.3).
2. `CollisionResolver.report_contact(a, b)`는 `_pending`에 `[a, b]`를 append만 한다.
3. 실제 처리는 `TurnManager`가 settle 루프에서 호출하는 `flush()`에서 한다. 물리 콜백 밖이므로 `add_child`/`queue_free`가 안전하다. 만약 엔진이 "flushing queries" 에러를 내면 `Board.spawn_orb`의 `add_child`를 `call_deferred`로 바꾸되, `_orbs` 목록에는 즉시 넣는다.

### 7.2 `flush()`

```
applied = 0
for [a, b] in _pending (삽입 순서):
    if not is_instance_valid(a) or not is_instance_valid(b): continue
    if a.consumed or b.consumed: continue
    r = ReactionRules.classify(a.color, a.level, b.color, b.level, Config.data)
    if r.type == NONE: continue
    chain = max(a.generation, b.generation) + 1
    pos_a, pos_b, vel_a, vel_b 저장
    board.remove_orb(a); board.remove_orb(b)
    match r.type:
      MERGE:      result = board.spawn_orb(a.color, r.result_level, clamp_inside((pos_a+pos_b)/2, r_new), (vel_a+vel_b)/2, chain)
      MAX_CLEAR:  (생성 없음)
      ANNIHILATE: if r.survivor != 0:   # 규칙 C 잔존
                      result = board.spawn_orb(r.result_color, r.result_level, 큰 쪽 pos, 큰 쪽 vel, chain)
    emit reaction_applied({...}); applied += 1
_pending.clear()
return applied
```

- `clamp_inside(p, r)`: 각 축을 `[-half + r, half - r]`로 제한한다. 벽 옆에서 합체하면 커진 구체가 벽과 겹쳐 생성되는 것을 막는다 (규칙 C 잔존 구체는 레벨이 줄어 필요 없음).
- "처리 예정" 표시 = `consumed`. `remove_orb`가 즉시 true로 만들어 같은 flush 안의 이후 쌍이 건너뛴다 → 3개 동시 접촉 시 중복 합체 없음.
- 새 구체가 기존 구체와 겹쳐 생성될 수 있다. 물리 엔진이 밀어내며, 겹친 상대와의 `body_entered`가 발생해 연쇄가 이어진다.
- `TurnManager`는 `reaction_applied`를 받아 `turn_max_chain = max(turn_max_chain, chain)`을 갱신하고 `chain_changed`를 발신한다.

### 7.3 안전망 `sweep_resting_contacts()` (M6)

`body_entered`는 "접촉 시작"에만 발생하므로, 규칙이 런타임에 바뀌었거나 접촉 보고가 누락된 경우 반응 대상 쌍이 붙은 채 남을 수 있다. 안정 판정 직전에 모든 Orb의 `get_colliding_bodies()`를 훑어 쌍을 `_pending`에 넣고 `flush()`한 결과를 반환한다.


### 7.4 합체 충격파 (기획서 0.9 — #21 추가 요구 1)
MERGE·MAX_CLEAR 반응 직후 반응 지점 `p`에서 충격파를 낸다.
- 대상: 일반 상태(유령·입구 대기 제외)이고 중심 거리 `d < R`인 구체. `R = shock_radius_factor × r_result` (MAX_CLEAR는 `r_L7` 기준)
- 충격량(속도 아님): `J = shock_impulse × (1 + shock_level_scale × (L_result − 1)) × (1 − d / R)`, 방향 `(q − p).normalized()` (평면). 속도 변화 = `J / mass` → **가벼운 구체가 더 크게 움직인다** (무게감)
- MAX_CLEAR(L7 잭팟)는 `J × shock_jackpot_scale`
- 결과 구체 자신은 제외. 물리 콜백 밖(`flush`)에서 적용
- 새 필드와 확정값 (#21): `shock_impulse` **600** (L1 기준 Δv 600px/s), `shock_radius_factor` 2.5, `shock_level_scale` 0.3, `shock_jackpot_scale` 3.0
- #21 측정: 충격파는 고밀도 재배열(켄달 불일치 약 6%)·L7 잼(81~87%)을 거의 바꾸지 못했다. 잼 해소가 아니라 **합체 손맛·무게 차이 표현**용으로 채택


### 7.5 순차 연쇄 (기획서 0.9.1 — #23)
- MERGE 결과·규칙 C 잔존 구체는 생성 후 `chain_reaction_delay`(가안 0.2초, 스케일된 시간) 동안 **반응 잠금**: `CollisionResolver.flush`는 잠긴 구체가 낀 쌍을 처리하지 않고 **보류 목록**에 남긴다
- 잠금이 풀리는 프레임에 그 구체의 현재 접촉(`get_colliding_bodies` 또는 반지름 합 + `ghost_exit_overlap` 이내 거리)을 다시 모아 반응 판정한다 — 잠금 중 생긴 접촉도 놓치지 않는다
- 보류 중인 반응이 있거나 잠긴 구체가 반응 가능한 상대와 닿아 있으면 **안정으로 보지 않는다** (턴이 연쇄 도중에 끝나지 않게). 1.5초 상한에 걸려 턴이 끝나도 연쇄는 입력 대기 중 계속된다 (기존 규칙)
- 충격파·콤보·점수는 반응마다 그대로 (두 번째 합체는 두 번째 충격파·×2)
- 새 필드 `chain_reaction_delay`


### 7.6 색별 반응 효과 (기획서 0.9.2·0.9.3 — #25)
§7.4 충격파를 **결과 구체의 색에 따라 다른 효과**로 바꾼다. 0.9.3에서 상극 소멸을 폐지해(`opposite_pairs = []`) 소멸 효과(IMPLODE 붕괴)는 넣지 않는다. 공통 기호는 §7.4와 같다 (`p` 반응 지점, `q` 대상 중심, `d = |q − p|`, `Lf = 1 + shock_level_scale × (L − 1)`, `mass`는 대상 질량, 대상은 일반 상태 구체이며 결과 구체 자신은 제외).

| 반응 | 모드 | 대상 | 효과 |
|---|---|---|---|
| 빨강 합체 | **PUSH 폭발** | `d < R`, `R = shock_color_radius_factor[RED] × r_result` | 충격량 `J = shock_impulse × shock_color_impulse_scale[RED] × Lf × (1 − d/R)`, 방향 `(q − p)` (바깥) |
| 파랑 합체 | **PULL 흡인** | `d < R` (파랑 계수) | 같은 식, 방향 `(p − q)` (안쪽). 끌려온 구체가 결과 구체와 닿아 다음 반응(§7.5 잠금 해제 후)을 만든다 |
| 초록 합체 | **SHAKE 진동** | 판 위 **모든** 일반 구체 | **속도 변화(질량 무관)** `Δv = min(green_shake_speed × Lf, green_shake_max_speed)`, 방향은 무작위 단위벡터. 큰 구체도 같이 흔들려 굳은 더미를 푼다 |
| 노랑 합체 | **LIFT 역중력** | `d < R` (노랑 계수) | 충격량은 PUSH와 같은 식, 방향 = **현재 중력의 반대** (`-gravity`) |

- `p`: 결과 생성 위치 (MAX_CLEAR는 두 구체 중심의 중점). ANNIHILATE는 효과 없음 (소멸을 다시 켜도 그대로)
- **MAX_CLEAR(L7 잭팟)**: 그 색의 모드를 쓰고 세기(Δv 포함)에 `shock_jackpot_scale`을 곱한다. 기준 반지름은 `r_L7`. SHAKE 잭팟도 `green_shake_max_speed × shock_jackpot_scale`로 상한
- **무작위 방향(SHAKE)**: 전용 `RandomNumberGenerator`를 게임 시드에서 파생해 쓴다 (`Spawner` RNG와 분리 — 생성 순서가 바뀌지 않게). 같은 시드면 같은 결과 (결정론)
- 효과는 §7.5와 같이 **반응마다** 적용한다 (순차 연쇄의 두 번째 합체는 두 번째 효과)
- 모드 배정은 `shock_color_modes` 배열(색 순서 RED, BLUE, GREEN, YELLOW)로 한다. 측정·플레이 비교를 위해 모드를 바꿔 끼울 수 있게 한다
- `color_effects_enabled = false`면 §7.4 기존 동작(모든 색 PUSH, 계수 1.0·2.5)과 같다 — 회귀 비교용
- 시각 표시(임시): 반응 지점에 모드별 색 고리 1회 (PUSH 바깥으로 퍼짐, PULL 안으로 수축, SHAKE 보드 프레임 짧은 떨림, LIFT 중력 반대 방향 화살). 정식 연출은 M8
- 새 필드 (가안, #25 측정 후 확정):

| 필드 | 타입 | 가안 |
|---|---|---|
| `color_effects_enabled` | bool | true |
| `shock_color_modes` | PackedInt32Array | [PUSH, PULL, SHAKE, LIFT] |
| `shock_color_impulse_scale` | PackedFloat32Array | [1.5, 0.8, 0.0, 1.0] (SHAKE는 미사용) |
| `shock_color_radius_factor` | PackedFloat32Array | [3.0, 3.0, 0.0, 3.0] (SHAKE는 판 전체) |
| `green_shake_speed` / `green_shake_max_speed` | float | 150 / 600 (px/s) |

- 위험: PULL은 구체를 서로·벽 쪽으로 몰아 **겹침·벽 관통**을 늘릴 수 있다. §10 3D 임계값(22시드 벽 ≤14 / 쌍 ≤16px, 연속 턴 벽 ≤28 / 쌍 ≤60px, 이탈·발산 0)을 그대로 지켜야 하며, 넘으면 계수를 낮추는 쪽으로 보고한다


### 7.7 대폭발 BLAST (기획서 0.9.5 — #29)
레벨 `blast_min_level`(**6**, #30에서 5 → 6) 이상 구체는 **폭발 가능 상태**다. **같은 레벨·다른 색**의 폭발 가능 구체 둘이 닿으면 둘 다 사라지고 판 전체를 밀어낸다. 레벨이 다르면(L5–L6 등) 반응하지 않는다 (2026-10-05 사용자 결정: L5–L6 폭발 제외).

- **판정 순서** (`ReactionRules.classify`): ① 같은 색·같은 레벨 → MERGE / MAX_CLEAR (기존, 성장 우선) ② 상극 → ANNIHILATE (현재 비활성) ③ `blast_enabled`이고 **두 레벨이 같고** `≥ blast_min_level` → **BLAST** ④ 그 외 NONE. 같은 색·같은 레벨은 ①에서 먼저 걸리므로 BLAST는 **같은 레벨·다른 색**만이다: L6–L6, L7–L7 (L7 같은 색은 MAX_CLEAR. #29 때는 L5–L5 포함). 레벨이 다른 쌍은 색과 무관하게 NONE
- **결과**: 두 구체 제거, 생성 없음. 지점 `p` = 두 중심의 중점
- **밀어내기**: 판 위 **모든** 일반 구체(유령·입구 대기 제외)에 **질량 무관 속도 변화** `Δv = blast_speed × lerp(1.0, blast_far_factor, clamp(d / board_size, 0, 1))`, 방향 `(q − p).normalized()` (`d ≈ 0`이면 `Vector2.RIGHT`). 큰 구체도 같이 날아가 굳은 더미가 풀린다. 색별 효과(§7.6)·충격파(§7.4)는 BLAST에 적용하지 않는다
- **점수**: 기본 점수 = `(score_for_level(La) + score_for_level(Lb)) × blast_score_factor` (L6+L6 = 640, L7+L7 = 1,280. `blast_min_level = 5`였던 #29에서는 L5+L5 = 320). 콤보·위험 배수는 §8.2 그대로. 콤보 +1
- **잠금(§7.5)**: 합체로 막 생긴 L5·L6은 잠금 동안 BLAST도 보류된다 (기존 잠금 규칙 그대로). 결과 구체가 없으므로 BLAST 자체는 잠금을 만들지 않는다
- **폭발 가능 표시**: 레벨 `≥ blast_min_level` 구체는 발광을 주기 `blast_blink_period`로 깜빡인다 (3D: 머티리얼 emission, 2D: 밝기). 상태 변화는 레벨로만 결정 — 별도 타이머 없음
- **임시 연출**: 폭발 지점 흰 섬광 고리 1회 + 보드 프레임 짧은 떨림. 정식 연출(화면 흔들림·파편·사운드)은 M8
- 반응 딕셔너리 `type = BLAST`, `levels`, `colors`, `position`, 점수 필드(§8.2). HUD·점수·콤보는 기존 경로로 처리
- 새 필드 (가안, #29 측정 후 확정):

| 필드 | 타입 | 가안 |
|---|---|---|
| `blast_enabled` | bool | true |
| `blast_min_level` | int | 5 → **6** (#30. #29 측정: 5에서는 12판 모두 800턴, 종료 점유율 17% — L5 쌍 하나가 L1 32개 면적을 치워 들어오는 양과 균형) |
| `blast_speed` | float | 900 (px/s) |
| `blast_far_factor` | float | 0.4 (보드 한 변 거리에서 Δv 비율) |
| `blast_score_factor` | float | 5.0 |
| `blast_blink_period` | float | 0.8 (초) |

- 위험: 판 전체에 큰 속도를 주므로 **벽 관통·겹침**이 늘 수 있다. §10 임계값을 지켜야 하며, 넘으면 `blast_speed`를 낮춘 값으로 재측정해 함께 보고

---

## 8. 점수·연쇄

### 8.1 콤보 (기획서 0.8 — #21에서 교체)
- **턴 콤보**: `on_swipe`에서 `turn_combo = 0`. 이후 다음 스와이프 전까지 적용되는 반응(MERGE·MAX_CLEAR·ANNIHILATE, 입력 대기 중 반응 포함)마다 `turn_combo += 1`, 그 반응의 `combo = turn_combo`
- 반응 점수 = 기본 점수 × `combo` (§8.2)
- 표시: 턴 중 현재 콤보, 판 전체 최대 콤보(`max_combo`). 신호 `combo_changed(combo)`
- 0.7까지의 **연쇄 세대**(`generation`, chain = max(gen)+1)는 콤보 계산에서 제외한다. 필드는 디버그 표시용으로 남겨도 된다

### 8.2 점수 (기획서 0.8 — #21에서 교체)

**반응 점수 = floor(기본 점수 × 콤보 배수 × 위험 배수)**

| 반응 | 기본 점수 |
|---|---|
| MERGE | `score_for_level(result_level)` |
| ANNIHILATE | `floor((score_for_level(La) + score_for_level(Lb)) × annihilation_score_factor)` |
| MAX_CLEAR (L7 잭팟) | `score_for_level(orb_max_level) × max_merge_bonus_factor` (128 × 5 = 640) |

- **콤보 배수** = `combo_multiplier_base ^ (combo − 1)` (기본 2.0). `combo`는 §8.1 턴 콤보
- **위험 배수** = 점유율 p(반응 직전, 최종 반지름 기준 Σπr² ÷ 보드²)가 `danger_start`(0.30) 미만이면 1, 이상이면 `2 ^ ((p − danger_start) ÷ danger_doubling)` (`danger_doubling` 0.20)
- 점수·최고 점수는 **int64**. 배수는 float으로 계산 후 마지막에 버림
- 반응 딕셔너리에 `base_points`, `combo_multiplier`, `danger_multiplier`, `points`를 담아 HUD·연출(M8)이 그대로 보여줄 수 있게 한다

예: 같은 턴 1번째 L2 합체(4점, 점유율 20%) = 4 / 2번째 L3 합체(8점) = 16 / 3번째 L7 청소(640점, 점유율 70% → ×4) = 640 × 4 × 4 = 10,240

---

## 9. 저장 데이터

| 파일 | 형식 | 내용 |
|---|---|---|
| `user://save.cfg` | `ConfigFile` | `[records] best_score` (M7), `[settings] vibration` (M10) |
| `user://playlog.csv` | CSV (append) | M9. 헤더: `timestamp,seed,turns,score,max_chain,max_level,duration_sec,annihilation_rule,spawn_mode,same_dir_swipe` |

파일이 없거나 손상돼도 기본값으로 진행한다 (에러로 멈추지 않음).

---

## 10. 테스트 전략

외부 애드온 없이 헤드리스로 돌리는 최소 러너를 둔다. **순수 로직(`SwipeDetector`, `ReactionRules`, `ScoreManager.points_for`, `GameConfig` 도우미, Spawner의 뽑기)은 씬 없이 테스트 가능하게** 분리한다.

### 10.1 실행 명령

```bash
# 임포트·스크립트 파싱 검사
godot --headless --path . --import
# 단위·시나리오 테스트 — 일반 묶음과 장기 Jolt 묶음을 **각각 새 프로세스**로 (#42). --fixed-fps 120이면 물리를 실시간보다 빠르게 돌린다 (결과 동일)
godot --headless --fixed-fps 120 --path . -s res://tests/run_tests.gd -- --test-suite=general
godot --headless --fixed-fps 120 --path . -s res://tests/run_tests.gd -- --test-suite=long
# 메인 씬 스모크: 300프레임 실행 후 종료, 출력에 SCRIPT ERROR가 없어야 함 (시작 화면 / 턴제 / BLITZ)
godot --headless --path . --quit-after 300
godot --headless --path . --quit-after 300 -- --mode=turn
godot --headless --path . --quit-after 300 -- --mode=blitz
```

- **권장: 래퍼 한 번** `.\tests\run_tests.ps1` — 일반·장기·성능(`--test-suite=perf`, 200구체 근접 검사 예열 후 3회 중 최선 p95 < 1ms) 세 묶음을 각각 새 프로세스로, 기본 `--fixed-fps 120` (약 40초). `-FixedFps 0`이면 실시간. 하나라도 실패하면 종료 코드 1
- PowerShell 5.1에서 래퍼 출력을 `*>`·`2>&1 | Tee-Object`로 받아도 끝까지 돈다 (#44, `8d24b68`). Godot 경고는 로그에 `NativeCommandError`로 남지만 판정은 각 프로세스 종료 코드로만 한다
- 인자 없는 `-s res://tests/run_tests.gd`는 호환용(한 프로세스, 장기 → 일반 순서)으로 남아 있다

`godot` 실행 파일 경로는 환경마다 다르다. `GODOT` 환경변수가 있으면 그것을 쓴다.

> #42 (PR #43, `563ccbe`): 장기 Jolt 테스트(2D 22시드 중력 순환, 3D 22시드·20턴·시드 101 120턴) 4개를 `--test-suite=long`으로 분리했다 — 앞선 테스트가 만든 물리 바디가 Jolt 생성 순서를 바꿔 결과를 흔들 수 있기 때문 (#38). 위 명령처럼 일반·장기를 각각 새 프로세스로 돌린다

### 10.2 러너 규약

- `tests/run_tests.gd` (`extends SceneTree`): `res://tests/`와 `res://tests/scenarios/`의 `test_*.gd`를 찾아 인스턴스화하고 `test_`로 시작하는 메서드를 모두 호출 (코루틴이면 `await`). 테스트별 결과와 실패 수를 출력하고 `quit(1 if failed > 0 else 0)`.
- `tests/TestCase.gd` (`extends RefCounted`): `assert_eq(a, b, msg)`, `assert_true(c, msg)`, `assert_near(a, b, eps, msg)` — 실패를 기록하고 계속 진행. 시나리오 테스트용으로 러너의 `SceneTree` 참조(`tree`)를 주입받는다.

### 10.3 마일스톤별 필수 테스트

| M | 파일 | 검증 |
|---|---|---|
| M1 | `test_config.gd` | `radius_for_level` 표 값 (1.00 / 1.25 / 1.5625 …) |
| M2 | `test_swipe.gd` | 짧은 이동·대각선 무시, 4방향 판정, 경계값 |
| M4 | `test_spawner.gd` | 같은 시드 → 같은 (레벨, 색) 50개 시퀀스, 가중치 분포 대략 검증 |
| M5 | `test_rules.gd` | 합체·최대레벨·무반응 조합 |
| M5 | `scenarios/test_merge_scenario.gd` | 같은 구체 2개 맞닿게 배치 → N프레임 후 레벨+1 구체 1개. 같은 구체 3개 동시 접촉 → 에러 없음, 합체 1회 |
| M6 | `test_rules.gd` | A/B/C 규칙 전수, 초록은 무반응 |
| M7 | `test_score.gd` | 8.2 표와 예시 |

시나리오 테스트는 `Board.tscn`을 루트에 붙이고 `await tree.physics_frame`으로 프레임을 진행한다.

- 시나리오 길이는 **시뮬레이션 초**로 정하고 프레임 수는 `Engine.physics_ticks_per_second × 초`로 계산한다. 프레임 수를 상수로 박으면 물리 틱을 바꿀 때 시험 강도가 몰래 달라진다.
- 구체 배치는 고정 시드 RNG로 한다. `randomize()` 금지 (실패 재현 불가).
- 헤드리스 실시간 동기화 때문에 오래 걸리면 `--fixed-fps <physics_ticks_per_second>`로 실행해도 된다 (물리 delta 동일).

### 10.4 수동 검증

로드맵 완료 조건 중 자동화하지 못한 항목(체감, 화면 확인 등)은 `docs/jeongmo_codex_to_claude.md` 회신에 **수동 확인 절차**로 적는다.

---

## 11. 설계 해석 (기획서 빈칸을 채운 결정)

기획서에 명시되지 않았거나 모호한 부분에 대한 이 문서의 결정이다. 플레이테스트 후 기획서에 반영하거나 뒤집는다.

### 11.1 같은 방향 스와이프
기획서 3.2 표는 "유효 입력", 7장은 미정. **기본 허용(true)**, 토글 제공. 비허용이면 입력을 잠그지 않고 무시만 한다.

### 11.2 게임오버 조건 — 입구 막힘 (기획서 0.6.1)
- **빈자리 탐색** (`find_free_spawn_slot(g, r, placed)`, 생성·경고 공용): `spawn_line(g, r)` 위 후보점(간격 `spawn_probe_step`)에서 모든 일반 구체 및 같은 묶음에서 먼저 놓인 구체와의 겹침이 `ghost_exit_overlap` 이하인 점. 선호 위치에서 가장 가까운 점, 동률이면 `s`가 작은 쪽
- **생성**: 묶음의 각 구체(묶음 순서대로)는 선호 위치(RNG `t`)가 비어 있으면 그 자리, 막혔으면 가장 가까운 빈자리에 생성한다 (유령 상태로 시작, 겹침이 없으니 곧 해제)
- **입구 대기**: 빈자리가 없으면 선호 위치에 **대기 상태**로 생성한다 — 다른 구체와 충돌하지 않고(유령 레이어), **중력 0, 속도 0으로 입구에 고정**. 매 물리 프레임 빈자리를 다시 찾아, 생기면 그 자리로 옮기고(`PhysicsDirectBodyState2D`) 중력을 켜고 일반 유령 경로로 들어간다
- **판정**: `CHECK_GAMEOVER`에서 대기 상태 구체가 하나라도 남아 있으면 `GAME_OVER` (막힌 방향 = 이번 턴 중력)
- 합체·규칙 C 잔존 구체는 대기·판정과 무관 (기존 유령 + 0.6초 타임아웃)
- 0.6 판정(유령이 턴 끝까지 겹침)은 폐기: 유령이 공을 통과해 반대편 바닥 더미 속에 박혀, 빈 판에서도 평균 13턴에 게임오버가 났다
- `GAME_OVER` 진입: 입력 잠금 유지, `game_over` 신호, 게임오버 패널. R키·버튼으로 재시작

### 11.3 생성 위치 결정
- 스와이프 순간(SPAWNING 1프레임) 새 중력의 반대편 벽 `spawn_line` 위에 생성한다.
- 위치: RANDOM이면 `s = lerpf(-extent, extent, t)`(`t`는 미리 뽑아 둔 값), CENTER면 `s = 0`.
- **겹침 검사·빈자리 탐색을 하지 않는다.** 기존 구체와 겹치면 물리 엔진이 밀어낸다. 과도한 튕김 여부는 시나리오 테스트로 측정한다 (M4 교체 항목 #6).

### 11.4 방향 경고 (기획서 0.6, 판정과 같은 기준)
턴이 끝날 때(`WAITING_INPUT` 진입 직전) 네 방향 `g` 각각에 대해, 다음 묶음(`peek_next()`)의 구체들이 `spawn_line(g, r)` 위에 들어갈 **빈자리**가 있는지 계산한다.
- 빈자리 = §11.2 `find_free_spawn_slot`과 **같은 함수**
- 묶음의 구체마다 서로 다른 빈자리가 필요하다 (앞 구체를 놓은 자리도 막힌 것으로 계산, 큰 구체부터)
- 자리가 부족한 방향 목록을 `warning_changed(dirs: Array[Vector2i])`로 발신 (변했을 때만). 표기 방향 = 그 방향으로 스와이프하면 막힘
- 경고는 **예측**이다. 실제 게임오버는 11.2 판정으로만

### 11.5 연쇄 정의
8.1의 세대 방식. 기획서 4장 "합체·소멸 후 다시 4번으로"와 동치이며 독립적인 동시 반응을 연쇄로 세지 않는다.

### 11.6 생성 후 반응
생성된 구체가 떨어져 일으킨 합체·소멸도 **같은 턴의 반응**으로 점수·연쇄에 포함한다.

### 11.7 소멸 규칙 C의 잔존 구체
큰 쪽의 색·위치·속도를 이어받고 레벨은 차이값. 점수는 원래 두 레벨 기준 소멸 공식.

### 11.8 히트스톱과 안정 판정
히트스톱은 `Engine.time_scale`을 낮추는 방식이다. 안정 판정의 프레임 카운트와 `max_settle_time`은 스케일된 물리 시간 기준이라 히트스톱이 강제 안정 시간을 잡아먹지 않는다. 해제 타이머는 `get_tree().create_timer(dur, true, false, true)`(ignore_time_scale)로 실시간 기준.

### 11.9 보드 기울기 연출
물리 보드를 회전하면 벽이 움직여 시뮬레이션이 깨지므로 **`Camera2D.rotation`만 트윈**한다.

### 11.10 미리보기 2턴치 (기획서 0.9.4 — #26)
- `Spawner`는 다음 묶음 하나 대신 **앞으로 `preview_turns`턴의 묶음 큐**를 가진다. 큐[0] = 다음 턴, 큐[1] = 그다음 턴. 각 묶음 크기는 `spawn_count_for_turn(그 턴 번호)` (ramp 사용 시에도 턴 번호 기준)
- 생성(`try_spawn`)은 큐[0]을 쓰고 맨 앞을 빼낸 뒤 맨 뒤에 새 묶음을 하나 뽑아 붙인다. 묶음 내용(색·레벨)은 **뽑힌 순간 확정**되고 이후 바뀌지 않는다 — 2턴 전에 본 공이 그대로 들어온다
- 같은 시드면 같은 순서 (결정론). 묶음을 미리 뽑으므로 이전 버전과 시드별 생성 순서가 달라지는 것은 허용
- 신호: `next_batch_changed(batch)`는 큐[0]용으로 유지하고, `preview_changed(batches: Array)`(전체 큐)를 추가한다. `peek_next()`는 큐[0], `peek_preview()`는 전체 큐
- F3 생성 수 변경(`sync_next_batch_size`)은 큐의 모든 묶음 크기를 맞춘다 (늘릴 때만 뒤에 새로 뽑아 붙이고, 줄일 때는 뒤에서 자른다)
- HUD: NEXT 영역에 큐[0]을 기존 크기로, 큐[1]을 오른쪽(또는 아래)에 **작고 흐리게**(알파 0.5, 크기 0.6배) 표시. 라벨 `NEXT` / `THEN`. 스와이프 영역을 가리지 않게 `mouse_filter = IGNORE` 유지

---

## 12. 마일스톤별 구현 명세

각 마일스톤은 로드맵의 "목표·완료 조건"을 그대로 따르며, 아래는 구현 세부다. **다음 마일스톤의 필드·기능을 미리 넣지 않는다.**

### M0. 프로젝트 셋업
- 1.1 설정으로 `project.godot` 생성, 1.3 폴더 생성 (빈 폴더는 `.gitkeep`).
- `GameConfig.gd`(필드 없음), `default_config.tres`, `Config` 오토로드.
- `Main.tscn`: Main(Node2D) + Camera2D(540, 960). 배경색은 `RenderingServer.set_default_clear_color`.
- git 저장소와 `.gitignore`(`.godot/`, `*.tmp`, `/android/`, `/build/`)는 이미 준비되어 있다. 필요한 항목만 추가한다. (`*.import` 파일은 Godot 4에서 커밋 대상이므로 무시하지 않는다.)
- `tests/run_tests.gd`, `tests/TestCase.gd` 뼈대 (테스트 0개로 통과).
- 검증: 10.1 명령 3종이 에러 없이 끝난다.

### M1. 보드와 구체 물리
- `Board.tscn`: 5.3 트리. 벽 4개의 크기·위치는 `_ready`에서 config 값으로 설정.
- `Frame`: 보드 경계선만 그린다.
- `Orb.tscn` + `Orb.gd` + `OrbVisual.gd`(단색 원). `CircleShape2D`는 `setup()`에서 새로 생성.
- `Main.gd`에 **임시** 방향키 처리 → `Board.set_gravity`. 주석 `# TEMP(M1): M2에서 InputRouter로 교체`.
- 테스트 구체 `debug_test_orb_count`개를 겹치지 않게 배치 (레벨 1~4 혼합). 여기서 쓰는 임시 RNG는 M4에서 제거.
- 테스트: `test_config.gd`.

### M2. 입력 추상화
- `SwipeDetector.gd`, `InputRouter.gd`(오토로드 등록), Input Map 액션 등록.
- `Main.gd`의 M1 임시 입력 제거 → `InputRouter.swipe` 연결 (M3 전까지는 바로 `Board.set_gravity`).
- 검증: `grep -rn "Input\.\|InputEvent" scripts --include=*.gd`가 `InputRouter.gd`, `SwipeDetector.gd`(타입 참조 없음이 이상적) 외에는 비어 있어야 한다.
- 테스트: `test_swipe.gd`.

### M3. 턴 상태 머신
- `TurnManager.gd` (6장). `SPAWNING`·`CHECK_GAMEOVER`는 즉시 통과.
- UI에 임시 디버그 라벨: `state`, `gravity`, `turn_index`, settle 경과. M9에서 DebugOverlay로 흡수.
- 강제 안정 발생 시 `push_warning`.

### M4. 구체 생성
- `Spawner.gd` (5.9, 11.3). `init_rng(Config.data.rng_seed)`, 실제 시드를 디버그 라벨에 표시.
- `Hud`에 다음 구체 미리보기 (`OrbVisual` 재사용).
- M1 테스트 구체·임시 RNG·`debug_test_orb_count` 삭제. 초기 구체 `initial_orb_count`개는 Spawner RNG로 보드 하단 절반에 배치.
- 테스트: `test_spawner.gd`.

### M5. 합체 규칙
- `ReactionRules.gd`(MERGE, MAX_CLEAR만), `CollisionResolver.gd`(7.1~7.2), Orb의 `contact_monitor`·`generation`·`consumed`, Board의 `orb_contact`.
- `TurnManager` settle 루프에 `flush()` 연결, 연쇄 갱신. 디버그 라벨에 턴 연쇄 수.
- 테스트: `test_rules.gd`, `scenarios/test_merge_scenario.gd`.

### M5+. 턴 소요 시간 튜닝 (M5 병합 직후, 별도 인박스 항목)
M4 검수(2026-09-28)에서 발견. 합체가 없는 M4 상태에서 **이동·생성 settle 단계 대부분이 `max_settle_time`(3초) 강제 안정**으로 끝났다.
- 원인: GodotPhysics2D에는 구름 저항이 없다. 벽에 붙은 구체와 쌓인 더미가 벽을 따라 30~100px/s로 계속 굴러 퍼져 `stable_linear_speed`(12) 아래로 내려가지 않는다. 240Hz에서 틱당 중력 속도 증가(2400/240 = 10px/s)도 임계값 12에 가깝다.
- 스크래치 측정 (8시드 × 6턴 = 96단계, 레벨1 더미 누적 상태):

| 감쇠 lin/ang | 마찰 | 임계 v/ω | 강제 안정 | 단계 평균 |
|---|---:|---|---:|---:|
| 0.1 / 1 (현재) | 0.3 | 12 / 1 | 83/96 | 2.81초 |
| 1 / 10 | 0.6 | 30 / 3 | 17/96 | 2.26초 |
| 1 / 30 | 0.6 | 30 / 3 | 22/96 | 2.12초 |
| 2 / 30 | 0.9 | 30 / 3 | 22/96 | 2.12초 |

- 할 일: 합체가 들어간 상태에서 다시 측정한다. **턴 소요 시간**(스와이프 → 입력 재개)과 **강제 안정 비율**을 시나리오 테스트 지표로 추가하고, 감쇠·마찰·`gravity_strength`·`stable_*`를 함께 조정한다. 목표값은 측정 후 Claude가 정한다. 물리 회귀(관통 ≤ 10px)를 유지한다.
- 이 항목 전까지 시나리오 테스트의 강제 안정 경고는 **기지의 문제**로 취급한다. "명세 동작"이 아니다.
- 기획서 0.2로 생성이 턴 시작으로 옮겨져 settle 단계가 턴당 1회로 줄었다. 위 표는 변경 전(이동·생성 2단계) 측정값이다.
- **M5 병합 후 재측정 (2026-09-28, Claude 스크래치, 6시드 × 20턴 = 120턴, 합체 포함, 턴 시간 = 스와이프 → `WAITING_INPUT`)**:

| 설정 | 강제 안정 | 평균 | p50 |
|---|---:|---:|---:|
| 현재 기본값 | 115/120 | 2.97초 | 3.00초 |
| 감쇠 1/30, 마찰 0.6, 임계 30/3 | 46/120 | 2.54초 | 2.63초 |
| 위 + 임계 120/5 | 13/120 | 2.13초 | 2.08초 |

- 진단: 측정 속도와 실제 이동 거리가 일치한다 (떨림이 아니라 **진짜 구름**). 구체 2개뿐인 판에서도 바닥의 공이 순수 구름(ω = v/r)으로 2.5초 뒤 40~150px/s. 더미 위 공이 굴러 떨어져 벽을 따라 반대 모서리까지 가고 튕겨 돌아온다.
- 저속 제동(접촉 중 & 속도 < 120px/s일 때 감쇠 10)은 적용되면 효과가 크다 (2.5초 시점 대부분 0.4~5px/s). 남는 경우는 제동 기준보다 빠르게 벽을 따라 구르는 공이다.
- 결론: **구름 저항**이 필요하다. 접촉 중인 구체의 속도 중 **중력에 수직인 성분**에만 일정 감속을 건다 (낙하 속도는 유지). 필요하면 저속 제동을 함께 쓴다. 인박스 #8.
- **#8 결과 (2026-09-29)**: 구름 저항은 속도 대입이 아니라 **힘·토크**로 건다 (속도 대입은 솔버 보정을 지워 관통 12px·이탈 발생). 12조합 스윕 후 기본값 `rolling_resistance 1.0`, 저속 제동 없음, 임계 30/3 지정 → 120턴 강제 0, p50 1.73초, p90 2.05초. 관통 기준 10 → 12px.
- **알려진 위험 — 물리 여유 부족**: 저항이 클수록 관통이 늘고(10~16px), 12조합 중 4개에서 20턴 중 이탈 1건이 났다. 지정 조합은 0건이지만 여유가 작다. 후속 후보: 관통 안전 보정(중심이 보드 밖이면 안쪽으로 되돌림), 벽 CCD·충돌 여유, `gravity_strength` 하향과 턴 시간 재측정. M9 전 별도 항목으로 다룬다.
- **최종 결론 (2026-09-29, 사용자 결정)**: 구름 저항 방식은 폐기한다. 바닥 한정으로 바꾸자 시간 개선이 거의 사라졌고(p50 2.2~2.4초), 저항 0에서도 20턴 회귀에 25px 초과 관통(안전장치 발동)이 있음이 드러났다 — 관통은 구름 저항과 별개인 기존 물리 약점이다. 두 문제를 분리한다:
  - **턴 시간 → 규칙으로 해결**: 기획서 0.3, `max_settle_time` 1.5초 상한. 움직임이 남아도 턴을 끝낸다. `rolling_resistance` 0, 임계 30/3 유지
  - **물리 안정성 → 별도 항목**: 이탈 안전장치(`escape_guard_depth` 25px)는 실제 플레이 보호막으로 유지. 관통 원인 조사는 후속 항목
- **#9 결과 (2026-09-29)**: 관통 원인은 새 구체가 기존 구체와 겹친 채 최종 크기로 나타나는 것 (안전장치 발동 전부가 `spawn_orb` 1~2프레임 뒤). **점진 성장** 도입 — `grow_duration 0.06`, `grow_start_ratio 0.3`. 120턴 안전장치 7 → 0, 최대 관통 79 → 13.6px. 연속 턴 관통 기준 16px, 물리 22시드·겹침 12px.
- **유령 상태 채택 (2026-09-29, 사용자 결정, 기획서 0.4)**: 새 구체는 겹침이 풀릴 때까지 다른 구체와 충돌하지 않는다. 아래 "엔진 발산"의 근본 대책. 인박스 #11.
  - #11 구현 시 사용자 승인으로 추가: 유령 타임아웃 시 유령 구체를 겹침이 가장 적은 가까운 위치로 옮기고 같은 프레임 기존 구체를 벽 안쪽으로 복구, 그리고 전역 사전 벽 복구(`wall_penetration_limit`). 모두 `PhysicsDirectBodyState2D`로 적용한다. 결과: 120턴 안전장치 0, 관통 8~12px, 사전 복구 발동 0.
- **알려진 위험 — 엔진 발산**: 새 구체 중심이 큰 구체 **내부**에 생기고 그 구체가 또 다른 구체와 맞닿은 3체 상태에서 GodotPhysics2D가 좌표를 발산시킨 사례가 있다 (비채택 조합 `0.20/0.3`, 속도는 정상인데 위치만 10^10px). 채택값에서는 미관측. 발산해도 안전장치가 보드 안으로 되돌리며, 모든 시나리오에 위치·속도 상한 assert가 있다. 근본 대책 후보(사용자 결정 필요 — 기획서 0.2 "빈자리와 무관한 생성"과 관련): 생성 직후 구체끼리 충돌을 끈 "유령 상태"로 두었다가 겹침이 풀리면 켜기, 또는 중심이 다른 구체 내부면 생성선 위에서 가장 가까운 비내부 지점으로 옮기기.

### M6. 상극 소멸
- `opposite_pairs`, `annihilation_rule`, `is_opposite` 추가. `ReactionRules`에 ANNIHILATE (5.8 표 전체).
- `sweep_resting_contacts` (7.3).
- 규칙 즉시 전환 확인용 임시 키(디버그 빌드 한정, `InputRouter` 경유)를 둬도 된다. M9 패널로 대체.
- 테스트: `test_rules.gd` 확장.

### M7. 게임오버와 점수
- `ScoreManager.gd` (5.10, 8.2), `save.cfg`.
- 게임오버·경고는 **보류** (11.2·11.4). 조건이 정해지기 전까지 M7은 점수·최고 점수 저장·재시작(R키)까지만 한다.
- `GameOverPanel`: 조건 확정 후. 재시작은 R키(`InputRouter.restart_requested`)로 `Main.restart()` 호출.
- 재시작: `get_tree().reload_current_scene()`. 설정은 `Config` 오토로드에 남아 유지된다.
- 테스트: `test_score.gd`.

### M8. 피드백과 UI
- `Effects.gd`가 `reaction_applied`, `gravity_changed`, `warning_changed`, `chain_changed`를 구독.
  - 합체: 결과 Orb의 `Visual.scale` 트윈 0.8 → `merge_pop_scale` → 1.0
  - 소멸·최대 합체: `CPUParticles2D` one-shot 파편. 합체와 시각적으로 확실히 다를 것
  - 연쇄(chain ≥ 2): "n연쇄" 라벨 팝업, 히트스톱(11.8), 효과음 `pitch_scale = 1 + (chain − 1) × chain_pitch_step`
  - 중력 전환: 카메라 기울기(11.9), 중력 방향 벽 강조(Frame), 하단 화살표 회전
  - 경고: 해당 벽 붉게 점멸 (Frame)
- `OrbVisual` 문양: 빨강 ▲, 파랑 ●(안쪽 작은 원), 초록 ■, 노랑 ◆. 흰색 반투명, `draw_colored_polygon`/`draw_circle`로 그린다 (폰트 의존 없음).
- 임시 효과음: `assets/sfx/`의 짧은 `.wav` (합체음과 소멸음은 달라야 함). 직접 생성 가능하면 `AudioStreamWAV` 코드 생성도 허용.
- 연출은 **물리 상태를 바꾸지 않는다** (Visual·카메라·파티클·UI만).

### M9. 디버그·밸런스 도구
- `DebugOverlay.tscn`은 `Main._ready`에서 `OS.is_debug_build()`일 때만 인스턴스화. `process_mode = PROCESS_MODE_ALWAYS`. 기존 임시 디버그 라벨 흡수.
- 표시: 상태, 구체 수, 턴 연쇄, 시드, FPS, 턴 수.
- 조작: 색·레벨 선택 후 보드 클릭 → 구체 생성(`InputRouter.debug_click`), 보드 초기화, 시드 입력 후 재시작, 스텝 모드.
  - 스텝 모드: 켜면 `TurnManager`가 상태 전이마다 `get_tree().paused = true`로 멈추고, N(`debug_step_requested`)으로 다음 전이까지 진행.
- 토글: 같은 방향 스와이프, 소멸 A/B/C, 생성 위치 모드. 슬라이더: 마찰, 반발, 반지름 증가율, 보드 크기, 중력 세기.
  - 반지름 증가율·보드 크기는 "보드 초기화" 시 반영. 마찰·반발·중력은 즉시 모든 Orb에 재적용.
- `PlayLogger.gd`: 게임오버 시 `playlog.csv`에 한 줄 append.
- 완료 확인: 기획서 7장 미정 사항 6개 모두 패널에서 변경 가능.

### M10. 모바일 포팅
- `export_presets.cfg` (Android). 키스토어 등 민감정보는 커밋하지 않는다.
- 세이프 영역: `DisplayServer.get_display_safe_area()`로 HUD 여백 조정.
- `Haptics.gd`: 스와이프 확정 시 `Input.vibrate_handheld(vibration_ms)` (설정 on일 때).
- `NOTIFICATION_APPLICATION_PAUSED` / `NOTIFICATION_APPLICATION_FOCUS_OUT` → 일시정지 패널, 복귀 시 이어하기.
- 실기기 재조정은 Codex가 측정값·기기명을 회신(`docs/jeongmo_codex_to_claude.md`)에 제안값으로 올리고, `default_config.tres` 반영은 Claude가 한다.

---

## 12-S. 스파이크: Jolt 3D + 평면 고정 (2026-10-02, 사용자 결정)

**목적**: ① 고밀도 물리 안정성 (Godot 2D 물리는 보정 장치 6겹으로 버티는 중) ② 화면·조작감 (입체 구슬, 기울어지는 보드). 실험 브랜치 `spike-jolt-3d`에서 진행하고, 결과를 보고 채택 여부를 정한다. `main`에는 결정 전까지 병합하지 않는다.

**구성**
- 물리: Godot 4.4+ 내장 **Jolt** (`physics/3d/physics_engine = "Jolt Physics"`). 구체는 `RigidBody3D` + 구 충돌체. **게임 평면은 XY**, `axis_lock_linear_z = true`, `axis_lock_angular_x/y = true` (Z축 회전만 허용 — 굴러가는 모습 유지)
- 단위: **1m = 100px** (보드 9.6m, L1 반지름 0.25m, 중력 1800px/s² → 18m/s²). 설정값(`GameConfig`)은 px 단위 그대로 두고 3D 쪽에서 환산한다
- 벽: 보드 4변 `StaticBody3D` 박스 + 앞뒤 투명 판(Z 잠금 보조, 필요 시)
- 화면: 원근 카메라가 보드를 정면에서 보고, 스와이프 시 **보드(시각 노드)가 중력 방향으로 살짝 기울어지는** 연출 (물리 평면은 고정). 구슬은 색 재질 + 간단한 조명·그림자. HUD·입력은 기존 2D 그대로 (`CanvasLayer`)
- **규칙·로직 재사용**: `TurnManager`·`Spawner`·`CollisionResolver`·`ReactionRules`·`ScoreManager`·`InputRouter`는 그대로 쓴다. `Board`/`Orb`와 같은 공개 API를 가진 `Board3D`/`Orb3D`를 만들어 위치·속도는 **평면 Vector2로 노출**한다 (코어가 읽는 `linear_velocity`·`angular_velocity`·`position` 의미를 유지할 어댑터)
- **보정 장치는 기본 끔**: 유령·점진 성장·타임아웃 보정·사전 벽 복구·안전장치 없이 먼저 측정한다. 게임 규칙인 빈자리 생성·입구 대기는 유지 (규칙이므로)

**비교 지표** (#17·#18과 같은 측정 경로, 시드 101~112, 게임오버 또는 400턴): 점유율 구간별 관통·이탈·발산, 레벨별 반경 미만 이동(잼), 게임오버 턴·점유율, 프레임당 물리 시간(ms), **결정성**(같은 시드 2회 실행 시 턴별 구체 상태 일치 여부), 물리 틱 60/120/240 비교

## 12-J. Jolt 3D 채택 (2026-10-03, 사용자 결정)

스파이크 #19 결과로 **물리 엔진을 Jolt 3D(평면 고정)로, 표현을 3D로** 바꾼다. 게임 규칙·평면 좌표(px)·설정값은 그대로다.

**채택 근거 (#19 2차, 120Hz, 12시드 게임오버까지)**: 보정 장치 없이 이탈·발산 0, 같은 기기 독립 프로세스 2회 120턴 상태 해시 일치(worker 1 + 접촉 쌍 ID 정렬), 프레임당 물리 0.40ms(2D 0.20ms — 1차의 19ms는 `--fixed-fps` 장시간 실행의 타이머 측정 오류), 카메라 FOV 25°로 세로 화면에 보드 전체. 남은 과제: 벽 침투 최대 19.1px, 턴 끝 쌍 겹침 최대 57.6px(주로 합체 직후 1~3프레임).

**확정 설정** (스파이크 값)
| 키 | 값 |
|---|---|
| `physics/3d/physics_engine` | Jolt Physics |
| `physics/jolt_physics_3d/simulation/position_steps` | 4 (기본 2) |
| `physics/jolt_physics_3d/simulation/velocity_steps` | 10 |
| `physics/jolt_physics_3d/simulation/baumgarte_stabilization_factor` | 0.2 |
| `physics/jolt_physics_3d/simulation/penetration_slop` | 0.02 |
| `physics/3d/run_on_separate_thread` | false |
| `threading/worker_pool/max_threads` | 1 (결정성. **전역 설정**이라 리소스 로딩 등 다른 스레드 작업에도 영향 — M10에서 재평가) |
| 물리 틱 | 120 (60Hz는 #20에서 재측정) |
| 단위 | 1m = 100px. 평면 XY, `axis_lock_linear_z`, `axis_lock_angular_x/y` |
| 카메라 | 원근 FOV 25°, z = 42m |

**통합 구조 (#20)**
- 코어(`TurnManager`·`CollisionResolver`·`ScoreManager`·`Spawner`·`Hud`)가 특정 노드 타입(`Orb`/`Orb3D`)에 묶이지 않게 한다. 코어가 쓰는 구체 API: `color`, `level`, `generation`, `consumed`, 평면 `position: Vector2`(px), `linear_velocity: Vector2`(px/s), `angular_velocity: float`, `get_radius()`, 유령·입구 대기 상태. 보드 API: §5.3 + 빈자리·입구 대기. **하나의 코어 경로**로 2D·3D 보드를 모두 돌릴 수 있게 하고(덕 타이핑 또는 공통 베이스), 스파이크의 `TurnManager3D`·`Hud3D` 등 복사본은 제거
- 메인 씬은 3D. 2D 씬은 회귀 비교가 끝날 때까지 유지 (`scenes/Main2D.tscn`으로 이름 변경 가능)
- 보정 장치: 3D 기본은 **합체·규칙 C 잔존 결과에만 유령**(겹침 풀릴 때까지 통과) 적용을 시험. 점진 성장·타임아웃 보정·사전 벽 복구·안전장치는 3D에서 기본 끔, 측정 후 필요한 것만 켠다
- 2D 물리·보정 장치 코드 정리는 3D 회귀가 안정된 뒤 별도 항목
- **#21 이후 기준**: 질량 지수 2로 바닥 압력이 커져 연속 턴 벽 침투가 약 25px. 연속 턴 벽 한도 28px (22시드 14 / 16px 유지). position steps 6·8은 일관된 개선이 없어 4 유지
- **M8 후보 — 표시 위치 보정**: 물리 위치는 그대로 두고, 렌더링할 때만 구슬 중심을 보드 안쪽 `half − r`로 제한해 벽 박힘이 보이지 않게 한다 (게임 로직·측정은 물리 위치 기준)

## 12-B. 스파이크: 타임어택 모드 BLITZ (기획서 0.10 — #31, 2026-10-05 사용자 결정)

턴제와 **별도 모드**로 실시간 타임어택을 만들어 둘 다 플레이해 보고 메인을 고른다. 목표 경험: **빠르게 손을 움직일수록 고득점** (참고: 비주얼드 블리츠). 턴제 코드·기본 동작은 그대로 둔다.

**모드 전환**
- `game_mode: GameMode { TURN, BLITZ }` (기본 TURN). 실행 인자 `--mode=blitz`, 디버그 키 **F4**(모드 전환 후 재시작, M9 디버그 패널이 대체할 때까지 TEMP)
- BLITZ에서는 `TurnManager` 대신 `BlitzManager`가 흐름을 맡는다. `CollisionResolver.flush(delta)`를 매 물리 프레임 호출하는 것, 반응 흐름 `reaction_applied → (모드 매니저).on_reaction → reaction_ready → ScoreManager`, 콤보 단일 출처(#24)는 같다. HUD·DebugHud·결과 패널은 모드 매니저의 같은 이름 신호·필드에 붙는다 (덕 타이핑)

**흐름**
| 단계 | 내용 |
|---|---|
| 시작 | 초기 구체는 턴제와 같다 (`initial_orb_count`). 타이머 `blitz_duration` **90초** 시작 |
| 진행 | **입력 잠금 없음**. 스와이프 즉시 중력 전환(굴러가는 중에도). 같은 방향 스와이프는 무시. 연타 방지 `blitz_swipe_cooldown` 0.12초. 보드 기울기 연출은 턴제와 같다 |
| 생성 | 스와이프와 무관하게 `blitz_spawn_interval`(0.5초)마다 1개, 현재 중력의 반대 벽에서. 입구 대기 구체가 있으면 그 틱은 건너뛴다 (쌓이지 않음). NEXT/THEN은 다음 생성 2개. 레벨 확률 `blitz_spawn_level_weights` |
| 종료 | 남은 시간 0 → 입력 잠금·생성 정지 → **피날레** → 결과 패널. 입구 막힘 게임오버는 없다 (판이 차면 반응이 줄어드는 것이 벌) |

**스피드 콤보·피버**
- 콤보: 반응(MERGE·MAX_CLEAR·BLAST)이 직전 반응 후 `blitz_combo_window`(1.5초) 안에 일어나면 `combo += 1`, 아니면 1부터 다시. 반응 없이 창이 지나면 0. 최대 콤보는 판 전체
- 콤보 배수 = `min(1 + blitz_combo_step × (combo − 1), blitz_combo_max_multiplier)` (가안 0.2 / ×5). 턴제의 2^(n−1)은 실시간 콤보 수에서 폭주하므로 쓰지 않는다. 위험 배수(§8.2)는 그대로
- **피버**: 콤보가 `blitz_fever_combo`(8)에 닿으면 `blitz_fever_duration`(6초) 동안 모든 반응 점수 ×`blitz_fever_multiplier`(2). 보드 프레임 주황 발광(임시). 피버 중 콤보 8 재도달은 시간 갱신만
- 반응 딕셔너리에 `combo`, `combo_multiplier`, `fever` 를 싣고 `ScoreManager`는 그 값을 쓴다 (모드별 배수 계산은 모드 매니저 한 곳)

**시간 보너스** (남은 시간에 더함, 화면에 `+3s` 표시)
- BLAST `blitz_time_bonus_blast` +3초, MAX_CLEAR `blitz_time_bonus_jackpot` +5초, 콤보가 10의 배수에 닿을 때마다 `blitz_time_bonus_combo10` +2초

**대폭발 레벨**: 90초 동안 들어오는 구체는 약 180개(색당 약 45개)라 L6(L1 32개 분량)은 거의 못 만든다. BLITZ에서는 `blitz_blast_min_level`(가안 **4**)을 쓴다 (턴제는 `blast_min_level` 6, #30). 깜빡임도 같은 기준

**피날레 (Last Hurrah)**: 시간 종료 후 폭발 가능 구체를 큰 레벨부터 `blitz_finale_interval`(0.3초) 간격으로 **하나씩** 터뜨린다 — 그 구체만 제거 + 전역 밀어내기(§7.7과 같은 Δv) + 점수 `score_for_level(L) × blast_score_factor`(배수 없음). 밀려서 생긴 반응은 콤보·피버 규칙대로 점수. 폭발 가능 구체가 없고 마지막 반응 후 1.5초(상한 5초)가 지나면 결과 패널 `TIME UP` — 점수, 최고 점수(**BLITZ 전용 저장 키**), 최대 콤보, 대폭발 수, 피버 횟수

**HUD**: 남은 시간(큰 숫자, 10초 이하 빨강), `COMBO n (x1.4)`, 피버 표시, 시간 보너스 팝업. 턴 수 표시는 숨김

**새 필드 (가안, 스파이크 측정·플레이로 조정)**
| 필드 | 가안 |
|---|---|
| `game_mode` | TURN |
| `blitz_duration` | 90.0 |
| `blitz_swipe_cooldown` | 0.12 |
| `blitz_spawn_interval` | 0.5 |
| `blitz_spawn_level_weights` | [0.7, 0.25, 0.05] |
| `blitz_combo_window` | 1.5 |
| `blitz_combo_step` / `blitz_combo_max_multiplier` | 0.2 / 5.0 |
| `blitz_fever_combo` / `blitz_fever_duration` / `blitz_fever_multiplier` | 8 / 6.0 / 2.0 |
| `blitz_time_bonus_blast` / `_jackpot` / `_combo10` | 3.0 / 5.0 / 2.0 |
| `blitz_blast_min_level` | 4 |
| `blitz_finale_interval` | 0.3 |

**측정 — 이 모드의 전제 검증**: 자동 입력 봇이 `blitz_bot_interval`마다 무작위(직전과 다른) 방향으로 스와이프. **0.3 / 0.6 / 1.2초** 3조건 × 시드 101~112. 보고: 점수 분포, 반응 수, 최대 콤보, 피버 횟수·누적 시간, BLAST 수, 시간 보너스 합·실제 플레이 시간, 점유율 시계열(10초 단위), 첫 반응까지 시간, 피날레 점수 비중, wall/pair·이탈·발산(빠른 중력 전환에서의 물리 안정성). **빠른 손일수록 점수가 뚜렷하게 높아야 한다** — 아니면 전제가 성립하지 않으므로 `상태: 질문`으로 보고

### 12-B.2 보완: 리필·스피드 체인·시간 보너스 축소 (기획서 0.10.1 — #32)
#31 측정에서 **느린 봇(1.2초)이 빠른 봇(0.3초)보다 점수가 9.6% 높았다**. 원인: ① 생성이 고정 간격이라 손이 빨라도 재료가 늘지 않음 ② 물리가 저절로 반응을 이어 1.5초 콤보가 거의 끊기지 않음(최대 콤보 p50 41~58, 피버가 플레이 시간의 약 45%) ③ 시간 보너스 과다(90초 판이 p50 273~297초). 비주얼드 블리츠처럼 **치운 만큼 채워지고, 빠르고 정확한 입력이 배수를 올리도록** 바꾼다.

**리필**
- 시작: 판을 `blitz_initial_occupancy`(0.35)까지 무작위 빈자리에 채운다 (레벨은 `blitz_spawn_level_weights`, 겹치지 않게). 그다음 `READY`(`blitz_ready_time` 1.5초, 입력 잠금·물리 진행) → `GO`에서 타이머 시작
- 생성 간격: 점유율이 `blitz_target_occupancy`(0.40) **미만이면** `blitz_refill_interval`(0.15초), 이상이면 `blitz_spawn_interval`(0.5 → **0.8초**). 많이 치울수록 빨리 채워진다. 입구 대기 시 건너뜀은 그대로

**스피드 체인** (#31의 1.5초 반응 콤보를 대체)
- 받아들여진 스와이프마다 `blitz_chain_window`(1.0초) 창을 연다. 창 안에 반응이 하나라도 나오면 그 스와이프는 **생산적** → `chain += 1` (스와이프당 1회). 창이 반응 없이 끝나면 `chain = 0`
- 마지막 스와이프 후 `blitz_chain_idle`(2.0초) 동안 스와이프가 없으면 `chain = 0` (손을 멈추면 끊김)
- 배수 = `min(1 + blitz_chain_step × chain, blitz_chain_max_multiplier)` (0.25 / ×5). **그 순간의 배수를 모든 반응 점수에 적용** (스와이프 없이 일어난 반응 포함). 위험 배수 그대로
- **피버**: `chain`이 `blitz_fever_chain`의 배수에 닿을 때마다 `blitz_fever_duration`로 시작·갱신, 점수 ×2. **#51 (2026-10-09 사용자 결정): 6 → 8** (8, 16, 24 …) — #36 측정에서 조준 플레이 시간의 49%가 피버(목표 15~30%)
- HUD `CHAIN 4 (x2.0)`, 결과 패널·디버그는 `MAX CHAIN`. #31의 반응 콤보 필드(`blitz_combo_*`, `blitz_fever_combo`)는 제거
- 반응 딕셔너리에 `chain`, `combo_multiplier`(체인 배수), `fever`를 싣는다 (`combo`는 `chain`과 같은 값으로 채워 HUD·점수 경로 호환)

**시간 보너스 축소**: BLAST +1초, MAX_CLEAR +3초, 콤보 10 보너스 **삭제**. 한 판 보너스 합계 상한 `blitz_time_bonus_cap` 20초

**필드 변경**
| 필드 | 값 |
|---|---|
| `blitz_spawn_interval` | 0.5 → **0.8** |
| 새 `blitz_initial_occupancy` / `blitz_target_occupancy` / `blitz_refill_interval` | 0.35 / 0.40 / 0.15 |
| 새 `blitz_ready_time` | 1.5 |
| 새 `blitz_chain_window` / `blitz_chain_idle` | 1.0 / 2.0 |
| 새 `blitz_chain_step` / `blitz_chain_max_multiplier` | 0.25 / 5.0 |
| 새 `blitz_fever_chain` | 6 → **8** (#51) |
| `blitz_fever_duration` | 6.0 → 5.0 → 1.2 (#32 측정 조정) → **3.0** (#33, 1.2초는 체감이 거의 없음) |
| `blitz_time_bonus_blast` / `_jackpot` | 3.0 / 5.0 → **1.0 / 3.0** |
| 새 `blitz_time_bonus_cap` | 20.0 |
| 제거 `blitz_combo_window`, `blitz_combo_step`, `blitz_combo_max_multiplier`, `blitz_fever_combo`, `blitz_time_bonus_combo10` | |

**측정 — 숙련 대리 봇 추가**: 무작위 봇은 "연타"만 재므로 **휴리스틱 봇**을 추가한다. 스와이프 시점마다 현재 중력이 아닌 3방향 각각에 대해, 반응 가능한 쌍(같은 색·같은 레벨, BLITZ BLAST 쌍) 중 중심을 잇는 방향이 그 방향과 `|cos| ≥ 0.8`이고 중심 거리 ≤ 두 반지름 합 × 3인 쌍의 수를 세어 최대 방향을 고른다 (동점은 봇 RNG). 조건: **휴리스틱 0.3 / 0.6 / 1.2초, 무작위 0.3 / 1.2초** × 시드 101~112. 보고: #31 표 항목 + 체인 분포·최대 체인·생산적 스와이프 비율, 피버 누적 비율(플레이 시간 대비), 시간 보너스 합·실제 플레이 시간, 리필 생성 수, 점유율 시계열

**#32 결과 (2026-10-05)**: 실제 플레이 p50 110초(④ 충족), 무작위 연타 이득 없음(③ 충족), 0.6·1.2초에서 휴리스틱 > 무작위. 그러나 휴리스틱 0.3초가 가장 낮음(50,501 vs 0.6초 77,157) — 반응 하나가 가장 최근 스와이프 하나만 생산적으로 인정해 1초 창 안에 겹친 스와이프가 헛스와이프가 됨. 물리가 초당 4~5회 저절로 반응을 만들어 반응만으로 숙련을 가리기 어렵다. **사용자 결정: 봇 기준 추적은 멈추고 직접 플레이로 판단** (체인 귀속 규칙 유지)

**판정 기준**: ① 휴리스틱 0.3 > 0.6 > 1.2 (빠르고 정확할수록 높음) ② 휴리스틱 > 같은 간격 무작위 ③ 무작위 0.3이 무작위 1.2보다 크게 높지 않음 (연타 무이득) ④ 실제 플레이 시간 p50 90~110초 ⑤ 피버 비율 15~30%. 수치 조정이 필요하면 가안을 바꾼 추가 조건으로 1회 재측정까지 허용, 그 뒤 `상태: 질문`

### 12-B.3 스와이프마다 생성 (기획서 0.10.2 — #33)
사용자 요청 (2026-10-05): "NEXT 구슬이 무조건 시간으로 나오는데, 방향을 입력할 때마다로 바꿔 달라". 생성이 손 속도에 묶이므로 **빠른 손 = 더 많은 재료 = 더 많은 점수 기회**, 대신 함부로 스와이프하면 판이 찬다.

- 새 필드 `blitz_spawn_on_swipe` (bool, 기본 **true**). true면 시간 생성(§12-B·12-B.2의 `blitz_spawn_interval`·`blitz_refill_interval`)을 끄고, **받아들여진 스와이프마다**(쿨다운·같은 방향으로 무시된 입력 제외) NEXT 묶음(1개)을 **새 중력의 반대 벽**에서 생성한다 — 턴제의 스와이프 순간 생성(§6)과 같은 `Spawner.try_spawn` 경로. NEXT/THEN 승격도 턴제와 같다
- 입구 대기 구체가 있으면 그 스와이프는 중력만 바꾸고 생성은 건너뛴다 (NEXT는 소비하지 않고 유지)
- READY 동안·시간 종료 후(피날레)에는 생성하지 않는다. 시작 35% 채움(`blitz_initial_occupancy`)은 그대로
- `blitz_spawn_on_swipe = false`면 #32의 시간·리필 생성과 같다 (비교용). 리필 필드는 지우지 않는다
- 스피드 체인·피버·시간 보너스 규칙은 그대로

### 12-B.4 BLITZ 6색 (기획서 0.10.3 — #34)
사용자 (2026-10-06): "블리츠 모드로 한다면 색이 4가지인 게 너무 쉬워진다". 4색은 아무 두 구체가 닿아도 같은 색일 확률이 25%라, 35~40% 찬 판에서 물리가 초당 4~5회 저절로 합체를 만든다 (#32·#33: 무작위 연타의 생산적 스와이프 75%, 연타 점수가 조준의 2.5배). 색을 늘려 우연한 합체를 줄이고 **조준해야 터지는** 판으로 만든다. **턴제는 4색 그대로**.

- `OrbTypes.OrbColor`에 **PURPLE**(4), **CYAN**(5)을 뒤에 추가한다 (기존 0~3 번호 불변)
- `color_display`에 보라 `#A35CF0`, 청록 `#22C7D9` 추가. 3D 머티리얼·HUD 미리보기·디버그가 같은 표를 쓴다
- 색별 합체 효과(§7.6): 새 두 색은 **기본 충격파** — `shock_color_modes` [PUSH, PULL, SHAKE, LIFT, **PUSH, PUSH**], `shock_color_impulse_scale` [1.5, 0.8, 0.0, 1.0, **1.0, 1.0**], `shock_color_radius_factor` [3.0, 3.0, 0.0, 3.0, **2.5, 2.5**] (§7.4 수치와 같음)
- 생성 색 확률: 턴제 `spawn_color_weights`는 **[1, 1, 1, 1, 0, 0]** — 턴제 생성 순서는 **시드별로 이전과 완전히 같아야 한다**. BLITZ는 새 필드 `blitz_spawn_color_weights` **[1, 1, 1, 1, 1, 1]**을 생성·시작 채움 모두에 쓴다
- 색 개수를 4로 가정한 코드(배열 길이·`range(4)`·색 순환 등)가 남지 않게 한다. 휴리스틱 봇도 6색에서 그대로 동작
- 색각 문양(M8)을 넣을 때 보라 ★, 청록 ✚로 한다 (기존 ▲ ● ■ ◆)

### 12-B.5 없어진 만큼 보충 (기획서 0.10.5 — #36)
사용자 (2026-10-06): "블리츠 모드일 때는 한 번에 한 개의 공만 들어가는 게 아니라, 없어지는 만큼 보충될 수 있도록 해야 할 것 같다". #33의 스와이프당 1개로는 합체·대폭발로 줄어든 만큼이 돌아오지 않아 판이 비어 간다 (#33 4색 조준 종료 점유율 7~10%, #34 6색 조준 23%).

- **보충 빚** `refill_debt`: RUNNING 중 반응마다 `(사라진 구체 수 − 새로 생긴 구체 수)`를 더한다 — MERGE +1 (2개 → 1개), BLAST +2, MAX_CLEAR +2. 피날레 폭발은 더하지 않는다 (생성이 멈춘 뒤라)
- **받아들여진 스와이프마다** `n = min(max(blitz_min_spawn_per_swipe, refill_debt), blitz_max_spawn_per_swipe)`개를 **한 묶음으로** 새 중력의 반대 벽에서 생성하고 `refill_debt = max(refill_debt − n, 0)`. 가안: 최소 **1**, 최대 **8** (넘는 빚은 다음 스와이프로 넘어감)
  - 줄어든 게 없는 헛스와이프는 지금처럼 1개 → 연타하면 판이 차는 벌칙 유지
  - 잘 터뜨린 뒤의 스와이프는 없어진 만큼 한꺼번에 쏟아져 들어온다 (기울이기 손맛)
- 묶음 배치는 턴제 다중 생성과 같은 경로 (`Spawner.try_spawn`의 빈자리 탐색, 자리가 없으면 입구 대기). 입구 대기 구체가 있으면 그 스와이프는 생성하지 않고 **빚은 그대로 유지**
- **후보 순서**: 후보는 한 줄로 뽑아 순서대로 소비한다 — 묶음 크기가 달라도 같은 시드면 같은 순서
- **미리보기**: NEXT = 다음 스와이프에 들어올 구체들(최대 5개 표시, 더 많으면 `×n` 개수 표시), THEN = 그다음 1개. 빚이 바뀔 때마다 갱신
- 시간 생성 경로(`blitz_spawn_on_swipe = false`)와 턴제는 그대로
- 새 필드: `blitz_min_spawn_per_swipe` 1, `blitz_max_spawn_per_swipe` 8. 시작 채움 35%는 유지 (측정 후 조정)

**#36 측정 → 목표 밀도 보충으로 교체 (2026-10-07 사용자 결정)**: 위 개수 기준 빚은 판을 꽉 채웠다 — 6색 조준 0.6초에서 점유율 40초 74% → 끝 81%, 반응 220 → 126, BLAST 22 → 10, 입구 막힘 70회. 합체하면 구체가 커지는데 개수만 되돌려 놓으니 면적이 늘어난다 (L1+L1 → L2 + 보충 L1 = 면적 약 1.8배). 그래서 **개수가 아니라 판 밀도를 기준**으로 채운다:
- 받아들여진 스와이프마다 현재 점유율 `p`(위험 배수와 같은 최종 반지름 기준)에서 시작해, 후보를 큐 순서대로 하나씩 묶음에 넣는다 — **첫 후보는 항상** 넣고(최소 `blitz_min_spawn_per_swipe` 1), 그다음은 `p + Σ 후보 면적 ÷ 보드 면적 < blitz_target_occupancy`(0.40, #32 필드 재사용)인 동안 계속, 최대 `blitz_max_spawn_per_swipe` 8개
  - 많이 터뜨려 판이 비면 다음 스와이프에 40%까지 한꺼번에 쏟아지고, 40% 이상이면 1개 (#34와 같아 연타 벌칙 유지)
- `refill_debt`(개수 빚)는 규칙에서 뺀다 (측정용 관측값으로 남겨도 됨). 입구 대기 중인 스와이프는 생성 없음 — 다음 스와이프에서 그때 밀도로 다시 계산하므로 이월할 것이 없다
- 미리보기: NEXT = 지금 스와이프하면 들어올 묶음 (반응·생성으로 점유율이 바뀔 때 다시 계산, 최대 5개 + `×n`), THEN = 그 묶음 다음 후보 1개
- 후보 한 줄 순서 소비(시드별 같은 순서)는 그대로

### 12-B.6 BLITZ 끊김·입력 지연 개선 (기획서 0.10.11 — #57)
사용자 수동 QA (2026-10-10, Codex 경유): **BLITZ에서 끊김·입력 지연이 느껴져 조작감이 나쁘다**. Codex 코드 분석(#56 후속 회신):
- 쿨다운(0.12초) 중 스와이프는 **버려지고**(버퍼 없음), 쿨다운이 물리 `delta`로 줄어 **히트스톱(시간 0.12배, 0.07초) 중엔 거의 줄지 않아** 최대 약 0.18초까지 늘어난다
- 스와이프 한 번에 구슬 1~8개를 동기 생성하며 구슬마다 `PhysicsMaterial`·`SphereShape3D`·`SphereMesh`·`StandardMaterial3D`를 새로 만든다
- 미리보기가 스와이프 한 번에 최대 3번 다시 그려지고 매번 `OrbVisual`을 지우고 새로 만든다 (최대 18개)
- 대폭발 연출이 매번 고리·파티클·조명·섬광 노드를 새로 만든다

**결정 (Claude, 2026-10-10)**
1. **BLITZ는 히트스톱 없음** — 빠른 연속 입력이 핵심인 모드에서 전체 시간을 멈추면 흐름과 입력이 끊긴다. 대폭발의 흔들림·섬광·고리·파편·소리는 그대로. 턴제는 히트스톱 유지. 새 필드 `blitz_hitstop_enabled` = **false**
2. **입력 쿨다운은 실제 시간 기준** — 시간 배율과 무관하게 줄어든다 (어떤 연출도 입력을 늦추지 못하게). `blitz_swipe_cooldown` 0.12 → **0.08초**
3. **입력 버퍼 1칸** — 쿨다운 중 들어온 스와이프는 버리지 않고 마지막 것 하나를 저장했다가 쿨다운이 끝나는 프레임에 실행한다. 그 순간 현재 중력과 같은 방향이면 버린다. READY·피날레 중 입력은 저장하지 않는다. 새 필드 `blitz_swipe_buffer_enabled` = **true**
4. **생성 렉 제거** — 구슬 리소스 공유: 레벨별 `SphereMesh`·`SphereShape3D`, 색별 기본 머티리얼, `PhysicsMaterial` 1개. 깜빡임처럼 구슬마다 달라야 하는 값은 인스턴스 셰이더 파라미터 또는 **그 구슬만 복제(copy-on-write)**, 반지름이 바뀌는 구슬의 모양도 복제 후 변경. 턴제·BLITZ 공통
5. **셰이더·자원 예열** — 판 시작 전(READY 동안, 턴제는 첫 생성 전)에 6색 × 7레벨 구슬 머티리얼, 대폭발·색 효과·합체 파티클 머티리얼을 화면 밖에서 한 번씩 그려 **첫 사용 때 셰이더 컴파일 멈춤**이 없게
6. **미리보기**: 스와이프 한 번에 갱신 **1회**로 합치고(프레임당 1회, 더티 플래그), `OrbVisual`은 지우지 않고 재사용 (색·반지름·문양만 바꿈)
7. **대폭발 연출 풀링**: 고리·파티클·조명·섬광 노드를 미리 만들어 재사용 (#46 색 효과처럼)
8. (덧붙임, #56 검수) THEN의 `×n` 글자가 너무 작고 보드 윗선에 붙는다 → NEXT `×n`과 같은 크기 규칙의 0.8배 이상, 보드 윗선과 8px 이상 간격

**측정 (창 모드 — 실제 렌더링)**: 캡처 도구처럼 창을 띄워 BLITZ를 스크립트로 진행 — 휴리스틱 봇 0.3초 + 강제 대폭발·큰 묶음 생성 구간 포함, 시드 101~104. 보고: **고치기 전(main)과 후** 각각 프레임 시간 p50/p95/p99/최대, 16.7ms·33.3ms 넘은 프레임 수, **입력 이벤트 → 수락** 지연 p50/p95/최대, 수락 → 생성 완료, 버려진 입력 수, 첫 대폭발·첫 큰 묶음 생성 프레임 시간
- 목표: 예열 이후 **33.3ms 넘는 프레임 0**, p99 < 16.7ms (이 PC), 버려진 입력 0, 수락 지연 ≤ 쿨다운 + 1프레임

## 12-F. 피드백 연출 1차: 대폭발 VFX·뽁뽁이 사운드 (기획서 0.10.4 — #35, M8 일부)

사용자 (2026-10-06): "폭발할 때 VFX가 더 강하게 들어갔으면 하고, 사운드도 그 뽁뽁이 있잖아, 그 사운드가 들어갔으면 해". 현재 3D 대폭발은 반지름 1.5m 흰 고리 0.18초 + 프레임 떨림 6cm뿐이고 소리가 없다.

**구조**
- 연출 전용 노드 `FeedbackDirector`를 메인 씬에 둔다. 모드 매니저의 `reaction_ready`(점수·콤보·체인이 채워진 반응)와 BLITZ 피날레 폭발을 받아 **VFX·SFX만** 만든다. 게임 상태·물리·점수는 바꾸지 않는다 (히트스톱만 예외 — 아래)
- VFX는 3D 메인 씬 기준. 2D 회귀 씬은 지금 연출 그대로 두고 SFX만 붙여도 된다
- 기존 `Board3D._play_blast_effect`(흰 고리·프레임 떨림)는 이 연출로 대체한다
- 레벨 계수 `k = 1 + 0.25 × (L − 4)` (최소 1). BLITZ L4 = 1.0, 턴제 L6 = 1.5, L7 = 1.75

**대폭발 VFX** (BLAST·MAX_CLEAR)
| 요소 | 내용 | 가안 |
|---|---|---|
| 히트스톱 | `Engine.time_scale`을 잠깐 낮춘다. 해제는 실시간 타이머(`ignore_time_scale`) | `fx_hitstop_scale` 0.12, `fx_hitstop_time` 0.07초 (MAX_CLEAR 0.1초) |
| 카메라 흔들림 | `Camera3D.h_offset/v_offset`를 감쇠 사인 합으로 흔든다 (난수 없음, 결정적). 물리 노드는 움직이지 않는다 | 진폭 `fx_shake_px` 16px × k (px → m는 ÷100), `fx_shake_time` 0.4초 |
| 화면 섬광 | HUD 아래 전체 화면 흰색 `ColorRect`, 알파 → 0 | `fx_flash_alpha` 0.35, `fx_flash_time` 0.15초 |
| 충격파 고리 | 평면 고리 메시 2개(첫째 흰색, 둘째 두 구체 색 섞음), 0.08초 간격. 반지름 0 → `fx_ring_radius_factor` 4.0 × r_L, 0.35초, 두께 감소·알파 페이드, unshaded·additive | |
| 파편 | `CPUParticles3D` 원샷 (Compatibility 렌더러·모바일 대응). 터진 구체마다 그 색 `fx_debris_per_orb` 24개 + 흰 불꽃 16개. XY 평면 방사 6~14 m/s × k, 현재 중력 방향 가속, 수명 0.5~0.8초, 크기 줄어듦 | |
| 섬광 조명 | 폭발 지점 `OmniLight3D`, 에너지 6 × k → 0, 0.2초, 범위 6m | |

- BLITZ 피날레의 단일 구체 폭발: 같은 연출 × 0.6, 히트스톱 없음 (연속으로 터지므로)
- **합체 연출(가볍게)**: 결과 구체 **메시만** 스케일 1.0 → 1.18 → 1.0 (0.14초, 충돌 크기 불변) + 결과 색 파티클 10개. 히트스톱·흔들림 없음

**뽁뽁이 사운드**
- `SfxBank`가 시작할 때 소리를 **코드로 합성**해 `AudioStreamWAV`(16bit 모노 44.1kHz)로 만든다 — 외부 음원·저작권 문제 없음. `res://assets/sfx/pop.wav`·`blast.wav`(또는 `.ogg`)가 있으면 그 파일을 대신 쓴다 (실제 뽁뽁이 녹음으로 교체 가능)
- 합성 **"뽁"(pop)**: 1.5ms 백색 잡음 클릭 + 감쇠 사인 (8ms 동안 1,800 → 900Hz로 피치 하강, 감쇠 시상수 18ms), 총 60ms
- 합성 **"대폭발"**: pop 7개를 25~45ms 간격으로 겹침 (피치 ±15%, 결정적 패턴 — 뽁뽁이를 한꺼번에 비트는 소리) + 저음 쿵 (사인 70 → 45Hz, 감쇠 180ms) + 잡음 휙 (감쇠 250ms)
- 재생 규칙
  - MERGE: pop. 피치 = 레벨 계수(결과 L2 1.35 … L7 0.75, 선형) × **연쇄 상승** `2^(min(n − 1, sfx_chain_semitones_max) / 12)` (n = 현재 콤보·체인, 반음씩 올라가 최대 한 옥타브) × 지터 ±`sfx_pitch_jitter`(3%). 지터는 `stable_spawn_id` 해시로 정한다 (난수 호출은 `Spawner.gd`만 규칙 유지)
  - BLAST·MAX_CLEAR: 대폭발 소리, +4dB
  - BLITZ 피날레 폭발: 대폭발 소리 −2dB, 터질 때마다 반음 상승
- 보이스: `AudioStreamPlayer` 12개 풀, 라운드로빈, 모자라면 가장 오래된 것을 끊는다. 버스 `SFX` 신설 (Master 아래)
- `sfx_volume_db` 0, 디버그 키 **M** 음소거 토글 (TEMP — M9 설정 화면에서 대체)

**새 필드 (가안)**
| 필드 | 가안 |
|---|---|
| `fx_enabled` / `fx_hitstop_enabled` | true / true |
| `fx_hitstop_scale` / `fx_hitstop_time` | 0.12 / 0.07 |
| `fx_shake_px` / `fx_shake_time` | 16.0 / 0.4 |
| `fx_flash_alpha` / `fx_flash_time` | 0.35 / 0.15 |
| `fx_ring_radius_factor` | 4.0 |
| `fx_debris_per_orb` | 24 |
| `sfx_enabled` / `sfx_volume_db` | true / 0.0 |
| `sfx_chain_semitones_max` / `sfx_pitch_jitter` | 12 / 0.03 |

**주의**
- 히트스톱은 물리 시간도 늦춘다. 실시간 타이머로 풀기 때문에 프레임 타이밍에 따라 결과가 달라진다 → **헤드리스 테스트·측정 러너는 `fx_hitstop_enabled = false`로 실행**한다. 히트스톱을 끄면 연출은 게임 결과에 영향이 없어야 한다
- 섬광은 광과민 우려가 있어 알파 0.35 이하로 둔다. 끄는 설정은 M8 접근성에서
- 동시 대폭발 3개 + 합체 다수일 때 3D 프레임 시간을 확인한다 (모바일 대비)

### 12-F.2 효과음 반응성 + 합체 판정 지연 (#41)
사용자 수동 플레이 (2026-10-08, 유선 PC 스피커): "효과음 타이밍이 조금 느리다" — **두 구슬이 처음 부딪혀 합칠 때**와 **대폭발**. 연쇄 잠금(0.2초)은 해당 없음.

**Claude 분석**
- 오디오 장치 지연은 작다: 이 PC의 Godot WASAPI 출력 지연 10ms, 믹스 주기 약 9ms (2026-10-08 측정)
- **유력 원인 — 접촉 보고 누락**: `contact_max_reported = 6`. Godot 문서상 `body_entered`는 `max_contacts_reported`가 모든 충돌을 담을 만큼 커야 한다. 빽빽한 판에서 벽·이웃 6곳 이상과 닿은 구체는 새 접촉을 보고받지 못해, 같은 색·같은 레벨이 닿아도 **바로 합체하지 않고** 접촉이 바뀌거나 턴제의 안정 점검(`sweep_resting_contacts`, 최대 1.5초 뒤) 때 합체한다 → 소리가 늦게 들린다. **BLITZ는 안정 점검이 없어** 더 오래 놓칠 수 있다
- 소리 설계: "뽁"은 잡음 클릭 1.5ms가 약하고 피치 하강 음이 주도해 시작이 무르다. 대폭발 "쿵"(70 → 45Hz)은 작은 스피커에서 거의 안 들리고, 들리는 "뽀뽀뽁"이 0~0.28초에 흩어져 타격의 중심이 뒤로 밀린다
- 효과음은 `FeedbackDirector._on_reaction_ready`에서 `call_deferred`로 한 번 미뤄 재생한다

**① 측정 먼저 (계측만, 동작 변경 전)**
- 합체·BLAST 가능한 쌍마다 **기하 접촉 시작**(중심 거리 ≤ 두 반지름 합 + 2px가 처음 된 물리 틱) → **반응 적용 틱** 지연을 잰다. 시드 101~112, TURN 120턴·BLITZ 110초(휴리스틱 0.6초). 보고: 지연 p50/p95/최대(ms), 1틱(8.3ms) 넘은 비율, **판정 경로별 개수**(`body_entered` / 안정 점검 sweep / 잠금 해제 재판정 / 놓친 채 끝남), 지연된 경우 그 구체의 당시 접촉 수, 잠금 중이었는지
- 반응 적용 → `AudioStreamPlayer.play()` 호출까지 지연도 함께 (ms)

**② 고침**
- **접촉 판정이 1틱 안에 일어나게**: 잠기지 않은 반응 가능 쌍은 기하 접촉 시작 후 **1 물리 틱 안에** 반응해야 한다. 방법은 Codex 선택 — 예: `contact_max_reported` 상향(6 → 16 이상), 그리고/또는 매 물리 틱 **(색, 레벨)별로 묶은 근접 검사**(같은 묶음 안의 쌍과 BLITZ BLAST 쌍만 거리 비교 — O(n²) 전체 비교 금지). 근접 판정 거리는 두 반지름 합 + 2px. 결정론 유지 (같은 시드 같은 결과). 비용: 구체 200개에서 판정 p95 < 1ms/틱
- **효과음 즉시 재생**: SFX는 `reaction_ready` 처리 안에서 바로 `play()` (VFX는 지연 그대로 둬도 됨)
- **"뽁" 다시 합성** (시작을 또렷하게): 잡음 클릭 1.5 → **3ms**, 크기 ×1.6, 고역 위주(1차 미분 등 간단한 고역 통과). 음 부분 2,400 → 1,200Hz를 5ms에 하강, 감쇠 시상수 18 → **10ms**, 길이 60 → 45ms. 첫 5ms 안에 최대 진폭
- **대폭발 다시 합성** (앞에 몰기 + 작은 스피커에서 들리게): t = 0에 큰 잡음 "탁" (0~15ms), **중저음 쿵 150Hz → 90Hz** (작은 스피커에서 들림, 어택 < 2ms, 감쇠 120ms) + 기존 초저음 70 → 45Hz에 2·3배음 섞기, 뽀뽀뽁 7개를 **0~100ms**로 압축하고 첫 pop이 가장 크게. 전체 최대 진폭이 **첫 10ms 안**에
- 외부 파일(`assets/sfx/*`)이 있으면 그대로 우선

**③ 재측정·보고**: ①과 같은 표를 고친 뒤 다시 — 지연 p95 ≤ 1틱, 놓친 채 끝남 0이 목표. 합성 파형의 최대 진폭 시점(ms)과 첫 10ms 에너지 비율도 적는다. 물리 결과(벽·쌍 침투, 이탈·발산)·게임 결과가 바뀌면 그 차이를 보고 (근접 판정은 반응 시점을 앞당기므로 점수·길이가 약간 달라질 수 있음)

## 12-U. 화면·접근성 정리 (2026-10-07 — #37~#39, M8·M9 일부)

사용자가 외부에 있는 동안 플레이 판단 없이 진행할 수 있는 항목 (2026-10-07 사용자 선택). 모바일 테스트(M10) 전에 키보드 없이 모든 기능을 쓸 수 있어야 한다.

### 12-U.1 시작 화면·모드 선택·소리 설정 (#37)
- 실행하면 **시작 화면**: 제목 `GRAVITY ORB`(임시 글자), 큰 버튼 2개 **`BLITZ`**(부제 "90초 타임어택")·**`CLASSIC`**(부제 "턴제"), 각 버튼 아래 그 모드의 최고 점수, 소리 켜기/끄기 버튼(🔊/🔇)
- 마지막에 고른 모드를 기억해 강조 (`last_mode` 저장). 소리 상태 `sfx_muted`도 저장하고 M키(TEMP)와 같은 상태를 공유한다 (`SFX` 버스 음소거)
- 버튼을 누르면 그 모드로 게임 시작. 실행 인자 `--mode=turn|blitz`가 있으면 시작 화면을 건너뛴다 (테스트·측정·스모크용). F4 디버그 전환도 유지
- 결과 패널(`GAME OVER`·`TIME UP`)에 **`다시 하기`**(같은 모드 재시작)·**`모드 선택`**(시작 화면으로) 버튼. 게임 중 HUD 한쪽에 작은 소리 버튼
- 모바일 기준: 버튼 높이 ≥ 120px(1080×1920 기준), 터치 동작. 버튼만 `MOUSE_FILTER_STOP`, 나머지 HUD는 스와이프를 막지 않는다 (§13)
- 저장 파일 `user://save.cfg`에 키 추가 — 기존 `best_score`·`blitz_best_score`는 그대로

### 12-U.2 색각 문양 6종 (#38, 기획서 6.3)
- 구체마다 색의 문양을 흰색 반투명(알파 0.55)으로 표시: 빨강 **▲**, 파랑 **●**(안쪽 작은 원), 초록 **■**, 노랑 **◆**, 보라 **★**, 청록 **✚**
- 3D: 구체 앞면(카메라 쪽, z + r)에 문양 사각 메시. 크기 약 0.45 × r. **구체가 굴러도 문양은 똑바로 선 채** 따라간다 (회전 상속 안 함). 문양 텍스처·머티리얼은 6종을 공유 (구체마다 만들지 않음). 대폭발 깜빡임(emission)이 계속 보여야 한다
- 2D: `OrbVisual`이 같은 문양을 다각형으로 그린다 (폰트 의존 없음)
- HUD NEXT/THEN 미리보기에도 문양
- 새 필드 `orb_symbols_enabled` (기본 true) — M8 접근성 설정에서 끄기

### 12-U.3 작은 UI 버그 묶음 (#39)
1. **결과 패널이 비쳐 보임** (2026-10-03 플레이 소감: 뒤 구슬이 비쳐 산만): 패널 배경을 불투명에 가깝게(알파 ≥ 0.92) + 화면 전체 어둡게(검정 알파 0.6). `GAME OVER`·`TIME UP` 공통
2. **시드가 음수로 표시**: `Seed:`가 음수로 나온다 (무작위 시드가 64비트라 부호 있는 정수로 출력됨). 표시는 항상 0 이상이고, **그 값을 `--jolt-seed=`로 넣으면 같은 판이 재현**되어야 한다 (예: 무작위 시드를 1 ~ 2^31−1 범위에서 뽑아 다시 시드로 쓰기). 고정 시드 테스트·측정의 생성 순서는 바뀌면 안 된다
3. **구슬이 벽 밖에 그려짐** (§12-J M8 후보): **렌더링만** 구슬 중심을 보드 안쪽 `half − r`로 제한한다. 물리 위치·게임 로직·측정은 물리 위치 그대로. 3D는 메시(와 문양) 위치만 보정
4. **3D 문양이 한 물리 틱 늦게 따라감** (#38 리뷰): `Orb3D._update_symbol_transform()`이 `_physics_process`에서 바디가 움직이기 **전** 위치로 문양을 옮겨, 화면에서는 문양이 1틱(1/120초) 뒤처진다 — 빠른 L1(대폭발로 900px/s 이상)에서 문양 크기(약 11px)와 비슷한 7~17px 어긋남. 렌더 직전 위치를 따르게 한다 (예: 바디 자식 `RemoteTransform3D`로 위치만 전달·회전/크기 상속 끔, 또는 `_process`에서 갱신). 3번 렌더링 보정과 함께 같은 위치 계산을 쓴다

### 12-U.4 3D 중심 이탈 견고성 (#40)
#38 회신: 같은 프로세스에서 먼저 구체 100개를 만든 테스트가 있으면 Jolt 바디 생성 순서(RID)가 달라져 **시드 101 장기 테스트에서 구체 중심이 보드 밖으로 5프레임 나갔다**. Codex는 테스트 순서를 격리해 통과시켰지만, 실제 게임은 시작 화면·재시작·대폭발 등으로 생성 순서가 판마다 달라진다. 지금까지의 "이탈 0"은 **한 가지 생성 순서**에서만 확인된 셈이다.
- 측정: 실행 전에 더미 물리 바디를 `P`개 만들었다 지워 RID 순서를 흔든다 (`P` = 0, 1, 7, 50, 100). 시드 101~112 × 각 `P`, **독립 프로세스**:
  - TURN 120턴 (현재 기본값)
  - BLITZ 110초, 휴리스틱 0.6초 봇 (6색·목표 밀도·BLAST 900px/s)
- 보고: 조건별 이탈 판 수·이탈 프레임 수·이탈 구체 레벨·바깥 최대 거리·**되돌아왔는지 / 영영 나갔는지**, 이탈 직전 사건(대폭발 밀어내기·합체 결과 생성·스와이프 생성·중력 전환 중 무엇 직후인지), 벽 침투 최대
- 이탈이 있으면 원인 분석과 **대책 후보**(예: 물리 위치가 보드 밖 `r` 이상이면 가장 가까운 안쪽으로 되돌리고 속도 0 — 2D의 escape guard와 같은 안전망, 또는 대폭발 Δv 상한)를 회신하고 `상태: 질문`으로 멈춘다. 대책 구현은 Claude 승인 후
- 이탈이 0이면 결과만 보고하고 완료. 어느 쪽이든 **장기 Jolt 테스트가 다른 테스트의 생성 순서에 영향받지 않게** 격리하는 방법(별도 프로세스 실행 등)을 제안한다
- **#40 결과 (2026-10-08, #41 반영 후 코드)**: `P` 5종 × TURN 120턴·BLITZ 110초 × 12시드 = **120판 모두 중심 이탈 0** (바깥 최대 0px), 벽 최대 23.7px, 쌍 최대 49.9px(10Hz). #38의 이탈은 같은 프로세스에서 **활성 구체 100개**를 먼저 만든 경우였고, 이번 흔들기는 충돌 끈 동결 바디라 조건이 완전히 같지는 않다 → 장기 Jolt 테스트를 별도 프로세스로 격리한다 (#42)

### 12-U.5 화면 배치 정리 + 스크린샷 검수 도구 (#50)
2026-10-08 Claude가 창 모드로 BLITZ(시드 101, 0.55초 자동 스와이프)를 찍어 보니, 헤드리스 테스트로는 안 잡히던 문제가 바로 보였다. M8(#45~#48)을 화면 확인 없이 병합한 결과다.
1. **`DANGER ×n` 배지가 NEXT 미리보기 구슬과 겹친다** (오른쪽 위, 7.5초·13.5초 두 장면 모두) → 배지를 배수 배지 바로 아래 가운데로 옮기는 등 **어떤 HUD 요소와도 겹치지 않게**
2. **예전 `FEVER ×2  n.ns` 라벨이 보드 한가운데에 남아 구슬에 묻혀 안 읽힌다** (#47 띠와 중복) → 예전 라벨 제거, 피버 남은 시간은 #47 띠나 배수 배지 쪽에 작게. 피버 띠·호령·`TIME UP!` 등 **모든 HUD 글자는 3D 보드 위에 또렷하게**
3. **피버 비네트가 보드 바깥 전체를 진한 주황으로 덮는다** → 가장자리 최대 알파 0.255 → **0.12**, 화면 테두리 쪽에만
4. **디버그 글자(Mode·State·Gravity…)가 왼쪽 위를 크게 차지한다** → 디버그 빌드에서도 **기본 숨김**, F1로 켜기 (TEMP — M9 디버그 패널이 대체)
5. **스크린샷 검수 도구**: `tests/spike/capture_screens.gd` + `tests/capture_screens.ps1` — 창 모드·Dummy 오디오·**임시 저장 파일**(사용자 `user://save.cfg`를 건드리지 않음)로 정해진 장면을 PNG로 저장 (`artifacts/screens/`, gitignore). 장면: 시작 화면, TURN 초반·콤보 중·게임오버 패널, BLITZ READY·체인/피버 중·DANGER 표시·`TIME UP!`/결과 패널. 고정 시드·스크립트 스와이프로 매번 같은 장면
- **이후 규칙**: 화면에 보이는 것을 바꾸는 항목은 회신에 이 도구로 찍은 장면 목록을 적고, Claude는 병합 전에 같은 도구로 직접 찍어 확인한다 (AGENTS.md에 반영)

### 12-U.6 피버 띠·막힘 표시·캡처 장면 일관성 (#52)
#50 병합 전 Claude가 `tests/capture_screens.ps1` 9장을 직접 보고 찾은 것 (2026-10-09):
1. **피버 시작 띠가 글자 없는 진한 주황 막대로 보드 한가운데를 가린다** (`06_blitz_fever_chain.png`, 피버 남은 3.0초). #47 띠는 원래 예전 `FEVER` 라벨 뒤에 깔려 있었고, #50에서 라벨을 지우자 빈 띠만 남았다 → 띠 위에 **`FEVER ×2` 글자**(외곽선), 띠 알파 ≤ **0.55**, 높이를 지금의 절반 정도로. 오른쪽에서 0.3초에 들어와 0.5초 머문 뒤 0.3초에 사라짐 — **피버 동안 계속 남지 않는다** (남은 시간은 #50의 `CHAIN · FEVER` 배지가 보여 줌)
2. **턴제 화면 아래 `BLOCKED: NONE`이 빨간 글자로 항상 떠 있다** → 막힌 방향이 없으면 숨김. 막힌 방향이 있을 때만 경고색으로 `BLOCKED: LEFT` (보드 테두리 붉은 표시와 함께)
3. **캡처 장면이 서로 맞지 않는다** — `08_blitz_time_up`의 타이머가 `87.2`, HUD 점수 14,720과 결과 패널 18,760이 다르고, `04_turn_game_over`는 아래 `BLOCKED: NONE`인데 패널은 `BLOCKED: LEFT`. 신호 주입으로 만든 장면도 **한 장면 안의 값이 서로 일치**하게 (TIME UP이면 타이머 0.0, 점수 같음, 막힌 방향 같음). 검수용 장면이 실제와 달라 보이면 리뷰를 그르친다

### 12-U.7 로컬 랭킹 (기획서 0.10.8 — #53)
사용자 요청 (2026-10-09): "랭킹 페이지 만들어줘" → 사용자 선택: **게임 안 로컬 랭킹** (서버 없음, 이 기기 기록만). 온라인 랭킹은 M10 이후 검토.

**저장** (`SaveStore`, `user://save.cfg`)
- 새 섹션 `rankings`, 모드별 키 `blitz` / `turn`에 **최대 10개** 기록 배열. 기록 한 줄:
  - 공통: `score`(int64), `date`(기기 현지 시각 `YYYY-MM-DD HH:MM`)
  - BLITZ: `max_chain`, `blasts`, `fevers` / 턴제: `max_combo`, `turns`, `max_level`
- 정렬: 점수 내림차순, **같은 점수면 먼저 세운 기록이 위** (새 기록은 같은 점수 아래). 11번째부터 버림
- 기존 `records.best_score` / `blitz_best_score`는 그대로 두고 함께 갱신 (BEST = 1위와 같음). **이전 저장 이전(migration)**: `rankings`가 없고 BEST만 있으면 그 점수를 날짜 `-`인 1위 기록으로 넣는다
- 손상된 값·형식이 틀린 항목은 건너뛰고 나머지를 살린다 (기존 손상 저장 규칙과 같게, 오류 없이)

**기록 시점**: 판이 **끝났을 때만** — 턴제 GAME OVER, BLITZ는 피날레가 끝나 결과 패널이 뜰 때. 중간에 R·다시 하기·모드 선택으로 그만둔 판은 넣지 않는다

**화면**
- **랭킹 화면**: 전체 화면 패널. 위에 탭 `BLITZ` / `CLASSIC`(처음엔 마지막에 고른 모드 탭), 표 10줄: `순위 · 점수 · 최대 체인(턴제: 최대 콤보) · 날짜(MM-DD HH:MM)`. 빈 줄은 `—`. 1~3위는 금·은·동 색. **방금 끝난 판의 기록이 들어갔으면 그 줄을 강조**(밝은 테두리 + 살짝 맥동). 아래 `닫기` 버튼 (이전 화면으로)
- **시작 화면**: 모드 버튼 아래에 `랭킹` 버튼 (높이 ≥ 120px)
- **결과 패널**(GAME OVER·TIME UP): 10위 안에 들면 `새 기록! n위` 한 줄(1위면 `최고 기록!`), 버튼 3개 `다시 하기` / `랭킹` / `모드 선택`. `랭킹`은 그 모드 탭을 열고 방금 기록을 강조
- 버튼 외에는 스와이프를 막지 않는다 (§13), 모바일 기준 터치 크기, 한글은 지금처럼 시스템 글꼴 대체 (M10에서 폰트 번들)

**캡처 도구**: `10_ranking_blitz.png`(기록 여러 개 + 방금 기록 강조), `11_result_new_record.png`(결과 패널 `새 기록! n위` + 버튼 3개) 장면 추가 — 임시 저장 파일에 정해진 기록을 넣어 찍고 사용자 저장은 건드리지 않는다
- **#53 추가 요구 1 (2026-10-09 Claude 캡처 검수)**: ① **표 열 정렬** — 머리줄(`순위 점수 최대 체인 날짜`)이 값 줄보다 오른쪽으로 밀려 있고, 빈 줄의 `6 —`은 순위 칸이 아니라 가운데에 놓여 열이 안 맞는다. 순위·점수·체인·날짜를 **고정 너비 열**로 두고 머리줄·기록 줄·빈 줄이 같은 열에 맞게 (빈 줄은 순위 칸에 숫자, 점수 칸에 `—`). 점수는 오른쪽 정렬 ② **선택 표시 통일** — 랭킹 탭은 선택된 탭이 더 어두운 검정이고, 시작 화면은 마지막 모드가 노란 글자로 강조돼 서로 반대로 읽힌다. **선택 = 노란 글자 + 밝은 바탕(또는 아래 밑줄), 선택 안 됨 = 흐린 글자**로 시작 화면 모드 버튼과 랭킹 탭을 같게

## 12-T. 턴제에 끝 만들기 — 생성 증가(ramp) 측정 (#54)
사용자 결정 (2026-10-09): "턴제도 계속 해 보기 위해" #28(보류)을 닫고 생성 증가로 턴제에 끝을 만드는 측정을 새로 한다.
- 배경: 대폭발(L6, #30) 이후 후반 반응 0 턴은 57% → 40%로 줄었지만 **12판 모두 800턴 상한**에 닿아 게임이 끝나지 않는다 (종료 점유율 p50 26%). 대폭발·고레벨 합체가 턴당 1개 유입을 그대로 치운다
- 수단: 기존 필드 `spawn_count_ramp_turns`·`spawn_count_max` (§4, #15) — 턴당 생성 = `min(1 + floor((턴 − 1) ÷ ramp), max)`. NEXT/THEN 미리보기는 턴 번호별 묶음 크기를 이미 지원 (#26)
- 측정 조건 (턴제 현재 기본값 위에서 — 4색, 대폭발 L6, 턴당 1개 시작, 미리보기 2턴):
  | 조건 | ramp | max | 턴당 생성 |
  |---|---|---|---|
  | A | 0 | — | 1개 (현재, 비교 기준) |
  | B | 100 | 2 | 1~100턴 1개, 101턴~ 2개 |
  | C | 100 | 3 | 1~100턴 1개, 101~200턴 2개, 201턴~ 3개 |
  | D | 60 | 3 | 1~60턴 1개, 61~120턴 2개, 121턴~ 3개 |
- 시드 101~112, Jolt 3D 120Hz, 게임오버 또는 **800턴**, 조건별 독립 프로세스 (`--fixed-fps 120`)
- 보고: 게임오버/800턴 도달 수, **게임 길이 p50·범위**, 종료 점유율, 점수, 최대 콤보, 대폭발 수·첫 대폭발 턴, **턴 구간별(1~100 / 101~200 / 201~300 / 301~끝) 턴당 반응·반응 0 턴 비율**, 마지막 50턴, 입구 대기로 막힌 턴 수, wall/pair·이탈·발산
- 판단 기준 (Claude): **모든 판이 게임오버로 끝나고** 길이 p50 **250~400턴**, 후반(201턴~) 반응 0 턴 비율 ≤ 45%, 물리 한도 안. 기본값은 바꾸지 않고 `상태: 질문` — 채택은 사용자 결정
- **#54 결과 (PR #55)**: A 1/12만 끝남(p50 800턴) / **B(100/2)** 12/12, 261턴(201~445), 후반 반응 0 31% / **C(100/3)** 12/12, **241턴(223~296)**, 후반 반응 0 **19%** / D(60/3) 180턴. 물리 모두 한도 안. B만 기준 4개 통과, C는 길이가 목표에 9턴 모자라지만 후반이 가장 활발하고 길이가 일정
- **결정 (2026-10-09 사용자): C 채택** — `spawn_count_ramp_turns` 0 → 100, `spawn_count_max` 3 유지 (#55)
- **변경 (2026-10-10 사용자): 50턴마다 +1개, 상한 없음** (#56) — 측정 D(60/최대 3)가 약 180턴이었으므로 더 짧아질 것으로 예상(150턴 안팎). #56에서 길이를 다시 잰다

## 12-P. M8 연출 2차 — 점수 읽기·색 효과·호령·중력 손맛 (기획서 0.10.6 — #45~#48)

사용자 선택 (2026-10-08): 네 묶음 모두. **공통 원칙**
- 화면·소리·진동만 바꾼다. 게임 상태·점수·물리는 그대로 — 각 항목에서 **연출 켬/끔 상태 해시 동일**(턴제 20턴·BLITZ 20초, 히트스톱 끔)을 테스트로 확인
- 연출용 노드는 풀(pool)로 재사용하고 끝나면 정리한다 (1.5초 안). 모바일(M10) 대비 프레임 부담을 회신에 적는다 (헤드리스 + 가능하면 창 모드)
- 난수가 필요하면 `stable_spawn_id` 해시 등 결정적 값 (난수 호출은 `Spawner.gd`만 규칙 유지)
- 각 묶음 켜고 끄는 `fx_*` 설정 필드 (M8 접근성 설정 화면에서 쓸 것)

### 12-P.1 점수 팝업 + 배수 크게 (#45)
- **점수 팝업**: 점수가 붙은 반응마다 반응 지점(3D → 화면 좌표 `Camera3D.unproject_position`)에 `+640`. 글자 34px × `clamp(1 + 0.25 × log10(점수 ÷ 10), 1, 2.4)`. 색: 합체 = 결과 구슬 색(밝게), 대폭발·잭팟 = 흰색 + 금색 테두리, 피날레 = 금색. 0.12초 동안 0.6 → 1.1 → 1.0으로 튀어나와 0.7초 동안 60px 떠오르고 마지막 0.25초에 사라짐. 1,000점 이상은 0.2초 더 머물고 살짝 흔들림
  - 콤보 배수 ×4 이상이거나 위험 배수 ×2 이상이면 팝업 아래 작은 줄로 **계산식** `640 ×8 ×4` — 점수가 왜 큰지 읽히게 (기획서 5.2)
  - 동시 표시 최대 16개 (넘으면 가장 오래된 것 제거). 같은 프레임에 40px 안의 반응은 합쳐서 하나로
- **배수 배지**: 지금의 `COMBO n (xM)` 줄을 화면 위 가운데 큰 배지로 — 큰 글자 `×8` + 아래 작은 글자 `COMBO 4`(턴제) / `CHAIN 6`(BLITZ). 오를 때마다 0.15초 1.0 → 1.35 → 1.0 펀치. 색 단계: ×1 흰색, ×2~3 노랑, ×4~7 주황, ×8 이상 빨강 + 은은한 맥동
- **DANGER 배지**: 배수 배지 옆 `DANGER ×4` (빨강). 반응이 있을 때만이 아니라 **점유율이 `danger_start` 이상인 동안 계속** 보인다 (판 점유율을 0.25초마다 다시 계산 — 표시용). 위험 배수가 클수록 빨리 맥동
- **점수 숫자**: SCORE가 0.25초 동안 굴러 올라가고, 큰 득점(≥ 1,000) 때 펀치
- 필드: `fx_score_popups_enabled`, `fx_popup_max` 16

### 12-P.2 색별 합체 효과 시각화 (#46, 기획서 6.2 "정식 연출은 M8")
색 효과(§7.6)가 **눈으로도 다르게** 보이게. MERGE·MAX_CLEAR에서 `color_effects_enabled`이고 효과 모드에 따라 (반경 `R`·세기 계수는 §7.6과 같은 값, 레벨이 클수록 크게):
| 모드 | 색 | 연출 |
|---|---|---|
| PUSH | 빨강 (×1.5), 보라·청록 (기본) | 결과 색 고리가 `r_result` → `R`로 0.3초 퍼짐 + 바깥으로 뻗는 짧은 선 6개. 빨강은 두껍고 밝게, 보라·청록은 얇게 |
| PULL | 파랑 | 고리가 `R` → `r_result`로 0.3초 **수축** + 안쪽으로 빨려 드는 점 입자, 결과 구슬이 순간 작아졌다가 펀치 |
| SHAKE | 초록 | **보드 프레임**이 0.25초 떨림(6px, 카메라 아님) + 판 끝까지 퍼지는 옅은 초록 물결 1겹 (0.4초) |
| LIFT | 노랑 | `R` 안 구슬 위치에서 **중력 반대 방향**으로 솟는 노란 빛줄기·입자 (0.35초) |
- 대폭발(BLAST) 연출(§12-F)과 겹치지 않게 BLAST에는 쓰지 않는다. 잭팟(MAX_CLEAR)은 대폭발 연출 + 그 색 모드 연출을 ×1.5
- 필드: `fx_color_effect_visuals_enabled`

### 12-P.3 콤보 호령 + 피버·타이머 강화 (#47)
- **호령**: 턴제 콤보 3·5·8·12 / BLITZ 체인 5·10·15·20·30에서 화면 가운데 큰 글자 `NICE!` `GREAT!` `AMAZING!` `INCREDIBLE!` (`UNSTOPPABLE!` = BLITZ 30). 0.12초 튀어나와 0.8초 뒤 사라짐. 한 턴(턴제) / 한 체인(BLITZ) 안에서 같은 단계는 한 번만. 합성 **차임**(장3화음 아르페지오, 단계마다 높게)
- **피버**: 시작 시 `FEVER ×2` 띠가 오른쪽에서 가운데로 0.3초에 날아들고, 화면 가장자리 주황 비네트가 2Hz로 맥동, 배경이 살짝 따뜻하게. 합성 **상승 스윕**(0.4초). 끝날 때 비네트 0.3초 페이드 + 하강 스윕
- **BLITZ 타이머**: 남은 10초부터 1초마다 타이머 펀치 + 합성 **똑딱**(짧은 우드블록), 3초부터 더 크고 높게. 시간 종료 시 버저 + 큰 `TIME UP!` 뒤 피날레
- **시간 보너스**: `+1s`가 대폭발 지점에서 타이머로 0.5초에 날아가 닿을 때 타이머가 초록으로 번쩍
- 새 소리는 §12-F처럼 코드 합성 (`SfxBank`, 외부 파일 우선 규칙 같음), `SFX` 버스·음소거 공유
- 필드: `fx_callouts_enabled`, 호령 단계 표는 상수

### 12-P.4 중력 전환 손맛 강화 (#48)
- **보드 기울기**: 4° → **6°**, 0.25 → **0.3초**, 되돌아올 때 살짝 넘어갔다 오는 탄성(back-out). 연속 스와이프 때는 이전 트윈을 이어받아 끊김 없이
- **스와이프 잔상**: 받아들여진 스와이프마다 판을 가로지르는 반투명 화살 줄기 (스와이프 방향, 0.2초)
- **"휙" 소리**: 합성 필터 잡음 스윕 120ms (SfxBank)
- **늘어남(squash & stretch)**: 속도 900px/s 이상인 구슬은 **메시만** 속도 방향으로 최대 1.15배 늘이고 수직으로 0.92배 (충돌·물리 불변, 문양은 그대로)
  - #49 보정: 문턱에서 켜졌다 꺼지면 900px/s 근처를 오가는 구슬이 깜빡이듯 모양이 바뀐다 → 속도 **700 → 1,100px/s 구간에서 smoothstep으로 0 → 1** 보간한 비율 `t`로 `1 + 0.15t` / `1 − 0.08t`. 메시 방향도 `t > 0`일 때만 속도 방향으로 정렬하고, 그 외에는 기존 바디 회전
- **진동(모바일 대비)**: `Haptics.gd`(Input 사용 허용 파일)에서 스와이프 8ms, 대폭발 25ms. PC에서는 아무것도 안 함. 필드 `haptics_enabled`
- 필드: `fx_tilt_degrees` 6, `fx_tilt_duration` 0.3, `fx_swipe_trail_enabled`, `fx_orb_stretch_enabled`

## 13. 알려진 함정 (Godot 4)

| 함정 | 대응 |
|---|---|
| `Orb.tscn`의 `CircleShape2D`가 인스턴스 간 공유되어 반지름을 바꾸면 모든 구체가 같이 변함 | `setup()`에서 `CircleShape2D.new()` |
| RigidBody2D·CollisionShape2D 스케일 변경은 물리가 무시하거나 깨짐 | 크기 연출은 `Visual` 노드만 |
| `body_entered` 안에서 `add_child`/`queue_free` → "Can't change this state while flushing queries" | 기록 후 `flush()`에서 처리 (7장) |
| 잠든 바디가 새 힘에 반응하지 않음 | `can_sleep = false` |
| 빠른 구체가 벽을 뚫음 | 두꺼운 벽 + `CCD_MODE_CAST_SHAPE` |
| `emulate_touch_from_mouse`로 마우스·터치 이벤트 이중 입력 | 제스처 source 고정 (5.5) |
| `contact_monitor` 꺼짐 또는 `max_contacts_reported = 0`이면 `body_entered` 미발생 | 둘 다 설정 |
| `PhysicsDirectSpaceState2D` 쿼리를 물리 프레임 밖에서 호출하면 실패 | 공간 쿼리는 `_physics_process` 흐름에서만 |
| `preload`한 리소스는 캐시 공유 → 런타임 수정이 원본 참조 전체에 퍼짐 | `Config`에서 `duplicate(true)` 한 번, 모두 `Config.data` 참조 |
| 고속 구체가 다른 구체에 밀려 벽 안으로 수십 px 파고듦 (60Hz 최대 53px, 시드 1047에서 중심 이탈) | 240 tick/s + `contact_max_allowed_penetration = 0.1` (방향당 2초·22시드 기준 최대 8.6px). solver 반복 증가·120Hz·`default_contact_bias` 상향은 효과 없음. M10에서 모바일 비용 재평가 |
| `Engine.time_scale` 복구 누락 | 히트스톱 종료 타이머 + `_exit_tree`에서 1.0 복구 |
| 전역 난수 사용 시 시드 재현 불가 | 5.9의 RNG만. 리뷰 시 `grep -rn "randf\|randi\|shuffle\|pick_random" scripts` |
