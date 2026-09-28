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

### [2026-09-28] 대상 #3 — M2 입력 추상화
- 상태: 완료
- 브랜치 / PR: `m2-input-abstraction` / PR 생성 후 링크 반영 예정
- 변경 파일: `project.godot`, `config/GameConfig.gd`, `config/default_config.tres`, `scripts/autoload/InputRouter.gd`, `scripts/core/SwipeDetector.gd`, `scripts/core/Main.gd`, `tests/test_config.gd`, `tests/test_input_router.gd`, `tests/test_swipe.gd`, Godot 생성 `.gd.uid` 4개
- Done-when 대조:
  - [x] 방향키·WASD와 마우스 드래그가 같은 `swipe(Vector2i)` 신호로 들어가고 `Main`이 `Board.set_gravity`에 연결 — `test_arrow_and_wasd_bindings_map_to_four_directions`, `test_mouse_left_drag_emits_once`, 메인 씬 스모크 자동 검증
  - [x] 마우스·터치 에뮬레이션 이중 이벤트가 드래그 1회당 신호 1회 — `test_emulated_touch_duplicate_emits_once` 자동 검증
  - [x] 짧은 이동·애매한 대각선 무시, 최소 거리·우세 비율 경계 포함 — `test_swipe.gd`와 `test_short_drag_is_ignored` 자동 검증
  - [x] 터치 index 0만 허용, 마우스 좌클릭만 허용, source 소유권 유지 — `test_input_router.gd` 자동 검증
  - [x] 잠금 중 입력과 잠금 중 시작한 뒤 해제된 제스처 무시 — `test_locked_drag_is_ignored`, `test_drag_started_locked_stays_ignored_after_unlock`, `test_locked_keyboard_action_is_ignored` 자동 검증
  - [x] 키 에코 제외 — `test_keyboard_action_emits_once_and_echo_is_ignored` 자동 검증
  - [x] 입력 격리 — `rg -n "Input\\.|InputEvent" scripts -g "*.gd"` 결과 9줄 모두 `scripts/autoload/InputRouter.gd`, 그 외 0건
  - [x] Input Map에는 `gravity_up/down/left/right` 4개만 등록 — 정적 검사, `restart`·`debug_*` 0개
  - [x] §10.1 명령 3종 종료 코드 0 — 자동 검증 완료
  - [ ] 실제 창에서 키보드·마우스 조작 체감과 에뮬레이션 설정 확인 — 미실행, 아래 수동 확인 절차 필요
- QA 관측값:
  - 실행 환경: `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe`, 버전 `4.8.dev3.mono.official.51105ccbe`
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - `godot --headless --fixed-fps 240 --path . -s res://tests/run_tests.gd` → 18/18 통과, 실패 0건, 종료 코드 0
  - 입력 테스트 세부 → `test_swipe.gd` 3/3, `test_input_router.gd` 11/11, `test_config.gd` M2 기본값 포함 3/3 통과
  - 기존 물리 회귀 → 22시드 이탈 0건, 최대 관통 `8.623px`, 시나리오 1/1 통과
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - 정적 검사 → 물리 `240 tick/s`, `contact_max_allowed_penetration=0.1` 유지; `emulate_touch_from_mouse` 항목 없음(기본값 false 유지)
- 수동 확인 절차:
  1. `& 'C:\work\Godot\Godot_v4.8-dev3_mono_win64.exe' --path .` 실행 후 ↑·↓·←·→와 W·S·A·D를 각각 누름 → 매 키마다 모든 구체가 대응하는 벽 쪽으로 가속하는지 확인한다.
  2. 보드 안팎에서 80px보다 긴 드래그를 상·하·좌·우로 각각 수행 → 우세 축 방향으로 중력이 바뀌는지 확인한다.
  3. 에디터에서 `Input Devices > Pointing > Emulate Touch From Mouse`를 임시로 켜고 마우스 드래그 1회 수행 → 중력 전환이 중복 없이 1회만 일어나는지 확인한 뒤 설정을 false로 되돌린다.
  4. 이동 30px의 짧은 클릭·드래그와 1:1 대각선 드래그를 수행 → 중력이 바뀌지 않는지 확인한다.
- 결정 사항: WASD는 키보드 배열과 무관하게 같은 물리 위치를 쓰도록 physical key로, 방향키는 logical key로 Input Map에 등록했다. 에뮬레이션 중 먼저 들어온 MOUSE/TOUCH source가 제스처를 소유하고 해당 source의 뗌만 종료 처리한다.
- 남은 것 · 질문: 실제 창 수동 QA는 미실행이다. 공개 API·수치 변경과 알려진 문제는 없다.

