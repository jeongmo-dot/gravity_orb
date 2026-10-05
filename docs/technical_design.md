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
| #15 | `spawn_count_ramp_turns` / `spawn_count_max` | int | 0 (비활성) / 3 | 점진 증가 (측정용, 기본 비활성) |
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
# 단위·시나리오 테스트 (실패 시 종료 코드 1)
godot --headless --path . -s res://tests/run_tests.gd
# 메인 씬 스모크: 300프레임 실행 후 종료, 출력에 SCRIPT ERROR가 없어야 함
godot --headless --path . --quit-after 300
```

`godot` 실행 파일 경로는 환경마다 다르다. `GODOT` 환경변수가 있으면 그것을 쓴다.

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
