# 기술 설계서 — 「그래비티 오브」 프로토타입

> 버전 1.0 · 2026-09-28
> 입력 문서: [`reference/gravity_orb_design.md`](reference/gravity_orb_design.md) (기획서 v0.1), [`reference/gravity_orb_roadmap.md`](reference/gravity_orb_roadmap.md) (구현 로드맵)
> 대상 독자: 구현 에이전트(Codex) 및 리뷰어

이 문서는 기획서와 로드맵을 **구현 가능한 수준의 구조·API·수치·알고리즘**으로 구체화한다.
기획서가 "무엇을", 로드맵이 "어떤 순서로"를 정한다면, 이 문서는 "어떻게"를 정한다.

- 문서 간 충돌 시 우선순위: **기획서 > 이 문서 > 로드맵**. 단, 11장 "설계 해석"은 기획서의 빈칸을 채운 결정이므로 기획서가 갱신되기 전까지 이 문서를 따른다.
- 모든 수치는 가안이며 `GameConfig`로 조정 가능해야 한다.
- **2026-10-25부터 JELLY 단일 앱** (§12-ONE). CLASSIC·BLITZ·SLIME 관련 절은 레거시 기록 — 네 모드 버전은 태그 `legacy-four-modes`

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
| 엔진 | **Godot 4.8 일반 빌드** (현재 `4.8.dev3.official`, 로컬 `C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`, 4.8 정식판 출시 시 교체). C#은 쓰지 않는다 — 2026-10-11 .NET 빌드(`4.8.dev3.mono`)에서 일반 빌드로 바꿨다 (Codex가 창을 띄우는 실행에서 .NET 폴더 확인 경고 창이 사용자 화면에 떴다). 네트워크 랭킹 등도 GDScript(`HTTPRequest`·`WebSocketPeer`)로 충분하고, C#이 필요해지면 그때 .NET 빌드로 바꿀 수 있다. 예전 mono 에디터가 남긴 `[dotnet]` 섹션은 그대로 둔다 (일반 빌드는 무시) |
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
| #38 | `orb_symbols_enabled` | bool | true → **false** (#66, 2026-10-11 사용자: 구슬 안 문양 삭제) | 색각 문양 표시 (§12-U.2). 기능은 남겨 두고 나중에 설정(접근성)에서 켤 수 있게 |
| #62 | `blast_min_level` / `blitz_blast_min_level` / `blitz_time_bonus_blast` | int / int / float | 6 → **4** / **삭제** (두 모드 `blast_min_level` 하나) / **삭제** (`blitz_time_bonus_blast_by_level`로) | **두 모드 모두 대폭발 L4, 기준은 항상 같다** (기획서 0.10.15, 2026-10-11 사용자 결정, §12-B.10) |
| #62 | `blast_push_radius_by_level` / `blitz_time_bonus_blast_by_level` | PackedFloat32Array | **[0, 0, 0, 0.3, 0.55, 1.0, 1.0]** / **[0, 0, 0, 0.5, 1.0, 2.0, 3.0]** | 클수록 큰 대폭발: 밀어내는 반경(`board_size` 비율, 1.0 이상 = 판 전체) / BLITZ 대폭발 시간 (§7.7, §12-B.10) |
| #36 | `blitz_min_spawn_per_swipe` / `blitz_max_spawn_per_swipe` | int | **1 / 8** | BLITZ 스와이프당 생성 = 없어진 만큼 (§12-B.5) |
| #35 | `fx_*`, `sfx_*` | | §12-F 표 | 대폭발 VFX·뽁뽁이 사운드 (§12-F) |
| #34 | `blitz_spawn_color_weights` | PackedFloat32Array | **[1, 1, 1, 1, 1, 1]** | BLITZ 생성 색 확률 (§12-B.4). 턴제 `spawn_color_weights`도 #74부터 같은 6색 (§12-W) |
| #33 | `blitz_spawn_on_swipe` | bool | **true** | BLITZ에서 스와이프마다 생성 (§12-B.3) |
| #31 | `game_mode`, `blitz_*` | | §12-B 표 | 타임어택 모드 스파이크 (§12-B) |
| #29 | `blast_enabled` 외 5개 | | §7.7 표 | 대폭발 BLAST (§7.7) |
| #25 | `color_effects_enabled` 외 5개 | | §7.6 표 | 색별 합체 효과 (§7.6) |
| #23 | `chain_reaction_delay` | float | 0.2 (가안, 플레이 체감으로 조정) | 합체 결과의 반응 잠금 시간 (초, §7.5) |
| #21 | `combo_multiplier_base` | float | 2.0 | 콤보 배수 밑 (§8.2) |
| #62 | `combo_multiplier_max` | float | **128.0** | 턴제 콤보 배수 상한 — `min(base^(combo − 1), max)`, 콤보 8부터 ×128 고정 (§8.2, 2026-10-11 사용자). BLITZ 체인 배수(최대 ×5)와 무관 |
| #21 | `danger_start` / `danger_doubling` | float | 0.30 / 0.20 | 위험 배수 시작 점유율 / 2배가 되는 점유율 간격 (§8.2) |
| #21 | `gravity_level_scale` | float | 0.1 (#21: L7 낙하 0.65초 vs L1 1.04초) → 0.25 (#60, 기획서 0.10.13: 레벨 하나마다 +25%, L7 = L1 × 2.5) → **0.05** (#115, 2026-10-29 사용자 "차이 줄이기": L7 = L1 × 1.3 — §12-ONE.8) | 레벨별 중력 배율 = 1 + 값 × (레벨 − 1). 큰 구체가 더 빨리 떨어진다 (기획서 0.8) |
| #118 | `gravity_turn_diagonal_time` | float | **0.15** (#118, 2026-10-30 사용자 "8방향으로 늘려서 좌에서 하로 갈 때와 우에서 하로 갈 때가 다른 중력 변화 과정을" — §12-ONE.11) | 90° 꺾을 때 처음 이 시간 (초, 물리 프레임으로 셈) 동안 두 방향 사이 대각선으로 당긴다. 같은·반대 방향은 곧장. 0이면 끈다. JELLY (`Board3D`)만 |
| #120 | `jelly_blast_min_level` | int | 0 (#98) → 5 (#96, J5 — §12-JE.5) → 7 (#120 1차, 2026-10-31 사용자 "폭발이 L7 이었으면 L7과 L7이 만났을 때만 폭발" — 대폭발 0번이라 병합 안 함) → **6** (#120 추가 요구 1, 사용자 "L6부터로 다시 재기" → 5·6·7을 본 뒤 "L6부터로 병합" — §12-ONE.13) | JELLY 대폭발 기준 레벨: 다른 색·같은 레벨 둘 다 이 레벨 이상이면 닿을 때 대폭발. 7이면 다른 색 L7+L7만. 터질 듯한 얼굴도 이 레벨부터 (L7은 MAX 얼굴). 0이면 끈다 |
| #14 | `mass_exponent` | float | **1.0** (#14 측정: 지수 2는 L1 관통 14.8px, 1은 8.2px) | 질량 = base × (r / r_L1)^지수. **#21에서 2로 확정** (L7이 L1에 밀리는 거리 47 → 12px) |
| M1 | `orb_max_level` | int | 7 | |
| M1 | `orb_base_mass` | float | 1.0 | L1 질량 |
| M1 | `gravity_strength` | float | 2400.0 → 1800.0 (#17: 고밀도 40%+ 사전 복구 910 → 13, 발산 0, 2D 시절) → 3600.0 (#58, 두 모드 모두 2배) → 1800.0 (#60, 2026-10-10 사용자: 되돌리고 대신 레벨 차이를 크게 — §12-B.8) → **3600.0** (#115, 2026-10-29 사용자 "너무 느려요" — §12-ONE.8) | **L1** 중력 가속도 (px/s²). 레벨 L은 × (1 + `gravity_level_scale` × (L − 1)) |
| M1 | `orb_friction` | float | 0.3 → 0.6 (#115, "구르지 않고 착 붙기" — §12-ONE.8) → **0.3** (#116, 2026-10-30 사용자 "마찰 낮추기" — §12-ONE.9) | #115~#116은 젤리 몸 회전 잠금 (`axis_lock_angular_z`). #117에서 잠금을 풀고, 대신 `orb_angular_damp`로 구르는 것을 금방 멈춘다 |
| M1 | `orb_bounce` | float | 0.15 → **0.06** (#115, "살짝만 통" — §12-ONE.8) | Godot은 두 물체의 튕김을 더한다. 젤리끼리 0.12 |
| M1 | `wall_friction` | float | 0.3 → 0.6 (#115) → **0.3** (#116) | 젤리 값과 같게 둬서 섞는 규칙과 상관없이 0.6 |
| M1 | `wall_bounce` | float | 0.1 → **0.06** (#115) | 젤리-벽 0.12 |
| M1 | `orb_linear_damp` | float | 0.1 | |
| M1 | `orb_angular_damp` | float | 1.0 → **15.0** (#117, 2026-10-30 사용자 "다시 구르게, 금방 멈추게" — §12-ONE.10) | 구르는 공의 속도는 1초에 약 (2/7) × (값 + Godot 기본 0.1)의 비율로 준다 |
| M1 | `color_display` | PackedColorArray | 빨 `#E5484D`, 파 `#3E7BFA`, 초 `#30A46C`, **노 `#F5C542`** (#15) → **행성색** (#75, §12-W: 화성·지구·천왕성·금성·해왕성·수성) | 인덱스 = `OrbTypes.OrbColor` |
| M1 | `debug_test_orb_count` | int | 5 | M1 전용. M4에서 삭제 |
| M2 | `swipe_min_distance` | float | 80.0 | 스와이프 최소 이동 거리 (기준 해상도 px) |
| M2 | `swipe_dominance_ratio` | float | 1.5 | 주 방향 성분 ≥ 보조 성분 × 이 값 |
| M3 | `stable_linear_speed` | float | 12.0 → #8에서 30.0 | 안정 판정 선속도 임계값 (px/s) |
| M3 | `stable_angular_speed` | float | 1.0 → #8에서 3.0 | 안정 판정 각속도 임계값 (rad/s) |
| M3 | `stable_duration` | float | 0.33 | 임계값 이하가 연속 유지되어야 하는 시간 (초, 스케일된 시간). 물리 틱 수와 무관하게 초 단위로 정한다 |
| M3 | `max_settle_time` | float | 3.0 → **1.5** (기획서 0.3) | 턴 최대 길이 (초, 스케일된 시간). 도달하면 움직임이 남아도 턴 종료 — 정상 동작 |
| M3 | `allow_same_direction_swipe` | bool | true → **false** (#124, 2026-10-31 사용자 "이전에 입력한 방향을 그대로 유지는 못하게" — §12-ONE.17) | 11.1 참조. false면 지금 중력 방향으로 밀면 무시 (첫 턴은 아래가 막힘) |
| M4 | `spawn_level_weights` | PackedFloat32Array | [0.9, 0.1] | 인덱스 0 = 레벨1 |
| #91 | `turn_start_colors` / `turn_color_unlock_turns` | int / Array[int] | 6 / [] (#91) → **4 / [30, 60]** (#92, §12-R.1 — 적용 `3ea4f0b`) | 턴제 시작 색 수와 색이 하나씩 열리는 턴. 색 순서는 색 번호 순 (화성·지구·천왕성·금성 → 해왕성 → 수성). 해금 턴 묶음 첫 구슬은 새 색 |
| M4 | `spawn_color_weights` | PackedFloat32Array | [1, 1, 1] → [1, 1, 1, 1] (#15) → **[1, 1, 1, 1, 1, 1]** (#74, 두 모드 같은 6색 §12-W.1) | 인덱스 = 색. 가중치 0인 색은 생성되지 않는다 |
| #15 | `spawn_count_per_turn` | int | 2 (기획서 0.6) → **1 (#26, 기획서 0.9.4: 상극 폐지 후 게임 길이 258 → 136턴)** | 턴당 생성 구체 수 |
| #26 | `preview_turns` | int | **2** | 미리보기로 보여 줄 앞으로의 턴 수 (§11.10) |
| #15 | `spawn_count_ramp_turns` / `spawn_count_max` | int | 0 → 100 (#55) → 50 (#56, 기획서 0.10.10) → 20 (#62, 판 길이 약 250턴 목표 — p50 240턴, §12-B.10) → 40 (#74, 6색에서 p50 266턴, §12-W.1) → 50 (#92, 단계별 난도 C2 §12-R.1 — 적용 `3ea4f0b`) → 5 (#119, 2026-10-30 사용자 "첫번째 1개씩 5턴 그 다음부터 매 5턴 마다 공 한개씩 추가" — §12-ONE.12) → **10** (#123, 2026-10-31 사용자 "5턴이 아니라 10턴 단위로" — §12-ONE.16) / 3 → **0 = 상한 없음** (#56) | 턴제 점진 증가: **10턴마다 +1개, 상한 없음** (1~10턴 1개, 11~20턴 2개, 21~30턴 3개 …, #123. #92~#118은 50턴마다, #119~#122는 5턴마다). `spawn_count_max ≤ 0`이면 상한 없음. BLITZ는 쓰지 않음 |
| M4 | `spawn_position_mode` | SpawnPositionMode | RANDOM | |
| M4 | `spawn_margin` | float | 4.0 | 생성 벽 안쪽 면과 구체 사이 여백 |
| M4 | `rng_seed` | int | 0 | 0이면 시작 시 무작위 시드를 뽑아 기록 |
| M4 | `initial_orb_count` | int | 2 | #119부터 시작 배치에 쓰지 않는다. 시작 색마다 L1 하나씩 바닥에 놓는다 (§12-ONE.12) |
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

> GRAVITY SLIME 모드 (§12-G)의 수치는 `GameConfig`가 아니라 `SlimeConfig` (`config/slime_config.tres`)에 둔다 — 값 표는 §12-G.2

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
> #74 (기획서 0.12): 색 = 행성으로 바뀌며 효과를 다시 배치했다 — 화성(빨강) 밀어내기 강, 지구(파랑) 흔들기, 천왕성(초록) 기본 밀어내기, 금성(노랑) 띄우기, 해왕성(보라) 끌어당기기, 수성(청록 자리) 기본 밀어내기. 아래 표의 식은 그대로, 색 배치만 §12-W.1
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
레벨 `blast_min_level`(6, #30에서 5 → 6 → **#62에서 4**, 두 모드 통일 §12-B.10) 이상 구체는 **폭발 가능 상태**다. **같은 레벨·다른 색**의 폭발 가능 구체 둘이 닿으면 둘 다 사라지고 주변을 밀어낸다 — **레벨이 클수록 넓게** (#62: L4 주변, L5 판 절반, L6·L7 판 전체. 그 전에는 모두 판 전체). 두 모드의 기준은 같다. 레벨이 다르면(L5–L6 등) 반응하지 않는다 (2026-10-05 사용자 결정: L5–L6 폭발 제외).

- **판정 순서** (`ReactionRules.classify`): ① 같은 색·같은 레벨 → MERGE / MAX_CLEAR (기존, 성장 우선) ② 상극 → ANNIHILATE (현재 비활성) ③ `blast_enabled`이고 **두 레벨이 같고** `≥ blast_min_level` → **BLAST** ④ 그 외 NONE. 같은 색·같은 레벨은 ①에서 먼저 걸리므로 BLAST는 **같은 레벨·다른 색**만이다: L6–L6, L7–L7 (L7 같은 색은 MAX_CLEAR. #29 때는 L5–L5 포함). 레벨이 다른 쌍은 색과 무관하게 NONE
- **결과**: 두 구체 제거, 생성 없음. 지점 `p` = 두 중심의 중점
- **밀어내기**: 판 위 **모든** 일반 구체(유령·입구 대기 제외)에 **질량 무관 속도 변화** `Δv = blast_speed × lerp(1.0, blast_far_factor, clamp(d / board_size, 0, 1))`, 방향 `(q − p).normalized()` (`d ≈ 0`이면 `Vector2.RIGHT`). 큰 구체도 같이 날아가 굳은 더미가 풀린다. 색별 효과(§7.6)·충격파(§7.4)는 BLAST에 적용하지 않는다
  - **#62 레벨별 범위**: `f = blast_push_radius_by_level[L]`. `f ≥ 1.0`이면 위 식 그대로 판 전체. `f < 1.0`이면 반경 `R = f × board_size` 안의 구체만 `Δv = blast_speed × lerp(1.0, blast_far_factor, clamp(d / R, 0, 1))`, 밖은 0. 가안 L4 0.3 · L5 0.55 · L6·L7 1.0. 충격파 고리 연출의 최대 반경도 이 범위에 맞춘다
- **점수**: 기본 점수 = `(score_for_level(La) + score_for_level(Lb)) × blast_score_factor` (L6+L6 = 640, L7+L7 = 1,280. `blast_min_level = 5`였던 #29에서는 L5+L5 = 320). 콤보·위험 배수는 §8.2 그대로. 콤보 +1
- **잠금(§7.5)**: 합체로 막 생긴 L5·L6은 잠금 동안 BLAST도 보류된다 (기존 잠금 규칙 그대로). 결과 구체가 없으므로 BLAST 자체는 잠금을 만들지 않는다
- **폭발 가능 표시**: 레벨 `≥ blast_min_level` 구체는 발광을 주기 `blast_blink_period`로 깜빡인다 (3D: 머티리얼 emission, 2D: 밝기). 상태 변화는 레벨로만 결정 — 별도 타이머 없음
- **임시 연출**: 폭발 지점 흰 섬광 고리 1회 + 보드 프레임 짧은 떨림. 정식 연출(화면 흔들림·파편·사운드)은 M8
- 반응 딕셔너리 `type = BLAST`, `levels`, `colors`, `position`, 점수 필드(§8.2). HUD·점수·콤보는 기존 경로로 처리
- 새 필드 (가안, #29 측정 후 확정):

| 필드 | 타입 | 가안 |
|---|---|---|
| `blast_enabled` | bool | true |
| `blast_min_level` | int | 5 → 6 (#30. #29 측정: 5에서는 12판 모두 800턴, 종료 점유율 17% — L5 쌍 하나가 L1 32개 면적을 치워 들어오는 양과 균형) → **4** (#62, 2026-10-11 사용자: 두 모드 L4 통일. 그 사이 생성 램프가 들어와 판은 끝난다 — 길이는 §12-B.10 측정) |
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

- **콤보 배수** = `combo_multiplier_base ^ (combo − 1)` (기본 2.0). `combo`는 §8.1 턴 콤보. **#62: 상한 `combo_multiplier_max` ×128** — `min(base^(combo − 1), 128)`, 콤보 8부터 고정 (대폭발 L4로 한 판 최대 콤보가 14~24가 되어 점수가 수백만~수억으로 폭주, 2026-10-11 사용자 결정)
- **위험 배수** = 점유율 p(반응 직전, 최종 반지름 기준 Σπr² ÷ 보드²)가 `danger_start`(0.30) 미만이면 1, 이상이면 `2 ^ ((p − danger_start) ÷ danger_doubling)` (`danger_doubling` 0.20)
- 점수·최고 점수는 **int64**. 배수는 float으로 계산 후 마지막에 버림
- 반응 딕셔너리에 `base_points`, `combo_multiplier`, `danger_multiplier`, `points`를 담아 HUD·연출(M8)이 그대로 보여줄 수 있게 한다

예: 같은 턴 1번째 L2 합체(4점, 점유율 20%) = 4 / 2번째 L3 합체(8점) = 16 / 3번째 L7 청소(640점, 점유율 70% → ×4) = 640 × 4 × 4 = 10,240

---

## 9. 저장 데이터

| 파일 | 형식 | 내용 |
|---|---|---|
| `user://save.cfg` | `ConfigFile` | `[records] best_score` (M7), `[settings] vibration` (M10) |
| `user://save.cfg` (GRAVITY SLIME, #81) | `ConfigFile` | 랭킹 `slime` TOP 10 (`score`·`date`·`turns`·`max_chain`·`max_colors`), 최고 점수·최고 턴·최고 연쇄, 마지막 모드 `"slime"` (§12-G.8) |
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

- **권장: 래퍼 한 번** `.\tests\run_tests.ps1` — 일반·장기·성능(`--test-suite=perf`, 200구체 근접 검사 예열 후 **5회 중 최선 p95 ≤ 1.5ms** — #65, 회귀 감지용) 세 묶음을 각각 새 프로세스로, 기본 `--fixed-fps 120` (약 40초). `-FixedFps 0`이면 실시간. 하나라도 실패하면 종료 코드 1
- PowerShell 5.1에서 래퍼 출력을 `*>`·`2>&1 | Tee-Object`로 받아도 끝까지 돈다 (#44, `8d24b68`). Godot 경고는 로그에 `NativeCommandError`로 남지만 판정은 각 프로세스 종료 코드로만 한다
- 인자 없는 `-s res://tests/run_tests.gd`는 호환용(한 프로세스, 장기 → 일반 순서)으로 남아 있다

`godot` 실행 파일 경로는 환경마다 다르다. `GODOT` 환경변수가 있으면 그것을 쓴다.

> #42 (PR #43, `563ccbe`): 장기 Jolt 테스트(2D 22시드 중력 순환, 3D 22시드·20턴·시드 101 120턴) 4개를 `--test-suite=long`으로 분리했다 — 앞선 테스트가 만든 물리 바디가 Jolt 생성 순서를 바꿔 결과를 흔들 수 있기 때문 (#38). 위 명령처럼 일반·장기를 각각 새 프로세스로 돌린다
>
> #65 (PR #67, `c7ef7d2`): 2D 120턴 턴 시간 검사(`test_all_turns_return_to_input_within_time_cap`)도 같은 이유로 장기 묶음으로 옮겼다 — 일반 묶음에서는 벽 복구가 0·1·4로 흔들려 한도 2를 가끔 넘었다. 장기 묶음에서는 3회 모두 1. 성능 묶음·창 모드 측정은 다른 Godot 프로세스와 동시에 돌리지 않는다

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

### 10.5 Windows 빌드 (#68)
사용자 (2026-10-11): 테스트용 Windows 빌드 → 정식 빌드 (내보내기 템플릿 + 내보내기 설정)
- **내보내기 템플릿**: Godot 4.8-dev3 공식 파일 (`godotengine/godot-builds` 릴리스의 `Godot_v4.8-dev3_export_templates.tpz`, SHA512 확인) 중 Windows 템플릿만 `%APPDATA%\Godot\export_templates\4.8.dev3\`에 설치 (Claude, 2026-10-11). 다른 PC에서 빌드하려면 같은 파일을 받아 같은 곳에 둔다
- **`export_presets.cfg`** (저장소에 커밋): 프리셋 이름 `Windows Desktop`, x86_64, PCK를 exe 안에 넣는다 (파일 하나). 콘솔 래퍼는 디버그·릴리스 모두 (`GravityOrb.console.exe`, 테스트 로그용). 제외: `tests/*`, `artifacts/*`, `docs/*`, `build/*`, `*.md`. 제품 이름 `Gravity Orb`, 파일 버전 `0.11.0` (기획서 버전). 아이콘은 V5에서 (지금은 기본)
- **빌드 스크립트** `tools/build_windows.ps1`: `GODOT` 환경변수 또는 일반 빌드 기본 경로로 `--headless --export-release "Windows Desktop" build/windows/GravityOrb.exe`. 템플릿이 없으면 설치 경로를 알려 주는 메시지로 멈춘다. `-Debug`는 `--export-debug`로 `build/windows-debug/`. 빌드 뒤 `BUILD.txt`에 커밋 해시·날짜·엔진 버전. 출력 폴더 `build/`는 이미 `.gitignore`에 있다
- **저장 위치**: 내보낸 게임도 편집기 실행과 같은 `%APPDATA%\Godot\app_userdata\Gravity Orb\save.cfg`를 쓴다 (기록·설정 공유). 빌드 검증은 이 파일을 바꾸면 안 된다
- **검증**: 빌드 스크립트 종료 코드 0과 exe 크기. 내보낸 exe (콘솔 래퍼)로 스모크 3종 (`--headless --quit-after 300`, `-- --mode=turn`, `-- --mode=blitz`) 종료 코드 0·`SCRIPT ERROR` 0. 검증 전후 사용자 `save.cfg` 해시 동일 (없으면 없는 채로). 내보낸 묶음에 `res://tests/`·`res://artifacts/`·`res://docs/`가 들어가지 않았음을 확인 (방법 자유). 래퍼 테스트 통과. `AGENTS.md` 명령 목록에 빌드 한 줄
- **결과 — 병합** ([PR #70](https://github.com/jeongmo-dot/gravity_orb/pull/70) `ec02c6e`, 2026-10-11): `.\tools\build_windows.ps1` → `build/windows/GravityOrb.exe` (111,038,784바이트, PCK 내장) + `GravityOrb.console.exe` + `BUILD.txt`. Claude 재검수: main 기준 다시 빌드, 내보낸 exe 스모크 3종 에러 0, 창 실행 6초 정상 (창 제목 `Gravity Orb`), 사용자 `save.cfg` 해시 전후 동일, exe 안에 `run_tests`·`capture_screens`·문서 이름 0건 / `OrbitStage`·`CelestialOrbArt` 있음, 래퍼 285/285. `script_export_mode=2` (압축 바이트코드)

#### 10.5.1 빌드 버전과 파일 이름 (#70)
사용자 (2026-10-11): 빌드 파일 이름에 버전이 들어가게
- **버전 한 곳**: `project.godot`의 `application/config/version` (예: `0.11.1`). 내보내기 프리셋의 파일·제품 버전 칸은 이 값을 따른다 (비워 두어 프로젝트 버전을 쓰거나, 빌드 스크립트가 같은 값인지 검사). 버전 값은 Claude가 정하고 이 절의 버전 기록에 적는다 (수치와 같은 원칙)
- **번호 규칙** `MAJOR.MINOR.PATCH`: `MAJOR.MINOR`는 기획서 버전 (지금 0.11), `PATCH`는 병합된 변경이 있는 상태에서 테스트 빌드를 새로 낼 때마다 +1. 기획서 버전이 오르면 `PATCH`는 0부터
- **파일 이름**: `build/windows/GravityOrb_v{버전}.exe` (예: `GravityOrb_v0.11.1.exe`), 콘솔 래퍼 `GravityOrb_v{버전}.console.exe`, 빌드 정보 `GravityOrb_v{버전}_BUILD.txt` (커밋·날짜·엔진·모드). 디버그는 `build/windows-debug/`에 같은 이름
- **이전 버전은 남긴다**: 빌드 스크립트는 같은 버전의 파일만 지우고 다시 만든다 (다른 버전 파일은 그대로 — 비교 테스트용). **2026-10-26 확인: 0.11.1·0.13.0·0.13.1·0.14.0 파일 (0.13.1.zip 포함 13개)이 `build/windows/`에서 사라졌다** — #100 회신 (10-24)에는 "유지", #103 회신 (10-25)부터는 0.15.x만. 지운 경위 조사·막는 장치는 인박스 #108 9번. 각 버전의 빌드 커밋은 아래 표에 있어 다시 만들 수는 있다. 버전 없는 예전 이름 (`GravityOrb.exe`·`GravityOrb.console.exe`·`BUILD.txt`)은 한 번 정리
- 빌드 결과 줄 (`WINDOWS_BUILD_RESULT`)에 버전과 실제 파일 경로를 적는다
- **항목 검증용 빌드는 `-Debug`로** (`build/windows-debug/`) — 릴리스 이름 파일 (`build/windows/GravityOrb_v*.exe`)은 빌드 항목에서만 만든다 (2026-10-17 추가). #81까지 항목마다 검증 빌드를 릴리스로 돌려 `GravityOrb_v0.11.1.exe`가 #81 브랜치 내용으로 덮였다 — 지금 그 파일은 예전 0.11.1 (V4-1까지)이 아니다
- **결과 — 병합** ([PR #72](https://github.com/jeongmo-dot/gravity_orb/pull/72) `87b75cc`, 2026-10-11): 프리셋 버전 칸을 비워 프로젝트 버전을 상속 (Windows 속성은 4자리 `0.11.1.0`, 파일 이름·`_BUILD.txt`는 `0.11.1`). Claude 재검수: main 기준 빌드 → `build/windows/GravityOrb_v0.11.1.exe` (111,053,536바이트) + `.console.exe` + `_BUILD.txt` (커밋 `87b75cc`), 다른 파일 (`GravityOrb.zip`) 보존, 버전 없는 예전 파일 정리됨, 내보낸 exe 스모크 3종 에러 0, 사용자 `save.cfg` 해시 전후 동일, 래퍼 291/291

버전 기록
| 버전 | 날짜 | 내용 |
|---|---|---|
| 0.11.0 | 2026-10-11 | 첫 Windows 테스트 빌드 (#68, V3-2까지) |
| 0.11.1 | 2026-10-11 | V4-1 반응 연출 A+C (#69) 포함 — 파일 이름 규칙 적용 첫 빌드 (#70) |
| 0.13.0 | 2026-10-17 ([PR #84](https://github.com/jeongmo-dot/gravity_orb/pull/84) `d04abba`, 빌드 커밋 `b69f2c0` — 같은 트리) | `GravityOrb_v0.13.0.exe` 111,165,560바이트. 기획서 0.13 — 0.12는 빌드 없이 지나감. V4-2 호령·팝업·피버 (#71), BLITZ 시계 단순화·겹 게이지 (#72), 결과 → 랭킹 버튼 잠금 수정 (#73), 행성 컬렉션 6종·두 모드 6색 (#74·#75·#78), 턴제 입력 표시 (#76·#77), GRAVITY SLIME 세 번째 모드 (#79~#81). 알려진 점: 화성 협곡 ✕·극관 곧은 경계 (#82), 슬라임 화면 화살표 겹침 (#83), 행성 늘어남 (§12-P.4, 나중에) |
| 0.13.1 | 2026-10-17 ([PR #90](https://github.com/jeongmo-dot/gravity_orb/pull/90) `1972fc0`, 빌드 커밋 `f274c15` — 같은 트리, 커밋 뒤 깨끗한 트리에서 빌드) | `GravityOrb_v0.13.1.exe` 111,169,640바이트. 기획서 0.13.1. 0.13.0 뒤 병합: 화성 협곡 Y·극관 둥근 조각 (#82·#86), 입력 표시 — 슬라임 화살표 없음·도는 빛 = 잠김 시간·슬라임 빛 버그 (#83), 슬라임 MAX 계속 성장 (#85), 슬라임 빛 경로·잔상 크기 (#87). 참고: `build/windows/GravityOrb_v0.13.0.exe`는 #83 검증 빌드로 덮여 원래 0.13.0이 아니다 |
| 0.14.0 | 2026-10-21 ([PR #96](https://github.com/jeongmo-dot/gravity_orb/pull/96) `1ec2b7a`, 빌드 커밋 `aedda73` — 같은 트리, 커밋 뒤 깨끗한 트리에서 빌드) | `GravityOrb_v0.14.0.exe` 111,177,032바이트. 기획서 0.14. 0.13.1 뒤 병합: 단계별 난도 (CLASSIC 4색 시작 → 30턴 해왕성·60턴 수성, 공 50턴마다 +1 / SLIME 20턴마다 새 색, 최소 등장 20·40·60턴 2·3·4 — #91·#92), 새 행성 안내 (들어오는 순간)·미리보기 테두리 (#92·#93), 행성 늘어남 끄기·BLITZ 보너스 글자 시점 (#93), 측정 도구 (#89~#91) |
| 0.15.0 | 2026-10-24 ([PR #102](https://github.com/jeongmo-dot/gravity_orb/pull/102) `ec99603`, 빌드 커밋 `b59cc20` — 같은 코드, 커밋 뒤 깨끗한 트리에서 빌드) | `GravityOrb_v0.15.0.exe` 111,213,584바이트. 기획서 0.15.1. 0.14.0 뒤 병합: **JELLY 네 번째 모드** — 흡수 규칙·FINAL MOVE (#95), L5부터 대폭발 J5 (#98), 3D 젤리 그림·말랑함·MAX 얼굴 시안 C (#96), 시작 화면 카드 4장·랭킹 JELLY 탭·결과 FINAL MOVE (#97), 결과 화면 레벨 이름·반쪽 카드 글자 (#99). 알려진 점 (사용자 플레이 2026-10-25): JELLY 움직임 지글거림·툭툭 튐 (#101), 대폭발 가능 표시 어두운 고리 (#102) |
| 0.15.1 | 2026-10-25 ([PR #105](https://github.com/jeongmo-dot/gravity_orb/pull/105) `91ebce9`, 빌드 커밋 `b76927e` — 같은 코드, 커밋 뒤 깨끗한 트리에서 빌드) | `GravityOrb_v0.15.1.exe` 111,219,904바이트. 기획서 0.15.1. 0.15.0 뒤 병합: JELLY 움직임 다듬기 — 중력 틀·`deform` 하나·속력 감소 찌그러짐·숨쉬기 가중치·흡수 0.10초 성장, 얼굴이 몸통에 가려지지 않음, 새 젤리 틀 바로 맞춤 (#101), 그림 위치 보간 (3D 모드 전체, #101), 대폭발 가능 표시 — 터질 듯한 얼굴·은은한 빛, 볼 색, 얼굴 늘 똑바로 (#102) |
| 0.15.2 | 2026-10-25 ([PR #107](https://github.com/jeongmo-dot/gravity_orb/pull/107) `4271f88`, 빌드 커밋 `a9f9a35` — 같은 코드, 커밋 뒤 깨끗한 트리에서 빌드, **태그 `legacy-four-modes`**) | `GravityOrb_v0.15.2.exe` 111,221,024바이트. **네 모드가 들어간 마지막 버전.** 기획서 0.15.2. 0.15.1 뒤 병합: JELLY 크기 레벨 고정·배 속에 먹은 젤리·대폭발 가능 뒤 빛 삭제 (#104) |
| 0.16.0 | 2026-10-26 ([PR #111](https://github.com/jeongmo-dot/gravity_orb/pull/111) `cad9727`, 빌드 커밋 `75ef9fc` — 같은 코드, 커밋 뒤 깨끗한 트리에서 빌드) | `GravityOrb_v0.16.0.exe` 111,069,840바이트. 기획서 0.16. **JELLY 단일 앱 첫 빌드** — BLITZ·SLIME 삭제, CLASSIC 숨김, 큰 JELLY 시작 버튼·JELLY 랭킹·"처음 화면" (#106), 젤리 둘레 색 효과 고리 끔 (#109), 고리 연출·그림 전부 삭제·몸통이 물리보다 작게 그려지던 빈틈 없앰·별가루 무작위 (#110). 프로젝트 버전은 #106에서 이미 0.16.0 |

#### 10.5.2 출시 절차
한국 모바일 출시에 필요한 법·행정·스토어·기술 절차와 M10 인박스 후보는 [release_checklist_kr.md](release_checklist_kr.md)에 둔다 (2026-10-11). 결정·확인 결과는 그 문서에 체크한다

## 11. 설계 해석 (기획서 빈칸을 채운 결정)

기획서에 명시되지 않았거나 모호한 부분에 대한 이 문서의 결정이다. 플레이테스트 후 기획서에 반영하거나 뒤집는다.

### 11.1 같은 방향 스와이프
기획서 3.2 표는 "유효 입력", 7장은 미정. **기본 허용(true)**, 토글 제공. 비허용이면 입력을 잠그지 않고 무시만 한다.
→ **#124 (2026-10-31)부터 비허용 (false)** — 사용자 "이전에 입력한 방향을 그대로 유지는 못하게". 지금 중력 방향 화살표는 입력 대기 중에 그리지 않는다 (§12-ONE.17)

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
- HUD: NEXT 영역에 큐[0]을 기존 크기로, 큐[1]을 오른쪽(또는 아래)에 **작고 흐리게**(알파 0.5, 크기 0.6배) 표시 (→ #122부터 NEXT·THEN 모두 판 위와 같은 크기, THEN은 흐리게만 — §12-ONE.15). 라벨 `NEXT` / `THEN`. 스와이프 영역을 가리지 않게 `mouse_filter = IGNORE` 유지

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
- **#58 이후 기준** (중력 3600): 22시드 벽/쌍 20/22px, 2D 호환 22시드 벽 14px, 연속·장시간 벽/쌍 34/68px, 이탈·발산 0 — §12-B.7
- **표시 위치 보정** (#39에서 구현, `Orb3D._render_clamp_enabled`): 물리 위치는 그대로 두고, 렌더링할 때만 구슬 중심을 보드 안쪽 `half − r`로 제한해 벽 박힘이 보이지 않게 한다 (게임 로직·측정은 물리 위치 기준)

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

**대폭발 레벨**: 90초 동안 들어오는 구체는 약 180개(색당 약 45개)라 L6(L1 32개 분량)은 거의 못 만든다. BLITZ에서는 `blitz_blast_min_level`(가안 **4**)을 쓴다 (턴제는 `blast_min_level` 6, #30). 깜빡임도 같은 기준 → #62: L6 시험 후 **두 모드 모두 L4로 통일** (§12-B.10)

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
- 측정 조건 (#65부터): **수직 동기 끔** (`--disable-vsync`) — 켜면 화면 주사율(120·165Hz)에 묶여 환경마다 비교가 안 된다. 보고에 수직 동기 상태·화면 주사율을 적는다

### 12-B.7 중력 2배 (기획서 0.10.12 — #58)
사용자 (2026-10-10, #57 이후 플레이): "딜레이는 해소된 것 같다, 중력 값이 더 셌으면 좋겠다" → 선택: **두 모드 모두, 2배 (1800 → 3600)**
- `gravity_strength` 1800 → **3600**. 레벨별 배율(`gravity_level_scale` 0.1)은 그대로 — L7은 3600 × 1.6 = 5760
- **물리 안전 한도 재측정이 핵심**: 2D 시절 2400 → 1800으로 내린 이력이 있다(#17, 고밀도 벽 복구 급증). Jolt 3D·120Hz·position steps 4에서 2배 중력이 버티는지 본다 — 22시드(벽 ≤ 14 / 쌍 ≤ 16px), 연속 턴(벽 ≤ 28 / 쌍 ≤ 60px), 이탈·발산 0
- 한도를 넘으면 기본값을 억지로 맞추지 말고 넘은 지표와 **대책 후보**(Jolt position/velocity steps 상향과 프레임 비용, 최대 속도 상한, 2700으로 낮추기 등)를 적어 `상태: 질문`
- 중력에 비해 상대적으로 약해지는 값(충격파 600, 대폭발 900px/s, 초록 진동 150px/s, 노랑 역중력)은 **바꾸지 않고** 체감 변화를 지표로만 본다 (플레이 후 조정)
- **#58 결과 (Draft PR #59)**: 3600에서 이탈·발산 0, 프레임 이상 없음. 한도 초과 — 3D 22시드 벽 17.3 > 14 / 쌍 18.8 > 16px, 2D 호환 벽 12.14 > 12px, BLITZ 장시간 벽 28.7 > 28 / 쌍 60.05 > 60px. 2700도 22시드 벽 15.7px로 실패, position steps 6은 효과 미미(+10% 시간)
- **결정 (Claude, 2026-10-10): 3600 유지 + 관통 한도 재설정.** 한도는 #39 렌더링 보정(구슬 그림을 보드 안 `half − r`로 제한) **이전**에 정한 값이라, 지금 벽 관통은 화면에 보이지 않는다. 판 밖으로 나가는 **이탈 0·발산 0을 절대 기준**으로 두고 관통 한도는 측정값 위 약 15% 여유로:
  | 한도 | 이전 | 새 값 (#58~) |
  |---|---:|---:|
  | 3D 22시드 벽 / 쌍 | 14 / 16px | **20 / 22px** |
  | 2D 호환 22시드 벽 | 12px | **14px** |
  | 연속·장시간(턴제·BLITZ 러너) 벽 / 쌍 | 28 / 60px | **34 / 68px** |
  | 이탈 / 발산 | 0 / 0 | **0 / 0 (그대로)** |
- 게임 영향 관측: BLITZ **무작위 연타 점수가 조준과 거의 같아졌다** (3600: 연타 0.3초 66,371 vs 조준 0.6초 64,491 — 무작위 ÷ 조준 점수비 0.52 → **1.03**, 연타 피버 14% → 42%). 중력이 세지면 물리가 저절로 만드는 반응이 늘어 "빠르고 정확한 손" 우위가 약해진다 → 사용자 플레이 후 판단 (필요하면 체인 판정·생산적 스와이프 기준 조정)
- **#58 병합** ([PR #59](https://github.com/jeongmo-dot/gravity_orb/pull/59), `17d3f8d`): 위 한도로 래퍼 259/259. 2D 연속 턴 테스트(시드 4242 20턴, 120턴)는 3D 러너 한도와 **별개** — 3600 실측 10.07 / 16.0px라 **14 / 18px**로 되돌렸다 (#59, [PR #60](https://github.com/jeongmo-dot/gravity_orb/pull/60) `ffbf541`)

### 12-B.8 중력 레벨 차등 (기획서 0.10.13 — #60)
사용자 (2026-10-10, #58 병합 후): "중력은 되돌리거나 1.25배 정도로 하고, 각 공마다의 차이 또는 레벨마다의 차이를 두는 게 좋겠다" → 선택: **레벨(크기)별 차이** (색깔별·둘 다는 고르지 않음)
- `gravity_strength` 3600 → **1800** (L1은 #58 이전과 같음), `gravity_level_scale` 0.1 → **0.25** (레벨 하나마다 +25%)

  | 중력 (px/s²) | L1 | L2 | L3 | L4 | L5 | L6 | L7 |
  |---|---:|---:|---:|---:|---:|---:|---:|
  | #58 이전 (1800, +10%) | 1800 | 1980 | 2160 | 2340 | 2520 | 2700 | 2880 |
  | #58 (3600, +10%) | 3600 | 3960 | 4320 | 4680 | 5040 | 5400 | 5760 |
  | **#60 (1800, +25%)** | **1800** | **2250** | **2700** | **3150** | **3600** | **4050** | **4500** |

- 의도: 크기만 봐도 무게를 안다. 기울이면 큰 공이 먼저 벽에 닿고 작은 공이 그 위에 쌓여, 큰 공끼리의 합체·대폭발은 벽 쪽에서, 작은 공 합체는 위쪽에서 일어나기 쉽다. 질량(`mass_exponent` 2)과 같은 방향이라 "큰 공 = 묵직함"이 일관된다. 작은 공이 큰 공 사이 틈으로 빠져 내려갈 수도 있으므로 층이 실제로 생기는지는 측정으로 본다
- 코드 변경 없음 — 레벨 배율은 이미 `Orb3D.set_gravity()`·`Orb.set_gravity()`가 적용하고, 합체 결과는 `Board3D.spawn_orb()`로 새로 생겨 새 레벨 중력을 받는다
- 물리 한도는 #58 기준 그대로 (3D 22시드 20/22px, 2D 호환 14px, 연속·장시간 34/68px, 2D 연속 턴 14/18px, 이탈·발산 0). 가장 센 중력(L7 4500)이 #58에서 통과한 L7 5760보다 작다. 넘으면 `상태: 질문`
- 충격파·대폭발·색 효과·생성 등 다른 값은 그대로
- 측정 — A #58 이전 (1800 / 0.1), B 현재 (3600 / 0.1), C 새 값 (1800 / 0.25):
  - 낙하 시간: 빈 판에서 L1·L4·L7 하나씩, 생성 벽에서 반대쪽 벽에 처음 닿을 때까지 (#21 방식)
  - 층: 턴 끝(BLITZ는 스와이프 1초 뒤) 구슬 중심에서 중력 쪽 벽까지 거리의 레벨별 평균 — C에서 큰 레벨이 더 벽 쪽에 있는지
  - 턴제 시드 101~112 게임오버까지: 길이 p50·점수·대폭발 p50·벽/쌍 최대·이탈·발산
  - BLITZ 휴리스틱 0.6초·무작위 0.3초 × 시드 101~112: 점수·반응·대폭발·피버 비율, **무작위 ÷ 휴리스틱 점수비** (#58: A 0.52 → B 1.03), 벽/쌍·이탈·발산
- **#60 결과** ([PR #61](https://github.com/jeongmo-dot/gravity_orb/pull/61), `340d029`):

  | 지표 | A 1800 / 0.1 | B 3600 / 0.1 | **C 1800 / 0.25** |
  |---|---:|---:|---:|
  | 빈 판 낙하 L1 / L4 / L7 | 1.042 / 0.850 / 0.708초 | 0.733 / 0.600 / 0.500초 | **1.042 / 0.733 / 0.567초** |
  | 턴제 길이 p50 / 점수 p50 / 대폭발 p50 | 153 / 15,896 / 0 | 167 / 23,733 / 1 | 162 / 18,655 / 1 |
  | BLITZ 조준(0.6초) / 연타(0.3초) 점수 p50 | 46,736 / 24,263 | 64,491 / 66,371 | 63,343 / 41,445 |
  | 연타 ÷ 조준 | 0.52 | 1.03 | **0.65** |
  | BLITZ 조준 피버 시간 p50 | 30.0% | 32.7% | 40.9% |
  | 벽 / 쌍 최대 (턴제 · BLITZ) | 21.6 / 35.1 · 21.6 / 58.3px | 27.4 / 36.4 · 28.7 / 60.1px | 20.1 / 25.5 · 21.5 / 59.3px |
  | 이탈 / 발산 | 0 / 0 | 0 / 0 | 0 / 0 |

- 큰 공이 **먼저 닿는 것**은 낙하 시간으로 확인 (L7이 L1의 54% 시간, A는 68%). **쌓인 더미의 크기별 층은 거의 생기지 않는다** — 턴 끝 구슬 중심에서 중력 벽까지 평균 거리 L1 286 / L4 286 / L6 327px (A 290 / 284 / 343과 비슷), BLITZ 조준은 L4가 L1보다 23px 벽 쪽. 꽉 찬 더미에서는 큰 공이 작은 공을 뚫고 내려가지 못하고, 합체로 생긴 큰 공은 더미 위쪽에서 태어나기 때문으로 본다 → 기획서 0.10.13의 "작은 공이 그 위에 쌓인다"는 뺐다
- 관찰 (사용자 플레이로 판단): BLITZ 조준 봇 피버 시간 30 → 41% (#51에서 "피버 잦음"으로 체인 6 → 8 올린 이력). 피버 시작 때 속도 체인 호령(`NICE!` 등)과 `FEVER ×2` 띠가 같은 높이에 겹쳐 호령이 띠 뒤에 가려지는 장면 (캡처 `06`)

### 12-B.9 BLITZ 줄어드는 시간 (기획서 0.10.14 — #61)
사용자 (2026-10-10, 두 모드 플레이 후): "턴 모드가 좀 더 게임성이 있고, 블리츠 모드는 그냥 막 눌러도 진행이 돼서 루즈하다. 긴장감이 없다" → 선택: **줄어드는 시간** (넘치면 끝·헛스와이프 벌칙·주문은 고르지 않음), 덧붙임: "기본 시간을 짧게 하고 합치거나 터질 때 시간 추가가 발생하게". 메인 모드 결정은 이 보완 뒤 다시 비교

**원인 (Claude)**: BLITZ에는 실패가 없다. 90초는 무조건 흐르고, 판은 40%까지 다시 채워져 늘 빽빽하다. 빽빽한 6색 판에서는 아무 방향으로 기울여도 반응이 나온다 (#60: 연타 0.3초 점수 = 조준 0.6초의 0.65배). 시간 보너스(대폭발 +1초, 잭팟 +3초, 합계 상한 20초)는 판을 조금 늘릴 뿐 생존과 상관이 없다. 줄어드는 시계는 시간 버는 속도의 작은 차이를 버틴 시간의 큰 차이로 키운다 (버는 속도 g초/초면 버티는 시간 ≈ 시작 시간 ÷ (1 − g))

**규칙** (`blitz_survival_enabled` = true)
- 시계: GO에서 `blitz_start_time` **30초**로 시작해 실제 시간으로 줄어든다. 0이 되면 지금처럼 입력 잠금 → 피날레 → 결과. `blitz_duration`(90초)과 보너스 합계 상한 `blitz_time_bonus_cap`(20초)은 쓰지 않는다
- 시간 보너스 — **합치거나 터질 때마다** 번다. 큰 합체일수록 크게 (RUNNING 중 반응만, 피날레 제외):

  | 반응 | 보너스 (가안 k = 1) | 이유 |
  |---|---:|---|
  | 합체 결과 L2 / L3 / L4 / L5 / L6 / L7 | +0.05 / +0.1 / +0.2 / +0.4 / +0.8 / +1.6초 | **레벨마다 2배** — 같은 재료를 한 단계 더 키울 때마다 같은 시간을 번다. 작은 합체는 빽빽한 판에서 저절로 많이 나므로 작게, 노려서 키운 큰 합체는 크게 |
  | 대폭발 (L4+, 같은 레벨·다른 색) | 1.0 → **+0.5초** | 같은 레벨끼리 닿으면 6색 중 5/6이 다른 색이라 우연히도 잘 난다 (#60: 연타 29회 vs 조준 37회) |
  | 잭팟 (MAX_CLEAR) | +3.0초 (그대로) | |
  | 피버 중 | 위 보너스 **×2** | 점수처럼 시간도 — 체인을 이어 가는 손이 오래 버틴다 |

  - 어림 (#60 반응·대폭발 수 기준, 레벨 분포는 추정): k = 1에서 조준 0.6초가 버는 속도 약 0.85초/초, 연타 0.3초 약 0.5초/초 → 버티는 시간 약 3분 vs 1분. 추정이 거칠어 측정에서 k를 0.5~2로 넓게 본다
- 보너스 표시: 타이머 옆 `+0.3s` — 0.5초 동안 들어온 보너스를 **합쳐 한 번에** (소수 한 자리, 합이 0.1초 미만이면 표시만 생략). 합체가 초당 여러 번 나므로 반응마다 띄우지 않는다
- 시계 상한 `blitz_time_max` **45초** — 시간을 쌓아 두고 쉬지 못하게. 넘는 보너스는 버린다 (표시는 실제로 더해진 값) → **#72에서 삭제 (0 = 상한 없음, §12-B.11)**
- 갈수록 빨라지는 시계 `blitz_drain_ramp_per_minute`: 시계가 1초에 `1 + 값 × (GO 이후 경과 분)`초씩 준다. 가안 **0.1** (2분 1.2배, 5분 1.5배) — 아주 잘해도 언젠가 끝나게. 0이면 일정 속도. 1.1배 이상이면 타이머 옆에 작게 `×1.2` (한 자리) → **#72에서 0 (일정 속도, §12-B.11)**
- 결과 패널에 **버틴 시간** `m:ss` (GO부터 시계 0까지, 피날레 제외)
- 시작 화면 BLITZ 버튼 글자 `90초 타임어택` → **`버티기 타임어택`**
- 저장: 점수 기준이 바뀌므로 BLITZ 최고 점수·랭킹은 새 키(`blitz_survival_best_score`, 랭킹 `blitz_survival`)로 새로 시작한다. 예전 90초 기록은 파일에 남기고 표시하지 않는다
- `blitz_survival_enabled = false`는 지금 90초 규칙 그대로 (비교용, 예전 저장 키)
- 바꾸지 않는 것: 생성·리필(40%), 스피드 체인·피버 조건(8체인·3초·×2), 대폭발 L4, 마지막 10초 똑딱(시계가 10초 이하일 때), 물리·중력, 턴제

**새·바뀐 필드**
| 필드 | 가안 |
|---|---|
| `blitz_survival_enabled` | true |
| `blitz_start_time` | 30.0 |
| `blitz_time_max` | 45.0 → **0 = 상한 없음** (#72) |
| `blitz_time_bonus_merge_by_level` | [0, 0.05, 0.1, 0.2, 0.4, 0.8, 1.6] (결과 레벨 L1~L7, L1은 쓰지 않음) |
| `blitz_time_bonus_display_window` | 0.5 |
| `blitz_time_bonus_blast` | 1.0 → **0.5** |
| `blitz_time_bonus_jackpot` | 3.0 (그대로) |
| `blitz_fever_time_multiplier` | 2.0 |
| `blitz_drain_ramp_per_minute` | 0.1 → **0** (#72) |

**측정 — 가안 확인과 크기 조정**
- 조건: 보너스 배율 k ∈ {0.5, 1.0, 2.0} (위 표의 시간 보너스 전체에 곱함) × 램프 ∈ {0, 0.1} = 6조건. 봇: 휴리스틱 0.3·0.6초, 무작위 0.3·0.6초 × 시드 101~112. 측정용 판 길이 상한 10분
- 보고: 버틴 시간 p50/p90/최대, 점수 p50, 무작위 ÷ 휴리스틱 점수비(같은 간격, 그리고 연타 0.3초 ÷ 조준 0.6초), 출처별 시간 보너스(분당), 결과 레벨별 합체 수, 대폭발, 피버 비율, 첫 L4 이상 합체까지 걸린 시간 p50 (초반 30초 안에 큰 합체가 나오는지), 끝 점유율, 벽/쌍·이탈·발산
- 기준: ① 조준 0.6초 버틴 시간 p50 **90~180초** ② 연타 0.3초 버틴 시간 p50 ≤ 조준 0.6초의 **0.6배** ③ 연타 0.3초 ÷ 조준 0.6초 점수 p50 ≤ **0.5** (#60: 0.65) ④ 10분 상한에 닿는 판 없음
- 기본값: 가안(k 1.0, 램프 0.1)이 ①~④를 지키면 그대로. 아니면 ①~④를 지키는 조건 중 ③이 가장 낮은 것 (같으면 램프 0). 지키는 조건이 없으면 가장 가까운 조건을 적고 `상태: 질문`

**#61 결과** ([PR #62](https://github.com/jeongmo-dot/gravity_orb/pull/62), `ae0e685`, 6조건 × 봇 4 × 시드 12 = 288판, 이탈·발산 0)

| k / 램프 | 조준 0.6초 버틴 시간 p50 | 연타 0.3초 p50 | 시간비 | 점수비 (연타 ÷ 조준) | 10분 상한 |
|---|---:|---:|---:|---:|---:|
| 0.5 / 0 | 44.6초 | 43.0초 | 0.96 | 0.88 | 0 |
| 0.5 / 0.1 | 43.9초 | 37.2초 | 0.85 | 0.61 | 0 |
| 1.0 / 0 | 69.7초 | 70.9초 | 1.02 | 1.05 | 0 |
| **1.0 / 0.1 (가안)** | **82.8초** | **66.0초** | **0.80** | **0.78** | **0** |
| 2.0 / 0 | 598.5초 | 126.6초 | 0.21 | 0.15 | 17 |
| 2.0 / 0.1 | 316.5초 | 114.0초 | 0.36 | 0.27 | 0 |

- 기준 ①~④를 모두 지키는 조건 없음. k를 키우면 구별은 좋아지지만 조준 쪽이 5~10분으로 길어진다
- **봇이 조준을 거의 못 한다**: 같은 0.6초에서 무작위 ÷ 휴리스틱 점수 0.93, 휴리스틱 0.3초가 네 봇 중 가장 짧다 (47.9초, 끝 점유율 58% — 빠른 스와이프마다 1개씩 들어와 판이 찬다). 봇 기준으로 수치를 더 쫓는 것은 #32처럼 멈춘다
- **BLITZ의 성장은 L4에서 멈춘다**: 조준 0.6초 12판 합체 L2 1,266 · L3 1,100 · L4 579 · **L5 23 · L6 2 · L7 0**. L4끼리 닿으면 5/6이 다른 색이라 대폭발로 사라진다. 분당 시간 보너스 출처: 대폭발 12.2 · L4 10.7 · L3 10.1 · L2 5.9 · L5 0.9 · L6 0.1초 — "큰 합체일수록 많이"가 실제로는 L4까지만 작동
- **결정 (Claude, 2026-10-10): 가안(k 1.0, 램프 0.1) 그대로 사용자 플레이로 판단.** 줄어드는 시계 자체의 긴장감(30초 시작, 1분 남짓 판)은 들어갔다. 플레이 후에도 "막 눌러도 된다"면 다음 레버 후보:
  1. **기울이기 비용** — 받아들여진 스와이프마다 시계 −0.2초 (연타 0.3초는 초당 0.67초를 더 잃고, 0.6초 조준은 0.33초). 한 번 기울일 때마다 값어치가 있어야 한다. 보너스 k를 올려 조준 쪽 길이를 맞춘다
  2. **BLITZ 대폭발 L4 → L5** — L4끼리 만나도 터지지 않아 L4를 같은 색끼리 맞춰 L5·L6로 키우는 길이 열린다 (대신 큰 공이 쌓여 판이 빨리 찬다)

### 12-B.10 대폭발 레벨 통일: L6 시험 → 두 모드 L4 (기획서 0.10.15 — #62)
사용자 (2026-10-10, #61 병합 후): "다른 색끼리 만나는데 왜 대폭발로 사라져?" → Claude가 대폭발 규칙(0.9.5)과 BLITZ L4 기준의 부작용(L4끼리 만나면 6색 중 5/6이 다른 색이라 거의 다 터져 L5 위로 크지 못함)을 설명 → **"L6으로 통일"**
- `blitz_blast_min_level` 4 → **6** (턴제 `blast_min_level` 6과 같음). 깜빡임·피날레 대상·휴리스틱 봇도 `active_blast_min_level()`을 따른다. 필드는 남긴다 (모드별로 다시 나눌 여지)
- 기대: BLITZ에서 L4·L5끼리는 다른 색이어도 터지지 않아, 같은 색끼리 맞춰 L5·L6·L7로 키우는 길이 열린다 (#61 L4 기준: 조준 봇 12판 L5 23 · L6 2 · L7 0). 대신 다른 색 L4·L5가 반응 없이 쌓여 판이 빨리 찬다 — 줄어드는 시계와 함께 "판이 막히지 않게"가 새 압박이 된다
- 대폭발 시간 보너스 `blitz_time_bonus_blast` 0.5 → **2.0초**: L6끼리의 대폭발은 우연히 나는 반응이 아니라 키워서 노린 결과다 (#61에서 0.5로 낮춘 이유가 사라짐. 사용자에게 보여 준 미리보기 값 +2초와 같음). 피버 중 ×2는 그대로
- 바꾸지 않는 것: 턴제, 대폭발 동작(두 구체만 사라지고 나머지는 밀려남)·점수(두 구체 기본 점수 합 × 5), 시계(30초·상한 45초·램프 0.1), 합체 시간 보너스 표, 생성·리필·체인·피버, 물리

**측정** (#61 측정기 재사용, 시드 101~112)
- A 지금 (대폭발 L4, 대폭발 +0.5초) vs **B 새 값** (L6, +2.0초), 둘 다 k 1.0·램프 0.1, 봇 4종 (휴리스틱 0.3·0.6초, 무작위 0.3·0.6초)
- B에서 시간 보너스 배율 k ∈ {0.75, 1.5, 2.0} × 봇 2종 (휴리스틱 0.6초, 무작위 0.3초) — 판 길이 조정용
- 보고: 버틴 시간 p50/p90, 점수 p50, 결과 레벨별 합체 수 (특히 L5~L7), 대폭발 수, 잭팟 수, 출처별 시간 보너스(분당), 피버 비율, 끝·최대 점유율, 피날레 대폭발 수, 벽/쌍·이탈·발산
- 기본 k: B에서 휴리스틱 0.6초 버틴 시간 p50이 **60~150초**면 k 1.0 유지. 벗어나면 {0.75, 1.5, 2.0} 중 그 값이 90초에 가장 가까운 k로 시간 보너스 값 전체(합체 표·대폭발·잭팟)에 곱해 기본값으로. 모두 벗어나면 `상태: 질문`. 봇 사이 구별 기준은 쓰지 않는다 (#61 결정)

**#62 1차 결과 — L6 시험** ([PR #63](https://github.com/jeongmo-dot/gravity_orb/pull/63), 168판, 이탈·발산 0)

| 조준 봇 0.6초 (12판) | A: L4 · 대폭발 +0.5초 | B: L6 · 대폭발 +2.0초 |
|---|---:|---:|
| 버틴 시간 p50 | 78.7초 | **37.4초** |
| 점수 p50 | 43,477 | **3,337** |
| 대폭발 p50 / 피날레 대폭발 p50 | 27 / 5 | **0 / 0** |
| 합체 L5 / L6 (12판 합) | 21 / 0 | 13 / 0 |
| 끝 점유율 p50 | 29.8% | **67.1%** (연타 0.3초 81.2%) |

- B는 168판 전부 L6 합체·대폭발·잭팟·피날레 대폭발이 0. 다른 색 L4·L5가 반응 없이 쌓여 판이 막히고, 시간 보너스가 작은 합체(분당 약 14초)뿐이라 30초 남짓에 끝난다. k 2.0도 46초
- 결론: BLITZ(6색·스와이프마다 생성·짧은 시계)에서는 L4 대폭발이 막힌 판을 뚫는 유일한 통로다

**결정 변경 (2026-10-11 사용자): "두 모드 다 L4로 통일"** (Claude 제시안은 BLITZ만 L4로 되돌리기 / L6 유지 + BLITZ 4색 / L6 유지)
- `blast_min_level`(턴제) 6 → **4**, `blitz_blast_min_level` **4** (그대로), `blitz_time_bonus_blast` **0.5** (L4 대폭발은 우연히도 잘 나므로 #61 값 그대로). 1차 PR의 `active_blast_min_level()` 통일(깜빡임·피날레·휴리스틱 봇)은 살린다
- **턴제 위험**: #29 측정에서 **L5** 대폭발만으로도 판이 17%에 머물러 12판 모두 800턴까지 갔다 (#30에서 L6으로 올린 이유). 그 뒤 생성 램프(50턴마다 +1개, 상한 없음, #56)가 들어와 판은 결국 끝나지만 길이가 크게 늘 수 있다. 턴제 4색에서는 같은 레벨 L4끼리 닿으면 3/4가 다른 색이라 대폭발이 잦다
- 턴제 측정 (시드 101~112, 게임오버까지): 길이 min/p50/max, 점수 p50, 대폭발 p50, 후반 반응 0 턴 비율, 종료 턴 턴당 생성 수, 끝 점유율, 벽/쌍·이탈·발산 — #60 기준(L6, 162턴)과 나란히. **800턴에 닿는 판이 있거나 p50 > 250턴이면** 생성 램프 `spawn_count_ramp_turns` 40·30 조건도 같이 재서 보고 (기본값은 바꾸지 않고 `상태: 질문` — 램프는 사용자가 정한 값)
- 수동 QA: 턴제에서 대폭발이 잦아질 때 히트스톱(0.07초)이 자주 걸리는 체감

**추가 결정 (2026-10-11 사용자)**
1. "모드 간의 폭발 기준은 같아야 해" → `blitz_blast_min_level` 필드를 **없애고** 두 모드 모두 `blast_min_level` 하나를 쓴다 (`active_blast_min_level()`은 모드 분기 없이 이 값). 레벨 조건·색 조건·밀어내기·점수·깜빡임은 모드와 무관하게 같다. 모드 고유로 남는 것: BLITZ의 시간 보너스·피날레, 턴제의 대폭발 히트스톱(연출)
2. "L5와 L6를 어떻게 할까" → **클수록 더 큰 대폭발** (Claude 제시안 중 선택. 다른 안: 최대 레벨 L5로 축소 / 그대로)
   - 밀어내는 범위를 레벨별로: 새 필드 `blast_push_radius_by_level` (L1~L7, `board_size` 비율) 가안 [0, 0, 0, **0.3, 0.55, 1.0, 1.0**] — L4 주변만, L5 판 절반, L6·L7 판 전체 (식은 §7.7). 충격파 고리 연출의 최대 반경도 범위에 맞춘다
   - BLITZ 대폭발 시간도 레벨별: `blitz_time_bonus_blast`(한 값) 대신 `blitz_time_bonus_blast_by_level` L4 **+0.5** · L5 **+1.0** · L6 **+2.0** · L7 **+3.0초** (피버 ×2 그대로)
   - 점수는 그대로 (두 구체 기본 점수 합 × 5 — 이미 레벨이 클수록 크다)
   - 의도: 같은 색끼리 맞춰 L5·L6로 키울 이유("지금 터뜨릴까, 더 키워서 크게 터뜨릴까")가 생기고, 잦은 L4 대폭발이 판 전체를 매번 흩뜨리지 않는다 (턴제 퍼즐성 유지)
3. 측정 (위 턴제 측정에 더해): 대폭발 레벨별 횟수, 대폭발 한 번에 밀려난 구슬 비율 평균 (L4 · L5 · L6+), BLITZ 봇 4종 — A(L4·판 전체 밀기, #62 1차) vs 새 값(L4·레벨별 범위): 버틴 시간·점수·L5~L7 합체·끝 점유율, 벽/쌍·이탈·발산. 범위 가안은 플레이로 판단 (봇 기준 선택 없음)

**#62 2차 결과 — L4 통일 + 레벨별 범위** ([PR #63](https://github.com/jeongmo-dot/gravity_orb/pull/63), 턴제 36판 · BLITZ 96판, 이탈·발산 0, 벽/쌍 한도 안)
- 규칙·연출은 명세대로: 두 모드 `blast_min_level` 4 하나, 범위 L4 0.3 · L5 0.55 · L6·L7 판 전체, 고리 반경 = 범위, BLITZ 대폭발 시간 0.5/1/2/3초. 대폭발 한 번에 밀려난 구슬 비율 L4 약 43% · L5 약 87% · L6+ 100% (턴제)
- BLITZ: 새 범위(B)는 판 전체 밀기(A)와 거의 같다 — 조준 0.6초 버틴 시간 77.2 vs 78.7초, 점수 39,232 vs 43,477. L5 이상 합체는 여전히 드물다 (12판 L5 22 · L6 0)
- **턴제 (L4)**:

  | 생성 램프 | 판 길이 min / p50 / max | 점수 p50 (최대) | 대폭발 p50 | 한 판 최대 콤보 | 후반 반응 0 |
  |---:|---:|---:|---:|---:|---:|
  | #60 기준 (L6, 50) | — / 162 / — | 18,655 | 1 | — | — |
  | 50 (기본) | 362 / **453** / 586 | **8,158,763** (7억 4,904만) | 133 | 14~23 | 37% |
  | 40 | 284 / 411 / 470 | 19,864,098 | 134 | — | 17% |
  | 30 | 263 / 310 / 435 | 18,844,226 (4억 8,942만) | 97 | 14~24 | 21% |

  - 대폭발 L4가 판을 계속 비워 길이가 약 3배. 콤보 배수 2^(n − 1)이 대폭발 연쇄로 콤보 14~24까지 올라가 점수가 폭주 (콤보 20 = 약 52만 배)

**결정 (2026-10-11 사용자)**
1. 턴제 한 판 **약 250턴** (Claude 제시안: 약 250턴 / 예전처럼 160턴 / 30턴 램프 310턴 / 그대로 450턴)
   - 수단: 생성 램프 간격만 줄인다 (턴당 1개로 시작하는 #27 결정은 유지). 후보 `spawn_count_ramp_turns` **25 · 20 · 15** (상한 없음 그대로) × 시드 101~112, 게임오버까지
   - 선택: p50이 **220~280턴** 안이면서 250에 가장 가까운 후보 (같으면 더 긴 간격). 없으면 `상태: 질문`
2. 턴제 콤보 배수 상한 **×128** (Claude 제시안: ×128 / ×1024 / 그대로) — 새 필드 `combo_multiplier_max` 128.0, `min(base^(combo − 1), max)`. BLITZ 체인 배수와 무관. 점수 팝업 계산식도 실제 쓴 배수(최대 ×128)를 보인다
- 보고: 후보별 길이 min/p50/max, 상한 적용 점수 p50/최대, 최대 콤보 분포, 대폭발 p50, 후반 반응 0 비율, 종료 턴 생성 수, 벽/쌍·이탈·발산

**#62 3차 결과** ([PR #64](https://github.com/jeongmo-dot/gravity_orb/pull/64), 콤보 상한 ×128 적용, 시드 101~112 게임오버까지)

| 생성 램프 | 판 길이 min / p50 / max | 점수 p50 (최대) | 최대 콤보 p50 | 대폭발 p50 | 후반 반응 0 |
|---:|---:|---:|---:|---:|---:|
| 25 | 208 / 239 / 326 | 1,004,767 (2,151,215) | 16 | 65 | 0.18% |
| **20 (채택)** | 167 / **240** / 292 | **1,170,088** (3,039,222) | 17 | 83 | 0.24% |
| 15 | 163 / 203 / 222 | 1,862,006 (2,491,695) | 18 | 77 | 0% |

- 선택 규칙(220~280턴 안, 250에 가장 가까움)대로 **20** (240턴). 25(239턴)와 거의 같다
- 콤보 상한으로 점수는 수억 → 백만 단위 (상한 전 램프 50 p50 816만·최대 7억). #60(L6) 시절 1.9만보다는 여전히 크다 — 대폭발이 잦아진 만큼
- 물리 한도 안, 이탈·발산 0. 후반 반응 0 턴이 거의 없다 (L6 시절 18~37%)

### 12-B.11 BLITZ 시계 단순화: 빨라지기·45초 상한 삭제 (기획서 0.11.1 — #72)
사용자 (2026-10-11): "시간이 빨리 감소하는 규칙 삭제. 시간이 흐르는 속도는 일정하게 유지. 시간이 증가하는 요인 중 추가 시간 45초 상한도 삭제. 계속 연장 가능하게"
- 빨라지는 시계와 상한은 #61에서 "아주 잘해도 언젠가 끝나게, 연타보다 조준이 유리하게, 후반 긴장"을 위해 넣었다 (§12-B.9). Claude가 그 이유와 #61 측정 (보너스 ×2·램프 0에서 조준 봇 p50 598초, 10분 상한 17판)을 설명한 뒤 사용자가 삭제를 결정했다. 결과: **잘하는 사람은 끝없이 이어 갈 수 있다** — 버틴 시간·점수에 위 한계가 없다
- `blitz_drain_ramp_per_minute` 0.1 → **0** — 시계는 항상 1초에 1초씩 준다. 타이머 옆 `×1.2` 표시는 나오지 않는다 (1.1배 이상일 때만 표시하는 기존 규칙 그대로). 필드와 계산은 남긴다 (0 = 일정)
- `blitz_time_max` 45 → **0 = 상한 없음** — 시간 보너스는 항상 전부 더한다. 0보다 크면 지금처럼 상한으로 쓴다 (필드는 남긴다)
- **시간 막대 — 겹 게이지**: 새 필드 `blitz_time_bar_reference` = **45.0** = 한 겹의 길이. 상한이 없으므로 45초가 넘으면 막대를 가득 채운 채 두지 않고 **겹을 쌓는다**
  - 0~45초: 어두운 바탕 위 1겹 (시간 초록 `#30D158`). 45~90초: 1겹이 가득 찬 위로 2겹 (청록 `#22C7D9`)이 왼쪽부터 찬다. 90~135초: 3겹 (보라 `#A35CF0`). 그다음은 초록 → 청록 → 보라를 되풀이
  - 막대 오른쪽 끝 옆에 겹 수 `×2`·`×3` (2겹 이상일 때만, Orbitron 작게, 그 겹 색). 빨라지는 시계 `×1.2` 표시는 없어지므로 그 자리를 쓴다
  - 시간이 줄어 겹 경계 아래로 내려가면 위 겹이 사라지고 아래 겹이 가득 찬 모습으로 돌아간다
  - 10초 이하 빨강은 그대로 (1겹만 남았을 때)
- **늘어난 시간을 막대에 보이기** (사용자 덧붙임 2026-10-11: "시간이 연장될 때 기존 게이지에 더해서 증가한 시간 게이지가 보이게")
  - 시간 보너스가 들어오면 **지금 채움 끝에 이어 붙는 밝은 조각**으로 늘어난 만큼을 보여 준다: 그 겹 색을 흰색 쪽으로 밝게 + 은은한 빛. 0.35초 그대로 있다가 0.3초에 걸쳐 평소 색으로 섞인다
  - `+0.3s` 글자와 같은 0.5초 묶음 창 안의 보너스는 **한 조각으로 합쳐 자란다**. 조각이 섞이는 동안 또 들어오면 이어서 붙는다
  - 조각이 겹 경계를 넘으면 나눠 그린다: 아래 겹의 남은 부분 + 새 겹의 왼쪽 시작 부분
  - 아주 작은 보너스 (+0.05초 ≈ 1px)도 보이게 조각 최소 폭 6 논리 px (표시만, 실제 시간과 무관)
  - 피버 중 (×2) 조각은 호박색 `#FFB020` 빛을 섞어 "두 배로 받았다"가 보이게
- **타이머 숫자**는 큰 값에서도 잘리지 않게 실제 글자 폭으로 맞춘다 (예: `128.4`, `999.9`, `1234.5`)
- **결과 패널 버틴 시간**: 1시간 미만 `m:ss`, 1시간 이상 `h:mm:ss`
- 바꾸지 않는 것: 시작 30초, 시간 보너스 표 (합체 L2~L7 +0.05~+1.6초, 대폭발 L4~L7 +0.5~+3초, 잭팟 +3초, 피버 ×2), 보너스 표시 0.5초 합산, 마지막 10초 똑딱, 피날레, 점수·생성·리필·피버 조건, 물리, 턴제, 저장 키 (`blitz_survival`) — 규칙이 바뀌어도 기록은 이어서 쌓는다
- **측정 (보고만, 합격 기준 없음)**: 바뀐 기본값으로 #61과 같은 봇 (휴리스틱 0.3·0.6초, 무작위 0.3·0.6초 × 시드 101~112, 측정용 판 길이 상한 10분) — 버틴 시간 p50/p90/최대, 10분 상한에 닿은 판 수, 점수 p50, 분당 시간 보너스 (출처별). 사용자에게 "한 판이 얼마나 길어질 수 있는지" 알려 주는 용도

**#72 결과 — 병합** ([PR #74](https://github.com/jeongmo-dot/gravity_orb/pull/74) `fe23984`, 2026-10-11, 1차 통과): 새 `BlitzTimeBar`가 겹·조각을 그린다. 경계 표현: 정확히 45.0초는 1겹 100%, 45초를 넘는 순간부터 2겹과 `×2` (빈 새 겹 깜빡임 방지). 측정 (Codex, 4봇 × 시드 101~112, 10분 상한) — 10분에 닿은 판 **0/48**

| 봇 | 버틴 시간 p50 / p90 / 최대 | 점수 p50 |
|---|---|---:|
| 휴리스틱 0.3초 | 46.1 / 57.7 / 58.3초 | 12,653 |
| 휴리스틱 0.6초 | 92.4 / 140.1 / 159.0초 | 43,984 |
| 무작위 0.3초 | 60.9 / 75.8 / 91.6초 | 25,584 |
| 무작위 0.6초 | 80.3 / 111.6 / 121.8초 | 40,465 |

- 봇은 상한·가속이 없어도 1~3분이면 끝난다 (분당 버는 시간 합계 약 21~42초로 줄어드는 60초보다 적다 — L4 대폭발·L3·L4 합체가 주 수입). 끝없이 이어지는지는 사람 플레이로 본다
- Claude 검수: Codex 캡처 `40`~`43` 직접 확인 (3겹 `×3`·`128.4`, +1.6초 밝은 조각 → 섞임, 44 → 46초 조각이 1겹 끝·2겹 시작에 나뉨, 피버 조각 호박색) — 재실행 없음
- 작게 남은 것: 조각은 보너스가 들어오는 즉시, `+1.6s` 글자는 0.5초 묶음이 끝난 뒤에 떠서 글자가 뜰 때 조각은 거의 섞여 있다 (`41_a`·`_b`). 플레이 소감을 보고 필요하면 조각 유지를 글자에 맞춘다
  - **#93 결과 — 병합** (`c18e0e2`): 글자는 첫 보너스 프레임에 뜨고 0.5초 동안 누적, 조각 섞임은 글자 페이드 시작에 맞춰 호출 (누적 0.5초 → 유지 0.45초 → 글자 0.2초 페이드, 조각 섞임 0.3초). Claude 검수: `41_a` 첫 `+1.6s`와 밝은 조각이 함께 보인다
  - **고침 (2026-10-19 사용자 선택) → #93**: 글자와 조각이 같은 순간에 보이게. ① `+n.ns` 글자는 **첫 보너스가 들어오는 순간** 바로 뜨고, 0.5초 묶음 동안 들어오는 보너스를 더해 숫자가 올라간다 (예: `+0.4s` → `+1.2s`) — 묶음이 끝난 뒤의 표시 시간·사라짐은 지금 그대로 ② 조각은 **글자가 보이는 동안 밝게** 유지하고, 글자가 사라지기 시작할 때 0.3초 동안 섞인다 (지금은 들어오고 0.35초 뒤 섞임 시작). 피버 호박색·최소 폭 6px·겹 나눔 그대로. 시간 계산·보너스 표는 그대로

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
- **#62 (2026-10-11)**: 대폭발 L4 통일로 50턴 램프의 판 길이 p50 162 → **453턴** (40턴 411, 30턴 310) → 사용자: **약 250턴** 목표 — 후보 25·20·15턴 측정 → **20턴** (p50 240턴, 167~292, PR #64)

### 12-T.2 턴제 입력 가능·잠김 구분 (#76)
사용자 (2026-10-12): "턴 방식일 때 입력을 받지 못하는 때랑 입력을 받을 수 있을 때를 잘 구분해줘야 할 것 같아"
지금 (main): 스와이프하면 `TurnManager.on_swipe` → `InputRouter.set_locked(true)`, 구슬이 멈출 때까지 (`stable_duration` 0.33초 연속 정지 또는 상한 `max_settle_time` 1.5초) 잠긴다. **화면에는 아무 표시가 없고** (상태 글자는 디버그 HUD에만), 잠긴 동안의 스와이프는 소리 없이 버려진다. 또 잠긴 중에 손을 대기 시작한 동작은 풀린 뒤에 손을 떼도 버려진다 (`InputRouter._started_locked`). 첫 생성 뒤 정지 (`_is_initial_settle`)도 같은 잠금
1. **입력 가능** (`WAITING_INPUT`)
   - 보드 테두리 밝게 (하늘색 `#BFE9FF` 쪽, V2 중력 벽 빛은 그대로)
   - 보드 네 변 바깥에 **방향 화살표 4개**가 0.2초에 부드럽게 나타난다. 막힌 방향 (`blocked_directions`)은 위험 빨강 `#FF3B30`, 같은 방향 스와이프가 허용되면 지금 중력 방향도 보인다
   - 잠금이 풀리는 순간 작은 **틱 소리** (아주 작게, 효과음 끔이면 없음) + 폰에서는 가벼운 진동 (`Haptics`, 짧게)
2. **계산 중 (잠김)** (`SPAWNING`·`SIMULATING`·첫 정지)
   - 화살표는 스와이프 순간 바로 사라진다 (0.1초)
   - 보드 테두리 어둡게 (약 40%) + 테두리를 따라 도는 **작은 빛 하나** (한 바퀴 약 1초 → **#83부터 한 바퀴 = 턴 잠김 상한**, §12-T.2.2) — "기다리는 중"
3. **잠긴 중 스와이프**: 받지 않는 규칙은 그대로 (턴제는 미리 넣어 두기 없음 — 생각하고 두는 모드). 대신 **그 방향 화살표가 회색 `#8EA3C8`으로 0.3초 깜박**여서 "지금은 안 받았다"를 알려 준다 (소리 없음)
4. **손 떼는 순간 기준**: 턴제에서는 잠긴 중에 손을 대기 시작했어도 **손을 뗄 때 입력 가능 상태면 받는다** (지금은 버림). BLITZ는 지금 그대로
5. 게임오버 (`GAME_OVER`)·결과 패널·랭킹 위에서는 화살표·도는 빛 없음
- 바꾸지 않는 것: 턴 규칙 (정지 판정 0.33초·상한 1.5초), BLITZ, 물리, 점수
- **검수**: 테스트 — 상태별 화살표·도는 빛 표시, 막힌 방향 빨강, 잠긴 중 스와이프 → 턴 없음 + 회색 깜박 1회, 잠긴 중 시작·풀린 뒤 뗀 스와이프 → 턴 1회 (턴제만), 틱 소리 1회/턴. 두 비율 캡처 `44_turn_ready` (막힌 방향 하나 포함), `45_turn_busy` (두 시점: 도는 빛 위치가 다름), `46_turn_rejected`. 물리 해시 동일

**#76 결과 — 병합** ([PR #77](https://github.com/jeongmo-dot/gravity_orb/pull/77) `9c666af`, 2026-10-12): `TurnInputIndicator` (HUD), `InputRouter.swipe_rejected` 신호, 턴제만 `set_accept_release_after_unlock(true)`, 틱은 외부 파일이 없을 때 50ms 합성음 (기본 효과음보다 12dB 작게), 진동 5ms. Codex 보고 래퍼 299/299, 해시 동일. Claude 검수 (Codex 캡처 `44`~`46`): 동작·색은 명세대로지만 **화살표 (540 폭 캡처에서 약 10px)와 도는 빛이 너무 작아** 폰에서 눈에 잘 안 띈다 → #77에서 키운다
- 함께 발견: 전체 캡처가 `same_size_stars` 화소 검사에서 멈춘다 (L7 0.88228 < L6 0.80869 × 1.1). #76 탓이 아니라 **검사가 시간에 따라 흔들린다** — L6 별 반짝임 (`sin(TIME…)`, 0.88~1.0)·L7 끓는 표면이 `TIME`을 써서, 찍는 순간이 조금만 달라져도 밝기 비가 1.09~1.14로 움직인다 (#69 때 L6 0.77879). #75에서 행성으로 바뀌며 이 검사도 바뀌므로 거기서 **측정용 캡처의 셰이더 시간을 고정**하게 한다

#### 12-T.2.1 화살표·도는 빛 키우기 (#77)
- 방향 화살표: **약 56 논리 px** (화면 폭의 약 5%) 갈매기 모양, 보드 각 변 바깥 가운데. 0.2초 나타날 때 0.8 → 1.0배로 살짝 커지며. 입력 가능 동안 아주 느린 숨쉬기 (알파 0.85~1.0, 1.6초 주기 — 눈에 띄되 거슬리지 않게). 막힌 방향 빨강, 거절 깜박 회색은 같은 크기
- 도는 빛: 지름 약 20 논리 px + 짧은 꼬리 (변 길이의 약 15%, 뒤로 갈수록 흐려짐) — "불러오는 중"처럼 보이게
- 화살표가 위 HUD (배수·콤보)·아래 받침과 겹치지 않음 (두 비율), 보드 안으로 들어가지 않음
- **막힌 방향 경고를 화살표 하나로** (사용자 2026-10-12: 경계선 빨간 라인이 왜 그려지는지 이해가 안 됨 → "빨간색은 없애줘")
  - 지금: 막힌 방향 (그 방향으로 기울이면 NEXT가 들어올 자리가 없어 게임오버)마다 **입구 벽** (기울인 방향의 반대쪽)이 빨갛게 맥동한다 (V2 `Board3D` `_warning_directions` → `WARNING_FRAME_COLOR`). 위험한 방향과 빨간 벽이 서로 반대쪽이라 헷갈리고, #76 빨간 화살표와 경고가 양쪽에 동시에 뜬다
  - 바꿈: **보드 테두리의 막힘 빨강을 없앤다** (벽은 평소 금속색, 피버 주황·중력 벽 빛은 그대로). 막힌 방향은 **화살표에만** — 빨강 화살표 위에 작은 ✕ (같은 크기 규칙), 입력 가능할 때만 보임. 받침의 `BLOCKED: LEFT` 글자는 `← 막힘`처럼 방향 화살표 + 한글로 (여러 방향이면 `← ↑ 막힘`)
  - 위험 배수 ×4의 빨강 바깥 띠 (V2 DANGER)는 뜻이 달라 그대로 둔다
  - 캡처 `18_board_blocked`와 그 화소 검사 (막힌 벽만 빨강)는 새 표시로 바꾼다: 테두리에 막힘 빨강 없음 + 빨강 ✕ 화살표 + `← 막힘`
- 검수: 두 비율 `44`~`46`·`18` 다시 (화살표·빛 크기 수치 보고)
- **#77 결과 — 병합** ([PR #78](https://github.com/jeongmo-dot/gravity_orb/pull/78) `07325c7`, 2026-10-12, 1차 통과): 갈매기 화살표 56 논리 px (팔 포함 외곽 — 9:16에서 보드 좌우 여백이 26.55px뿐이라 좌우 화살표는 보드에서 13px, 위아래는 34px), 막힘은 빨강 갈매기 + 작은 빨간 ✕, 도는 빛 지름 20px + 꼬리 148.5px (반투명 원 18개). `Board3D`의 막힘 빨강 (`_warning_directions` → 벽 색·안쪽 빛)을 지움 — 피버 주황·위험 ×4 빨강 띠·중력 벽 빛은 그대로. 받침 `← 막힘`·`← ↑ 막힘`. Codex 보고 래퍼 299/299, 해시 동일. Claude 검수: Codex 캡처 `44`·`45_a`·`46`·`18` 직접 확인 — 재실행 없음. 전체 캡처는 아직 `-HudScenesOnly`로만 (흔들리는 L6·L7 검사는 #75에서)

#### 12-T.2.2 도는 빛 한 바퀴 = 턴 잠김 시간 (#83)
사용자 (2026-10-17, 0.13.0 플레이): "일반 모드에서도 한 바퀴를 도는 시간을 턴이 고정되는 시간과 일치하게 맞춰줘"
- 지금: 도는 빛은 잠김과 상관없이 **1초에 한 바퀴** (`ORBIT_DURATION`). 턴제 잠김 상한은 1.5초, 슬라임은 입장 + 1.85초라 빛이 몇 바퀴 돌다 아무 데서나 끝난다
- 바꿈: 도는 빛은 **시계처럼** — 잠김이 시작되는 순간 출발점 (왼쪽 위 모서리)에서 떠나, **잠김 상한에 닿는 순간 정확히 한 바퀴**를 돈다. 진행은 시간을 따로 세지 않고 **게임이 잠김을 재는 그 시계**에서 바로 계산한다 (히트스톱·느려짐이 있어도 빛과 잠김이 어긋나지 않게)
  - **턴제 (CLASSIC)**: `진행 = TurnManager.settle_elapsed / Config.data.max_settle_time` (0~1로 자름). `SPAWNING` 한 프레임은 0. 안정 판정으로 일찍 끝나면 그 자리에서 대기 표시로 바뀐다 (한 바퀴를 채우지 않음). 처음 판 깔기 (`_is_initial_settle`)도 같은 식
  - **슬라임**: 잠김 상한 = 입장 끝 시각 + `max_simulation_time` (1.85초). 입장 중에는 `진행 = intro_elapsed / (예정된 마지막 입장 시각 + 1.85)`, 대기열이 빈 뒤에는 `진행 = (대기열이 실제로 빈 시각 + simulation_elapsed) / (대기열이 실제로 빈 시각 + 1.85)`. 입구가 막혀 입장이 늦어지면 분모가 커져 값이 잠깐 줄 수 있으니 **진행은 뒤로 가지 않는다** (앞선 값과 큰 쪽). FINAL MOVE 턴 (생성 없음)은 `simulation_elapsed / 1.85`. 정지 판정으로 일찍 끝나면 그 자리에서 대기 표시로
  - BLITZ는 도는 빛이 없다 (그대로)
- 꼬리 길이 (변의 15%)·빛 크기·색은 그대로. 빛 속도만 잠김 시간에 맞춰 느려진다 (턴제 한 바퀴 1.5초, 슬라임 보통 2.5~2.8초)
- 검수: 테스트 — 턴제 `settle_elapsed` 0·0.75·1.5초에서 진행 0·0.5·1.0, 슬라임 입장 3개 턴에서 대기열이 빈 순간과 상한 순간의 진행 (상한에서 1.0), 입장 지연 시 진행이 줄지 않음, 같은 잠김 상태를 매 걸음 다시 알려도 진행이 되돌아가지 않음 (§12-G.11 도는 빛 버그). 캡처 `45_turn_busy` 두 시점 (예: 0.5초·1.0초 → 진행 1/3·2/3)과 `50_slime_shell_play` ③

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
  - 알려진 문제 (2026-10-16, 사용자 "공 모양이 변하는 경우가 있던데"): 행성 그림 (§12-W) 뒤로 ① 행성이 달걀 모양이 되고 ② `t > 0`이 되는 순간 메시 회전이 바디 회전에서 속도 방향으로 바뀌어 무늬 (대륙·협곡·고리)가 획 돌아가며 ③ 겉 빛·문양은 둥근 채라 몸통과 어긋난다. 안: A 끄기 (`fx_orb_stretch_enabled = false`, 기존 값이라 Claude가 바꿀 수 있음) / B 약하게 (1.05·0.97) + 무늬 회전 연속 (Codex). **사용자: 나중에 처리** — 그때까지 그대로
  - **결정 (2026-10-19 사용자 "행성 늘어남 끄기")** → #93: `fx_orb_stretch_enabled` 기본값 **false** (안 A). 메시·겉 빛·문양은 늘 둥글고 무늬는 바디 회전 그대로. 빠른 느낌은 보드 기울기·스와이프 잔상·"휙"이 맡는다. 필드와 늘어남 코드는 남긴다 (켜면 예전 그대로). 연출만이라 물리 해시 그대로
  - **#93 결과 — 병합** ([PR #95](https://github.com/jeongmo-dot/gravity_orb/pull/95) `c18e0e2`): 기본값 false, 꺼짐에서 빠른 행성 메시 배율 (1, 1, 1)·회전 = 바디 회전 테스트. 해시 그대로 (Codex)
- **진동(모바일 대비)**: `Haptics.gd`(Input 사용 허용 파일)에서 스와이프 8ms, 대폭발 25ms. PC에서는 아무것도 안 함. 필드 `haptics_enabled`
- 필드: `fx_tilt_degrees` 6, `fx_tilt_duration` 0.3, `fx_swipe_trail_enabled`, `fx_orb_stretch_enabled` (true → **false** #93 `c18e0e2`, 2026-10-19)

## 12-V. 비주얼 업그레이드 — 천체 컬렉션 (기획서 0.11 — #63~)

사용자 (2026-10-11): "수동 플레이 감각을 확인하기 전에 전체적인 게임 비주얼 퀄리티를 올리고 싶다, 판매가 가능한 수준으로" → Claude가 시안 4개(코스믹 네온 · 천체 컬렉션 · 캔디 젤리 · 보석 공방) 제시 → **천체 컬렉션** 선택

**진단** (Claude, 2026-10-11 캡처 기준)
- 정체성이 없다: 배경은 단색 남색, 보드는 단순 그라데이션 — 테마가 보이지 않는다
- UI가 시제품 수준: 기본 글꼴 흰 글자뿐, 패널·아이콘·버튼 디자인 없음, 화면 아래 약 1/4이 빈 공간
- 구슬 개성 부족: 레벨이 올라도 크기만 커지고 모양·질감은 같다 → 키우는 보상감이 약하다
- 시작·결과·랭킹 화면이 텍스트와 사각 버튼뿐
- 이펙트가 기능 위주 (네모 파편, 반투명 타원 고리)
- 판매 필수 요소 없음: 로고, 앱 아이콘, 화면 전환, 상업용 글꼴

**아트 원칙** (모든 단계 공통)
1. 정보 우선순위: ① **색** (매칭 열쇠) ② **레벨** = 천체 종류·크기 ③ 색각 문양 ④ 장식. 장식이 색 구분을 흐리면 장식을 줄인다
2. 배경은 어둡고 채도 낮게, 구슬은 밝고 채도 높게 — 주인공은 구슬
3. 색 기준값은 `color_display` 6색 그대로: 빨강 `#E5484D`, 파랑 `#3E7BFA`, 초록 `#30A46C`, 노랑 `#F5C542`, 보라 `#A35CF0`, 청록 `#22C7D9`
4. 질감은 절차적(노이즈·셰이더)이거나 저장소 안에서 코드로 만든 작은 이미지 — 외부 아트 에셋을 쓰지 않는다 (라이선스). 글꼴은 OFL 등 상업 사용이 가능한 것만, 저장소에 동봉
5. 렌더러는 지금처럼 `gl_compatibility` (모바일 대상). 화면 후처리(글로우 등)에 기대지 않고 빛남은 머티리얼 발광·빌보드로 낸다
6. 보이는 것만 바꾼다 — 물리·규칙·수치는 그대로 (연출 켬/끔 물리 상태 해시 동일, §12-P 원칙)

**단계** (단계마다 전후 캡처 → Claude 검수 → 사용자 확인 후 다음 단계)

| 단계 | 내용 | 인박스 |
|---|---|---|
| V1 | 천체 구슬 — 레벨별 천체 모양·질감, 색 유지, 색각 문양, 폭발 가능 표시, NEXT/THEN 미리보기 | #63 완료 (PR #65) |
| V2 | 우주 배경·보드 — 성운·별(느린 반짝임·시차), 보드 테두리, 중력 방향 표시, 위험(DANGER) 연출 | #64 완료 (PR #66) |
| **V3-1** | **글꼴·테마·HUD** — 오비트론 + 노토 산스 KR, 색 토큰·Theme, HUD 재배치(아래 빈 공간·안전 영역·세로로 긴 화면), 점수 카운터, NEXT/THEN 받침, 타이머 막대, 아이콘 | #66 완료 (PR #68) |
| **V3-2** | **화면** — 시작 화면 (궤도 무대: 로고·고리 행성·모드 카드), 결과·랭킹, 설정 (소리·색각 문양), 버튼 눌림 상태, 화면 전환 | #67 완료 (PR #69) |
| **V4-1** | **반응 연출 (A+C)** — 작은 합체 별가루, L6·L7 탄생 강착·신성, L4 대폭발 중력파, L5+ 초신성 성운, 번쩍임 안전. **그림 남은 것**: L7 태양 (쌀알 무늬·고리 홍염), L5 바깥 테 틈, NEXT/THEN L1 미리보기 | #69 완료 (PR #71) |
| **V4-2** | **호령·점수 팝업·색 효과·피버 (A+C)** — 단계별 호령, 쉼표·금색 큰 점수, 색 효과를 별가루 체계로 (고리 한 겹), 피버 빛줄기·성운 빛 | #71 완료 (PR #73) |
| **V6** | **행성 컬렉션** — 색 = 행성 6종 (화성·지구·천왕성·금성·해왕성·수성), 레벨 = 크기 + 디테일, 두 모드 같은 6색 (§12-W) | **#74·#75** |
| V5 | 판매 준비 — 로고, 앱 아이콘, 스플래시, 스토어 스크린샷 장면. **V3-2에서 넘어온 것**: 시작 화면 행성 `SubViewport`가 320px인데 354 논리 px로 그려짐 → 실제 폰 해상도(1080·1440 폭)에서 선명한지 확인, 필요하면 표시 크기에 맞춤 | 다음 |

### V1 천체 구슬 (#63)
레벨 사다리 — 충돌 반지름 R은 그대로, 그림이 충돌 원 안을 채운다:

| 레벨 (R) | 천체 | 모양 | 색 표현 |
|---|---|---|---|
| L1 (25px) | 운석 | 울퉁불퉁한 바위 (실루엣 0.9~1.0R), 표면의 금 | 금 사이로 그 색이 빛난다 (광맥) + 가장자리 빛 |
| L2 (40px) | 달 | 크레이터가 있는 둥근 위성 | 표면이 그 색의 밝은 톤 |
| L3 (60px) | 바위 행성 | 대륙·바다 무늬 + 얇은 대기 | 바다·대기가 그 색 |
| L4 (85px) | 고리 행성 | 줄무늬 몸통(약 0.68R) + 기울어진 고리(바깥 1.0R) | 몸통 줄무늬·고리가 그 색 |
| L5 (100px) | 가스 거인 | 굵은 띠 + 소용돌이 폭풍 | 띠가 그 색 계열 |
| L6 (120px) | 별 | 스스로 빛나는 구 + 둘레 광채 | 빛 자체가 그 색 |
| L7 (140px) | 태양 | 표면이 끓는 듯한 큰 항성 + 느린 플레어 | 빛·플레어가 그 색 |

- 회전: 몸통 무늬는 물리 회전대로 구른다. 고리(L4)와 별·태양의 광채(L6·L7)는 **카메라 기준 고정** (고리 기울기 약 20°) — 구를 때 뒤집히지 않게
- 그림(고리·광채 포함)은 충돌 원 **1.0R 안**에 들어간다 — 이웃 구슬과 겹쳐 보이지 않게
- 가장자리 빛(프레넬 림)은 그 색으로 — 어두운 운석도, 스스로 빛나는 별도 색이 먼저 읽히게
- 색각 문양(▲ ● ■ ◆ ★ ✚): **어두운 외곽선이 있는 흰 무늬**로 다시 그리고, 카메라를 향하고, 레벨에 맞는 크기로. `orb_symbols_enabled` 켬/끔 그대로
- 폭발 가능(L4 이상) 표시: 몸통 전체 깜빡임 대신 **그 색의 바깥 테두리 맥동** (주기 `blast_blink_period`). 이미 빛나는 L6·L7에서도 구별되게
- 합체·성장 중(그림 반지름 보간)도 자연스럽게. 합체 순간 연출(펀치)은 지금 그대로 (V4에서 다듬음)
- NEXT/THEN 미리보기도 같은 천체 그림 (작게)
- 리소스: (색 × 레벨) 머티리얼·메시 공유 (#57 copy-on-write 규칙 유지), 새 머티리얼도 예열(#57)에 포함

**V1 검수**
- 캡처 13장 + 새 장면 `14_orb_codex`: 6색 × 7레벨 도감 (문양 켬, 같은 배경)
- 색 구분 수치: 도감에서 구슬마다 **밝은 쪽 40% 화소의 평균색**을 Lab으로 바꿔 — 같은 레벨의 서로 다른 색 쌍 ΔE(CIE76) **최소 25 이상**, 평균색의 색상각이 기준색과 **±25° 안**. 기준 6색끼리의 최소 ΔE도 같이 적는다 (비교용). 표로 보고
- 성능: #57 창 모드 측정 그대로 (BLITZ 시드 101~104, 봇 0.3초) — 프레임 p99 < 16.7ms, 33.3ms 초과 0, 첫 생성 프레임. 전후 그리기 호출 수·머티리얼 수 보고
- 테스트: 물리 상태 해시 전후 동일 (턴제 20턴·BLITZ 20초), 머티리얼·메시 공유 수 ≤ 색 × 레벨 (+ 깜빡임·성장 복제 예외), 문양 켬/끔, 테두리 맥동은 L4 이상만, 미리보기가 같은 그림을 쓴다

**V1 1차 결과** ([PR #65](https://github.com/jeongmo-dot/gravity_orb/pull/65)) — 래퍼 274/274, 캡처 14장, 색 구분 같은 레벨 최소 ΔE 27.3~32.4 · 색상각 오차 2° 이하, BLITZ 창 모드 프레임 p99 3.8ms · 33.3ms 초과 0, 물리 해시 동일. **기능 명세는 충족했지만 그림 품질은 판매 수준에 못 미친다** (Claude 캡처 검수, 2026-10-11):
1. **평면적이다** — 구에 빛과 그림자가 없어(셰이더 `unshaded`, 조명 계산 없음) 스티커처럼 보인다. 예전 광택 구슬보다 입체감이 떨어진다
2. **세로 이음매** — L2~L7 몸통 가운데에 세로 경계선이 있고, 노이즈가 좌우 반쪽에서 끊긴다 (UV 이음매)
3. **천체로 읽히지 않는다** — L1 운석·L2 달은 그냥 작은 원판이다 (불규칙한 실루엣·크레이터 없음). L6 별·L7 태양은 얼룩진 행성에 테두리를 두른 모습이라 스스로 빛나는 느낌이 없다
4. **고리와 폭발 표시가 헷갈린다** — L4 이상에 그려지는 원형 폭발 외곽선이 고리처럼 보이고, 기울어진 고리는 잘 읽히지 않는다
5. L5 가스 거인의 띠가 평평한 가로 물결이라 구의 곡면을 따라 휘지 않는다

**V1 추가 요구 1 — 그림 품질** (같은 PR)
- **구 셰이딩** (L1~L5): 화면 왼쪽 위에서 오는 빛 하나로 밝은 면 → 그림자 면(오른쪽 아래, 약 40% 어둡게) 명암을 주고, 가장자리는 어둡게(림 감쇠) + 그 색의 대기 가장자리 빛. L2~L5에는 은은한 왼쪽 위 하이라이트. 모든 무늬는 구의 곡면을 따라 휜다 (띠·대륙이 위도선처럼)
- **이음매 제거**: 무늬는 구의 3D 위치(노멀)로 만든 끊김 없는 노이즈 — 어느 각도에서도 경계선이 없어야 한다. 검사: 도감에서 몸통 세로 중심선 좌우 1px 열의 평균 차이가 주변 열끼리 평균 차이의 2배 이하
- **레벨별 정체성 강화**:

  | 레벨 | 고칠 점 |
  |---|---|
  | L1 운석 | 실루엣을 울퉁불퉁하게 (원이 아니게, 0.85~1.0R). 몸통은 어둡고 채도 낮은 바위, 그 색으로 빛나는 금(광맥)이 또렷하게. 작은 크기에서도 "돌"로 읽히게 |
  | L2 달 | 그 색의 밝은 톤 표면 + 크레이터 3~5개 (테두리는 밝고 안쪽은 어두운 명암) |
  | L3 바위 행성 | 대륙(어둡고 채도 낮게)과 바다(그 색, 채도 높게)의 대비 + 얇고 밝은 대기 테 |
  | L4 고리 행성 | 고리는 **얇은 타원** (기울기 약 20°, 납작한 비율) — 아래쪽은 몸통 앞, 위쪽은 몸통 뒤로 지나간다. 원형 테두리처럼 보이면 안 된다 |
  | L5 가스 거인 | 폭이 다른 여러 띠 + 난류 + 타원형 폭풍 1개, 띠가 구면을 따라 휜다 |
  | L6 별 | **스스로 빛난다**: 중심은 거의 흰색 → 가장자리로 갈수록 그 색. 몸통 둘레 부드러운 광채(1.0R 안), 은은한 네 방향 빛살, 느린 반짝임 |
  | L7 태양 | 별보다 큰 발광체 + 천천히 끓는 표면 무늬(쌀알 무늬) + 가장자리 어둡게 + 광채 + 천천히 솟는 홍염 2~3개 (1.0R 안) |

- **폭발 가능 표시 변경**: 몸통 둘레에 따로 그리는 원은 없앤다 (고리와 헷갈림). L4·L5는 **그 색의 가장자리 빛(림)이 밝아졌다 어두워지는 맥동**, 별·태양(L6·L7)은 광채의 크기·밝기가 맥동. 주기 `blast_blink_period` 그대로
- 그대로 지킬 것: 색 구분 (같은 레벨 ΔE ≥ 25, 색상각 ±25°), 장식 1.0R 안, 물리 해시 동일, 프레임 예산 (#57 측정 p99 < 16.7ms, 33.3ms 초과 0), 머티리얼 공유
- 캡처: `14_orb_codex` + 새 `15_orb_closeup` (한 색의 L1~L7을 3배 크기로, 그림 검수용). 몸통 이음매 검사 수치 보고

**V1 결과 — 병합** ([PR #65](https://github.com/jeongmo-dot/gravity_orb/pull/65) `87bbb83`, 2026-10-11 사용자 확인): 추가 요구 1로 구 셰이딩·이음매 제거(도감 전체 비율 1.18)·레벨별 정체성·림/광채 맥동 반영. 같은 레벨 최소 ΔE 26.8~33.7, 색상각 오차 8° 이하, 프레임 p99 3.8ms, 래퍼 275/275, 물리 해시 동일. 남은 것(L7 태양 밝기·홍염 모양, L5 바깥 테 틈)은 V4로

### V2 우주 배경·보드 (#64)
지금: 배경은 `WorldEnvironment` 단색(#060B18), 보드는 불투명 남색 판(`Backing` #10192E) + 얇은 하늘색 막대 테두리(#8EC5FF), 막힌 방향은 빨강·피버는 주황 테두리
1. **배경** (화면 전체, 보드 뒤)
   - 깊은 우주: 아주 어두운 남색 → 보라 그라데이션, 가운데가 조금 밝은 비네트
   - 성운: 절차적 구름 2~3겹 (남보라 · 짙은 청록 · 자주 계열, 채도 낮게), 아주 느리게 흐른다 (한 바퀴 90초 이상)
   - 별: 3겹 (멀고 작은 별 다수 · 중간 · 가깝고 큰 별 소수), 느린 반짝임. **시차**: 중력 전환 때 별층이 새 중력 방향으로 살짝 밀렸다 돌아온다 (가까운 층 8px · 먼 층 2px, 보드 기울기 연출 0.3초와 함께)
   - 가끔 지나가는 유성 하나 (20~40초에 한 번, 0.6초, 주로 보드 바깥)
2. **보드** (중력 우물의 창)
   - 안쪽 판: 불투명 남색 대신 **어둡고 살짝 비치는 유리** — 뒤의 성운·별이 30~40% 밝기로 비치고, 가장자리로 갈수록 조금 어두워진다
   - **중력장 선**: 안쪽에 아주 옅은 격자선이 현재 중력 벽 쪽으로 휘어 흐른다 (불투명도 0.12 이하). 전환 때 0.3초에 새 방향으로 휜다
   - 테두리: 얇은 막대 대신 **금속·유리 느낌** (안쪽 빛 + 바깥 은은한 그림자, 모서리 사선 처리). 물리 벽 위치·두께는 그대로
   - **중력 벽 빛**: 지금 중력이 향하는 벽이 은은히 밝다 (흰빛 도는 하늘색). 전환 때 0.25초에 새 벽으로 옮겨 간다
   - 막힌 방향(턴제 BLOCKED)은 그 벽이 빨갛게 맥동, 피버(BLITZ)는 테두리 전체가 주황빛으로 달아오른다 (의미는 지금과 같음)
   - **위험(DANGER)**: 점유율이 `danger_start` 이상이면 위험 배수에 따라 테두리 바깥 빛이 하늘색 → 호박색 → 빨강, ×4 이상이면 천천히 맥동하고 배경 성운에 붉은 기운이 조금 섞인다. HUD `DANGER ×n` 글자는 V3까지 그대로
3. **지킬 것**: 물리 벽·보드 크기, 보드 기울기 연출(6°), 구슬 그림(V1), 외부 에셋·후처리 없음, 물리 해시 동일
4. **검수**
   - 캡처 15장 다시 + 새 장면 `16_gravity_switch` (중력 전환 0.12초 뒤 — 벽 빛 이동·중력장 선·별 시차가 보이는 순간), `17_board_danger` (턴제 위험 ×4)
   - 대비 수치: 구슬이 없는 보드 안쪽 평균 휘도 **≤ 0.10**, 배경 별·성운 최대 휘도 **≤ 0.6**. 붐비는 BLITZ 캡처(`07`)에서 구슬 평균 휘도와 보드 안쪽 휘도의 비 보고
   - 성능: #57 창 모드 측정 (BLITZ 시드 101~104, 봇 0.3초) — p99 < 16.7ms, 33.3ms 초과 0, 전후 그리기 호출 수

**V2 1차 결과** ([PR #66](https://github.com/jeongmo-dot/gravity_orb/pull/66)) — 래퍼 280/280, 캡처 17장, 대비: 빈 보드 안쪽 평균 휘도 0.022 (≤ 0.10), 배경 최대 0.548 (≤ 0.6), 붐비는 판(`07`) 구슬/보드 휘도 비 19.1, BLITZ 창 모드 프레임 p99 3.86ms · 33.3ms 초과 0, 물리 해시 동일. 우주 배경·비치는 유리 보드·휘는 중력장 격자는 좋다. 고칠 것 (Claude 캡처 화소 측정, 2026-10-11):
1. **중력 벽 빛이 엉뚱한 곳에 몰린다** — 중력이 아래일 때(`02`) 빛이 아래 벽 가운데가 아니라 **왼쪽 아래 모서리**에 몰린다: 아래 벽 밝기가 왼쪽 x≈60에서 (127, 215, 255), 가운데부터 오른쪽은 (69, 91, 126) 안팎이고 왼쪽 벽 아래쪽도 밝다. 오른쪽으로 바꾸는 중간(`16`)에도 빛이 왼쪽 아래에 남아 있다 → 지금 중력 방향을 잘못 알려 줄 수 있다
2. **위험 ×4 테두리가 거의 안 보인다** — `17`에서 테두리 바깥 평균색 (13, 6, 25) vs 보통 `02` (3, 5, 24): 빨강이 +10 남짓. 성운의 붉은 기운도 눈에 띄지 않는다

**V2 추가 요구 1** (같은 PR)
1. **중력 벽 빛**: 지금 중력이 향하는 **벽 전체가 고르게** 밝다 — 벽 가운데가 가장 밝고 양 끝으로 조금 약해지며, 모서리에 몰리지 않는다. 전환 때는 **가까운 모서리를 돌아** 새 벽으로 0.25초에 옮겨 간다 (아래 → 오른쪽이면 오른쪽 아래 모서리를 지나서). 정반대 전환은 한쪽으로 일관되게 돈다
   - 검사: 네 방향 각각 정지 상태에서 그 벽 가운데 밝기 ≥ 그 벽 양 끝 밝기, 그리고 다른 세 벽 가운데보다 1.5배 이상 밝다 (캡처 화소 또는 렌더 테스트)
2. **위험 표시 강화**: 테두리 바깥 빛(4~10px 띠)을 위험 배수에 따라 또렷한 색으로 — ×1.5 이상 호박색 `#FFB020`, ×4 이상 빨강 `#FF3B30`이 맥동 (밝기 60% ~ 100%). ×4에서 성운의 붉은 기운도 눈에 띄게 (보드 바깥 배경 평균 R 채널 +20 이상). 보드 안쪽 휘도 한도(≤ 0.10)는 지킨다
   - 검사: `17`에서 테두리 바깥 띠의 평균색이 맥동 최저점에서도 R ≥ 90, R ≥ 2 × G, R ≥ 2 × B
3. **막힌 방향 캡처** `18_board_blocked`: 게임오버 패널 없이, 턴제 경고(BLOCKED) 상태에서 그 벽만 빨갛게 맥동하는 장면
4. 나머지 그대로: 대비 한도, 프레임 예산, 물리 해시, 외부 에셋·후처리 없음

**V2 결과 — 병합** ([PR #66](https://github.com/jeongmo-dot/gravity_orb/pull/66) `ae0a713`, 2026-10-11): 추가 요구 1로 중력 벽 빛이 그 벽 전체를 고르게 밝힘 (네 방향 가운데 0.50~0.67 vs 다른 벽 최대 0.13), 아래 → 오른쪽 전환은 가까운 모서리로, 위험 ×4 바깥 띠 최저점 (95, 24, 36) + 성운 빨강 +25, `18_board_blocked` 막힌 벽만 빨강 (R 135 vs 다른 벽 8). 대비: 빈 보드 0.022, 배경 최대 0.577, 붐비는 판 구슬/보드 16.2. 같은 PR에서 엔진을 **일반 Godot 빌드**(`C:\work\GodotStandard`)로 전환 — 스크립트 기본 경로·`project.godot`의 빈 `[dotnet]` 섹션 삭제
- 성능 판정 (Claude): Codex 환경의 창 모드 p99 18.5 → 18.9ms(+1.8%)는 변경 전후 모두 같은 환경이라 회귀가 아니다. 그 환경의 p50 8.25ms는 120Hz 수직 동기 한 칸이라 측정이 화면 주사율에 묶여 있었다. Claude 환경(같은 PC, 165Hz)에서는 p50 6.07 · p99 9.06 · 최대 12.4ms, 16.7ms 초과 0, 입력 120/120 — **통과**. 앞으로 창 모드 측정은 수직 동기를 끄고 잰다 (#65)
- 성능 묶음의 근접 탐색 검사(200개 p95 < 1ms, 3회 중 최소)는 이 PC에서 762~1,046µs로 경계에 붙어 있어 Codex 환경에서 흔들린다 → #65에서 완화
- **#65 결과** ([PR #67](https://github.com/jeongmo-dot/gravity_orb/pull/67) `c7ef7d2`): 근접 탐색 5회 중 최소 p95 ≤ 1.5ms (Claude 3회 665/620/613µs), 2D 턴 시간 검사는 장기 묶음으로 (벽 복구 3회 모두 1), 래퍼 280/280 3회 연속. 창 모드 측정 수직 동기 끔 (Claude 165Hz: p50 1.63 · p95 2.86 · p99 4.20 · 최대 10.8ms, 16.7ms 초과 0, 입력 120/120)

### V3-1 글꼴·테마·HUD (#66)
사용자 (2026-10-11): 글꼴 조합 시안 4개(오비트론 + 노토 산스 KR · 엑소 2 + 고딕 A1 · 프레도카 + 주아 · 오디오와이드 + 도현) 중 **A. 오비트론 + 노토 산스 KR**
지금: 엔진 기본 글꼴, 흰 글자만, 패널 없음. 위쪽에 SCORE·BEST·NEXT/THEN·배수·DANGER·타이머가 몰려 있고 화면 아래 약 1/4이 비어 있다 (소리 버튼과 BLOCKED 글자만). 기준 해상도 1080×1920, `canvas_items` 늘리기, 비율 유지(기본 `keep`) → 세로로 긴 폰(9:19.5~9:21)에서는 위아래에 검은 띠가 생긴다
1. **글꼴** (둘 다 SIL OFL 1.1, Google Fonts 공식 저장소)
   - 제목·숫자·영문 라벨: **Orbitron** (500·700). 숫자는 고정 폭처럼 보이게 (자릿수가 바뀌어도 흔들리지 않게)
   - 한글·본문: **Noto Sans KR** (400·500). 용량을 줄이려고 KS X 1001 한글 2,350자 + 영문·숫자·기호로 **서브셋** (글꼴 파일 합계 3MB 이하)
   - `assets/fonts/`에 글꼴과 `OFL.txt`를 함께 두고, 출처·버전을 적는다
   - 오비트론은 폭이 넓다 → 큰 숫자(턴제 점수는 이제 수백만)는 칸 너비에 맞춰 **자동으로 줄인다** (최소 크기 정함), 9,999,999까지 잘리지 않게
2. **색 토큰·Theme**: Godot `Theme` 리소스 하나로 — 글자 주색 `#E8EEFF`, 보조색 `#8EA3C8`, 강조 하늘색 `#BFE9FF`, 패널 바탕(남색 반투명 약 60%) + 얇은 하늘색 테두리 + 둥근 모서리 12px, 호박색 `#FFB020`, 위험 빨강 `#FF3B30`, 시간 초록 `#30D158`, 피버 주황 `#FF9F0A`. 흰 글자 기본값 대신 토큰을 쓴다
3. **HUD 재배치** (1080×1920 기준, 안전 영역 안)
   - 위: 가운데 **점수 패널** (작은 `SCORE` 라벨 + 큰 숫자), 오른쪽에 `BEST`, 왼쪽에 소리 아이콘 버튼. 배수(×n)·콤보/체인 줄은 점수 패널 바로 아래. DANGER 배지는 점수 패널 왼쪽 아래 (보드 테두리 색과 같은 색)
   - BLITZ 타이머: 큰 숫자 + 보드 바로 위 **시간 막대** (상한 45초 기준으로 차는 막대, 10초 이하 빨강). `+0.3s`와 시계 속도 `×1.2`는 타이머 양옆
   - **아래 받침 (빈 공간 활용)**: 보드 아래에 NEXT(크게)·THEN(작게)과 `×n`을 담은 패널. BLOCKED 경고도 이 받침 위쪽에. 손가락이 닿는 곳이지만 표시만 하고 입력을 막지 않는다 (스와이프는 화면 전체)
   - 소리 버튼은 이모지 대신 **벡터 아이콘** (스피커 켬/끔, 저장소 안에서 그린 SVG 또는 코드 드로잉)
4. **세로로 긴 화면**: 비율 유지 대신 **세로 확장**(`expand`)으로 — 배경은 화면 끝까지 채우고, HUD는 위·아래 가장자리(안전 영역)에 붙고, 보드는 가운데에서 지금 크기를 유지한다. 3D 카메라는 가로 폭 기준으로 보드 전체가 보이게
5. **점수 카운터**: 점수가 한 번에 바뀌지 않고 0.3초 동안 올라간다 (빠르게 시작해 천천히 멈춤). 큰 득점(배수 ×8 이상 등)은 숫자가 살짝 튄다. BEST 경신 순간 BEST가 반짝
6. **구슬 안 문양 끄기** (사용자 2026-10-11: "구슬 안에 심볼은 이제 삭제"): `orb_symbols_enabled` 기본값 true → **false**. 게임판·NEXT/THEN 모두 문양 없이 천체 그림만. 문양 기능과 켬/끔 경로는 지우지 않는다 — V3-2 이후 설정 화면에 접근성 항목(색각 문양)으로 다시 켤 수 있게 (Claude: 색만으로 구분하면 색각 이상이 있는 사람은 파랑·보라, 초록·청록을 헷갈릴 수 있음). 도감 캡처 `14`는 기본값(문양 없음)으로, 문양을 켠 상태는 테스트로 확인
- 바꾸지 않는 것: 게임 규칙·수치·물리, 구슬(V1)·배경·보드(V2), 시작·결과·랭킹 화면(V3-2), 이펙트(V4) — 단 점수 팝업·호령 글자는 새 글꼴만 적용
- **검수**: 캡처를 두 비율로 — 540×960(9:16)과 540×1170(9:19.5) — 주요 장면 `02`·`03`·`06`·`07`·`12`·`13`·`17`·`18`. 화면 배치 테스트에 세로로 긴 비율 추가 (HUD끼리·보드와 안 겹침, 안전 영역 안), 점수 9,999,999·BLITZ 타이머 45.0·NEXT `×8`이 잘리지 않음, 글꼴 용량, 프레임 예산

**V3-1 1차 결과** ([PR #68](https://github.com/jeongmo-dot/gravity_orb/pull/68)) — 래퍼 283/283, 스모크 3종 0, 캡처 26장 (9:16 18장 + 9:19.5 8장), 글꼴 합계 1.03MB, 물리 해시 동일, 창 모드 p99 3.75ms (Codex). 글꼴·패널·색 토큰·아래 받침·시간 막대·벡터 소리 아이콘·문양 끔은 명세대로 나왔다. Claude 캡처 검수 (2026-10-11)에서 찾은 것:
- **세로로 긴 화면에서 보드 양옆이 잘린다** (9:19.5 캡처 8장 모두). `Main3D.tscn` 카메라가 기본 `keep_aspect`(세로 기준, FOV 25°)라 화면이 길어지면 보드가 약 1.22배로 커져 좌우 벽·테두리가 화면 밖으로 나가고 가장자리 구슬이 잘린다 (`17`의 왼쪽 L2 빨강). 배치 테스트는 보드를 "화면 가운데 ±480"으로 가정하고 실제 카메라 투영을 보지 않아 통과했다 (9:16 실제 보드 테두리는 논리 y 약 450~1470)
- 소리 버튼·DANGER 배지는 화면 왼쪽 끝(x 0), BEST 패널은 오른쪽 끝(x 1080)에 붙어 좌우 여백이 없다. 스피커 아이콘은 버튼 왼쪽에 작게 치우쳐 있다
- 점수 패널의 `SCORE` 글자가 숫자와 같은 크기다 (한 라벨에 `SCORE` + 숫자를 넣고 자릿수에 따라 함께 줄임). 명세는 작은 라벨 + 큰 숫자. BEST도 같다
- `THEN` 글자가 너무 흐리다 (가장 밝은 화소 RGB 74·88·118, 보조색 `#8EA3C8`보다 훨씬 어둡다). NEXT `×8`이 마지막 구슬 테두리에 겹친다 (`07`)
- 글꼴 라이선스: `OFL.txt`에 Noto Sans KR 저작권 문구가 없다 (Orbitron 것만 있음). Orbitron은 변수 글꼴에서 정적 굵기로 뽑아 바꾼 파일인데 예약 이름 "Orbitron"을 그대로 쓴다. OFL은 수정본에 예약 이름을 쓰지 못하게 하므로, 수정하지 않은 원본을 넣는 쪽이 깔끔하다. 파일 안 이름표도 실제 굵기와 다르다 (Orbitron 두 파일 모두 "Regular", Noto 두 파일 모두 "Thin". 굵기 값 500·700·400·500 자체는 맞음)
- 범위 밖 (→ V4): NEXT/THEN의 L1 미리보기(2D)가 흰 금 간 별 모양이라 문양을 끈 지금은 문양처럼 읽히고, 게임판 L1 운석(점박이)과 다르게 보인다

**V3-1 추가 요구 1**
1. **보드가 어느 세로 비율에서도 다 보이게**: 화면이 9:16보다 세로로 길면 카메라를 가로 기준(`KEEP_WIDTH`)으로 바꾸고, FOV는 9:16에서 지금과 같은 가로 화각으로 둔다 (세로 25°를 9:16으로 환산하면 약 14.22°. 값은 코드에서 계산). 9:16이거나 더 넓은 화면은 지금 그대로 (세로 기준 25°). 화면 크기가 바뀔 때마다 다시 정한다. **9:16에서 3D 장면(보드·구슬·배경)은 지금과 화소 단위로 같아야 한다**
   - 배치 테스트: 보드 위치를 가정하지 말고 **실제 카메라로 보드 테두리 바깥 네 모서리를 화면에 투영**해서 잰다. 두 비율 모두 보드가 화면 안 (좌우 여백 16 논리 px 이상), 두 비율의 보드 가로 크기 차이 1% 이하, 시간 막대·위 HUD는 보드 위쪽에, 아래 받침은 보드 아래쪽에 겹치지 않게
   - 캡처 검사: 9:19.5 캡처에서 보드 좌우 테두리가 9:16 캡처와 같은 x 위치 (±2px)
2. **좌우 여백**: 소리 버튼·DANGER 배지·BEST 패널(아래 MAX COMBO/CHAIN 포함)도 안전 영역 안쪽으로 24 논리 px 띄운다 (위쪽과 같은 `HUD_MARGIN`). 스피커 아이콘은 버튼 가운데에, 버튼 높이의 약 45% 크기로
3. **점수·BEST 위계**: 라벨과 숫자를 나눈다. 작은 라벨 (`SCORE`·`BEST`, Orbitron 500, 보조색 `#8EA3C8`, 숫자 최대 크기의 약 40%, 자릿수와 무관하게 고정) + 큰 숫자 (Orbitron 700, 주색, 지금처럼 칸에 맞춰 자동 축소). 점수 튐·BEST 반짝은 숫자에 적용
4. **NEXT/THEN 받침 다듬기**: `THEN` 글자는 보조색 `#8EA3C8` 불투명 (THEN 구슬은 지금처럼 흐리게 둬도 된다). `×n`은 구슬 테두리에서 4 논리 px 이상 떨어지게
5. **글꼴 라이선스·이름표**
   - `OFL.txt` 맨 위에 두 글꼴의 저작권 문구를 모두 적는다. Noto Sans KR은 글꼴 파일에 든 문구 그대로: `(c) 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'.`
   - Orbitron은 google/fonts의 **수정하지 않은 원본 변수 글꼴** (`ofl/orbitron/Orbitron[wght].ttf`)을 그대로 넣고, Godot `FontVariation`의 `wght` 축으로 500·700을 고른다 (서브셋·정적 변환 없음). `SOURCE.md`에 경로·커밋·SHA-256을 적는다
   - Noto Sans KR 서브셋 두 파일의 이름표를 실제 굵기에 맞춘다 (Regular·Medium). 예약 이름 'Source'는 쓰지 않으므로 글꼴 이름 "Noto Sans KR"은 그대로 둔다
- 바꾸지 않는 것: 1차와 같다 (규칙·수치·물리, 구슬·배경·보드 그림, V3-2 화면, 이펙트)
- 검수: 두 비율 캡처 26장 다시, 배치 테스트 (실제 투영), 9:16 3D 영역 화소 동일, 글꼴 합계 3MB 이하, 창 모드 성능 (수직 동기 끔), 물리 해시 동일

**V3-1 추가 요구 1 결과** (PR #68 `f94e4e3`) — Claude 재검수 (2026-10-11): 래퍼 283/283, 스모크 3종 0, 캡처 26장. **긴 화면 보드 잘림 해결**: 9:19.5에서 카메라 `KEEP_WIDTH`·FOV 14.217°, 보드 테두리 투영이 두 비율 모두 x 13.28~526.72px (차이 0). 9:16 3D 영역은 1차 캡처와 화소 동일 (`02`·`17`·`18` 보드 영역 차이 0, `07`은 생성선 입자 띠 y 432~446만 다름 — 시간 연출). 좌우 24px 여백·SCORE 라벨 분리·THEN 글자·`×n` 위치·OFL 문구·Noto 이름표 좋음, Orbitron 원본 SHA-256 일치. 남은 것:
- **Orbitron 굵기가 적용되지 않는다**: 숫자·배수가 1차(정적 Bold)보다 눈에 띄게 가늘다 (`×8`의 8이 속 빈 네모처럼 보임). 헤드리스 진단에서 `FontVariation`에 `wght` 400·500·700·900 (문자열 키·정수 태그 키 모두)을 줘도 `9` 글리프 윤곽이 모두 같다 → 기본 인스턴스(400)로 그려지는 것으로 보인다
- **BEST 숫자가 패널 밖으로 나간다** (`03`·`13`·`17`·`18`의 9,999,999, 오른쪽 테두리를 약 3px 넘음). 자동 축소가 숫자 폭을 글자 크기의 0.72배로 가정하는데 Orbitron 숫자는 약 0.83배 (54px에서 7자리 313px)
- `BEST` 제목이 너무 작다 (`SCORE` 제목보다 훨씬 작아 거의 안 읽힘)

**V3-1 추가 요구 2**
1. **Orbitron 굵기 실제 적용**: 500·700이 화면에서 실제로 달라야 한다. 변수 글꼴 축을 제대로 적용하는 방법을 찾고, 이 엔진 버전에서 안 되면 **원저작자가 배포한 수정하지 않은 정적 파일** (Medium·Bold, 출처 저장소의 릴리스·빌드 산출물)을 쓴다. 직접 만든 인스턴스·서브셋은 쓰지 않는다 (예약 이름). `SOURCE.md`에 경로·커밋·SHA-256
   - 검사: 굵기가 적용됐음을 수치로 — 헤드리스에서 500과 700의 글리프 윤곽(또는 획 폭)이 다르거나, 캡처에서 점수 숫자 잉크 비율이 700일 때 500보다 15% 이상 크다
2. **숫자 맞춤을 실제 글자 폭으로**: 자릿수 × 계수 대신 그 라벨의 실제 글꼴(굵기 포함)로 `get_string_size`를 재서, 패널 안쪽 여백 좌우 8 논리 px 이상을 남기는 가장 큰 크기를 고른다 (최소 크기 아래로는 안 내려감). 점수·BEST 모두. 배치 테스트에 9,999,999에서 숫자 폭 ≤ 칸 폭 − 16 확인
3. **제목 크기 통일**: `SCORE`·`BEST` 제목을 같은 크기로 (약 22 논리 px, 보조색, 고정)
- 검수: 두 비율 캡처 (`03`·`06`·`13`·`17` 위 HUD 확대), 굵기 검사, 래퍼, 물리 해시 동일

**V3-1 결과 — 병합** ([PR #68](https://github.com/jeongmo-dot/gravity_orb/pull/68) `d3054e0`, 2026-10-11): 추가 요구 2로 Orbitron 축 키를 문자열 `"wght"`에서 TextServer 숫자 태그(`name_to_tag("wght")` = 2003265652)로 바꿔 500·700이 실제로 갈리고 (헤드리스 `9` 윤곽이 기본 굵기와 다름, 캡처에서 숫자·`×8`이 1차 정적 Bold처럼 굵음), 숫자 맞춤은 그 라벨의 실제 글꼴로 `get_string_size`를 재서 좌우 8px 여백을 남긴다 (BEST 9,999,999가 9:16에서 x 417~519, 패널 테두리 410·527 안). `SCORE`·`BEST` 제목은 같은 22px. Claude 재검수: 래퍼 283/283, 스모크 3종 0, 캡처 26장, 물리 해시 동일, 창 모드 (수직 동기 끔, 165Hz) p50 2.05 · p95 3.65 · p99 5.14 · 최대 12.8ms, 16.7ms 초과 0, 입력 120/120 (#65 때 p99 4.20ms 대비 +0.9ms — 글꼴·패널 HUD 몫, 예산 안). 남은 것 → V4: NEXT/THEN의 L1 미리보기 그림

### V3-2 시작·결과·랭킹·설정 화면 (#67)
사용자 (2026-10-11): 화면 시안 3개 (A 궤도 무대 · B 천체 도감 · C 보드 위 패널) 중 **A. 궤도 무대**
지금 (캡처 `01`·`04`·`09`·`10`·`11`): 엔진 기본 버튼과 회색 패널. 시작 화면은 제목 글자만 있고, 기록이 없는 모드는 `BEST 0`, 소리 버튼은 이모지. 결과는 글자 줄 나열, 랭킹은 표. V3-1 글꼴·Theme은 게임 중 HUD에만 적용돼 있다
1. **시작 화면**
   - 배경: V2 우주 배경(성운·별)이 그대로 보인다 (불투명 패널로 가리지 않음)
   - 로고: 가운데 위에 `GRAVITY` / `ORB` 두 줄 (Orbitron 700, 주색). 아래 작은 부제 `중력을 바꿔 합쳐라` (Noto 400, 보조색)
   - 로고 위 **고리 행성**: V1 천체 그림 그대로 (L4 고리 행성, 청록). 게임판 구슬과 같은 셰이더로 크게 (화면 폭의 약 22%) 그리고 천천히 자전 (한 바퀴 약 20초). 로고를 감싸는 얇은 궤도 타원 1~2개 (하늘색, 불투명도 30~50%)와 그 위를 천천히 도는 작은 천체 1~2개 (L1·L2, 한 바퀴 약 12초)
   - **모드 카드 두 장** 나란히: 왼쪽 BLITZ (번개 아이콘, 호박색 `#FFB020`), 오른쪽 CLASSIC (모래시계 아이콘, 하늘색 `#BFE9FF`). 카드 안에 아이콘, 모드 이름 (Orbitron 700), 한 줄 설명 (`시간 버티기` / `턴제 퍼즐`, Noto), BEST 숫자 (Orbitron, 천 단위 쉼표, V3-1처럼 실제 글자 폭으로 칸에 맞춰 축소). 기록이 없으면 `BEST —`. 마지막으로 한 모드의 카드는 그 모드 색 테두리
   - 아래 아이콘 줄: 랭킹 (트로피) · 소리 (V3-1 스피커 켬/끔 아이콘) · 설정 (톱니). 모두 저장소 안 벡터 아이콘, 누르는 칸은 88 논리 px 이상
2. **결과 패널** (게임판은 뒤에 어둡게 남김)
   - 제목 `TIME UP` / `GAME OVER` (Orbitron 700, 위험 빨강 `#FF3B30`)
   - 점수 패널: 작은 `SCORE` 라벨 + 큰 숫자 (쉼표). 0에서 최종 점수까지 0.6초 동안 올라간다
   - 기록 배지: 1위면 `최고 기록!`, 2~10위면 `새 기록 · n위`. 호박색 배지로, 점수가 다 오른 뒤 톡 튀며 나타난다. 기록이 아니면 그 자리에 BEST 숫자를 작게
   - 기록 칸 2×2: BLITZ는 버틴 시간 (초록) · 최대 체인 · 대폭발 · 피버, 턴제는 턴 수 · 최대 콤보 · 최고 천체 (`ScoreManager.max_level_reached`를 `L5 가스 거인`처럼) · 막힌 방향
   - 버튼: 하늘색으로 채운 큰 `다시 하기` (남색 글자) 한 줄, 그 아래에 테두리 버튼 `랭킹` · `모드 선택` 나란히
3. **랭킹 화면**: 제목 `랭킹`, BLITZ/CLASSIC 탭 (선택된 탭은 하늘색으로 채움), 10줄. 각 줄은 순위 (1·2·3위는 금·은·동 색), 점수 (Orbitron, 쉼표, 오른쪽 정렬), 체인/콤보 (`체인 14`), 날짜 (작게, 보조색). 빈 줄은 `—`를 흐리게. 방금 기록한 줄은 하늘색 테두리 + 지금의 맥동. 아래 `닫기`
4. **설정 패널** (톱니): `소리` 켬/끔, `색각 문양` 켬/끔 (구슬 안 문양, 기본 끔 — §12-U.2, #66). 둘 다 저장 파일의 설정 구역에 저장 (`sfx_muted`는 기존 키, 문양은 새 키 하나). 문양을 바꾸면 다음 판부터가 아니라 바로 게임판·NEXT/THEN에 반영. 아래 `닫기`
5. **버튼 상태·전환**
   - 모든 버튼·카드: 누름 (0.96배 + 테두리 밝게, 0.08초), 마우스 올림 (테두리 밝게), 키보드·패드 초점 테두리. 패널은 V3-1 Theme 스타일 (남색 반투명 + 하늘색 테두리 + 둥근 12px)
   - 시작 → 게임: 시작 화면이 0.25초에 사라지며 HUD가 나타난다. 결과 패널: 뒤 어둡게 0.2초 + 패널 0.92 → 1.0배 (살짝 튐) 0.25초. 랭킹·설정: 아래에서 0.25초에 올라오고, 닫을 때는 반대로
   - 전환 중 두 번 눌러도 한 번만 처리한다 (게임 두 번 시작 금지). 전환 때문에 입력이 0.3초 넘게 막히지 않는다
6. **세로로 긴 화면**: 네 화면 모두 V3-1처럼 `expand` + 안전 영역. 늘어난 높이는 로고와 카드 사이, 패널 위아래 여백으로 나눈다
- 바꾸지 않는 것: 게임 규칙·수치·물리, 구슬·배경·보드 그림 (V1·V2 — 시작 화면의 고리 행성은 V1 그림을 그대로 쓴다), 게임 중 HUD (V3-1), 이펙트 (V4), 저장 형식 (설정 키 하나 추가만)
- **검수**: 두 비율 (540×960·540×1170) 캡처 — `01` 시작, `04` 턴제 결과, `09` BLITZ 결과, `10` 랭킹, `11` 새 기록 결과, 새 `19_settings`, 새 `20_start_no_record` (기록 없는 첫 실행). 배치 테스트 (두 비율, 겹침 없음·안전 영역 안·누르는 칸 88px 이상), 점수 9,999,999와 랭킹 10줄이 잘리지 않음, 전환 중 두 번 누름 테스트, 문양 설정 저장·즉시 반영 테스트 (사용자 저장 파일 대신 임시 경로), 시작 화면 정지 상태 창 모드 5초 (수직 동기 끔) 프레임 p99 < 16.7ms, BLITZ 창 모드 측정, 물리 해시 동일

**V3-2 1차 결과** ([PR #69](https://github.com/jeongmo-dot/gravity_orb/pull/69)) — 래퍼 285/285, 스모크 3종 0, 캡처 40장 (두 비율 20장씩), 물리 해시 동일, 시작 화면 정지 p99 1.72ms, BLITZ 창 모드 p99 5.93ms (Codex). 결과 패널 (점수 쉼표·기록 2×2·버튼 세 개)과 설정 패널, `BEST —`, 문양 설정 저장·즉시 반영은 명세대로 나왔다. Claude 캡처 검수 (2026-10-11)에서 찾은 것:
- **시작 화면 로고와 행성이 겹친다**: 고리 행성 아래쪽이 `GRAVITY` 글자에 덮이고, 도는 작은 보라 천체(L2)가 `GRAVITY`·`ORB` 글자 위를 지나간다 (`01`·`20` 두 비율 모두)
- 시작 화면 행성이 **2D 미리보기 그림**(`OrbVisual`)이다 — 명세는 게임판 구슬과 같은 셰이더 (빛·그림자·림). 회신에 이 결정이 적혀 있지 않다
- **고르지 않은 모드 카드가 꺼진 것처럼 보인다**: 마지막 모드가 아닌 카드는 이름·설명이 회색이라 눌러도 안 될 것 같다 (`20`에서 BLITZ, `01`에서 CLASSIC). 카드 글자가 모두 Noto이고 이름·설명이 같은 크기다 (명세: 이름 Orbitron 700, 설명 작게, BEST 숫자 Orbitron)
- 시작 화면 아래쪽 약 1/3이 비어 있다 (9:16 캡처에서 카드 끝 y 565 → 아이콘 y 875). 아래 아이콘 세 개는 테마 없는 검은 네모
- **랭킹 패널** 위아래가 크게 비어 있고 (9:16 캡처에서 테두리 안 위아래 각 약 120px = 논리 240px, 9:19.5는 더 큼) 내용 덩어리가 가운데 떠 있다. `닫기`는 테마 없는 회색 막대. 선택된 탭은 명세(하늘색 채움 + 남색 글자)와 다르게 어두운 채움. 점수가 Noto
- 결과 기록 2×2의 값이 라벨과 같은 작은 Noto 글자다. 턴제 `턴 수`가 초록 (초록은 BLITZ 시간 전용). `블라스트` → 게임 용어는 `대폭발`. 새 기록은 배지가 아니라 호박색 글자

**V3-2 추가 요구 1**
1. **로고와 행성 분리**: 고리 행성(고리 포함)은 로고 글자 위쪽에 16 논리 px 이상 떨어져 온전히 보이게. 도는 천체는 로고 글자 뒤로 지나가거나 (그리는 순서) 궤도가 글자 영역을 피하게. 배치 테스트: 행성 사각형과 로고 글자 사각형이 겹치지 않음, 도는 천체가 한 바퀴 동안 글자 위에 그려지지 않음
2. **시작 화면 행성은 V1 셰이더로**: 게임판 구슬과 같은 `CelestialOrbArt` 머티리얼 (L4 청록, 빛·그림자·림·고리). 방법은 자유 (SubViewport 또는 3D 장면 노드). 작은 도는 천체도 같은 셰이더면 좋고, 어려우면 2D 그대로. 시작 화면 정지 p99 < 16.7ms 유지
3. **모드 카드**
   - 두 카드 모두 켜진 모양: 이름은 주색, 아이콘은 그 모드 색 (BLITZ 호박색, CLASSIC 하늘색). 마지막 모드는 그 모드 색 테두리 + 아주 옅은 같은 색 바탕으로만 구분
   - 글자 위계: 모드 이름 Orbitron 700 크게, 설명 (`시간 버티기` / `턴제 퍼즐`) Noto 작게·보조색, BEST 숫자 Orbitron
4. **시작 화면 세로 배치**: 로고 묶음 · 카드 · 아이콘 줄 사이 빈 공간이 비슷하게 (가장 큰 빈 공간이 가장 작은 것의 1.5배 이하, 두 비율 모두). 카드는 높이를 키워도 된다. 아래 아이콘 세 개는 V3-1 패널 스타일 (남색 반투명 + 하늘색 테두리 + 둥근 12px, HUD 소리 버튼과 같은 모양)
5. **랭킹 패널**: 패널 높이를 내용에 맞추거나 (위아래 안쪽 여백 각 40 논리 px 이하) 줄 높이를 늘려 채운다. 제목은 패널 위쪽에. `닫기`는 결과 패널의 테두리 버튼과 같은 스타일. 선택된 탭은 하늘색 `#BFE9FF` 채움 + 남색 글자. 점수 숫자는 Orbitron (쉼표)
6. **결과 기록 2×2**: 값은 Orbitron (라벨의 약 1.6배), 라벨은 Noto 작게·보조색. 초록은 BLITZ `버틴 시간`에만. `블라스트` → `대폭발`. 새 기록은 호박색 배지 (호박색 테두리·옅은 바탕, 점수가 다 오른 뒤 톡)
- 검수: 두 비율 캡처 `01`·`04`·`09`·`10`·`11`·`19`·`20` 다시, 배치 테스트 (행성·로고 비겹침, 빈 공간 비율), 시작 화면 정지 p99, 물리 해시 동일

**V3-2 추가 요구 1 결과** (PR #69 `409b613`) — Claude 재검수 (2026-10-11): 래퍼 285/285, 스모크 3종 0, 캡처 40장, 물리 해시 동일. 결과 패널 (Orbitron 값·`대폭발`·호박색 배지·초록은 BLITZ 시간만), 랭킹 (내용에 맞춘 패널·하늘색 탭·테두리 `닫기`·Orbitron 점수), 모드 카드 (두 장 모두 켜진 모양·Orbitron 이름), 테마 아이콘 줄, 셰이더 행성 (`SubViewport`, 숨으면 렌더 끔) 좋음. 실제 창에서 시작 화면을 2.5초 간격으로 세 번 찍어 보니 (캡처는 정지 한 장이라 안 보임) 남은 것:
- **행성이 바람개비처럼 돈다**: 자전을 화면 축(`rotation.z`)으로 돌려서 몸통 줄무늬가 화면 안에서 빙글 돌고, 고정된 고리와 각도가 계속 어긋난다
- **작은 천체가 그려진 궤도를 따라가지 않는다**: 궤도선은 납작한 타원인데 천체는 반지름 245·142의 원으로 돈다. 그래서 파란 L1이 `GRAVITY`의 `GR` 위를 지나간다 (2.5초 프레임). 배치 테스트는 궤도선 사각형만 봐서 통과했다
- 행성이 작다: 몸통 지름이 화면 폭의 약 14% (540 폭 캡처에서 약 76px, 명세 약 22%)
- 전체 묶음이 위로 쏠려 있다: 위 여백 (궤도 위 끝까지) 약 92px, 아래 여백 (아이콘 아래) 약 195px (9:16 캡처, 9:19.5는 113 / 245px)

**V3-2 추가 요구 2** (시작 화면만)
1. **자전 축**: 행성의 극축 (고리 면에 수직인 축, 고리 기울기와 맞춤)으로 돌려서 줄무늬가 고리 방향으로 흘러가게. 화면 축 회전 금지. 빛은 지금처럼 화면 기준 고정
2. **도는 천체는 그려진 궤도 타원 위로**: 같은 중심·반지름·기울기의 타원 위를 움직인다. 궤도 타원과 도는 천체 전체 (천체 반지름 포함)는 로고 글자 위 16 논리 px 이상. 배치 테스트는 한 바퀴를 64번 나눠 천체 위치를 재서 로고 글자 사각형과 안 겹치는지 본다
3. **행성 크기**: 몸통 지름을 화면 폭의 약 20~22%로 (고리는 그 비율대로). 궤도 타원도 같이 키우되 2번 조건 유지
4. **세로 균형**: 위 여백 (안전 영역 위 → 궤도 위 끝)과 아래 여백 (아이콘 줄 아래 → 안전 영역 아래)의 차이가 1.5배 이하. 두 비율 모두. 지금의 로고 · 카드 · 아이콘 사이 간격 조건도 유지
- 검수: 실제 창 시작 화면을 일정 간격으로 여러 장 찍어 (예: 0·2.5·5초) 자전 방향과 천체 위치 확인, 두 비율 `01`·`20` 캡처, 배치 테스트, 시작 화면 정지 p99, 물리 해시 동일

**V3-2 결과 — 병합** ([PR #69](https://github.com/jeongmo-dot/gravity_orb/pull/69) `9921ef6`, 2026-10-11): 추가 요구 2로 행성은 고리 면 법선(극축)으로 자전 (줄무늬 기울기가 고리와 맞은 채 흐름), 작은 천체는 그려진 타원식 위로 (한 바퀴 64점 검사, 로고와 최소 19.8px / 9:19.5 32.4px), 몸통 지름 화면 폭의 21.05%, 위/아래 여백 비 1.23 (9:16) · 1.41 (9:19.5). 캡처 도구에 시간차 시작 화면 `21_start_screen_t2_5`·`22_start_screen_t5_0` 추가. Claude 재검수: 래퍼 285/285, 스모크 3종 0, 캡처 44장 (두 비율 22장씩, `01`·`21`·`22`로 움직임 확인), 시작 화면 정지 p99 1.51ms, 물리 해시 동일. 남은 것 → V5: 행성 `SubViewport` 해상도
- **알려진 버그 (2026-10-11 사용자 제보 → #73)**: 결과 패널에서 랭킹을 열었다 닫으면 결과 패널 세 버튼이 모두 꺼진 채 남는다. 원인: `GameOverPanel._take_action()` 1회 잠금이 갔다가 돌아오는 랭킹 버튼에도 걸리고, 돌아올 때 풀지 않음 → **고침** ([PR #75](https://github.com/jeongmo-dot/gravity_orb/pull/75) `66adcc4`): `DebugHud._on_ranking_closed`가 결과로 돌아갈 때 `GameOverPanel.restore_actions_after_ranking()` 호출 — 결과 패널이 보일 때만 잠금을 풀고 세 버튼을 켠다. 회귀 테스트 `test_result_actions_restore_after_two_ranking_round_trips` (탭 전환 포함 왕복 2회, 다시 하기·모드 선택 신호 1회)

### V4 이펙트 — A+C 섞기 (#69)
사용자 (2026-10-11): 연출 시안 3개 (A 우주 물리 · B 네온 아케이드 · C 천체 현상) 중 **A+C 섞기** — 자주 일어나는 것은 A처럼 가볍게, 가끔 오는 큰 순간은 C처럼 크게
지금: 합체 = 그 색 입자 10개 + 색 효과 선·점 + 구슬 튐. 대폭발 = 흰·혼합색 토러스 고리 2개 (0.35초) + 색 파편 + 흰 불꽃 16개 + 점광원 + **화면 전체 흰 번쩍임** + 카메라 흔들림. L6·L7이 생겨도 따로 연출이 없다. 호령·점수 팝업은 V3-1 글꼴만 바뀜
단계: **V4-1** 반응 연출 + 그림 남은 것 (#69) → V4-2 호령·점수 팝업·색 효과 선·피버 (다음)

**V4-1 요구**
1. **작은 합체** (결과 L2~L5, A): 그 색 별가루 약 12개 (작은 점이 바깥으로 0.6~0.8초에 흩어지며 사라짐) + 얇은 하늘색 고리 하나 (결과 구슬 반지름에서 약 2배까지, 0.5초). 지금의 색 입자 10개를 대체. 구슬 튐·색 효과 표시는 그대로
2. **L6·L7 탄생** (결과 L6 이상 합체, C): 0.25초 동안 그 색·흰 입자 약 14개가 결과 구슬로 나선을 그리며 빨려 들어간 뒤 → 신성: 흰 중심 빛이 줄어들며 그 색 빛무리가 반지름 약 2.5배까지 퍼진다 (0.8초) + 얇은 고리. L7은 테두리에서 솟는 고리 모양 홍염 호 2~3개를 1초 더. 흔들림은 L4 대폭발 수준
3. **L4 대폭발** (A + 작은 C): 얇은 중력파 고리 2겹 (흰·하늘색, 그 레벨의 밀어내기 반경까지, 0.6초) + 두 색의 작은 성운 빛무리 (0.4초) + 두 색 파편. **화면 전체 번쩍임 없음**. 흔들림은 지금의 절반
4. **L5 이상 대폭발** (C): 폭발 지점 둘레만 흰 번쩍임 → 두 색이 섞인 **초신성 성운**이 밀어내기 반경까지 퍼지고 1.2초에 걸쳐 사라짐 + 얇은 중력파 고리 + 반짝이는 별 10여 개. 화면 전체 번쩍임은 L6 이상만, 알파 0.15 이하. 흔들림은 지금 수준
5. **번쩍임 안전**: 화면 전체 번쩍임은 1초에 3번을 넘지 않는다 (연쇄로 대폭발이 몰려도, BLITZ 피날레 포함). 넘치는 것은 건너뛴다
6. **성능**: 새 연출 노드는 모두 #57처럼 미리 만들어 재사용 (풀)하고 판 시작 전에 예열 (첫 사용 멈춤 없음). BLITZ 창 모드 (수직 동기 끔) p99 < 16.7ms·33.3ms 초과 0. 대폭발 3개 + 합체 10개가 한꺼번에 나는 장면도 따로 잰다
7. **그림 남은 것** (V1·V3-1에서 넘어온 것)
   - **L7 태양을 L6 별보다 밝고 화려하게**: 밝은 쌀알 무늬 (작고 밝은 세포 무늬가 천천히 끓음), 테두리 홍염은 덩어리 대신 고리 모양 호 2~4개. 같은 크기 캡처에서 L7 몸통 평균 휘도 > L6
   - **L5 바깥 얇은 테**가 몸통과 떨어져 보이는 틈을 없앤다
   - **NEXT/THEN L1 미리보기** (2D): 흰 금 간 별 모양 대신 게임판 L1 운석처럼 울퉁불퉁한 가장자리 + 점박이 무늬. 문양으로 읽히지 않게
- 바꾸지 않는 것: 규칙·수치·물리 (밀어내기 반경·힘 그대로 — 그림만), HUD·화면 (V3), 호령·점수 팝업·색 효과 선·피버 (V4-2), 소리
- **검수**: 새 캡처 `23_merge_stardust` (L3 합체), `24_birth_l6`, `25_birth_l7`, `26_blast_l4`, `27_blast_l6` — 각각 연출 중간 두 시점 (진행이 보이게) + `14_orb_codex`·`15_orb_closeup` 다시 (L7·L5) + NEXT L1이 보이는 장면. 화소 검사: L7 몸통 휘도 > L6, L4 대폭발 중 폭발 반경 밖 화면 평균 휘도 상승 0.03 이하, 화면 전체 번쩍임 1초 3회 이하 (자동). 창 모드 성능, 물리 해시 동일

**V4-1 1차 결과** ([PR #71](https://github.com/jeongmo-dot/gravity_orb/pull/71)) — 래퍼 288/288, 스모크 3종 0, 캡처 64장, 물리 해시 동일, 동시 부하 (대폭발 3 + 합체 10) p99 0.99ms, 번쩍임 1초 3회 제한·L4 반경 밖 휘도 상승 0.00006, 노드 사전 풀링 (Codex). 별가루·탄생 흡입·신성·번쩍임 정책·L5 테·NEXT L1 (흰 별 모양 없어짐)은 좋다. Claude 캡처 검수 (2026-10-11)에서 찾은 것:
- **고리가 모두 납작한 타원**이다 (합체 고리·신성 고리·대폭발 중력파, 가로:세로 약 1.4~2:1). 위에서 내려다보는 판에서 기울어진 행성 고리처럼 읽혀 L4 고리 행성과 헷갈린다 (V1에서 원형 폭발 외곽선을 지운 이유와 같음). 밀어내기는 판 위 원이므로 그림도 원이어야 한다
- **성운이 바람개비 소용돌이**다: 팔 8개가 한 점으로 모이는 회전 대칭 무늬라 은하·최면 무늬처럼 보이고, 명세의 초신성 (퍼지는 껍질)과 다르다. L6 대폭발 (`27_b`)에서는 이 소용돌이가 판 전체를 덮는다
- 연출 캡처가 빈 무대에서 찍혀 있어 **구슬이 가득한 판에서 성운이 구슬을 가리는지** 알 수 없다
- **L7 홍염이 머그잔 손잡이처럼** 보인다: 몸통과 같은 색의 굵고 불투명한 고리 3개가 같은 크기로 붙어 있다. L7 몸통 휘도가 L6보다 겨우 0.5% 높다 (0.79557 vs 0.79135) — "L6보다 밝고 화려하게"가 눈으로는 안 느껴진다
- 성능은 고정 120fps 동시 부하만 쟀다 — 명세의 BLITZ 창 모드 측정이 빠졌다

**V4-1 추가 요구 1**
1. **고리는 판 위의 원**: 합체·신성·대폭발 고리 모두 화면에서 가로:세로 1 ± 0.05. 테스트로 투영된 고리 비율 확인
2. **성운을 초신성 껍질로**: 부드러운 둥근 빛무리 + 바깥으로 퍼지는 조금 더 밝은 테두리 (껍질), 얼룩진 잡음 무늬로 두 색이 섞인다. 한 점으로 모이는 팔·회전 대칭 무늬·날카로운 중심 없음. L4의 작은 성운도 같은 모양으로 작게
3. **구슬이 가려지지 않게**: 성운·빛무리는 구슬 **뒤** (판 유리와 구슬 사이)에 그리고, 성운 안에서도 구슬이 또렷하게. 새 캡처 `28_blast_l5_crowded`·`29_blast_l6_crowded` (07처럼 구슬이 가득한 판에서 대폭발 중간, 두 시점) — 성운 영역의 구슬/배경 휘도 비 4 이상 (평소 07은 약 16)
4. **L7 홍염**: 가늘고 끝이 가늘어지는 밝은 호 2~4개, 반투명 발광 (몸통보다 밝은 노랑·흰색 쪽), 크기 제각각 (몸통 지름의 15~30% 높이), 천천히 모양·위치가 변함. 굵은 고리·같은 크기 금지. **L7 몸통 평균 휘도 ≥ L6 × 1.1** (`15` 같은 크기 비교)
5. **BLITZ 창 모드 측정** (`run_blitz_responsiveness_measurement`, 수직 동기 끔) p99·33.3ms 초과·입력 보고 (#64·#65와 같은 방식)
- 검수: 두 비율 캡처 `23`~`29` (각 두 시점) + `15`, 고리 비율·휘도·구슬/배경 비 화소 검사, 창 모드 성능, 물리 해시 동일

**V4-1 결과 — 병합** ([PR #71](https://github.com/jeongmo-dot/gravity_orb/pull/71) `bf14f32`, 2026-10-11): 추가 요구 1로 고리는 모두 판 위 원 (가로:세로 0.95~1.05), 성운은 회전 팔 없는 얼룩진 두 색 초신성 껍질로 구슬 뒤 (`z=-0.24`, 유리 `-0.31` 앞)에 그림, 혼잡 판 (`28`·`29`) 성운 영역 구슬/배경 휘도 비 L5 4.65 · L6 7.55, L7 홍염은 크기 다른 가는 반투명 호 3개, L7 몸통 휘도 L6의 1.137배. Codex 보고: 래퍼 291/291, BLITZ 창 모드 (수직 동기 끔) p99 4.31ms · 33.3ms 초과 0 · 입력 120/120, 동시 부하 p99 0.84ms, 물리 해시 동일. Claude 검수: Codex가 만든 캡처 (`15`·`23`~`29`)를 직접 확인하고 PR 상태 확인 후 병합 — 사용자 요청으로 이번엔 Claude 재실행 (래퍼·캡처·측정) 생략

### V4-2 호령·점수 팝업·색 효과·피버 — A+C 같은 원칙 (#71)
사용자 (2026-10-11): V4-2도 **A+C 원칙**으로 명세 작성 — 자주 나오는 것은 A처럼 깔끔하게, 드문 큰 순간만 C처럼 반짝이게
지금
- 호령 (`Hud._show_callout`): 콤보 단계 (턴제 3·5·8·12, BLITZ 5·10·15·20·30)마다 `NICE!`·`GREAT!`·`AMAZING!`·`INCREDIBLE!`·`UNSTOPPABLE!`이 화면 가운데에 0.6 → 1.15배로 튀고 0.8초에 사라진다. 단계와 상관없이 모양이 같다
- 점수 팝업 (`ScorePopup`): `+1240`처럼 **쉼표 없음**. 합체는 결과 색, 대폭발·잭팟은 흰 글자 + 금색 6px 테두리, 피날레는 금색. 1,000점 이상이면 좌우로 떨린다 (±3px)
- 색 효과 표시 (§12-P.2): PUSH 결과 색 고리 + 바깥 선 6개, PULL 수축 고리 + 점, SHAKE 판 테두리 떨림 + 초록 물결, LIFT 노란 빛줄기. V4-1의 합체 별가루·고리와 **고리가 두 겹**으로 겹친다
- 피버: `FEVER ×2` 주황 띠가 화면을 가로질러 들어왔다 사라지고, 화면 가장자리 주황 비네트 (알파 0.12), 판 테두리 주황 (V2). 끝날 때 띠 없이 사라짐. BLITZ 끝의 `TIME UP`은 호령과 같은 튐

요구
1. **호령 — 단계별로 커지게**
   - 1~3단계 (`NICE!`·`GREAT!`·`AMAZING!`, A): Orbitron 700, 얇은 어두운 테두리, 0.9 → 1.0배로 살짝 커지며 8 논리 px 떠오른 뒤 사라짐 (전체 0.8초). 색은 단계마다 하늘색 `#BFE9FF` → 주색 `#E8EEFF` → 호박색 `#FFB020`
   - 4~5단계 (`INCREDIBLE!`·`UNSTOPPABLE!`, C): 금색 `#FFD54A`, 글자 뒤 부드러운 금빛 (알파 0.3 이하), 네 갈래 별 반짝임 3~5개가 글자 둘레에서 깜박임, 1.0초. 5단계는 별이 한 바퀴 돌며 흩어짐
   - `TIME UP` (BLITZ 끝)도 같은 글꼴 체계로: 위험 빨강 `#FF3B30`, C처럼 별 대신 짧게 퍼지는 빨간 얇은 고리 하나
2. **점수 팝업**
   - 모든 숫자에 천 단위 쉼표 (`+48,600`). 계산식 줄 (`120 ×8 ×2`)도 Orbitron 500, 보조색
   - 보통 (A): 합체는 결과 색 (밝게), 어두운 얇은 테두리. 0.6 → 1.1 → 1.0배 튐 + 위로 떠오름은 그대로, **1,000점 이상 좌우 떨림은 없앰** (대신 크기 규칙으로 큰 점수가 커 보임)
   - 큰 점수 (C): 대폭발·잭팟·배수 ×8 이상·피날레는 금색 `#FFD54A` + 금빛 (알파 0.3 이하) + 작은 네 갈래 별 1~2개. 지금의 흰 글자 + 금색 6px 테두리는 없앰
3. **색 효과 표시를 별가루 체계로** (기능·반경·세기는 그대로, 그림만)
   - 합체 한 번에 **고리는 한 겹만**: 색 효과가 켜져 있으면 V4-1 합체 고리 대신 그 색 효과의 모양을 쓴다 (별가루는 그대로)
   - PUSH (빨강·보라·청록): 얇은 고리가 `r_result` → `R`로 퍼지고 별가루가 바깥으로. 빨강만 고리가 조금 더 굵고 밝게
   - PULL (파랑): 고리가 `R` → `r_result`로 줄어들고, 별가루가 안쪽으로 나선을 그리며 빨려 듦 (V4-1 강착과 같은 모양, 작게)
   - SHAKE (초록): 판 테두리 떨림은 그대로, 초록 물결은 판 끝까지 퍼지는 얇은 원 하나 (V4-1 고리와 같은 두께)
   - LIFT (노랑): `R` 안 구슬에서 중력 반대 방향으로 솟는 짧은 별가루 줄기 (빛줄기 대신)
4. **피버**
   - 들어올 때 (C): `FEVER ×2` 글자가 Orbitron 700 호박색으로 가운데에 나타나며, 얇은 빛줄기 하나가 화면을 가로질러 지나간다 (혜성 꼬리처럼, 0.4초). 띠 배경은 없애고 글자 둘레 별 반짝임 3개
   - 피버 동안 (A): 주황 비네트 대신 화면 가장자리의 **옅은 호박색 성운 빛** (알파 0.12 이하, 천천히 흐름). 판 테두리 주황은 그대로
   - 끝날 때: 성운 빛이 0.3초에 사라지고 `FEVER` 글자 없음 (지금처럼)
5. **읽기·안전**: 호령·팝업 글자는 V3-1 위 HUD·아래 받침과 겹치지 않는다. 화면 전체 번쩍임 없음 (V4-1 정책 그대로). 반짝임 별은 화면에 동시에 20개 이하
6. **성능**: 별 반짝임·빛줄기·성운 빛 노드는 미리 만들어 재사용 (풀)·예열. BLITZ 창 모드 (수직 동기 끔) p99 < 16.7ms·33.3ms 초과 0, 피버 중 측정 포함
- 바꾸지 않는 것: 규칙·수치·물리·점수 계산, 호령 단계 기준, HUD·화면 배치 (V3), V4-1 반응 연출 (합체 고리를 색 효과로 대신하는 것 제외), 소리
- **검수**: 두 비율 캡처 — `30_callout_great`, `31_callout_unstoppable` (두 시점), `32_popup_merge`, `33_popup_blast_big` (쉼표·금색), `34_color_push`·`35_color_pull`·`36_color_shake`·`37_color_lift` (각 두 시점), `38_fever_start` (두 시점)·`39_fever_running`, `08_blitz_time_up` 다시. 화소 검사: 합체 한 번에 고리 한 겹, 팝업 쉼표 (텍스트 검사), 반짝임 별 동시 20개 이하. 창 모드 성능, 물리 해시 동일

**V4-2 결과 — 병합** ([PR #73](https://github.com/jeongmo-dot/gravity_orb/pull/73) `3183bf2`, 2026-10-11, 1차 통과): 새 `CosmicSparkle`·`CosmicRing2D` (풀), 점수 팝업 세로 공간 180px (큰 숫자와 계산식 분리, 표시 위치는 위·아래 HUD 안전 구역 안으로 제한). Codex 보고: 래퍼 293/293, 캡처 106장, BLITZ 창 모드 (수직 동기 끔) p99 4.99ms · 피버 구간 p99 5.29ms · 33.3ms 초과 0 · 입력 120/120, 물리 해시 동일. Claude 검수: Codex 캡처 `30`~`39`·`08` 직접 확인 (호령 단계 색·금색 별, `+1,280`·금색 `+48,600`, 색 효과 고리 한 겹·PULL 수축·LIFT 고리 없음, 띠 없는 피버 빛줄기, 빨간 `TIME UP` 고리) — 재실행 없음. **V4 단계 끝**

## 12-W. 행성 컬렉션 — 색 = 행성 6종, 두 모드 같은 색 (기획서 0.12 — #74·#75)
사용자 (2026-10-12): "턴제와 블리츠 모두 같은 색깔 구성이 되어야 할 것 같고, 청록이랑 파랑이 잘 구분이 안돼" → "모든 구슬을 다 행성화해서 수성, 금성, 지구, 화성, 목성 등으로 표현하는 건 어떨까?" → Claude가 시안 두 개 (A 실제 행성 5 · B 게임 색 우선 5)를 작은 크기·흑백으로 비교 → **"B로 하면서 행성 크기는 모두 레벨 별로 같게 하면서 6종"**
- 원칙: **색 = 행성** (같은 행성끼리 합체, 다른 행성 같은 레벨은 대폭발 — 규칙 그대로), **레벨 = 크기 + 디테일** (크기 표 `level_radii`는 그대로, 모든 행성이 같음). 실제 행성 색은 빨강·주황·노랑에 몰려 작은 크기에서 헷갈리므로 **색이 먼저 읽히게 게임 색을 우선**하고 행성다움은 무늬로 살린다 (B)
- 6종 (인덱스 = `OrbTypes.OrbColor`, 코드 이름은 그대로 두고 그림·표시만 바꾼다)

| 인덱스 | 행성 | 표시 색 (가안) | 무늬 | 색 효과 (#74) | 색각 문양 |
|---|---|---|---|---|---|
| RED | **화성** | `#D0503A` | 붉은 사막·어두운 협곡 무늬, 흰 극관 | 밀어내기 (강, ×1.5) — 그대로 | ▲ |
| BLUE | **지구** | `#2F6FD6` | 파란 바다·어두운 초록 대륙·흰 구름 | **흔들기 (지진)** — 초록에서 옮김 | ● |
| GREEN | **천왕성** | `#35B97C` (민트 초록) | 세로로 흐르는 옅은 띠, 얇은 세로 고리선 (몸통 안) | **기본 밀어내기** | ■ |
| YELLOW | **금성** | `#E9C46A` | 두꺼운 구름 소용돌이 띠 | 띄우기 — 그대로 | ◆ |
| PURPLE | **해왕성** | `#6C5CE7` (보라빛, 실제보다 과장) | 가로 바람 띠, 어두운 폭풍 점 | **끌어당기기** — 파랑에서 옮김 | ★ |
| CYAN | **수성** | `#DCE3EC` (은백) | 크레이터 | 기본 밀어내기 (청록 그대로) | ✚ |

- 6번째로 천왕성 (민트 초록)을 고른 이유 (Claude): 다섯 색과 색상·밝기가 가장 멀다. 결과적으로 빨강·파랑·초록·노랑·보라는 지금 팔레트의 색상각 그대로 (#63 ΔE 검사를 통과한 축), 헷갈리던 청록만 은백 수성으로 바뀐다. 목성은 화성·금성과 같은 따뜻한 색이라 뺐다
- 색 효과 재배치는 행성 이미지에 맞춘 것이다 (지구 = 지진 흔들기, 해왕성 = 거대 행성의 끌어당김). 사용자가 바꾸자고 하면 표만 고친다

### 12-W.1 두 모드 같은 6색 + 색 효과 재배치 + 턴제 밸런스 (#74)
- 턴제 `spawn_color_weights` [1, 1, 1, 1, 0, 0] → **[1, 1, 1, 1, 1, 1]** (BLITZ와 같은 6색). BLITZ `blitz_spawn_color_weights`는 이미 6색
- 색 효과 (인덱스 순서 RED·BLUE·GREEN·YELLOW·PURPLE·CYAN)
  - `shock_color_modes` [PUSH, PULL, SHAKE, LIFT, PUSH, PUSH] → **[PUSH, SHAKE, PUSH, LIFT, PULL, PUSH]**
  - `shock_color_impulse_scale` [1.5, 0.8, 0.0, 1.0, 1.0, 1.0] → **[1.5, 0.0, 1.0, 1.0, 0.8, 1.0]**
  - `shock_color_radius_factor` [3.0, 3.0, 0.0, 3.0, 2.5, 2.5] → **[3.0, 0.0, 2.5, 3.0, 3.0, 2.5]**
  - 색 효과 그림 (V4-2)은 모드를 따라가므로 그대로 맞는다 (지구 합체 = 판 떨림 + 초록 대신 지구색 물결)
- **턴제가 어려워진다**: 4색 → 6색이면 같은 색끼리 만날 확률이 25% → 약 17%로 줄어 합체가 줄고 판이 빨리 찬다 (대신 다른 색 같은 레벨 대폭발은 늘어난다). 사용자 목표 **약 250턴** (#62)
  - 측정: 6색 + 재배치로 턴제 휴리스틱 봇 × 시드 101~112, 게임오버까지 — 생성 램프 `spawn_count_ramp_turns` **20 (지금) · 30 · 40 · 60** 네 조건. 보고: 판 길이 min/p50/max, 점수 p50, 대폭발·합체 수 p50, 끝 점유율, 벽/쌍·이탈·발산
  - 기본값 규칙: **p50이 250턴에 가장 가까운 조건**을 `spawn_count_ramp_turns` 기본값으로 (같으면 작은 값). 어느 조건도 150~400턴 밖이면 그대로 두고 `상태: 질문`
  - BLITZ도 같은 봇 측정 (#72와 같은 4봇 × 시드 101~112, 10분 상한) — 버틴 시간·점수 p50, 색 효과 재배치 전후 비교 (보고만)
- 물리 상태 해시: 생성 색이 바뀌므로 **턴제·BLITZ 해시가 달라지는 것이 정상**. 대신 물리 한도 (22시드 벽·쌍, 이탈·발산 0, 장기)를 그대로 통과하고 새 해시를 기록한다
- 저장: 규칙이 바뀌어 기록 비교가 어렵지만 랭킹 키는 그대로 이어서 쓴다 (사용자 결정 전까지. 필요하면 새 키)

**#74 결과 — 병합** ([PR #76](https://github.com/jeongmo-dot/gravity_orb/pull/76) `8c7d3af`, 2026-10-12, 1차 통과): 턴제 6색 (10,000회 생성에서 색마다 1,626~1,714), 색 효과 재배치. 턴제 측정 (휴리스틱 봇 × 시드 101~112, 게임오버까지, 48/48 끝남)

| `spawn_count_ramp_turns` | 판 길이 min / p50 / max | 점수 p50 | 합체 / 대폭발 p50 | 최대 벽 / 쌍 |
|---|---|---:|---|---|
| 20 (4색 때 기본) | 132 / 156 / 186턴 | 183,993 | 481 / 28 | 23.8 / 35.4px |
| 30 | 157 / 215 / 251턴 | 251,087 | 648 / 41 | 20.8 / 32.8px |
| **40 (선택)** | **237 / 266 / 328턴** | **318,392** | 781 / 51 | 21.4 / 33.6px |
| 60 | 287 / 331 / 443턴 | 221,178 | 838 / 56 | 23.0 / 39.6px |

- 6색이 되자 같은 생성 속도 (20)에서 판이 240 → 156턴으로 짧아졌다 → 규칙대로 250턴에 가장 가까운 **40**. 이탈·발산 0, 22시드 장기 벽/쌍 13.3/14.4px
- BLITZ (보고만, #72 대비 p50): 휴리스틱 0.3초 51.3초 (+5.2) · 0.6초 92.0초 (−0.4) · 무작위 0.3초 68.8초 (+7.9) · 0.6초 98.5초 (+18.3), 10분 도달 0/48. 지구 흔들기·해왕성 끌어당기기 재배치로 무작위 봇이 조금 오래 버틴다
- 상태 해시: 해시 검사는 생성기를 거치지 않고 여섯 색을 직접 놓아 #72와 같은 값. 6색 생성 결정론은 시드 101·777·4242의 `Spawner` 후보 순서 기준값을 새로 기록
- Claude 검수: 코드·설정·측정 보고 확인 — 재실행 없음

### 12-W.2 행성 그림 (#75)
- `CelestialOrbArt`의 "레벨마다 다른 천체" (운석·달·바위 행성·고리 행성·가스 거인·별·태양)를 **색마다 다른 행성**으로 바꾼다. 셰이더 방식 (구 셰이딩·화면 기준 빛·이음매 없는 3D 잡음·공유 머티리얼·1.0R 안)은 그대로
- **레벨 = 크기 + 디테일**: 몸통 비율 L1~L5 0.94R, L6 0.86R, L7 0.82R (남는 테두리에 빛)
  - L1~L2: 바탕색 + 대표 무늬 하나 (화성 극관, 지구 대륙 하나와 구름, 금성 구름 띠 두 줄, 해왕성 바람 띠 하나, 천왕성 세로 띠, 수성 크레이터 2~3개) — 작아도 행성이 읽히게
  - L3~L5: 위 표의 무늬 전부
  - L6: 그 행성 색의 은은한 테두리 빛 + 천천히 움직이는 무늬 (지구 구름 흐름, 금성 구름 소용돌이, 화성 먼지 폭풍, 해왕성 폭풍 점, 천왕성 띠 반짝임, 수성 표면 반사)
  - L7: 가장 밝은 테두리 빛과 반짝임 — "전설" 단계. 같은 행성 L7끼리면 지금처럼 잭팟
- 폭발 가능 표시 (L4+ 테두리 맥동), 색각 문양 (기본 끔, 켜면 위 표의 문양), NEXT/THEN 2D 미리보기 (같은 행성 그림의 2D판 — 금 간 별 모양 없음), 시작 화면 행성 (지구 L5 모습, 도는 작은 천체는 화성 L1·수성 L2)
- V4-1 연출: L7 탄생의 태양 홍염 호 → 그 행성 색의 빛 고리 한 번 (태양이 없어지므로). 별가루·성운 색은 새 표시 색을 따른다
- 기획서 표시 색은 가안 — **같은 레벨 최소 ΔE ≥ 25**, 색상각 오차·이음매 검사 (#63 기준) 를 지키도록 조정하고 실제 값을 보고. 흑백으로도 밝기가 갈리는지 (가장 가까운 두 행성의 밝기 차) 보고
- 바꾸지 않는 것: 규칙·수치 (#74 제외)·물리·크기 표, 배경·보드·HUD·화면·이펙트 구조
- **캡처 검사를 결정적으로** (#76에서 발견): 측정용 캡처는 셰이더 애니메이션 시간을 고정한다 (`TIME` 대신 스크립트가 넣는 시간 유니폼 등 — 방법 자유). 같은 장면을 두 번 찍으면 화소 측정이 같아야 한다. 별·태양용 `same_size_stars` 검사는 행성 L6·L7 검사 ("L7 테두리 빛 평균 > L6")로 바꾼다. **전체 캡처 (`-HudScenesOnly` 없이)가 끝까지 통과**해야 한다

**#75 1차 결과** ([PR #79](https://github.com/jeongmo-dot/gravity_orb/pull/79)) — 래퍼 299/299, **전체 캡처 124장 끝까지 통과** (측정 셰이더 시간 4.25초 고정, 같은 장면 두 번 바이트 동일), 표시 색 가안 그대로 (같은 레벨 최소 ΔE 41.2~47.0, 색상각 오차 9.7~15.4° — 검사 한도 25°, 이음매 비 0.85), L7/L6 테두리 빛 0.246/0.162, BLITZ 창 p99 3.81ms, 해시 동일 (Codex). 여섯 행성이 색과 무늬로 갈리고 붐비는 판 (`07`)에서도 읽힌다. 금성·해왕성·수성, 2D 미리보기, 시작 화면 지구, L6·L7 빛, L7 탄생 고리는 좋다. Claude 캡처 검수 (2026-10-12)에서 찾은 것 (`15` 확대):
- **천왕성이 수박처럼 보인다**: 초록 바탕에 진한 초록 세로 줄무늬 — 이 장르 (수박게임)에서 수박으로 읽히면 곤란하다
- **지구 무늬가 네모 블록**으로 깨진다: 대륙·구름이 정사각형 칸 모양 (잡음이 계단처럼 끊김) — 위성 사진이 아니라 위장 무늬처럼 보인다
- **화성에 미로 같은 검은 선**이 그물처럼 깔린다: 등고선·회로 무늬처럼 보여 붉은 사막 행성으로 안 읽힌다
- 흑백에서 화성(빨강)·해왕성(보라)의 밝기가 거의 같다 (상대 휘도 차 0.0005~0.014) — 색상·무늬가 크게 달라 색각 정상이면 문제없고, 문양을 켜면 구분된다. 지금은 그대로 둔다

**#75 추가 요구 1** (그림만, 색·규칙·크기 그대로)
1. **천왕성**: 진한 세로 줄무늬를 없애고 **부드러운 민트빛 대기** — 아주 옅은 띠 (밝기 차 5% 이내, 넓고 흐릿하게), 가장자리로 갈수록 살짝 밝은 대기 빛. 얇은 고리선은 유지하되 몸통을 가로지르는 기울어진 타원 고리로 (지금의 직선 대신). 수박·공 무늬로 읽히지 않게
2. **지구**: 대륙·구름을 **부드러운 경계**로 — 대륙은 큰 덩어리 2~3개 (해안선은 작은 굴곡), 구름은 흰 소용돌이·줄기 (반투명, 대륙 위로 흐름). 계단·사각 칸이 보이면 안 된다 (잡음 보간을 매끄럽게, 여러 크기 잡음 섞기)
3. **화성**: 검은 그물선을 없애고 **녹슨 붉은 바탕 + 부드러운 짙은 먼지 지대** 몇 곳 + 가로로 긴 협곡 한 줄 (마리너 협곡 느낌) + 흰 극관. 크레이터는 작은 것 몇 개만
4. 세 행성 모두 L1~L2 대표 무늬 (작아도 읽히게)와 L6·L7 움직임은 1차 규칙 그대로
- 검수: `14`·`15` 두 비율 다시 (세 행성 확대 비교), `07`·`13`·`01`, ΔE·이음매·결정적 캡처 그대로 통과, 물리 해시 동일

**#75 결과 — 병합** ([PR #79](https://github.com/jeongmo-dot/gravity_orb/pull/79) `29bf46d`, 2026-10-12): 추가 요구 1 반영 — 천왕성은 수박 줄무늬 없이 민트 대기 + 몸통 안 기울어진 타원 고리, 지구는 매끄러운 4옥타브 잡음의 비정형 대륙 2개·섬 + 반투명 구름 줄기, 화성은 녹슨 표면·먼지 지대·협곡·극관. 같은 레벨 최소 ΔE 38.8~47.5, 색상각 오차 ≤ 19.8° (한도 25°), 이음매 비 0.66, 전체 캡처 124장, 래퍼 300/300, BLITZ 창 p99 4.35ms, 해시 동일 (Codex). Claude 검수: Codex 캡처 `14`·`15`·`07`·`13`·`01` 직접 확인 — 재실행 없음
- 남은 것 → #78: **화성이 얼굴처럼 보인다** — 가운데를 가로지르는 곧은 협곡 한 줄 위에 비슷한 크기 크레이터 두 개가 좌우로 놓여 "눈 두 개 + 입"으로 읽힌다 (`15` L5, `14` L3~L7)

#### 12-W.3 화성 무늬 — 얼굴처럼 보이지 않게 (#78)
- 협곡: 가운데를 가로지르는 곧은 선 대신 **적도 아래로 비켜 10~20° 기울어진** 길이 몸통 지름의 약 50%, 폭이 고르지 않고 가지 1~2개, 양 끝은 흐려진다. 대비는 지금보다 약하게
- 크레이터: 3~5개를 크기·간격 제각각으로 흩는다. 협곡 위에 좌우로 짝을 이루는 비슷한 크기 점 두 개 금지 (세로축 대칭 배치 금지)
- 극관·먼지 지대·색은 그대로. 2D 미리보기도 같은 원칙
- 구슬은 굴러서 돌기 때문에 캡처의 한 방향만이 아니라 **여러 회전 (0·90·180·270°)**에서 얼굴로 읽히지 않는지 본다 — 새 캡처 `47_mars_rotations` (L5 화성 네 방향, 두 비율)
- 검수: `14`·`15`·`47`, ΔE·이음매·결정적 캡처 그대로 통과, 물리 해시 동일

**#78 결과 — 병합** ([PR #80](https://github.com/jeongmo-dot/gravity_orb/pull/80) `970c47b`, 2026-10-16): 3D 협곡은 적도 아래 (`y = −0.18`) 15° 기울기, 길이 지름 약 50%, 잡음 가변 폭·양 끝 감쇠·가지 1개, 대비 0.82 → 0.58. 크레이터 4개 비대칭. 2D 미리보기도 같은 방향·가지·크레이터 4개. ΔE·색상각·이음매 #75와 같음, 래퍼 300/300, 해시 동일, 캡처 126장 (Codex). Claude 검수 (Codex 캡처 `47` 두 비율 확대·`15`·`14`, 재실행 없음): **네 방향 모두 얼굴로 읽히지 않는다** — 목표 달성. 남은 다듬기 → #82:
- 3D 가지가 본줄기를 **가로질러** 얇은 ✕ 모양이 된다 (가지 식이 본줄기와 기울기만 다른 직선이라 교차) — 골짜기보다 긁힌 자국·표시처럼 보인다. 폭 변화도 거의 보이지 않는다 (2D 미리보기는 한쪽으로 갈라지는 Y라 괜찮다)
- 극관 경계가 곧은 선이라 굴러서 옆으로 오면 (`47` 90°·270°) 가장자리에 곧은 흰 띠가 붙은 것처럼 보인다 — 잘린 면·그림 오류처럼 읽힌다 (#78 범위 밖, #75부터)

#### 12-W.4 화성 협곡·극관 다듬기 (#82, 작은 마무리)
- 협곡 가지: 본줄기에서 **한쪽으로만 갈라지는 Y** (가로지르는 ✕ 금지) — 2D 미리보기와 같은 모양. 가지는 본줄기보다 가늘고 끝으로 갈수록 흐려진다
- 협곡 폭: 가장 넓은 곳이 가장 좁은 곳의 **2배 이상**으로 눈에 보이게, 전체 평균 폭은 지금의 약 1.5배 — 긁힌 선이 아니라 골짜기로 읽히게. 가장자리는 부드럽게, 대비는 지금 (0.58) 그대로
- 극관: 경계를 잡음으로 **울퉁불퉁하게** (위도 ±0.04 정도 흔들림), 둥근 모자처럼 — 옆·아래로 돌아가도 곧은 띠나 잘린 면으로 보이지 않게. 2D 미리보기 극관도 같은 원칙
- 바꾸지 않는 것: 협곡 위치·기울기·길이, 크레이터, 먼지 지대, 색, 다른 행성, 규칙·물리
- 검수: `47`·`15`·`14` 두 비율, ΔE·이음매·결정적 캡처 그대로, 물리 해시 동일

**#82 결과 — 병합** ([PR #85](https://github.com/jeongmo-dot/gravity_orb/pull/85) `4c033d6`, 2026-10-17): 3D 가지가 `x < −0.10`에서 한쪽으로만 벌어지는 Y (폭 0.026 → 0.010), 본줄기 반폭 `0.028 + 잡음 × 0.044` (최소/최대 비 2.57, 평균 1.47배), 극관 경계에 3D 잡음 ±0.04 (2D는 사인 합 ±0.04). ΔE·이음매·결정적 캡처·해시 그대로, 래퍼 332/332 (Codex). Claude 검수 (`47` 두 비율 확대·`15`, 재실행 없음): 가지 교차 (✕) 없어지고 협곡이 넓어져 긁힌 선보다 골짜기로 읽힌다
- 남은 것 (다음 단계 V5 후보, 지금은 두지 않음): 극관은 경계가 조금 울퉁불퉁해졌지만 **옆으로 돌아가면 여전히 가장자리 흰 띠**처럼 보인다 (`47` 90°·270°). 자전축이 화면 평면 안에 있어 극관을 늘 적도에서 옆으로 보기 때문 — 위도 원은 정사영에서 곧은 선이 된다. ±0.04 (Claude 명세 수치)로는 부족했다. 고치려면 자전축을 화면 쪽으로 20~30° 기울여 극관이 원판 안쪽의 둥근 조각으로 보이게 하는 편이 맞다 → 사용자 "눈에 잘 띄여" → §12-W.5 (#86)

#### 12-W.5 화성 극관 — 기울어진 극에서 둥근 조각으로 (#86)
사용자 (2026-10-17): 극관이 옆에서 흰 띠처럼 보이는 것이 "눈에 잘 띄여" → 지금 고친다 (V5 후보에서 올림)
- 원인: 구슬은 화면 수직축 (z)으로만 구른다 (`Orb3D` 각속도 z만). 극관은 물체 좌표 `y` 기준 위도 원이라 극이 늘 화면 평면 안 (원판 가장자리)에 있고, 위도 경계가 정사영에서 곧은 선이 된다 → 어느 각도에서도 가장자리 띠
- 바꿈: 극관만 **화면 쪽으로 35° 기울어진 극축** 기준으로 그린다 — `pole = normalize(vec3(0, cos 35°, sin 35°))` (물체 좌표. 구슬이 z축으로 돌아도 극의 z 성분이 그대로라 늘 보는 쪽으로 기울어 있다)
  - `polar = dot(body_position, pole) + (잡음 − 0.5) × 0.06`, `polar_cap = smoothstep(0.866, 0.914, polar)` — 각반지름 약 24~30°. 기울기 35°가 각반지름보다 커서 **극관 전체가 원판 안쪽**에 들어와, 가장자리 가까이 둥글고 납작한 흰 조각으로 보인다 (가장자리를 잘라 먹지 않음)
  - 경계 잡음은 지금 극관 잡음 그대로 (3D 이음매 없는 잡음), 색·세기 (0.82) 그대로
  - 협곡·크레이터·먼지 지대·기본 방향은 그대로 (물체 `y` 기준). 극관만 바뀐다
- 2D 미리보기 (`OrbVisual._draw_mars_polar_cap`): 위쪽 띠 대신 원판 안쪽 위 (중심에서 `0.60r` 위) **납작한 둥근 조각** (가로 반지름 `0.36r`, 세로 `0.20r`, 경계 사인 흔들림 그대로)
- L1~L2 대표 무늬 규칙은 그대로 (극관이 보이는 레벨도 그대로)
- 검수: 캡처 `47` 두 비율 네 방향 모두 극관이 원판 안쪽 둥근 조각 (가장자리 흰 띠·곧은 경계 없음), `15`·`14`·`13` (2D NEXT), ΔE·이음매·결정적 캡처 그대로, 물리 해시 동일
- **#86 결과 — 병합** ([PR #88](https://github.com/jeongmo-dot/gravity_orb/pull/88) `eed646c`, 2026-10-17): 명세 식 그대로 (35° 극축·잡음 0.06·`smoothstep(0.866, 0.914)`), 2D는 `0.60r` 위 `0.36r × 0.20r` 닫힌 조각. ΔE 38.82·이음매 0.66·결정적 캡처·해시 그대로, 래퍼 339/339, 검증 빌드 `-Debug`만, 마지막 실행 전체 캡처 (Codex). Claude 검수 (`47` 두 비율 확대, 재실행 없음): **네 방향 모두 극관 전체가 원판 안쪽의 둥근 흰 조각** — 가장자리 띠 없어짐

## 12-G. 세 번째 모드 GRAVITY SLIME (기획서 0.13 — #79~#81)

사용자 (2026-10-16): 별도 프로토타입 「Gravity Slime」 README 분석 후 "그래비티 슬라임 모드를 하나 더 추가해서 만들어서 그대로 적용하는 설계 문서 만들어줘"

### 12-G.0 원칙
- **원본**: `Restfulnap/GravityOrb` 커밋 `8062ddc` — `prototype/main.gd` (1,061줄, Godot 4 2D) + `prototype/README.md`. 로컬 사본 `C:\work\GravityOrb-main\GravityOrb\prototype`. **README와 코드가 다르면 `main.gd`가 기준**이다 (예: `BALANCE_REPORT.md`의 보드 520×690·"같은 색 MAX 소멸"은 옛 값, 코드는 550×700·색 무관)
- **그대로 옮기는 것**: 규칙, 물리 감각 (원본 자체 위치 보정 솔버), 수치, 그림, 연출, 소리, 문구. **이 모드는 밸런스를 다시 맞추지 않는다** — 측정은 관측만 하고, 수치 변경은 플레이 후 사용자 결정으로 따로 한다
- **우리 것을 쓰는 것 (앱 껍데기)**: 시작 화면 진입, 결과·랭킹·저장, 소리 끄기, 입력 (스와이프 + 방향키/WASD, `InputRouter`), 턴 입력 표시 (§12-T.2 — 사용자 2026-10-12 "입력을 받을 때와 못 받을 때를 잘 구분"), 진동, 글꼴 (Orbitron + Noto Sans KR), 해상도·비율 대응
- **이 모드에 넣지 않는 것**: Jolt 물리·`Board3D`·`Orb3D`·`ReactionRules`·`Spawner`·`TurnManager`, 행성 그림, 색 효과, 대폭발, 콤보 ×128·위험 배수, BLITZ 시계, 색각 문양, V4 연출, 보드 기울기·스와이프 잔상·우주 배경. 이 모드의 코드는 **기존 두 모드의 결과(물리 해시)를 바꾸지 않는다**
- 원본 저장소에는 라이선스 파일이 없다 → **원본 코드를 이 저장소에 복사하지 않는다.** 이 명세의 규칙·수치로 우리 구조에 다시 구현한다. 패리티 검사 (§12-G.9)는 로컬 원본을 읽기만 한다

### 12-G.1 구조
- 새 장면 `scenes/SlimeMain.tscn` — 2D 전용 (3D 카메라·Jolt 없음). 바탕색은 원본 `Color(0.025, 0.035, 0.075)`
  - `scripts/slime/SlimeSim.gd` — **순수 규칙·물리** (`RefCounted`: 노드·입력·소리·그리기 없음). 상태, `step(dt)`, `start_turn(dir)`, 사건 목록 (생성·흡수·MAX 완성·MAX CLEAR·충돌음·해금·입장 취소·FINAL MOVE·게임오버·메시지). 테스트·봇·패리티는 이것만 쓴다
  - `scripts/slime/SlimeGame.gd` — 장면 진행: 고정 간격 `step`, 입력 연결, 사건을 그림·소리·HUD로 넘김
  - `scripts/slime/SlimeView.gd` — 보드·슬라임·연출 그리기 (`Node2D._draw`, §12-G.6)
  - `scripts/slime/SlimeHud.gd` — 원본 HUD 문구·배치 (§12-G.5)
  - `config/SlimeConfig.gd` + `config/slime_config.tres` — 수치 (§12-G.2). 필드가 많고 다른 모드와 섞이지 않게 `GameConfig`에 넣지 않는다. 값 변경은 다른 수치와 같이 §12-G.2 표 갱신과 같은 커밋
- **좌표 단위 = 원본 좌표**: 시뮬레이션은 원본 640×920 화면의 px로 계산한다 (보드 `Rect2(45, 180, 550, 700)`). 화면에 그릴 때만 §12-G.5의 배율 `k`를 곱한다 → 수치와 결과가 원본과 숫자 그대로 같다
- **고정 간격 1/60초**: 원본은 60Hz `_physics_process`다. 우리 엔진은 120Hz이므로 `SlimeGame`이 누적기로 정확히 1/60초마다 `step(1.0 / 60.0)`을 부른다 (한 프레임 최대 4회). 엔진 틱이 60이든 120이든 같은 해시
- **난수 둘**:
  - 게임 난수 (`--jolt-seed=` 인자 공유, 없으면 무작위 시드): 묶음 개수·레벨·색 주머니 섞기·첫 입장 lane 섞기와 흔들림·MAX CLEAR의 거리 0 방향. 섞기는 `Array.shuffle()` (전역 난수) 대신 이 난수로 Fisher–Yates
  - 그림 난수: 호흡 위상·속도, 입자 각도·속도·크기·밝기. 그림을 켜고 꺼도 게임 진행이 같아야 한다
  - 원본은 둘이 같은 난수라 뽑는 순서는 다르지만, 분포와 규칙은 같다
- **모드**: `GameConfig.GameMode`에 `SLIME` (값 2, 기존 값 유지) 추가. `--mode=slime`이면 바로 시작. 시작 화면에서 고르면 `SlimeMain`으로 장면을 바꾼다. 다시 하기는 `SlimeMain`을 다시 불러오고, 모드 선택은 시작 화면 (`Main3D` + 시작 화면 강제)으로 간다

### 12-G.2 수치 (`SlimeConfig` — 원본 값 그대로)
단위: 길이 = 원본 px, 시간 = 초, 감쇠 = 1/60초당 비율

| 묶음 | 필드 | 값 | 원본 |
|---|---|---|---|
| 보드 | `board_rect` | `Rect2(45, 180, 550, 700)` | `BOARD` |
| 물리 | `gravity` | 2,220 px/s² | `GRAVITY` |
| | `damping` | 0.981 | `DAMPING` |
| | `lateral_damping` | 0.935 | 옆 성분 감쇠 |
| | `rest_speed` | 34 px/s | `REST_SPEED` |
| | `settle_hold` | 0.18 | 정지 유지 시간 |
| | `soft_stop_start` / `soft_stop_factor` | 1.34 / 0.82 | `SOFT_STOP_START` |
| | `max_simulation_time` | 1.85 | `MAX_SIMULATION_TIME` |
| | `wall_restitution` | 0.23 | 벽 반발 |
| | `pair_impulse_factor` | 0.61 | 쌍 반발 |
| | `solver_iterations` | 4 | 쌍 보정 반복 |
| | `touch_margin` | 0.75 px | 닿음 판정 여유 |
| | `turn_kick_speed` | 80 px/s | 턴 시작 밀기 |
| 쌓임 미끄러짐 | `stack_slip_speed` | 105 px/s | `STACK_SLIP_SPEED` |
| | `stack_slip_alignment` | 0.18 | `STACK_SLIP_ALIGNMENT` |
| | `stack_slip_min_axis` | 0.72 | 중력축 거리 하한 비 |
| | `stack_slip_max_impulse` | 24 px/s | |
| | `stack_slip_lower_share` | 0.12 | 아래쪽 반작용 비 |
| | `stack_slip_nudge` | 0.22 px | 위치 편향 |
| 크기 | `level_radii` | 31.5, 42, 54, 68, 84, 101, 112 | `LEVEL_RADII` (L0~L6) |
| | `pre_max_radius` | 108 | `PRE_MAX_RADIUS` |
| | `max_mass` | 64 | `MAX_MASS` (#85부터 MAX 기준. 상한은 아님 — §12-G.12) |
| | `max_growth_enabled` / `max_growth_exponent` / `max_growth_radius_cap` | true / 0.2 / 165 | #85 새 필드 (원본에 없음) |
| 생성 | `max_slimes` | 40 | 안전 한도 |
| | `spawn_level_weights` | 0.70, 0.25, 0.05 | L0·L1·L2 |
| | `crowd_thresholds` | 10, 16 | 수 < 10 / < 16 |
| | `crowd_counts` | 3 (30% → 4), 2, 1 | |
| | `turn_floors` | 30턴 → 최소 2, 60턴 → 최소 3 | |
| | `color_bag_copies` | 2 | 색마다 2개씩 |
| | `spawn_speed` | 90 px/s | 입장 속도 |
| | `intro_first_delay` / `intro_interval` | 0.03 / 0.30 | 순차 입장 |
| | `intro_abandon_after` | 0.9 | 입구 막힘 대기 한도 |
| | `entry_margin` | 5 px | 입구 비어 있음 여유 |
| 해금 | `start_colors` | 3 | |
| | `unlock_scores` | 50,000 / 150,000 / 300,000 / 500,000 | `COLOR_UNLOCK_SCORES` |
| | `unlock_grace_waves` / `unlock_grace_count` | 2 / 2 | 해금 뒤 묶음 2번 최대 2개 |
| | `unlock_forced_slots` | 2 | 새 색을 묶음 앞 2개에 |
| 점수 | `score_per_mass` | 25 | 흡수 기본 = 합친 질량 × 25 |
| | `max_reach_bonus` | 2,500 | 처음 MAX가 될 때 |
| | `max_clear_score` | 7,500 | |
| | `chain_step` / `chain_max_steps` | 0.25 / 7 | 최대 ×2.75 |
| 합체 | `merge_velocity_keep` | 0.35 | 합친 속도 비 |
| MAX CLEAR | `clear_push_radius` / `clear_push_speed` | 165 px / 180 px/s | |
| 입구 경고 | `entry_danger_clearance` / `entry_caution_clearance` | 15 / 70 px | 빨강 / 노랑 |
| 첫 입장 | `initial_count` | 4 | `INITIAL_SLIMES` |
| | `initial_levels` / 색 | L0, L0, L0, L1 / `i % 3` | |
| | `initial_lanes` | 0.08, 0.22, 0.36, 0.50, 0.64, 0.78, 0.92 (섞어 앞 4개) | |
| | `initial_lane_jitter` / 자름 | ±0.035 / [0.07, 0.93] | |
| | `initial_delay` | `0.10 + i × 0.105 + U(0, 0.055)` | |
| 충돌 세기 | 벽 / 쌍 / 소리 문턱 / 쿨다운 | `abs(v) / 900` / `−rel / 850` / 0.22 / 0.09초 | 그림·소리용 |

색 (원본 순서 = 해금 순서): 0 초록 `#59E2AB`, 1 파랑 `#72A7FF`, 2 분홍 `#FF7595` (시작 3색), 3 주황 `#FFAD63` (5만), 4 보라 `#BC86FF` (15만), 5 노랑 `#FFE77A` (30만), 6 청록 `#53DCDE` (50만). 레벨마다 `lightened(level × 0.018)`

### 12-G.3 규칙·물리 (원본 처리 순서 그대로)
**한 틱 `step(dt)`** — 순서가 결과를 바꾸므로 그대로 지킨다
1. 충돌음 쿨다운·중력 섬광 시간 감소
2. 그림 상태 갱신 (§12-G.6 — 물리에 쓰이지 않는다)
3. 입장 대기열 처리 ("입장")
4. 움직이는 중이 아니면 여기서 끝
5. 대기열이 비었으면 `simulation_time += dt`
6. 슬라임마다 배열 순서대로:
   - `v += g × gravity × dt`, `v *= damping^(dt×60)`
   - 중력 성분 `(v·g)g`와 옆 성분으로 나눠 옆 성분만 `× lateral_damping^(dt×60)`
   - 대기열이 비었고 `simulation_time > soft_stop_start`면 `v *= soft_stop_factor^(dt×60)`
   - `p += v × dt`
   - 굴림·변형 목표 갱신 (그림), 벽 처리
7. 쌍 처리를 `solver_iterations`번
8. 모든 슬라임 벽 처리 한 번 더
9. 모두 `|v| ≤ rest_speed`면 `settle_time += dt`, 아니면 0
10. 대기열이 비었고 `settle_time > settle_hold` 또는 `simulation_time ≥ max_simulation_time`이면 턴 끝

**벽**: 축마다 `[보드 시작 + r, 보드 끝 − r]` 밖이면 그 축 위치를 경계로 돌리고, 그 축 속도를 안쪽으로 `|v_축| × wall_restitution`. 충격 (그림) `impact = max(impact, clamp(|v_축| / 900, 0, 1))`

**쌍 처리** (`i < j` 이중 반복, 배열 순서대로)
- `Δ = p_b − p_a`, `d = |Δ|`, `target = r_a + r_b`
- `d ≤ target + touch_margin`이면:
  1. 둘 다 `mass == max_mass` → **MAX CLEAR** (색 무관). 처리 후 `j = i + 1`로 다시
  2. 같은 색이고 둘 다 `mass < max_mass` → **흡수**. 처리 후 `j = i + 1`로 다시
- 반응이 없었고 `d < target`이면:
  - 법선 `n = Δ/d` (`d ≤ 0.01`이면 `(1, 0)`), 겹침 `target − max(d, 0.01)`의 절반씩 서로 밀어냄
  - 쌓임 미끄러짐 (아래)
  - `rel = (v_b − v_a)·n < 0`이면: 세기 `s = clamp(−rel/850, 0, 1)`. `s > 0.22`이고 쿨다운 0이면 충돌음 사건 (쿨다운 0.09초). 두 슬라임 `impact = max(impact, s)`. `J = n × rel × pair_impulse_factor`, `v_a += J`, `v_b −= J` — **질량을 보지 않는다**
- 배열 조작: 흡수는 두 슬라임을 지우고 (큰 인덱스 먼저) 새 슬라임을 **맨 뒤에 추가**, MAX CLEAR는 둘만 지운다. 반복 순서가 원본과 같아야 패리티가 맞는다

**쌓임 미끄러짐** (중력축으로 거의 일직선인 접촉만 — 수직 탑 방지)
- `t = (−g.y, g.x)`. `|Δ·t| > target × stack_slip_alignment` 또는 `|Δ·g| < target × stack_slip_min_axis`면 하지 않는다
- 위쪽 = `p·g`가 작은 쪽. `offset = (p_위 − p_아래)·t`, `σ = sign(offset)`. `|offset| < 0.5`면 `σ = −1 if (i + j + 위.color + 위.mass) % 2 == 0 else +1`
- `cur = (v_위·t) × σ < stack_slip_speed`면 `imp = min(stack_slip_max_impulse, stack_slip_speed − cur)`, `v_위 += tσ × imp`, `v_아래 −= tσ × imp × stack_slip_lower_share`
- 위쪽 위치는 항상 `tσ × stack_slip_nudge`만큼 옮긴다

**흡수** (같은 색, 둘 다 MAX 아님 — 크기 무관)
- `raw = m_a + m_b`, `m = min(raw, max_mass)` — 64를 넘는 몫은 버린다
- 위치 = 중점, 속도 = `(v_a + v_b) × merge_velocity_keep`, 색 그대로
- 레벨 = 질량으로: 1 → L0, 2~3 → L1, 4~7 → L2, 8~15 → L3, 16~31 → L4, 32~63 → L5, 64 → L6 (MAX)
- 반지름 = 질량 보간: `L = level(m)`. L6이면 112. 아니면 `lerp(R[L], 다음, (m − 2^L) / 2^L)` — 다음 = `R[L+1]`, L5면 `pre_max_radius` 108 (64가 되는 순간 112로 한 번 더 커진다)
- 기본 점수 `raw × score_per_mass`. 두 재료 모두 64 미만이고 결과가 64면 `+ max_reach_bonus`, 그 색을 **MAX 완성 색**에 추가 (한 번 완성하면 지워져도 유지), 화면 흔들림 4px·0.16초
- → 연쇄 점수 → 점수에 더하고 해금 확인
- 그림: 새 슬라임 `visual_scale = clamp(max(r_a, r_b) / r_새 × 0.88, 0.68, 0.88)`, `merge_glow = 1`

**MAX CLEAR** (MAX 둘이 닿음, 색 무관)
- 둘 다 지우고 새 슬라임 없음. 기본 점수 `max_clear_score` → 연쇄 점수
- 중점 `c`에서 `clear_push_radius` 안의 슬라임: `v += 방향(c → p) × (1 − d / 165) × clear_push_speed` (`d ≤ 0.01`이면 게임 난수로 무작위 방향), `impact = max(impact, 0.28)`
- 화면 흔들림 9px·0.34초

**연쇄 점수**
- `turn ≤ 0` (첫 입장)이면 기본 점수 그대로, 연쇄를 세지 않는다
- 아니면 `chain += 1`, 배수 `1 + min(chain − 1, chain_max_steps) × chain_step` (1.00, 1.25 … 최대 2.75), 점수 `round(기본 × 배수)` (반올림은 0에서 먼 쪽)
- 연쇄는 턴 시작에 0. 판 최고 연쇄와 전체 최고 연쇄를 기록

**턴 시작** `start_turn(dir)` — 움직이는 중·게임오버가 아닐 때만. 같은 방향도 받는다
- 중력 = dir, `turn += 1`, `chain = 0`, 중력 섬광 0.28초, 중력음
- FINAL MOVE 대기 중이었으면 FINAL MOVE 진행으로 바꾸고 **생성 없음** (NEXT 묶음은 그대로 남는다)
- 아니면 NEXT 묶음을 입장 대기열로: 개수 `min(묶음 수, max_slimes − 현재 수)`, 반대편 벽 **가운데** (lane 0.5), 예정 시각 `intro_first_delay + i × intro_interval`. NEXT를 비운다
- 움직임 시작, `settle_time`·`simulation_time` 0
- 판에 있는 **모든 슬라임에 `v += dir × turn_kick_speed`** (대기열 슬라임은 아직 없다)

**입장** (매 틱, 대기열 맨 앞부터 차례로)
- 경과 시간이 맨 앞의 예정 시각에 닿으면: 입구가 비어 있으면 생성하고 다음 것으로, 아니면 기다린다. 예정 시각보다 `intro_abandon_after` 넘게 기다리면 **대기열 전체를 버린다** (메시지 "투입 중단 · 현재 슬라임 이동 후 공간을 확인합니다", 1.2초) — 버려진 슬라임은 들어오지 않는다
- 입구 위치 (중력 g, 반지름 r, lane λ): DOWN `(lerp(left + r, right − r, λ), top + r)`, UP `(…, bottom − r)`, RIGHT `(left + r, lerp(top + r, bottom − r, λ))`, LEFT `(right − r, …)`
- 비어 있음 = 모든 슬라임이 `|p − 입구| ≥ r_s + r + entry_margin`
- 생성: 그 입구에 질량 `2^레벨`, 속도 `g × spawn_speed`, 그림 `visual_scale 0.35`

**턴 끝**
- 움직임 멈춤, **모든 속도 0**
- FINAL MOVE 진행 중이었으면: 네 입구가 모두 막혀 있으면 NEXT를 비우고 **게임오버** ("보드가 가득 찼습니다"). 아니면 계속 ("공간 확보 성공 · 다음 중력을 선택하세요")
- 아니면: 네 입구가 모두 막혔으면 **FINAL MOVE 대기** ("FINAL MOVE · 한 번의 중력 이동으로 공간을 만드세요"), 아니면 보통 ("다음 중력을 선택하세요")
- 게임오버가 아니면 NEXT가 비어 있을 때만 새로 뽑는다
- 네 입구가 모두 막힘 = 네 방향 모두 L0 반지름 (31.5)·lane 0.5 입구가 비어 있지 않음
- 이 모드에는 "막힌 방향으로 밀면 게임오버"가 없다. 막힌 방향으로도 중력은 바뀌고, 들어올 슬라임은 기다리거나 버려진다

**NEXT 묶음 뽑기** (턴 끝 시점의 `turn`·슬라임 수 기준. 처음 묶음은 시작할 때 수 0·turn 0)
- 남은 자리 `max_slimes − 수` ≤ 0이면 빈 묶음
- 개수: 수 < 10 → 3 (30% → 4), < 16 → 2, 그 외 1 → `turn ≥ 60`이면 최소 3, `turn ≥ 30`이면 최소 2 → 해금 완화가 남아 있으면 최대 2 (완화 −1) → 남은 자리로 자름
- 슬라임마다 **색을 먼저** (주머니), **그다음 레벨** (L0 70% · L1 25% · L2 5%). 새 색이 있으면 묶음 앞 `min(unlock_forced_slots, 개수)`개의 색을 새 색으로 바꾼다 (주머니에서 꺼낸 색은 버림). 다 뽑고 새 색 표시를 지운다
- 색 주머니: 비면 해금된 색을 `color_bag_copies`개씩 넣어 섞고, 뒤에서 하나씩 꺼낸다

**색 해금**: 흡수·MAX CLEAR로 점수가 오를 때마다 확인. 해금 수 < 7인 동안 `점수 ≥ unlock_scores[해금 수 − 3]`이면 해금 수 +1, 그 색을 새 색으로, 주머니를 비우고, 완화 2회. 한 번에 여러 개 열릴 수 있다 (새 색은 마지막 것). 메시지 "새로운 색상 해금!  n / 7"

**첫 입장 (turn 0)**: 시작하자마자 4개가 위에서 떨어진다 (§12-G.2 첫 입장). 대기열을 만든 뒤 첫 NEXT를 뽑고, 중력 DOWN으로 움직임 시작 ("슬라임들이 입장합니다..."). 이 턴의 합체는 연쇄에 들지 않는다

**입구 경고 3단계** (입력 대기 중에만): 방향마다 L0·가운데 입구의 여유 `min(|p − 입구| − r_s − 31.5 − 5)` (슬라임이 없으면 999). `< 15` 위험 빨강 `#FF5878`, `< 70` 주의 노랑 `#FFD166`, 그 외 안전 청록 `#55E0BC`

**메시지** (원본 문구 그대로): 턴 시작 "FINAL MOVE · 공간을 다시 여세요" / "중력 전환 · 슬라임 n마리 등장" / "중력 이동 중...", 흡수 "n CHAIN!  +점수" (연쇄 2 이상) / "MAX 슬라임 완성!  +점수" / "흡수!  +점수", MAX CLEAR "MAX CLEAR · n CHAIN!  +점수" / "MAX CLEAR!  +점수", 해금·입장 취소·턴 끝·게임오버는 위. 해금이 일어난 반응은 해금 메시지가 우선

### 12-G.4 원본 그대로 두는 동작 — 고치지 않는다
> 2026-10-17 사용자 결정으로 첫 두 줄 (64 넘는 몫 버림, MAX는 흡수 안 함)은 #85부터 바뀐다 — §12-G.12 (`max_growth_enabled`)
- 64를 넘는 흡수 몫은 버린다 (40 + 30 → 64)
- MAX는 같은 색도 더 흡수하지 않고 물리적으로 부딪히기만 한다. MAX 둘은 색이 달라도 사라진다
- 입구가 0.9초 넘게 막히면 그 턴의 남은 입장이 모두 사라진다
- 슬라임은 최대 40개
- 쌍 반발은 질량을 보지 않는다 (작은 것과 큰 것이 같은 세기로 튄다)
- 턴은 대기열이 빈 뒤 최대 1.85초. 끝나면 모든 속도가 0
- 첫 입장의 우연한 합체는 연쇄가 없다
- FINAL MOVE 턴은 NEXT를 쓰지 않고 다음 턴으로 넘긴다
- 메시지 줄은 시간이 지나도 지워지지 않고 다음 메시지가 올 때까지 남는다

### 12-G.5 화면 배치
- 원본 화면 640×920 **전체를 배율 `k = 1.6875`** (1080 ÷ 640)로 옮겨 보이는 영역 가운데에 둔다 (1080 × 1552.5)
  - 9:16 (1080×1920): 위아래 여백 183.75px, 보드 화면 좌표 `(76, 487.5)`~`(1004, 1668.75)` (928 × 1181)
  - 긴 화면 (540×1170 → 1080×2340)도 세로 가운데, 넓은 화면은 가로 가운데 (`k` 그대로)
- 시뮬레이션 좌표 `p` → 화면 `origin + p × k`. 모든 길이·선 두께·글자 크기·흔들림 세기 = 원본 값 × `k`
- HUD (원본 좌표, 왼쪽 기준선. 크기 × `k`):

| 내용 | 위치 | 크기 | 색 | 글꼴 |
|---|---|---|---|---|
| `GRAVITY SLIME` | (30, 34) | 25 | `#DFE8FF` | Orbitron |
| `BEST %06d` | (390, 33) | 15 | `#FFE77A` | Orbitron |
| `SCORE %06d` | (30, 72) | 20 | `#75E6A4` | Orbitron |
| `TURN %02d` | (230, 72) | 19 | `#B8C6ED` | Orbitron |
| `GRAVITY ↑↓←→` | (365, 72) | 19 | `#FFC75F` | Orbitron (화살표는 Noto) |
| `NEXT` + 미리보기 | 글자 (30, 116), 슬라임 중심 (115 + 62i, 123) | 17 | `#B8C6ED` | Orbitron |
| `SLIME n · C n/7 · MAX n/7` | (350, 122) | 14 | `#B8C6ED` | Orbitron |
| 메시지 | (30, 166) | 17 | `#DFE8FF` | Noto Sans KR |

- NEXT 미리보기: 반지름 = 그 레벨 반지름 × 0.5, 중력 방향을 본 얼굴, 숨쉬기 없음
- `BEST`는 저장된 최고 점수와 지금 점수 중 큰 값 (원본처럼 판 중에 바로 오른다)
- 글꼴 폭이 원본 기본 글꼴과 달라 같은 줄에서 겹치면 그 줄 안에서 x만 옮기고 보고한다
- 원본에 없는 추가: 소리 버튼 (기존 HUD와 같은 아이콘·동작) — 보드 아래 여백 가운데

### 12-G.6 그림·연출 (원본 그대로, 길이 × k)
**그리는 순서**: 보드 → 중력 전환 → 합체 잔상 (빨려듦) → (움직이는 중) 속도 잔상 → **모든 그림자** → 모든 슬라임 → 합체 효과 (섬광·파동·입자·팝업) → 입구 막대 → HUD·FINAL MOVE 띠·CHAIN 표시
- **보드**: 바탕 `#111A38`, 테두리 `#5B72B8` 4px, 격자 40px 간격 (보드 시작 + 40부터) `Color(0.2, 0.3, 0.55, 0.10)` 1px
- **슬라임 재질**: 레벨·색마다 한 번 만든 정사각 텍스처 (원본 192px — 우리는 화면이 1.69배라 **384px**, 같은 식). 단위원 안 픽셀마다 `z = √(1 − x² − y²)`, `n = (x, y, z)`, 빛 `L = normalize(−0.20, −0.86, 0.48)`, `H = normalize(L + (0, 0, 1))`
  - `diffuse = max(0, n·L)`, `spec = max(0, n·H)^72`, `broad = max(0, n·H)^11`, `rim = (1 − z)^2.2`, `scatter = max(0, y)(1 − z) × 0.15`
  - `illum = 0.60 + diffuse × 0.34 + broad × 0.055`
  - R = `c.r × illum + spec × 0.62 + rim × c.r × 0.10 + scatter × c.r`, G = `… spec × 0.66 … rim × 0.11 …`, B = `… spec × 0.72 … rim × 0.13 …` (0~1로 자름)
  - 알파 = `clamp((1 − √(x² + y²)) × 크기 × 0.52, 0, 1)` (가장자리 약 2px만 흐림)
- **몸 그리기**: 변환 = 위치, 회전 `rotation + roll`, 늘임 `deform` (대기 중이면 × 숨 `(1 + b, 1 − b)`, `b = sin(idle_phase) × 0.018`). 텍스처를 `[−r, r]²`에, `r = radius × visual_scale`. 합체 빛: 흰 원 `α = glow × 0.55`, 반지름 `r × (0.72 + glow × 0.2)`
- **얼굴** (같은 변환 안, 눈 크기는 절대 px × k): `eye = clamp(3.8 + L × 0.75, 3.8, 7.6)`, 눈 높이 `−0.12r`, 간격 `±0.30r`, 색 `#17203C`
  - 보통: 세로 캡슐 눈 — 반폭 `eye × 0.72`, 반높이 `eye × lerp(1.08, 1.42, L/6)`, 흰 반사점 (α 0.88) 중심 `(−0.28 반폭, −0.40 반높이)`, 반지름 `max(1, 0.27 반폭)`
  - 깜빡임: 대기 중이고 `sin(idle_phase × 0.73 + color) > 0.985`면 눈 대신 가로선 (`±eye`, 두께 3)
  - MAX: 반달눈 호 (중심 `(±간격, 눈 높이 + 2)`, 반지름 `eye + 2.5`, 각 `π + 0.22 ~ 2π − 0.22`, 두께 4), 볼 `#FF5F87` α 0.52 원 2개 (`(±0.48r, 0.11r)`, 반지름 7.5), 미소 호 (중심 `(0, 0.12r)`, 반지름 `0.105r`, 각 `0.16 ~ π − 0.16`, 두께 4)
- **그림자** (모든 몸보다 먼저): 몸과 같은 늘임·숨, 오프셋 `(0.06r, 0.58r)`을 `rotation + roll`로 돌림, 세로 납작 × 0.27, 반지름 `0.70r` 원 `Color(0.015, 0.02, 0.06, 0.27)`
- **그림 상태 갱신** (매 틱):
  - `visual_scale → 1` (`min(dt×13, 1)`로 보간), `merge_glow −= dt × 3.2`, `idle_phase += dt × idle_speed` (생성 때 위상 `U(0, 2π)`, 속도 `U(1.5, 2.1)`, 그림 난수)
  - `rotation → 중력 각도` (`g.angle() − π/2`, `lerp_angle`, `min(dt×8, 1)`) — 얼굴이 중력 쪽으로 천천히 돈다
  - `impact −= dt × 4.8`
  - 대기 중: 변형 목표 `(1, 1)`, `roll → 0` (`lerp_angle`, `min(dt×4.5, 1)`)
  - `deform → 목표` (`min(dt×11, 1)`)
- **움직이는 중 (물리 단계 안)**: `roll += (v·t / max(r, 1)) × dt × 0.86`. 낙하 속도 `f = max(0, v·g)`, `s = clamp(f / 5100, 0, 0.19)`, 목표 `(1 − 0.55s, 1 + s)` — 떨어질 때 늘어남. `impact > 0`이면 목표 `(1 + 0.18i, 1 − 0.20i)` — 부딪힐 때 찌그러짐
- **들썩임**: 대기 중 그리는 위치 = `p − g × sin(idle_phase) × 1.8`
- **속도 잔상** (움직이는 중, 속도 > 190): 길이 `clamp(속도 × 0.045, 12, 52)`, 슬라임 색 `α = clamp((속도 − 190) / 950, 0, 0.16)`, 선 3개 (옆으로 `−0.28r, 0, +0.28r`), 시작 `p − 방향 × 0.58r + 옆`, 끝 = 시작 − 방향 × 길이, 두께 2.5 (가운데) / 1.5
- 효과 색: 흡수 = 새 슬라임 색 (새 레벨 밝기), MAX CLEAR = 두 슬라임 색 A·B와 그 중간색
- **합체 잔상** 0.36초: 두 원이 각자 자리에서 중점으로 `smoothstep` 이동, 반지름 (둘 다) `max(r_a, r_b) × lerp(1, 0.04, 진행)` → **#87부터 각자 자기 반지름** `r_a × lerp(…)`·`r_b × lerp(…)` (2026-10-17 사용자 결정, §12-G.13), `α (1 − 진행) × 0.78` (흡수는 효과 색, MAX CLEAR는 A·B 각각)
- **합체 파동** 0.68초 (`power` = 흡수 1, MAX CLEAR 1.65, 고리 색 = 효과 색 / 중간색): 흰 섬광 원 `α min(1, (1−p)³ × 0.72 × power)`, 반지름 `lerp(20, 7, p) × power`. 고리 `lerp(10, 94, p) × power`, 색 `lightened(0.35)` `α 1 − p`, 두께 `lerp(8, 1.2, p) × power`. 두 번째 고리 `q = clamp((p − 0.14) / 0.86)`: `lightened(0.55)` `α (1 − q) × 0.48`, 반지름 `lerp(8, 70, q) × power`, 두께 `lerp(4.5, 1, q) × power`. MAX CLEAR는 반원 두 개 추가 (**오른쪽 반 `−π/2 ~ π/2` = 색 A, 왼쪽 반 `π/2 ~ 3π/2` = 색 B** — 2026-10-17 정정, 처음에 "위 반·아래 반"으로 잘못 적었다. `lightened(0.30)`, 반지름 `lerp(16, 112, p) × power`, 두께 `lerp(6, 1, p)`)
- **입자** 0.75초: 흡수 14개 (각 `2πi/14 ± 0.16`, 속도 `U(90, 230)`, 색 `lightened(U(0, 0.35))`, 크기 `U(2.5, 6)`), MAX CLEAR 26개 (`± 0.12`, `U(150, 360)`, 색 A·B 번갈아 `lightened(U(0.08, 0.45))`, 크기 `U(4, 9)`). 매 틱 `p += v dt`, `v *= 0.90^(dt×60)`, 그리기 반지름 `크기 × (1 − 0.45 진행)`, `α 1 − 진행`
- **점수 팝업** 0.86초: "+점수" / "MAX CLEAR  +점수", `#FFF4B5`, 크기 20, 초당 42px 위로, `α 1 − 진행`. 위치는 원본 오프셋 대신 **가운데 정렬** (글꼴이 달라서)
- **중력 전환** 0.28초: `#8EC8FF` `α sin(진행 × π) × 0.22`. 보드 중심에서 `±g × 88` 화살 선 (두께 5) + 끝 삼각형 (끝 `+g × 21`, 밑 `−g × 6 ± 옆 × 16`), 도착 벽 (중력 쪽 벽) 전체 선 두께 5
- **입구 막대** (대기 중, 게임오버 아님): 방향마다 그 방향 입구 벽의 가운데 (DOWN → 위 벽, UP → 아래 벽, RIGHT → 왼쪽 벽, LEFT → 오른쪽 벽). 반길이 35 (지금 중력 방향) / 27, 바닥 선 `Color(0.02, 0.03, 0.08, 0.9)` 두께 10 위에 3단계 색 두께 6. **빨간 막대도 그대로 둔다** (2026-10-16 사용자: "슬라임 모드는 입구 경고의 빨간 막대 유지" — 턴제에서 막힘 빨간 벽을 없앤 #77과는 별개)
- **FINAL MOVE 띠** (FINAL MOVE 대기 중): 상자 `(145, 보드 위 + 22, 350, 62)`, 바탕 `Color(0.08, 0.05, 0.10, 0.78)`, 테두리 `#FFCF66` 3px `α 0.82 + sin(ms × 0.008) × 0.18`, 글자 "FINAL MOVE" 28 (상자 가운데)
- **CHAIN 표시** (`chain ≥ 2`, 반응 뒤 1.15초): "n CHAIN  x1.25" `#FFF0A0` `α clamp(남은 시간 / 0.30)`, 크기 25, 보드 위 + 52, 가로 가운데
- **화면 흔들림**: 남은 시간 동안 매 프레임 `(U(−s, s), U(−s, s))`, `s → 0` (`min(dt×9, 1)`). 끝나면 위치를 0으로 (`min(dt×18, 1)`). MAX 완성 4·0.16초, MAX CLEAR 9·0.34초, 게임오버 5·0.24초. 흔드는 것 = 보드·슬라임·연출·HUD (원본과 같다). 결과·랭킹 창은 흔들지 않는다

### 12-G.7 소리 (원본 합성 그대로 — `SfxBank`, `SFX` 버스·음소거 공유)
- 합성: 22,050Hz 모노 16비트. 주파수를 시작 → 끝으로 직선 변화, `φ += 2π f / 22050`, 파형 `sin φ × 0.78 + sin 2.03φ × 0.22`, 엔벨로프 `min(p / 0.08, 1) × (1 − p)^1.65`, × 음량

| 이름 | 시작 → 끝 Hz | 길이 | 음량 | 재생 |
|---|---|---|---|---|
| `slime_impact` | 135 → 92 | 0.10 | 0.20 | −8dB, 음높이 `lerp(1.15, 0.78, 세기)`, 세기 > 0.22·쿨다운 0.09초 |
| `slime_gravity` | 230 → 360 | 0.14 | 0.18 | 턴 시작, −4dB |
| `slime_merge` | 390 → 610 | 0.20 | 0.22 | 흡수, 음높이 `1 + min(chain × 0.055, 0.42)`, −4dB |
| `slime_max` | 330 → 760 | 0.34 | 0.25 | MAX 완성 (흡수음 대신), 음높이 같은 식 |
| `slime_clear` | 210 → 880 | 0.48 | 0.28 | MAX CLEAR, −4dB |
| `slime_game_over` | 260 → 105 | 0.52 | 0.23 | 게임오버, −4dB |

- 외부 음원 파일 우선 규칙 (§12-F)은 이 모드에 적용하지 않는다 — 원본 합성음 그대로

### 12-G.8 앱 연결 (우리 껍데기)
- **시작 화면**: 카드 3장. BLITZ·CLASSIC 카드 높이 480 → **400**, 그 아래 가로로 긴 **SLIME 카드** `Rect2(side, card_y + 400 + gap, width − 2 side, 132)` (기준 1080 폭: x 72, y 1403, 936 × 132). 아래 아이콘 줄 `bottom_y` 1550 → **1600** (긴 화면 보정식 그대로)
  - SLIME 카드 안: 왼쪽 아이콘 100px (L3 초록 슬라임 얼굴 — `SlimeView` 그리기로 만든 텍스처), 이름 `SLIME`, 설명 "같은 색이면 크기 상관없이 흡수", 오른쪽 `BEST n`. 선택 강조색 `#59E2AB`
- **장면 전환**: SLIME 카드 → 마지막 모드 저장 → `SlimeMain`. 결과 화면 "모드 선택" → 시작 화면, "다시 하기"·R → `SlimeMain` 다시 불러오기
- **입력**: `InputRouter` 스와이프·방향키/WASD. 움직이는 중에는 입력을 받지 않는다 (원본). 턴제와 같이 잠금이 풀린 뒤 손을 뗄 때 받는다 (`set_accept_release_after_unlock(true)`)
- **턴 입력 표시** (`TurnInputIndicator`, 원본에 없는 추가): 대기 = 밝은 테두리 + 네 방향 화살표 + 똑딱·5ms 진동, 움직이는 중 = 흐린 테두리 + 도는 빛, 움직이는 중 스와이프 = 회색 화살표 0.3초. **막힘 표시 (빨간 화살표·✕·"막힘")는 쓰지 않는다** — 이 모드는 막힌 방향으로도 밀 수 있다. 테두리는 슬라임 보드 사각형 기준 (원본 4px 테두리 바깥)
- **진동**: 스와이프 8ms (기존 `Haptics`, PC 무동작)
- **결과 화면**: 원본 결과 상자 대신 `GameOverPanel` — 점수 (올라가는 숫자), 턴, 최고 연쇄, MAX 완성 n/7, 새 기록 배지 (`새 기록! n위`), "ALL TIME 최고 점수 · T 최고 턴 · C 최고 연쇄" 한 줄. 버튼은 다른 모드와 같다. 게임오버 소리·흔들림이 끝난 뒤 연다
- **랭킹**: `RankingPanel`에 `SLIME` 탭 (BLITZ·CLASSIC 오른쪽). 열: 순위 · 점수 · 턴 · 연쇄 · MAX · 날짜
- **저장** (`SaveStore`, `user://save.cfg` — 원본의 `gravity_slime_save.cfg`는 쓰지 않는다): 랭킹 `slime` TOP 10 (`score`, `date`, `turns`, `max_chain`, `max_colors`), 기록 최고 점수·최고 턴·최고 연쇄, 마지막 모드 `"slime"`. 게임오버 때 한 번 저장 (원본은 바뀔 때마다 저장 — 다른 모드와 맞춘다). 손상·없음이면 0
- **디버그**: 모드 순환 단축키가 TURN → BLITZ → SLIME → TURN

### 12-G.9 검증
**테스트** (`tests/`, 래퍼 일반 묶음에 추가)
- 원본 회귀 4개 대응:
  - 입구: 네 방향 각각 입구를 막고 그 방향으로 밀어도 턴이 시작되고, 막힌 동안 겹쳐 생성되지 않고, 기존 슬라임이 움직이면 대기 슬라임이 들어오고, 턴이 끝나 입력을 받는다. FINAL MOVE 턴은 생성 없이 진행된다
  - MAX CLEAR: 색이 같든 다르든 정확히 맞닿은 MAX 둘이 사라지고 7,500점
  - 크기·해금: 레벨 반지름 표, 질량 1~64 반지름 단조 증가, 문턱 질량 = 표 반지름, 8 + 16 → 24 (반지름 = 질량 식), 32 + 32 → 64·112. 해금 점수 4개 경계 (−1점 미해금, 정확히 해금, 색 수 4~7)
  - 쌓임 미끄러짐: 네 방향에서 일직선 두 슬라임의 위쪽이 옆으로 미끄러지고 중력축 속도는 생기지 않는다
- 추가:
  - 묶음 개수표: 수 9/10/15/16 × 턴 29/30/59/60 × 완화 유무
  - 색 주머니: 해금 색이 정확히 2개씩, 새 색이 앞 2개에 강제
  - 레벨 분포: 시드 고정 10,000번 70/25/5 ± 1.5%p
  - 연쇄 배수: 1.00 → 2.75 (8연쇄부터 고정), `round`, turn 0은 연쇄 없음
  - 넘침: 40 + 30 → 64, 점수 `70 × 25 + 2,500`
  - MAX와 같은 색 작은 슬라임은 흡수하지 않음
  - 입장 취소: 0.9초 초과 대기 시 대기열 전체 버림
  - 40개 한도, FINAL MOVE 두 갈래 (성공 → 계속, NEXT 유지 / 실패 → 게임오버)
  - 입구 막대 경계 (여유 14.9 빨강, 69.9 노랑, 70 청록)
  - 결정론: 같은 시드 + 같은 스와이프 30턴 → 같은 해시. 엔진 60Hz / 120Hz 같은 해시
  - 그림을 끈 실행과 켠 실행이 같은 해시
  - 기존 두 모드 물리 해시 동일
- **패리티 (로컬 전용, 래퍼 밖)**: `tests/tools/run_slime_parity.ps1 -PrototypePath <원본 prototype 폴더>`
  - 원본 `main.gd`를 그 경로에서 읽어 (저장소에 복사하지 않음, 원본 폴더에 새 파일을 만들지 않음 — 필요하면 임시 폴더에 복사해 실행) 같은 장면을 원본과 `SlimeSim`에서 틱마다 기록해 비교한다. 원본 기록 저장·소리는 테스트 하위 클래스로 막는다 (원본 테스트와 같은 방식)
  - 장면 6개 (난수를 쓰지 않게 상태를 직접 놓는다): ① 섞인 색·질량 12개 고정 배치, 중력 DOWN, 생성 없이 턴 끝까지 ② 같은 배치 LEFT ③ 같은 색 셋 연쇄 흡수 ④ MAX 둘 + 주변 6개 MAX CLEAR 밀기 ⑤ 서로 다른 색 4개 수직 탑 + 빠른 벽 충돌 ⑥ NEXT 3개를 직접 정해 막힌 입구에서 대기 후 입장
  - 합격: 틱마다 위치·속도 차 ≤ 1e-6px, 수·질량·점수·연쇄·턴 끝 틱이 같다. 다르면 첫 차이 틱과 원인을 보고
- **봇 측정 (관측만)**: `SlimeSim` 헤드리스, 시드 1~100, 250턴 상한, 전략 3개 (원본 `balance_simulator.py`와 같은 뜻)
  - 무작위: 봇 난수로 4방향 균등
  - 공간 우선: 방향마다 상태를 복제해 생성 없이 그 턴 끝까지 돌린 뒤, 그 방향 입구의 여유가 가장 큰 방향
  - 합체 우선: 같은 복제에서 `점수 증가 × 3 + 여유`가 가장 큰 방향
  - 동률은 봇 난수 × 0.01
  - 보고: 평균·중앙 턴, 250턴 도달 판 수, 평균·중앙 점수, 판 끝 해금 색 수 분포, MAX 완성·MAX CLEAR 횟수, FINAL MOVE 발생·성공률, 입장 취소 횟수, 턴 시간 p50/p95 (시뮬레이션 초), 최대 슬라임 수
- **캡처** (두 비율 540×960·540×1170, 고정 시드·고정 그림 시간): #79 `48_slime_core`, #80 `49_slime_states` (첫 입장 중, 대기 + 3단계 막대 셋 다, 움직이는 중 늘어남·잔상, 흡수 중 파동, MAX 얼굴, MAX CLEAR 반원 파동, FINAL MOVE 띠, 깜빡임), #81 `50_slime_shell` (시작 화면 카드 3장, 랭킹 SLIME 탭, 결과 화면)
- **성능**: 창 측정 (`--disable-vsync`)으로 슬라임 40개가 움직이는 장면 프레임 p99 보고 (기준 16.7ms 이하)
- **스모크**: 기본·`--mode=turn`·`--mode=blitz`·`--mode=slime` 4종 에러 0

### 12-G.10 단계 — 인박스 #79 → #80 → #81
| 항목 | 범위 | 확인 |
|---|---|---|
| **#79** 규칙·물리 코어 | `SlimeConfig`, `SlimeSim` (§12-G.2~12-G.4), 최소 화면 (보드·색 원·입구 막대·FINAL MOVE 띠·HUD 문구·원본 결과 상자 임시), 방향키·스와이프·R, `GameMode.SLIME`·`--mode=slime`, 테스트·패리티·봇 측정 | 패리티 6장면, 해시, 봇 표, `48` |
| **#80** 그림·연출·소리 | §12-G.6 전부, §12-G.7 소리 6종 | `49`, 그림 켜고 끈 해시 동일, 성능 |
| **#81** 앱 연결 | §12-G.8 전부 (시작 카드·랭킹 탭·저장·결과·소리 버튼·턴 입력 표시·진동·장면 왕복) | `50`, 시작 → SLIME → 결과 → 랭킹 → 돌아오기 → 다시 하기 왕복에서 모든 버튼 동작 (#73 교훈), 사용자 저장 파일 해시 불변 |

**#79 결과 — 병합** ([PR #81](https://github.com/jeongmo-dot/gravity_orb/pull/81) `46aef16`, 2026-10-16): `SlimeConfig`·`SlimeSim` (`RefCounted`, 고정 1/60초, 게임·그림 난수 분리, 사건 목록, 복제·상태 해시), `SlimeMain` 최소 화면, `GameMode.SLIME`·`--mode=slime`. **원본 패리티 6장면 틱마다 ≤ 1e-6px 통과** (원본은 임시 폴더 복사본에서 하위 클래스로 실행 — 저장소에 원본 코드 없음), 같은 시드·그림 켜고 끄기·60/120Hz 해시 일치, TURN·BLITZ 해시 동일, 래퍼 321/321, 스모크 4종 (Codex). Claude 검수 (diff·`48` 두 비율, 재실행 없음): 규칙·물리 코어는 원본 처리 순서·배열 반복 순서 그대로

봇 관측 (300판, 250턴 상한, 수치 변경 없음):

| 전략 | 턴 평균 / 중앙 | 250턴 | 점수 평균 | 끝 해금 색 | MAX 완성 / CLEAR | FINAL MOVE 발생 / 성공 | 입장 취소 |
|---|---|---|---|---|---|---|---|
| 무작위 | 66.6 / 70 | 0 | 149,234 | 4색 32 · 5색 66 | 2.33 / 0.73 | 10 / 80% | 0.81 |
| 공간 우선 | 82.1 / 84 | 0 | 142,003 | 4색 50 · 5색 49 | 2.26 / 0.69 | 44 / 86% | 0.64 |
| 합체 우선 | 64.0 / 70.5 | 0 | 161,904 | 5색 69 · 6색 2 | 2.21 / 0.73 | 3 / 100% | 0.55 |

- 원본 `BALANCE_REPORT.md` (근사 모델)는 공간 우선이 100턴 이상 버텼다고 했지만, 원본 물리 그대로 돌리면 **어느 전략도 250턴에 못 가고 평균 64~82턴**이다. 턴 시간 중앙값이 정확히 입장 3개 0.63초 + 상한 1.85초 = 2.48초 (p95 2.78초 = 입장 4개 + 1.85초) — 대부분의 턴이 정지 판정 전에 1.85초 상한으로 끝난다. 한 판 약 3분
- 50만 점 (7색)은 300판 중 0번, 30만 점 (6색)은 2번 — 뒤 두 색은 사실상 나오지 않는다 (관측. 원본 그대로 두는 것이 사용자 결정)

**#79에서 명세와 달라 #80으로 넘기는 것** (코어가 아니라 표시 쪽이라 병합 후 #80에서 함께 고친다)
- 메시지가 원본 한국어가 아니라 영어 (`"Gravity changed"`, `"Choose gravity"` 등 — §12-G.3 메시지 표). `48` 캡처는 캡처 스크립트가 메시지를 한국어로 덮어써서 드러나지 않았다 → 캡처는 시뮬레이션이 실제로 낸 메시지를 그대로 찍는다
- HUD가 §12-G.5 표와 다르다: 색 (BEST `#FFE77A`·SCORE `#75E6A4`·TURN `#B8C6ED`·GRAVITY `#FFC75F`·메시지 `#DFE8FF` 대신 세 가지 색), 숫자 글꼴 (Orbitron 대신 Noto), `%06d`·`%02d` 자리 채움 없음, 정보 줄이 `COLORS n  SLIMES n` (원본 `SLIME n · C n/7 · MAX n/7`), NEXT 16 → 17
- FINAL MOVE 띠가 진행 턴에도 남는다 (원본은 대기 중에만), 테두리 깜빡임 (`α 0.82 + sin(ms × 0.008) × 0.18`) 없음
- 보드 격자가 원본보다 밝다 (`Color(0.35, 0.47, 0.72, 0.18)` → 원본 `Color(0.2, 0.3, 0.55, 0.10)`)
- **입구 막대가 원본과 다르다**: 위험 색이 분홍 슬라임 색 `#FF7595` (원본 빨강 `#FF5878` — 사용자가 유지하기로 한 그 빨간 막대), 주의·안전도 슬라임 색 (원본 `#FFD166`·`#55E0BC`), 반길이 55 고정 (원본 지금 중력 35 / 나머지 27), 같은 색 반투명 14 + 5 (원본 짙은 남색 `Color(0.02, 0.03, 0.08, 0.9)` 10 + 색 6), 슬라임보다 먼저 그림 (원본은 슬라임 뒤)
- 충돌음 사건이 **벽 충돌에서도** 나고 쿨다운을 쓴다 — 원본은 슬라임끼리 부딪힐 때만. 문턱도 `≥ 0.22` → 원본 `> 0.22`
- 흡수된 새 슬라임에 `impact = 0.75`를 준다 — 원본은 `impact` 대신 `visual_scale` (§12-G.3 식)·`merge_glow = 1`
- `48`의 FINAL MOVE 칸은 위·아래 입구가 안전 (청록)인데 띠가 떠 있다 — 실제로 네 입구가 모두 막힌 상태로 찍는다

**#80 1차 결과** (PR #82, 2026-10-17): #79에서 넘어온 표시 차이 (한국어 메시지·HUD 색·자리 채움·정보 줄·입구 막대 색과 길이·벽 충돌음·흡수 `visual_scale`)를 원본대로 고침. 384px 원본 식 재질, 캡슐 눈·MAX 표정·깜빡임·숨·들썩임·얼굴 방향·굴림·늘어남/찌그러짐·그림자·잔상, 흡수·MAX CLEAR·중력 전환·CHAIN·흔들림, 합성음 6종. 그림 켜고 끈 해시·60/120Hz·패리티 6장면 통과, TURN·BLITZ 해시 동일, 래퍼 326/326, 창 40개 p99 5.33ms (Codex). 슬라임 모양·얼굴·명암은 원본과 나란히 놓아 봐도 같다. Claude 검수 (diff·`49` 두 비율·원본 비교 사진 확대, 재실행 없음)에서 찾은 것:
- **입구 막대와 반응 효과 (파동·입자·점수 팝업)가 엉뚱한 곳에 그려진다**: `SlimeView._draw()`가 슬라임마다 `draw_set_transform(위치, 회전, 늘임)`을 걸고, 슬라임 반복이 끝난 뒤 되돌리지 않은 채 `_draw_reaction_effects()`·`_draw_entry_bars()`를 그린다 → 둘 다 **마지막 슬라임의 위치·회전·늘임 기준**으로 옮겨진다. `49`에서: 막대 칸 (2번)에 막대가 하나도 안 보이고, 흡수 칸 (3번)은 파동·팝업 없이 청록 막대 하나가 보드 오른쪽 밖에 떠 있고, FINAL MOVE 칸 (4번)은 네 벽의 빨간 막대 대신 빨간 막대 하나가 보드 안 아래쪽에 떠 있다. 패널 아래 바깥에도 잘린 고리 모양이 찍혔다. Codex 보고 ("안전·주의·위험 막대", "실제 FINAL MOVE")와 캡처가 다르다
- 막대 길이 테스트는 있지만 **위치** 테스트가 없어서 통과했다
- 입구 막대가 벽선에서 2px 안쪽에 그려진다 — 원본은 벽선 위 (`center.y = BOARD.position.y` 등)
- MAX CLEAR 반원 방향: 원본은 **오른쪽 반 (`−π/2 ~ π/2`) = 색 A, 왼쪽 반 = 색 B**다. §12-G.6에 "위 반 = A, 아래 반 = B"로 잘못 적은 것은 Claude 명세 오류 (이번에 §12-G.6을 고쳤다)

**#80 추가 요구 1** (같은 브랜치에서 이어서)
1. 슬라임을 다 그린 뒤 (그리고 그림자 반복 뒤에도) `draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)`으로 되돌리고 반응 효과·입구 막대를 그린다 — 효과와 막대는 보드 좌표 그대로
2. 입구 막대 중심을 벽선 위로 (2px 안쪽 오프셋 삭제)
3. MAX CLEAR 반원: 오른쪽 반 = 색 A (`−π/2 ~ π/2`), 왼쪽 반 = 색 B (`π/2 ~ 3π/2`)
4. **위치 회귀 테스트**: 화면 밖 `SubViewport`에 슬라임 몇 개 (마지막 슬라임은 보드 가운데가 아닌 곳, 회전·늘임 있는 상태) + 대기 상태로 그려 ① 네 벽 막대 중심 화소가 단계 색이고 ② 흡수 사건 직후 파동 고리가 반응 지점 둘레에 있는지 (지점에서 고리 반지름만큼 떨어진 화소가 바탕과 다름) 확인한다. 고치기 전 코드로 실패해야 한다
5. `49` 다시: 2번 칸 네 막대 (안전·주의·위험 섞임)가 네 벽 가운데, 3번 칸 흡수 파동·입자·팝업이 흡수 지점에, 4번 칸 네 막대 모두 빨강, 패널 밖에 그려진 것 없음. 원본 비교 사진도 다시
- 검수: `49` 두 비율·원본 비교, 그림 켜고 끈 해시·패리티 그대로, 물리 해시 동일

**#80 결과 — 병합** ([PR #82](https://github.com/jeongmo-dot/gravity_orb/pull/82) `8022fac`, 2026-10-17): 추가 요구 1 반영 — 그림자·슬라임 반복 뒤 변환 복원, 막대를 벽선 위로, MAX CLEAR 반원 오른쪽 = A·왼쪽 = B. 화면 밖 렌더 화소 테스트 (네 벽 막대 중심 색·MAX CLEAR 좌우 색)가 고치기 전 실패 (5/6) → 고친 뒤 6/6. 래퍼 327/327, 패리티·해시 그대로, 창 40개 p99 5.54ms (Codex). Claude 검수 (`49` 두 비율 확대·원본 비교, 재실행 없음): 막대 칸 네 벽에 단계 색, 흡수 칸 효과가 흡수 지점에, FINAL MOVE 칸 네 벽 모두 빨강 + MAX CLEAR 파동이 반응 지점에, 패널 밖 잔상 없음
- (#84에서 발견) #81의 시작 화면 → SLIME 전환이 **릴리스 창에서 멈췄다**: `Main`이 장면 전환으로 빠진 뒤에도 `FeedbackDirector._prewarm_visual_resources_offscreen()`의 대기 코루틴이 `get_tree()` (null)를 불러 오류 후 종료. #84에서 트리 소속·`SceneTree`·임시 viewport를 대기 전후로 확인하게 고치고 회귀 테스트 추가 (사용자 승인, Codex 보고). 헤드리스 테스트·스모크는 이 경로 (헤드리스는 프리워밍을 건너뜀)를 지나지 않아 놓쳤다
- 알아 둘 것: 화소 테스트는 헤드리스 (dummy renderer)에서 화소 부분을 건너뛰고, 실제 화소는 창 실행 `tests/run_slime_visual_render_test.ps1`에서만 본다 → #81에서 `tests/capture_screens.ps1` 실행에 포함시켜 캡처할 때마다 같이 돌게 한다

**#81 결과 — 병합** ([PR #83](https://github.com/jeongmo-dot/gravity_orb/pull/83) `e23e776`, 2026-10-17): 시작 화면 카드 3장 (BLITZ·CLASSIC 400 + 가로 SLIME 카드, 아이콘 줄 1600), `SlimeMain`에서 `UI.tscn`의 실제 `GameOverPanel`·`RankingPanel`·`HudSoundButton`을 재사용, SLIME 결과 (점수·턴·최고 연쇄·MAX n/7·새 기록 순위·ALL TIME), 랭킹 SLIME 탭 6열, `SaveStore` 랭킹 `slime`·최고 점수/턴/연쇄 (순위 밖 판도 갱신)·마지막 모드, 결과 → 랭킹 → 돌아오기 후 버튼 복구 (#73), 턴 입력 표시를 슬라임 보드에 연결, 스와이프 8ms·대기 5ms 진동, 디버그 모드 순환, 캡처 때 화소 회귀 같이 실행. 래퍼 331/331, 스모크 4종, 사용자 저장 파일 변경 0 (Codex). Claude 검수 (diff·`50` 시작·랭킹·결과·`01` 두 비율, 재실행 없음): 세 화면 모두 겹침·잘림 없음

남은 것 → #83:
- **게임 화면의 입력 표시를 캡처로 보지 못했다** — `50`은 시작·랭킹·결과만, `48`·`49`는 셸을 끄고 찍는다 (Claude 명세 누락). 코드로 계산하면 (9:16, 캔버스 1080×1920) 슬라임 화면에서도 턴제처럼 네 방향 화살표를 그려서:
  - 아래 화살표 (보드 아래 + 34, y 약 1697~1722, x 512~568)가 소리 버튼 (y 1699~1803, x 488~592)과 겹친다
  - 위 화살표 (y 약 434~460, x 512~568)가 원본 메시지 줄 (기준선 y 약 464, 글자 높이 약 29)의 긴 문구와 겹친다 — 입력 대기 중에 뜨는 "FINAL MOVE · 한 번의 중력 이동으로 공간을 만드세요", "공간 확보 성공 · 다음 중력을 선택하세요"
  - 네 화살표가 벽 가운데 입구 막대 바로 바깥에 붙어, 빨간 위험 막대 옆 화살표가 턴제의 "막힌 방향"처럼 읽힐 수 있다
- 시작 화면 SLIME 카드 아이콘이 입이 있는 따로 그린 얼굴이다 — 게임 안 L3 슬라임 (캡슐 눈·반사점, 입 없음)과 다르다

#### 12-G.11 슬라임 모드 입력 표시 정리 (#83)
- 결정 (Claude, 2026-10-17): **슬라임 모드는 방향 화살표를 그리지 않는다** — 이 모드는 네 방향이 언제나 가능해 화살표가 주는 정보가 없고, 원본 HUD 메시지·입구 막대·소리 버튼과 부딪힌다. 입력 가능·잠김 구분 (§12-T.2, 사용자 2026-10-12)은 테두리·빛·소리로 한다
  - 대기: 밝은 테두리 + 숨쉬기 + 똑딱 + 5ms 진동 (그대로)
  - 움직이는 중: 흐린 테두리 + 도는 빛 (그대로)
  - **도는 빛 버그** (2026-10-17 사용자 플레이: "게임 판 외곽선을 도는 애니메이션이 이상하게 출력"): `SlimeGame.advance_elapsed()`가 시뮬레이션 한 걸음 (1/60초)마다 `_sync_input_lock()` → `TurnInputIndicator.set_slime_state(false, …)`를 부르고, `set_slime_state()`는 잠김 상태면 **부를 때마다** `_orbit_elapsed = 0`으로 되돌린다 → 빛이 돌지 못하고 왼쪽 위 모서리 근처에서 떨리며, 꼬리는 음수 진행값이 둘레 끝으로 감겨 왼쪽 변에 붙는다. 턴제는 `_on_state_changed()`가 상태가 바뀔 때만 불려 문제없다. 고침: 도는 빛 진행을 따로 세지 않고 **잠김 시계에서 바로 계산**한다 (§12-T.2.2 — 사용자 요청으로 한 바퀴 = 잠김 시간). 같은 상태를 매 걸음 다시 알려도 진행이 되돌아가지 않는 회귀 테스트 (지금 코드로 실패해야 함)
  - 거절 (움직이는 중 스와이프): 회색 화살표 대신 **테두리가 회색 (`REJECTED_COLOR`)으로 0.3초** 번쩍인 뒤 흐린 테두리로
  - 턴제는 그대로 (화살표·막힘 표시 유지)
- 소리 버튼은 지금 자리 (보드 아래 + 30) 그대로 — 화살표가 없으면 겹치지 않는다. 도는 빛 경로 (보드 + 14px)와도 떨어져 있는지 캡처로 본다
- SLIME 카드 아이콘을 게임 안 L3 초록 슬라임과 같은 그림으로 (`SlimeView` 재질 텍스처·캡슐 눈·반사점, 입 없음)
- 새 캡처 `50_slime_shell_play` 두 비율: ① 대기 (막대 단계 섞임) ② 대기 + FINAL MOVE (네 막대 빨강 + 긴 메시지) ③ 움직이는 중 (도는 빛) ④ 거절 (회색 테두리). 셸을 켠 실제 게임 화면으로 찍는다
- 검수: `50` 두 비율 — 메시지·막대·테두리·도는 빛·소리 버튼이 서로 겹치지 않음, 턴제 입력 표시 캡처 (`44`·`45`·`46`) 그대로, 물리 해시·패리티 그대로

**#83 결과 — 병합** ([PR #86](https://github.com/jeongmo-dot/gravity_orb/pull/86) `41f6bcc`, 2026-10-17): 슬라임 모드 화살표 없음 (`_slime_mode`에서 화살표 그리기 건너뜀), 거절은 테두리 회색 0.3초, 대기 테두리 숨쉬기. 도는 빛 진행은 잠김 시계에서 — 턴제 `settle_elapsed / max_settle_time` (`SPAWNING` 0), 슬라임 `SlimeGame`이 예정·실제 입장 끝 + 1.85초로 계산하고 뒤로 가지 않음 (같은 잠김을 매 걸음 다시 알려도 그대로 — 슬라임 빛 버그 해결). SLIME 카드 아이콘은 게임 L3 재질·캡슐 눈·입 없음. 래퍼 334/334, 패리티·해시 그대로 (Codex). Claude 검수 (diff·`45_a`·`45_b`, 재실행 없음): 턴제 빛이 진행 1/3 (오른쪽 변 1/3 지점)·2/3 (아래 변)에 정확히 있다
- **캡처가 남아 있지 않았다**: Codex가 마지막에 `-HudScenesOnly`로 다시 돌려 출력 폴더에 HUD 장면 17장만 남았다 — `50_slime_shell_play_*` 네 장과 `01_start_screen`은 보고에만 있고 파일이 없어 Claude가 보지 못했다. 코드로는 화살표가 그려지지 않는 것이 분명하고 빛 경로 (보드 + 14px)와 소리 버튼 (보드 아래 + 30)도 떨어져 있어 병합하고, 화면은 #85의 전체 캡처에서 함께 본다
- **릴리스 빌드를 덮었다**: 검증 빌드를 `-Debug`가 아니라 릴리스로 돌려 `build/windows/GravityOrb_v0.13.0.exe`가 #83 브랜치 작업 트리 내용 (111,168,488바이트)으로 바뀌었고, `_BUILD.txt` 커밋은 그 전 main `17d3c8a`로 적혀 실제 내용과 다르다. 원래 0.13.0 (`d04abba`)은 남아 있지 않다. 내용은 지금 main (`41f6bcc`)과 같다

#### 12-G.12 슬라임 MAX도 계속 자란다 (기획서 0.13.1 — #85)
사용자 (2026-10-17, 0.13.0 플레이): "녹색 슬라임은 레벨이 최대가 된 이후로 변화가 없네" → Claude 설명 (원본은 MAX가 더 흡수하지 않음) → **"슬라임 모드는 계속 더 커지게 하자"**

**규칙** (원본에서 바꾸는 것은 아래뿐 — 나머지는 §12-G.3 그대로)
- **같은 색이면 MAX도 흡수한다.** 질량 상한 64를 없앤다 — `m = a + b` (버리는 몫 없음). MAX (64 이상)끼리도 같은 색이면 합쳐진다
- 판정 순서가 바뀐다: ① 같은 색 → 흡수 (질량 무관) ② 다른 색이고 둘 다 64 이상 → MAX CLEAR (원본처럼 7,500점, 165px 밀기) ③ 그 외 충돌만. 원본은 ②를 ①보다 먼저 봐서 같은 색 MAX 둘도 사라졌다
- **크기**: 64까지는 원본 그대로 (32~63은 101 → 108 보간, 64에서 112). 64 넘으면 `r = min(112 × (m / 64)^0.2, 165)` — 질량이 두 배가 될 때마다 약 15% 커진다 (원본 위쪽 단계의 커지는 비율 1.20·1.11에 이어지게). 질량 128 → 128.6, 192 → 140, 256 → 147.8, 약 444부터 165 (지름 330 = 보드 폭 550의 60%)에서 멈춘다. 상한은 보드 안에서 물리가 깨지지 않게 하는 안전 한도
- 레벨·얼굴: 64 이상은 계속 MAX (L6) — 반달눈·볼·미소 그대로. "MAX 완성 색"·`+2,500`은 처음 64를 넘는 흡수 한 번만 (원본 그대로)
- **점수**: 원본 식 그대로 `합친 질량 × 25` (상한 없음) — 큰 MAX에 작은 슬라임을 먹일수록 한 번에 큰 점수 (MAX 200 + 1 → 5,025). 점수가 빨리 올라 색 해금 (5만·15만·30만·50만)도 빨라질 수 있다 → 봇 측정으로 보고 필요하면 따로 정한다
- 흡수 연출·소리는 원본 그대로 (새 슬라임이 `visual_scale`로 부풀며 커지는 것이 보인다)
- 재질 텍스처: L6은 반지름 165 × k = 278px까지 커지므로 **L6만 512px** (같은 식)
- 새 필드 (`SlimeConfig`): `max_growth_enabled` (bool, 기본 **true** — false면 원본 규칙: 패리티 검사는 false로), `max_growth_exponent` **0.2**, `max_growth_radius_cap` **165**

**검수**
- 테스트: 같은 색 MAX + L0 → 질량 65·반지름 식, 같은 색 MAX 64 + 64 → 128·128.6, 다른 색 MAX 둘 → MAX CLEAR 7,500, 처음 64를 넘을 때만 +2,500, 반지름 단조 증가·165에서 멈춤, 반지름 165 슬라임이 벽 처리에서 보드 안에 머묾, `max_growth_enabled = false`면 원본과 같음 (넘는 몫 버림·MAX 흡수 없음)
- 패리티: `max_growth_enabled = false`로 6장면 그대로 통과
- 봇 측정: #79와 같은 조건 (시드 1~100, 250턴, 전략 3개)으로 다시 — 턴·점수·해금 색 분포·MAX 완성/CLEAR·최대 반지름·FINAL MOVE를 #79 표와 나란히
- 캡처: `51_slime_max_growth` 두 비율 — 질량 64·128·256·450 이상 MAX를 나란히 (보드 안), 큰 MAX가 작은 같은 색을 흡수하는 순간

**#85 결과 — 병합** ([PR #87](https://github.com/jeongmo-dot/gravity_orb/pull/87) `49477c7`, 2026-10-17): 판정 순서 ① 같은 색 흡수 (성장 켜짐이면 질량 무관) ② 둘 다 64 이상 → MAX CLEAR, 64 넘는 반지름 식·165 상한, `+2,500`은 두 재료 모두 64 미만일 때만, L6 재질 512px, `maximum_slime_radius` 관측값 (해시에는 안 넣음). 성장을 끄면 원본 순서와 같아 패리티 6장면 통과. 래퍼 338/338, 해시 그대로, 검증 빌드는 `-Debug`만, 마지막 실행이 전체 캡처 146장 (Codex). Claude 검수 (diff·`51`·`50_slime_shell_play_*` 네 장·`01` 두 비율, 재실행 없음): 64·128·256·451 크기 단계가 보이고 451은 165에서 보드 안. #83에서 못 본 슬라임 대기·FINAL MOVE·움직임·거절 화면은 화살표 없음, 네 막대 빨강, 소리 버튼 겹침 없음

봇 관측 (#79 → #85, 100판씩, 250턴 상한 — 도달 0):

| 전략 | 턴 평균 | 점수 평균 | 6색까지 연 판 | MAX 완성 / CLEAR | 최대 반지름 평균 | FINAL MOVE 발생 / 성공 |
|---|---|---|---|---|---|---|
| 무작위 | 66.6 → **71.3** | 149,234 → **184,406** | 0 → 1 | 2.33 / 0.73 → 2.34 / 0.75 | 124.8 | 10 / 80% → 7 / 71% |
| 공간 우선 | 82.1 → **90.0** | 142,003 → **178,687** | 0 → 2 | 2.26 / 0.69 → 2.52 / 0.81 | 127.2 | 44 / 86% → 64 / 88% |
| 합체 우선 | 64.0 → **68.4** | 161,904 → **202,505** | 2 → 12 | 2.21 / 0.73 → 2.34 / 0.82 | 123.4 | 3 / 100% → 1 / 100% |

- 한 판이 5~10% 길어지고 점수는 23~26% 오른다. 최대 반지름 평균 약 125 (질량 약 110) — 한 판 동안 MAX가 질량 두 배까지 크는 일은 드물어 걱정했던 점수 폭주는 크지 않다. 6색 해금이 조금 늘었고 7색은 여전히 0
- 남은 것 (Claude 검수에서) → #87:
  - **도는 빛이 메시지 줄 위를 지나간다** (`50_slime_shell_play_busy`): 빛 경로가 보드 + 14px라 위 변의 빛 (지름 20 + 빛무리 44 논리 px)이 원본 메시지 줄 (보드 위 약 23px) 글자 아래쪽에 겹친다. 잠김 동안 메시지 ("중력 전환 · 슬라임 n마리 등장", "n CHAIN!" 등)가 바뀌는 바로 그때 빛이 한 바퀴의 처음 1/4 동안 그 위를 지나간다
  - **큰 MAX가 작은 슬라임을 먹을 때 커다란 잔상 원 두 개** (`51` 넷째 칸): 원본 합체 잔상은 두 원 모두 반지름 `max(r_a, r_b)`라, 질량 1짜리 쪽에도 반지름 165 원이 그려져 양옆에 갈색 "귀"처럼 튀어나온다. 원본에도 있던 규칙이지만 (L5 + L0도 같은 모양) MAX가 커지면서 눈에 띈다 — 바꿀지 사용자 결정

#### 12-G.13 슬라임 도는 빛 경로·합체 잔상 크기 (#87)
- 슬라임 모드의 도는 빛 경로를 **보드 테두리 선 위** (`board_rect`, 바깥으로 키우지 않음)로 — 빛 중심이 원본 4px 테두리 위를 돈다. 위 변에서 빛 바깥 끝이 보드 위 약 10 논리 px로, 메시지 줄 글자와 떨어진다. 턴제 경로는 그대로 (보드 + 14px)
- 빛 크기·꼬리·색·진행 (잠김 시계)은 그대로
- **합체 잔상은 각자 자기 크기로** (2026-10-17 사용자: "잔상을 각자 자기 크기로 해줘"): 원본은 두 잔상 원을 모두 `max(r_a, r_b)`로 그려, 큰 MAX가 질량 1짜리를 먹으면 작은 쪽 자리에도 반지름 165 원이 생겨 양옆에 "귀"처럼 튀어나왔다. 이제 잔상 A는 `r_a`, 잔상 B는 `r_b`에서 시작해 `× lerp(1, 0.04, 진행)`으로 줄며 중점으로 빨려 든다. 흡수·MAX CLEAR 둘 다. 시간 (0.36초)·색·알파·이동은 그대로. 그림만 바뀌고 해시·패리티는 그대로
- 검수: `51` 넷째 칸 (질량 450 + 1 흡수)에서 작은 쪽 잔상이 작게 보이고 양옆 큰 원이 없음, `50_slime_shell_play_busy` 두 비율에 위 변을 지나는 순간 (진행 0.1) 한 장 추가 — 빛과 메시지 글자가 겹치지 않음, 입구 막대와는 겹쳐 보여도 된다 (막대는 대기 중에만 보이고 빛은 잠김 중에만 보인다)
- **#87 결과 — 병합** ([PR #89](https://github.com/jeongmo-dot/gravity_orb/pull/89) `52cd77a`, 2026-10-17): 입력 표시에 테두리 사각형과 빛 경로 사각형을 따로 넘겨 슬라임만 빛 경로 = `board_rect` (턴제는 보드 + 14px 그대로), 합체 잔상 A·B가 각자 `r_a`·`r_b`에서 줄어듦. 래퍼 340/340, 패리티·해시 그대로, `-Debug`만, 전체 캡처 (Codex). Claude 검수 (`50_slime_shell_play_busy` 위 변 확대·`51` 넷째 칸 두 비율, 재실행 없음): 빛이 보드 위 테두리 위에 있어 메시지 글자와 떨어지고, 흡수 잔상은 큰 쪽 하나만 커서 양옆 "귀"가 없다

## 12-M. 모드별 실력 차이 측정 — 세 모드를 같은 잣대로 (#89)

사용자 (2026-10-18): "세 가지 모드 중에 어느게 제일 나은 것 같아? 퍼즐 게임으로서" → Claude 의견 (CLASSIC — 다만 실력 차이를 숫자로 잰 것은 SLIME뿐) → **"세 가지를 측정항목으로 진행해줘"**

**목적**: 퍼즐다움 = "잘 고를수록 결과가 좋아지는가"를 세 모드에서 같은 방법으로 잰다. 관측만 — 수치·규칙은 바꾸지 않는다
- 지금까지: CLASSIC 측정은 고정 방향 순서 (`DIRECTION_PATTERN`)로만 돌렸고 전략이 없다. BLITZ는 무작위·휴리스틱 봇이 있다. SLIME은 복제 미리보기 봇 (무작위·공간 우선·합체 우선)이 있다

**공통 전략 3개** (세 모드 모두 같은 뜻 — 미리보기 없이 지금 판만 본다)
- **R 무작위**: 봇 난수로 4방향 균등 (게임 난수와 분리)
- **S 안전**: 지금 막히지 않은 방향 중에서 무작위. 막힘 = CLASSIC은 `TurnManager.blocked_directions` (게임이 보여 주는 막힘 경고와 같은 판정), SLIME은 그 방향 입구 여유 `< 0` (빨간 막대 중에서도 실제로 막힌 것), BLITZ는 그 방향 생성 벽에 빈자리가 없음. 다 막혔으면 R처럼
- **G 욕심**: S가 고를 수 있는 방향 중에서 **그 방향으로 정렬된 반응 쌍**이 가장 많은 방향 (동률은 봇 난수). 반응 쌍 = 그 모드 규칙으로 닿으면 반응하는 두 구슬, 중심 사이가 두 반지름 합의 3배 이내, 방향과 `|cos| ≥ 0.8` (지금 `run_blitz_measurement.gd`의 `_count_reaction_pairs`와 같은 식). CLASSIC은 합체·L7 잭팟·대폭발, SLIME은 같은 색 흡수·다른 색 MAX 둘, BLITZ는 지금 휴리스틱 그대로
- (참고) **SLIME 미리보기 봇** (#79의 공간 우선·합체 우선, 복제 시뮬레이션): 미리보기가 되는 SLIME에서만 "더 잘 고르면 어디까지 가나"의 위쪽 기준으로 함께 낸다. Jolt 모드는 상태 복제가 안 돼 하지 않는다

**조건**
| 모드 | 시드 | 전략 | 상한 | 끝 |
|---|---|---|---|---|
| CLASSIC | 1~30 | R·S·G | 600턴 | 게임오버 |
| SLIME | 1~100 | R·S·G + 미리보기 2개 | 250턴 | 게임오버 |
| BLITZ | 1~30 | R·S·G, 스와이프 간격 0.35초 고정 | 10분 | 시간 0 |

- 같은 시드는 세 전략이 **같은 생성 순서**로 시작한다 (게임 난수 같음, 봇 난수만 다름) → 같은 시드끼리 비교한다
- 지금 main 기본값 그대로 (설정·규칙 바꾸지 않음). 물리 해시·사용자 저장 파일 불변

**보고** (모드마다 표 하나 + 세 모드 요약 표)
- 전략별 중앙값·평균: CLASSIC·SLIME은 버틴 턴과 점수, BLITZ는 버틴 시간과 점수. 최대 레벨 (CLASSIC L7 도달 판 수, SLIME MAX 완성 수), 대폭발·잭팟·MAX CLEAR 수
- **실력 비** = G 중앙값 ÷ R 중앙값, S ÷ R (버틴 길이·점수 각각)
- **같은 시드 승률** = G가 R보다 오래 버틴 시드의 비율 (같으면 반)
- **운 비중** = R의 변동 계수 (표준편차 ÷ 평균) — 실력 비가 작고 변동이 크면 운이 결과를 정한다
- CLASSIC: 막힌 방향으로 밀어 끝난 판 비율 (S·G는 0에 가까워야 정상 — 아니면 경고와 실제 판정이 다르다는 뜻)
- 측정 시간 (모드별)

**판정 기준 (Claude, 해석용 — 넘지 못해도 실패가 아니라 정보)**
- 퍼즐다운 모드: 실력 비 (버틴 길이) ≥ 1.5, 같은 시드 승률 ≥ 80%
- 1.2 미만이면 결과를 운이 주로 정한다

**#89 결과 — 병합** ([PR #91](https://github.com/jeongmo-dot/gravity_orb/pull/91) `eb9e031`, 2026-10-18): 측정 도구만 추가 (`tests/tools/run_mode_skill_measurement.ps1` 한 줄 재실행), 게임 코드·설정 그대로, 해시 동일, 래퍼 340/340 (Codex). Claude 해석 (Codex 표, 재실행 없음):

| 모드 | 길이 G/R | 길이 S/R | 점수 G/R | 점수 S/R | G 같은 시드 승률 | R 길이 변동 | R 점수 변동 |
|---|---|---|---|---|---|---|---|
| CLASSIC (턴 중앙 R 201.5) | 0.76 | 1.05 | 0.12 | 1.01 | 0% | 0.085 | 0.57 |
| SLIME (턴 중앙 R 73) | 0.98 | 0.92 | 0.76 | 0.67 | 54% | 0.33 | 0.39 |
| BLITZ (생존 중앙 R 60.7초) | 0.52 | 0.93 | 0.03 | 0.94 | 0% | 0.25 | 0.59 |

1. **G (욕심) 전략이 잘못 만들어졌다 — Claude 명세 탓**: "그 방향으로 정렬된 반응 쌍"은 대부분 지금 중력축으로 이미 쌓여 있는 구슬 쌍이라, G가 **지금 중력 방향을 계속 다시 고른다**. BLITZ는 같은 방향 스와이프를 무시해 G가 멈춰 버리고 (생존 0.52배, 점수 0.03배), CLASSIC은 같은 벽에 생성만 쌓인다 (길이 0.76배, 점수 0.12배). 원래 BLITZ 휴리스틱은 직전 방향을 뺐는데 공통 정의에서 그것을 빠뜨렸다. **G 결과는 실력 측정으로 쓰지 않는다**
2. **CLASSIC 판 길이는 선택보다 생성 증가가 정한다**: 무작위 봇의 턴 수 변동이 8.5%뿐 (중앙 201.5턴)이고, 막힘 경고를 지키는 S도 4.5%만 더 버틴다 (210.5턴). R은 30판 모두 막힌 방향으로 밀어 끝나고, S도 27판이 네 방향이 다 막힌 뒤 (어쩔 수 없이 고른 수) 끝난다 → 미리보기 없는 봇 기준으로 **버티는 길이는 40턴마다 1개씩 늘어나는 생성이 거의 정한다**. 점수는 변동 57%로 대폭발·콤보 운이 크다
3. **SLIME은 미리보기가 있어야 실력이 보인다**: 미리보기 없는 S·G는 무작위와 같거나 못하다 (0.92·0.98). 판을 복제해 미리 돌려 보는 봇은 공간 우선이 길이 1.28배 (93.5턴), 합체 우선이 점수 1.18배 — 실제로 "생각하면" 나아지지만 §12-M 기준 (1.5배)에는 못 미친다
4. 정리: 세 모드 모두 기준을 넘지 못했다. 다만 **CLASSIC·BLITZ는 쓸 만한 봇이 없어서 생긴 결과**다 (Jolt 상태는 복제가 안 돼 미리보기 봇이 없다). 퍼즐다움을 숫자로 비교하려면 CLASSIC에도 미리보기 봇이 필요하다 — 다음 단계는 사용자 결정 (manual_qa "결정 대기") → 2026-10-18 "A안으로 진행" → §12-M.1 (#90)

### 12-M.1 CLASSIC 미리보기 봇 + G 고쳐 다시 재기 (#90)
사용자 (2026-10-18): #89 결과 설명 후 "A안으로 진행" — CLASSIC에도 미리보기 봇을 두고, G를 고쳐 다시 잰다

**1. G 고침 (세 모드 공통)**: 후보에서 **지금 중력 방향을 뺀다** (S 후보 중 지금 방향 말고 다른 방향이 있을 때. 지금 방향만 남으면 그것). 나머지 정의 (정렬된 반응 쌍 최대, 동률 봇 난수)는 그대로. 원래 BLITZ 휴리스틱과 같은 생각이다. R·S는 그대로

**2. CLASSIC 미리보기 봇 L** — SLIME의 복제 미리보기 봇과 같은 생각을 Jolt에서
- 입력 대기 때마다 지금 판을 **따로 만든 물리 공간 4개** (방향마다 하나, 각자 `World3D`)에 복사한다: 구슬 위치·회전·속도·레벨·색·상태 (유령·입구 대기), 중력, 턴 번호, NEXT 묶음 (뽑힌 내용과 선호 위치 그대로). 네 공간이 동시에 한 턴을 돈다 (생성·중력·반응·안정 판정·1.5초 상한까지 실제 `TurnManager` 규칙 그대로)
- 복사본은 실제 판과 비트 단위로 같지 않아도 된다 (Jolt 접촉 캐시 등) — 봇의 "어림"이면 된다. 복사본은 점수·저장·연출·소리를 바꾸지 않고, 끝나면 지운다
- 평가:
  - **L-공간**: `V = 다음 턴에 막히지 않은 방향 수 × 1,000 + (1 − 점유율) × 1,000`. 그 턴이 게임오버로 끝나면 `−1,000,000`
  - **L-합체**: `V = 그 턴 점수 증가 + L-공간 V`
  - 가장 큰 `V`의 방향 (동률은 봇 난수 × 0.01). 같은 방향 스와이프도 후보 (CLASSIC은 같은 방향도 생성이 들어오는 유효한 수)
- 고른 방향으로 실제 판을 한 턴 진행하고 다시 반복

**3. 선택이 중요한 순간** (L이 있는 CLASSIC·SLIME에서, 퍼즐다움의 직접 지표)
- **치명 회피 턴 비율**: 네 후보 중 적어도 하나는 그 턴에 게임오버, 적어도 하나는 아님인 턴의 비율 — "여기서 잘못 고르면 끝"인 순간이 얼마나 자주 오나
- **선택 폭**: 턴마다 네 후보 중 가장 좋은 것과 가장 나쁜 것의 차 — 다음 턴 막히지 않은 방향 수 차의 평균, 점수 증가 차의 중앙값
- SLIME은 #79 복제 미리보기 봇에 같은 집계를 붙인다

**조건**
| 모드 | 새로 돌릴 것 | 시드 | 상한 |
|---|---|---|---|
| CLASSIC | G (고친 것), L-공간, L-합체 | 1~30 | 600턴 |
| SLIME | G (고친 것) + 미리보기 2개에 "선택이 중요한 순간" 집계 | 1~100 | 250턴 |
| BLITZ | G (고친 것) | 1~30, 0.35초 | 10분 |

- R·S는 #89 결과를 그대로 쓴다 (그 뒤 게임 코드 변경 없음 — 바뀌었으면 다시)
- 보고: #89 표에 새 줄을 더한 세 모드 요약 (실력 비 G/R·L/R, 같은 시드 승률 L vs R, 치명 회피 턴 비율, 선택 폭), 모드별 상세, 측정 시간. L의 턴당 결정 시간 (벽시계)
- 판정 기준은 §12-M 그대로 (길이 1.5배·같은 시드 승률 80%)

**#90 결과 — 병합** ([PR #92](https://github.com/jeongmo-dot/gravity_orb/pull/92) `d9d47a3`, 2026-10-18 — Codex가 PR을 만들지 않아 Claude가 만들어 병합): 측정 도구만, 게임 코드 diff 0, 해시 동일, 래퍼 340/340. CLASSIC 미리보기는 방향별 `SubViewport`·`World3D` 4개에 판·NEXT·난수·점수 상태를 복제해 실제 한 턴 (결정 1회 0.9~1.2초, CLASSIC 측정 약 5시간) (Codex). Claude 해석 (Codex 표, 재실행 없음):

| 모드 | 가장 나은 봇 | 길이 (무작위 대비) | 점수 (무작위 대비) | 같은 시드 승률 | 치명 회피 턴 |
|---|---|---|---|---|---|
| **CLASSIC** | L-합체 (미리보기, 합체 우선) | **1.34배** (269 vs 201.5턴) | **2.41배** | **100%** | 0.4% |
| CLASSIC | G (고친 욕심) | 1.21배 | 1.27배 | 96.7% | — |
| SLIME | 미리보기 공간 | 1.28배 (93.5 vs 73턴) | 0.96배 | 77.5% | 0.6% |
| SLIME | 미리보기 합체 | 1.03배 | 1.18배 | 55.5% | 0.03% |
| BLITZ | G (고친 욕심) | 0.83배 | 1.06배 | 31.7% | — |

1. **실력이 결과로 가장 잘 드러나는 모드는 CLASSIC**: 미리보기 합체 봇이 30판 모두 무작위를 이기고 (100%), 점수 2.4배·길이 1.34배. 미리보기 없는 G도 96.7% 이긴다. SLIME은 가장 나은 봇도 길이 1.28배·같은 시드 77.5%, BLITZ는 봇 전략이 거의 의미 없다 (BLITZ의 실력은 손 빠르기 쪽 — 이 측정의 범위 밖)
2. **CLASSIC에서는 공간을 지키는 수보다 합체로 공간을 만드는 수가 낫다**: L-공간 (막히지 않은 방향·빈 면적만 봄)은 무작위보다 못하다 (길이 0.80배, 대폭발 276 vs 676). 합체·대폭발이 판을 비우는 수단이라, 당장 넓어 보이는 수가 길게는 손해 — 퍼즐로서 좋은 성질 (보이는 것과 좋은 수가 다르다). 다만 1수만 보는 봇의 한계일 수도 있다
3. **"여기서 잘못 고르면 끝"인 턴은 드물다** (CLASSIC 0.4~0.9%, SLIME 0.03~0.6%): 두 모드 모두 실력은 한 수의 생사보다 **여러 턴에 걸친 합체 쌓기**로 드러난다
4. **기준 (길이 1.5배)은 어느 모드도 못 넘었다**: CLASSIC 길이는 40턴마다 1개씩 느는 생성이 위를 막는다 (가장 나은 봇도 269턴). 점수로는 CLASSIC이 2.4배로 뚜렷하다
- 결론 (Claude): **퍼즐로는 CLASSIC이 가장 낫다** — #89 전의 의견을 이번에는 숫자가 받친다. 실력이 더 길게 버티는 것으로도 드러나게 하려면 생성 증가를 늦추는 것이 후보 (지금은 바꾸지 않음 — 사용자 결정)

## 12-R. 단계별 난도 — 색 수와 등장 수를 턴에 따라 늘리기 (CLASSIC·SLIME — #91 측정)

사용자 (2026-10-18): "클래식과 슬라임 모드 둘다 처음에는 색깔 수를 줄였다가 색깔 수와 한번에 등장하는 공 수를 늘리는 건 어때?" → Claude 의견 (좋다 — 첫 판이 쉬워지고 판에 고비가 생김. 점수로 열면 잘하는 사람이 빨리 어려워져 실력 차이가 줄어든다) → 사용자 결정: **턴 수 기준**, 일정은 **후보를 측정해 고른다**

**원칙**
- 새 색·등장 수는 **턴 번호로만** 정한다 (점수·판 상태와 무관 — 누구에게나 같은 일정). SLIME은 원본의 점수 해금을 턴 해금으로 바꾼다 (원본 변경, 사용자 결정)
- 새 색이 열리는 턴의 묶음 **첫 구슬은 새 색** (처음 보는 행성·슬라임이 바로 나온다). SLIME은 원본 규칙 그대로 앞 2개를 새 색으로 + 두 묶음 동안 최대 2개
- 미리보기 (CLASSIC NEXT·THEN, SLIME NEXT)는 그 묶음이 들어갈 **턴의 일정**으로 뽑는다 (2턴 전에 본 것이 그대로 들어온다는 규칙 유지)
- 이번 항목은 **측정만** — 새 설정 필드를 더하되 기본값은 지금 동작 그대로. 고른 일정은 측정 뒤 Claude가 값으로 넣고 (기획서 갱신과 같이), 새 색 등장 안내 연출은 그때 따로

**새 설정 필드** (기본값 = 지금 동작)
- CLASSIC (`GameConfig`): `turn_start_colors` (기본 6), `turn_color_unlock_turns` (기본 빈 배열 — 색이 하나 열리는 턴 목록). 색 순서는 지금 색 번호 순 — 처음 4색 = 화성·지구·천왕성·금성, 5번째 해왕성, 6번째 수성
- 등장 수는 지금 `spawn_count_per_turn` + `spawn_count_ramp_turns` (턴 `1 + ⌊(t − 1) / ramp⌋`개)를 그대로 쓴다
- SLIME (`SlimeConfig`): `color_unlock_mode` (`score` 기본 / `turn`), `color_unlock_turns` (turn일 때 4·5·6·7번째 색이 열리는 턴), `turn_floor_steps` (턴 → 최소 등장 수 표, 기본 30 → 2, 60 → 3 = 원본). 붐빌 때 줄이는 원본 규칙 (10개 미만 3~4 / 16개 미만 2 / 그 외 1)은 그대로, 최소 등장 수만 일정대로 올린다

**후보 일정**

| CLASSIC | 시작 색 | 새 색 (턴) | 등장 수 늘림 |
|---|---|---|---|
| C0 지금 (기준) | 6 | — | 40턴마다 +1 |
| C1 | 4 | 5색 40, 6색 80 | 40턴마다 +1 |
| C2 | 4 | 5색 30, 6색 60 | 50턴마다 +1 |
| C3 | 4 | 5색 50, 6색 100 | 60턴마다 +1 |

| SLIME | 시작 색 | 새 색 (턴) | 최소 등장 수 |
|---|---|---|---|
| S0 지금 (기준, 점수 해금) | 3 | 점수 5만·15만·30만·50만 | 30턴 2 · 60턴 3 |
| S1 | 3 | 15·30·45·60 | 30턴 2 · 60턴 3 |
| S2 | 3 | 20·40·60·80 | 20턴 2 · 40턴 3 · 60턴 4 |
| S3 | 3 | 25·50·75·100 | 25턴 2 · 50턴 3 · 75턴 4 |

**측정** (#89·#90 도구 그대로)
- CLASSIC: 후보마다 시드 1~20, 전략 R·G·L-합체, 600턴 상한. C0은 #89·#90 결과 (30판)를 그대로 쓴다
- SLIME: 후보마다 시드 1~100, 전략 R·G·미리보기 공간·미리보기 합체, 250턴 상한 (MAX 성장 켜짐 — 지금 기본)
- 보고 (후보마다): 전략별 턴·점수 중앙값, **실력 비** (가장 나은 미리보기 봇 / R, 길이·점수), 같은 시드 승률, R 길이 변동, **초반 합체율** (1~30턴의 턴당 합체 수 — 첫 판이 쉬운지), 판 끝 색 수 분포 (각 새 색이 실제로 나온 판 비율), 치명 회피 턴 비율, 측정 시간
- 게임 기본값·물리 해시·사용자 저장 파일 불변 (새 필드는 측정에서만 바꾼다)

**고르는 기준 (Claude)**
1. 무작위 봇 판 길이 중앙값이 지금과 크게 다르지 않게 — CLASSIC 150~250턴, SLIME 60~95턴 (한 판 길이 유지)
2. 그 안에서 **실력 비 (길이)가 가장 큰** 후보 — 1.5배 이상이면 가장 좋다
3. 초반 합체율이 C0·S0보다 높을 것 (첫 판이 쉬워졌는지)
4. 마지막 색이 무작위 봇 판에서도 절반 이상 나올 것 (일정이 판 길이에 맞는지)

**#91 결과 — 병합** ([PR #93](https://github.com/jeongmo-dot/gravity_orb/pull/93) `ea103ff`, 2026-10-19): 새 필드 (기본값 = 지금 동작 — 해시·패리티 그대로), 해금 턴 첫 구슬 강제·미리보기 들어갈 턴 일정, 측정 도구 (`tests/tools/run_staged_difficulty_measurement.ps1`). 래퍼 343/343 (Codex). Claude 해석 (Codex 표·`artifacts/measurements/staged_difficulty_report.json`, 재실행 없음):

| CLASSIC | R 턴 중앙 | L-합체 턴 | 실력 비 길이 / 점수 | 같은 시드 | R 초반 합체/턴 | 5·6색 등장 |
|---|---|---|---|---|---|---|
| C0 지금 | 201.5 | 269 | 1.34 / 2.41 | 100% | 0.510 | — |
| C1 (40·80, 램프 40) | 194 | 277.5 | 1.43 / 3.96 | 100% | 0.590 | 100% |
| **C2 (30·60, 램프 50)** | **221** | **327** | **1.48** / 2.72 | 100% | 0.595 | 100% |
| C3 (50·100, 램프 60) | 257.5 (범위 밖) | 379.5 | 1.47 / 3.14 | 100% | 0.617 | 100% |

| SLIME | R 턴 중앙 | 최고 미리보기 | 실력 비 길이 / 점수 | 같은 시드 | R 초반 합체/턴 | 4·5·6·7색 등장 |
|---|---|---|---|---|---|---|
| S0 원본 (점수 해금) | 73 | 공간 93.5 | 1.28 / 0.96 | 77.5% | 3.11 | 96·65·2·0% |
| S1 (15턴마다) | 64 | 공간 64 | 1.00 / 0.55 | 57% | 2.85 | 100·100·85·66% |
| S2 (20턴마다, 최소 4개) | 52 (범위 밖) | 합체 60 | 1.15 / 1.46 | 57.5% | 2.97 | 100·85·26·1% |
| **S3 (25턴마다, 최소 4개)** | **65.5** | 합체 73 | **1.11 / 1.37** | 56.5% | 3.04 | 97·62·39·0% |

- **CLASSIC → C2**: 기준을 모두 만족한다 — 판 길이 범위 안 (221턴, 지금보다 약 10% 길다), 범위 안 실력 비 최고 (1.48배 — 1.5배 기준에 거의 닿음, 지금 1.34배), 초반 합체가 지금보다 17% 잦다 (첫 판이 쉬워짐), 5·6색이 모든 판에 나온다. 가장 잘 두는 봇은 327턴까지 간다 (지금 269턴) — 실력이 **오래 버티는 것으로도** 드러나기 시작했다
- **SLIME → S3**: 턴 해금 후보는 모두 원본 (S0)보다 실력 비가 낮다. 다만 S0의 높은 실력 비 (공간 1.28배)는 **점수 해금의 허점**에서 온다 — 미리보기 공간 봇은 점수를 덜 내서 (R보다 낮음) 색이 늦게 열리고 그래서 오래 버틴다. "점수를 일부러 안 내야 쉬워지는" 규칙은 사용자가 고른 턴 기준의 이유 그대로다. 턴 후보 중 S3는 판 길이가 범위 안이고 (65.5턴), 4·5번째 색이 원본과 거의 같은 때 나오며 (97·62%, 원본 96·65%), 초반 합체도 원본과 거의 같다 (−2%). 6번째 색은 39%로 원본 (2%)보다 자주 나온다. 7번째 색은 여전히 거의 안 나온다 (판이 그 전에 끝남). 실력 비는 길이 1.11·점수 1.37 — SLIME은 가볍게 즐기는 모드로 본다
- 결정 (Claude, 2026-10-19): **CLASSIC C2, SLIME S3** → §12-R.1 (#92)에서 기본값으로
- **바꿈 (사용자 2026-10-19 "slime 모드의 난이도를 조금 더 증가시키고 싶어") → SLIME S2**: 이미 잰 후보 중 S3보다 어렵다 — 무작위 판 길이 65.5 → **52턴** (약 20% 짧음, 원본 73턴), 색 20턴마다·최소 등장 수 20·40·60턴에 2·3·4개. 실력 비는 오히려 조금 높다 (길이 1.15·점수 1.46 vs S3 1.11·1.37), 5번째 색 85%·6번째 26% 판에서 나온다. §12-R 판 길이 범위 (60~95턴)는 사용자 요청으로 SLIME만 낮춘다

### 12-R.1 단계별 난도 적용 + 새 색 등장 안내 (#92, 기획서 0.14)
**값** (기본값으로)
- CLASSIC: `turn_start_colors` **4**, `turn_color_unlock_turns` **[30, 60]** (**30턴째 묶음부터 5색 (해왕성), 60턴째 묶음부터 6색 (수성)** — 측정과 같은 해석), `spawn_count_ramp_turns` 40 → **50** (1~50턴 1개, 51~100턴 2개 …)
- SLIME: `color_unlock_mode` **turn**, `color_unlock_turns` **[20, 40, 60, 80]**, `turn_floor_steps` **[(20, 2), (40, 3), (60, 4)]** (S2 — 사용자 요청으로 S3에서 바꿈). 붐빌 때 줄이는 원본 규칙·새 색 앞 2개·두 묶음 최대 2개는 그대로
- BLITZ: 바꾸지 않는다 (6색 처음부터)

**새 색 등장 안내** (CLASSIC — SLIME은 원본 메시지 "새로운 색상 해금!  n / 7"을 그대로 쓴다)
- 새 색이 열리는 턴에 입력이 풀리기 전 (그 턴 묶음이 들어오는 순간) 보드 위쪽에 호령 자리 (§12-P 호령과 같은 자리·글꼴)로 **"새 행성 — 해왕성"** / **"새 행성 — 수성"** 1.2초. 글자 옆에 그 행성 2D 그림 (L2 크기). 호령과 겹치면 호령 뒤에 이어서
- NEXT·THEN 미리보기에 그 색이 처음 보일 때 칸 테두리가 그 색으로 한 번 반짝 (0.6초) — 미리 알 수 있게
- 소리: 기존 해금·잭팟 계열 합성음 중 짧은 것 하나 (새 소리 만들지 않음)
- 시작 화면·결과·랭킹은 그대로. 랭킹은 이어서 쓴다 (점수 크기가 비슷 — C2 무작위 점수 중앙 124k, 지금 126k)

**검수**
- 테스트: 기본값에서 CLASSIC 1~29턴 4색만, 30턴 묶음 첫 구슬 해왕성, 60턴 첫 구슬 수성, 등장 수 50턴마다 +1, SLIME 20·40·60·80턴 해금·최소 등장 수 표. 안내가 해금 턴에 한 번만, 미리보기 반짝임 한 번만
- 해시: CLASSIC·SLIME 기본 동작이 바뀌므로 **새 기준 해시**를 보고 (이전 값과 다름이 맞다). BLITZ 해시는 그대로. SLIME 원본 패리티는 `color_unlock_mode = score`·원본 표로 두고 그대로 통과
- 봇 확인: C2·S2로 R 10판씩 — #91 측정과 같은 범위인지 (CLASSIC 무작위 중앙 약 221턴, SLIME 약 52턴)
- 캡처: `52_new_planet_callout` 두 비율 (CLASSIC 30턴 안내 + NEXT 반짝), 기존 `01`·`02` 등 CLASSIC 캡처는 4색으로 바뀐 것 확인

**#92 결과 — 병합** ([PR #94](https://github.com/jeongmo-dot/gravity_orb/pull/94) `3ea4f0b`, 2026-10-19): CLASSIC C2·SLIME S2 기본값, `TurnManager.planet_unlocked` 신호 (해금 턴이 **끝나고** 입력이 풀리기 직전 — 새 행성은 그 턴에 이미 들어와 있고, 안내는 "방금 들어온 그 행성"을 알려 주는 셈), 안내는 호령 대기열 뒤에 이어서, 미리보기 칸 테두리 0.6초 1회. 새 기준 해시 CLASSIC `cf617242…`·SLIME `7ebe5d76…` (BLITZ 그대로), SLIME 원본 패리티 (score 모드) 통과, 봇 확인 R 10판 CLASSIC 중앙 224.5턴·SLIME 50.5턴 (#91 221·52 근처), 래퍼 348/348, 전체 캡처 148장 (Codex). Claude 검수 (`52`·`02` 확인, 재실행 없음): 안내 글자·해왕성 그림·NEXT 보라 테두리 겹침 없음, 시작이 4색
- **#93 결과 — 병합** ([PR #95](https://github.com/jeongmo-dot/gravity_orb/pull/95) `c18e0e2`, 2026-10-19): `SPAWNING`에서 `try_spawn()`이 돌려준 구슬 중 새 색이 있으면 `planet_unlocked` (턴 끝 신호 제거), 행성마다 한 번. Claude 검수 (`52` 확인, 재실행 없음): 해왕성이 왼쪽 입구에 나타난 프레임에 안내가 떠 있다. `52`의 NEXT 보라 테두리는 캡처가 생성 직전에 미리보기 색을 바꿔 생긴 것이라 실제 플레이와 다르다 (실제로는 THEN에 처음 보일 때 한 번)
- **안내 시점 바꿈** (사용자 2026-10-19 "들어오는 순간에 뜨는게 좋지") → #93: `planet_unlocked`를 해금 턴이 끝날 때가 아니라 **그 턴 묶음이 생성되는 순간** (스와이프 → `SPAWNING`에서 `try_spawn` 직후, 새 행성 구슬이 입구에 나타나는 프레임)에 보낸다. 안내 1.2초는 그 턴 움직임과 함께 흐른다. 호령 대기열 규칙 (먼저 온 것이 끝나면 다음)·미리보기 테두리·소리는 그대로. 턴 끝 신호는 없앤다 (게임당 행성마다 한 번)

## 12-JE. 네 번째 모드 JELLY (가칭) — CLASSIC과 SLIME 사이 (기획서 0.15 — #95~#97)

사용자 (2026-10-21): "클래식과 슬라임의 중간 버전이 필요할 것 같아" → Claude 축별 정리 → 사용자 선택: **합체 규칙·FINAL MOVE·대폭발 빼기**를 부드럽게, **새 모드 (4번째)**, 그림은 **"3d 행성이 아닌 3d 젤리로"**

**한 줄**: CLASSIC의 3D 물리·턴·미리보기·단계별 난도 위에서, 같은 색이면 한 단계 작은 것도 먹으며 자라는 3D 젤리. 대폭발은 없고, 막혀도 마지막 기회가 한 번 있다.

- 이름은 가칭 `JELLY` (시작 카드·랭킹 탭·`--mode=jelly`·`GameConfig.GameMode.JELLY` = 3). 사용자가 바꾸면 따른다
- 위치: **CLASSIC보다 쉽고 너그럽고, SLIME보다 생각할 거리가 많다** — 측정으로 확인한다 (§12-JE.4)
- CLASSIC·SLIME·BLITZ의 규칙·해시는 바꾸지 않는다

### 12-JE.1 규칙 (CLASSIC 턴제 위에서 바꾸는 것만)
**흡수 합체** (같은 색)
- 구슬마다 **질량**: L1 = 1, L2 = 2, L3 = 4 … L7 = 64 (`2^(L−1)`). 생성 구슬은 그 레벨의 질량
- 같은 색 둘이 닿고 **레벨 차이가 1 이하**면 합쳐진다. 결과 질량 = 합 (상한 64), 레벨 = 질량으로 (`⌊log2 m⌋ + 1`)
  - 같은 레벨 `L + L` → 정확히 `L+1` (CLASSIC 합체와 같다). 위치는 두 중심의 중점 (CLASSIC 그대로)
  - 한 단계 차이 `L + (L−1)` → **큰 쪽이 작은 쪽을 먹는다**: 레벨 `L` 그대로, 질량 1.5배 (다음 레벨까지 절반). 같은 일을 한 번 더 하면 `L+1`. 위치는 큰 쪽 자리 (먹는 쪽이 그대로 있고 작은 쪽이 빨려 든다)
  - 레벨 차이 2 이상은 반응 없음 (부딪히기만 한다)
- **크기** (→ 2026-10-25 §12-JE.9에서 **레벨 반지름 고정**으로 바뀜): 레벨 사이를 질량으로 보간 — `r = lerp(R[L], R[L+1], (m − 2^(L−1)) / 2^(L−1))` (`R` = CLASSIC `level_radii` 25·40·60·85·100·120·140). L7은 140. 물리 크기도 같이 (기존 `Orb3D` 성장 보간 그대로)
- **L7**: 같은 색 `L7 + L7` → 잭팟 (CLASSIC `MAX_CLEAR` 그대로 — 둘 다 사라짐, 640점, 충격파). 같은 색 `L7 + L6` → L7이 먹는다 (질량 상한 64라 크기 그대로, L6만 사라진다 — 판 청소)
- **점수**: 레벨이 오르면 `score_for_level(새 레벨)` (CLASSIC 합체와 같음), 그대로면 `score_for_level(먹힌 쪽 레벨)`. 콤보 배수·위험 배수·잭팟은 CLASSIC 그대로
- **색 효과** (§7.6)·순차 연쇄 잠금 (§7.5)은 흡수에도 그대로 (세기는 결과 레벨 기준)

**대폭발 없음**: 이 모드는 `BLAST`를 만들지 않는다 — 다른 색끼리는 절대 반응하지 않는다 → **#98 측정 뒤 L5부터 대폭발** (`jelly_blast_min_level` 5 — §12-JE.5. 실력 비가 1.03 → 1.47) → **#120에서 L6부터** (§12-ONE.13)

**FINAL MOVE** (CLASSIC 게임오버 판정을 한 번 미룬다)
- CLASSIC에서 게임오버가 되는 순간 (턴 끝에 입구 대기 구슬이 남음, §11.2) → 게임오버 대신 **FINAL MOVE 대기**
- 다음 스와이프는 **새 구슬 없이** 중력만 바뀐다 (NEXT·THEN은 그대로 다음 턴으로 넘어간다). 입구에서 기다리던 구슬은 계속 기다리다 자리가 나면 들어간다
- 그 턴 끝에 대기 구슬이 모두 들어갔으면 계속, 하나라도 남았으면 게임오버
- 표시: FINAL MOVE 대기 중 보드 위쪽에 "FINAL MOVE" 띠 (노랑 테두리 깜빡임 — SLIME 띠와 같은 생김새, 이 모드 글꼴·크기로) + 메시지 "막혔어요 · 한 번의 이동으로 입구를 비우세요"

**그대로 (CLASSIC과 같음)**: 3D 물리·중력·안정 판정·1.5초 상한, 생성 위치·NEXT·THEN, **단계별 난도** (4색 시작 → 30턴 5색·60턴 6색, 공 50턴마다 +1 — 측정 뒤 조정), 입력 표시 (화살표·막힘 표시 — 이 모드에서 막힘은 FINAL MOVE로 이어진다는 경고), 히트스톱·흔들림

### 12-JE.2 3D 젤리 그림 (사용자: "3d 행성이 아닌 3d 젤리로")
- **색** (CLASSIC 색 번호에 맞춘 SLIME 팔레트): 0 분홍 `#FF7595`, 1 파랑 `#72A7FF`, 2 초록 `#59E2AB`, 3 노랑 `#FFE77A`, 4 보라 `#BC86FF`, 5 주황 `#FFAD63`. 시작 4색 = 분홍·파랑·초록·노랑, 30턴 보라, 60턴 주황. 레벨마다 `lightened(L × 0.018)` (SLIME과 같음)
- **몸통**: 구 메시에 젤리 셰이더 — SLIME 재질 식 (§12-G.6)을 3D 노멀로: `diffuse × 0.34`, 넓은 반사 (`^11 × 0.055`), 날카로운 반사점 (`^72`), 가장자리 빛 (`(1 − n·v)^2.2`), 아래쪽 산란. **빛 방향은 화면 기준 (위·왼쪽)으로 고정**해 구슬이 굴러도 반사점이 늘 같은 자리 — 젤리는 무늬가 없어 구르는 회전이 보이지 않는다. 가장자리가 살짝 비치는 반투명 느낌 (가장자리 알파 0.9 → 안쪽 1.0), 안쪽이 조금 밝은 젤
- **얼굴**: 몸통 앞에 카메라를 보는 얼굴 판 (지금 문양 메시와 같은 방식), 크기 ∝ 반지름. 세로 캡슐 눈 + 반사점, L7은 MAX 표정 (반달눈·볼·미소), 대기 중 깜빡임 — 모양·비율은 SLIME 얼굴 (§12-G.6)과 같게. 얼굴은 **중력 쪽으로 천천히 돈다** (SLIME 규칙)
- **말랑함** (메시만 — 물리 그대로): 떨어질 때 중력 방향으로 늘어남 (최대 `1 + 0.19` / `1 − 0.10`), 부딪히면 찌그러짐 (`1 + 0.18i` / `1 − 0.20i`), 대기 중 숨쉬기 ±1.8%, 합쳐질 때 부풀기 (`visual_scale` 0.88 → 1) — 수치는 SLIME과 같다. 행성에서 끈 늘어남 (§12-P.4)은 젤리에는 맞으므로 이 모드만 켠다 (무늬가 없어 방향 회전이 튀지 않음)
- **연출**: CLASSIC 합체·잭팟·색 효과 연출을 젤리 색으로. 행성 전용 (L6·L7 빛무리·홍염 등)은 MAX 젤리 **반짝임** (몸통 가장자리 흰 빛 맥동)으로 바꾼다. 흡수는 작은 쪽이 큰 쪽으로 빨려 드는 잔상 (SLIME 잔상과 같은 생각, 각자 자기 크기)
- **소리**: CLASSIC "뽁" 계열 그대로 (젤리와 맞다)
- **문양 설정** (색각): 켜면 얼굴 아래쪽에 작은 문양
- 보드·배경·HUD는 CLASSIC 그대로

**#96 1차 결과** (PR #99, 2026-10-22): J5 기본값 (`jelly_blast_min_level` 5), JELLY 전용 `JellyOrbArt` (6색·화면 고정 빛·반투명 가장자리·MAX 흰 맥동), 얼굴 판·깜빡임·문양, 말랑함 (메시 자식만 — 충돌체 그대로), 젤리 색 합체·대폭발·흡수 꼬리, 행성 코로나·홍염 제거. 다른 모드 그림·해시 그대로, JELLY 그림 켜고 끈 해시 동일, 래퍼 364/364, 창 40개 p99 3.51ms, 전체 캡처 162장 (Codex). 젤리 몸통·색·크기 단계·붐비는 판·늘어남은 좋다 (SLIME과 같은 귀여움이 3D로 산다). Claude 검수 (`53_jelly_look_*` 두 비율 확대, 재실행 없음)에서 찾은 것:
- **MAX 얼굴이 위아래로 뒤집혀 있다** (`53_jelly_look_max`·`_levels`의 L7): 반달눈이 `∪`로 아래쪽에, 미소가 `∩`로 눈 **위**에 있어 찡그린 얼굴로 읽힌다. SLIME 원본은 눈이 중심 위 (`−0.12r`)에 `∩`, 미소가 중심 아래 (`+0.12r`)에 `∪`, 볼은 `+0.11r`. 2D 그리기 좌표 (y 아래)를 3D 얼굴 판 (y 위)으로 옮기며 뒤집혔거나 중력 쪽 회전이 180° 어긋난 것으로 보인다. 보통 얼굴은 캡슐 눈이 위아래 대칭이라 티가 안 나지만 반사점 위치 (원본 왼쪽 위)도 같이 뒤집혔을 것이다
- **NEXT·THEN 미리보기가 행성 그대로**다 — JELLY 판에 젤리가 나오는데 미리보기는 화성·지구 그림
- 같은 이유로 새 색 안내도 "새 행성 — 해왕성"과 행성 그림, 미리보기 테두리는 행성 표시색으로 나올 것이다 (§12-R.1)

**#96 추가 요구 1** (같은 브랜치)
1. 얼굴 방향: 중력이 아래일 때 SLIME 원본과 같은 모양 (눈이 위·미소가 아래·볼은 미소 높이 양옆·반사점은 눈의 왼쪽 위). 다른 중력에서는 그 얼굴 전체가 중력 쪽을 아래로 돈다. **회귀 테스트**: 얼굴 텍스처 (또는 판의 화면 투영)에서 중력 아래일 때 미소 중심이 눈 중심보다 화면 아래, 중력 오른쪽이면 미소가 눈보다 화면 오른쪽 — 지금 코드로 실패해야 한다
2. NEXT·THEN 미리보기: JELLY에서는 2D 젤리 (그 색·레벨 밝기, SLIME 재질 식, 캡슐 눈 / L7은 MAX 얼굴) — `OrbVisual`의 JELLY 경로
3. 새 색 안내: JELLY에서는 **"새 젤리 — 보라"** / **"새 젤리 — 주황"** + 그 젤리 2D 그림, 미리보기 테두리는 젤리 색. 소리·시점 (생성 순간)·대기열 그대로. CLASSIC은 그대로
4. 캡처 `53_jelly_look_*` 다시 + `53_jelly_look_unlock` (30턴 새 젤리 안내 + NEXT 젤리) 두 비율. **마지막은 전체 캡처**
5. **MAX 얼굴을 시안 C로 바꾼다** (사용자 2026-10-23 "웃는 얼굴이 안 예뻐" → Claude 시안 4개 [`docs/mockups/jelly_max_faces.png`](mockups/jelly_max_faces.png) → **C. 반짝 눈 + 고양이 입**). 원본 SLIME MAX 얼굴 (가는 반달눈·작은 미소)은 큰 L7 위에서 작고 가늘어 보였다. 길이는 몸통 반지름 `r` 기준, 중력이 아래일 때:
   - 눈: 짙은 남보라 `#1B1630` 타원 (가로 반지름 `0.09r`, 세로 `0.13r`), 중심 `(±0.26r, −0.08r)`
   - 반사점 (두 눈 모두 같은 방향 — 빛이 왼쪽 위): 흰 원 반지름 `0.04r`를 눈 중심 `(−0.03r, −0.06r)`에, 흰 원 `0.02r`를 `(+0.04r, +0.06r)`에
   - 입 `ω`: 반지름 `0.06r` 아래로 볼록한 호 두 개 — `(−0.12r, 0.14r)` → `(0, 0.14r)`, `(0, 0.14r)` → `(0.12r, 0.14r)`, 두께 `0.04r`, 끝 둥글게
   - 볼: `#FF4F7F` 알파 0.45 타원 (가로 `0.12r`, 세로 `0.07r`), 중심 `(±0.46r, 0.16r)`
   - 깜빡임은 보통 얼굴처럼 (눈만 가로선, 입·볼 그대로). MAX 흰 맥동·고리·반짝임은 그대로
   - SLIME 모드의 MAX 얼굴은 원본 그대로 둔다 (이 변경은 JELLY만)

**#96 결과 — 병합** ([PR #99](https://github.com/jeongmo-dot/gravity_orb/pull/99) `7d20bd9`, 2026-10-23): 추가 요구 1의 1~5 반영 — 얼굴 방향 (화면 좌표 회귀 테스트), JELLY NEXT·THEN 2D 젤리, "새 젤리 — 보라/주황" + 젤리 그림·젤리색 테두리, MAX 얼굴 시안 C (`JellyOrbArt` 상수 한 벌을 3D·2D가 공유). 다른 모드 해시 그대로, JELLY 그림 켜고 끈 해시 동일, 래퍼 366/366, 창 40개 p99 3.09ms, 전체 캡처 164장 (Codex). Claude 검수 (`53_jelly_look_max`·`_unlock`·`_levels` 확대, 재실행 없음): 얼굴이 바로 섰고 (눈 위·`ω` 입 아래), 미리보기·안내가 젤리다
- 남은 것 → #97 첫 요구: **3D MAX 얼굴이 시안의 약 60% 크기**다. `Orb3D`가 얼굴 판을 `radius_m × 0.62`로 놓아 (보통 얼굴용 배율), 몸통 반지름 기준 상수가 0.62배로 그려진다 — 눈 간격 `±0.18r`·눈 높이 `0.07r` (명세 `±0.26r`·`0.13r`). 2D 미리보기는 명세에 가깝다. MAX (L7) 얼굴만 판 배율을 몸통 반지름 그대로 (1.0)로 하거나 상수를 판 기준으로 나눠 **3D와 2D가 같은 비율**이 되게. 보통 얼굴은 그대로

### 12-JE.3 앱 연결
- 시작 화면: 카드 4장 — 위 줄 BLITZ·CLASSIC (그대로), 아래 줄을 반으로 나눠 **JELLY (왼쪽)·SLIME (오른쪽)** (각 폭 = 위 카드와 같게, 높이 132 → 150). 아이콘 줄은 아래로 밀리면 비율별로 맞춘다. JELLY 카드: 아이콘 = L3 분홍 젤리 얼굴, 설명 "한 단계 작은 것도 먹고 자라요", BEST, 강조색 `#FF7595`
- 랭킹: JELLY 탭 (열은 CLASSIC과 같게 + FINAL MOVE 횟수), 저장 키 `jelly`, 마지막 모드 `"jelly"`
- 결과 화면: CLASSIC 결과 + "FINAL MOVE n번 버팀"

**#97 결과 — 병합** ([PR #100](https://github.com/jeongmo-dot/gravity_orb/pull/100) `d6a77a5`, 2026-10-23): 시작 화면 카드 4장 (아래 JELLY·SLIME 반씩), JELLY 카드 (L3 분홍 젤리·설명·BEST·`#FF7595`), 랭킹 탭 BLITZ·CLASSIC·JELLY·SLIME (JELLY 열: 점수·최대 콤보·FINAL MOVE·날짜), 저장 키 `jelly`·마지막 모드, 결과 "FINAL MOVE n번 버팀", 왕복 테스트, **3D MAX 얼굴을 몸통 반지름 비율로** (얼굴 판 배율 L7 젤리만 1.0). 래퍼 370/370, 전체 캡처 170장, 사용자 저장 파일 불변 (Codex). Claude 검수 (`54_jelly_shell_*`·`53_jelly_look_max`, 재실행 없음): MAX 얼굴이 시안 C 크기, 카드·랭킹·결과 겹침 없음. 남은 것 → #99:
- **결과 화면의 "최고 천체 — L7 태양"**: `GameOverPanel`이 V3 천체 사다리 이름 (운석·달·바위 행성·고리 행성·가스 거인·별·태양)을 아직 쓴다 — 행성 컬렉션 (#74) 이후 레벨은 크기일 뿐이라 CLASSIC에서도 틀리고, JELLY에서는 젤리인데 "태양"이 나온다
- **아래 줄 반쪽 카드 설명 글자가 너무 작다**: "한 단계 작은 것도 먹고 자라요"가 두 줄로 접히며 위 카드 설명보다 작다 (540 폭 캡처에서 글자 높이 약 8px — 폰에서 1mm 안팎). SLIME 카드도 같다

#### 12-JE.6 결과 화면 이름·반쪽 카드 글자 (#99)
- 결과 화면 최고 레벨 칸: CLASSIC은 **"최고 레벨 — L7"** (레벨 숫자만, 천체 이름 없음), JELLY는 **"최고 젤리 — L7 MAX"** (L7일 때만 MAX, 그 아래는 `L5`처럼). BLITZ·SLIME 결과는 그대로. 천체 이름 표는 지운다
- 아래 줄 카드 설명을 **한 줄**로 짧게 — JELLY "작은 것도 먹고 자라요", SLIME "크기 상관없이 흡수". 글자 크기는 위 카드 설명 (BLITZ "시간 버티기")과 같게. 카드 높이·배치는 그대로, 두 비율에서 잘림 없이
- 검수: 캡처 `54_jelly_shell_{start,result}`·CLASSIC 결과 캡처 두 비율, 테스트 (레벨 칸 문구 세 경우)

**#99 결과 — 병합** ([PR #101](https://github.com/jeongmo-dot/gravity_orb/pull/101) `9cc17a0`, 2026-10-23): `GameOverPanel` 천체 이름 표 (`LEVEL_NAMES_KO`) 삭제, 레벨 칸 CLASSIC "최고 레벨 / L7"·JELLY "최고 젤리 / L5" (L7만 `L7 MAX`). 반쪽 카드 설명 JELLY "작은 것도 먹고 자라요"·SLIME "크기 상관없이 흡수", 글자 18·16 → 28 (위 카드 설명과 같음), 툴팁 문구도 같게. 테스트 세 경우 (CLASSIC L4·JELLY L6·JELLY L7 MAX)와 캡처 검사 추가. 래퍼 370/370, 전체 캡처 170장, 사용자 저장 파일 불변 (Codex). Claude 검수 (`54_jelly_shell_start` 두 비율·`54_jelly_shell_result`·`04_turn_game_over`, 재실행 없음): 설명 한 줄·잘림 없음, 레벨 칸 문구 바름

#### 12-JE.7 젤리 움직임 다듬기 — 지글거림·툭툭 튐 (#101)
사용자 (2026-10-25, 0.15.0 빌드 플레이): "젤리 모드 공이 움직이는 동안 이질감이 크네.. 자연스럽지가 않고 툭 툭 튀는 느낌이야", "지글거림이 있어. 불쾌한 느낌이야" (스크린샷: 중력 오른쪽, 오른쪽 벽에 쌓인 판)

**진단 (Claude, 코드 읽기 — 실행 없음)**: §12-JE.2 말랑함은 "수치는 SLIME과 같다"였는데, 수치만 같고 **방식이 다르다**. SLIME (`SlimeSim._update_motion_visual`·`_update_visual_state`)은 모양 하나 (`deform`)가 목표를 부드럽게 따라가고 축이 중력 기준인데, JELLY (`Orb3D`)는 크기를 매 프레임 새로 계산하거나 한 번에 바꾼다.

| # | 지금 JELLY | 자리 | SLIME 원본 |
|---|---|---|---|
| 1 | **닿을 때마다 찌그러짐을 새로 시작** — 접촉 시작마다 (벽 포함) `play_jelly_impact(clamp(속력 ÷ 1100, 0.18, 1))`. 최소 0.18이라 멈춰 있는 구슬도 한 프레임에 3.6% 이상 튀고, `TRANS_BACK`이라 1을 넘었다 돌아온다. 붐비는 판에서 쉬는 구슬끼리 접촉이 끊겼다 이어질 때마다 반복 → **지글거림의 주범으로 본다** | `Board3D._on_orb_body_entered`, `Orb3D.play_jelly_impact` | 다가오는 상대 속도 ÷ 850 (0부터), 매 프레임 `−4.8/s`로 줄고, 모양이 목표를 따라감 |
| 2 | **늘어남이 속력에서 바로** — `smoothstep(700, 1100, 속력)`를 따라가기 없이 씀. 부딪히는 한 스텝에 1.19 → 1.0. 메시 회전은 속력 700 경계에서 0 과 속도 방향 사이를 순간 전환 | `Orb3D._visual_stretch_ratio`·`_update_visual_transform` | `deform`이 목표를 `delta × 11`로 따라감, 축은 중력 방향 (회전도 `delta × 8`로 따라감) |
| 3 | **찌그러짐 축이 반대** — 메시 로컬 x 줄고 y·z 늘어남. 쉬는 구슬 (회전 0)은 늘 좌우로 눌리고, 떨어져 내려앉는 구슬은 납작해지지 않고 홀쭉해진다 | `Orb3D.play_jelly_impact` | 중력 쪽으로 납작 (가로 `1 + 0.18i`, 중력 쪽 `1 − 0.20i`) |
| 4 | **숨쉬기가 켜졌다 꺼짐** — 구슬마다 속력 140 미만일 때만, 크기 전체를 키움. 경계에서 최대 1.8%씩 튐 | `Orb3D._update_visual_transform` | 판 전체가 멈춘 동안만, 가로 `1 + b`·중력 쪽 `1 − b` |
| 5 | **얼굴과 몸통 축이 어긋남** — 얼굴 판은 얼굴 회전 축에 늘어남 x·y를 곱한다. 몸통이 세로로 늘어날 때 얼굴은 가로로 | `Orb3D._update_visual_transform` | 얼굴도 같은 변형 안에서 그림 |
| 6 | **흡수한 구슬이 한 번에 커짐** — `set_jelly_mass`가 물리·그림 반지름을 즉시 바꿈. 한 단계 작은 것을 먹으면 제자리에서 약 10px 커지며 이웃을 한 스텝에 밀어냄 (툭) | `Orb3D.set_jelly_mass` | — |
| 7 | **화면 164Hz · 물리 120Hz · 보간 없음** — 그림이 `_process`에서 `_body.position`을 그대로 읽어, 164Hz 화면에서 물리 위치가 1프레임·2프레임씩 고르지 않게 보인다 (움직이는 동안 떨림). 사용자 화면 164Hz (RTX 4070 Ti SUPER, 2560 폭). **3D 모드 전체** (CLASSIC·BLITZ도) | `project.godot` `physics_ticks_per_second=120`, `Orb3D._update_visual_transform` | (원본은 화면 갱신마다 그림) |

**고칠 것** — JELLY 말랑함을 SLIME 방식으로 다시 (수치는 SLIME, 속력 기준만 JELLY 판에 맞춤)
1. **젤리 틀**: 구슬마다 틀 회전 하나 — 중력 방향 각으로 `lerp_angle(…, min(delta × 8, 1))`. 몸통 메시와 얼굴 판이 이 틀을 함께 쓴다. JELLY는 속도 방향 회전을 쓰지 않는다 (`JELLY_FACE_TURN_SPEED` 2.4 → 틀 속도 8). 얼굴이 중력 쪽으로 도는 것은 그대로 — 사용자 (2026-10-25) "지금처럼 돌기"
2. **모양 `deform` 하나** (틀 기준 가로, 중력 쪽):
   - 떨어지는 중 목표: `s = clamp(max(0, v·g) ÷ 5800, 0, 0.19)` → `(1 − 0.55s, 1 + s)` — `v·g` = 중력 방향 속력 (px/s), 1100에서 최대 (지금과 같은 자리)
   - 찌그러짐 중 목표: `(1 + 0.18i, 1 − 0.20i)` (SLIME 그대로, 1보다 앞섬)
   - 판이 멈춘 동안 (턴 입력 대기) 목표 `(1, 1)`
   - 따라가기: 매 프레임 `deform = deform.lerp(목표, min(delta × 11, 1))` — 목표로 건너뛰지 않는다
   - `play_jelly_impact`의 즉시 크기 변경·`TRANS_BACK` 트윈, 속력 `smoothstep` 늘어남은 JELLY에서 없앤다
3. **찌그러짐 세기 `i`**: 접촉 이벤트로 켜지 않는다. 물리 스텝마다 속력이 줄어든 양으로 — `i = clamp((|v_prev| − |v_now|) ÷ 1000, 0, 1)`, `i < 0.06`이면 무시, `impact = max(impact, i)`, 매 프레임 `impact −= delta × 4.8` (0 아래로 안 감). 쉬는 구슬 (속력 변화 없음)은 0. 새로 만든 구슬·순간 이동한 구슬은 `v_prev = v_now`로 시작
4. **숨쉬기**: 판이 멈춘 동안만. 가중치 `w`가 `delta × 4`로 0 과 1 사이를 따라가 켜고 끌 때 튀지 않게. 모양에 `(1 + b·w, 1 − b·w)`, `b = sin(위상) × 0.018` (크기 전체가 아니라 가로·중력 쪽 반대로)
5. **얼굴 판**: 몸통과 같은 틀·같은 `deform` (가로 → 얼굴 가로, 중력 쪽 → 얼굴 세로). 합체 부풀기 (`visual_scale` 0.88 → 1)는 지금처럼 둘 다에
6. **흡수 결과 반지름**: 먹는 쪽 반지름 (물리·그림)을 **0.10초** 동안 이전 → 새 반지름으로 키운다 (`_advance_growth`). 같은 레벨 합체 결과 (새 구슬)는 지금 그대로
7. **그림 보간 (3D 모드 전체)**: 그림 위치 = 이전 물리 위치와 지금 물리 위치 사이를 `Engine.get_physics_interpolation_fraction()`으로 보간. 생성·입구 대기 들어감/풀림·합체 결과·물리 끄기 같은 순간 이동은 보간을 처음부터. 물리는 그대로 (렌더만) — 방식 (전역 `physics_interpolation` 또는 직접 보간)은 Codex
- 그대로: 규칙·점수·대폭발·FINAL MOVE, 젤리 셰이더·색·얼굴 그림, CLASSIC·BLITZ 그림 (보간 말고), SLIME 전부. SLIME의 굴림 (`roll`)·통통 튐 (`bob`)은 넣지 않는다

**검수**
- 측정 (고치기 전·후, 헤드리스 가능): 붐비는 판 (JELLY 40개, 턴 입력 대기 3초)에서 ① 찌그러짐 시작 횟수/초 ② 프레임 사이 메시 크기 변화 최대값 ③ 숨쉬기 켜고 끌 때 한 프레임 변화. 바라는 값: ① 0 ② 0.5% 이하 ③ 0.5% 이하
- 내려앉는 순간 (중력 네 방향): 중력 쪽 < 1·가로 > 1 (납작) 테스트, 몸통과 얼굴 축이 같은지 테스트, 한 프레임에 목표로 건너뛰지 않는 테스트
- 보간: 분수 0·0.5·1에서 그림 위치, 순간 이동 뒤 첫 프레임이 이전 위치에서 끌려오지 않는 테스트. 물리 120 / 화면 164를 흉내 낸 프레임 사이 이동량 고르기 (표준편차 ÷ 평균) 전·후
- 해시: CLASSIC·BLITZ·SLIME 그대로 (보간은 렌더만), JELLY는 6번 때문에 바뀜 → 새 값 보고. JELLY 그림 켠·끈 해시 같음
- JELLY 판 길이: 무작위 R × 시드 1~20 중앙값이 #98 J5 (223.5턴)의 ±10% 안
- 캡처 두 비율: `55_jelly_motion_land` (떨어져 내려앉는 0.25초를 10장 띠로 — 늘어남 → 납작 → 돌아옴이 이어지는지), `55_jelly_motion_rest` (붐비는 판 쉬는 순간), 중력 오른쪽 판 한 장
- 창 실행 확인 (사용자 화면과 같은 고주사율이 아니면 그 사실을 적는다)

**#101 1차 결과** ([PR #103](https://github.com/jeongmo-dot/gravity_orb/pull/103), 2026-10-25 Claude 검수 — 병합 보류): 고칠 것 1~7이 명세 식 그대로 들어왔다 (틀 `delta × 8`·`deform` `delta × 11`·낙하 `÷ 5800`·속력 감소 `÷ 1000`·숨쉬기 가중치·흡수 0.10초·렌더 보간, 접촉 찌그러짐 삭제). 래퍼 375/375, CLASSIC·BLITZ·SLIME 해시 그대로, JELLY R 중앙 230.5턴 (범위 안), 숨쉬기 켜짐/꺼짐 4.73% → 0.06% (Codex). Claude 검수 (`55_jelly_motion_*` 직접, 재실행 없음)에서 세 가지와 측정 한 가지가 남았다 → **추가 요구 1**
1. **납작해질 때 얼굴이 몸통에 가려진다** — `55_jelly_motion_land_06~10`에서 눈·입이 거의 사라지고 볼만 남는다. 몸통 메시 z 배율 = `deform.x` (찌그러짐 최대 1.18)이라 몸통 앞면 (`r × 1.18`)이 얼굴 판 (`r + 0.006`)보다 앞으로 나온다. 큰 젤리는 숨쉬기 +1.8%만으로도 가릴 수 있다 (L7 `1.40 m × 0.018 = 0.025 m` > 0.006 m). 고치기 전 찌그러짐 (y·z 1.18)도 같은 이유로 닿을 때마다 얼굴을 가렸을 것 — 지글거림을 키운 원인으로 본다
   - 고치기: 얼굴 판·문양의 z를 몸통 앞면 기준으로 (반지름 × 몸통 z 배율 × 부풀기 배율 + 여유), 또는 몸통 z 배율을 1 이하로. 방식은 Codex
   - 검수: `land_06~08`에서 눈·입이 다 보임, L7 숨쉬기 최고점 캡처, 테스트 (찌그러짐 최대·숨쉬기 최고점·부풀기에서 얼굴 판 z > 몸통 앞면)
2. **새 젤리가 돌면서 나타난다** — `setup`이 틀 회전을 0 (중력 아래 각)으로 두고 `set_gravity`는 목표만 바꿔, 중력이 위·옆이면 생성·합체 결과마다 90~180°를 돌며 나타난다 (매 턴 들어오는 젤리 포함, #96부터 — 그때는 2.4로 더 느리게)
   - 고치기: 새로 생긴 젤리 (생성·합체 결과)는 첫 중력 설정 때 틀 회전을 목표 각으로 바로 맞춘다. 그 뒤 중력이 바뀔 때만 `delta × 8`로 돈다
   - 검수: 테스트 (중력 위·왼쪽·오른쪽에서 생성 직후 틀 각 = 목표 각, 합체 결과도)
3. **레벨이 오르는 흡수는 아직 한 번에 커진다** — `set_jelly_mass`의 "이전 반지름"이 새로 만든 결과 구슬의 반지름 (`radius_for_level(결과 레벨)`)이다. 먹는 쪽이 질량 1.5배 (레벨 사이 크기)일 때 `L + (L−1)` → `L+1`이면 시작이 `R[L+1]`이라 자라지 않고 한 번에 10~12px 커진다 (테스트는 레벨이 그대로인 4 → 6만 확인)
   - 고치기: `CollisionResolver`가 먹는 쪽의 지금 반지름 (`source_radii`)을 시작 반지름으로 넘긴다
   - 검수: 테스트 (질량 6 (72.5) + 2 → 8 (L4 85)이 0.10초 동안 72.5 → 85, 0.05초에 중간)
4. **측정을 실제로 쌓인 판에서 다시** — 쉬는 판 측정·캡처 (`rest`)가 격자에 띄워 둔 배치라 젤리끼리 닿지 않는다 (변경 전에도 찌그러짐 시작 0회 — 접촉이 없어서). 중력으로 떨어뜨려 쌓여 서로 닿은 40개 (턴 3번 이상 뒤)에서 ① 찌그러짐 시작/초 ② 프레임 사이 크기 변화 최대, 그리고 **움직이는 동안** (중력 바꾼 뒤 1.5초) 프레임 사이 크기·틀 회전 변화 최대 — main (변경 전)·이 PR (변경 후). `rest` 캡처도 쌓인 판으로
- 그대로: 1차의 나머지 (식·수치·보간·해시 결과)

**#101 결과 — 병합** ([PR #103](https://github.com/jeongmo-dot/gravity_orb/pull/103) `f02e8ad`, 2026-10-25): 추가 요구 1 반영 — 얼굴 판·문양 z = 몸통 앞면 (`반지름 × 몸통 z 배율` + 여유, 찌그러짐·숨쉬기·부풀기 포함), 새 젤리 (생성·합체 결과)는 첫 중력 설정 때 틀 각을 바로 맞춤, 흡수 성장은 먹는 쪽 지금 반지름에서 (`CollisionResolver` → `set_jelly_mass(…, 시작 반지름)`, 질량 6 → 8이 72.5 → 85). 래퍼 377/377, CLASSIC·BLITZ·SLIME 해시 그대로, JELLY 그림 켠·끈 해시 같음, JELLY 시드 1 새 마지막 상태 `95ecb859…` (209턴), R 중앙 230.5턴 (Codex). 실제로 떨어뜨려 쌓은 40개 (접촉쌍 68~69, 중력 5번) 측정 (Codex 표, Claude 해석):

| 측정 | main (변경 전) | 변경 후 |
|---|---|---|
| 쉬는 판 찌그러짐 시작 | 0회/초 | 0회/초 |
| 쉬는 판 프레임 사이 크기 변화 최대 | 0.027% | 0.027% |
| **움직이는 동안 프레임 사이 크기 변화 최대** (중력 바꾼 뒤 1.5초) | **26.9%** | **2.56%** |
| **움직이는 동안 프레임 사이 틀 회전 최대** | **1.72 rad (약 99°)** | **0.105 rad (약 6°)** |
| 숨쉬기 켜짐/꺼짐 한 프레임 | 4.73% | 0.07% |

- 해석: 사용자가 느낀 "툭 툭 튀는" 것은 **움직이는 동안**이었다 — 한 프레임에 크기 27%·방향 99°가 바뀌었다 (속력 경계에서 늘어남이 켜졌다 꺼지고 메시가 0 ↔ 속도 방향으로 순간 회전). Claude가 주범으로 본 "쉬는 젤리끼리 닿을 때마다 찌그러짐"은 실제 쌓인 판에서도 0회 — **추정이 빗나갔다**. 지글거림은 움직임 튐, 숨쉬기 켜짐/꺼짐, 찌그러질 때 얼굴이 가려졌다 나타남, 164Hz 화면의 보간 없음이 겹친 것으로 본다
- Claude 검수 (`55_jelly_motion_land_06~08`·`breathe_max`·`rest`·`right` 직접, 재실행 없음): 납작할 때도 눈·입이 다 보임, L7 숨쉬기 최고점 얼굴 선명, 쉬는 판은 실제로 쌓인 더미, 오른쪽 중력에서 몸통·얼굴 함께 회전

#### 12-JE.8 대폭발 가능 표시 — 터질 듯한 얼굴 (#102)
사용자 (2026-10-25): 스크린샷의 L5 노랑 젤리 둘레 어두운 고리 (지금 대폭발 가능 표시) → "완전히 바꿔. 대폭발 가능 표시가 뭐 이래" → Claude 시안 A~D ([docs/mockups/jelly_blast_marks.png](mockups/jelly_blast_marks.png)) → 사용자 선택 **C. 터질 듯한 얼굴**

- 지금: `BlastOutline`에 링 셰이더 (`JellyOrbArt._get_outline_shader`, 반지름 0.78~1.0 고리)를 깜빡임 (`blast_blink_period` 0.8)으로 — 어두운 판 위에서 반투명 고리가 탁하게 보인다. JELLY에서는 **없앤다** (CLASSIC·BLITZ 대폭발 표시는 그대로)
- 대상: JELLY에서 대폭발 가능한 젤리 (`blast_enabled_for_level` — 지금 L5 이상). L5·L6은 얼굴이 바뀌고, L7은 **MAX 얼굴 (시안 C) 그대로** 빛만 더한다. `jelly_blast_min_level`이 0이면 아무것도 안 바뀐다
- **터질 듯한 얼굴** (L5·L6, 보통 눈 대신 — 깜빡이지 않음). 좌표는 몸통 반지름 `r` 기준 (위가 음수), 얼굴 판 배율은 MAX처럼 **1.0**

| 부분 | 값 |
|---|---|
| 눈 `>` (왼쪽) | 꺾인 선 `(−0.32, −0.16)` → `(−0.16, −0.04)` → `(−0.32, 0.08)` |
| 눈 `<` (오른쪽) | 좌우 대칭 `(0.32, −0.16)` → `(0.16, −0.04)` → `(0.32, 0.08)` |
| 눈 선 | 굵기 `0.064r`, 끝·꺾임 둥글게, 색 = MAX 얼굴색 `#1B1630` |
| 입 `o` | 중심 `(0, 0.22)`, 반지름 `0.064r × 0.076r`, 색 `#3A1530` |
| 볼 | 중심 `(±0.48, 0.18)`, 반지름 `0.16r × 0.10r`, 색 `#FF4F7F`, 알파 0.6 |

- **은은한 제 색 빛** (L5·L6·L7): 몸통 뒤 (몸통에 가려 가장자리 밖으로만 보이게), 제 색 (`color_for`)을 조금 밝게, 몸통 가장자리에서 바깥 `0.25r`까지 부드럽게 옅어짐. 알파 0.22 ↔ 0.40을 **1.6초 사인**으로 천천히 (한 프레임에 튀지 않게)
- 얼굴 판의 회전·말랑함은 보통 얼굴과 같다 (§12-JE.7 틀·`deform`, 중력 쪽으로 돈다)
- 바뀌는 순간: 흡수·합체로 L5가 되거나 L5로 들어올 때 얼굴이 바뀐다 (합체 부풀기와 같은 순간이라 그대로 바꾼다). L5 미만으로 내려가는 일은 없다
- 2D로 그리는 젤리 얼굴이 있으면 (미리보기·안내 등) 같은 정의를 쓴다 — 지금은 L5 이상이 2D로 그려지는 곳이 없으면 3D만
- 그대로: 규칙·물리·해시 (그림만), CLASSIC·BLITZ·SLIME 그림, 보통 얼굴·MAX 얼굴 그림
- 검수: 캡처 `56_jelly_blast_face` 두 비율 — ① 노랑 L5 + 보라 L5 나란히 (시안 C와 비교), L6, L7 (MAX 얼굴 + 빛) ② 붐비는 판에 대폭발 가능 젤리 여럿 ③ 중력 오른쪽 판. 테스트 — L4 보통 얼굴·L5/L6 터질 듯한 얼굴·L7 MAX + 빛, JELLY 링 셰이더 꺼짐, CLASSIC 대폭발 표시 그대로, 빛 알파가 한 프레임에 0.02 넘게 바뀌지 않음. 모든 모드 해시 그대로

**#102 1차 결과** ([PR #104](https://github.com/jeongmo-dot/gravity_orb/pull/104), 2026-10-25 Claude 검수 — 병합 보류): 링 셰이더 삭제, 터질 듯한 얼굴 (명세 좌표·굵기·색, 얼굴 판 1.0, 깜빡임 없음), 빛 알파 0.22 ↔ 0.40 · 1.6초, `jelly_blast_min_level = 0`이면 없음, 모든 해시 그대로, 래퍼 379/379 (Codex). Claude 검수 (`56_jelly_blast_face` 두 비율 직접·픽셀 값, 재실행 없음)에서 남은 것 → **추가 요구 1**
1. **뒤 빛이 보이지 않는다** — 몸통 가장자리 바로 밖이 배경색 그대로다 (노랑 L5 왼쪽 밖 `(1,4,14)`~`(5,10,22)`). 빛 판을 `−(몸통 앞면 + 0.004)`에 두어, 반지름 1.0 m 이상인 L5~L7은 빛 판이 보드 배경판 (`Board3D` backing z −0.34 m, 격자 −0.31 m)보다 뒤로 가 가려진다
   - 고치기: 빛 판을 배경판·격자보다 앞, 몸통 앞면보다 뒤에 둔다 (예: z −0.30 m 근처 — 몸통 안쪽은 몸통이 가리고 밖으로만 보인다). 방식은 Codex
   - 검수: 몸통 가장자리 밖 `0.1r` 지점 밝기가 배경보다 밝음 (픽셀 값 보고, 알파 최저·최고 두 순간), 확대 캡처
2. **볼이 탁하다** — 초록 L5 볼이 `(147,133,137)` 회갈색 (시안: `#FF4F7F` 60% → 약 `(193,138,161)` 분홍). 얼굴 셰이더가 볼 색을 얼굴 어두운 색 (`max_face_color`)과 `blush × 알파`로 섞은 뒤 알파를 다시 곱해서다. MAX 얼굴 볼 (0.45)도 같은 식
   - 고치기: 눈·입과 겹치지 않는 볼 픽셀은 색 = 볼 색 그대로, 진하기는 알파로만. 터질 듯한 얼굴·MAX 얼굴 둘 다
   - 검수: 노랑·초록·파랑 L5 볼 중심 픽셀 값 보고 (볼 색 × 알파 + 몸통 색 × (1 − 알파)와 ±12 안)
3. **얼굴을 늘 똑바로** — 사용자 (2026-10-25, 중력 오른쪽 캡처 확대를 보고): 얼굴이 중력 쪽으로 90° 돌아 `><`가 `v ^`처럼 읽힌다 → **"똑바로 고정"**. §12-JE.2·§12-JE.7의 "얼굴이 중력 쪽으로 돈다 (지금처럼 돌기)"를 바꾼다
   - 모든 JELLY 얼굴 (보통·터질 듯한·MAX)과 문양은 회전 0 (화면 위가 위)
   - 말랑함은 그대로 중력 기준: 몸통 메시는 지금처럼 틀 회전 + `deform` (구라 회전은 보이지 않음). 얼굴 판은 회전 없이 몸통과 같은 화면 방향으로 늘어나고 납작해진다 — 얼굴 판 변환 = `R(θ) · S(deform) · R(−θ) · 얼굴 크기` (θ = 틀 회전). 중력 오른쪽이면 얼굴은 똑바른 채 가로로 늘어나고 세로로 납작해진다
   - 빛 판은 몸통과 같게 (틀 회전 + `deform`)
   - 검수: 테스트 (중력 네 방향에서 얼굴 판 회전 0, 중력 오른쪽 늘어남에서 얼굴 판 화면 가로 배율 = `deform` 중력 쪽 값), 캡처
4. **캡처 다시** — 지금 `56_jelly_blast_face`는 중력 오른쪽 한 장뿐이라 시안 C와 나란히 비교할 수 없다. 두 비율로 ① 중력 아래: 노랑 L5 + 보라 L5 나란히·L6·L7 (시안 C와 같은 방향) ② 중력 오른쪽 붐비는 판 ③ 1번 빛 확대 (알파 최저·최고)
- 그대로: 1차의 나머지 (얼굴 좌표·빛 알파·주기·해시)

**#102 결과 — 병합** ([PR #104](https://github.com/jeongmo-dot/gravity_orb/pull/104) `d06d898`, 2026-10-25): 추가 요구 1 반영 — 빛 판 z −0.30 m (격자 −0.31 m 앞, 몸통 안쪽은 몸통이 가림, 0..1 UV 판 + 인스턴스 `glow_alpha`), 볼은 볼 색 그대로·알파로만 (눈·입과 겹치는 곳 제외, MAX 얼굴 포함), 모든 JELLY 얼굴·문양 회전 0 + 얼굴 판 `R(θ)·S(deform)·R(−θ)`. 래퍼 380/380, 모든 모드 해시 그대로 (Codex). 픽셀 (Codex 측정): 볼 노랑 `(247,133,126)`·초록 `(192,131,142)`·파랑 `(200,112,170)` (예상과 ±1), 빛 1.1r 휘도 최저 0.173·최고 0.252 (배경 0.078). Claude 검수 (`56_jelly_blast_face_down`·`_right`·`_glow_max` 직접, 재실행 없음): 중력 아래 판이 시안 C와 같음, 중력 오른쪽에서도 얼굴 똑바로, 빛이 가장자리 밖으로 은은하게, L7 MAX 볼도 분홍

#### 12-JE.9 크기는 레벨에 고정 · 배 속에 먹은 젤리 · 뒤 빛 삭제 · 어두운 띠 (#104)
사용자 (2026-10-25, 0.15.1 플레이): "지금 젤리 모드 두 단계 이상 차이나도 합쳐지는 것 같은데", "2레벨 차이도 합쳐지는 것 같고, 3레벨 차이부터 안합쳐지는 거 같아", "합쳐지지 않은 상태에서 변화가 발생하는데 이유가 뭐지", "레벨 말고 크기가 달라질 이유가 있나"

**진단 (Claude, 코드 읽기 — 실행 없음)**: 규칙은 명세대로다 (`ReactionRules._classify_jelly`: 같은 색·레벨 차 1 이하, 레벨 = `⌊log₂ m⌋ + 1` — 2의 거듭제곱에서 반올림 오차 없음). 문제는 **크기가 질량으로 레벨 사이를 보간**한다는 것 (§12-JE.1 "크기"). 한 단계 작은 것을 먹은 젤리는 레벨은 그대로인데 크기는 다음 레벨 쪽으로 커진다.

| 실제 | 반지름 | 눈에는 |
|---|---|---|
| L3 (질량 4) | 60 | L3 |
| L3 + L2 (질량 2 → 6) | 72.5 | L3과 L4 사이 |
| L3 + L2 (질량 3 → 7) | 78.75 | 거의 L4 (85) |
| L4 + L3 (질량 6 → 14) | 96.25 | 거의 L5 (100) |

- "거의 L4"인 L3이 L2 (40)를 먹으면 눈에는 **두 단계 차이 흡수** — 어긋남은 반 단계 남짓이라 세 단계 차이로 보이는 일은 없다 (사용자 관찰과 같다)
- 작은 L1을 먹은 L2는 40 → 47.5로 커지는데 먹힌 쪽이 작아 눈에 잘 안 띈다 → "합쳐지지 않았는데 커진다"
- 퍼즐로서 문제: 크기만 보고 합쳐질지 예측할 수 없다 → 사용자 선택 **"크기는 레벨에 고정"** + 한 번 먹은 표시 시안 ([docs/mockups/jelly_full_marks.png](mockups/jelly_full_marks.png)) **C. 배 속에 먹은 젤리**

**바꿀 것** (규칙·점수·질량 계산은 그대로)
1. **크기 = 레벨 반지름** (`level_radii`) — 물리·그림 모두. 질량 (`jelly_mass`)은 규칙에만 쓴다. `jelly_radius_for_mass(m)` = `radius_for_level(jelly_level_for_mass(m))`. 흡수 성장 0.10초 (#101)는 **레벨이 오를 때만** (이전 레벨 반지름 → 새 레벨 반지름). 레벨이 그대로인 흡수는 크기가 변하지 않는다 (합체 부풀기 `visual_scale` 0.88 → 1은 그대로 — "냠"). §12-JE.1 "크기" 줄을 이것으로 바꾼다
2. **배 속에 먹은 젤리** (시안 C) — 채움 `f = (m − 2^(L−1)) ÷ 2^(L−1)` (0 이상 1 미만). `f > 0`이면 몸통 안 중력 쪽에 같은 색의 작은 젤리가 비친다
   - 위치 (젤리 틀 기준, `r` = 몸통 반지름): 중력 쪽 `0.44r`, 가로 `+0.12r`. 반지름 `0.54r × √f` (f 0.5 → 0.38r, 0.75 → 0.47r). 몸통 윤곽 밖으로는 잘라 낸다
   - 생김새: 몸통 색을 `0.35` 밝게, 알파 0.85, 위·왼쪽 작은 반사점 (흰색 알파 0.7). 얼굴 없음. 몸통 앞·얼굴 뒤 (얼굴을 가리지 않는다)
   - 말랑함은 몸통과 같이 (틀 회전 + `deform`). 얼굴처럼 똑바로 세우지 않는다 — 배 속 젤리는 늘 중력 쪽 (아래)에 있다
   - 바뀔 때: `f`가 바뀌면 (흡수) 0.15초에 걸쳐 커진다. 레벨이 오르면 새 `f`로 (0이면 0.15초에 걸쳐 사라짐). 한 프레임에 튀지 않는다
   - 모든 JELLY 레벨 (L7은 질량 상한 64라 늘 `f = 0`), 터질 듯한 얼굴 (L5·L6)에도
3. **대폭발 가능 뒤 빛 삭제** (사용자 "없애기") — JELLY에서 `BlastOutline`을 쓰지 않는다 (늘 숨김). 대폭발 가능은 터질 듯한 얼굴 `><`만으로 알린다. §12-JE.8 "은은한 제 색 빛"·#102 빛 판은 폐기. CLASSIC·BLITZ 대폭발 표시는 그대로
4. **어두운 띠 원인 찾기** — 사용자 스크린샷 (0.15.1 — 실행 중 프로세스 `build\windows\GravityOrb_v0.15.1.exe` 확인): **보통 얼굴** (대폭발 가능 아님) 젤리 둘레에 제 색을 어둡게 한 띠 (노랑은 올리브, 파랑은 남색)가 몸통 바깥 약 `1.25r`까지. "2,3번 움직이는 동안 계속 있다가 어느 순간 사라졌어", "다른 색깔들도 나와". 띠 크기·색은 #102 빛 판 (`1.25r`, 제 색 × 알파 0.22~0.40)과 같은데, 코드상 빛 판은 `_blast_armed`일 때만 보인다 — 원인 미확정
   - 재현: JELLY 시드 여럿 × 턴 여럿 (R 전략), 프레임마다 모든 젤리에 대해 보이는 자식 메시·알파 (특히 `_blast_armed`가 아닌데 `BlastOutline` 보임), 젤리 중심에서 `1.4r` 안에 0.5초 넘게 보이는 `FeedbackDirector` 연출 노드를 기록 → 원인 보고
   - 3번을 한 뒤에도 띠가 나오면 그 원인도 고친다. 검수: 같은 재현에서 띠 0회
- 그대로: 규칙 (같은 색·레벨 차 1 이하, 질량 합, L7 두 경우, 점수), 대폭발 L5부터, FINAL MOVE, 터질 듯한 얼굴, 얼굴 늘 똑바로, 말랑함 (#101)

**측정** (크기가 바뀌어 물리가 달라진다): R·G·L-합체 × 시드 1~20 × 600턴 — 판 길이 중앙·실력 비 (길이·점수)·초반 합체율, #98 J5 (실력 비 1.47, R 223.5턴 — #101 뒤 230.5)와 나란히. 실력 비가 1.3 아래로 떨어지면 그 사실과 원인 후보를 보고

**#104 결과 — 병합** ([PR #106](https://github.com/jeongmo-dot/gravity_orb/pull/106) `b314221`, 2026-10-25): `jelly_radius_for_mass(m)` = `radius_for_level(jelly_level_for_mass(m))` (물리·그림), 레벨이 그대로인 흡수는 크기 불변·레벨이 오를 때만 0.10초 성장 (L3 60 → 60 → L4 85), 배 속 젤리 (`Belly` 판 — 몸통 앞·얼굴 뒤, 채움 `f`·0.15초 전환·틀 회전 + `deform`), JELLY `BlastOutline` 늘 숨김 (CLASSIC·BLITZ 그대로). 래퍼 381/381, CLASSIC·BLITZ·SLIME 해시 그대로 (Codex). 측정 (Codex 표, Claude 해석):

| JELLY | R 턴 | L 턴 | 실력 비 길이 / 점수 | 같은 시드 (길이) | R 초반 합체/턴 |
|---|---|---|---|---|---|
| #98 J5 (크기 보간) | 223.5 | 328 | 1.47 / 4.15 | — | 0.725 |
| **#104 (크기 레벨 고정)** | **256.5** | **371** | **1.45 / 2.80** | 95% | **0.738** |

- 해석: 판이 조금 길어졌고 (R +15%), 실력 비 (길이)는 그대로 1.45 — CLASSIC C2 (1.48)와 같은 자리. 점수 비가 4.15 → 2.80으로 준 것은 잘 두는 봇의 점수 우위가 줄었다는 뜻 (크기가 레벨에 맞아 큰 젤리끼리의 공간 싸움이 덜하다). 초반 합체 0.738 (CLASSIC 0.595보다 24% 잦음). 바라는 자리 세 항목 (판 150~300·실력 비 1.3 이상·초반 CLASSIC보다 잦음) 모두 안
- **어두운 띠**: 재현하지 못했다 — 크기·색이 맞는 후보는 #102 빛 판 (`1.25r`)뿐인데 코드상 대폭발 가능일 때만 보이고, 계측에서 보통 얼굴에 켜지는 경로를 찾지 못했다. 빛 판을 JELLY에서 늘 숨긴 뒤 R·G·L 60판 계측 (빛 판 보임 0)·흡수 캡처 (0.5초 넘게 남는 연출 0)에서 0회. 다만 60판 측정은 그림 `_process`를 끈 채라 연출 노드는 캡처 장면에서만 확인했다 — **0.15.2에서 사용자 플레이로 다시 본다**
- Claude 검수 (`57_jelly_full_down`·`_right`·`_eat_00~02` 직접, 재실행 없음): `f` 0·0.5·0.75 순서로 배 속 젤리가 커짐, 흡수 60 → 60 (배 속 생김) → 85 (배 속 비움), 중력 오른쪽에서 배 속 젤리가 오른쪽, `><` 얼굴이 배 속 젤리 앞. 배 속 젤리가 시안보다 옅다 (몸통과 같은 계열 색) — 플레이에서 안 보이면 밝기를 올린다

#### 12-JE.10 젤리 둘레 반투명 고리 — 다시 (#109)
사용자 (2026-10-25, Godot 편집기에서 main 실행 — JELLY 단일 앱): "합쳐진 이후로 이 다음 커질 상태가 미리 나오는 것 같은데" + 스크린샷 (중력 아래, 바닥의 젤리 4개)

- **Claude 픽셀 분석**: 초록 젤리 둘레 `(21~24, 46~54, 39~45)`, 파랑 젤리 둘레 `(30, 41, 61~63)` — 각자 **제 색 × 약 0.22**, 몸통 가장자리부터 **약 1.2r**까지, 바깥은 배경 `(1, 1, 9)`. 고리는 초록·큰 파랑 (둘 다 배 속 젤리가 있음 — 방금 흡수)과 맨 왼쪽 작은 파랑 L1 (배 속 없음)에 있고, 노랑에는 없다. 앞선 보고: "2,3번 움직이는 동안 계속 있다가 어느 순간 사라졌어", "다른 색깔들도 나와"
- **원인이 아닌 것**: #102 빛 판 (`BlastOutline`) — #104부터 JELLY에서 늘 숨김·투명도 1인데 그 뒤에도 나온다. 다음 크기를 미리 보여 주는 기능은 명세에 없다. 환경 빛번짐 (bloom)은 꺼져 있다 (`Main3D.tscn` Environment에 glow 없음)
- **#104 재현이 실패한 이유**: 60판 측정은 그림 `_process`를 끈 채였고, 연출 노드 검사는 캡처 장면에서만 했다
- **찾는 법**: 그림을 켠 실제 창 (편집기 또는 Debug 빌드, 기본 창 크기)에서 실제 턴 진행 (봇 입력 가능), 흡수·합체 뒤 3턴을 프레임마다 본다. 고리 영역 (젤리 중심에서 `1.0r~1.3r`) 픽셀이 배경보다 제 색 쪽으로 밝으면 고리. 고리가 보이는 프레임에서 후보를 하나씩 숨겨 사라지는 것을 찾는다 — Orb3D 자식 메시 각각 (Mesh·Adornment·BlastOutline·Belly·Face·Symbol), `FeedbackDirector` 연출 노드 종류별 (glow·ring·particles·flash·light·arc), `ColorEffectVisual`, 스와이프 자국, `Board3D` 장식. 그 노드가 왜 그 크기·투명도로 몇 턴 남는지 보고
- **고치기**: 원인을 없앤다 (명세에 없는 반투명 원판이면 지운다). 고친 뒤 같은 재현에서 고리 0회 (흡수·합체 뒤 3턴 × 20번 이상, 픽셀 검사)

**#109 결과 — 병합** ([PR #109](https://github.com/jeongmo-dot/gravity_orb/pull/109) `f440d10`, 2026-10-25): 원인은 **색 효과 고리 `ColorEffectVisual/ModeRing`** — 합체·흡수마다 결과 젤리 색으로, 결과 반지름에서 색 효과 반지름까지 0.3~0.4초 동안 커지며 (PULL은 줄며) 알파 `1 − 진행`으로 옅어진다. 반응 직후 `1.0r~1.3r`에 걸려 "다음 크기 예고"처럼 보였다. 노랑 (LIFT)은 원래 고리를 숨기는 분기라 노랑에만 없던 것과 맞다. 연출 수명은 정상 (끝나면 반납) — "2~3턴 남았다"는 연쇄 흡수·합체마다 새 고리가 생긴 것으로 본다. 실제 창 (그림 켬)에서 80ms 시점 후보 숨김: 흡수 잔상만 숨기면 남고 `ModeRing`을 숨기면 사라짐. 고침: JELLY에서 `ModeRing`만 끈다 (색 효과 별가루·보드 흔들림·당김 펀치·물리 효과는 그대로, 다른 모드 경로는 그대로). 합체·흡수 20번 + 뒤 실제 턴 60번에서 고리 영역 픽셀 차이 수정 전 8,120 (540×960)·7,975 (540×1170) → 수정 후 0. 래퍼 283/283, JELLY 해시 그대로 (Codex). Claude 검수 (`jelly_halo_post/540x960/case_01_before`·`_after` 직접, 재실행 없음): 고치기 전 분홍 젤리 둘레 고리, 고친 뒤 별가루만
- 반성 (Claude): #102·#104에서 크기·색이 맞는 빛 판을 원인으로 짚었으나 틀렸다. 그림을 끈 측정으로는 화면에만 있는 고리를 잡을 수 없었다 — 화면 문제는 그림을 켠 실제 창에서 후보를 하나씩 숨겨 찾는다

### 12-JE.4 측정 (#95)
- 도구: #89~#91 그대로 — 전략 R·G (고친 것)·L-합체 (미리보기 — 평가에 FINAL MOVE 대기 `−500,000`, 게임오버 `−1,000,000`), 시드 1~20, 600턴 상한
- 비교: CLASSIC (C2, #91)·SLIME (S2, #91) 결과와 나란히
- 보고: 턴·점수 중앙값, 실력 비 (L/R 길이·점수), 같은 시드 승률, 초반 합체율 (1~30턴), FINAL MOVE 발생·성공률, 흡수 (한 단계 차이) 비율, L7 도달·잭팟, 치명 회피 턴
- **바라는 자리**: 초반 합체율 CLASSIC보다 높게, 실력 비 (길이) SLIME (1.15)보다 높게 (1.3 이상이면 좋다), 무작위 판 길이 150~300턴. 벗어나면 단계별 난도 값 (`spawn_count_ramp_turns`, 해금 턴)을 이 모드만 따로 조정하는 후보를 같이 보고

**#95 결과 — 병합** ([PR #97](https://github.com/jeongmo-dot/gravity_orb/pull/97) `f981d5c`, 2026-10-21): `GameMode.JELLY`·`--mode=jelly`, 규칙 질량 `jelly_mass` (물리 질량과 분리), 흡수·L7 두 경우·점수 두 경우·대폭발 없음·FINAL MOVE (띠·안내). 다른 모드 해시 그대로, 래퍼 357/357 (Codex). 그림은 아직 CLASSIC 행성 (#96 전). Claude 해석 (Codex 표, 재실행 없음):

| 모드 (각 무작위 R → 미리보기 L-합체) | R 턴 | L 턴 | 실력 비 길이 / 점수 | 같은 시드 (길이) | R 초반 합체/턴 | R 점수 중앙 |
|---|---|---|---|---|---|---|
| CLASSIC C2 | 221 | 327 | **1.48** / 2.72 | 100% | 0.595 | 124,263 |
| **JELLY** | **154** | 158.5 | **1.03** / 1.17 | 90% | **0.725** | **9,074** |
| SLIME S2 | 52 | 60 | 1.15 / 1.46 | 57.5% | 2.97 | 103,232 |

- 맞은 것: **초반 합체가 CLASSIC보다 22% 잦다** (배우기 쉬움), 판 길이 154턴은 바라는 범위 안 (150~300)
- 빗나간 것: **실력 비 1.03 — 네 모드 중 가장 낮다** (SLIME 1.15보다도 낮음). FINAL MOVE는 거의 모든 판의 끝에 오지만 (R 21번) 살아나는 일이 드물다 (R 5%, L 13%). L7은 60판 모두 0번, 점수는 CLASSIC의 7% (대폭발·연쇄 배수가 없어서)
- **원인 (Claude)**: ① CLASSIC에서 실력이 드러나는 길은 **대폭발**이었다 — 미리보기 봇이 무작위를 이기는 차이 (점수 2.7배·길이 1.48배)는 대부분 대폭발로 판을 치우는 데서 왔다. JELLY는 대폭발을 빼서 판을 비우는 수단이 합체뿐이고, 끝은 생성 증가가 정한다 ② **규칙이 느슨할수록 무작위도 잘 합쳐진다** — 합체의 54%가 한 단계 차이 흡수다. 아무렇게나 밀어도 합쳐지니 잘 두는 것과 차이가 줄어든다 (SLIME이 낮은 것과 같은 이유)
- 다음 단계는 사용자 결정 — #96 (그림)·#97 (앱 연결)은 규칙이 정해질 때까지 **보류** → 2026-10-22 "대폭발 되살려 측정" → §12-JE.5 (#98)

### 12-JE.5 대폭발 되살리기 후보 측정 (#98)
사용자 (2026-10-22): #95 결과 설명 후 "대폭발 되살려 측정"

**후보** (다른 규칙은 #95 그대로 — 흡수·FINAL MOVE·L7)
| 후보 | 대폭발 |
|---|---|
| J0 지금 (#95 결과 재사용) | 없음 |
| J4 | **L4부터** — CLASSIC과 같음: 다른 색·같은 레벨 (표시 레벨) 둘 다 L4 이상이면 둘 다 사라지며 밀어내기. 범위 L4 0.3 · L5 0.55 · L6·L7 판 전체 (`blast_push_radius_by_level`), 점수 `(두 레벨 점수 합) × 5` |
| J5 | **L5부터** — 같은 식, L4끼리는 반응 없음 |

- 판정 순서: ① 같은 색·레벨 차 ≤ 1 → 흡수 (L7+L7 잭팟 포함) ② 다른 색·같은 레벨·둘 다 기준 이상 → 대폭발 ③ 그 외 반응 없음
- "같은 레벨"은 표시 레벨 (질량이 레벨 사이여도 레벨로 비교)
- 대폭발 가능 구슬의 깜빡임 표시는 CLASSIC 그대로 (기준 레벨부터)
- 새 필드: `jelly_blast_min_level` (기본 **0 = 대폭발 없음**, 지금 동작) — 측정에서만 4·5로. 고른 값은 Claude가 넣는다

**측정**: J4·J5 × 전략 R·G·L-합체 × 시드 1~20 × 600턴 (J0은 #95 재사용). 보고는 #95 표에 대폭발 수·L7 도달·점수 더해 CLASSIC C2·SLIME S2와 나란히

**고르는 기준 (Claude)**
1. 실력 비 (길이) **1.3 이상** — SLIME (1.15)보다 확실히 크게. CLASSIC (1.48)보다 조금 낮아도 된다 (중간 자리)
2. 초반 합체율 CLASSIC (0.595)보다 높게 유지
3. 무작위 판 길이 150~300턴
4. 둘 다 맞으면 대폭발이 덜 잦은 쪽 (J5) — 규칙이 더 단순하게 느껴지는 쪽

**#98 결과 — 병합** ([PR #98](https://github.com/jeongmo-dot/gravity_orb/pull/98) `07e973b`, 2026-10-22): `jelly_blast_min_level` (기본 0), JELLY 판정 순서 (흡수 → 대폭발 → 없음), 깜빡임은 기준 레벨부터·질량 흡수로 레벨이 닿으면 바로. 다른 모드 해시 그대로, 래퍼 358/358 (Codex). Claude 검수 (diff·`53_jelly_blast_j5`, 재실행 없음):

| JELLY 후보 | R 턴 | L 턴 | 실력 비 길이 / 점수 | 같은 시드 | R 초반 합체 | 대폭발 (R 20판) |
|---|---|---|---|---|---|---|
| J0 없음 | 154 | 158.5 | 1.03 / 1.17 | 90% | 0.725 | 0 |
| J4 L4부터 | 358 (범위 밖) | 579 | 1.62 / 3.96 | 95% | 0.732 | 1,320 |
| **J5 L5부터** | **223.5** | **328** | **1.47 / 4.15** | **95%** | **0.725** | **188** |
| (CLASSIC C2) | 221 | 327 | 1.48 / 2.72 | 100% | 0.595 | — |

- **결정 (Claude, 2026-10-22): J5** — 네 기준 모두 맞음 (실력 비 1.47 ≥ 1.3, 초반 합체 CLASSIC보다 22% 잦음, 판 길이 범위 안, J4보다 대폭발이 7분의 1). J4는 판이 너무 길고 점수가 폭주한다
- 자리: J5는 깊이·판 길이가 **CLASSIC과 거의 같고** (실력 비 1.47 vs 1.48), 초반이 쉽고 FINAL MOVE로 너그럽다 — "중간 깊이"라기보다 **"더 친절한 CLASSIC"**. SLIME (1.15)보다는 확실히 깊다
- 적용: `jelly_blast_min_level` 기본값 **5** — 테스트가 기본 0을 확인하므로 #96 첫 요구로 함께 바꾼다 (JELLY 새 기준 해시). #96·#97 보류 풀기

## 12-ONE. JELLY 단일 앱 — 다른 모드는 레거시 (기획서 0.16 — #105·#106)

사용자 (2026-10-25): "일단 이 버전을 킵 하고, 젤리 모드 외에는 모두 레거시로 보관해줘. 지금 이후 부터는 젤리 모드 하나만 잡고 개선하자" → 선택: **태그로 보관, main은 JELLY만** · 시작 화면은 **큰 시작 버튼 하나**

### 12-ONE.1 보관 (레거시)
- **네 모드 마지막 버전** = #105 빌드 0.15.2 (BLITZ·CLASSIC·JELLY·SLIME, JELLY는 #104까지). #105 병합 커밋 `4271f88`에 주석 태그 **`legacy-four-modes`** (2026-10-25, 원격에 푸시함). 실행 파일 `build/windows/GravityOrb_v0.15.2.exe`와 이전 버전 파일은 지우지 않는다
- 레거시 모드: **CLASSIC (턴제 행성)·BLITZ (시간 버티기)·SLIME (그래비티 슬라임)**. 이 문서의 해당 절 (§12-B BLITZ, §12-G SLIME, §12-V·§12-W 행성 그림, §12-M·§12-R의 CLASSIC·SLIME 부분, §10.5.1 0.15.2까지 기록)은 지우지 않고 **레거시 기록**으로 남긴다 — 다시 쓸 때는 태그에서 꺼낸다
- 사용자 저장 파일의 다른 모드 기록·키는 그대로 둔다 (앱이 읽지 않을 뿐)

### 12-ONE.2 main = JELLY만 (#106)
- **BLITZ·SLIME은 main에서 지운다**: 코드·씬·HUD·설정 필드·설정 파일 (`config/slime_config.tres`)·테스트·캡처 장면·측정 도구 (`tests/tools/run_slime_parity.ps1` 등)
- **CLASSIC은 고를 수 없게**: 시작 카드·랭킹 탭·실행 인자 없음. 다만 JELLY는 CLASSIC 턴제 위에 지은 모드라 CLASSIC 규칙·턴·물리·반응·생성 코드는 이번에 남긴다 (CLASSIC 전용 분기 — 행성 그림·행성 연출·CLASSIC 합체 규칙 — 정리는 다음 항목). 공통 경로를 지키는 CLASSIC 회귀 테스트도 그때까지 둔다
- `GameConfig.GameMode` 값은 그대로 (TURN 0·BLITZ 1·SLIME 2·**JELLY 3**) — 저장 파일 호환. 쓰지 않는 값은 레거시 주석
- 앱은 늘 JELLY로 시작한다. `--mode`는 없거나 `jelly`만
- **시작 화면**: 로고 (GRAVITY ORB·부제·행성 그림) 그대로 + **큰 JELLY 시작 버튼 하나** (너비 = 지금 위 두 카드 + 사이 간격, 높이 200, L3 분홍 젤리 얼굴 아이콘·"JELLY"·"작은 것도 먹고 자라요"·BEST, 강조색 `#FF7595`) + 아이콘 줄 (랭킹·소리·설정). 누르면 바로 JELLY. 모드 카드 4장은 없다
- **랭킹**: JELLY 하나 (탭 없음, 열은 지금 JELLY 탭 그대로)
- **결과 화면**: 버튼 "모드 선택" → **"처음 화면"** (시작 화면으로)
- 그대로: JELLY 규칙·물리·그림·수치 전부, 소리·설정·랭킹 저장 방식
- 버전: 기획서 0.16 → 이 뒤 빌드는 **0.16.0**부터

**#106 결과 — 병합** ([PR #108](https://github.com/jeongmo-dot/gravity_orb/pull/108) `9157b6c`, 2026-10-25): BLITZ·SLIME 런타임·씬·HUD·설정 필드 (`blitz_*`·`SlimeConfig`)·전용 테스트·측정 도구 76개 파일 삭제 (−20,055줄), `GameMode` 값 그대로·레거시 주석, 앱은 늘 JELLY (`--mode`는 없거나 `jelly`), 시작 화면 큰 JELLY 버튼 하나 (UI 기준 936×200)·아이콘 줄, 랭킹 JELLY 하나, 결과 "처음 화면", 다른 모드 저장 키 보존, `docs/.gdignore`, 프로젝트 버전 **0.16.0**. 래퍼 282/282 (일반 273·장기 5·성능 4), JELLY 그림 켠·끈 해시 `5c96a80c…` 그대로, 내보낸 묶음에 BLITZ·SLIME 문자열 0, 사용자 저장 파일 불변 (Codex). Claude 검수 (`01_jelly_start` 두 비율·`02_jelly_ranking`·`03_jelly_result` 직접, 재실행 없음): 레거시 카드·탭 없음, 잘림 없음. 런타임 삭제 함수는 BLITZ·SLIME 전용 (피버·타이머·시간 보너스·슬라임 소리·BLITZ 생성)이고 새 젤리 안내 연결은 남아 있음
- 남은 것 → #108: **JELLY를 지키던 테스트·캡처까지 함께 지워졌다** — `tests/test_callouts.gd`를 통째로 지워 BLITZ가 아닌 테스트 (`test_jelly_preview_and_unlock_use_jelly_art_and_names`, 턴제 호령 한 연쇄에 한 번, 효과음 음소거·호령 음높이, 호령 끄기 + 해시 보존, 호령 프레임 비용 — 성능 5 → 4)도 사라졌고, 캡처가 105장 → 12장으로 줄며 JELLY 장면 (설정, 기록 없는 시작 화면, 중력 전환·위험·막힘, 입력 표시 준비·계산·거절, 호령·점수 팝업, `53_jelly_look_*`, `55_jelly_motion_*`)도 빠졌다

### 12-ONE.4 쓰지 않는 것 (사용자 결정 — 다시 만들지 않는다)
- **고리 모양 연출·그림 전부** — 사용자 (2026-10-25): `ModeRing` 설명을 듣고 "완전히 삭제하고 다시 사용하지 마", "그 합체가 그만큼 밀어낸다는 것도 말이 안되는 변명이야", "다 지워", "고리를 그리는 거 다 지워". 도넛 (torus)·원 테두리·타원 선 모양으로 그리는 것은 합체·흡수·대폭발·잭팟·MAX·시작 화면 어디에도 두지 않는다 (#110에서 코드째 삭제). 명세에 없는 연출은 넣지 않는다
- **그림자** — 사용자 (2026-10-26): "그런데 나는 그런 그림자를 그리라고 한 적이 없어". 그림자는 2026-10-03 #20 (Jolt 3D 정식 통합)에서 `Main3D.tscn` `KeyLight` `shadow_enabled = true`·`Orb3D.tscn` `Mesh` `cast_shadow = 1`로 들어왔다 (사용자 요청 아님). 빛의 그림자는 쓰지 않는다 (#111에서 끈다)
- **공 바깥의 그림자·외곽선·띠** — 사용자 (2026-10-26): "늘어나더라도 공이 늘어나야지. 저렇게 그림자가 생기거나 다른 외곽선이 생기는 것은 전혀 예뻐보이지 않아". 늘어나고 찌그러지는 것은 **공 자체** (몸통·얼굴·배 속 젤리가 함께)만 — 공을 따라 생기는 어두운 띠·그림자·외곽선은 어떤 이유로도 두지 않는다
- **배경 유성** — 사용자 (2026-10-26) "없애기" (#112)
- 남기는 것 (고리가 아님): 젤리 몸통 셰이더의 가장자리 광택, 별가루·섬광·흔들림·멈칫, 보드 테두리를 도는 입력 표시 빛, 보드 격자. **별가루는 같은 간격 원으로 퍼지지 않게 무작위로** (사용자 2026-10-25 "무작위로 흩어지게")
- **#109 설명이 맞지 않는 점** (사용자 2026-10-25: "그 변명이 말이 돼? 이미 그 만큼 다 공간을 잡아먹고 있고 몇턴씩 남아있는데?"): `ModeRing`은 0.3~0.4초짜리라 "몇 턴씩 남는" 고리와 "그만큼 공간을 차지하는" 고리를 설명하지 못한다. Claude 픽셀 확인 (사용자 스크린샷): 맨 왼쪽 작은 파랑과 초록이 몸통이 아니라 **고리끼리 맞닿아** 몸통 사이에 고리 두께만큼 (약 9px) 빈틈 — 고리가 실제 물리 크기를 드러낸 것일 수 있다. 고리 그림만 지우면 보이지 않는 빈틈이 남는다 → #110에서 **물리 반지름과 그린 반지름**을 프레임마다 재고, 고리가 몇 턴 남았던 이유를 레거시 main으로 재현해 밝힌다

**#110 1차 결과** ([PR #110](https://github.com/jeongmo-dot/gravity_orb/pull/110), 2026-10-25 Claude 검수 — 병합 보류): 고리 삭제는 명세대로 — `TorusMesh`·`_create_ring`·`ModeRing`·`Adornment`·`BlastOutline` 0건, 빛 셰이더 `shell`·`rim`·행성 고리·2D 대폭발 원·`CosmicRing2D`·시작 화면 궤도 선 삭제, 남은 `draw_arc` 10건은 MAX 입·행성 표면 선 (닫힌 원 아님). 래퍼 282/282, 해시 그대로 (Codex). Claude 캡처 검수 (`01_jelly_start`·`13~17_jelly_*_effect`, 재실행 없음): 시작 화면 궤도 선 없음, 합체·대폭발·잭팟·MAX 순간 고리 없음.
- **삭제 전 측정 (9번, `9157b6c`) — 사용자 관찰과 맞는다**:
  - "몇 턴씩 남아": 고리 한 개의 수명은 합체 약 294ms (46프레임)·흡수 약 240ms (35프레임)이지만, 매 턴 새 반응이 고리를 다시 만들어 5턴 각각 12·121·93·36·75프레임 보였고, 턴이 끝나 입력을 기다리는 순간에도 5턴 중 3턴 보였다. 5턴 뒤 씬 트리에 고리 노드 5·Torus 메시 21 (풀 포함)
  - "공간을 잡아먹고": **실제였다** — `Orb3D._mesh.scale`에 JELLY `deform`·합체 부풀기 (0.88 → 1)를 곱하는데 충돌 반지름 (`SphereShape3D.radius`)은 그대로라, 1,007프레임 중 899프레임에서 그린 반지름 ≠ 물리 반지름 (최대 14.1px), 맞닿은 7,127표본 중 209프레임 빈틈 (최대 7.8px). 몸통이 물리보다 작게 그려진 만큼 빈 공간
- **Codex가 고친 방식이 문제**: JELLY 몸통 메시 배율을 늘 1로 두어 (`_mesh.scale = Vector3.ONE`) 몸통의 늘어남·찌그러짐·숨쉬기·합체 부풀기를 모두 없앴다 (얼굴·배 속 젤리만 변형 — 동그란 몸통 안에서 얼굴만 늘어난다). 명세에 없는 디자인 변경이다 → 사용자 선택 (2026-10-25): **"말랑함 유지, 작아지지만 않게"**
- **흡수 장면 `14_jelly_absorption_effect`에 점 12개가 같은 간격 원으로 퍼지는 "점선 고리"** (색 효과 별가루 `ModeStardust`) → 사용자 선택: **"무작위로 흩어지게"**
- **추가 요구 1**:
  1. **몸통은 물리 크기보다 작아지지 않는다** — 몸통 그림 배율을 축마다 `max(1, 변형값)`으로: 떨어질 때 중력 쪽 늘어남 (`1 + s`)은 그대로, 가로 줄어듦 (`1 − 0.55s`)은 1로; 찌그러짐의 가로 넓어짐 (`1 + 0.18i`)은 그대로, 중력 쪽 줄어듦 (`1 − 0.20i`)은 1로; 숨쉬기도 `max(1, 1 ± b)`. 몸통 앞뒤 (z) 배율도 1 아래로 가지 않는다
  2. **합체 부풀기는 커지는 쪽으로만** — 지금 0.88 → 1 (작아졌다 돌아옴) 대신 **1.0 → 1.06 (0.08초, 바깥으로 부드럽게) → 1.0 (0.10초)**
  3. 얼굴·배 속 젤리는 몸통과 같은 (위 1·2번을 적용한) 배율을 쓴다 — 얼굴은 똑바로 선 채 (§12-JE.8 추가 요구 1의 `R·S·R⁻¹` 그대로), 얼굴 판 z는 몸통 앞면 기준
  4. 9번 측정을 다시 — 빈틈 프레임 0·최대 0px (그린 반지름 ≥ 물리 반지름이 모든 축에서), 대신 **겹침** (맞닿은 두 젤리의 그린 반지름 합 − 중심 거리)의 최대·지속 시간을 보고 (부딪히는 순간 잠깐 서로 눌려 겹치는 것은 의도)
  5. **색 효과 별가루를 무작위로** — 점마다 방향은 0~360° 무작위, 거리 배율 0.6~1.0·속도 배율 0.7~1.0 무작위로 해서 어느 프레임에도 같은 간격 원으로 보이지 않게. 난수는 효과마다 따로 씨앗을 둔 지역 난수 (전역 난수 금지·물리 해시 그대로·캡처가 매번 같게)
  6. 캡처 다시: 착지 띠 (`land`) — 늘어남·찌그러짐이 다시 보이는지, 흡수·합체 순간 (점선 원 없음·부풀기), 붐비는 쉬는 판 (빈틈 없음), 두 비율
- 그대로: 1차의 고리 삭제 전부

**#110 결과 — 병합** ([PR #110](https://github.com/jeongmo-dot/gravity_orb/pull/110) `3e80e1d`, 2026-10-26): 추가 요구 1 반영 — JELLY 몸통 배율 `max(1, 변형)` (축마다·숨쉬기·z 포함), 합체 부풀기 1.0 → 1.06 (0.08초) → 1.0 (0.10초), 얼굴·배 속 젤리가 몸통과 같은 배율 (얼굴은 똑바로), 색 효과 별가루는 효과마다 씨앗을 둔 지역 난수로 방향 0~360°·거리 0.6~1.0·속도 0.7~1.0. main에서 `TorusMesh`·`_create_ring`·`ModeRing`·`BlastOutline`·`Adornment` 0건. 래퍼 284/284, 해시 그대로 (Codex). 실제 창 재측정 (두 비율): 물리보다 작게 그린 프레임 0·빈틈 0, 고리 0. **겹침 최대 40.8px·한 쌍 최장 약 1.27초** — Claude 계산: 떨어질 때 중력 쪽 늘어남 (최대 19%, `JELLY_STRETCH_MAX`)으로 같은 줄에서 함께 떨어지는 두 젤리가 겹친다 (L5 둘 × 19% ≈ 38px + 부풀기 6%). 이 늘어남은 #101부터 있던 것 (이번에 생긴 것은 충돌 순간 가로 넓어짐 쪽 겹침뿐). Claude가 사용자에게 말한 "0.2초 살짝"은 틀렸다 — 떨어지는 동안 보인다. Claude 검수 (`18_jelly_landing_strip`·`19_jelly_crowded_rest`·`14_jelly_absorption_effect` 직접, 재실행 없음): 세로 늘어남·가로 넓어짐 돌아옴, 쉬는 판 빈틈 없음, 별가루 원 모양 아님. 겹침이 거슬리면 `JELLY_STRETCH_MAX`를 줄이는 것이 다음 후보 (사용자 플레이 뒤)

### 12-ONE.5 인박스 전체 점검 (2026-10-25)
사용자: "제대로 확인해.. 지금 많이 문제가 쌓여있어", "기존 인박스 코덱스와 클로드 주고 받은 내용들 전체적으로 확인하고 미확인 미검수, 폐기할 내용 정리해" → "둘 다 진행해". 두 인박스 (지시 110건·회신 130건)를 번호로 맞추고 회신의 "남은 것"·지시의 보류 표시를 모두 훑었다.

- **미확인** (결과·결정 대기): 인박스 #110 (먼저)·#107·#108, 사용자 결정 (효과음·시작 화면 그림·CLASSIC에서 따라온 연출), 사용자 체감 체크리스트
- **미검수** (닫았지만 근거가 모자랐던 것):
  - #109 원인 설명 (0.3~0.4초 고리)이 "몇 턴 남음·공간 차지"와 맞지 않는다 → #110 9번
  - #104 어두운 띠를 그림을 끈 측정으로 "재현 0"이라 닫았다, #102 빛 판 검수도 같은 관찰을 넘겼다 → #109·#110
  - JELLY 해시 `5c96a80c…`가 #101~#109 내내 같다 (#104 크기 변경에도) — 흡수·대폭발·FINAL MOVE를 지나지 않는 장면 → #108 4번
  - #106에서 테스트 381 → 282·캡처 105 → 12 (JELLY 것까지) — #109는 줄어든 테스트로 검증됨 → #108 1·2번
  - #101 164Hz 보간은 실제 주사율로 잰 적 없음 → 사용자 체감
  - 빌드 #88·#94·#100·#103·#105 시작 화면 카드 실제 클릭 자동화 실패 (0.15.1만 사용자 플레이로 확인)
  - #104 배 속 젤리가 시안보다 옅음 → 사용자 체감
  - #95·#98 캡처 끝 `ObjectDB instances leaked` 경고 4건, 처리 안 됨 → #108 5번
  - Claude가 캡처에서 보고도 짚지 않은 것: `57_jelly_full_eat_02` "NICE!"가 젤리 얼굴을 덮음, `57_jelly_full_right` 보드 왼쪽 흰 줄 → #108 6·7번
  - 실기기 (폰) 성능·터치 검수는 한 번도 없음 → 수동 확인 목록
  - 인박스 "완료 30건 넘으면 보관" 규칙을 지키지 않음 (110건) → 보관함
- **폐기**: CLASSIC·BLITZ·SLIME의 미결 질문·측정·수동 확인 (#29~#32, #54~#62, #79~#91 등, 체크리스트 약 170건), 초기 "수동 확인 보류" (#6~#29), 뒤집힌 명세 (뒤 빛 §12-JE.8, "얼굴이 중력 쪽으로 돈다", 크기 보간 §12-JE.1, "CLASSIC 연출을 젤리 색으로"의 고리, #109 "ModeRing만 숨김"), 낡은 JELLY 체크 항목 ("은은한 빛"·"반쪽 카드 설명"·"164Hz에서 CLASSIC·BLITZ도"·"합체 고리가 겹쳐 보이지 않는가")
- **정리 결과**: 인박스 #1~#100 → [archive/claude_to_codex_001-100.md](archive/claude_to_codex_001-100.md), 수동 확인 목록 정리 전 전체 → [archive/manual_qa_legacy_2026-10-25.md](archive/manual_qa_legacy_2026-10-25.md) (새 목록은 JELLY만), 회신 파일 #100 이하 보관은 Codex (#108 8번)

### 12-ONE.6 가장자리 젤리의 어두운 테두리 — 렌더링 (#111)
사용자 (2026-10-26, 편집기에서 main 실행 — #110 뒤): 스크린샷 (오른쪽 아래 구석 초록 젤리 둘레 어두운 고리), "시작부터 만들어저 있어", "공을 좌우로 보내면 좌우 끝에서 고리가 보이고, 가운데서는 안보이는게 그림자 처럼 느껴져"

- **연출이 아니다**: #110에서 고리 연출·그림 코드를 모두 지웠는데도 나온다. 합체 없이 시작부터 있고, 자리에 따라 (좌우 끝·구석) 생기고 가운데에서는 없다 — 카메라 시점·그리는 순서에 따라 생기는 렌더링 문제로 본다
- **Claude 픽셀 분석** (사용자 스크린샷): 초록 젤리 둘레 `(23~26, 51~56, 43~47)` — 제 색 × 약 0.22, 띠 두께 4~6px, 몸통 반지름의 약 1.2~1.3배까지. 같은 화면 오른쪽 벽 가운데쪽의 분홍·노랑에는 없다. Codex 캡처 `55_jelly_motion_rest` (실제로 쌓인 판)에서도 왼쪽 끝 젤리들은 바깥쪽 (왼쪽·아래)에 어두운 테두리, 가운데 젤리에는 없다. 앞선 사진들 (#104·#109 때)의 고리 젤리도 모두 구석·끝에 있었다 — **#102~#110에서 쫓던 "고리"의 상당 부분이 이것이었을 수 있다**
- **Claude 후보** (확정 아님 — 하나씩 꺼 보고 정한다):
  1. 반투명 그리기 순서 — 보드 유리판 (`Board3D` `Backing`, z −0.34, `blend_mix`)·중력장 (`GravityField`, z −0.31)과 젤리 몸통 (가장자리 알파 0.9, `depth_prepass_alpha`)이 같은 반투명 단계에서 카메라 거리순으로 그려진다. 화면 끝 젤리는 카메라에서 더 멀어 판보다 먼저 그려지고, 깊이를 쓰지 않은 몸통 가장자리를 판이 덮어 어둡게 할 수 있다
  2. 원근 시차 — 몸통 뒤쪽에 있는 무엇 (몸통 크기의 어두운 판·그림자 등)이 화면 끝에서만 바깥으로 비껴 보인다 (가운데에서는 몸통에 가려진다)
  3. 그림자 — `KeyLight` `shadow_enabled = true`, 젤리 `Mesh` `cast_shadow = 1` (#20부터, 사용자 요청 아님 → 원인이든 아니든 #111에서 끈다)
  4. 벽 안쪽 빛 띠 (`InnerGlow`, 벽 기준 z +0.17)·바깥 빛 (`OuterGlow`)
  5. 얼굴·배 속 판 (몸통 앞 평면)의 원근 어긋남
- **움직이는 동안 원 → 타원** — 사용자 (2026-10-26): "위아래, 좌우로 움직이는 동안 공의 형태도 원에서 타원으로 변하는 게 있어. 그것도 같이 검사해". 의도된 것: 말랑함 (§12-JE.7·#110 — 떨어질 때 중력 쪽 최대 `1 + 0.19`, 부딪히면 가로 최대 `1 + 0.18`, 숨쉬기 ±1.8%, 합체 부풀기 1.06). 의도하지 않았을 수 있는 것: 화면 끝 원근 왜곡, 중력이 바뀔 때 틀이 `delta × 8`로 도는 동안 늘어남 축이 비스듬해지는 것, 몸통·얼굴·배 속 판의 배율·회전 어긋남. 어느 것이 얼마인지 #111에서 잰다 — 의도된 말랑함이면 숫자와 함께 사용자에게 (줄일지·끌지), 의도하지 않은 것이면 고친다

**#111 1차 결과** ([PR #112](https://github.com/jeongmo-dot/gravity_orb/pull/112), 2026-10-26 Claude 검수 — 병합 보류): 측정은 사용자 관찰과 맞는다 — 고치기 전 어두운 띠는 끝·구석에서만 (540×960 아래·좌하·우하 45px, 540×1170 67px), 가운데 0. 원인 둘이 겹침: ① 보드 유리판·중력장이 거리순 반투명 그리기에서 끝 쪽 젤리 가장자리를 덮음 (몸통 색 띠) ② 몸통이 보드에 드리운 그림자가 원근으로 끝에서 삐져나옴 (사용자 "그림자 처럼"). 직교 카메라에서 둘 다 사라짐 (원근 탓 확인, 진단만). 움직임: 의도한 늘어남 최대 1.189·평균 1.099, 원근 왜곡 0.0002%, **중력이 바뀔 때 틀이 `delta × 8`로 도는 동안 늘어남 축이 최대 84~90° 기울어 있었다 (버그)**, 얼굴·배 판 원근 어긋남 최대 3.2px. 고침: 그림자 끔 (`shadow_enabled = false`, `cast_shadow = 0` — 소스 0건), 몸통 재질 `render_priority = 10`, 중력이 바뀌면 틀을 즉시 맞춤, 얼굴·배·문양 판을 카메라 쪽 광선 위에 둠. 고친 뒤 아홉 자리 어두운 띠 0, 기울어짐 0.000005°, 판 어긋남 0.00006px. 가장자리 밝힘 (`rim`)은 켠·끈 확대에서 바깥 띠를 만들지 않음 (Claude 확인 — 차이는 테두리가 살짝 밝아지는 정도). 래퍼 286/286, 해시 그대로 (Codex).
- **회귀 (Claude 캡처 검수)**: `08_jelly_full_down`에서 **배 속 젤리가 보이지 않고** (L3 채움 0·0.5·0.75가 모두 같아 보임), `06_jelly_blast_down`·`08`의 터질 듯한 얼굴·MAX 얼굴에서 **볼 (분홍)이 사라졌다**. 몸통 재질만 `render_priority = 10`이라, 반투명 단계에서 얼굴·배 판 (우선순위 0)이 먼저 그려진 뒤 몸통이 그 위를 덮는다 — 깊이를 쓰는 진한 눈·입만 남고 반투명한 볼 (알파 0.45~0.6)·배 속 젤리 (0.85)·눈 가장자리는 덮인다. Codex 회신의 "직접 확인"이 이것을 놓쳤다
- **부작용**: 틀을 즉시 맞추면서 배 속 젤리도 새 중력 쪽으로 한 번에 옮겨 간다 (예전에는 `delta × 8`로 부드럽게 돌았다)
- **추가 요구 1**:
  1. 얼굴·배 속·문양 재질을 몸통보다 나중에 그린다 (`render_priority`를 몸통 10보다 높게 — 예: 배 속 11·얼굴 12·문양 13). 볼·배 속 젤리·눈 가장자리가 #102·#104 때처럼 보이는지 픽셀로 확인 (볼 중심 — 노랑 L5 `(247,133,126)`·초록 `(192,131,142)`·파랑 `(200,112,170)` ±12, 배 속 젤리 채움 0.5·0.75에서 보임)
  2. 연출 (별가루·빛 구름·MAX 반짝임 등)이 몸통 앞에 있어야 할 때 몸통에 덮이지 않는지 확인 — 덮이면 그 재질도 몸통보다 나중에 (고치기 전과 같은 보임새)
  3. 배 속 젤리 위치는 예전처럼 중력 쪽으로 부드럽게 (`delta × 8`) 돈다 — 몸통 늘어남 축만 즉시 맞춘다
  4. 1차 측정 (아홉 자리 띠 0·기울어짐·판 어긋남)을 다시 해 그대로인지, 캡처 두 비율 전체 (볼·배 속·연출이 보이는 장면 확대 포함)
- 그대로: 1차의 그림자 끔·몸통 그리기 순서·틀 즉시 맞춤 (늘어남 축)·판 광선 배치

**#111 결과 — 병합** ([PR #112](https://github.com/jeongmo-dot/gravity_orb/pull/112) `9e546c6`, 2026-10-26): 추가 요구 1 반영 — 반투명 그리기 순서를 몸통 10 → 배 속 11 → 얼굴 12 → 문양 13 → 앞쪽 별가루·MAX 반짝임 14 (깊이 검사 끔)로 고정, 몸 뒤 빛 구름은 그대로. 배 속 젤리 위치만 `_jelly_belly_rotation`으로 `delta × 8` 부드럽게 (늘어남 축은 즉시). 볼 중심 노랑 L5 `(246,132,125)`·초록 `(192,131,142)`·파랑 `(200,112,171)` (예전 값 ±1), 배 속 젤리 보임 `(144,233,197)` vs 숨김 `(91,210,162)`. 아홉 자리 어두운 띠 0·늘어남 기울어짐 0 그대로, main에서 그림자 설정 0건. 래퍼 286/286, 해시 그대로 (Codex). Claude 검수 (`08_jelly_full_down`·`06_jelly_blast_down`·`25_jelly_max_effect_zoom`·`04_jelly_gameplay` 직접, 재실행 없음): 배 속 젤리 (채움 0.5·0.75)·볼 (터질 듯한·MAX)·MAX 반짝임 보임, 끝 쪽 젤리 띠 없음

**#108 1차 결과** ([PR #113](https://github.com/jeongmo-dot/gravity_orb/pull/113), 2026-10-26 Claude 검수 — 병합 보류): 9가지 중 8가지는 명세대로 —
- 호령 테스트 5개 되살림 (`test_jelly_turn_callout_stages_fire_once_per_chain`·`test_jelly_preview_and_unlock_use_jelly_art_and_names`·`test_callout_sound_uses_sfx_mute_and_stage_pitch`·`test_callout_toggle_hides_callout_and_preserves_jelly_state_hash`·`test_callout_frame_cost_report`, 성능 4 → 5), 래퍼 293/293
- **JELLY 기준 해시 새로**: 시드 `1085050` 한 판이 흡수 (레벨 그대로·오름)·L5 대폭발·L7이 L6 먹기·MAX CLEAR·FINAL MOVE 성공·실패를 모두 지남, 그림 켠·끈 같음 `2891601066178f822af63ef863edf9f40f82933979680ea5196ebe0033fa62a8` (이전 `5c96a80c…`를 대신하는 JELLY 물리 기준)
- `ObjectDB instances leaked` — 테스트 끝 직전 효과음 재생이 남긴 `AudioStreamPlaybackWAV` (테스트 코드 쪽) → 고쳐서 0건
- 호령·점수 팝업이 붐비는 판에서 젤리 얼굴을 덮음: 최대 100%, 1초 중 0.908초 (두 비율) — 보고만, 결정은 사용자
- 보드 왼쪽 흰 줄 = `SpaceBackdrop.gd` 배경 셰이더의 유성 (30초마다 0.6초)
- Codex 회신 #100 이하 → `docs/archive/codex_to_claude_001-100.md` (Claude 확인: 원문 5,207줄 중 빠진 줄 0)
- 사라진 빌드 파일: 지운 명령은 기록에서 찾지 못함. `build/windows-debug/`에는 0.11.1·0.13.0·0.13.1·0.14.0이 남아 있어 `build/windows/`만 겨냥한 정리로 본다. 빌드 스크립트가 다른 버전 파일의 경로·크기를 전후로 검사해 빠지거나 바뀌면 실패하게 하고 테스트 (`test_windows_build_preserves_other_version_artifacts`) 추가
- 캡처 31장 되살림 (두 비율 56장씩) — 옛 이름 대응표는 회신에
- **남은 것 → 추가 요구 1 (Claude 캡처 검수)**: 움직임 캡처가 이름과 내용이 다르다 — `44~53_jelly_motion_land_01~10`이 10장 모두 같은 동그란 젤리 (떨어짐 → 착지 → 돌아옴이 없다. 턴 입력 대기 상태라 말랑함 목표가 1로 잡힌 것으로 보임), `55_jelly_motion_rest`·`56_jelly_motion_right`는 공중에 띄운 격자 판 (실제로 쌓인 더미·오른쪽으로 쏠리는 움직임이 아님). 회신의 "착지/호흡/쌓임/오른쪽 중력 직접 확인"은 맞지 않는다
  1. 착지 띠: 젤리를 높이 두고 실제 중력으로 떨어뜨려 (턴 진행 중 — 쉼 상태 아님) 떨어지는 동안·착지 순간·돌아오는 동안을 10장. 각 장의 몸통 가로·세로 배율을 회신에 적어 장마다 달라짐을 보인다
  2. 쌓인 판: 실제로 떨어뜨려 바닥·벽·구석까지 맞닿아 쌓인 더미 (#101 추가 요구 1 때와 같은 방식)
  3. 오른쪽 중력: 쌓인 더미에서 중력을 오른쪽으로 바꾼 뒤 움직이는 도중
  4. 캡처 검사가 "장마다 다름"·"실제 접촉 쌍 수"를 확인해 같은 일이 다시 없게 한다

**#108 결과 — 병합** ([PR #113](https://github.com/jeongmo-dot/gravity_orb/pull/113) `a7625d4`, 2026-10-27): 추가 요구 1 반영 — `44~53` 착지 띠는 실제 L7 하나가 `y = −330`에서 떨어져 5번 장에서 바닥에 닿고 7~9번 반동·10번 정지 (PNG·물리 상태·몸체 비율 모두 10장이 서로 다름 — 캡처 검사가 확인), `55` 쌓인 판은 L1 40개가 실제로 쌓인 더미 (젤리끼리 접촉 54쌍·바닥 17·벽 4·구석 2 — 0이면 캡처 실패), `56` 오른쪽 중력은 같은 더미에서 0.22초 뒤 (움직이는 젤리 39/40). 캡처 중에는 반응 처리를 멈춰 더미가 합쳐 사라지지 않게 하고 끝나면 되돌림. 런타임 코드·설정 그대로. 래퍼 293/293 (성능 5/5), JELLY 기준 해시 `2891601…` (Codex). Claude 검수 (착지 띠 10장·`55`·`56` 직접, 재실행 없음): 떨어지며 세로로 늘어남 → 닿음 → 가로 눌림·반동 → 정지가 이어지고, 쌓인 판 구석 젤리에도 어두운 띠 없음 (#111 확인)

### 12-ONE.7 호령·점수 팝업 자리 · 배경 유성 삭제 (#112)
사용자 (2026-10-26): #108 측정 (붐비는 판에서 호령·팝업이 젤리 얼굴을 최대 100%·1초 중 0.908초 덮음)과 `35_callout_incredible` 캡처를 보고 → **"보드 밖 위쪽으로 옮기기"**, 배경에 30초마다 지나가는 흰 유성 (`SpaceBackdrop.gd` 셰이더 `meteor`, V2 우주 배경에서 들어옴) → **"없애기"**

- **호령** (NICE!·GREAT!·AMAZING!·INCREDIBLE!·UNSTOPPABLE! 등): 보드 위에 뜨지 않고 **보드 밖 위쪽** — 콤보 표시 (`x1 / COMBO n`) 아래와 보드 위쪽 가장자리 사이 빈 공간의 가운데. 보드·HUD·콤보 표시와 겹치지 않게 그 공간 높이에 맞춰 글자 크기를 줄인다 (두 비율에서). 단계별 생김새 (색·금색 반짝임)·소리·나오는 조건은 그대로
- **점수 팝업** (`+1,280`·큰 금색 `+48,600` 등): 젤리 얼굴 위가 아니라 **합쳐진 젤리 옆에 작게 잠깐** — 글자 크기 지금의 70%, 자리는 젤리 중심에서 오른쪽 (`r + 12px`)을 먼저, 보드 밖으로 나가거나 다른 젤리 얼굴을 더 덮으면 왼쪽·위·아래 중 얼굴을 가장 적게 덮는 쪽. 보이는 시간·떠오름·사라짐은 그대로
- **배경 유성 삭제**: `SpaceBackdrop.gd`의 유성 (`meteor`) 코드째 삭제. 별·성운 등 나머지 배경은 그대로
- 검수: #108의 겹침 측정을 다시 — 호령이 젤리 얼굴·보드와 겹치는 비율 0, 점수 팝업이 젤리 얼굴을 덮는 비율·시간 (붐비는 판), 캡처 두 비율 (호령 단계별·점수 팝업 작은 것·큰 것·붐비는 판), 소스에 `meteor` 0

**#112 결과 — 병합** ([PR #114](https://github.com/jeongmo-dot/gravity_orb/pull/114) `c93b468`, 2026-10-27): 호령 다섯 단계 (NICE!~UNSTOPPABLE!)는 콤보 표시 아래·보드 위 빈 공간 가운데, 올라가는 길 전체가 콤보·보드와 겹치지 않게 글자 크기 제한 — 얼굴·보드 겹침 0 (두 비율). 점수 팝업은 글자 70%, 실제 글자 사각형 (1.1배 튀어나옴·60px 상승 포함) 기준으로 오른쪽 `r + 12px` 먼저, 아니면 보드 안에서 얼굴을 가장 적게 덮는 쪽. 배경 유성 코드째 삭제 (`meteor` 0건). 래퍼 294/294, JELLY 기준 해시 그대로 (Codex). Claude 검수 (`57_callout_nice`·`34`·`58`·`35`·`59_callout_unstoppable`·`36`·`37`·`60_popup_crowded` 두 비율, 재실행 없음): 호령은 보드 밖 위쪽 (540×960에서는 보드 위 입력 화살표 바로 위, 겹치지 않음), 팝업은 젤리 옆. **남은 것**: 붐비는 판 (5×5)에서는 옆도 다른 젤리라 팝업이 얼굴을 최대 100%·1초 중 0.892초 덮는다 → 사용자 (2026-10-27) **"지금처럼 두기"**

### 12-ONE.8 JELLY 물리 — 단단한 구슬에서 젤리로 (#115)
사용자 (2026-10-29): 편집기에서 플레이한 뒤 **"물리 엔진이 좀 이상해"**. 증상은 "튕김·미끄러짐"과 "속도·무게감", 상황은 "중력 바꿔 떨어질 때". 방향은 빠르기 **"너무 느려요"**, 레벨 차 **"차이 줄이기"**, 착지 **"살짝만 통"**, 퍼짐 **"구르지 않고 착 붙기"**

**진단** (Claude, 코드 읽기 — 실행 없음): JELLY의 물리값은 모두 CLASSIC (M1, 2026-09-28, 단단한 행성 공)의 것을 그대로 쓴다. JELLY에 맞게 바꾼 물리값은 없다.
- **튕김**: `orb_bounce` 0.15·`wall_bounce` 0.10. Godot은 두 물체의 튕김을 더한다 (`PhysicsMaterial.absorbent` 설명). 그래서 실제 튕김은 젤리끼리 0.30, 젤리-벽 0.25. 튀어 오르는 높이는 튕김² × 떨어진 높이라서, 판 끝에서 끝까지 떨어진 L1은 약 57px 튄다. 자기 지름 50px보다 높다
- **미끄러짐**: 구체가 평면 안에서 마음대로 구른다 (`axis_lock_angular_z` 없음). 마찰은 0.3, `rolling_resistance`는 0이다. 그림은 중력 방향만 따라 돌고 (`Orb3D.gd` `_update_visual_transform()`의 `_mesh.rotation = _jelly_frame_rotation`) 몸이 구르는 것은 보이지 않는다. 그래서 굴러가는 구슬이 얼음 위를 미끄러지는 것처럼 보이고, 쌓인 더미는 굴러서 옆으로 퍼진다
- **빠르기**: L1은 1800 px/s²이고 레벨마다 +25%씩 세다 (L7은 4500). 판을 가로지르는 데 L1은 약 1.0초, L7은 약 0.55초 걸린다 (감쇠 무시)

| 필드 | 지금 | **새 값** | 효과 (감쇠 무시 계산) |
|---|---|---|---|
| `gravity_strength` | 1800 | **3600** | L1이 판을 가로지르는 시간 1.0 → 0.71초, 닿는 속도 약 1800 → 2560 px/s |
| `gravity_level_scale` | 0.25 | **0.05** | L7 = L1 × 1.30 = 4680 px/s² (지금 4500과 비슷 — 0.54초). L1과 L7의 걸리는 시간 차 1.83배 → 1.32배 |
| `orb_bounce` | 0.15 | **0.06** | 젤리끼리 0.30 → 0.12 |
| `wall_bounce` | 0.10 | **0.06** | 젤리-벽 0.25 → 0.12. 판 끝까지 떨어진 L1이 튀는 높이 57 → 13px, L7 42 → 10px. 두 번째 튐은 1px 아래 (한 번만 통) |
| `orb_friction` | 0.3 | **0.6** | |
| `wall_friction` | 0.3 | **0.6** | 젤리와 벽 값을 같게 둬서, 두 마찰을 섞는 규칙 (작은 쪽이든 곱의 제곱근이든)과 상관없이 실제 마찰은 0.6 |
| 회전 | 평면 안에서 구름 | **잠금** (`axis_lock_angular_z = true`, 새 설정 필드 없음) | 구르지 않고 미끄럼 마찰로만 멈춘다. 바닥에서 500 px/s로 밀린 L1은 약 0.23초·58px 안에 멈춘다 (마찰 × 중력 = 2160 px/s²). 지금은 구르느라 속도가 거의 줄지 않는다 |

- 3600은 #58 (2026-10-10)에서 써 본 값이다. 그때 L7 5760 (3600 × 1.6)까지 관통 측정을 통과했다. 이번 L7 4680은 그 안이다
- `GameConfig.gd` 기본값도 같은 값으로 맞춘다
- 그대로 두는 것: `orb_linear_damp` 0.1, 젤리 말랑함 (`JELLY_*` 상수 — 늘어남·눌림·흡수 크기), 규칙·점수, `stable_*`·`max_settle_time`, 색 효과 세기
- 위험: 젤리가 착 붙으면 더미가 덜 퍼져서 같은 색이 덜 만날 수 있다 (판이 더 빨리 찰 수 있다). 측정으로 확인하고, 결과를 보고 Claude가 값을 다시 정한다

**측정** (바꾸기 전 → 후, 같은 시드):
1. 레벨별 (L1·L4·L7) 판을 가로지르는 시간과 닿는 속도
2. 튕김: 판 끝까지 떨어진 L1·L7이 첫 번째·두 번째로 튀어 오른 높이 (px)와 실제 튕김 비율 (되튄 속도 ÷ 닿은 속도). 목표 0.12 ± 0.03. 벗어나도 값은 바꾸지 말고 보고한다 (Godot이 튕김을 섞는 규칙 확인용)
3. 미끄러짐: 쌓인 판 (L1 40개 — #108 `55`와 같은 방식)이 멈춘 뒤 더미의 너비·높이, 오른쪽 중력으로 바꾼 뒤 멈출 때까지 걸린 시간
4. 턴: 자동 플레이 (§12-M #89 방식, 시드 20개 이상)로 평균 턴 시간 (스와이프 → 입력 재개), 1.5초 강제 안정 비율, 턴당 합체 수, 게임 오버까지의 턴 수·점수
5. 관통: 고밀도 판의 최대 관통 (px, 10px 이하 유지), 판 밖 이탈 0
6. 색 효과 (밀기·흔들기·끌기·띄우기): 회전 잠금·마찰을 바꾼 뒤에도 보이는지 — 젤리가 움직인 거리 전/후
7. 캡처 두 비율: 착지 띠 `44~53`, 쌓인 판 `55`, 오른쪽 중력 `56`
8. JELLY 기준 해시는 물리가 바뀌므로 새로 만든다. 시드는 지금처럼 흡수 (레벨 그대로·오름)·L5 대폭발·L7이 L6 먹기·MAX CLEAR·FINAL MOVE 성공·실패를 모두 지나야 하고, 그림을 켜든 끄든 같아야 한다. `1085050`이 이제 다 지나지 않으면 새 시드를 찾는다

**#115 결과 — 병합** ([PR #115](https://github.com/jeongmo-dot/gravity_orb/pull/115) `cf3630f`, 2026-10-30): 값 6개와 젤리 몸 회전 잠금 (`Orb3D.gd` `setup()`의 `axis_lock_angular_z = _is_jelly_visual`)만 바꿨다. 측정은 변경 전 `origin/main`과 같은 조건으로 했다 (Codex):
- 판 가로지르기 / 닿는 속도: L1 1.042초·1669 px/s → **0.733초·2405 px/s**, L4 0.733 → 0.633초, L7 0.567 → 0.558초 (계산값 0.71·0.54초와 맞음)
- 튕김: 실제 비율 0.2496 → **0.120** (목표 0.12 ± 0.03 안 — "Godot은 튕김을 더한다"는 진단과 맞음). 첫 튐 L1 45.7 → 10.5 px, L7 36.0 → 9.7 px, 두 번째 튐 0
- 쌓인 판 (L1 40개): 멈춘 더미 너비 × 높이 960 × 188 → **437 × 256 px**, 오른쪽 중력으로 바꾼 뒤 멈출 때까지 4.03 → 1.23초
- 색 효과로 움직인 최대 거리: 밀기 356 → 231, 흔들기 137 → **17**, 끌기 283 → 66, 띄우기 124 → 62 px (모두 남아 있지만 흔들기가 가장 많이 줄었다)
- 자동 플레이 20시드 (101~120, 같은 방향 패턴, 400턴 상한): 평균 턴 1.515 → 1.391초, 1.5초 강제 안정 99.3% → 49.9%, 최대 관통 27.7 → 9.9 px, 판 밖 이탈 0. **턴당 합체 3.45 → 1.87 (−46%), 게임 오버까지 335 → 192턴 (−43%), 점수 462,849 → 49,209 (−89%)**
- 새 JELLY 기준 해시 `88cc180c…`: 시드 `1085050` 그대로 7가지 사건을 모두 지나고, 그림을 켜든 끄든 같다. 해시 입력에 물리값 6개와 회전 잠금을 넣었다. 래퍼 295/295, Debug 빌드 (Codex)
- Claude 검수 (`50_jelly_motion_land_07`·`55_jelly_motion_rest`·`56_jelly_motion_right`·`13_jelly_merge_effect` 직접, 재실행 없음): 착지 뒤 짧게 한 번 튀고, 더미가 판 전체로 퍼지지 않는다
- **남은 것**:
  1. 위험이 실제로 나타났다 — 판이 빨리 찬다 (위 숫자). 점수가 약 1/9이 되어 예전 물리로 세운 기록 (사용자 저장 파일의 최고 187,750)은 넘기 어렵다. 사용자가 직접 플레이해 본 뒤 결정한다: 그대로 / 마찰 낮추기 / 난도를 따로 낮추기
  2. `55` 더미는 떨어뜨린 격자 모양 그대로 네모난 블록으로 선다. 마찰이 0.6이면 젤리가 다른 젤리 꼭대기에서 31°까지 얹혀 있을 수 있다 (탑처럼 쌓임). 어색하면 1번과 함께 마찰로 조정한다
  3. 예전 물리에서는 턴의 99%가 1.5초 상한까지 기다렸다 (계속 굴러서). 지금도 절반은 상한까지 간다. 턴이 느리게 느껴지면 따로 본다

### 12-ONE.9 마찰 낮추기 — 덜 붙고 조금 퍼지게 (#116)
사용자 (2026-10-30): #115 결과를 보고 결정 대기 "물리 바꾼 뒤 난도"에서 **"마찰 낮추기"**를 골랐다. #115 결과는 봇 20판에서 턴당 합체 −46%, 게임 오버까지 335 → 192턴, 점수 −89%이고, 젤리가 다른 젤리 꼭대기에 31°까지 얹혀 있을 수 있다

- `orb_friction`·`wall_friction` 0.6 → **0.3** (둘을 같게 둔다). 회전 잠금·중력·튕김은 #115 그대로다. 젤리는 구르지 않고 미끄러지다 멈춘다
- 0.3은 #115 전과 같은 숫자지만, 그때는 구슬이 굴러서 마찰이 거의 일하지 않았다. 이번에는 회전 잠금이라 미끄럼 마찰로 멈춘다
- 계산 (L1, 중력 3600 px/s²):

| 마찰 | 바닥에서 500 px/s로 밀린 L1이 멈출 때까지 | 다른 젤리 꼭대기에 얹혀 있을 수 있는 각도 |
|---|---|---|
| 0.15 | 0.93초 · 231px | 8.5° |
| **0.3** | **0.46초 · 116px** | **16.7°** |
| 0.45 | 0.31초 · 77px | 24.2° |
| 0.6 (#115) | 0.23초 · 58px | 31.0° |

- **값을 한 번 더 고를 수 있게 마찰 0.15·0.3·0.45를 모두 잰다** (0.6은 #115 숫자가 기준). 설정에는 0.3만 넣는다. 최종 값은 측정을 보고 Claude가 정하고, 0.3이 아니면 추가 요구로 바꾼다

**측정** (마찰 0.15·0.3·0.45 각각, #115와 같은 도구·조건):
1. 쌓인 판 (L1 40개): 떨어뜨리는 격자의 가로 위치를 조금씩 흐트린다 (±10px, 고정 시드). 정렬된 격자는 마찰과 상관없이 네모 블록으로 서기 때문이다 (#115 `55`). 멈춘 더미의 너비·높이와, 오른쪽 중력으로 바꾼 뒤 멈출 때까지 걸린 시간을 잰다. 0.6도 흐트린 조건으로 다시 잰다
2. 바닥에서 500 px/s로 밀린 L1이 멈출 때까지의 시간·거리 (계산값 확인)
3. 자동 플레이 20시드 (101~120, #115와 같은 패턴·상한): 평균 턴 시간, 1.5초 강제 안정 비율, 턴당 합체 수, 게임 오버까지 턴 수·점수, 최대 관통, 판 밖 이탈
4. 색 효과 네 가지의 최대 이동 거리
5. 마찰 0.3으로 두 비율 전체 캡처 (마지막에)와 새 JELLY 기준 해시 (시드 `1085050`이 7가지 사건을 모두 지나는지)

**#116 결과 — 병합** ([PR #116](https://github.com/jeongmo-dot/gravity_orb/pull/116) `fd53a87`, 2026-10-30): 마찰 두 값만 0.3으로 바꿨다. 쌓인 판 격자는 가로 ±10px 흐트렸다 (시드 `11620261030`). 마찰별 측정 (Codex):

| 마찰 | 더미 너비 × 높이 (px) | 500 px/s로 밀린 L1이 멈출 때까지 | 턴당 합체 | 게임 오버까지 (턴) | 점수 | 1.5초 강제 안정 | 최대 관통 (px) |
|---|---|---|---|---|---|---|---|
| 0.15 | 962 × 592 | 0.94초 · 204px | 3.66 | 351 (16/20판만 끝남) | 483,977 | 96.0% | 34.1 |
| **0.3** | **802 × 484** | **0.53초 · 107px** | **2.76** | **272** | **263,685** | **84.2%** | **15.8** |
| 0.45 | 668 × 490 | 0.39초 · 72px | 2.18 | 218 | 101,182 | 64.3% | 22.1 |
| 0.6 (#115) | 596 × 392 | 0.33초 · 54px | 1.87 | 192 | 49,209 | 49.9% | 9.9 |
| #115 전 (구름) | 960 × 188 (흐트리지 않은 격자) | — | 3.45 | 335 | 462,849 | 99.3% | 27.7 |

- 0.3 채택: 0.6보다 판 길이 +81턴, 점수 5.4배, 턴당 합체 1.48배. #115 전과 비교하면 판 길이 81%, 점수 57%, 합체 80%다. 미끄럼이 멈추는 시간·거리는 계산 (0.46초·116px)과 비슷하다
- 새 JELLY 기준 해시 `d1f7ca9a…` (시드 `1085050`, 7가지 사건, 그림 켠·끈 같음). 래퍼 295/295, Debug 빌드 (Codex)
- Claude 검수 (`55_jelly_motion_rest` 직접, 재실행 없음): **왼쪽 벽에 L1 11개가 한 줄로 선 탑**이 있다. 캡처는 실제 플레이처럼 중력을 왼쪽 → 아래로 바꾼다. 왼쪽 중력에서 벽에 한 줄로 붙어 있던 젤리들이 아래로 떨어지며 서로 바로 위에 얹힌다. 회전을 잠그면 꼭대기에 똑바로 얹힌 젤리를 떨어뜨릴 힘이 없어서 그대로 선다. 구르는 공은 꼭대기에서 버티지 못한다 (#115 전 더미 높이 188px). 마찰 0.15에서도 더미 높이가 592px라서, 마찰만 낮춰서는 탑이 사라지지 않는 것으로 보인다 (0.3 말고는 캡처 없음) → 결정 대기 "벽에 선 젤리 탑"
- 남은 것: 최대 관통 15.8px (#115의 0.6은 9.9px, #115 전은 27.7px. 장기 표준 22시드는 9.4px로 10px 이하). 1.5초 강제 안정 84%

### 12-ONE.10 다시 구르게, 금방 멈추게 — 벽에 선 젤리 탑 없애기 (#117)
사용자 (2026-10-30): #116 검수에서 찾은 "벽에 선 젤리 탑"을 보고 **"다시 구르게, 금방 멈추게"**를 골랐다. `55` 캡처에서 중력을 왼쪽 → 아래로 바꾼 뒤 왼쪽 벽에 L1 11개가 한 줄로 서 있었다

- 원인 (Claude): #115의 회전 잠금. 젤리가 다른 젤리 바로 위에 얹히면, 어긋남이 미끄럼 마찰 각 (마찰 0.3이면 16.7°) 안일 때는 움직이지 않는다. 왼쪽 중력에서 벽을 따라 한 줄로 붙어 있던 젤리들은 아래 중력으로 바꾸면 똑바로 얹히므로 그대로 선다. 구를 수 있는 공은 꼭대기에서 버티지 못한다. 조금만 어긋나도 그 어긋남이 커져 굴러 떨어진다 (#115 전 더미 높이 188px)
- **회전 잠금 해제**: `Orb3D.gd` `setup()`의 `axis_lock_angular_z = _is_jelly_visual`을 없앤다. #115 전처럼 평면 안에서 구른다
- **`orb_angular_damp` 1.0 → 15.0**: 구르는 속도를 강하게 줄인다. 구르는 공의 속도는 1초에 약 (2/7) × (값 + Godot 기본 0.1)의 비율로 준다. 1.0이면 1초에 약 30%만 줄어서 #115 전에는 판 끝까지 굴러갔다
- 그림은 그대로 둔다 (얼굴은 똑바로, 몸이 구르는 것은 보이지 않음)
- 계산 (L1, 중력 3600, 마찰 0.3). 회전 없이 500 px/s로 밀린 L1은 처음에 미끄러지며 돌기 시작하고, 그다음 구르며 느려진다:

| 회전 감쇠 | 30 px/s 아래로 느려질 때까지 (계산) |
|---|---|
| 1.0 (#115 전) | 약 8초 · 1000px 넘게 (벽까지 굴러감) |
| 5 | 약 1.8초 · 260px |
| **15** | **약 0.7초 · 135px** |
| 30 | 약 0.5초 · 120px |
| 회전 잠금 (지금, 마찰 0.3) | 0.46초 · 116px (#116 측정 0.53초 · 107px) |

- 꼭대기에서 어긋남이 커지는 빠르기는 회전 감쇠 15에서도 감쇠가 없을 때의 약 3/4다. 그래서 탑은 무너질 것으로 본다 (측정으로 확인)
- 그대로 두는 것: 중력 3600·레벨 0.05·튕김 0.06·마찰 0.3, `JELLY_*`, 규칙·점수·난도, `stable_*`·`max_settle_time`, 색 효과 세기

**측정** (회전 감쇠 5·15·30 각각과, 지금 (회전 잠금·마찰 0.3)을 기준으로):
1. 탑: `55`와 같은 흐트린 더미에 같은 중력 순서 (…왼쪽 → 아래)를 쓴다. 아래 중력으로 바꾸고 0.5·1.0·1.5·3.0초 뒤의 더미 높이와 "가장 긴 줄"을 잰다. 가장 긴 줄은 바로 아래 젤리 하나에 얹힌 (접촉 방향이 중력과 10° 안) 젤리가 이어진 개수다
2. 바닥에서 회전 없이 500 px/s로 밀린 L1이 30 px/s·1 px/s 아래로 느려질 때까지의 시간·거리 (계산값 확인)
3. 자동 플레이 20시드 (#115·#116과 같은 조건): 평균 턴 시간, 1.5초 강제 안정 비율, 턴당 합체 수, 게임 오버까지 턴 수·점수, 최대 관통, 판 밖 이탈
4. 색 효과 네 가지의 최대 이동 거리
5. 회전 감쇠 15로 두 비율 전체 캡처 (마지막에, `55`에 탑이 없어야 함)와 새 JELLY 기준 해시 (시드 `1085050`이 7가지 사건을 모두 지나는지)

**#117 결과 — 병합** ([PR #117](https://github.com/jeongmo-dot/gravity_orb/pull/117) `ab4a7d8`, 2026-10-30): `Orb3D.gd` `setup()`의 회전 잠금 줄을 지우고 `orb_angular_damp`만 15.0으로 바꿨다. 회전 감쇠별 측정 (Codex, 마찰 0.3, 흐트린 L1 40개 더미 시드 `11620261030`):

| 조건 | 아래 중력 뒤 더미 높이 (px) · 가장 긴 줄 — 0.5 / 1.0 / 1.5 / 3.0초 | 오른쪽 중력 뒤 멈출 때까지 | 밀린 L1이 30 px/s 아래로 | 1 px/s 아래로 |
|---|---|---|---|---|
| 회전 잠금 (#116) | 538·8 / 484·10 / 484·10 / 484·10 | 1.45초 | 0.42초 · 107px | 0.44초 · 107px |
| 감쇠 5 | 572·3 / 252·3 / 173·2 / 138·2 | 2.51초 | 1.62초 · 237px | 12초 안에 못 감 (2.99 px/s) |
| **감쇠 15** | **578·8 / 299·2 / 177·3 / 171·3** | **2.69초** | **0.68초 · 125px** | **12초 안에 못 감 (1.04 px/s)** |
| 감쇠 30 | 589·4 / 319·4 / 237·2 / 182·2 | 2.38초 | 0.48초 · 110px | 0.94초 · 113px |

자동 플레이 20시드 (101~120, #115·#116과 같은 조건. 게임 오버까지 턴·점수는 400턴 상한 전에 끝난 판의 평균):

| 조건 | 게임 오버 | 게임 오버까지 (턴) | 점수 | 턴당 합체 | 평균 턴 | 1.5초 강제 안정 | 최대 관통 (px) |
|---|---|---|---|---|---|---|---|
| 회전 잠금 (#116) | 20/20 | 272 | 263,685 | 2.76 | 1.477초 | 84.2% | 15.8 |
| 감쇠 5 | 16/20 | 335 | 487,194 | 3.54 | 1.510초 | 97.7% | 30.6 |
| **감쇠 15** | **19/20** | **340** | **480,026** | **3.49** | **1.510초** | **97.7%** | **32.9** |
| 감쇠 30 | 20/20 | 332 | 496,587 | 3.36 | 1.509초 | 97.2% | 29.1 |
| #115 전 (구름, 감쇠 1.0) | — | 335 | 462,849 | 3.45 | 1.515초 | 99.3% | 27.7 |

- 15 그대로 채택: 계산 (0.7초·135px)과 측정 (0.68초·125px)이 맞는다 (5·30도 계산과 맞음). 아래 중력 뒤 탑이 1초 안에 무너진다 (가장 긴 줄 8 → 2. 3초의 3은 세 층 더미). 30은 더 빨리 멈추지만 1초에도 줄이 4개 남아 1.5초에야 무너진다 — 턴 상한 1.5초와 겹친다. 5는 1.6초·237px를 굴러 "금방 멈추게"에 맞지 않고, 20판 중 4판이 400턴 상한까지 간다
- 난도가 #115 전 수준으로 돌아왔다: 게임 오버까지 340턴 (#115 전 335), 점수 48만 (46만), 턴당 합체 3.49 (3.45). 예전 물리로 세운 기록 (사용자 최고 187,750)도 다시 넘을 만하다
- 새 JELLY 기준 해시 `a1f64302…` (시드 `1085050`, 7가지 사건, 그림 켠·끈 같음). 해시 입력에 `orb_angular_damp`를 넣었다. 래퍼 295/295, Debug 빌드 (Codex)
- Claude 검수 (`55_jelly_motion_rest`·`56_jelly_motion_right` 두 비율 직접, 재실행 없음): 벽에 선 탑이 없다. 40개가 바닥에 세 층쯤으로 낮게 퍼졌다 (높이 156px, 가장 긴 줄 2). `56`에서 더미가 오른쪽으로 움직인다
- **남은 것**:
  1. 1.5초 강제 안정 84% → 97.7%: 거의 모든 턴이 1.5초 상한까지 기다린다 (#115 전 99.3%와 같음). 턴이 느리게 느껴지면 따로 본다
  2. 최대 관통 32.9px (합체 직후, 시드 120). #115 전 27.7px보다 조금 크다. 장기 표준 22시드는 2D 13.0px·3D 17.1px
  3. 바닥에서 구르던 L1이 1 px/s 아래로 멈추지 않는다. 12초 뒤 속도가 감쇠 5에서 2.99, 15에서 1.04 px/s로 감쇠에 거의 반비례한다. 아주 작은 일정한 힘 (약 6 px/s², 중력의 0.2%쯤)이 계속 미는 것으로 보인다 (원인 미확인. 회전 잠금일 때는 미끄럼 마찰이 막았다). 30 px/s 아래로 느려진 뒤 11초 동안 18px만 움직여 눈에 띄지 않고, 안정 판정 (30 px/s)에도 걸리지 않는다

### 12-ONE.11 90° 꺾을 때 대각선을 지나게 — 왼→아래와 오른→아래를 다르게 (#118)
사용자 (2026-10-30): "지금은 중력이 4방향으로만 작용하잖아, 이것을 8방향으로 늘려서 좌에서 하로 갈 때와 우에서 하로 갈 때가 다른 중력 변화 과정을 거치게". 반대 방향으로 바꿀 때는 **"곧장 뒤집기"**를 골랐다

- 지금: 스와이프하면 공에 걸리는 중력이 그 물리 프레임에 바로 새 방향으로 바뀐다. 판 그림 (중력장 0.30초, 테두리 빛 0.25초)만 돌아간다. 그래서 왼→아래와 오른→아래는 바뀌는 과정이 같다 (곧장 아래)
- **바꿀 것**: 스와이프는 4방향 그대로 둔다. 중력을 90° 꺾을 때는 처음 `gravity_turn_diagonal_time` (새 필드, **0.15초**) 동안 두 방향 사이의 대각선으로 당기고, 그다음 새 방향으로 당긴다
  - 왼 → 아래는 왼아래를 지나고, 오른 → 아래는 오른아래를 지난다. 나머지 6가지 90° 꺾기도 두 방향 사이 대각선을 지난다 (중력 방향은 모두 8가지)
  - 반대 방향 (아래 ↔ 위, 왼 ↔ 오른)과 같은 방향은 지금처럼 곧장 바꾼다 (사용자 결정)
  - 대각선 중력의 세기는 곧은 방향과 같다 (방향만 45° 돌림, 레벨 보정 포함). `Vector2i(-1, 1)`을 그대로 곱하면 √2배가 되므로 정규화한다
  - 시간은 물리 프레임으로 센다 (120Hz에서 18프레임). 값이 0이면 지금과 같다
- 대각선은 **공에 거는 중력에만** 쓴다. 판 안의 모든 공 (전환 중에 새로 나온 공, 합체로 커진 공, 입구에서 풀려난 공 포함)은 그 순간의 실제 중력을 받는다
- 나머지는 모두 지금처럼 **최종 방향**을 쓴다: `TurnManager.gravity`, 신호 (`gravity_changed`·`turn_started`·`visual_gravity_changed`는 최종 방향으로 한 번), 입구·스폰 위치, 막힘·경고, FINAL MOVE, 띄우기 (노랑) 방향, 판 기울임, 중력장·테두리 빛, 배경 시차, HUD
- 턴: 전환이 끝나기 전에는 안정 판정을 쌓지 않는다 (안정 시간 0 유지). 1.5초 상한은 지금처럼 스와이프부터 센다 (턴 길이 그대로)
- 그림: 새 연출은 만들지 않는다. 판 그림은 이미 90° 꺾을 때 그 사이 모서리 쪽으로 돈다 (중력장 각도 보간, 테두리 빛은 가까운 쪽). 젤리 그림은 지금 규칙대로 실제 중력을 따른다
- 계산 (빈 판, 위쪽 가운데에 가만히 있던 L1이 바닥까지 약 900px 떨어질 때, 중력 3600):

| 대각선 시간 | 대각선이 끝날 때 옆 속도 | 바닥에 닿을 때까지 옆으로 간 거리 |
|---|---|---|
| 0 (지금) | 0 | 0 |
| 0.1초 | 255 px/s | 약 175px |
| **0.15초** | **380 px/s** | **약 255px** |
| 0.25초 | 635 px/s | 약 410px |

- 대각선 동안 얻은 옆 속도는 중력이 아래로 바뀐 뒤에도 남는다 (옆으로 당기는 힘도 막는 힘도 없음). 그래서 짧아도 공중에 있는 공은 크게 휜다. 스와이프 직후 입구에서 나오는 새 공이 가장 크게 영향을 받는다. 벽에 붙어 있던 공은 벽이 옆 속도를 막아서 거의 곧장 내려간다
- 0.15초는 판 중력장이 0.30초 동안 90° 도는 중에 45°를 지나는 때다
- 그대로 두는 것: 중력 3600·레벨 0.05·튕김 0.06·마찰 0.3·회전 감쇠 15, 스와이프 판정 (4방향), `JELLY_*`, 규칙·점수·난도, `stable_*`·`max_settle_time`, 색 효과 세기, 그림·연출, CLASSIC (`scripts/core/Board.gd`)

**측정** (대각선 시간 0.1·0.15·0.25 각각과, 지금 (0)을 기준으로):
1. 공 하나: 빈 판에서 중력을 왼쪽 (오른쪽)으로 두고 위쪽 가운데에 L1을 고정해 둔다. 아래로 바꾸는 순간 놓고, 바닥에 닿은 x와 옆으로 간 거리를 잰다 (계산값 확인). 왼→아래와 오른→아래가 좌우 대칭인지 본다
2. 쌓인 더미: `55`와 같은 흐트린 L1 40개를 쓴다. 중력 순서는 …왼 → 아래 (지금 `55`)와, 좌우를 바꾼 …오른 → 아래 두 가지다. 멈춘 더미의 무게중심 x, 너비·높이, 가장 긴 줄을 잰다
3. 자동 플레이 20시드 (#115~#117과 같은 조건. 방향 순서 아래·오른·위·왼·아래·왼·위·오른은 모두 90° 꺾기다). 0은 #117 결과를 기준으로 쓴다. 평균 턴 시간, 1.5초 강제 안정 비율, 턴당 합체, 게임 오버까지 턴 수·점수, 최대 관통, 판 밖 이탈
4. 0.15로 캡처: 새 캡처 3장 (왼→아래 대각선 도중 1장, 같은 더미를 왼→아래·오른→아래로 바꾼 뒤 멈춘 모습 2장)과 두 비율 전체 캡처 (마지막에). 새 JELLY 기준 해시 (시드 `1085050`이 7가지 사건을 모두 지나는지)

**#118 결과 — 병합** ([PR #118](https://github.com/jeongmo-dot/gravity_orb/pull/118) `e8450cc`, 2026-10-30): 판이 최종 방향 (`_gravity_direction`, 4방향)과 따로 공에 거는 실제 방향 (`_actual_gravity_direction`, 정규화)을 갖는다. 90° 꺾기에서만 `gravity_turn_diagonal_time` 동안 대각선으로 당기고, 같은·반대 방향은 곧장 바꾼다. 전환 중에는 안정 시간을 쌓지 않는다. 대각선 시간별 측정 (Codex):

| 대각선 시간 | 공 하나가 옆으로 간 거리 (계산) | 바닥에 닿는 시간 | 멈춘 더미 무게중심 x — 왼→아래 / 오른→아래 |
|---|---|---|---|
| 0 (#117) | 0 | 0.733초 | −59 / +69px |
| 0.1초 | 154px (175) | 0.758초 | −87 / +111px |
| **0.15초** | **234px (255)** | **0.775초** | **−84 / +107px** |
| 0.25초 | 385px (410) | 0.800초 | −104 / +74px |

자동 플레이 20시드 (#117과 같은 조건. 게임 오버까지 턴·점수는 400턴 상한 전에 끝난 판의 평균):

| 대각선 시간 | 게임 오버 | 게임 오버까지 (턴) | 점수 | 턴당 합체 | 1.5초 강제 안정 | 최대 관통 (px) |
|---|---|---|---|---|---|---|
| 0 (#117) | 19/20 | 340 | 480,026 | 3.49 | 97.7% | 32.9 |
| 0.1초 | 18/20 | 356 | 514,135 | 3.65 | 98.3% | 37.2 |
| **0.15초** | **17/20** | **337** | **456,640** | **3.53** | **98.4%** | **38.3** |
| 0.25초 | 15/20 | 337 | 499,110 | 3.63 | 98.8% | 45.8 |

- 0.15 그대로 채택: 공 하나는 왼→아래와 오른→아래가 정확히 좌우 대칭으로 휜다. 더미도 왼→아래는 왼쪽, 오른→아래는 오른쪽으로 더 치우친다 (0은 −59 / +69px, 0.15는 −84 / +107px, 캡처 `62`·`63`은 −93 / +93px). 판 길이·점수·합체는 0과 비슷하다. 다만 400턴 상한까지 간 판이 1판에서 3판으로 늘어 조금 쉬워졌다. 0.25는 관통이 45.8px로 커지는데, 더미 치우침은 0.15보다 크지 않다
- 공 하나 234px는 계산 255px보다 작다. 계산은 선속도 감쇠 (0.1 + Godot 기본 0.1)를 뺐고, 감쇠를 넣으면 약 250px다. 남은 차이는 대각선이 실제로 17스텝만 걸리기 때문으로 보인다 (17스텝이면 약 238px). Claude가 코드를 읽어 본 바로는, 끝내기가 `call_deferred`라서 18번째 물리 프레임의 스텝 전에 최종 방향이 들어간다. 0.142초와 0.150초라 체감 차이는 없어 그대로 둔다
- 새 JELLY 기준 해시 `58e00b4b…` (시드 `1085050`, 7가지 사건, 그림 켠·끈 같음). 해시 입력에 `gravity_turn_diagonal_time`을 넣었다. 래퍼 299/299, Debug 빌드 (Codex)
- Claude 검수 (`61_jelly_gravity_left_down_diagonal`·`62`·`63` 직접 확인, 재실행 없음): `61`에서 공이 왼아래로 가는 중이고 중력장 격자도 왼아래로 휜다. `62`는 왼쪽, `63`은 오른쪽으로 치우쳐 쌓인 더미다. 새 게임은 장면을 다시 불러 판이 새로 만들어지므로 시작할 때 대각선이 끼지 않는다
- 남은 것: 최대 관통 32.9 → 38.3px (합체 직후), 1.5초 강제 안정 98.4%

### 12-ONE.12 공이 빨리 늘어나게, 시작은 색마다 하나씩 (#119)
사용자 (2026-10-30): 턴마다 들어오는 공 수를 물은 뒤 **"첫번째 1개씩 5턴 그 다음부터 매 5턴 마다 공 한개씩 추가"**, **"그리고 시작할 때 아래에 색깔별로 공 하나씩 배치된 상태로 시작"**

**1. 공 늘어나는 간격**
- `spawn_count_ramp_turns` 50 → **5**. `spawn_count_per_turn` 1, `spawn_count_max` 0 (상한 없음)은 그대로다. 턴당 들어오는 공 = 1 + ⌊(턴 − 1) ÷ 5⌋

| 턴 | 지금 (50턴마다) | 새 규칙 (5턴마다) | 그때까지 누적 (새 규칙) |
|---|---|---|---|
| 1~5 | 1 | 1 | 5 |
| 6~10 | 1 | 2 | 15 |
| 26~30 | 1 | 6 | 105 |
| 46~50 | 1 | 10 | 275 |
| 96~100 | 2 | 20 | 1,050 |

- 지금은 한 판 (봇 약 340턴) 동안 약 1,300개가 들어온다. 새 규칙에서는 110턴쯤이면 그만큼 들어온다
- 입구 한 줄에는 L1이 많아야 19개 들어간다 (판 960px, 지름 50px). 위치가 무작위라 실제로는 더 적다. 턴당 19개가 되는 91턴부터는 판이 비어 있어도 한 턴 몫이 다 들어가지 못해 입구에서 기다린다 (→ FINAL MOVE). 그보다 먼저 판이 찰 것으로 본다. 판 길이는 측정으로 본다
- 그대로 두는 것: 색 해금 (4색 → 30턴 5색 → 60턴 6색), 크기 (L1 90%·L2 10%), 미리보기 (NEXT·THEN). 미리보기는 5개까지 보이고, 그보다 많으면 `×n`이 붙는다 (#56·#57). `×n`이 두 자리가 돼도 잘리지 않는지 캡처로 본다

**2. 시작 배치**
- 지금은 무작위 구체 2개 (`initial_orb_count`, 색·레벨 무작위)로 시작한다
- 바꾼 뒤에는 시작 색 (`color_count_for_turn(1)` = 4색)마다 **L1 하나씩**, 4개를 판 아래 바닥에 같은 간격으로 놓고 시작한다. 위치 규칙은 지금 `spawn_initial()`과 같다 (바닥 줄, (i + 1) ÷ (개수 + 1) 위치)
  - 색 순서는 판마다 섞는다 (Spawner의 시드 RNG를 쓰므로 같은 시드면 같은 순서다. Claude 결정). 색마다 하나씩이라 같은 색이 붙어서 시작하지는 않는다
  - 30·60턴에 열리는 색은 넣지 않는다. 해금 안내가 지금처럼 의미가 있게 둔다
  - `initial_orb_count`는 시작 배치에 쓰지 않는다
- 그대로 두는 것: 물리 (중력·튕김·마찰·회전 감쇠·대각선 0.15), 규칙·점수·FINAL MOVE, `stable_*`·`max_settle_time`, 그림·연출

**측정**:
1. 자동 플레이 20시드 (#118과 같은 조건): 지금 (#118 결과)과 새 규칙을 비교한다. 게임 오버 수, 게임 오버까지 턴 (평균·최소·최대), 점수, 턴당 합체, 게임 오버 때 턴당 들어오는 공 수, 들어온 공 총수, FINAL MOVE 횟수·성공, 평균 턴 시간, 1.5초 강제 안정 비율, 최대 관통, 판 밖 이탈
2. 판에 공이 가장 많을 때의 공 수와 물리 프레임 시간 (평균·최대, 기존 성능 측정 방식)
3. 캡처: 시작 화면 (바닥에 4색 L1 4개), 한 턴에 10개 넘게 들어오는 턴의 NEXT·THEN (두 자리 `×n`), 두 비율 전체 캡처 (마지막에). 새 JELLY 기준 해시 (시드 `1085050`이 7가지 사건을 다 지나지 않으면 새 시드를 찾는다)

**#119 결과 — 병합** ([PR #119](https://github.com/jeongmo-dot/gravity_orb/pull/119) `5b77ece`, 2026-10-31): `spawn_count_ramp_turns` 5. `spawn_initial()`은 `color_count_for_turn(1)`의 색을 Spawner 시드 RNG로 섞어 (Fisher–Yates) L1 하나씩 바닥 줄에 놓는다. `initial_orb_count`는 필드만 남고 (기본 2) 런타임은 읽지 않는다. 자동 플레이 20시드 (시드 101~120, #118과 같은 방향·물리·400턴 상한, Codex):

| | #118 (50턴마다) | **#119 (5턴마다)** |
|---|---|---|
| 게임 오버 | 17/20 | **20/20** |
| 게임 오버까지 턴 (평균 / 최소 / 최대) | 337 / 290 / 394 | **79.6 / 72 / 87** |
| 점수 (게임 오버 판 평균) | 456,640 | **604,802** |
| 턴당 합체 | 3.53 | **6.59** |
| 게임 오버 턴의 턴당 생성 수 (평균 / 최소 / 최대) | 7.3 / 6 / 8 | **16.4 / 15 / 18** |
| 한 판에 들어온 공 (게임 오버 판 평균) | 약 1,320 (계산) | **661** |
| FINAL MOVE (횟수 / 성공) | 20 / 3 (15%) | **21 / 1 (4.8%)** |
| 1.5초 강제 안정 | 98.4% | 96.2% |
| 최대 관통 (턴 끝) | 38.3px | 25.4px |
| 판 밖 이탈 | 0 | 0 |
| 판에 공이 가장 많을 때 (시드 평균 / 최대) | 102 / 126개 | 118 / 133개 |
| 그 턴의 물리 프레임 시간 (측정 도구 값, 시드 평균 / 최대) | 25.6 / 43.6ms | 32.3 / 52.8ms |

- 판 길이 337 → 약 80턴 (4분의 1). 게임 오버는 턴당 15~18개가 들어오는 72~87턴에 온다. 명세에서 본 91턴 (빈 판이어도 입구 한 줄에 한 턴 몫이 다 들어가지 못하는 턴)보다 먼저 판이 찬다. 점수는 턴당 합체·콤보가 늘어 오히려 32% 높다. FINAL MOVE는 한 턴 몫이 커서 거의 살리지 못한다 (4.8%). 값은 명세대로 그대로 두고 결과를 사용자에게 보인다 (턴당 상한 `spawn_count_max`는 사용자 결정)
- 물리 프레임 시간: Claude가 측정 코드를 읽어 본 바로는 이 값은 물리 프레임 사이의 실제 시간 (측정 도구가 프레임마다 모든 공을 검사하는 시간 포함, 4프로세스 병렬)과 `TIME_PHYSICS_PROCESS` 중 큰 값이라, 실제 게임의 프레임 시간이 아니다. 같은 도구로 #118보다 26% 늘었는데, 공이 가장 많은 순간이 102 → 118개로 늘었기 때문이다. 최대 공 수 (126 → 133)는 비슷하지만 이제 모든 판이 끝 무렵 이 수에 닿는다. 실제 창의 프레임 시간은 #121 (§12-ONE.14 — 사용자가 "화면을 채울 때쯤 많이 느려진다"고 알림)에서 잰다
- 새 JELLY 기준 해시 `ce7054b6…` (시드 `1085050`, 7가지 사건, 그림 켠·끈 같음). 램프 값을 함께 쓰는 CLASSIC 단계별 난도 해시도 바뀌었다 (`fc099580…`, 레거시). 120턴 생존 장기 테스트는 시드 101이 66턴에 게임 오버하므로 게임 오버까지 이탈·발산이 없는지 보는 테스트로 바꿨다. 래퍼 300/300, Debug 빌드 (Codex)
- Claude 검수 (diff, 캡처 `64_jelly_initial_four_colors`·`65_jelly_preview_double_digit` 두 비율 직접 확인, 재실행 없음): `64`는 바닥에 노랑·초록·파랑·분홍 L1이 같은 간격으로 놓였다. `65`는 NEXT·THEN 모두 5개와 `×11`이 잘리지 않는다. 테스트는 `initial_orb_count`를 99로 둬도 4개만 놓이는지 본다

### 12-ONE.13 대폭발은 L7끼리만 → L6부터 (#120)
사용자 (2026-10-31): **"폭발이 L7 이었으면 L7과 L7이 만났을 때만 폭발"**

- 지금: 다른 색·같은 레벨 젤리가 둘 다 L5 이상이면 닿을 때 대폭발한다 (`jelly_blast_min_level` 5, #98 J5 — §12-JE.5). L5는 판 절반, L6·L7은 판 전체를 밀어낸다
- **바꿀 것**: `jelly_blast_min_level` 5 → **7**. 규칙 코드는 그대로 두고 값만 바꾼다 (판정 `ReactionRules._classify_jelly()`, 표시 `GameConfig.blast_enabled_for_level()`이 이 값을 따른다)

| 닿은 두 젤리 | 지금 (L5부터) | 바뀐 뒤 (L7만) |
|---|---|---|
| 같은 색, 레벨 차 1 이하 | 흡수 (L7+L7은 잭팟) | 그대로 |
| 다른 색 L5+L5 · L6+L6 | 대폭발 (L5 판 절반, L6 판 전체) | **반응 없음** |
| 다른 색 L7+L7 | 대폭발 (판 전체) | 대폭발 (그대로) |
| 다른 색 L4 이하 같은 레벨 · 다른 색 다른 레벨 | 반응 없음 | 그대로 |

- 그래서 L7끼리 만날 때만 둘 다 사라진다: 같은 색이면 잭팟 (지금 그대로), 다른 색이면 대폭발. 점수 (대폭발 `(128 + 128) × 5` = 1,280, 잭팟 640)·밀어내는 범위·연출은 그대로
- 값을 따라 저절로 바뀌는 것: L5·L6의 터질 듯한 얼굴 `><`이 보통 얼굴로 돌아간다 (터질 수 없으므로). L7은 지금처럼 MAX 얼굴이다. 그래서 `><` 얼굴은 판에 나오지 않는다. 얼굴 코드는 지우지 않는다. 봇·측정의 대폭발 판단도 `active_blast_min_level()`을 따른다
- 위험 (기록에서):
  - #98: 대폭발이 없을 때 (J0) 실력 비 (L-합체 ÷ 무작위 판 길이)가 1.03이었다 (잘 두나 아무렇게나 두나 같음). L7은 60판 모두 0번. L5부터 (J5)로 1.47이 됐다
  - #103 (L5부터, #115 물리 전): L7까지 간 판은 무작위 0%, G 5%, L-합체 30%였다. 다른 색 L7 둘이 판에 함께 있어야 대폭발하므로 대폭발은 아주 드물 것으로 본다 → J0에 가깝다
  - 다른 색 L5·L6이 사라지지 않고 남아 판이 빨리 찬다. #119 (5턴마다 +1)와 겹쳐 판이 더 짧아질 수 있다
  - 물리는 #115~#118로 바뀌었고 그 뒤로 실력 비는 재지 않았다. 판 길이·실력 비는 측정으로 본다. 결과가 나빠도 값은 그대로 두고 보고한다 (결과를 사용자에게 보여 주고 정한다)
- 그대로 두는 것: 흡수 규칙·잭팟, `blast_push_radius_by_level`·`blast_speed`·`blast_far_factor`·`blast_score_factor`, 물리, #119 값 (생성 램프·시작 배치), 색 해금, 그림·연출 (새 연출 없음), CLASSIC `blast_min_level` (레거시)

**측정** (#124 병합 뒤 main 기준 — 생성은 10턴마다 +1, 같은 방향 막힘. J5 = 지금, J7 = 새 값):
1. 자동 플레이 20시드 (#124와 같은 조건): J7을 #124 결과 (J5)와 비교한다. 게임 오버 수, 게임 오버까지 턴 (평균·최소·최대), 점수, 턴당 합체, 대폭발 수 (레벨별), 잭팟 수, L7 생성 수, FINAL MOVE 횟수·성공, 게임 오버 때 판에 남은 L5 이상 젤리 수
2. 실력 비 (§12-JE.5 #98 방식, `tests/tools/run_jelly_blast_measurement.ps1`): J5·J7 × 전략 R·G·L-합체 × 시드 1~20. 턴·점수 중앙값, 실력 비 (L ÷ R 길이·점수), 같은 시드 L 우세율, 초반 합체 (1~30턴), 대폭발 수, L7 판 비율, 잭팟 수. 도구가 지금 main에서 돌지 않으면 고쳐서 쓰고 회신에 적는다
3. 캡처: 다른 색 L5+L5·L6+L6이 닿은 채 반응 없이 있는 판 (보통 얼굴), 다른 색 L7+L7 대폭발 순간, 두 비율 전체 캡처 (마지막에). L5·L6 대폭발이나 터질 듯한 얼굴을 보여 주던 기존 캡처 (`06_jelly_blast_down`·`56_jelly_blast_face` 등)는 새 규칙에 맞게 바꾸고, 바꾼 목록을 회신에 적는다
4. 새 JELLY 기준 해시. 7가지 사건의 "L5 대폭발"은 "L7 대폭발 (다른 색 L7+L7)"로 바꾼다. 고정 시드 경로에서 자연스럽게 지나지 않으면 회귀 장면에 젤리를 놓아 만들어도 된다 (방법을 회신에 적는다)
5. ~~(#119 후속) 실제 창 프레임 시간~~ → #121 (§12-ONE.14)로 옮김. #120은 #121 뒤라, J7에서 장면 ③ (합체가 많은 턴)의 프레임 시간만 한 번 더 잰다

**#120 1차 결과** ([PR #124](https://github.com/jeongmo-dot/gravity_orb/pull/124), 2026-10-31 Claude 검수 — **병합 보류**): `jelly_blast_min_level` 7, 회귀의 대폭발 사건을 다른 색 L7+L7로, 캡처 `06_jelly_l5_l6_no_blast`·`07_jelly_l7_blast`·`15` (L7 쌍). 래퍼 308/308, 해시 `5656ac3c…` (Codex). 코드·테스트는 명세대로다 (Claude가 diff와 캡처 `06`을 직접 확인, 재실행 없음). 측정 (Codex, #124 위 — 10턴마다 +1·같은 방향 막힘):

| 봇 20판 (시드 101~120) | J5 (지금) | J7 |
|---|---|---|
| 게임 오버까지 턴 (평균 / 최소 / 최대) | 112.8 / 102 / 129 | **83.0 / 80 / 86** |
| 점수 (평균) | 414,217 | **47,161** |
| 턴당 합체 | 4.90 | 3.34 |
| 대폭발 (레벨별) | 204 (모두 L5) | **0** |
| 잭팟 / L7 생성 | 0 / 0 | 0 / 1 |
| FINAL MOVE (횟수 / 성공) | 22 / 2 | 23 / 3 |
| 게임 오버 때 판의 L5 이상 (평균) | 2.7 | 6.3 |

| 전략 봇 (시드 1~20, 600턴 상한) | R 턴 / 점수 | G 턴 / 점수 | L-합체 턴 / 점수 | 실력 비 L÷R 길이 / 점수 | 같은 시드 L 우세 (길이 / 점수) | 대폭발 (R·G·L) |
|---|---|---|---|---|---|---|
| J5 | 102 / 228,449 | 107 / 274,161 | 122 / 552,477 | 1.20 / 2.42 | 100% / 95% | 132·172·278 |
| J7 | 82 / 48,355 | 83 / 38,062 | 83.5 / 54,658 | **1.02 / 1.13** | 77.5% / 45% | 0·0·0 |

- J7은 다른 색 L7 둘이 함께 닿는 일이 120판 동안 한 번도 없어 대폭발이 사실상 사라졌다 (#98 J0와 같은 상태 — 실력 비 1.03). 다른 색 L5·L6이 판에 남아 (끝날 때 6.3개) 판이 26% 짧아지고 점수는 89% 줄었다
- 참고: J5의 실력 비도 1.20으로 #98 (1.47)·#103 (1.45)보다 낮다. 그 뒤 물리 (#115~#118)와 생성 (#119·#123)이 바뀌었다
- J7 실제 창 장면 ③ (공 112개): 프레임 p99 5.2ms, 게임 ÷ 실제 시간 1.00
- 사용자 결정 (2026-10-31, 결과를 보고): **"L6부터로 다시 재기"** → 추가 요구 1

**추가 요구 1 — L6부터** (같은 브랜치·PR #124에서):
1. `jelly_blast_min_level` 7 → **6**. 다른 색 L5+L5는 반응 없음, 다른 색 L6+L6·L7+L7은 대폭발 (L6·L7 모두 판 전체 밀어내기, 점수 L6 쌍 `(64 + 64) × 5` = 640), 같은 색 L7+L7은 잭팟
2. 얼굴: L6은 터질 듯한 얼굴 `><`, L5는 보통 얼굴, L7은 MAX 얼굴 (값을 따라 저절로)
3. 테스트·회귀: 위 판정과 얼굴. 회귀의 대폭발 사건은 다른 색 L6+L6으로. 새 기준 해시
4. 측정: 1차와 같은 두 측정 (봇 20판, 전략 봇 R·G·L × 20)을 **J6**으로. 표에는 1차의 J5·J7과 나란히 (같은 코드 기준이 아니면 J5도 다시). 대폭발은 레벨별 (L6·L7)
5. 캡처: `06`은 다른 색 L5+L5가 반응 없이 붙어 있고 (보통 얼굴) L6은 `><` 얼굴인 판, `07`은 다른 색 L6+L6 대폭발 순간, `15`는 L6 쌍. 이름은 내용에 맞게 바꾸고 회신에 적는다. 두 비율 전체 캡처 (마지막에)
- 값은 6으로 두고 결과를 보고한다. 병합 여부와 최종 값 (5·6·7)은 결과를 보고 사용자와 정한다

**#120 결과 — 병합 (L6)** ([PR #124](https://github.com/jeongmo-dot/gravity_orb/pull/124) `32ee9d8`, 2026-10-31): 추가 요구 1 반영 — `jelly_blast_min_level` **6**. 다른 색 L5 반응 없음, 다른 색 L6·L7 대폭발, 같은 색 L7 잭팟. 회귀의 대폭발 사건은 다른 색 L6+L6, 새 해시 `5e00b1f7…`, 래퍼 308/308 (Codex). 측정 (Codex, 같은 조건):

| 봇 20판 (시드 101~120) | J5 | **J6** | J7 |
|---|---|---|---|
| 게임 오버까지 턴 (평균 / 최소 / 최대) | 112.8 / 102 / 129 | **87.9 / 80 / 98** | 83.0 / 80 / 86 |
| 점수 (평균) | 414,217 | **90,588** | 47,161 |
| 턴당 합체 | 4.90 | **3.63** | 3.34 |
| 대폭발 (레벨별) | 204 (L5) | **18 (L6)** | 0 |
| FINAL MOVE (횟수 / 성공) | 22 / 2 | 23 / 3 | 23 / 3 |
| 게임 오버 때 판의 L5 이상 (평균) | 2.7 | 5.9 | 6.3 |

| 전략 봇 (시드 1~20) | R 턴 / 점수 | G 턴 / 점수 | L-합체 턴 / 점수 | 실력 비 L÷R 길이 / 점수 | 같은 시드 L 우세 (길이 / 점수) | 대폭발 (R·G·L) |
|---|---|---|---|---|---|---|
| J5 | 102 / 228,449 | 107 / 274,161 | 122 / 552,477 | 1.20 / 2.42 | 100% / 95% | 132·172·278 |
| **J6** | **83.5 / 57,981** | **86 / 51,445** | **95 / 150,686** | **1.14 / 2.60** | **92.5% / 75%** | **9·13·37** |
| J7 | 82 / 48,355 | 83 / 38,062 | 83.5 / 54,658 | 1.02 / 1.13 | 77.5% / 45% | 0·0·0 |

- **결정 (사용자, 2026-10-31 — 세 값을 나란히 본 뒤 "L6부터로 병합", Claude 추천)**: J6은 대폭발이 드물지만 있다 (봇 판당 약 1번, 잘 두는 봇 약 2번) — 사용자가 처음 원한 "큰 젤리끼리만 터지는 드문 순간"에 가깝고, 실력 비 (점수 2.60)가 살아 있다. J7은 대폭발이 사라져 실력 비가 #98 J0 수준 (1.02)이었다
- 대가: 판이 113 → 88턴, 점수 41만 → 9만. 다른 색 L5가 판에 남는다 (끝날 때 L5 이상 5.9개). 판 길이는 생성 램프 (`spawn_count_ramp_turns`)로 따로 맞출 수 있다
- 얼굴: L6 `><`, L5 보통, L7 MAX (값을 따라). 얼굴 코드 보존용 볼 확대 캡처 (`20~22`)만 격리 장면에서 잠시 5로 낮춘다
- Claude 검수 (diff, 캡처 `06_jelly_l5_no_blast_l6_face` 직접 확인, 재실행 없음): 다른 색 L5 둘이 맞닿아도 보통 얼굴로 남고, L6 둘은 `><` 얼굴이다

### 12-ONE.14 공이 많을 때 느려짐 — 가볍게 (#121)
사용자 (2026-10-31): **"공이 많아졌을 때 화면을 채울 때 쯤 많이 느려지네, 좀 더 빠르고 가볍게 할 수 없을까"**

- 배경: #119부터 모든 판이 끝 무렵 판에 공이 약 120개가 된다 (봇 20판: 가장 많을 때 평균 118개, 최대 133개). 한 턴에 15~18개가 들어오고, 판이 차면 들어오지 못한 공이 입구에서 기다린다. 측정 도구의 물리 프레임 시간은 #118보다 26% 늘었지만 (§12-ONE.12 결과), 실제 창의 값은 아직 재지 않았다
- **Claude 코드 읽기 (측정 아님)** — 공 수에 따라 커지고 물리 프레임마다 (초당 120번) 도는 곳:
  1. `Board3D._update_entrance_waiters()`: 입구에서 기다리는 공마다 `find_free_spawn_slot()`이 입구 줄 전체를 5px 간격 (약 180곳)으로 판의 모든 공과 비교한다. 넘겨주는 `placed`에 판의 공이 이미 다 들어 있는데 `find_free_spawn_slot()`이 `_orbs`를 또 더해서, 한 곳마다 공을 두 번씩 (약 2n) 본다. 판이 차 있으면 대부분 실패하므로 180곳을 다 본다. 기다리는 공 16개, 판 120개면 최악 약 16 × 180 × 240 ≈ 70만 번 거리 비교 (GDScript). **"판이 찰 때"에만 커지는 곳은 이것뿐이라 가장 유력하다** — 측정으로 확인한다
  2. `CollisionResolver._scan_geometric_contacts()` (`flush()`에서 매 프레임): 칸 키를 문자열로 만들고 (`"%d:%d"`, 공마다 9번), 닿은 쌍마다 `_pair_can_react()` → `ReactionRules.classify()`가 사전 (Dictionary)을 만든다. 꽉 찬 판은 닿은 쌍이 약 300개다
  3. `TurnManager._all_below_threshold()` → `CollisionResolver.has_pending_reactions()`: 반응 잠금마다 `_current_reaction_partners()`가 모든 공을 돌며 `classify()`한다
  4. `Board3D._update_ghost_orbs()`: 막 들어온 공 (턴마다 최대 18개)마다 `maximum_normal_overlap()`이 모든 공을 돈다
  5. `get_orbs()`는 부를 때마다 새 배열을 만든다. 한 프레임에 여러 번 불린다
  6. 턴 시작 생성 (`try_spawn`·`blocked_spawn_directions()`): 공마다 입구 줄을 훑는다 (턴마다 한 번 튀는 비용)
  - 그리기: 젤리마다 반투명 층 (몸통·배 속·얼굴·문양)이 여러 장이다. 130개면 수백 장. 재지 않았다
- **방법**:
  1. **먼저 잰다** (바꾸기 전): 실제 창 (Debug 빌드 또는 편집기 실행, 한 프로세스, 수직 동기 끔), 540×960. 장면 ① 공 약 120개가 멈춘 판 (기다리는 공 없음) ② 같은 판에 입구에서 기다리는 공 16개 (판이 꽉 참) ③ 합체가 많은 턴 (#119 게임 오버 무렵 — 예: 자동 플레이 시드로 75턴쯤까지). 보고: 프레임 시간 p50·p99·최대, 그 안의 물리 한 스텝 (Jolt)·스크립트 (위 1~6 각각)·그리기 시간, 그린 프레임마다 물리 스텝 수 (따라잡기), 그리기 호출 수, 게임 시간이 실제 시간보다 얼마나 느리게 가는지
  2. **잰 순서대로 고친다**: 규칙·물리 값·느낌·결과는 그대로다. **JELLY 기준 해시가 바뀌면 안 된다** (같은 결과를 더 싸게 내는 고침만). 예: 기다리는 공 탐색에서 겹친 목록 없애기, 비교할 목록을 프레임마다 한 번만 만들어 함께 쓰기, 문자열 키 대신 정수·`Vector2i` 키, 반응 가능 판정을 사전 없이 (같은 규칙), `get_orbs()` 결과를 프레임 안에서 다시 쓰기. 어떤 고침을 할지는 Codex가 측정을 보고 고른다
  3. 결과 (해시)가 바뀌어야만 되는 고침 (예: 매 프레임이 아니라 몇 프레임마다 검사), 물리 주기 (120Hz)를 바꾸는 것, 그림·연출을 줄이는 것은 **하지 않고** 효과 추정과 함께 보고한다 (사용자 결정)
- 목표: 장면 ①~③에서 물리 한 스텝 (스크립트 포함) p99 4ms 이하, 전체 프레임 p99 16.7ms 이하, 게임 시간이 실제 시간과 같은 빠르기. 못 미치면 남은 비용과 원인을 보고한다
- 그대로 두는 것: 규칙·점수, 물리 값·물리 주기, #119 값, 그림·연출, 자동 플레이 결과

**측정**:
1. 장면 ①~③의 고치기 전·후 표 (위 항목별 시간, 공 수, 기다리는 공 수)
2. JELLY 기준 해시 그대로 (`ce7054b6…`, 그림 켠·끈 같음)
3. 자동 플레이 20시드 (#119와 같은 조건)가 #119 결과와 같은지 (판 길이·점수·합체 수가 같아야 한다)
4. 장면 ②는 편집기 실행과 Debug 빌드 창 둘 다 잰다 (사용자가 어느 쪽으로 해 보는지에 따라 다를 수 있다)

**#121 결과 — 병합** ([PR #120](https://github.com/jeongmo-dot/gravity_orb/pull/120) `12bf7a3`, 2026-10-31 — PR 번호와 항목 번호가 다르다): 규칙·값·물리 주기·그림은 그대로 두고, 반복 전수 탐색과 반응 판정의 사전 만들기를 줄였다. 실제 창 (540×960, 수직 동기 끔, 한 프로세스, 편집기 실행) 고치기 전 → 후 (Codex, p50 / p99, ms):

| 장면 | 전체 프레임 | 스크립트 (물리 쪽 합계) | 그린 프레임마다 물리 스텝 (p50 / p99) | 게임 시간 ÷ 실제 시간 |
|---|---|---|---|---|
| ① 공 120개 멈춘 판 | 16.6 / 25.6 → **2.2 / 4.3** | 6.8 / 10.1 → **0.9 / 1.6** | 2 / 3 → 0 / 1 | 1.00 → 1.00 |
| ② ① + 입구 대기 16개 | **104.7 / 109.0** → **2.3 / 4.5** | **12.3** / 13.6 → **0.9 / 1.5** | **8 / 8** → 0 / 1 | **0.64** → **1.00** |
| ③ 75턴 합체 많은 턴 | 8.1 / 26.9 → **2.4 / 5.6** | 5.9 / 9.1 → **0.8 / 4.0** | 1 / 3 → 0 / 1 | 1.00 → 1.00 |

- **원인 (측정으로 확인)**: 물리 한 스텝 (120Hz)의 예산은 8.33ms다. 고치기 전 스크립트만 ① 6.8ms (닿은 쌍 찾기 `flush` p99 9.7ms), ② 12.3ms (기다리는 공 자리 찾기 p99 6.9ms + `flush` 7.5ms)였다. ②에서 예산을 넘자 엔진이 밀린 스텝을 한 프레임에 최대 8번까지 몰아 돌려 프레임이 105ms (약 10fps)가 되고, 그래도 따라잡지 못해 게임이 실제 시간의 0.64배로 느려졌다. 판이 차서 입구에서 공이 기다릴 때만 생기므로 사용자 관찰 ("화면을 채울 때쯤 많이 느려진다")과 맞는다. Claude가 코드만 보고 가장 유력하다고 본 기다리는 공 탐색은 예산을 넘기는 마지막 몫이었고, 늘 도는 닿은 쌍 찾기도 그만큼 비쌌다
- 고친 것: ① 닿은 쌍 찾기 — 문자열 칸 키 → `Vector2i`, 칸 크기를 판의 실제 최대 반지름으로, 이웃 칸을 앞쪽 5칸만 (쌍마다 한 번), 공 값을 배열에 한 번 모아 쓰기, `ReactionRules.can_react()` (사전 없이 `classify() != NONE`과 같은 판정, 모든 색·레벨 조합 테스트), 점유율을 반응마다 다시 세지 않고 더하고 빼기, 쌍 키를 정수로 ② 기다리는 공·입구 경고·턴 생성 — 판의 공을 프레임마다 한 번 모으고 (겹친 목록 없앰), 공마다 입구 줄에서 막는 구간을 계산해 (중력·반지름별로 같은 프레임 안에서 재사용) 180곳을 공 전부와 비교하던 것을 구간 확인으로 ③ 반응 대기 판정 — 잠금이 없으면 바로 끝, JELLY는 색·레벨 묶음에서만 짝을 찾는다 ④ 유령 해제 — 공 목록을 프레임에 한 번
- 같은 결과: JELLY 기준 해시 `ce7054b6…` 그대로 (그림 켠·끈 같음), 자동 플레이 20시드 (#119 조건)의 판 길이·점수·합체·생성·FINAL MOVE·매 턴 기록이 20/20 같다. 고친 함수 넷의 고치기 전·후 같음 테스트 4개. 막는 구간 계산은 경계에서 반올림이 다를 수 있지만 해시·20판에서 차이가 없었다
- 목표 대조: 전체 프레임 p99 16.7ms 이하·실제 시간과 같은 빠르기는 세 장면 모두 맞다. 물리 한 스텝 p99 4ms 이하는 ①② 맞고 (3.3 / 3.2ms), ③은 엔진 모니터 값이 8.8ms로 나왔다. 같은 장면의 전체 프레임 p99가 5.6ms, 스텝 수 p99가 1이라 모니터가 여러 스텝 값을 묶어 되풀이한 것으로 보인다 (Codex). 합체가 몰리는 프레임의 Jolt 한 스텝 시간은 확인하지 못한 채 남긴다
- Debug 빌드 창: 전체 프레임 p99 ① 4.2 / ② 4.3 / ③ 6.1ms, 게임 ÷ 실제 시간 1.00
- 측정기: Debug 빌드·편집기에서 `--full-board-performance --performance-output=<절대 JSON 경로>` (사용자 인수)로 장면 ①~③을 실제 창에서 잰다 (`scripts/platform/FullBoardPerformanceMeasurement.gd`, Release에서는 꺼짐). 그리기 호출은 공 120개에서 약 310~365로 줄이지 않았다
- Claude 검수 (diff, 재실행 없음): `can_react()`가 `classify()`의 모든 갈래와 같은지, 앞쪽 5칸이 모든 쌍을 한 번씩 보는지, 막는 구간이 열린 구간 (경계는 비어 있음)으로 원래 `<` 비교와 같은지, 기다리는 공을 놓은 뒤 구간을 다시 계산하는지 확인했다. 남은 것: `_scan_geometric_contacts()` 안쪽 블록 들여쓰기가 한 단계 깊다 (동작 문제 없음, 다음에 그 함수를 고칠 때 정리)

### 12-ONE.15 미리보기를 판과 같은 크기로 (#122)
사용자 (2026-10-31): NEXT에 큰 노랑·작은 노랑, THEN에 작은 젤리 셋이 보이는 스크린샷과 함께 "이렇게 나오는데 L1, L2 만 들어온다고?" → Claude 설명 (큰 노랑이 L2, 작은 노랑이 L1. 미리보기는 칸에 맞춰 최대 2배로 키우고, THEN은 다시 0.6배) → 시안 A "미리보기를 판 위와 같은 크기로 고정" 선택, **"A로 해줘. NEXT도 같은 크기로"** (THEN도 NEXT와 같은 크기 — 흐림은 그대로)

- 지금: `Hud._render_preview()`가 한 묶음을 `PREVIEW_REGION_SIZE` (480×180)에 맞춰 `preview_scale = min(2.0, 맞춤 배율)`로 키운다. 공 2개면 2배, 5개면 약 1.5배라 같은 L1도 턴마다 크기가 다르고, NEXT의 L2 (반지름 40 × 2배)가 판 위 L4 (반지름 85)와 비슷하게 보인다. THEN은 `UI.tscn`의 `ThenPreview` 노드가 다시 0.6배·알파 0.5다 (#26, §11.10 큐[1] "작고 흐리게")
- **바꿀 것**:
  1. NEXT·THEN 미리보기 젤리가 화면에서 **판 위 같은 레벨 젤리와 같은 크기**로 보인다. 배율은 판의 화면 투영 (`_projected_board_rect()`) 너비 ÷ `board_size`로 정하고, 창 크기·비율이 바뀌면 다시 계산한다. 공 개수와 상관없이 같은 레벨은 늘 같은 크기다
  2. THEN도 NEXT와 같은 크기 (`ThenPreview` 0.6배 → 1.0). 흐림 (알파 0.5)은 그대로 (사용자 결정)
  3. 한 줄이 칸보다 길면 먼저 젤리 사이 간격을 줄이고 (최소 0), 그래도 넘치면 **크기는 그대로** 두고 이웃끼리 같은 만큼 겹쳐 놓는다 (앞 젤리가 위). 배율을 줄이지 않는다
     - 어림 (가로 1080 기준, 판 배율 약 1.04): L1 지름 약 52, L2 약 83. NEXT 칸 (480)에는 L2 5개까지 들어간다. THEN 칸 (약 370)에는 L1 5개 (약 330)는 들어가고, L2가 2개 이상 섞이면 넘친다 (턴당 5개 이상일 때 약 8%)
  4. 칸 안 세로 위치, `×n` 표시, 새 색 반짝임, NEXT·THEN 글자는 그대로
- 그대로 두는 것: 미리보기 개수 (5개까지)·`×n` 규칙, 미리보기 젤리 그림 (`setup_jelly_preview()`), 판·규칙·물리·생성
- 확인: 판 위 몸통과 미리보기 몸통의 화면 지름 (픽셀)을 재서 차이 5% 이내 (젤리가 멈춰 있을 때, 두 비율). JELLY 기준 해시 그대로 (그림만 바뀜)

**#122 결과 — 병합** ([PR #121](https://github.com/jeongmo-dot/gravity_orb/pull/121) `6469966`, 2026-10-31): `Hud`의 미리보기 배율을 `preview_scale_for_width()` = 판 투영 너비 ÷ `board_size`로 고정 (`PREVIEW_REGION_SIZE` 삭제). 간격은 `PREVIEW_GAP` × 배율, 칸 (NEXT·THEN 칸 너비)이 모자라면 `(칸 너비 − 지름 합) ÷ (개수 − 1)`로 줄이고 음수면 같은 양으로 겹친다. `ThenPreview` 0.6배 삭제 (알파 0.5 그대로). 창 크기가 바뀌면 저장해 둔 묶음을 다시 그린다 (새 색 반짝임은 다시 나지 않음). 화면 지름 (캡처 `66`, 멈춘 상태, Codex):

| 화면비 | L1 판 / NEXT / THEN | L2 판 / NEXT / THEN | 차이 |
|---|---|---|---|
| 540×960 | 51.551 / 51.551 / 51.551px | 82.482 / 82.482 / 82.482px | 0% |
| 540×1170 | 51.551 / 51.551 / 51.551px | 82.482 / 82.482 / 82.482px | 0% |

- JELLY 기준 해시 `ce7054b6…` 그대로, 래퍼 306/306, Debug 빌드 (Codex). 새 캡처 `66`~`70` (판과 나란히, NEXT 1·2·5개, THEN L2 5개 겹침)
- Claude 검수 (diff, 캡처 `66`·`70` 직접 확인, 재실행 없음): `66`에서 판 위 노랑 L1·파랑 L2와 NEXT·THEN의 같은 레벨이 같은 크기이고 THEN만 흐리다. `70`에서 THEN의 L2 5개가 줄지 않고 고르게 겹치며 칸 안에 있다. 겹침 순서는 명세 ("앞 젤리가 위")와 달리 뒤 젤리가 위다 — 일정하고 칸 안이라 받아들인다

### 12-ONE.16 공 늘어나는 간격 5턴 → 10턴 (#123)
사용자 (2026-10-31): **"그리고 들어오는 공의 수가 늘어나는 턴 기준도 5턴이 아니라 10턴 단위로 바꿔줘"**

- `spawn_count_ramp_turns` 5 → **10**. `spawn_count_per_turn` 1, `spawn_count_max` 0 (상한 없음)은 그대로다. 턴당 들어오는 공 = 1 + ⌊(턴 − 1) ÷ 10⌋

| 턴 | #119 (5턴마다) | **#123 (10턴마다)** | 그때까지 누적 (#123) |
|---|---|---|---|
| 1~5 | 1 | 1 | 5 |
| 6~10 | 2 | 1 | 10 |
| 11~20 | 3~4 | 2 | 30 |
| 41~50 | 9~10 | 5 | 150 |
| 71~80 | 15~16 | 8 | 360 |
| 91~100 | 19~20 | 10 | 550 |

- #119는 턴당 15~18개가 들어오는 72~87턴에 판이 끝났다 (봇 20판 평균 79.6턴). 10턴마다면 같은 턴에 절반쯤 들어오므로 판이 길어진다 — #119 (약 80턴)와 #118 (약 340턴) 사이로 본다. 입구 한 줄의 L1 한계 (19개)는 181턴에 닿는다
- 그대로 두는 것: 시작 배치 (4색 L1), 색 해금 (30·60턴), 크기 (L1 90%·L2 10%), 미리보기, 물리, 규칙·점수, 대폭발 (#120은 이 뒤에 잰다)

**측정**:
1. 자동 플레이 20시드 (#119와 같은 조건): #118 (50턴마다)·#119 (5턴마다)·#123 (10턴마다)을 나란히. 게임 오버 수, 게임 오버까지 턴 (평균·최소·최대), 점수, 턴당 합체, 게임 오버 때 턴당 들어오는 공 수, 들어온 공 총수, FINAL MOVE 횟수·성공, 1.5초 강제 안정 비율, 최대 관통, 판 밖 이탈, 판에 공이 가장 많을 때의 공 수
2. 새 JELLY 기준 해시 (시드 `1085050`이 7가지 사건을 다 지나지 않으면 새 시드). 두 자리 `×n` 캡처 (`65_jelly_preview_double_digit`)는 턴당 10개 이상인 턴 (91턴 이후)으로 옮긴다. 두 비율 전체 캡처 (마지막에)

**#123 결과 — 병합** ([PR #122](https://github.com/jeongmo-dot/gravity_orb/pull/122) `3336886`, 2026-10-31): `spawn_count_ramp_turns` 10. 자동 플레이 20시드 (시드 101~120, 같은 방향 순서·물리·400턴 상한, Codex):

| | #118 (50턴마다) | #119 (5턴마다) | **#123 (10턴마다)** |
|---|---|---|---|
| 게임 오버 | 17/20 | 20/20 | **20/20** |
| 게임 오버까지 턴 (평균 / 최소 / 최대) | 337 / 290 / 394 | 79.6 / 72 / 87 | **111.1 / 99 / 124** |
| 점수 (게임 오버 판 평균) | 456,640 | 604,802 | **374,038** |
| 턴당 합체 | 3.53 | 6.59 | **4.85** |
| 게임 오버 턴의 턴당 생성 수 (평균 / 최소 / 최대) | 7.3 / 6 / 8 | 16.4 / 15 / 18 | **11.6 / 10 / 13** |
| 한 판에 들어온 공 (평균) | 약 1,392 (계산) | 661 | **668** |
| FINAL MOVE (횟수 / 성공) | 20 / 3 (15%) | 21 / 1 (4.8%) | **22 / 2 (9.1%)** |
| 1.5초 강제 안정 | 98.4% | 96.2% | 96.5% |
| 최대 관통 (턴 끝) | 38.3px | 25.4px | 20.4px |
| 판 밖 이탈 | 0 | 0 | 0 |
| 판에 공이 가장 많을 때 (시드 평균 / 최대) | 102 / 126개 | 118 / 133개 | 110 / 130개 |

- 판 길이 약 80 → 111턴 (+40%). 판이 끝나는 때는 턴당 10~13개가 들어오는 99~124턴이다. 한 판에 들어오는 공 수는 #119와 거의 같다 (661 → 668) — 판이 감당하는 총량은 비슷하고, 천천히 늘어나는 만큼 오래 간다
- 점수는 세 규칙 중 가장 낮다 (37.4만). 턴당 합체가 6.59 → 4.85로 줄어 콤보 배수가 덜 붙는다. #119는 한 턴에 많이 들어와 합체가 몰렸다
- JELLY 기준 해시 `ce7054b6…` 그대로 — 회귀 장면 (`test_jelly_regression`)은 판을 비우고 젤리를 직접 놓아 7가지 사건을 만들므로 생성 램프와 무관하다 (Claude 코드 확인). CLASSIC 단계 진행 해시는 `d0e0a894…`로 바뀜 (레거시). 래퍼 306/306, Debug 빌드 (Codex)
- 캡처 `65_jelly_preview_double_digit`은 91턴 (턴당 10개, `×10`)으로 옮겼다 (Codex 두 비율 확인)
- Claude 검수 (diff·회신, 재실행 없음): 값 한 줄과 테스트 경계값 (1·10·11·20·21·50·51·100·101턴 → 1/1/2/2/3/5/6/10/11), 캡처 턴만 바뀌었다

### 12-ONE.17 같은 방향으로는 밀 수 없게 (#124)
사용자 (2026-10-31): **"그리고 방향 입력 할 때 이전에 입력한 방향을 그대로 유지는 못하게 막아줘."**

- 지금: `allow_same_direction_swipe` true (§11.1 "기본 허용"). 지금 중력과 같은 방향으로 밀면 중력은 그대로이고 새 공만 들어오며 턴이 넘어간다
- **바꿀 것**:
  1. `allow_same_direction_swipe` true → **false**. 이미 있는 판정 (`TurnManager.on_swipe()` — 지금 중력과 같은 방향이면 잠그지 않고 무시)을 쓴다. 턴은 넘어가지 않고 다른 방향 입력을 기다린다
  2. 비교 기준은 **지금 중력 방향**이다. 첫 턴은 시작 중력이 아래라 아래로 밀 수 없다 (Claude 결정 — 시작 배치가 이미 바닥에 놓여 있다). FINAL MOVE의 한 번도 같은 규칙이다
  3. 입력 안내 (`TurnInputIndicator`): 입력을 기다리는 동안 **지금 중력 방향의 화살표와 막힘 표시는 그리지 않는다** — 고를 수 있는 세 방향만 보인다 (Claude 결정). 같은 방향으로 밀었을 때 새 소리·연출은 넣지 않는다 (무시만)
  4. 막힘 경고 계산 (`blocked_spawn_directions()`·`warning_changed`)은 그대로 네 방향을 계산한다 (표시만 3번처럼)
  5. 봇·측정: 자동 플레이 방향 순서 (`tests/spike/run_jolt_3d_measurement.gd` `DIRECTION_PATTERN` 아래·오른·위·왼·아래·왼·위·오른)는 첫 수 "아래"가 시작 중력과 같아 막힌다 → 차례의 방향이 지금 중력과 같으면 순서의 다음 방향을 쓴다 (모든 판 같은 규칙). R·G·L 전략 봇은 지금 방향을 후보에서 뺀다
- 영향: 매 턴 중력을 바꿔야 하므로 같은 쪽으로 계속 쌓는 수가 없어진다. 판 길이·합체가 달라질 수 있다 → 측정
- 그대로 두는 것: 스와이프 판정 (4방향·거리·우세 비율), 반대 방향 곧장·90° 대각선 (#118), 생성·규칙·점수·물리, 그림·연출

**측정**:
1. 자동 플레이 20시드 (위 5번 순서 규칙): #123 결과와 나란히 (§12-ONE.16 측정 1과 같은 항목)
2. 새 JELLY 기준 해시 (회귀 경로에 같은 방향 입력이 있으면 바꾸고 7가지 사건을 다시 지나는지 확인). 캡처: 입력 대기 화면 (지금 중력 방향 화살표 없음) 두 비율, 두 비율 전체 캡처 (마지막에)

**#124 결과 — 병합** ([PR #123](https://github.com/jeongmo-dot/gravity_orb/pull/123) `99240c2`, 2026-10-31): `allow_same_direction_swipe` false. 판정은 기존 `TurnManager.on_swipe()` 그대로 (지금 중력과 같으면 잠그지 않고 무시 — 턴·중력·생성·미리보기·신호 그대로). `TurnInputIndicator.is_direction_selectable()`로 입력 대기 중 지금 방향 화살표·막힘 표시를 그리지 않는다 (처리 중 화면은 그대로). `InputRouter.swipe`는 `TurnManager`만 받으므로 무시된 입력에는 소리·연출이 없다 (Claude 확인). 봇: 순서 봇은 차례 방향부터 순서를 훑어 첫 다른 방향, 전략 봇 (R·G·L)은 세 방향만 후보. 자동 플레이 20시드 (시드 101~120, 400턴 상한, Codex):

| | #123 (같은 방향 허용) | **#124 (막힘)** |
|---|---|---|
| 게임 오버 | 20/20 | **20/20** |
| 게임 오버까지 턴 (평균 / 최소 / 최대) | 111.1 / 99 / 124 | **112.8 / 102 / 129** |
| 점수 (게임 오버 판 평균) | 374,038 | **414,217** |
| 턴당 합체 | 4.85 | **4.90** |
| 게임 오버 턴의 턴당 생성 수 | 11.6 | 11.7 |
| FINAL MOVE (횟수 / 성공) | 22 / 2 (9.1%) | 22 / 2 (9.1%) |
| 1.5초 강제 안정 | 96.5% | 97.3% |
| 최대 관통 (턴 끝) | 20.4px | 31.6px |
| 판 밖 이탈 | 0 | 0 |
| 판에 공이 가장 많을 때 (시드 평균 / 최대) | 110 / 130개 | 114 / 128개 |

- 봇 기준으로는 거의 같다 (판 +1.7턴, 점수 +11%). 순서 봇은 원래 같은 방향을 거의 두지 않았다 (방향 순서가 모두 90° 꺾기, 첫 수만 시작 중력과 같음). 사람의 "같은 방향으로 버티기"가 막히는 효과는 봇 수치에 드러나지 않는다 — 수동 확인으로 본다. 같은 방향 입력 수는 순서 봇 20판·전략 봇 표본 모두 0
- 최대 관통 20.4 → 31.6px은 #118 (38.3px) 범위 안이라 그대로 둔다
- 새 JELLY 기준 해시 `935908ce…` (해시 입력에 `allow_same_direction_swipe`를 넣음, 7가지 사건 그대로, 그림 켠·끈 같음). 과거 궤적을 비교하는 Jolt 장기 테스트 둘은 테스트 안에서만 허용 (true)으로 두고 되돌린다. 래퍼 308/308, Debug 빌드 (Codex)
- Claude 검수 (diff, 캡처 `31_turn_input_ready` 직접 확인, 재실행 없음): 중력 오른쪽에서 오른쪽 화살표가 없고 위·왼쪽과 막힌 아래 (빨간 X)만 보인다

### 12-ONE.3 다음 (JELLY 개선)
- CLASSIC 전용 분기 정리 (행성 그림·연출·규칙 — JELLY가 안 쓰는 것)
- 결정 대기에서 이어지는 것: 효과음 (합성·녹음), 시작 화면 그림 (지금 행성 — JELLY에 맞게?)
- 사용자 플레이 소감에 따라

## 13. 알려진 함정 (Godot 4)

| 함정 | 대응 |
|---|---|
| `Orb.tscn`의 `CircleShape2D`가 인스턴스 간 공유되어 반지름을 바꾸면 모든 구체가 같이 변함 | `setup()`에서 `CircleShape2D.new()` |
| `FontVariation.variation_opentype`에 문자열 키 `"wght"`를 넣으면 (4.8-dev3, `.tres`·코드 모두) 굵기가 적용되지 않고 기본 인스턴스로 그려진다 (#66) | 키를 `TextServerManager.get_primary_interface().name_to_tag("wght")` 정수(2003265652)로. 적용 여부는 글리프 윤곽 비교로 검사 |
| `window/stretch/aspect="expand"`에서 `Camera3D` 기본 `keep_aspect`(세로 기준)는 세로로 긴 화면에서 3D 장면을 키워 좌우를 자른다 (#66) | 9:16보다 긴 화면은 `KEEP_WIDTH` + 9:16 환산 가로 화각 (`Main.configure_camera_for_viewport`). 배치 검사는 실제 카메라 투영으로 |
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