---

## 확인됨

### [2026-09-28] 대상 #2 — 추가 요구 2: 시나리오 시간 보정과 접촉 설정
- 상태: 완료
- 브랜치 / PR: `m1-board-physics` / [PR #2](https://github.com/jeongmo-dot/gravity_orb/pull/2)
- 변경 파일: `project.godot`, `tests/scenarios/test_board_physics.gd`
- Done-when 대조:
  - [x] 22시드 × 방향당 2.0초 × 4바퀴에서 중심 이탈 0건 — 방향당 `Engine.physics_ticks_per_second × 2.0 = 480`프레임 자동 계산
  - [x] 전체 최대 관통 깊이 10px 이하 — `8.623px`
  - [x] `run_tests.gd` 3회 종료 코드 0 — 매회 3/3 통과
  - [x] §10.1 `--import`, `--quit-after 300` — 각 종료 코드 0, 오류 0건
- 변경 관측:
  - `physics/2d/solver/contact_max_allowed_penetration = 0.1` 추가, 물리 tick은 240 유지
  - 고정 `120`프레임을 제거하고 방향당 `2.0` 시뮬레이션 초에서 프레임 수를 계산하도록 변경
  - Claude 스크래치 측정의 접촉 설정 적용값 `8.623px`과 전체 최대 관통 관측값이 일치
- 시드별 QA (`departures / max_penetration px / max_speed px/s`):

| 시드 | 조건 | 이탈 | 최대 관통 | 최대 속도 |
|---:|---|---:|---:|---:|
| 1000 | 표준 | 0 | 8.623 | 1935.013 |
| 1001 | 표준 | 0 | 5.431 | 1809.424 |
| 1002 | 표준 | 0 | 6.312 | 1841.898 |
| 1003 | 표준 | 0 | 8.413 | 1804.026 |
| 1004 | 표준 | 0 | 7.362 | 1906.831 |
| 1005 | 표준 | 0 | 5.604 | 1669.325 |
| 1006 | 표준 | 0 | 8.131 | 1897.450 |
| 1007 | 표준 | 0 | 6.490 | 1901.420 |
| 1008 | 표준 | 0 | 7.571 | 1831.612 |
| 1009 | 표준 | 0 | 7.245 | 1895.938 |
| 1010 | 표준 | 0 | 6.919 | 1817.490 |
| 1011 | 표준 | 0 | 5.842 | 1935.529 |
| 1012 | 표준 | 0 | 6.801 | 1740.802 |
| 1013 | 표준 | 0 | 5.000 | 1808.997 |
| 1014 | 표준 | 0 | 5.383 | 1856.695 |
| 1015 | 표준 | 0 | 6.615 | 1722.892 |
| 1016 | 표준 | 0 | 8.136 | 1800.498 |
| 1017 | 표준 | 0 | 6.309 | 1824.417 |
| 1018 | 표준 | 0 | 6.994 | 1924.697 |
| 1019 | 표준 | 0 | 4.352 | 1739.993 |
| 1047 | 재현 회귀 | 0 | 6.496 | 1706.570 |
| 2000 | 최악 조건 | 0 | 5.758 | 1908.344 |

- 3회 실행 결과 (`--fixed-fps 240`):

| 실행 | 종료 코드 | 테스트 | 이탈 | 최대 관통 | 최대 속도 |
|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 3/3 | 0 | 8.623 | 1935.529 |
| 2 | 0 | 3/3 | 0 | 8.623 | 1935.529 |
| 3 | 0 | 3/3 | 0 | 8.623 | 1935.529 |

- §10.1 QA 관측값:
  - 실행 환경: `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe`, 버전 `4.8.dev3.mono.official.51105ccbe`
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - `godot --headless --fixed-fps 240 --path . -s res://tests/run_tests.gd` → 3회 모두 3/3 통과, 종료 코드 0
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
- 결정 사항: 없음. 인박스와 갱신된 §1.1·§10.3 설정 및 시간 기반 시나리오 규약을 그대로 적용했다.
- 남은 것 · 질문: 240Hz 물리 비용은 기존 회신과 동일하게 M10 실기기 성능 QA에서 재평가가 필요하다.

---

### [2026-09-28] 대상 #2 — 추가 요구 1: 간헐적 보드 이탈 회귀
- 상태: 완료
- 브랜치 / PR: `m1-board-physics` / [PR #2](https://github.com/jeongmo-dot/gravity_orb/pull/2)
- 변경 파일: `project.godot`, `tests/scenarios/test_board_physics.gd`
- Done-when 대조:
  - [x] 시드 1000~1019 + 최악 조건 2000에서 중심 이탈 0건 — 자동 검증 완료. 재현 시드 1047도 상시 회귀에 추가해 0건
  - [x] 전체 최대 관통 깊이 10px 이하 — 최종 22개 시드 최대 `7.437px`
  - [x] `run_tests.gd` 연속 10회 종료 코드 0 — 10/10회, 매회 3/3 테스트 통과
- 원인 진단과 수정 전·후 관측:
  - 수정 전 60Hz 확장 시드 1000~1099 + 최악 조건 2000 → 시드 1047에서 중심 이탈 1건. 프레임 750, 2바퀴째 UP, 구체 인덱스 4, 레벨 1, 위치 `(483.1807, -327.0191)`, 속도 `(618.4645, 152.0858)`. 전체 최대 관통 `53.181px`, 최대 속도 `1971.830px/s`
  - 120Hz → 중심 이탈 0건, 최대 관통 `25.671px`, 최대 속도 `1960.477px/s`. 10px 기준 미충족
  - 60Hz + `physics/2d/solver/solver_iterations=32` → 중심 이탈 2건, 최대 관통 `65.268px`, 최대 속도 `1980.131px/s`. 개선되지 않아 설정 폐기
  - 240Hz → 확장 시드 101개에서 중심 이탈 0건, 최대 관통 `8.584px`, 최대 속도 `1863.250px/s`
  - 원인 관측: 60Hz에서 최대 관통이 고속 구체의 한 물리 tick 이동 거리와 같은 수십 px 규모였고, 120Hz에서 대략 절반으로 감소했다. solver 반복 증가는 효과가 없어 고속 이동 대비 시간 해상도 부족으로 판단했다
  - 최종 수정: `physics/common/physics_ticks_per_second = 240`. §4 M1 밸런스 필드는 변경하지 않음
- 최종 시드별 QA (`departures / max_penetration px / max_speed px/s`):

| 시드 | 조건 | 이탈 | 최대 관통 | 최대 속도 |
|---:|---|---:|---:|---:|
| 1000 | 표준 | 0 | 3.698 | 1567.354 |
| 1001 | 표준 | 0 | 4.221 | 1655.039 |
| 1002 | 표준 | 0 | 6.986 | 1705.035 |
| 1003 | 표준 | 0 | 4.567 | 1583.733 |
| 1004 | 표준 | 0 | 4.913 | 1554.586 |
| 1005 | 표준 | 0 | 4.609 | 1681.710 |
| 1006 | 표준 | 0 | 5.158 | 1524.380 |
| 1007 | 표준 | 0 | 4.940 | 1634.037 |
| 1008 | 표준 | 0 | 5.018 | 1537.155 |
| 1009 | 표준 | 0 | 5.107 | 1625.996 |
| 1010 | 표준 | 0 | 4.842 | 1703.033 |
| 1011 | 표준 | 0 | 4.632 | 1698.437 |
| 1012 | 표준 | 0 | 5.193 | 1764.002 |
| 1013 | 표준 | 0 | 4.628 | 1802.668 |
| 1014 | 표준 | 0 | 4.388 | 1694.076 |
| 1015 | 표준 | 0 | 4.784 | 1670.913 |
| 1016 | 표준 | 0 | 5.002 | 1610.739 |
| 1017 | 표준 | 0 | 5.479 | 1565.884 |
| 1018 | 표준 | 0 | 5.291 | 1624.887 |
| 1019 | 표준 | 0 | 4.087 | 1629.189 |
| 1047 | 재현 회귀 | 0 | 4.469 | 1543.579 |
| 2000 | 최악 조건 | 0 | 7.437 | 1583.773 |

- 연속 10회 QA (`--fixed-fps 240`으로 240Hz 물리 delta는 유지하고 실시간 동기화만 해제):

| 실행 | 종료 코드 | 테스트 | 이탈 | 최대 관통 | 최대 속도 |
|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 3/3 | 0 | 7.437 | 1802.668 |
| 2 | 0 | 3/3 | 0 | 7.437 | 1802.668 |
| 3 | 0 | 3/3 | 0 | 7.437 | 1802.668 |
| 4 | 0 | 3/3 | 0 | 7.437 | 1802.668 |
| 5 | 0 | 3/3 | 0 | 7.437 | 1802.668 |
| 6 | 0 | 3/3 | 0 | 7.437 | 1802.668 |
| 7 | 0 | 3/3 | 0 | 7.437 | 1802.668 |
| 8 | 0 | 3/3 | 0 | 7.437 | 1802.668 |
| 9 | 0 | 3/3 | 0 | 7.437 | 1802.668 |
| 10 | 0 | 3/3 | 0 | 7.437 | 1802.668 |

- §10.1 QA 관측값:
  - 실행 환경: `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe`, 버전 `4.8.dev3.mono.official.51105ccbe`
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - `godot --headless --path . -s res://tests/run_tests.gd` → 실시간 동기화 원문 명령으로 3/3 통과, 종료 코드 0
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
- 결정 사항: 진단 확장 시드 1000~1099는 수정 전·후 한 번씩 전수 실행했다. 상시 회귀는 요구된 1000~1019, 발견된 재현 시드 1047, 최악 조건 2000의 22개로 유지한다.
- 남은 것 · 질문: 240Hz는 기존 60Hz보다 물리 step 비용이 최대 4배이므로 M10 실기기 성능 QA에서 재평가가 필요하다.

---

### [2026-09-28] 대상 #2 — M1 보드와 구체 물리
- 상태: 완료
- 브랜치 / PR: `m1-board-physics` / PR 없음
- 변경 파일: `project.godot`, `config/GameConfig.gd`, `config/default_config.tres`, `scenes/Main.tscn`, `scenes/Board.tscn`, `scenes/Orb.tscn`, `scripts/core/Main.gd`, `scripts/core/Board.gd`, `scripts/core/Orb.gd`, `scripts/core/OrbTypes.gd`, `scripts/core/OrbVisual.gd`, `tests/test_config.gd`, `tests/scenarios/test_board_physics.gd`, Godot 생성 `.gd.uid` 6개
- Done-when 대조:
  - [ ] 방향키 4개로 중력이 바뀌고 모든 구체가 해당 벽으로 이동 — `Board.set_gravity()` 4방향 자동 시나리오 통과, 키 입력 연결은 수동 확인 필요
  - [x] 구체가 벽을 뚫거나 보드 밖으로 나가지 않음 — 자동 시나리오 1,920프레임에서 중심 이탈 0건
  - [ ] 레벨별 구체 크기가 눈에 띄게 다름 — 반지름 수치 자동 검증 완료, 시각적 차이는 수동 확인 필요
  - [x] `test_config.gd` 반지름 1~7과 레벨 2 질량 — 자동 테스트 2건 통과, 오차 허용치 `1e-3`
  - [x] §10.1 명령 3종 — 종료 코드 0, 테스트 3/3 통과
- QA 관측값:
  - 실행 환경: `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe`, 버전 `4.8.dev3.mono.official.51105ccbe`
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - `godot --headless --path . -s res://tests/run_tests.gd` → 3/3 통과, 실패 0건, 종료 코드 0
  - 물리 시나리오 → 초기 벽·구체 겹침 0건, DOWN→RIGHT→UP→LEFT 각 120프레임 × 4바퀴(총 1,920프레임), 보드 밖 중심 이탈 0건, 최대 속도 `1777.007 px/s`
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - 정적 점검 → M5 `contact_monitor`·`max_contacts_reported`·`generation`·`consumed` 0건, 임시 입력 참조는 `Main.gd` 3건, 임시 RNG 참조는 `Main.gd` 3건
- 수동 확인 절차:
  1. `& 'C:\work\Godot\Godot_v4.8-dev3_mono_win64.exe' --path .` 실행 → 흰 보드 테두리 안에 3색 구체 5개가 표시되고 레벨 1~4의 지름 차이가 눈에 띄는지 확인한다.
  2. ↑ → ↓ → ← → → 방향키를 차례로 누름 → 매번 모든 구체가 해당 방향 벽으로 가속하고 벽 안쪽에서 멈추거나 튕기는지 확인한다.
  3. 각 방향으로 충분히 굴린 뒤 보드 모서리와 벽을 관찰 → 구체가 흰 테두리 밖으로 완전히 빠져나가지 않는지 확인한다.
- 결정 사항: 명세에 수치가 없던 보드 테두리 두께는 연출 상수 `4.0px`로 두었다. 임시 구체는 보드를 셀로 나눈 뒤 각 셀의 반지름 안전 영역 안에서 RNG 오프셋을 뽑아 초기 겹침을 방지한다. 인박스 지시에 따라 M5의 `generation` 인자·필드와 접촉 신호는 추가하지 않았다. 작업 전 에디터가 다시 쓴 `project.godot` 변경은 되돌리지 않고 포함했다.
- 남은 것 · 질문: 방향키 입력과 시각적 크기 차이 수동 QA가 필요하다. 자동 검증은 4.8-dev3 Mono에서 수행했다.

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
