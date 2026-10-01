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

### [2026-10-01] 대상 #15 추가 요구 2 — B2 기본값 채택
- 상태: 완료
- 브랜치 / PR: `m7-four-color-multi-spawn` / PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `tests/test_config.gd`, `tests/test_rules.gd`, `tests/scenarios/test_spawn_flow.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] 코드 선언·기본 리소스를 B2(`spawn_count_per_turn=2`, 4색 동일 가중치, `opposite_pairs=[R↔B]`, `spawn_count_ramp_turns=0`)로 변경 — config·규칙 자동 검증
  - [x] 측정 모드 `--spawn-suite`·`--spawn-case`와 램프 구현 유지
  - [x] 단일 생성을 검증하는 미리보기·중앙 겹침 시나리오는 `spawn_count_per_turn=1`을 명시하고, 턴 흐름·20턴 회귀는 새 기본값 2를 사용하도록 기대값 갱신
  - [x] 전체 98/98 및 §10.1 명령 3종 통과
  - [x] 회귀 기준: 22시드·겹침·20턴·120턴에서 이탈·발산·안전장치·사전 복구 0, 관통 한도 이내
- QA 관측값:
  - 22시드 → 이탈 0, 발산 0, 최대 관통 `7.925px`, 안전장치 0, 사전 복구 0, 유령 timeout 0
  - 중앙 겹침 0.5초 → 이탈 0, 발산 0, 최대 관통 `0.000px`, 안전장치 0, 사전 복구 0
  - 시드 4242 × 20턴(턴당 2개, 최종 구체 42개) → 이탈 0, 발산 0, 최대 관통 `7.397px`, 안전장치 0, 사전 복구 0, 유령 timeout 5, timeout 보정 44
  - 120턴(시드 101~106 × 20턴) → 점유율 평균/최대 `4.8536% / 10.5504%`, 턴 종료 구체 수 평균/최대 `7.525 / 13`, 최종 구체 평균 `10.167`, 최대 레벨 `[4,4,4,4,4,5]`
  - 120턴 물리 → 이탈 0, 발산 0, 최대 관통 `9.973px`, 안전장치 0, 사전 복구 0, 유령 timeout 13, timeout 보정 65
  - 120턴 시간 → p50/p90/max `1.504167 / 1.504167 / 1.504167s`, 상한 도달 `119/120` (`99.1667%`)
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --import` → 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . -s res://tests/run_tests.gd` → 98/98 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --quit-after 300` → 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - 정적 검사 → `Input`/`InputEvent` 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만; `git diff --check` 이상 없음
  - 환경 진단 → 사용자 로그·Windows 루트 인증서·에디터 설정 접근 오류가 출력됐으나 프로젝트 스크립트 로드 및 검증 종료 코드에는 영향 없음
- 수동 확인 절차:
  1. 게임을 시작하고 NEXT를 본다 → 4색 중 두 구체가 나란히 표시된다.
  2. 스와이프한다 → 미리 본 두 구체가 같은 물리 프레임에 생성되고 NEXT가 다시 두 개로 갱신된다.
  3. 같은 레벨의 초록·노랑을 충돌시킨다 → 소멸하지 않는다. 같은 레벨의 빨강·파랑은 규칙 B에 따라 소멸한다.
- 결정 사항: 없음. 기획서 0.6 및 추가 요구 2의 지정값을 그대로 반영했다. 램프·측정 경로는 삭제하지 않았다.
- 남은 것 · 질문: 없음

### [2026-10-01] 대상 #15 추가 요구 1 — 노랑 상극 없음·점진 생성 180턴 측정
- 상태: 질문
- 브랜치 / PR: `m7-four-color-multi-spawn` / PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `scripts/core/Main.gd`, `scripts/core/Spawner.gd`, `scripts/core/TurnManager.gd`, `scripts/ui/DebugHud.gd`, `tests/run_tests.gd`, `tests/scenarios/test_turn_time.gd`, `tests/test_config.gd`, `tests/test_spawner.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] `spawn_count_ramp_turns`(기본 0)·`spawn_count_max`(기본 3) 및 `spawn_count_for_turn(turn_index)` 구현. 램프 활성 시 명세 공식을 사용하고 비활성 시 기존 고정 생성 수 유지
  - [x] NEXT가 다음 턴 기준 크기로 미리 추출됨 — 현재 턴 생성 뒤 `turn_index + 1`로 다음 묶음 생성, F3도 다음 턴 기준으로 동기화
  - [x] 턴 1·40·41·81·121 생성 수 `1·1·2·3·3` — GameConfig와 Spawner 경계 단위 테스트 통과
  - [x] A3/B1/B2/B3/CA/CB 6조합을 각각 독립 프로세스, `--fixed-fps 240`, 시드 101~106×최대 180턴으로 측정. 70% 초과 시 해당 시드 즉시 중단
  - [x] 체크포인트 30·60·90·120·150·180, 30%·50%·70% 최초 턴과 점유율·구체·점수·연쇄·레벨·물리 안전·턴 시간 출력
  - [x] 기본값 `생성 1 / 4색 / R↔B·G↔Y / 램프 비활성` 유지, 전체 98/98와 §10.1 명령 3종 통과
  - [ ] 최종 생성·색·상극·점진 증가 조합 — 아래 결과에 물리 발산 및 복구 다발 후보가 있어 Claude·사용자 결정 필요
- QA 관측값: 점유율은 각 턴 종료 직후 최종 레벨 반지름의 `Σ(πr²) / board_size²`이다. 체크포인트 값은 그 턴까지 진행된 시드의 평균이며, 포화 중단으로 표본 수가 6보다 적으면 괄호에 표본 수를 적었다. 이탈·발산은 orb-frame 횟수다.

| ID | 생성 / 색 / 상극 | 완료 턴 합계 | 점유율 평균 / 최대 | 점유율 30 / 60 / 90 / 120 / 150 / 180턴 | 구체 수 평균 / 최대 | 턴 p50 / cap 비율 |
|---|---|---:|---:|---:|---:|---:|
| A3 | 3 고정 / 3색 / R↔B | 1080 | 20.2923% / 48.2267% | 13.1937 / 19.6662 / 26.8475 / 29.4283 / 20.3537 / 22.7668% | 12.205 / 27 | 1.504167s / 100.0000% |
| B1 | 1 고정 / 4색 / R↔B | 1080 | 16.0404% / 31.4892% | 6.6700 / 12.0247 / 16.3795 / 20.8295 / 24.7255 / 29.4652% | 10.797 / 21 | 1.504167s / 100.0000% |
| B2 | 2 고정 / 4색 / R↔B | 1080 | 30.0547% / 60.7712% | 12.3088 / 22.2512 / 31.7761 / 39.9957 / 45.1090 / 54.6225% | 18.407 / 38 | 1.504167s / 99.8148% |
| B3 | 3 고정 / 4색 / R↔B | 863 | 35.7574% / 70.6824% | 17.2573 / 30.7492 / 44.4386 / 56.1153 / 66.2424% (2) / — (0) | 24.032 / 58 | 1.504167s / 99.5365% |
| CA | 1→2→3 / 3색 / R↔B | 1080 | 17.4099% / 44.0849% | 5.3775 / 10.5759 / 18.1223 / 23.7611 / 30.6683 / 26.7609% | 10.626 / 24 | 1.504167s / 99.9074% |
| CB | 1→2→3 / 4색 / R↔B | 1058 | 28.4802% / 71.1000% | 6.8120 / 15.6196 / 25.9115 / 41.3266 / 54.0203 / 64.2077% (4) | 19.683 / 55 | 1.504167s / 99.9055% |

| ID | 30% 최초 초과 (시드 101~106) | 50% 최초 초과 | 70% 포화 중단 | 최종 점수 | 최대 연쇄 | 최고 레벨 |
|---|---|---|---|---|---|---|
| A3 | `[87, 66, 81, 130, 104, 88]` | 전부 — | 전부 — | `[5502, 9668, 5610, 4836, 5838, 5994]` | `[4, 7, 4, 4, 5, 3]` | `[7, 7, 7, 7, 7, 7]` |
| B1 | `[175, 178, 173, 176, —, 177]` | 전부 — | 전부 — | `[1356, 1438, 1334, 1240, 1280, 1390]` | `[2, 3, 3, 2, 3, 3]` | `[6, 6, 6, 6, 6, 6]` |
| B2 | `[87, 84, 74, 81, 105, 88]` | `[151, 175, 141, 160, —, 168]` | 전부 — | `[3094, 2974, 2988, 2606, 2696, 3178]` | `[3, 3, 4, 3, 4, 4]` | `[7, 7, 7, 7, 7, 7]` |
| B3 | `[59, 56, 56, 54, 69, 54]` | `[90, 124, 85, 102, 113, 118]` | `[122, 159, 139, 134, 160, 149]` | `[2658, 3974, 3454, 2448, 3948, 4566]` | `[3, 3, 3, 3, 4, 5]` | `[6, 7, 7, 6, 7, 7]` |
| CA | `[123, 157, 104, 170, 151, 131]` | 전부 — | 전부 — | `[4818, 2980, 4722, 3062, 2816, 4292]` | `[5, 3, 4, 4, 3, 3]` | `[7, 7, 7, 7, 7, 7]` |
| CB | `[98, 99, 95, 92, 111, 99]` | `[130, 146, 132, 147, 150, 153]` | `[163, 175, —, —, —, —]` | `[2548, 3536, 3362, 3260, 3324, 4692]` | `[4, 5, 3, 3, 4, 5]` | `[6, 7, 7, 7, 7, 7]` |

| ID | 안전장치 | 사전 복구 | 유령 timeout | 이탈 / 발산 | 최대 관통 | timeout 보정 | 최종 구체 평균 |
|---|---:|---:|---:|---:|---:|---:|---:|
| A3 | 28 | 2,186 | 447 | 3 / 3 | `2.3214e34px` | 2,558 | 12.167 |
| B1 | 12 | 373 | 132 | 1 / 1 | `2.8306e35px` | 857 | 14.667 |
| B2 | 4 | 735 | 476 | 0 / 0 | 15.527px | 3,383 | 30.500 |
| B3 | 26 | 1,331 | 750 | 1 / 1 | `6.0342e34px` | 5,193 | 48.333 |
| CA | 0 | 139 | 347 | 0 / 0 | 15.333px | 1,963 | 14.333 |
| CB | 56,386 | 61,707 | 696 | 2 / 96 | `1.6114e35px` | 4,833 | 40.333 |

  - A3/B1/B3/CB의 천문학적 최대 관통은 고밀도 상태에서 실제 좌표 발산이 발생한 관측값이다. 측정 모드는 이를 합격/불합격으로 판정하지 않고 카운터와 함께 끝까지 기록했다.
  - B3는 6시드 모두 122~160턴에 포화 중단됐다. CB는 시드 101·102가 163·175턴에 포화 중단됐고 나머지 4시드는 180턴을 완료했다.
  - A3/B1/B2/CA는 모든 시드가 180턴을 완료했다. 이 중 B2·CA는 이탈·발산 0이지만 각각 안전장치/사전 복구 `4/735`, `0/139`가 관측됐다.
  - 측정 명령: `Godot_v4.8-dev3_mono_win64_console.exe --headless --fixed-fps 240 --path . -s res://tests/run_tests.gd -- --spawn-suite=measurement --spawn-case=<ID>` — 6개 독립 프로세스 각각 1/1 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --import` → 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . -s res://tests/run_tests.gd` → 98/98 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --quit-after 300` → 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - 기본값 전체 회귀 → 22시드 이탈·발산·안전장치·사전 복구 0, 최대 관통 7.925px. 총 120턴 점유율 평균/최대 `2.1684% / 5.7695%`, 구체 수 평균/최대 `3.917 / 8`, 최대 관통 9.621px
  - 정적 검사 → `Input`/`InputEvent` 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만; `git diff --check` 이상 없음
  - 환경 진단 → 사용자 로그/Windows 루트 인증서/에디터 설정 접근 오류가 출력됐으나 프로젝트 스크립트 로드·검증 종료 코드에는 영향 없음
- 수동 확인 절차:
  1. 테스트용으로 `spawn_count_per_turn=1`, `spawn_count_ramp_turns=40`, `spawn_count_max=3`을 설정하고 플레이한다 → 1~40턴 NEXT/생성 수 1, 41~80턴 2, 81턴부터 3인지 확인한다.
  2. 40턴과 80턴 종료 직후 NEXT를 본다 → 각각 다음 턴용 2개·3개 묶음으로 즉시 바뀌며, 다음 스와이프 생성 수·색·레벨과 일치하는지 확인한다.
- 결정 사항: `spawn_count_max`의 비활성 기본값은 기존 F3/NEXT 최대와 측정 C안의 지정 상한에 맞춰 3으로 두었다. `Spawner.try_spawn()`에 현재 `turn_index`를 전달하고, 초기 NEXT는 1턴·생성 후 NEXT는 `turn_index + 1` 기준으로 추출한다. 180턴 측정은 `--spawn-case=A3|B1|B2|B3|CA|CB`로 조합을 고정하며 모든 추가 측정 조합의 상극은 R↔B만으로 덮어쓴다. 스크린샷은 dummy renderer를 사용하는 headless 독립 측정이라 생성하지 못했다.
- 남은 것 · 질문: 어떤 조합을 기본값으로 채택할지 지정해 달라. A3/B1/B3/CB는 좌표 발산이 관측됐고 B3는 전 시드, CB는 2시드가 70% 포화됐다. B2는 발산 0이나 안전장치 4·사전 복구 735회, CA는 발산·안전장치 0이나 사전 복구 139회였다. 현재 기본값은 지시대로 `생성 1 / 4색 / R↔B·G↔Y / 램프 0`을 유지한다.

### [2026-10-01] 대상 #15 — 4색(노랑) + 턴당 다중 생성 측정
- 상태: 질문
- 브랜치 / PR: `m7-four-color-multi-spawn` / PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `project.godot`, `scenes/UI.tscn`, `scripts/autoload/InputRouter.gd`, `scripts/core/Main.gd`, `scripts/core/OrbTypes.gd`, `scripts/core/Spawner.gd`, `scripts/ui/DebugHud.gd`, `scripts/ui/Hud.gd`, `tests/run_tests.gd`, `tests/scenarios/test_ghost_scenario.gd`, `tests/scenarios/test_score_flow.gd`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_time.gd`, `tests/test_config.gd`, `tests/test_input_router.gd`, `tests/test_rules.gd`, `tests/test_spawner.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] `YELLOW=#F5C542`, 4색 동일 가중치, `(GREEN, YELLOW)` 상극을 선언·기본 리소스에 추가하고 색 개수 3 고정 가정을 제거 — config·분포·반응 규칙 자동 검증
  - [x] `spawn_count_per_turn`과 묶음 선추출/동일 물리 프레임 생성/다음 묶음 발행 구현 — 2개 생성 프레임·preview 일치 자동 검증
  - [x] 개별 구체마다 level→color→position 순으로 난수를 소비하고, 동일 시드에서 count 2 묶음의 `(level,color,t)` 연속열이 count 1과 동일 — `test_count_two_batch_sequence_matches_continuous_count_one_sequence`
  - [x] `next_batch_changed(Array[Dictionary])`와 묶음형 `peek_next()` 적용. 기존 `next_changed`는 제거 — 전체 참조 전환 및 회귀 통과
  - [x] NEXT를 최대 3개 가로 배치하고 실제 반지름 비율을 유지하며 280×150 영역 초과 시 전체 축소 — 3개 자식·레벨별 원본 반지름 자동 검증
  - [x] F3이 잠금 상태와 무관하게 1→2→3→1을 순환하고 디버그 HUD에 `Spawn: N` 표시 — 입력 자동 검증, 실제 키 조작은 아래 수동 절차
  - [x] 규칙 B에서 초록 L1+노랑 L1 소멸, 노랑 L1+노랑 L1 합체 — 단위 자동 검증
  - [x] 6조합을 각각 별도 프로세스, `--fixed-fps 240`, 시드 101~106×120턴으로 측정 — 각 조합 1/1 통과, 종료 코드 0
  - [x] 기본 4색·턴당 1개에서 전체 96/96와 §10.1 명령 3종 통과
  - [ ] 기본 `spawn_count_per_turn` 최종값 — 아래 측정표를 근거로 Claude 결정 필요. 측정 중 기본값은 지시대로 1, 4색 유지
- QA 관측값: 점유율은 각 턴 `WAITING_INPUT` 복귀 직후 최종 레벨 반지름의 `Σ(πr²) / board_size²`, 체크포인트는 해당 턴의 6시드 평균이다. `—`는 120턴 안에 임계값을 넘지 않았다는 뜻이다.

| 턴당 생성 | 활성 색 | 점유율 평균 / 최대 | 점유율 30 / 60 / 90 / 120턴 | 구체 수 평균 / 최대 | 턴 p50 / cap 비율 | 최대 관통 | 안전 / 사전복구 / 유령 timeout | 이탈 / 발산 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 8.1222% / 16.7033% | 5.1914% / 8.0278% / 11.6810% / 13.6723% | 6.633 / 15 | 1.504167s / 99.8611% | 10.432px | 0 / 0 / 36 | 0 / 0 |
| 1 | 4 | 4.7796% / 10.8231% | 4.2781% / 5.8050% / 6.2055% / 6.4782% | 5.403 / 10 | 1.504167s / 99.8611% | 10.761px | 0 / 0 / 24 | 0 / 0 |
| 2 | 3 | 14.1328% / 30.1001% | 8.7238% / 14.8881% / 18.1919% / 23.6702% | 9.246 / 19 | 1.504167s / 99.8611% | 13.067px | 0 / 2 / 131 | 0 / 0 |
| 2 | 4 | 7.1448% / 14.4365% | 5.9655% / 7.8048% / 9.1812% / 9.6058% | 7.564 / 15 | 1.504167s / 99.8611% | 12.381px | 0 / 0 / 90 | 0 / 0 |
| 3 | 3 | 19.1476% / 42.3634% | 13.0090% / 18.1464% / 25.9328% / 34.3228% | 11.510 / 23 | 1.504167s / 100.0000% | 14.633px | 0 / 0 / 253 | 0 / 0 |
| 3 | 4 | 8.5854% / 18.5697% | 7.1302% / 8.1784% / 12.6397% / 11.5006% | 8.911 / 17 | 1.504167s / 100.0000% | 12.542px | 0 / 7 / 150 | 0 / 0 |

| 턴당 생성 / 색 | 30% 최초 초과 턴 (시드 101~106) | 50% 최초 초과 | 70% 포화 중단 | 최종 점수 (시드 101~106) | 최대 연쇄 | 최고 레벨 |
|---|---|---|---|---|---|---|
| 1 / 3 | `[—, —, —, —, —, —]` | 전부 — | 전부 — | `[880, 788, 950, 780, 688, 884]` | `[2, 3, 4, 3, 3, 3]` | `[6, 6, 6, 6, 6, 6]` |
| 1 / 4 | `[—, —, —, —, —, —]` | 전부 — | 전부 — | `[522, 376, 428, 502, 346, 422]` | `[3, 3, 2, 3, 2, 3]` | `[4, 4, 4, 5, 3, 5]` |
| 2 / 3 | `[—, —, 97, —, —, —]` | 전부 — | 전부 — | `[1880, 1758, 1978, 1884, 1844, 1788]` | `[3, 2, 3, 3, 3, 4]` | `[7, 7, 7, 7, 7, 7]` |
| 2 / 4 | `[—, —, —, —, —, —]` | 전부 — | 전부 — | `[1138, 1066, 1000, 948, 756, 930]` | `[3, 3, 3, 3, 3, 3]` | `[5, 5, 5, 5, 4, 5]` |
| 3 / 3 | `[87, 117, 82, —, 106, 108]` | 전부 — | 전부 — | `[2814, 2728, 2602, 2430, 2566, 3506]` | `[4, 3, 3, 3, 4, 5]` | `[7, 7, 7, 7, 7, 7]` |
| 3 / 4 | `[—, —, —, —, —, —]` | 전부 — | 전부 — | `[1558, 1754, 1370, 1326, 1300, 1524]` | `[3, 3, 3, 3, 4, 3]` | `[6, 5, 5, 5, 5, 5]` |

  - 최종 잔여 구체 평균은 조합 순서대로 `7.000 / 5.667 / 12.333 / 8.333 / 15.167 / 10.167`이다.
  - 타임아웃 시 보정 횟수는 `178 / 105 / 738 / 441 / 1452 / 784`이다. 2개·3색의 사전 복구 2회는 마지막 유령 timeout 뒤 `[1, 2171]` physics frame, 3개·4색의 7회는 `[1, 1, 1, 2, 2, 3, 1]` frame에 관측됐다.
  - 모든 조합이 6시드 각각 120턴을 완료했다. 50%·70% 초과 시드는 없어 포화 중단은 발생하지 않았다.
  - 측정 명령 형식: `Godot_v4.8-dev3_mono_win64_console.exe --headless --fixed-fps 240 --path . -s res://tests/run_tests.gd -- --spawn-suite=measurement --spawn-count=N --active-colors=C` — 6개 독립 프로세스 최종 실행 각각 1/1 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --import` → 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . -s res://tests/run_tests.gd` → 96/96 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --quit-after 300` → 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - 기본 4색·1개 전체 회귀의 총 120턴 → 점유율 평균/최대 `2.1684% / 5.7695%`, 구체 수 평균/최대 `3.917 / 8`, 이탈·발산·안전장치·사전 복구 `0 / 0 / 0 / 0`, 최대 관통 `9.621px`
  - 환경 진단 → 사용자 로그/Windows 루트 인증서/에디터 설정 접근 오류가 출력됐으나 프로젝트 스크립트 로드·검증 종료 코드에는 영향 없음
  - 정적 검사 → `Input`/`InputEvent` 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만; `git diff --check` 이상 없음
- 수동 확인 절차:
  1. 프로젝트를 실행한다 → 노랑 구체가 `#F5C542`로 보이고 NEXT의 색·레벨과 다음 생성 구체가 일치하는지 확인한다.
  2. F3을 반복해서 누른다 → 디버그 HUD가 `Spawn: 1 → 2 → 3 → 1`로 순환하고 NEXT도 같은 개수로 즉시 바뀌는지 확인한다.
  3. `Spawn: 3`에서 NEXT를 본다 → 세 구체가 가로로 표시되고 L1/L2의 상대 크기가 유지되며 NEXT 영역을 벗어나지 않는지 확인한다. 스와이프하면 세 구체가 같은 프레임에 각 미리보기 색·레벨로 생성되는지 확인한다.
  4. 초록 L1과 노랑 L1을 충돌시킨다 → 규칙 B에서 둘 다 사라지는지 확인한다. 노랑 L1 두 개를 충돌시키면 노랑 L2로 합체하는지 확인한다.
- 결정 사항: 기존 단일 `next_changed`는 호환 유지 없이 제거하고 모든 소비자를 `next_batch_changed`로 전환했다. 공개 `peek_next()`/신호에는 `{color, level}`만 노출하고 위치 난수 `t`는 내부 묶음에만 보관한다. F3로 묶음 크기를 늘릴 때 기존 prefix를 유지한 채 뒤에 새 후보를 추출하고, 줄일 때 뒤 후보를 버린다. NEXT 구현 영역은 기존 HUD 배치 안에서 280×150px, 간격 16px로 잡았고 영역 초과 시 구체·간격을 동일 비율로 축소한다. 스크린샷은 headless 검증만 수행해 미생성이다.
- 남은 것 · 질문: 6조합 중 최종 `spawn_count_per_turn` 값을 지정해 달라. 4색에서는 1/2/3개 모두 120턴 최대 점유율이 각각 10.8231% / 14.4365% / 18.5697%였고 30%를 넘지 않았다. 3색·3개만 6시드 중 5개가 30%를 넘었지만 최대 42.3634%로 50%·70%에는 도달하지 않았다. 결정 전 기본값은 4색·1개로 유지한다.

### [2026-10-01] 대상 #14 추가 요구 1 — 질량 지수 1.0 채택 및 안전 기준 갱신
- 상태: 완료
- 브랜치 / PR: `m7-radius-mass-remeasure` / PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `tests/test_config.gd`, `tests/scenarios/test_board_physics.gd`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_time.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] `mass_exponent` 선언·기본 리소스를 1.0으로 변경하고 config 기본값 자동 검증 갱신
  - [x] 관통 한도를 물리 22시드 10px, 20턴·120턴 14px, 겹침 12px로 적용 — fixed·실시간 측정 통과
  - [x] `wall_penetration_limit=16`, `escape_guard_depth=25`와 사전 복구 assert(22시드·겹침·20턴 0, 120턴 ≤2) 유지
  - [x] 120턴 매 턴 종료 시 `Σ(πr²) / board_size²` 점유율과 구체 수를 수집해 각각 평균·최대를 출력 — 보고 전용, assert 없음
  - [x] 기본값 전체 92/92, fixed 측정 11/11, realtime 120턴 1/1 통과
  - [x] §10.1 명령 3종 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - [ ] NEXT 미리보기·HUD 새 크기 육안 확인 — #14의 기존 수동 확인 절차 유지
- QA 관측값:

| 실행 | 최대 관통 | 안전장치 | 사전 복구 | 유령 timeout | 이탈/발산 | 최종 구 평균 | 턴 종료 점유율 평균/최대 | 턴 종료 구체 수 평균/최대 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| fixed 22시드 | 8.182px | 0 | 0 | 0 | 0 / 0 | — | — | — |
| fixed 겹침 | 0.000px | 0 | 0 | 0 | 0 / 0 | — | — | — |
| fixed 20턴 | 6.853px | 0 | 0 | 1 | 0 / 0 | 22.000 | — | — |
| fixed 120턴 | 10.292px | 0 | 0 | 9 | 0 / 0 | 4.833 | 2.0775% / 4.9940% | 3.858 / 8 |
| realtime 120턴 | 11.574px | 0 | 0 | 6 | 0 / 0 | 4.667 | 2.1376% / 5.2070% | 3.942 / 7 |
| 전체 실시간 22시드 | 7.925px | 0 | 0 | 0 | 0 / 0 | — | — | — |
| 전체 실시간 20턴 | 8.444px | 0 | 0 | 1 | 0 / 0 | 22.000 | — | — |
| 전체 실시간 120턴 | 10.086px | 0 | 0 | 7 | 0 / 0 | 5.167 | 2.1696% / 4.9940% | 3.858 / 7 |

  - fixed 120턴 시드 101~106 → 점수 `[60, 70, 60, 62, 68, 54]`, 최대 연쇄 `[2, 1, 2, 2, 2, 1]`, 최고 레벨 `[3, 4, 3, 3, 4, 3]`
  - realtime 120턴 시드 101~106 → 점수 `[56, 86, 46, 62, 76, 74]`, 최대 연쇄 `[2, 2, 1, 2, 2, 2]`, 최고 레벨 `[3, 4, 3, 3, 4, 3]`
  - 전체 실시간 120턴 시드 101~106 → 점수 `[60, 86, 46, 54, 86, 46]`, 최대 연쇄 `[2, 2, 2, 1, 2, 1]`, 최고 레벨 `[3, 4, 3, 3, 4, 3]`
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --fixed-fps 240 --path . -s res://tests/run_tests.gd -- --mass-suite=fixed` → 11/11 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . -s res://tests/run_tests.gd -- --mass-suite=realtime` → 1/1 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --import` → 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . -s res://tests/run_tests.gd` → 92/92 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --quit-after 300` → 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - 환경 진단 → 사용자 로그/Windows 루트 인증서/에디터 설정 접근 오류가 출력됐으나 프로젝트 스크립트 로드·검증 종료 코드에는 영향 없음
  - 정적 검사 → `Input`/`InputEvent` 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만; `git diff --check` 이상 없음
- 수동 확인 절차:
  1. 프로젝트를 실행해 NEXT의 L1/L2 미리보기와 실제 생성 구체를 비교한다 → 미리보기와 실제 크기가 일치하고 25px/40px 차이가 분명한지 확인한다.
  2. 합체로 L1→L2→L3 이상을 만든다 → 레벨별 크기 차이가 보이고 NEXT·SCORE·BEST·MAX CHAIN HUD가 겹치거나 잘리지 않는지 확인한다.
- 결정 사항: 점유율의 `r`은 성장 중 현재 반지름이 아닌 레벨별 최종 반지름으로 계산했고, 분모는 현재 `Config.data.board_size²`를 사용했다(기본 960²와 동일). 점유율·구체 수는 각 턴이 `WAITING_INPUT`으로 돌아온 직후 120개 표본에서 집계한다. 1단계 `--mass-suite` 모드는 유지했다.
- 남은 것 · 질문: 코드·자동 검증 기준 남은 항목 없음. 실제 NEXT/HUD 크기는 위 수동 절차로 확인 필요.

### [2026-10-01] 대상 #14 — 레벨별 반지름 표 + 질량 지수 + 안전 기준 재측정
- 상태: 질문
- 브랜치 / PR: `m7-radius-mass-remeasure` / PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `scripts/core/Board.gd`, `tests/run_tests.gd`, `tests/test_config.gd`, `tests/scenarios/test_annihilation_scenario.gd`, `tests/scenarios/test_board_physics.gd`, `tests/scenarios/test_ghost_scenario.gd`, `tests/scenarios/test_merge_scenario.gd`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_time.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] `level_radii=[25, 40, 60, 85, 115, 150, 190]`, `mass_exponent=2.0` 기본값과 명세 공식을 적용하고 `orb_base_radius`·`orb_radius_growth` 코드/리소스 참조 제거 — config 자동 검증
  - [x] 새 반지름에 맞춰 config 기대값 및 접촉·합체·유령 시나리오 배치를 반지름 함수 기반으로 갱신 — 관련 회귀 자동 검증
  - [x] 물리 22시드의 레벨 1~4 순환과 최악 구성 `L4×4 + L1×4` 유지 — 자동 검증
  - [x] 지수 2/1.5/1 각각 fixed 묶음과 realtime 120턴을 별도 프로세스로 실행하고 요구 지표 출력 — 아래 표
  - [x] 모든 사전 복구 경고·측정 표에 마지막 유령 타임아웃 이후 physics frame 수 추가. 선행 타임아웃이 없으면 `-1` — 자동 검증
  - [ ] 전체 92개 테스트 중 91개 통과. `test_cycle_seeded_orbs_remain_inside_board_during_gravity_cycles`는 기본 지수 2에서 현행 12px/사전 복구 0회 기준 초과 — Claude의 지수·안전 기준 결정 필요
  - [ ] NEXT 미리보기와 HUD 새 크기 육안 확인 — 수동 확인 필요(아래 절차)
- QA 관측값: 아래 fixed 열은 지수마다 `--fixed-fps 240 --mass-suite=fixed` 독립 프로세스, realtime 열은 `--mass-suite=realtime` 독립 프로세스다. `최대 비율`은 관측 프레임의 관통을 해당 구체의 **최종 설정 반지름**으로 나눈 별도 최댓값이다. `이탈`·`발산`은 orb-frame 횟수이며 발산 기준은 속도 `>5000px/s` 또는 중심이 `half+100px` 밖이다.

| 질량 지수 | 시나리오 | 안전장치 | 사전 복구 (마지막 timeout 후 frame) | 유령 timeout | 이탈 | 발산 | 최대 관통(px) | 최대 비율 (레벨) | 120턴 잔여 구 평균 |
|---:|---|---:|---|---:|---:|---:|---:|---:|---:|
| 2.0 | fixed 물리 22시드 | 0 | 0 (`[]`) | 0 | 0 | 0 | 14.823 | 59.290% (L1) | — |
| 2.0 | fixed 겹침 | 0 | 0 (`[]`) | 0 | 0 | 0 | 0.000 | 0% (—) | — |
| 2.0 | fixed 20턴 | 0 | 0 (`[]`) | 1 | 0 | 0 | 6.631 | 26.524% (L1) | — |
| 2.0 | fixed 120턴 | 0 | 0 (`[]`) | 6 | 0 | 0 | 13.135 | 52.538% (L1) | 5.667 |
| 2.0 | realtime 120턴 | 0 | 1 (`[757]`) | 6 | 0 | 0 | 14.091 | 56.365% (L1) | 4.833 |
| 1.5 | fixed 물리 22시드 | 0 | 0 (`[]`) | 0 | 0 | 0 | 12.036 | 48.143% (L1) | — |
| 1.5 | fixed 겹침 | 0 | 0 (`[]`) | 0 | 0 | 0 | 0.000 | 0% (—) | — |
| 1.5 | fixed 20턴 | 0 | 0 (`[]`) | 1 | 0 | 0 | 8.594 | 34.377% (L1) | — |
| 1.5 | fixed 120턴 | 0 | 0 (`[]`) | 4 | 0 | 0 | 10.811 | 43.243% (L1) | 5.333 |
| 1.5 | realtime 120턴 | 0 | 0 (`[]`) | 4 | 0 | 0 | 13.542 | 54.168% (L1) | 5.333 |
| 1.0 | fixed 물리 22시드 | 0 | 0 (`[]`) | 0 | 0 | 0 | 8.182 | 32.729% (L1) | — |
| 1.0 | fixed 겹침 | 0 | 0 (`[]`) | 0 | 0 | 0 | 0.000 | 0% (—) | — |
| 1.0 | fixed 20턴 | 0 | 0 (`[]`) | 1 | 0 | 0 | 6.853 | 27.143% (L1) | — |
| 1.0 | fixed 120턴 | 0 | 0 (`[]`) | 9 | 0 | 0 | 10.292 | 41.166% (L1) | 4.833 |
| 1.0 | realtime 120턴 | 0 | 0 (`[]`) | 6 | 0 | 0 | 11.574 | 46.295% (L1) | 4.667 |

  - 지수별 프로세스 결과 → `2.0 fixed 10/11(종료 1), realtime 1/1(종료 0)`; `1.5 fixed 10/11(종료 1), realtime 1/1(종료 0)`; `1.0 fixed 11/11(종료 0), realtime 1/1(종료 0)`. fixed 실패는 각각 22시드 12px 기준 초과(`2.0: 14.823px`, `1.5: 12.036px`)뿐이다.
  - 지수 2 realtime 사전 복구 1회 → `L1 / x / depth 22.551px / since_last_spawn 177 / since_last_ghost_timeout 757 / on_ghost_timeout_frame=false`. #12의 timeout+1 frame 가설과 다른 사례다.
  - 필수 전체 실시간 실행의 22시드 → 안전장치 0, 사전 복구 1, 유령 timeout 0, 이탈 0, 발산 0, 최대 관통 14.144px, 최대 비율 56.5763%(L1). 복구는 시드 1013의 `depth 16.157px / since_last_spawn 2558 / since_last_ghost_timeout -1`이며 선행 timeout이 없었다. 12px 초과 시드는 1002/1003/1009/1012/1013/1018/1047/2000이다.
  - 필수 전체 실시간 실행의 120턴 → 안전장치 0, 사전 복구 0, 유령 timeout 7, 이탈 0, 발산 0, 최대 관통 12.562px, 최대 비율 50.2463%(L1), 최종 구 평균 5.833.
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --import` → 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . -s res://tests/run_tests.gd` → 91/92 통과, 종료 코드 1. 위 22시드 안전 기준 테스트 1개만 실패
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --quit-after 300` → 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - 환경 진단 → 사용자 로그/Windows 루트 인증서/에디터 설정 접근 오류가 출력됐으나 프로젝트 스크립트 로드·실행 결과에는 영향 없음
  - 정적 검사 → `Input`/`InputEvent` 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만; `git diff --check` 이상 없음
- 수동 확인 절차:
  1. 프로젝트를 실행하고 NEXT의 L1/L2 미리보기와 실제 생성 구체를 번갈아 본다 → 미리보기와 생성 구체 크기가 일치하고 L1 25px·L2 40px 차이가 분명히 보이는지 확인한다.
  2. 같은 색·레벨 구체를 차례로 합체해 L1→L2→L3 이상을 만든다 → 25/40/60/85px 표에 따라 단계별 크기 차이가 보이고 HUD의 NEXT·SCORE·BEST·MAX CHAIN이 겹치거나 잘리지 않는지 확인한다.
  3. 네 방향으로 여러 턴 플레이한다 → 큰 구체가 벽에서 튀거나 순간 이동하는 복구가 눈에 띄는지, 중심 이탈이나 수치 발산이 보이는지 확인한다.
- 결정 사항: 지수 비교용 `--mass-exponent`/`--mass-suite` 러너 인자를 추가했으며 기본 리소스의 `mass_exponent=2.0`은 유지했다. 최대 비율 분모는 성장 중 현재 반지름이 아니라 레벨별 최종 반지름으로 정의했다. 안전 기준(`escape_guard_depth=25`, `wall_penetration_limit=16`, 테스트 12/16px), 물리 tick/contact, 성장·유령, 턴·반응 규칙은 변경하지 않았다.
- 남은 것 · 질문: 표를 근거로 최종 `mass_exponent`와 새 안전 기준을 지정해 달라. 현행 기준에서는 지수 2 fixed 22시드와 realtime 120턴, 지수 1.5 fixed 22시드와 realtime 120턴이 12px를 넘고, 지수 1만 독립 fixed/realtime 측정의 12px 이내였다. 결정 전까지 기본값은 지시대로 2.0이며 안전 수치는 그대로다.

### [2026-09-30] 대상 #13 — M7 점수·최고 점수·재시작 (게임오버 보류)
- 상태: 완료
- 브랜치 / PR: `m7-score-restart` / PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `project.godot`, `scenes/Main.tscn`, `scenes/UI.tscn`, `scripts/autoload/InputRouter.gd`, `scripts/core/Main.gd`, `scripts/core/ScoreManager.gd`, `scripts/core/ScoreManager.gd.uid`, `scripts/core/Spawner.gd`, `scripts/ui/DebugHud.gd`, `scripts/ui/Hud.gd`, `tests/test_config.gd`, `tests/test_input_router.gd`, `tests/test_score.gd`, `tests/test_score.gd.uid`, `tests/scenarios/test_score_flow.gd`, `tests/scenarios/test_score_flow.gd.uid`, `tests/scenarios/test_turn_time.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] MERGE·ANNIHILATE·MAX_CLEAR 기본 점수와 chain 배수 계산 — `test_score.gd` 5/5 자동 검증(8, 32, 3, 27, 640/1280)
  - [x] 반응 시점 즉시 점수 반영, 합체 연쇄 `4 + 8×2 = 20`, 최대 연쇄 2 — `test_score_flow.gd` 자동 검증
  - [x] 점수가 최고점을 넘을 때마다 `[records] best_score` 즉시 저장, 새 `ScoreManager`가 같은 경로에서 최고점 8 복원 — 자동 검증
  - [x] 저장 파일 없음·손상 시 0으로 시작하고 `ConfigFile` 파서 오류 없이 진행 — 자동 검증
  - [x] R 입력이 잠금과 무관하게 `restart_requested`를 발신하고 `Main.restart()`에 연결; 재시작 의미에서 점수 0·최고점 유지·`Config.data.annihilation_rule` 유지 — 입력·메인 씬 바인딩·ScoreManager reset 자동 검증
  - [x] SCORE/BEST/MAX CHAIN HUD가 신호로 갱신되고 관련 Control의 `mouse_filter = IGNORE` — 메인 씬 자동 검증
  - [x] 120턴 시드별 최종 점수·최대 연쇄·최고 도달 레벨 출력 — 자동 관측
  - [x] 전체 테스트 92/92 및 §10.1 명령 3종 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - [ ] 실제 창의 HUD 배치·BEST 재실행 유지·R 씬 재로드 체감 — 수동 확인 필요(아래 절차)
- QA 관측값:
  - 점수 순수 계산 5/5 → MERGE L2→L3 chain1 `8`, MERGE L3→L4 chain2 `32`, ANNIHILATE L2+L1 `3`, 규칙 C L4+L1 chain3 `27`, MAX_CLEAR chain1/2 `640/1280`
  - 점수 흐름 6/6 → 합체 연쇄 최종 `20점 / max_chain 2 / max_level 3`, 입력 대기 반응 직후 `4점`, 새 인스턴스 `score 0 / best 8`, 손상 저장 `score 0 / best 0`, 재시작 의미 `score 0 / best 8 / 규칙 C 유지`, HUD `SCORE 32 / BEST 32 / MAX CHAIN 2`
  - 120턴 시드 101~106 최종 점수 → `[80, 80, 62, 58, 64, 50]`; 최대 연쇄 → `[2, 2, 1, 2, 1, 2]`; 최고 도달 레벨 → `[3, 4, 3, 3, 4, 3]`
  - 120턴 물리 회귀 → 120/120 입력 복귀, 상한 도달 118회, 평균 1.501354초, 최대 1.504167초, 중심 이탈 0, 안전장치 0, 사전 복구 1(≤2), 최대 관통 10.974px, 최종 구체 평균 5.167, 타임아웃 보정 37, 유령 타임아웃 11
  - 물리 22시드 → 중심 이탈 0, 안전장치 0, 사전 복구 0, 최대 관통 9.365px, 최대 속도 1938.483px/s
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . -s res://tests/run_tests.gd` → 92/92 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - 환경 진단 → 사용자 로그/Windows 루트 인증서/에디터 설정 접근 오류가 출력됐으나 프로젝트 스크립트 로드와 위 종료 코드에는 영향 없음
  - 정적 검사 → `Input`/`InputEvent` 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만; `git diff --check` 이상 없음
- 수동 확인 절차:
  1. 프로젝트를 실행한다 → 상단 중앙에 큰 `SCORE`, 오른쪽 `BEST`, 그 아래 `MAX CHAIN`이 겹치거나 잘리지 않고 표시되며 해당 영역에서 드래그해도 중력 입력이 되는지 본다.
  2. 같은 색·레벨 구체를 합체시키고 빨강·파랑 같은 레벨을 소멸시킨다 → 반응 즉시 SCORE가 각각 명세 점수만큼 오르고 연쇄 시 MAX CHAIN이 갱신되는지 본다.
  3. 점수를 올린 뒤 프로그램을 종료하고 다시 실행한다 → SCORE는 0, BEST는 직전 최고점으로 유지되는지 본다.
  4. F2로 규칙을 C로 바꾸고 점수를 올린 뒤 시뮬레이션 중 R을 누른다 → 즉시 씬이 재시작되어 SCORE는 0, BEST와 `Rule: C`는 유지되는지 본다.
- 결정 사항: 실제 생성 구체 레벨 추적을 위해 `Spawner.orb_spawned(level)` 신호를 추가해 `ScoreManager.on_orb_spawned()`에 연결했다. 제품 저장 경로는 명세대로 `user://save.cfg`이며 export된 `save_path`로 테스트 경로를 바꿀 수 있다. 현재 샌드박스의 `user://` 쓰기 제한 때문에 저장 자동 테스트는 워크스페이스의 임시 `res://tests/*.tmp.cfg`를 사용하고 매 테스트 뒤 제거한다. 손상 파일은 `ConfigFile.load()`가 자체 오류를 출력하기 전에 `[records] best_score=<int>` 최소 형식을 검사해 0으로 복구한다. 게임오버·경고·패널은 추가하지 않았다.
- 남은 것 · 질문: 코드·자동 검증 기준 남은 항목 없음. 실제 창의 HUD 배치, 프로세스 재실행 BEST 유지, R키 씬 재로드 체감은 위 수동 절차로 확인 필요.

### [2026-09-30] 대상 #12 추가 요구 1 — 물리 보정 관측 카운터 + 기본 규칙 B
- 상태: 완료
- 브랜치 / PR: `m5-physics-observability` / PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `scripts/core/Board.gd`, `scripts/core/Orb.gd`, `tests/test_config.gd`, `tests/scenarios/test_board_physics.gd`, `tests/scenarios/test_ghost_scenario.gd`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_time.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] `Board.wall_recovery_count`(복구 축 단위)와 `Board.timeout_correction_count`(보정 구체 단위) 추가 — 자동 검증
  - [x] `[WALL_RECOVERY]`에 `level/axis/depth/ghost/age_frames/since_last_spawn_frames/on_ghost_timeout_frame` 출력 — 단위·120턴 시나리오에서 관측
  - [x] 물리 22시드·겹침 생성·20턴은 `wall_recovery_count == 0`, fixed·실시간 120턴은 추가 요구의 `wall_recovery_count <= 2` assert 적용 — 자동 검증
  - [x] 현재 반지름 기준 벽 안쪽 20px 배치 단위 시나리오에서 사전 복구 1회, 안전장치 0 — 자동 검증
  - [x] 물리 22시드·겹침 생성·20턴·120턴 출력에 두 카운터 포함, 타임아웃 보정 경로의 증가를 자동 검증
  - [x] `GameConfig` 선언·기본 리소스·config 테스트를 기본 규칙 `B_SAME_LEVEL`로 변경. 시작 디버그 라벨은 `Config.data.annihilation_rule`에 따라 `Rule: B`
  - [x] 전체 테스트 79/79 및 검증 명령 3종 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건
  - [ ] 실제 창의 `Rule: B` 라벨 및 규칙 B 접촉 결과 — 수동 확인 필요(아래 절차)
- QA 관측값:
  - 물리 22시드 → 중심 이탈 0, 최대 관통 9.365px, 안전장치 0, 사전 복구 0, 타임아웃 보정 0
  - 겹침 생성 → 중심 이탈 0, 최대 관통 0.000px, 안전장치 0, 사전 복구 0, 타임아웃 보정 0
  - 20턴 시드 4242 → 최종 구체 22개, 중심 이탈 0, 최대 관통 7.747px, 안전장치 0, 사전 복구 0, 타임아웃 보정 20, 유령 타임아웃 3
  - fixed 240Hz 120턴 단독 → 최종 구체 평균 5.500, 중심 이탈 0, 최대 관통 11.682px, 안전장치 0, **사전 복구 1(≤2)**, 타임아웃 보정 39, 유령 타임아웃 12. 경고는 `L2 / y / 20.461px / ghost=false / age=276 / since_last_spawn=145 / on_ghost_timeout_frame=false`
  - 실시간 120턴 단독 → fixed 단독과 동일하게 최종 구체 평균 5.500, 중심 이탈 0, 최대 관통 11.682px, 안전장치 0, **사전 복구 1(≤2)**, 타임아웃 보정 39, 유령 타임아웃 12, `on_ghost_timeout_frame=false`
  - 전체 테스트 내부 120턴 → 최종 구체 평균 5.667, 중심 이탈 0, 최대 관통 8.844px, 최대 잔여 속도 843.538px/s, 안전장치 0, **사전 복구 1(≤2)**, 타임아웃 보정 57, 유령 타임아웃 17. 경고는 `L1 / x / 24.769px / ghost=false / age=869 / since_last_spawn=145 / on_ghost_timeout_frame=false`
  - 20px 단위 시나리오 → `[WALL_RECOVERY]` 1건, `wall_recovery_count=1`, `escape_guard_count=0`, `on_ghost_timeout_frame=false`
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . -s res://tests/run_tests.gd` → 79/79 통과, 종료 코드 0
  - fixed 240Hz·실시간 120턴 단독 실행 → 각각 1/1 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - 환경 진단 → 사용자 로그/Windows 루트 인증서/에디터 설정 접근 오류가 출력됐으나 프로젝트 스크립트 로드와 위 종료 코드에는 영향 없음
  - 정적 검사 → `Input`/`InputEvent` 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만; `git diff --check` 이상 없음
- 수동 확인 절차:
  1. 디버그 빌드로 실행한다 → 시작 라벨이 `Rule: B`인지 확인한다.
  2. 서로 다른 레벨의 빨강·파랑을 접촉시킨다 → 둘 다 남고, 같은 레벨끼리는 소멸하는지 확인한다.
- 결정 사항: 추가 요구 1에 따라 120턴만 사전 복구 허용치를 `<= 2`로 적용했고, 물리 22시드·겹침 생성·20턴은 0 기준을 유지했다. 같은 물리 프레임의 유령 타임아웃 여부를 경고 시점에 판별하도록 진단 로그만 지연 출력했으며 복구·타임아웃 보정의 조건과 적용 순서, 밸런스 수치는 변경하지 않았다.
- 남은 것 · 질문: 코드·자동 검증 기준 남은 항목 없음. 관측된 120턴 사전 복구는 fixed·실시간 모두 유령 타임아웃과 같은 물리 프레임이 아니었다(`on_ghost_timeout_frame=false`). 실제 창의 라벨·접촉 결과는 위 수동 절차로 확인 필요.

### [2026-09-29] 대상 #11 — 새 구체 유령 상태 (생성 직후 통과)
- 상태: 완료
- 브랜치 / PR: `m5-ghost-state` / PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `scripts/core/Board.gd`, `scripts/core/Orb.gd`, `scripts/core/OrbVisual.gd`, `scripts/core/Spawner.gd`, `tests/test_config.gd`, `tests/scenarios/test_ghost_scenario.gd`, `tests/scenarios/test_ghost_scenario.gd.uid`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_time.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] 초기 배치를 제외한 `Board.spawn_orb` 구체가 레이어 3(비트 4) / 벽 마스크 1 / alpha 0.55로 시작하고, 초기 2개는 일반 상태 — 자동 검증
  - [x] 최대 일반 구체 겹침이 4px 이하일 때 레이어 2 / 마스크 1+2 / alpha 1.0으로 해제; 0.6초 초과 시 `[GHOST_TIMEOUT]` 경고와 카운터 증가 — 자동 검증
  - [x] 유령 두 개가 서로 통과하고 각각 해제; 해제 뒤 같은 색·레벨 접촉이 합체 1회 — 자동 검증
  - [x] 바닥 더미 6개 겹침 생성에서 더미 변위 0.000px(<2px), 유령 지속 0.079167초; 빈 곳은 0.004167초에 해제 — 자동 검증
  - [x] #9 `0.20/0.3` 발산 재현 배치에서 발산 0, 안전장치 0, 최대 관통 3.953px, 타임아웃 1 — 자동 검증
  - [x] 20턴에서 중심 이탈 0, 안전장치 0, 최대 관통 7.747px, 타임아웃 3, 평균 유령 지속 0.093542초 — 자동 검증
  - [x] 기본값 실시간 120턴에서 중심 이탈 0, 발산 0, 안전장치 0, 최대 관통 12.186px(≤16px), 타임아웃 12 — 자동 검증
  - [x] 기본값 fixed 240Hz 120턴에서 중심 이탈 0, 발산 0, 안전장치 0, 최대 관통 11.486px(≤16px), 타임아웃 12 — 자동 검증
  - [x] 전체 79/79 및 §10.1 명령 3종 종료 코드 0, 프로젝트 `SCRIPT ERROR`·`Parse Error` 0건 — 자동 검증
  - [ ] 반투명 전환의 시각적 자연스러움 — 수동 확인 필요(아래 절차)
- QA 관측값:
  - 유령 전용 시나리오 8개 전부 통과(명세 6개 + 승인 보정 회귀 2개). 더미 변위 `0.000px`, 빈 곳 해제 `0.004167초`, 유령 쌍 해제 각각 `0.270833초`, 해제 후 합체 반응 `1회`, 꽉 찬 바닥 타임아웃 `1회`, #9 재현 안전장치 `0회`
  - 물리 22시드 → 중심 이탈 0, 안전장치 0, 최대 관통 9.365px, 최대 속도 1938.483px/s
  - 실시간 120턴 단독 → 120/120 입력 복귀, 상한 도달 117회, 평균 1.500590초, 최대 1.504167초, 중심 이탈 0, 안전장치 0, 최대 관통 12.186px, 타임아웃 12회, 완료 유령 162개, 평균 유령 지속 0.048302초, 위치·속도 발산 0
  - fixed 240Hz 120턴 단독 → 120/120 입력 복귀, 상한 도달 117회, 평균 1.500590초, 최대 1.504167초, 중심 이탈 0, 안전장치 0, 최대 관통 11.486px, 타임아웃 12회, 완료 유령 161개, 평균 유령 지속 0.048577초, 위치·속도 발산 0
  - 최종 전체 테스트의 120턴 → 안전장치 0, 최대 관통 8.095px, 타임아웃 10회, 완료 유령 162개, 평균 유령 지속 0.043544초
  - 20턴 → 안전장치 0, 최대 관통 7.747px, 타임아웃 3회, 평균 유령 지속 0.093542초
  - 타임아웃 프레임의 기존 구체 경계 복구와 타임아웃 구체 겹침 완화를 `PhysicsDirectBodyState2D`에 적용. 전역 선제 복구는 벽 관통이 `wall_penetration_limit=16px`를 초과할 때 기존 25px 안전장치 전에 경계로 복구하며, 최종 스트레스 실행에서 안전장치 0·관통 기준 충족을 관측
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . -s res://tests/run_tests.gd` → 79/79 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - 환경 진단 → 실행마다 사용자 로그/Windows 루트 인증서 접근 오류가 출력됐으나 테스트 로드·실행과 종료 코드에는 영향 없음
  - 정적 검사 → `Input`/`InputEvent` 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만; `git diff --check` 이상 없음
- 수동 확인 절차:
  1. 프로젝트를 실행하고 구체가 쌓인 생성 벽 방향으로 스와이프한다 → 새 공이 alpha 0.55로 나타나 이웃 공을 밀지 않고 통과하며, 벽은 통과하지 않는지 본다.
  2. 겹침이 풀리는 순간 새 공이 alpha 1.0으로 돌아오는지, 이후 같은 색·레벨 공에 닿으면 합체하는지 본다.
  3. 빽빽한 상태에서 0.6초 타임아웃 경고가 난 직후 기존 공이 벽 쪽으로 튀거나 보정이 눈에 띄게 어색한지 본다. 자동 회귀의 타임아웃 경로 안전장치는 0회다.
- 결정 사항: 사용자 승인에 따라 (1) 타임아웃 구체를 일반 구체·벽에서 4px 떨어진 최소 이동 위치로 보정, (2) 같은 프레임의 기존 구체도 벽에서 4px 안쪽으로 복구, (3) 모든 구체의 16px 초과 벽 관통을 기존 25px 안전장치 전에 전역 복구한다. `wall_penetration_limit=16.0`을 새 config 필드로 두고 `PhysicsDirectBodyState2D`에 적용했다. 기존 물리·성장·안전장치 수치는 바꾸지 않았다. 충돌 우선순위 실험은 최대 관통이 악화되어 최종 코드에서 제거했다.
- 남은 것 · 질문: 코드·자동 검증 기준 남은 항목 없음. 반투명 전환과 드문 타임아웃 보정의 시각적 자연스러움은 수동 확인 필요.

### [2026-09-29] 대상 #10 — M6 상극 소멸
- 상태: 완료
- 브랜치 / PR: `m6-annihilation` / push 완료, PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `project.godot`, `scripts/autoload/InputRouter.gd`, `scripts/core/CollisionResolver.gd`, `scripts/core/Main.gd`, `scripts/core/ReactionRules.gd`, `scripts/core/TurnManager.gd`, `scripts/ui/DebugHud.gd`, `tests/test_config.gd`, `tests/test_input_router.gd`, `tests/test_rules.gd`, `tests/scenarios/test_annihilation_scenario.gd`, `tests/scenarios/test_merge_scenario.gd`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_manager.gd`, `tests/support/PassiveCollisionResolver.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] 빨강↔파랑 규칙 A 전 레벨 49조합 소멸, 규칙 B 같은 레벨만 소멸, 규칙 C 차이 레벨 잔존 — `test_rules.gd` 자동 검증
  - [x] 초록은 상극 반응 없음, 같은 초록·같은 레벨 합체 유지 — `test_green_is_not_opposite_under_any_rule`
  - [x] 같은 색 합체 우선순위 유지 — `(RED, RED)`를 상극 목록에 넣어도 같은 레벨 빨강은 MERGE 자동 검증
  - [x] 규칙 변경을 매 `classify`/`flush` 시점에 읽어 다음 충돌부터 즉시 적용 — 순수 규칙·시나리오 자동 검증
  - [x] 규칙 C 잔존체가 큰 쪽의 색·위치·속도, 차이 레벨, `generation = chain`으로 생성 — 시나리오 자동 검증
  - [x] 합체 후 소멸 연쇄 순서 `[1, 2]`, 최종 구체 0개 — `test_merge_then_annihilation_reports_chain_one_two`
  - [x] 정지 접촉 규칙 B→A 전환 뒤 `sweep_resting_contacts()` 적용 수 1, 최종 구체 0개 — `test_sweep_rechecks_resting_pair_after_rule_change`
  - [x] 안정 종료 직전 스윕 반응 시 settle 연장, 1.5초 상한에서는 스윕 결과와 무관하게 종료 — `TurnManager` 구현 및 전체 턴 회귀
  - [x] 디버그 빌드 F2 입력 신호와 A→B→C 순환, `Rule: A/B/C` 라벨 추가 — 신호 자동 검증, 실제 라벨·플레이 반응은 아래 수동 절차
  - [x] §10.1 명령 3종 종료 코드 0, 전체 71/71 통과, `SCRIPT ERROR`·`Parse Error` 0건
- QA 관측값:
  - 상극 시나리오 → 규칙 A `반응 1 / 구체 0`, 규칙 B 다른 레벨 `반응 0 / 구체 2`, 규칙 C 빨강 L4+파랑 L1 `빨강 L3 / generation 1`, 즉시 규칙 전환의 두 번째 충돌 `반응 0`
  - 소멸 연쇄 → chain `[1, 2]`, 최종 구체 0; 정지 접촉 스윕 → 적용 수 1
  - 22시드 물리 회귀 → 중심 이탈 0, 안전장치 0, 최대 관통 8.517px, 최대 속도 1976.520px/s
  - 겹침 생성 회귀 → 중심 이탈 0, 안전장치 0, 최대 관통 9.465px, 최대 속도 1142.404px/s
  - 20턴 생성 회귀 → 20/20 완료, 최종 구체 22개(반응 격리 픽스처), 중심 이탈 0, 안전장치 0, 최대 관통 7.747px
  - 기본 규칙 A 120턴 회귀 → 120/120 입력 복귀, 상한 도달 117회, 평균 1.497812초, 최대 1.504167초, 중심 이탈 0, 안전장치 0, 최대 관통 15.507px, 최대 잔여 속도 942.110px/s, 최종 구체 수 평균 3.333, 위치·속도 발산 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . -s res://tests/run_tests.gd` → 71/71 통과, 종료 코드 0
  - `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - 정적 검사 → `Input`/`InputEvent` 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만
- 수동 확인 절차:
  1. 디버그 빌드로 프로젝트를 실행한다 → 디버그 라벨에 기본 `Rule: A`가 표시되는지 본다.
  2. F2를 세 번 누른다 → 라벨이 `B → C → A` 순서로 즉시 바뀌는지 본다. settle 중 F2도 같은 방식으로 바뀌어야 한다.
  3. Rule A에서 빨강·파랑을 접촉시킨다 → 레벨과 무관하게 둘 다 사라지는지, 초록이 포함된 접촉은 사라지지 않는지 본다.
  4. Rule B에서 서로 다른 레벨 빨강·파랑을 접촉시킨다 → 둘 다 남고, 같은 레벨끼리는 둘 다 사라지는지 본다.
  5. Rule C에서 서로 다른 레벨 빨강·파랑을 접촉시킨다 → 큰 쪽 색으로 레벨 차이 구체 하나가 큰 쪽 위치에 남는지 본다.
- 결정 사항: M6 스윕 도입 뒤 기존 생성/M3 전용 테스트가 의도적으로 끊어 둔 충돌 신호를 스윕이 다시 수집하므로, 해당 두 테스트 픽스처만 `tests/support/PassiveCollisionResolver.gd`로 반응을 격리했다. 게임 리졸버와 실제 120턴 회귀는 기본 M6 스윕을 사용한다. 그 외 문서 밖 게임 동작·수치 결정 없음.
- 남은 것 · 질문: 자동 완료 조건은 충족. 실제 창에서 색 접촉과 F2 라벨 전환의 시각 확인은 위 수동 절차로 남는다.

### [2026-09-29] 대상 #9 추가 요구 1 — 0.06/0.3 채택 및 fixed 0.20/0.3 발산 조사
- 상태: 완료
- 브랜치 / PR: `m5-orb-growth` / PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `scripts/core/Board.gd`, `scripts/core/Orb.gd`, `tests/TestCase.gd`, `tests/test_config.gd`, `tests/scenarios/test_board_physics.gd`, `tests/scenarios/test_merge_scenario.gd`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_manager.gd`, `tests/scenarios/test_turn_time.gd`, `docs/jeongmo_codex_to_claude.md`
- 추가 요구 1 Done-when 대조:
  - [x] 기본값 `grow_duration = 0.06`, `grow_start_ratio = 0.3`을 `GameConfig`와 기본 리소스에 반영하고 config 자동 검증 갱신
  - [x] 연속 120턴·20턴 관통 기준 16px, 물리 22시드·겹침 생성 기준 12px으로 분리
  - [x] 선택값 fixed 120턴 `0회 / 13.638px`, 실시간 120턴 `0회 / 15.373px`, 20턴 `0회 / 8.090px`, 물리 22시드 `0회 / 8.623px`, 겹침 `0회 / 9.465px`; 중심 이탈·발산 0
  - [x] 20턴·120턴 안전장치 `assert 0` 복원
  - [x] 물리 22시드·20턴·120턴·겹침·합체·턴 시나리오의 매 물리 프레임에 중심 extent `≤ 2 × half`와 속도 `≤ 10000px/s` 검사 추가
  - [x] fixed `0.20/0.3` 최초 발산과 직전 10프레임을 재현하고 원인 분류 — 아래 진단
  - [x] 수정 전·후 7행을 독립 프로세스로 재측정 — 아래 표
  - [x] §10.1 명령 3종 종료 코드 0, 전체 58/58 통과, `SCRIPT ERROR`·`Parse Error` 0건
- 발산 진단: fixed `0.20/0.3`, 최초 임계 위반 물리 프레임 **219308**. 아래 `r`은 현재/최종 반지름, `p`는 위치, `v`는 속도이며 두 구체 모두 각 행의 `guard=false`, 누적 안전장치 0이다.

| 프레임 | L3 id 3759606334938 (`r=78.125/78.125`) | L4 id 3771115505186 (`r=97.656/97.656`) |
|---:|---|---|
| 219298 | `p=(-401.9134,-401.8756)`, `v=(-0.000001,0.050894)`, overlap=L4, age=846 | `p=(-238.8362,-336.2802)`, `v=(-64.82278,162.7128)`, overlap=L3, age=186 |
| 219299 | `p=(-401.9134,-401.8753)`, `v=(-0.0,0.072789)`, overlap=L4, age=847 | `p=(-239.1120,-335.5959)`, `v=(-66.20883,164.2233)`, overlap=L3, age=187 |
| 219300 | `p=(-401.9134,-401.8749)`, `v=(-0.0,0.098878)`, overlap=L4, age=848 | `p=(-239.3938,-334.9054)`, `v=(-67.62280,165.7433)`, overlap=L3, age=188 |
| 219301 | `p=(-401.9134,-401.8744)`, `v=(0.0,0.129365)`, overlap=L4, age=849 | `p=(-239.6816,-334.2084)`, `v=(-69.06520,167.2727)`, overlap=L3, age=189 |
| 219302 | `p=(-401.9134,-401.8737)`, `v=(0.0,0.164379)`, overlap=L4, age=850 | `p=(-239.9755,-333.5050)`, `v=(-70.53654,168.8115)`, overlap=L3, age=190 |
| 219303 | `p=(-401.9134,-401.8728)`, `v=(0.0,0.204160)`, overlap=L4, age=851 | `p=(-240.2756,-332.7952)`, `v=(-72.03733,170.3594)`, overlap=L3, age=191 |
| 219304 | `p=(-401.9134,-401.8718)`, `v=(-0.0,0.248646)`, overlap=L4, age=852 | `p=(-240.5822,-332.0789)`, `v=(-73.56816,171.9164)`, overlap=L3, age=192 |
| 219305 | `p=(-401.9134,-401.8705)`, `v=(-0.0,0.298129)`, overlap=없음, age=853 | `p=(-240.8952,-331.3560)`, `v=(-75.12949,173.4823)`, overlap=없음, age=193 |
| 219306 | `p=(-401.9134,-401.8693)`, `v=(-0.0,0.297135)`, overlap=L4, age=854 | `p=(-241.2496,-330.6338)`, `v=(-85.06688,173.3377)`, overlap=L3, age=194 |
| 219307 | `p=(-401.9134,-401.8694)`, `v=(0.000001,-0.026830)`, overlap=L4, age=855 | `p=(-241.5669,-329.8949)`, `v=(-76.14867,177.3462)`, overlap=L3, age=195 |

  - 같은 프레임 219307에 L1 id 3774504502876이 `r=15/50`, `p=(-381.0987,-426)`, `v=(0,0)`으로 생성됐다. L3와 중심 거리 31.867px, 충돌 반지름 합 기준 겹침 깊이 **61.258px**이다.
  - 프레임 219308에는 L3 `p=(-2827461,3548126208)`, `v=(-0.008398,10.42726)`, L4 `p=(14086104064,-12601398272)`, `v=(-75.74788,187.0403)`, 새 L1 `p=(-44059791360,39415795712)`, `v=(5.211356,7.556991)`로 위치만 폭주했다. 세 구체 모두 `guard=false`, 누적 안전장치 0이며 현재/최종 반지름은 각각 `78.125/78.125`, `97.656/97.656`, `15/50`, 나이는 856/196/1이다.
- 원인 및 수정 여부:
  - 첫 이상 프레임의 세 속도는 모두 5000px/s보다 훨씬 작고 직전 10프레임에도 안전장치 발동이 없다. 따라서 성장 보간 산술이나 `body_set_state` 안전장치가 먼저 좌표를 만든 것이 아니다.
  - 작은 새 구체의 중심이 완성 L3 내부에 깊게 들어가고 L3가 다시 L4와 접촉한 3체 상태에서, GodotPhysics2D의 접촉 솔버가 속도와 일치하지 않는 거대한 **위치 보정**을 산출한 엔진 한계로 관측했다. 이후 안전장치는 이미 폭주한 위치에 반응한 결과다.
  - 성장 중 CCD·충돌 우선순위·생성선 변경을 각각 국소 실험했으나 발산이 다른 조합/실행 순서로 이동하거나 선택값 관통이 악화되어 최종 코드에는 넣지 않았다. 물리 설정을 임의 변경하지 않고, 모든 관련 시나리오의 프레임 상한 assert로 회귀를 즉시 검출하도록 했다.
- 7행 수정 전 → 후 비교: 각 셀은 `안전장치 / 최대 관통(px)`. fixed 120턴·20턴·22시드·겹침은 전후 동일하게 재현됐다. 실시간 비채택 행은 솔버 순서 변동이 관측됐으며 선택값은 동일했다.

| 성장 시간 / 비율 | fixed 120턴 전→후 | realtime 120턴 전→후 | 20턴 전→후 | 물리 22시드 전→후 | 겹침 전→후 |
|---:|---:|---:|---:|---:|---:|
| 없음 `0/1.0` | `7/79.349 → 7/79.349` | `4/57.855 → 4/57.855` | `0/12.979 → 0/12.979` | `0/8.623 → 0/8.623` | `0/4.922 → 0/4.922` |
| `0.06/0.3` | `0/13.638 → 0/13.638` | `0/15.373 → 0/15.373` | `0/8.090 → 0/8.090` | `0/8.623 → 0/8.623` | `0/9.465 → 0/9.465` |
| `0.06/0.6` | `0/21.150 → 0/21.150` | `0/21.150 → 0/21.150` | `0/7.747 → 0/7.747` | `0/9.227 → 0/9.227` | `0/17.432 → 0/17.432` |
| `0.12/0.3` | `0/16.998 → 0/16.998` | `0/15.087 → 0/22.310` | `0/7.747 → 0/7.747` | `0/8.623 → 0/8.623` | `0/8.497 → 0/8.497` |
| `0.12/0.6` | `2/35.743 → 2/35.743` | `2/33.128 → 1/26.218` | `0/7.747 → 0/7.747` | `0/8.623 → 0/8.623` | `0/16.882 → 0/16.882` |
| `0.20/0.3` | `18/44059790895 → 18/44059790895` | `0/12.746 → 11/3006437522991.729` | `0/7.747 → 0/7.747` | `0/9.227 → 0/9.227` | `0/8.112 → 0/8.112` |
| `0.20/0.6` | `0/22.934 → 0/22.934` | `0/17.595 → 0/21.014` | `0/19.382 → 0/19.382` | `0/8.623 → 0/8.623` | `0/16.662 → 0/16.662` |

- 자동 QA 관측값:
  - 선택값 fixed 묶음 → 11/11 통과, 종료 코드 0; 최대 속도는 물리 1935.529px/s, 겹침 1142.404px/s, 120턴 잔여 속도 976.469px/s로 프레임 상한 이내
  - 선택값 실시간 120턴 → 1/1 통과, 종료 코드 0; 최대 잔여 속도 1340.601px/s, 중심 이탈 0, 발산 0
  - 문제 조합 진단 실행은 의도한 상한/관통 실패 때문에 종료 코드 1이며, 최초 발산을 새 assert가 검출
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `godot --headless --path . -s res://tests/run_tests.gd` → 58/58 통과, 종료 코드 0. 통합 120턴은 안전장치 0, 중심 이탈 0, 최대 관통 13.949px, 최대 잔여 속도 1347.014px/s
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - 정적 검사 → Input 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만
- 검증 경계: 120턴 16px 관통 assert는 명세의 조합별 독립 프로세스인 `--growth-suite` 실행에서 적용한다. 첫 전체 통합 실행에서는 앞선 57개 테스트의 PhysicsServer body 이력 뒤 선택값 120턴 관통이 21.061px로 변동했으나 안전장치·중심 이탈·발산은 0이었고, 최종 전체 재실행에서는 13.949px였다. 통합 실행도 안전장치 0 및 매 프레임 위치·속도 상한은 계속 assert하며 관통은 관측값으로 출력한다.
- 수동 확인 절차:
  1. 프로젝트를 실행하고 DOWN·RIGHT·UP·LEFT 입력을 반복한다 → 새 공이 최종 크기의 30%에서 0.06초 동안 자연스럽게 커지고 순간이동하지 않는지 본다.
  2. 같은 색·레벨 합체를 만든다 → 합체 결과도 같은 성장 연출을 보이며 벽을 뚫거나 순간 이동하지 않는지 본다.
- 결정 사항: fixed `0.20/0.3` 발산은 위 관측 근거로 엔진 접촉 위치 보정 한계로 분류했으며, 선택 기본값의 물리 동작은 변경하지 않았다. 진단 출력은 `--growth-diagnose`에서만 활성화된다.
- 남은 것 · 질문: 자동 완료 조건은 충족. 실제 창의 성장 연출 체감 확인은 위 수동 절차로 남는다.

### [2026-09-29] 대상 #9 — 물리 안정성: 새 구체 점진 성장
- 상태: 질문 — 지정 6조합과 성장 없음 기준 중 모든 실행의 안전장치 0·관통 12px 이하를 함께 만족하는 후보 없음
- 브랜치 / PR: `m5-orb-growth` / PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `scripts/core/Board.gd`, `scripts/core/Orb.gd`, `scripts/core/OrbVisual.gd`, `tests/run_tests.gd`, `tests/test_config.gd`, `tests/test_orb_growth.gd`, `tests/test_orb_growth.gd.uid`, `tests/scenarios/test_board_physics.gd`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_time.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] `[ESCAPE_GUARD]`에 `age_frames`와 `since_last_spawn_frames` 추가; `Board.spawn_orb` 때 기존 구체와 새 구체 모두 마지막 생성 프레임 갱신
  - [x] 모든 `Board.spawn_orb` 구체의 충돌·Visual 반지름을 `grow_start_ratio`에서 `grow_duration` 동안 선형 성장; 질량은 생성 즉시 최종값
  - [x] `get_radius()`는 최종 반지름 유지, `get_current_radius()` 추가; 관통 계측은 현재 충돌 반지름 기준
  - [x] `GameConfig.grow_duration`, `grow_start_ratio` 추가
  - [x] 성장 단위 시나리오 — 0.12초/0.6에서 생성 직후 충돌·Visual 반지름 60%, 최종 질량, 29틱(±1틱) 뒤 최종 반지름; 0초는 즉시 최종 반지름
  - [x] 성장 없음 + 6조합을 독립 프로세스로 고정 FPS 120턴·20턴·22시드·겹침, 실시간 120턴 측정
  - [ ] 선택 기본값의 fixed/실시간 120턴·20턴 최대 관통 ≤ 12px 및 모든 회귀 안전장치 0 — 충족 후보 0/7
  - [ ] 20턴·120턴 안전장치 assert 0 복원 — 선택값이 없어 지시대로 미적용
  - [x] fallback 성장 없음(`0.0 / 1.0`)에서 전체 58/58 및 §10.1 명령 3종 종료 코드 0
- QA 관측값: 아래 고정 FPS 열의 20턴·22시드·겹침과 fixed 120턴은 조합당 한 독립 프로세스, realtime 120턴은 조합당 별도 독립 프로세스다. 값은 `안전장치 / 최대 관통(px)`이다.

| 성장 시간 / 시작 비율 | fixed 120턴 | realtime 120턴 | 20턴 | 물리 22시드 | 겹침 생성 | 충족 |
|---:|---:|---:|---:|---:|---:|:---:|
| 없음 `0 / 1.0` | 7 / 79.349 | 4 / 57.855 | 0 / 12.979 | 0 / 8.623 | 0 / 4.922 | 아니오 |
| `0.06 / 0.3` | 0 / 13.638 | 0 / 15.373 | 0 / 8.090 | 0 / 8.623 | 0 / 9.465 | 아니오 |
| `0.06 / 0.6` | 0 / 21.150 | 0 / 21.150 | 0 / 7.747 | 0 / 9.227 | 0 / 17.432 | 아니오 |
| `0.12 / 0.3` | 0 / 16.998 | 0 / 15.087 | 0 / 7.747 | 0 / 8.623 | 0 / 8.497 | 아니오 |
| `0.12 / 0.6` | 2 / 35.743 | 2 / 33.128 | 0 / 7.747 | 0 / 8.623 | 0 / 16.882 | 아니오 |
| `0.20 / 0.3` | 18 / 44059790895.000 | 0 / 12.746 | 0 / 7.747 | 0 / 9.227 | 0 / 8.112 | 아니오 |
| `0.20 / 0.6` | 0 / 22.934 | 0 / 17.595 | 0 / 19.382 | 0 / 8.623 | 0 / 16.662 | 아니오 |

- 추가 QA 관측값:
  - 모든 120턴 실행 → 120/120 상한 도달, p50·최대 1.504167초; 중심 이탈은 fixed `0.12/0.6` 1회, fixed `0.20/0.3` 11회, 그 외 독립 스윕 실행 0회
  - 가장 근접한 후보: `0.20 / 0.3` realtime은 0회·12.746px이나 fixed에서 18회·44059790895px; 양 실행 동시 조건 불충족
  - 고정 FPS fallback 진단 7건 → 마지막 생성 뒤 1~3프레임, 구체 나이 1 또는 465~2173프레임, 깊이 25.986~79.349px
  - fixed `0.12/0.6`의 120턴 2건 → 마지막 생성 뒤 1프레임, 나이 1·2173프레임, 깊이 36.437·29.510px
  - fixed `0.20/0.3`의 120턴 18건 → 마지막 생성 뒤 1~5프레임, 나이 1~3844프레임; 연쇄적인 초대형 좌표 발산 포함
  - §10.1 실시간 전체 fallback → 20턴 0회·17.068px, 120턴 7회·54.656px·중심 이탈 1회. 실행 순서에 따라 독립 스윕 수치와 달라지지만 완료 기준에는 어느 쪽도 미달
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `godot --headless --path . -s res://tests/run_tests.gd` → 58/58 통과, 종료 코드 0
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
- 수동 확인 절차: 선택값이 없어 성장 기본값을 비활성으로 유지했으므로 미실행. 새 후보 지정 시 실행 후 일반 생성과 합체 결과가 작은 원에서 자연스럽게 커지는지, 성장 중 벽 파고듦·순간 튐이 없는지 확인해야 한다.
- 결정 사항: 충족 후보가 없다는 지시 분기에 따라 `default_config.tres`는 성장 없음인 `grow_duration = 0.0`, `grow_start_ratio = 1.0`으로 두었다. 초기 배치도 구현상 같은 성장 경로를 사용하지만 기본값에서는 즉시 최종 크기다. 스윕 인자는 런타임 config만 바꾸며 기본 리소스를 수정하지 않는다.
- 남은 것 · 질문: 0.06/0.3이 두 실행 모두 안전장치 0으로 가장 안정적이지만 최대 관통이 fixed 13.638px·realtime 15.373px다. 허용 조합을 더 탐색할지, 성장 방식 또는 관통 기준을 조정할지 결정이 필요하다.

### [2026-09-29] 대상 #8 — 턴 소요 시간 튜닝: 구름 저항
- 상태: 완료 — 추가 요구 4 최종 규칙 반영
- 브랜치 / PR: `m5-turn-time-tuning` / PR 미생성
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `scripts/core/Board.gd`, `scripts/core/Orb.gd`, `scripts/core/TurnManager.gd`, `tests/run_tests.gd`, `tests/test_config.gd`, `tests/scenarios/test_board_physics.gd`, `tests/scenarios/test_merge_scenario.gd`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_manager.gd`, `tests/scenarios/test_turn_time.gd`, `tests/scenarios/test_turn_time.gd.uid`, `docs/jeongmo_codex_to_claude.md`
- 추가 요구 4 Done-when 대조:
  - [x] 기본값 `max_settle_time = 1.5`, `rolling_resistance = 0.0`, 저속 제동 0/0, 임계 30/3, 바닥 여유 2px·안전장치 깊이 25px 반영 — config 자동 검증
  - [x] 시간 상한을 정상 턴 종료로 처리하고 경고를 제거; 실제 턴의 상한 도달만 누적하는 `TurnManager.capped_turn_count` 노출 — T1·T5 자동 검증
  - [x] `CollisionResolver.flush()`를 모든 상태의 매 물리 프레임 시작에 1회 호출하고, SIMULATING의 적용 수로 안정 누적 리셋
  - [x] `WAITING_INPUT`에서 기록된 접촉이 다음 물리 프레임에 처리되어 `reaction_applied` 발신, `turn_max_chain` 갱신, 결과 generation이 직전 연쇄 +1 — `test_waiting_input_flush_continues_previous_turn_chain`
  - [x] 120턴 모두 1.5초 + 1물리 틱 이내 `WAITING_INPUT` 복귀 — 최대 1.504167초
  - [x] 20턴·120턴 안전장치 횟수는 assert하지 않고 기본 실행에서 각각 2회·73회로 보고; 20턴 중심 이탈 0 assert 유지
  - [x] 22시드 물리 회귀와 겹침 생성은 안전장치 0·관통 12px 이하 assert 유지 — 각각 8.623px·4.922px
  - [x] 전체 56/56 통과, 테스트 출력의 `forced settle` 문자열 0건
  - [x] §10.1 명령 3종 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
- 추가 요구 4 QA 관측값:
  - 120턴(§10.1 기본 실행) → 상한 도달 120/120(100%), 평균·p50·p90·최대 모두 1.504167초, 턴 종료 시 최대 잔여 선속도 1111.436px/s, 최종 구체 수 평균 9.000, 안전장치 73회
  - 120턴(`--fixed-fps 240` 보조 실행) → 상한 도달 120/120(100%), 최대 잔여 선속도 953.920px/s, 최종 구체 수 평균 8.333, 안전장치 5회
  - 120턴 방향별 p50 → DOWN·RIGHT·UP·LEFT 모두 1.504167초
  - 20턴(시드 4242) → 상한 도달 20/20, 중심 이탈 0, 최대 관통 42.646px, 안전장치 2회, 최종 구체 22개
  - 22시드 물리 회귀 → 중심 이탈 0, 최대 관통 8.623px, 최대 속도 1935.529px/s, 안전장치 0
  - 겹침 생성(시드 4006) → 중심 이탈 0, 최대 관통 4.922px, 최대 속도 1144.726px/s, 안전장치 0
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `godot --headless --path . -s res://tests/run_tests.gd` → 56/56 통과, 종료 코드 0
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - 정적 검사 → Input 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만, `CollisionResolver.flush()` 호출은 `TurnManager.gd` 1곳, `scripts/`·`tests/`의 `forced settle` 0건
- 추가 요구 4 수동 확인 절차:
  1. 실행 후 DOWN·RIGHT·UP·LEFT를 반복 입력 → 각 스와이프 뒤 1.5초 안에 다음 입력이 가능해지는지 확인한다.
  2. 턴 종료 시 아직 구르는 구체가 다음 입력 대기 중에도 계속 움직이는 모습이 어색하지 않은지 확인한다.
  3. 입력 대기 중 같은 색·같은 레벨 구체가 닿는 상황을 관찰 → 다음 스와이프 없이 즉시 합체하고 디버그 `Chain` 값이 직전 턴 연쇄에 이어지는지 확인한다.
- 추가 요구 4 결정 사항: `capped_turn_count`는 통계 의미를 턴에 한정하기 위해 시작 시 초기화하고 초기 배치 settle의 상한 도달은 세지 않는다. 턴 시간은 `_settle_elapsed` 자체를 측정하며 테스트 허용치는 설계대로 1.5초 + 1물리 틱이다.
- 추가 요구 4 남은 것 · 질문: 기본 실행과 `--fixed-fps 240` 실행에서 120턴 최종 구체 수·잔여 속도·안전장치 횟수가 달랐다(각각 9.000/1111.436/73 대 8.333/953.920/5). 두 실행 모두 120/120 턴 상한과 전체 56/56은 통과했으며 안전장치 횟수는 지시대로 보고만 했다. 실제 창 체감 QA는 위 절차로 별도 확인 필요.

- 추가 요구 3 Done-when 대조:
  - [x] `position.dot(g) >= half - r - floor_contact_tolerance`인 현재 중력 쪽 바닥에서만 힘·토크 기반 구름 저항 적용; `get_contact_count()` 조건 제거
  - [x] `floor_contact_tolerance = 2.0`, `escape_guard_depth = 25.0` config 필드와 기본값 추가
  - [x] 축별 관통 깊이가 25px을 넘으면 `PhysicsServer2D.body_set_state()`로 중심을 `±(half-r)`에 복귀시키고 외향 속도 성분을 0으로 설정; `[ESCAPE_GUARD]` 경고와 `Board.escape_guard_count` 누적
  - [x] 공중에서 맞닿아 스치는 두 구체의 구름 저항 힘 0 — `test_floor_resistance_is_zero_for_airborne_orb_contact`
  - [x] 40px 벽 관통에서 안전장치 1회, PhysicsServer 위치 경계 복귀, 외향 속도 제거 — `test_guard_restores_orb_after_forty_pixel_penetration`
  - [x] 후보 인자 `--turn-time-candidate=<값>`이면 해당 조합만 새 프로세스에서 기본 픽스처 경로로 측정; exact parity assert 제거
  - [x] 0.5·1.0·1.5 세 후보를 각각 독립 프로세스 3회 측정 — 각 후보의 3회 수치가 모두 동일
  - [x] 충족 후보가 없어 지시대로 `rolling_resistance = 0.0`으로 복귀
  - [x] 저항 0의 22시드 회귀는 안전장치 0회·이탈 0·최대 관통 8.623px로 기존 수치 보존
  - [ ] 선택 기본값의 독립 실행으로 전체 테스트 통과 — 충족 후보가 없어 선택 불가; fallback 0에서 54/56 통과
  - [ ] §10.1 명령 3종 에러 0 — import와 300프레임 스모크는 종료 코드 0, 전체 테스트는 종료 코드 1
- 추가 요구 3 QA 관측값 (`저항 / 제동 0·0 / 임계 30·3`, 아래 각 행은 독립 실행 3회 모두 동일):

| 저항 | 강제 | p50 | p90 | 물리 이탈/관통 | 20턴 이탈/관통 | 겹침 이탈/관통 | 안전장치 턴/물리/20턴/겹침 | 충족 |
|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| 0.5 | 20 | 2.366667 | 3.004167 | 0 / 11.329px | 0 / 27.403px | 0 / 4.634px | 3 / 0 / 2 / 0 | 아니오 |
| 1.0 | 20 | 2.250000 | 3.004167 | 0 / 12.941px | 0 / 29.378px | 0 / 2.082px | 445 / 0 / 1 / 0 | 아니오 |
| 1.5 | 24 | 2.225000 | 3.004167 | 0 / 13.303px | 0 / 22.755px | 0 / 2.119px | 4 / 0 / 0 / 0 | 아니오 |

- 추가 요구 3 QA 세부:
  - 0.5는 22시드 관통 기준을 만족하지만 강제·p50·p90과 20턴 안전장치 0 조건을 넘음
  - 1.0은 강제·p50·p90, 22시드 관통, 20턴 안전장치 조건을 넘음
  - 1.5는 20턴·겹침 안전장치 0을 만족하지만 강제·p50·p90과 22시드 관통을 넘음
  - fallback 0 전체 실행 → 54/56 통과, 종료 코드 1. 실패는 20턴 안전장치 1회와 선택 기본값 시간 목표(강제 112, p50·p90 3.004167초) 2개
  - fallback 0의 겹침 회귀 → 이탈 0, 최대 관통 6.867px, 안전장치 0
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `godot --headless --fixed-fps 240 --path . -s res://tests/run_tests.gd` → 54/56 통과, 종료 코드 1
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - 정적 검사 → `Orb.gd`의 `get_contact_count`, `linear_velocity =`, `angular_velocity =` 0건; Input 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만
  - 추가 요구 3 커밋은 이후 `origin/m5-turn-time-tuning`에 반영됨
- 추가 요구 3 수동 확인: 충족 기본값이 없어 미실행. 기본값을 새로 지정하면 DOWN·RIGHT·UP·LEFT 반복 입력으로 낙하 속도 유지, 바닥에서만 횡구름 감속, `[ESCAPE_GUARD]` 미발생을 확인해야 한다.
- 추가 요구 3 결정 사항: 후보별 실행 순서 의존성을 피하려고 테스트 러너가 후보 인자를 받으면 `test_turn_time.gd`만 실행하고, 그 안에서 22시드 → 20턴 → 겹침 → 턴 시간 순서로 측정하도록 고정했다. 안전장치 단위 테스트는 솔버가 경계 접촉체를 추가 보정한 뒤의 Node 좌표가 아니라 명세가 지정한 `PhysicsServer2D` body state의 복귀 좌표를 검증한다.
- 추가 요구 3 남은 것 · 질문: 지정 3조합에는 모든 선택 조건을 만족하는 값이 없다. 지시대로 기본 저항을 0으로 복귀했으므로 다음 튜닝 축 또는 기준 변경이 필요하다. 특히 0.5는 물리 관통은 통과하지만 시간 목표와 20턴 안전장치가 실패하고, 1.5는 안전장치 회귀는 통과하지만 시간·물리 관통이 실패한다.

- 추가 요구 2 Done-when 대조:
  - [x] 지정 기본값 `rolling_resistance 1.0`, 저속 제동 `0/0`, 안정 임계 `30/3`을 `default_config.tres`와 config 테스트에 반영
  - [x] 물리·겹침·스윕 선택 조건의 관통 기준을 12px로 변경
  - [x] 스윕의 `1.0 / 0·0 / 30·3` 행은 추가 요구 1 수치와 정확히 일치 — 강제 0, p50 1.733333초, p90 2.045833초, 물리 관통 10.450px, 20턴 이탈 0, 겹침 4.693px
  - [ ] 같은 실행 끝의 기본값 재측정과 스윕 행 일치 — 강제 4, p50 1.737500초, p90 2.112500초로 불일치
  - [ ] 지정 기본값으로 전체 테스트 통과 — 물리 회귀와 20턴 회귀 2개 실패, 52/54 통과
  - [ ] §10.1 명령 3종 에러 0 — import·300프레임 스모크는 종료 코드 0, 전체 테스트는 종료 코드 1
  - [x] 같은 브랜치 push — 질문 상태의 재현 코드·관측값 공유용이며 병합은 보류
- 추가 요구 2 QA 관측값:
  - 독립 기본값 실행을 3회 반복한 결과 모두 동일: 물리 22시드 이탈 0·최대 관통 **12.891px**(시드 1008), 20턴은 11턴째 UP에서 중심 이탈 1회·최대 관통 **57.279px**, 겹침 이탈 0·관통 4.599px
  - 독립 기본값 턴 시간 → 강제 3/120, 평균 1.803576초, p50 1.745833초, p90 2.041667초, 최대 3.004167초, 최종 구체 평균 11.167. 시간 목표 자체는 충족
  - 전체 테스트 `forced settle` 경고 → 4건. T5 의도적 1건을 제외하면 신규 턴 시간 시나리오의 3건
  - 같은 스윕 프로세스의 후보 행 → 강제 0/120, 평균 1.774687초, p50 1.733333초, p90 2.045833초, 최대 2.400000초, 최종 구체 평균 10.333, 물리 관통 10.450px, 20턴 이탈 0, 겹침 4.693px
  - 같은 스윕 프로세스 끝의 기본값 재측정 → 강제 4/120, 평균 1.808715초, p50 1.737500초, p90 2.112500초, 최대 3.004167초, 최종 구체 평균 10.667. exact parity assert 실패
  - 실행 순서별 결과는 각각 반복 재현되며, fixture 제거 후 물리 프레임 추가 대기와 fixture 시작을 물리 프레임 경계로 맞춘 실험에서도 독립 실행 수치가 바뀌지 않아 두 실험은 되돌림
  - 원인 관측: 동일 설정·시드라도 앞서 생성·해제된 물리 body 이력에 따라 접촉 솔버 순서가 달라지는 실행 순서 의존성이 있다. 힘 기반 저항이 더미를 조밀하게 유지해 이 차이가 관통·중심 이탈까지 증폭되는 것으로 추정한다
  - `godot --headless --path . --import` → 종료 코드 0, 파싱 오류 0건
  - `godot --headless --fixed-fps 240 --path . -s res://tests/run_tests.gd` → 52/54 통과, 종료 코드 1. 실패는 `test_board_physics`와 `test_seed_4242_completes_twenty_turns_without_departures`
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
- 추가 요구 2 수동 확인: 자동 물리 안전 회귀가 실패해 미실행
- 추가 요구 2 남은 것 · 질문: 지정 기본값은 시간 목표를 만족하지만 독립 실행에서 12px 관통 기준과 중심 이탈 0 조건을 만족하지 않는다. 특히 20턴 최대 관통 57.279px은 허용치 완화로 처리할 수준이 아니다. 기본값 또는 힘 적용 방식을 다시 지정해야 하며, 질문 상태의 재현 코드와 관측값은 같은 브랜치에 push하고 병합은 보류한다.

- 추가 요구 1 Done-when 대조:
  - [x] `Orb.gd`의 `linear_velocity =`·`angular_velocity =` 대입 제거 — 정적 검색 0건
  - [x] 접촉 중 구름 속도 반대 방향의 중앙 힘을 `min(rolling_resistance × gravity_strength, rolling_speed / delta) × mass`로 적용하고, 원형 관성 모멘트 기반 토크로 각속도를 같은 비율 감속
  - [x] 스윕 조합 설정 후 픽스처를 새로 만들고 `start_game()`을 거치는 기본값 경로로 측정
  - [x] 12개 후보마다 턴 120회 + 물리 회귀 22시드 + 시드 4242의 20턴 + 겹침 생성을 모두 측정하고 선택 조건에 포함
  - [x] p50 목표 상수를 1.9초로 갱신
  - [x] 충족 조합이 없어 `default_config.tres`의 저항·제동 기본값 0과 임계 12/1 유지
  - [ ] 스윕 선택 조합과 기본값 수치 일치 — 선택 조합이 없어 비교 대상 없음
  - [ ] 선택 기본값으로 전체 테스트 통과 — 선택 조합이 없어 현 기본값의 목표 assert 1개 실패
- 추가 요구 1 QA 관측값:
  - 스윕 결과 → 충족 0/12. 스윕 모드 테스트 러너 요약 54/54 통과
  - 시간·이탈·겹침까지 통과하고 물리 관통만 가장 근접한 조합은 `0.7 / 60·8 / 30·3`: 강제 4/120, p50 1.800000초, p90 2.137500초, 물리 최대 관통 10.230px(기준 0.230px 초과), 20턴 이탈 0, 겹침 이탈 0·관통 4.604px
  - 물리 회귀를 통과한 `0.3 / 120·10 / 30·3`: 관통 9.833px, 20턴·겹침 이탈 0이지만 p50 1.929167초·p90 2.333333초로 시간 목표 초과
  - 현 기본값 전체 실행 → 53/54 통과. 기존 테스트 53개 전부 통과, 신규 턴 시간 목표 assert 1개 실패
  - 현 기본값 회귀 → 물리 22시드 이탈 0·최대 관통 8.623px; 20턴 이탈 0·강제 15회; 겹침 이탈 0·관통 3.149px
  - `godot --headless --path . --import`와 `--quit-after 300` → 각각 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건

| 저항 | 제동 | 강제 | 평균 | p50 | p90 | 최대 | 최종 수 | 물리 이탈 | 물리 관통 | 20턴 이탈 | 겹침 이탈 | 겹침 관통 | 충족 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| 0.3 | 0/0 | 5 | 2.096736 | 2.012500 | 2.550000 | 3.004167 | 11.500 | 0 | 11.874 | 1 | 0 | 4.594 | 아니오 |
| 0.3 | 60/8 | 10 | 2.113472 | 2.037500 | 2.879167 | 3.004167 | 10.167 | 0 | 13.739 | 0 | 0 | 4.599 | 아니오 |
| 0.3 | 120/10 | 3 | 1.954201 | 1.929167 | 2.333333 | 3.004167 | 9.500 | 0 | 9.833 | 0 | 0 | 1.813 | 아니오 |
| 0.5 | 0/0 | 14 | 2.014722 | 1.883333 | 3.004167 | 3.004167 | 10.667 | 0 | 16.205 | 1 | 0 | 2.710 | 아니오 |
| 0.5 | 60/8 | 0 | 1.875486 | 1.829167 | 2.158333 | 2.758333 | 11.000 | 0 | 13.054 | 0 | 0 | 2.730 | 아니오 |
| 0.5 | 120/10 | 2 | 1.906389 | 1.820833 | 2.320833 | 3.004167 | 10.000 | 0 | 11.974 | 1 | 0 | 5.518 | 아니오 |
| 0.7 | 0/0 | 5 | 1.848090 | 1.783333 | 2.170833 | 3.004167 | 11.833 | 0 | 12.811 | 0 | 0 | 3.127 | 아니오 |
| 0.7 | 60/8 | 4 | 1.848437 | 1.800000 | 2.137500 | 3.004167 | 10.500 | 0 | 10.230 | 0 | 0 | 4.604 | 아니오 |
| 0.7 | 120/10 | 0 | 1.802535 | 1.779167 | 2.075000 | 2.591667 | 10.500 | 0 | 15.420 | 0 | 0 | 1.793 | 아니오 |
| 1.0 | 0/0 | 0 | 1.774687 | 1.733333 | 2.045833 | 2.400000 | 10.333 | 0 | 10.450 | 0 | 0 | 4.693 | 아니오 |
| 1.0 | 60/8 | 0 | 1.788125 | 1.729167 | 2.066667 | 2.808333 | 10.500 | 0 | 11.639 | 1 | 0 | 4.710 | 아니오 |
| 1.0 | 120/10 | 0 | 1.768785 | 1.716667 | 2.029167 | 2.416667 | 9.333 | 0 | 12.395 | 0 | 0 | 4.793 | 아니오 |

- 추가 요구 1 방향별 p50:

| 저항 | 제동 | DOWN | RIGHT | UP | LEFT |
|---:|---:|---:|---:|---:|---:|
| 0.3 | 0/0 | 1.954167 | 1.987500 | 2.033333 | 2.062500 |
| 0.3 | 60/8 | 2.037500 | 2.120833 | 1.925000 | 2.037500 |
| 0.3 | 120/10 | 1.908333 | 1.812500 | 1.958333 | 1.979167 |
| 0.5 | 0/0 | 1.904167 | 1.870833 | 1.812500 | 1.970833 |
| 0.5 | 60/8 | 1.825000 | 1.833333 | 1.858333 | 1.770833 |
| 0.5 | 120/10 | 1.837500 | 1.775000 | 1.825000 | 1.879167 |
| 0.7 | 0/0 | 1.770833 | 1.725000 | 1.741667 | 1.820833 |
| 0.7 | 60/8 | 1.775000 | 1.775000 | 1.812500 | 1.804167 |
| 0.7 | 120/10 | 1.779167 | 1.704167 | 1.754167 | 1.795833 |
| 1.0 | 0/0 | 1.729167 | 1.720833 | 1.729167 | 1.766667 |
| 1.0 | 60/8 | 1.737500 | 1.704167 | 1.741667 | 1.704167 |
| 1.0 | 120/10 | 1.700000 | 1.700000 | 1.745833 | 1.700000 |

- 추가 요구 1 결정 사항: 자동 관성값을 직접 읽는 공개 API 대신 원형 구체의 관성 모멘트 `0.5 × mass × radius²`로 목표 각가속도를 토크로 변환했다. `_integrate_forces` 관통 악화 관측(3.149 → 27.014px)은 아래 초기 회신에 유지했다.
- 추가 요구 1 남은 것 · 질문: 지정한 12조합 모두 적어도 한 조건을 넘었다. 가장 근접한 `0.7 / 60·8`의 관통 기준을 10.230px로 허용할지, 또는 물리 관통을 낮출 다른 구현·튜닝 축을 지정할지 결정이 필요하다.

- 초기 요구 Done-when 대조 (2026-09-28):
  - [x] 실제 `Board`+`Spawner`+`CollisionResolver`+`TurnManager`와 합체 연결을 사용해 시드 101~106 × 20턴, 지정 8방향 반복의 강제 종료·평균·p50·p90·최대·최종 구체 수 평균을 측정 — `test_turn_time.gd`
  - [x] 접촉 중 중력 수직 성분만 `rolling_resistance × gravity_strength × delta`만큼 0을 넘지 않게 줄이고 각속도도 같은 비율로 감속; 중력축 성분은 유지 — `Orb._physics_process()`
  - [x] 접촉 중 전체 속도가 `rest_speed` 미만이면 선형·각 감쇠를 `rest_damp`로 올리고 조건 해제 시 기존 감쇠로 복원
  - [x] 지정 30개 조합 전체 측정 — 아래 QA 표, 스윕 모드 테스트 러너 요약 54/54
  - [x] 목표 충족 조합이 없을 때 기본값을 바꾸지 않는 선택 규칙 준수 — 신규 세 필드 모두 `0.0`, 기존 임계 `12/1` 유지
  - [ ] 선택 기본값 목표 assert 통과 — 충족 조합 0개. 현 기본값 관측은 강제 114/120, p50·p90 3.004167초
  - [ ] 기존 물리 회귀를 기존 감쇠와 새 기본값 두 상태로 보고 — 새 기본값을 선택할 수 없어 기존 상태만 확인(22시드 이탈 0, 최대 관통 8.623px)
  - [ ] §10.1 명령 3종 모두 성공 — import와 300프레임 스모크는 성공, 전체 테스트는 신규 목표 assert 1개 실패
  - [ ] 실제 창 체감 확인 — 미실행, 기본값 결정 뒤 아래 절차 필요
- QA 관측값:
  - 실행 환경: `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe`, 버전 `4.8.dev3.mono.official.51105ccbe`
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - `godot --headless --fixed-fps 240 --path . -s res://tests/run_tests.gd -- --turn-time-sweep` → 30조합 출력, 테스트 러너 요약 54/54 통과. `Select-String` 파이프를 포함한 셸 종료 코드는 1로 관측
  - 기본값 검증 실행 → 53/54 통과, 실패는 `test_selected_defaults_meet_turn_time_targets` 1개. 기존 테스트 53개는 전부 통과
  - 기본값 관측 → 강제 114/120, 평균 2.964931초, p50 3.004167초, p90 3.004167초, 최대 3.004167초, 최종 구체 평균 8.000, 방향별 p50 모두 3.004167초
  - 격자 내 최선 관측(`0.5 / 120·10 / 30·3`) → 강제 0/120, 평균 1.866181초, p50 1.841667초, p90 2.175000초, 최대 2.708333초, 최종 구체 평균 10.000. 방향별 p50 DOWN 1.845833 / RIGHT 1.758333 / UP 1.812500 / LEFT 1.900000초
  - 목표와의 차이 → 최선 관측은 강제 종료와 p90은 충족하지만 p50이 상한 1.6초보다 0.241667초 큼
  - 기존 물리 회귀(비활성 기본값) → 22시드 이탈 0건, 최대 관통 `8.623px`, 최대 속도 `1935.529px/s`
  - 생성 겹침 회귀(비활성 기본값) → 이탈 0건, 최대 관통 `3.149px`, 최대 속도 `1142.834px/s`
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - 정적 검사 → Input 참조는 `InputRouter.gd`만, 난수 API는 `Spawner.gd`만; `gravity_strength=2400`, 물리 240 tick, 접촉 허용 관통 0.1 유지

| 저항 | 저속 제동 | 임계 | 강제 | 평균 | p50 | p90 | 최대 | 최종 수 | D p50 | R p50 | U p50 | L p50 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.0 | 0/0 | 12/1 | 114 | 2.964931 | 3.004167 | 3.004167 | 3.004167 | 8.000 | 3.004167 | 3.004167 | 3.004167 | 3.004167 |
| 0.0 | 0/0 | 30/3 | 113 | 2.967882 | 3.004167 | 3.004167 | 3.004167 | 8.500 | 3.004167 | 3.004167 | 3.004167 | 3.004167 |
| 0.0 | 60/8 | 12/1 | 102 | 2.917431 | 3.004167 | 3.004167 | 3.004167 | 8.667 | 3.004167 | 3.004167 | 3.004167 | 3.004167 |
| 0.0 | 60/8 | 30/3 | 94 | 2.886667 | 3.004167 | 3.004167 | 3.004167 | 8.000 | 3.004167 | 3.004167 | 3.004167 | 3.004167 |
| 0.0 | 120/10 | 12/1 | 89 | 2.895278 | 3.004167 | 3.004167 | 3.004167 | 8.667 | 3.004167 | 3.004167 | 3.004167 | 3.004167 |
| 0.0 | 120/10 | 30/3 | 60 | 2.776389 | 2.987500 | 3.004167 | 3.004167 | 8.833 | 2.983333 | 2.925000 | 2.979167 | 3.004167 |
| 0.1 | 0/0 | 12/1 | 33 | 2.628299 | 2.662500 | 3.004167 | 3.004167 | 8.833 | 2.570833 | 2.725000 | 2.691667 | 2.600000 |
| 0.1 | 0/0 | 30/3 | 37 | 2.591806 | 2.650000 | 3.004167 | 3.004167 | 8.833 | 2.741667 | 2.654167 | 2.429167 | 2.787500 |
| 0.1 | 60/8 | 12/1 | 24 | 2.525660 | 2.545833 | 3.004167 | 3.004167 | 9.000 | 2.550000 | 2.475000 | 2.437500 | 2.783333 |
| 0.1 | 60/8 | 30/3 | 29 | 2.507604 | 2.479167 | 3.004167 | 3.004167 | 9.667 | 2.533333 | 2.383333 | 2.487500 | 2.587500 |
| 0.1 | 120/10 | 12/1 | 41 | 2.539132 | 2.612500 | 3.004167 | 3.004167 | 9.500 | 2.400000 | 2.820833 | 2.400000 | 2.620833 |
| 0.1 | 120/10 | 30/3 | 31 | 2.476806 | 2.462500 | 3.004167 | 3.004167 | 8.500 | 2.458333 | 2.758333 | 2.266667 | 2.437500 |
| 0.2 | 0/0 | 12/1 | 23 | 2.389792 | 2.345833 | 3.004167 | 3.004167 | 10.000 | 2.345833 | 2.370833 | 2.170833 | 2.416667 |
| 0.2 | 0/0 | 30/3 | 12 | 2.333403 | 2.279167 | 2.995833 | 3.004167 | 9.000 | 2.162500 | 2.370833 | 2.162500 | 2.395833 |
| 0.2 | 60/8 | 12/1 | 18 | 2.332743 | 2.295833 | 3.004167 | 3.004167 | 9.667 | 2.341667 | 2.287500 | 2.158333 | 2.345833 |
| 0.2 | 60/8 | 30/3 | 6 | 2.206771 | 2.150000 | 2.725000 | 3.004167 | 8.833 | 2.116667 | 2.212500 | 2.108333 | 2.229167 |
| 0.2 | 120/10 | 12/1 | 25 | 2.299826 | 2.212500 | 3.004167 | 3.004167 | 9.167 | 2.212500 | 2.287500 | 2.145833 | 2.233333 |
| 0.2 | 120/10 | 30/3 | 13 | 2.184063 | 2.116667 | 3.004167 | 3.004167 | 10.333 | 2.062500 | 1.975000 | 2.050000 | 2.195833 |
| 0.3 | 0/0 | 12/1 | 16 | 2.221076 | 2.108333 | 3.004167 | 3.004167 | 9.667 | 2.108333 | 2.129167 | 1.979167 | 2.220833 |
| 0.3 | 0/0 | 30/3 | 8 | 2.097708 | 2.037500 | 2.587500 | 3.004167 | 10.667 | 2.000000 | 2.054167 | 1.966667 | 2.250000 |
| 0.3 | 60/8 | 12/1 | 14 | 2.189688 | 2.120833 | 3.004167 | 3.004167 | 10.167 | 2.020833 | 2.133333 | 2.045833 | 2.187500 |
| 0.3 | 60/8 | 30/3 | 3 | 2.026528 | 1.987500 | 2.416667 | 3.004167 | 9.667 | 1.966667 | 1.987500 | 1.916667 | 2.000000 |
| 0.3 | 120/10 | 12/1 | 8 | 2.081667 | 1.987500 | 2.670833 | 3.004167 | 10.000 | 1.908333 | 1.912500 | 1.962500 | 2.075000 |
| 0.3 | 120/10 | 30/3 | 0 | 1.976111 | 1.950000 | 2.341667 | 2.887500 | 9.833 | 1.854167 | 1.929167 | 1.950000 | 2.041667 |
| 0.5 | 0/0 | 12/1 | 19 | 2.083958 | 1.879167 | 3.004167 | 3.004167 | 10.333 | 1.870833 | 1.862500 | 1.833333 | 1.991667 |
| 0.5 | 0/0 | 30/3 | 5 | 1.947014 | 1.854167 | 2.358333 | 3.004167 | 10.667 | 1.816667 | 1.829167 | 1.850000 | 1.879167 |
| 0.5 | 60/8 | 12/1 | 17 | 2.090868 | 1.887500 | 3.004167 | 3.004167 | 9.833 | 1.879167 | 1.916667 | 1.858333 | 1.937500 |
| 0.5 | 60/8 | 30/3 | 4 | 1.940556 | 1.862500 | 2.366667 | 3.004167 | 10.167 | 1.850000 | 1.816667 | 1.862500 | 1.954167 |
| 0.5 | 120/10 | 12/1 | 23 | 2.112500 | 1.925000 | 3.004167 | 3.004167 | 11.167 | 1.908333 | 1.883333 | 1.816667 | 2.037500 |
| 0.5 | 120/10 | 30/3 | 0 | 1.866181 | 1.841667 | 2.175000 | 2.708333 | 10.000 | 1.845833 | 1.758333 | 1.812500 | 1.900000 |

- 수동 확인 절차(기본값 결정 후):
  1. 실행 후 DOWN·RIGHT·UP·LEFT 방향을 반복 입력 → 기울이면 구체가 중력 방향으로 계속 떨어지면서 수직 방향의 구름만 자연스럽게 줄어드는지 확인한다.
  2. 벽과 더미에 닿은 구체 관찰 → 회전과 횡이동이 함께 잦아들고, 반대 방향으로 갑자기 튀거나 각속도만 남지 않는지 확인한다.
  3. 매 턴 `WAITING_INPUT` 복귀까지 대기 → 기존 3초 대기보다 짧아졌는지, 입력 재개 전에 움직이는 구체가 눈에 띄게 남지 않는지 확인한다.
- 결정 사항: `_integrate_forces()` 구현은 저항 0에서도 기존 생성 겹침 회귀의 최대 관통을 3.149px에서 27.014px로 악화시켰다. 명세가 `_integrate_forces`를 권장으로만 두었으므로 같은 프레임별 공식을 `_physics_process(delta)`에 구현해 비활성 기본값의 기존 물리 결과를 보존했다. 문서에 없는 밸런스 값은 선택하지 않았다.
- 초기 질문(추가 요구 1로 대체됨): 지정 격자에는 세 목표를 모두 만족하는 조합이 없었다. 이후 추가 요구 1에서 힘 기반 구현·완화된 p50·확장 격자로 재측정했다.

---

## 확인됨

### [2026-09-28] 대상 #7 — M5 합체 규칙
- 상태: 완료
- 브랜치 / PR: `m5-merge-rules` / [PR #7](https://github.com/jeongmo-dot/gravity_orb/pull/7)
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `scenes/Main.tscn`, `scenes/UI.tscn`, `scripts/core/Board.gd`, `scripts/core/CollisionResolver.gd`, `scripts/core/Orb.gd`, `scripts/core/ReactionRules.gd`, `scripts/core/TurnManager.gd`, `scripts/ui/DebugHud.gd`, `tests/test_config.gd`, `tests/test_rules.gd`, `tests/scenarios/test_merge_scenario.gd`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_manager.gd`, 신규 `.gd.uid` 4개, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] 같은 색·같은 레벨 L1~L6만 MERGE, 같은 색 L7은 MAX_CLEAR, 다른 색·레벨 조합은 NONE — `test_rules.gd` 3개 자동 검증
  - [x] 빨강 L1 두 개 접촉 후 0.5초 내 합체 1회, L2·generation 1·clamp된 중간 위치 — `test_matching_pair_merges_once_at_clamped_midpoint`
  - [x] 빨강 L1 세 개 동시 접촉 시 합체 정확히 1회, L2 1개 + L1 1개 유지 — `test_three_simultaneous_contacts_apply_exactly_one_merge`
  - [x] 빨강/파랑 L1 및 빨강 L1/L2 접촉은 반응 0회·구체 2개 유지 — `test_nonmatching_pairs_do_not_merge`
  - [x] 합체 결과가 다시 합체하면 chain 1 → 2, `chain_changed`도 `[1, 2]`, 최종 L3 generation 2 — `test_merge_result_reacts_again_as_chain_two`
  - [x] 떨어진 두 곳의 동시 합체는 모두 chain 1, `turn_max_chain` 1 — `test_independent_simultaneous_merges_are_both_chain_one`
  - [x] L7 두 개는 MAX_CLEAR 후 구체 0개, 벽 옆 합체 결과는 새 반지름 기준 보드 안쪽 — MAX_CLEAR·clamp 시나리오 자동 검증
  - [x] TurnManager 턴 중 합체 후 `WAITING_INPUT` 복귀, `turn_finished.max_chain ≥ 1` — `test_turn_manager_finishes_turn_after_merge`
  - [x] 물리 콜백은 `orb_contact` 발신만 수행하고 트리 변경은 `CollisionResolver.flush()`에서 수행 — 정적 검사 및 전체 출력 `flushing queries` 0건
  - [x] 디버그 라벨에 `Chain: <turn_max_chain>` 추가 — 씬 정적 검사 및 300프레임 스모크
  - [x] §10.1 명령 3종 종료 코드 0, 전체 51/51 통과 — 자동 검증 완료
  - [ ] 실제 창에서 합체·비합체·Chain 표시를 눈으로 확인 — 미실행, 아래 수동 확인 절차 필요
- QA 관측값:
  - 실행 환경: `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe`, 버전 `4.8.dev3.mono.official.51105ccbe`
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - `godot --headless --path . -s res://tests/run_tests.gd` → 51/51 통과, 실패 0건, 종료 코드 0
  - 테스트 세부 → M5 config 1/1, `test_rules.gd` 3/3, `test_merge_scenario.gd` 8/8, 기존 39/39 회귀 통과
  - 연쇄 시나리오 → 반응 순서 chain `[1, 2]`, `chain_changed` `[1, 2]`, 최종 빨강 L3 1개·generation 2
  - 동시 접촉 → L1 세 개는 반응 1회·잔여 L2 1 + L1 1; 독립 L1 두 쌍은 반응 2회·chain `[1, 1]`·최대 chain 1
  - MAX_CLEAR → 빨강 L7 두 개 제거, `result_level = 0`, `result_orb = null`; 벽 옆 MERGE 결과는 L2 반지름 기준 각 축 보드 내부
  - 오류 검색 → 전체 출력에서 `flushing queries` 0건, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - 기존 물리 회귀 → 22시드 이탈 0건, 최대 관통 `8.623px`, 최대 속도 `1935.529px/s`
  - 생성 겹침 회귀 → 이탈 0건, 최대 관통 `3.149px`, 최대 속도 `1142.834px/s`
  - 전체 테스트 `forced settle` → 18건(20턴 회귀 15건 + TurnManager T2·T3·T5 각 1건). 기존 알려진 문제의 관측 횟수이며 명세 동작으로 판정하지 않음
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - 정적 검사 → Input 참조는 `InputRouter.gd`에만 9줄, 난수 API는 `Spawner.gd`에만 1줄, 물리 240 tick·접촉 허용 관통 0.1 유지
- 수동 확인 절차:
  1. `& 'C:\work\Godot\Godot_v4.8-dev3_mono_win64.exe' --path .` 실행 후 같은 색·같은 크기의 구체가 닿도록 여러 턴 진행 → 두 구체가 사라지고 같은 색의 한 단계 큰 구체 1개가 나타나는지 확인한다.
  2. 서로 다른 색 또는 같은 색·다른 크기의 구체가 닿는 상황 관찰 → 합체하지 않고 물리적으로 튕기기만 하는지 확인한다.
  3. 합체 결과가 같은 색·같은 크기의 다른 구체와 연속으로 닿는 상황 관찰 → 디버그 라벨 `Chain`이 1에서 2 이상으로 올라가는지 확인한다.
  4. 합체가 일어난 턴이 끝날 때까지 대기 → 상태가 `WAITING_INPUT`으로 복귀하고 다음 스와이프를 정상 수신하는지 확인한다.
- 결정 사항: `CollisionResolver`가 `_ready()`에서 `Board.orb_contact`를, `TurnManager`가 `reaction_applied`를 직접 구독한다. 기존 생성·턴 테스트 fixture는 해당 기능만 격리 검증하도록 Board→Resolver 접촉 연결을 끊고, 실제 결합은 신규 TurnManager 합체 시나리오에서 검증했다. M6의 ANNIHILATE 분기와 `sweep_resting_contacts()`는 추가하지 않았다.
- 남은 것 · 질문: 실제 창 수동 QA는 미실행이다. 기본 설정의 강제 settle 다발은 기존 알려진 문제이며 후속 M5+ 튜닝 대상이다.

### [2026-09-28] 대상 #6 — 생성 시점 변경: 스와이프 순간 생성
- 상태: 완료
- 브랜치 / PR: `m4-spawn-on-swipe` / [PR #6](https://github.com/jeongmo-dot/gravity_orb/pull/6)
- 변경 파일: `scripts/core/TurnManager.gd`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_manager.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] 스와이프 직후 `SPAWNING`, 다음 물리 프레임에 구체 수 +1·생성선 위 배치·`SIMULATING` 진입 — `test_preview_matches_spawned_orb_and_spawn_line` 자동 검증
  - [x] 상태 순서 `SPAWNING → SIMULATING → CHECK_GAMEOVER → WAITING_INPUT`, `turn_started`·`turn_finished` 각 1회 — TurnManager T2 자동 검증
  - [x] `SPAWNING`과 `SIMULATING` 중 추가 스와이프 무시 — TurnManager T3 자동 검증
  - [x] 생성 전 settle을 제거해 턴당 settle 1회, 초기 settle은 생성 없이 유지 — TurnManager T1·T4·T5와 `test_three_turns_spawn_before_one_settle_each` 자동 검증
  - [x] 기존 미리보기 일치·시드 777 재현·4방향 생성선 회귀 유지 — `test_spawn_flow.gd` 자동 검증
  - [x] 바닥에 안정시킨 레벨1 구체 8개 중 dummy와 CENTER/UP 생성 구체를 겹치게 한 뒤 0.5초 관측 — 이탈 0건, 최대 관통 `2.513px`, 최대 속도 `1142.434px/s`
  - [x] 시드 4242, DOWN·RIGHT·UP·LEFT 반복 20턴 — 매 턴 `WAITING_INPUT` 복귀, 최종 구체 22개, 이탈 0건
  - [x] `Spawner.try_spawn()`의 무조건 생성 및 RNG 소비 순서 유지, GAME_OVER·경고 API 추가 없음 — 코드 확인과 회귀 테스트
  - [x] §10.1 명령 3종 종료 코드 0, 전체 39/39 테스트 통과 — 자동 검증 완료
  - [ ] 실제 창에서 스와이프 즉시 생성·기존 구체와 함께 이동·게임오버 없이 연속 진행 확인 — 미실행, 아래 수동 확인 절차 필요
- QA 관측값:
  - 실행 환경: `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe`, 버전 `4.8.dev3.mono.official.51105ccbe`
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - `godot --headless --path . -s res://tests/run_tests.gd` → 39/39 통과, 실패 0건, 종료 코드 0
  - #6 테스트 세부 → `test_spawn_flow.gd` 7/7, 갱신된 `test_turn_manager.gd` 7/7; 전체 회귀 25/25
  - 겹침 생성 관측(시드 4006, 생성 후 0.5초) → 이탈 0건, 최대 관통 `2.513px`, 최대 속도 `1142.434px/s`
  - 20턴 최종 통과 실행 settle 초 → T1 `1.725000`; T2~T17 각 `3.000000`(강제); T18 `2.758333`; T19 `2.975000`; T20 `2.679167`. 방향은 DOWN·RIGHT·UP·LEFT 5회 반복, 매 턴 이탈 0건
  - 20턴 최종 통과 실행 → 강제 settle 16회, 최종 구체 22개, 이탈 0건. 직전 독립 실행에서는 강제 settle 15회(T1 `1.725000`, T2~T12·T14~T16·T20 강제, T13 `2.400000`, T17 `2.508333`, T18 `2.620833`, T19 `2.833333`)로 실행 간 변동 관측
  - 기존 물리 회귀 → 22시드 이탈 0건, 최대 관통 `8.623px`, 최대 속도 `1935.529px/s`
  - T4 안정 settle → `0.333333초/80틱`; T5 강제 settle → `3.000000초/720틱`
  - 전체 테스트 경고 → 최종 실행에서 `forced settle` 19건(20턴 16건 + T2·T3·T5 각 1건). 강제 settle은 기존 알려진 문제의 관측 횟수이며 명세 동작으로 판정하지 않음
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - 정적 검사 → `InputEvent`는 `InputRouter.gd`에만 9줄, 난수 API는 `Spawner.gd`에만 1줄; config 값·물리 설정·RNG 소비 순서 변경 없음
- 수동 확인 절차:
  1. `& 'C:\work\Godot\Godot_v4.8-dev3_mono_win64.exe' --path .` 실행 후 초기 settle이 끝날 때까지 대기한다.
  2. 방향키나 80px 이상의 드래그로 한 번 스와이프 → 반대편 생성 벽에 NEXT와 같은 구체가 즉시 나타나고 기존 구체와 함께 같은 중력 방향으로 움직이는지 확인한다.
  3. 구체가 움직이는 동안 추가 입력 → 현재 턴의 중력·턴 수가 바뀌지 않고, `WAITING_INPUT` 복귀 뒤 다음 입력만 받아들이는지 확인한다.
  4. 네 방향을 반복해 20턴 이상 진행 → 생성 겹침 여부와 무관하게 매 턴 구체가 1개씩 늘고, 게임오버 화면이나 경고 UI 없이 계속 진행되는지 확인한다.
- 결정 사항: 공개 API·config 값·물리 설정·RNG 순서는 변경하지 않았다. 겹침 회귀 테스트는 8개를 DOWN으로 안정시킨 뒤 중앙 dummy를 다음 구체의 UP 생성선 원점에 맞춰 확정적으로 겹치도록 구성했다.
- 남은 것 · 질문: 실제 창 수동 QA는 미실행이다. 20턴의 강제 settle이 독립 실행에서 15회와 16회로 달라지는 물리 안정화 변동을 관측했으며, 기존 알려진 문제로 횟수만 보고한다.

### [2026-09-28] 대상 #5 — M4 구체 생성
- 상태: 완료
- 브랜치 / PR: `m4-orb-spawning` / [PR #5](https://github.com/jeongmo-dot/gravity_orb/pull/5)
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `scenes/Main.tscn`, `scenes/UI.tscn`, `scripts/core/Board.gd`, `scripts/core/Main.gd`, `scripts/core/Spawner.gd`, `scripts/core/TurnManager.gd`, `scripts/ui/DebugHud.gd`, `scripts/ui/Hud.gd`, `tests/run_tests.gd`, `tests/test_config.gd`, `tests/test_spawner.gd`, `tests/scenarios/test_board_physics.gd`, `tests/scenarios/test_spawn_flow.gd`, `tests/scenarios/test_turn_manager.gd`, Godot 생성 `.gd.uid` 4개
- Done-when 대조:
  - [x] 4방향 모두 중력 반대편 생성 벽의 `spawn_line` 공식과 실제 생성 좌표 일치 — `test_spawn_line_matches_all_four_generation_walls`, 시드 777의 5턴 시나리오 자동 검증
  - [x] 시작 시 바닥에 초기 구체 2개를 등간격 배치하고 벽·서로 겹침 0건 — `test_initial_two_orbs_use_even_bottom_positions_without_overlap` 자동 검증
  - [x] 미리보기의 color·level과 다음 실제 생성 구체 일치 — `test_preview_matches_spawned_orb_and_spawn_line` 자동 검증
  - [x] 같은 시드의 `(level, color, t)` 50개 시퀀스 및 시드 777의 5턴 실제 생성 결과 재현 — `test_spawner.gd`, `test_seed_777_reproduces_five_turn_sequence` 자동 검증
  - [x] CENTER 모드에서도 position 난수를 소비해 RANDOM과 level·color 순서 유지 — `test_center_mode_consumes_position_and_preserves_item_sequence` 자동 검증
  - [x] `SIMULATING` 안정 후 1개 생성, `SPAWNING`에서 다시 settle한 뒤 턴 종료 — `test_three_turns_add_three_orbs_and_settle_in_spawning_state` 및 갱신된 T1~T7 자동 검증
  - [x] M1 임시 RNG·구체 생성 코드와 `debug_test_orb_count` 제거 — 정적 검사 0건, 물리 시나리오는 내부 상수 5 사용
  - [x] RNG API 참조를 `Spawner.gd`로 격리 — `rg -n "randf|randi|shuffle|pick_random|RandomNumberGenerator" scripts -g "*.gd"` 결과 파일 1개
  - [x] NEXT 미리보기와 실제 seed 표시, 모든 Control `mouse_filter = IGNORE` — 씬 정적 검사와 메인 씬 스모크 자동 검증
  - [x] §10.1 명령 3종 종료 코드 0, 기존 물리 회귀 수치 유지 — 자동 검증 완료
  - [ ] 실제 창에서 초기 배치·NEXT 시각·4방향 생성과 고정 시드 재실행 확인 — 미실행, 아래 수동 확인 절차 필요
- QA 관측값:
  - 실행 환경: `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe`, 버전 `4.8.dev3.mono.official.51105ccbe`
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - `godot --headless --fixed-fps 240 --path . -s res://tests/run_tests.gd` → 37/37 통과, 실패 0건, 종료 코드 0
  - 테스트 세부 → `test_spawner.gd` 5/5, `test_spawn_flow.gd` 5/5, 갱신된 `test_turn_manager.gd` 7/7, 나머지 회귀 20/20
  - 시드 42, 10,000회 분포 → 레벨1 `0.8971`; 색상 `0.3360 / 0.3302 / 0.3338` (각 목표 대비 허용 오차 ±0.02 이내)
  - 4방향 레벨1 생성선 원점 → DOWN `(0, -426)`, UP `(0, 426)`, LEFT `(426, 0)`, RIGHT `(-426, 0)`
  - 시드 777, 5턴 생성 `(중력 / color / level / position)` → DOWN `0/1/(-360.4127,-426)`, LEFT `1/1/(426,285.0786)`, UP `2/1/(-35.29215,426)`, RIGHT `1/1/(-426,136.5205)`, DOWN `2/1/(283.709,-426)`; 독립 실행 2회 완전 일치
  - M3 시간 회귀 → T4 `0.333333초/80틱`, T5 `3.000000초/720틱`; 강제 settle 경고 4건은 기존 알려진 문제로 관측했으며 명세 동작으로 판정하지 않음
  - 기존 물리 회귀 → 22시드 이탈 0건, 최대 관통 `8.623px`, 최대 속도 `1935.529px/s`
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - 정적 검사 → 물리 240 tick·접촉 허용 관통 0.1 유지, M7 `is_circle_free`·후보 대체 API 0건
- 수동 확인 절차:
  1. `& 'C:\work\Godot\Godot_v4.8-dev3_mono_win64.exe' --path .` 실행 → 보드 바닥에 구체 2개가 간격을 두고 나타나며, 우측 상단에 `NEXT` 구체와 좌측 디버그 라벨의 실제 `Seed`가 표시되는지 확인한다.
  2. DOWN·LEFT·UP·RIGHT 순서로 스와이프 → 각각 위·오른쪽·아래·왼쪽 벽에서 새 구체가 나타나고 `SPAWNING` 상태에서 구른 뒤 `WAITING_INPUT`으로 돌아오는지 확인한다.
  3. 각 스와이프 직전 `NEXT`의 색·크기를 기억 → 생성된 구체와 일치하고, 생성 직후 NEXT가 다음 구체로 갱신되는지 확인한다.
  4. `default_config.tres`의 `rng_seed`를 임시로 `777`로 설정해 두 번 실행 → 초기 구체와 이후 5턴의 색·레벨·선호 생성 위치가 반복되는지 확인하고 값을 `0`으로 복구한다.
- 결정 사항: 중첩 UI 씬 내부의 `Hud`는 바깥 씬 고유 이름을 직접 찾을 수 없어 `UI` 루트가 `%Spawner` 참조를 주입하고, 이후 `Hud`가 `next_changed`를 직접 구독한다. 테스트 러너는 파싱 실패 스크립트가 잘못 통과하지 않도록 `Script.can_instantiate()` 검사를 추가했다.
- 남은 것 · 질문: 실제 창 수동 QA는 미실행이다. 기본 설정의 많은 턴이 3초 강제 settle로 끝나는 기존 알려진 문제가 있다.

### [2026-09-28] 대상 #4 — M3 턴 상태 머신
- 상태: 완료
- 브랜치 / PR: `m3-turn-state-machine` / [PR #4](https://github.com/jeongmo-dot/gravity_orb/pull/4)
- 변경 파일: `config/GameConfig.gd`, `config/default_config.tres`, `scenes/Main.tscn`, `scenes/UI.tscn`, `scripts/core/Main.gd`, `scripts/core/TurnManager.gd`, `scripts/ui/DebugHud.gd`, `tests/test_config.gd`, `tests/scenarios/test_turn_manager.gd`, Godot 생성 `.gd.uid` 3개
- Done-when 대조:
  - [x] 구체가 굴러가는 `SIMULATING` 중 추가 입력 무시, 입력 잠금 유지 — T3 자동 검증
  - [x] 안정 조건이 `stable_duration` 동안 유지되면 입력 재개 — T1·T2·T4 자동 검증
  - [x] 안정 불가 시 `max_settle_time`에 강제 안정 후 턴 완료 — T5 자동 검증
  - [x] `SIMULATING → SPAWNING → CHECK_GAMEOVER → WAITING_INPUT` 상태 신호 순서와 턴 신호 각 1회 — T2 자동 검증
  - [x] 같은 방향 스와이프 허용 토글의 잠금·턴 수 동작 — T6·T7 자동 검증
  - [x] `Main`의 입력 연결을 `TurnManager.on_swipe`로 교체하고 `Board.set_gravity` 직접 호출을 `TurnManager`로 한정 — 정적 검사와 메인 씬 스모크 자동 검증
  - [x] 임시 디버그 라벨에 state·gravity·turn index·settle 초 표시, `mouse_filter = IGNORE`, 상단 HUD 영역 배치 — 씬 정적 검사와 메인 씬 스모크 자동 검증
  - [x] §10.1 명령 3종 종료 코드 0, 기존 M0~M2 회귀 포함 — 자동 검증 완료
  - [ ] 실제 창에서 입력 잠금 체감과 디버그 라벨 상태 변화 확인 — 미실행, 아래 수동 확인 절차 필요
- QA 관측값:
  - 실행 환경: `C:\work\Godot\Godot_v4.8-dev3_mono_win64_console.exe`, 버전 `4.8.dev3.mono.official.51105ccbe`
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - `godot --headless --fixed-fps 240 --path . -s res://tests/run_tests.gd` → 26/26 통과, 실패 0건, 종료 코드 0
  - M3 시나리오 → T1~T7 7/7 통과; 기존 테스트 18/18 회귀 없음; M3 config 기본값 테스트 1/1 통과
  - T4 안정 settle → `0.333333초`, `80틱`, 목표 `0.33초`, 허용 오차 1물리틱 이내
  - T5 강제 settle → `3.000000초`, `720틱`, 목표 `3.00초`, 허용 오차 1물리틱 이내; 명세의 `forced settle turn=1 elapsed=3.000` 경고 1건 관측
  - 기존 물리 회귀 → 22시드 이탈 0건, 최대 관통 `8.623px`
  - `godot --headless --path . --quit-after 300` → 종료 코드 0, `SCRIPT ERROR` 0건, `Parse Error` 0건
  - 정적 검사 → 상태 대입은 `_set_state()` 내부 1곳, 미래 M5/M7 API·호출 0건, 물리 설정 240 tick·접촉 허용 관통 0.1 유지
- 수동 확인 절차:
  1. `& 'C:\work\Godot\Godot_v4.8-dev3_mono_win64.exe' --path .` 실행 → 화면 상단 라벨에 `State`, `Gravity`, `Turn`, `Settle` 네 항목이 표시되고 마우스 입력을 가로막지 않는지 확인한다.
  2. 초기 `SIMULATING`이 끝나 라벨이 `WAITING_INPUT`으로 바뀐 뒤 방향키나 드래그 입력 → `Turn`이 1 증가하고 `Gravity`와 `State`가 즉시 바뀌는지 확인한다.
  3. 구체가 구르는 동안 서로 다른 방향키를 연타하거나 여러 방향으로 드래그 → 첫 입력 뒤 `SIMULATING` 동안 중력·턴 수가 더 바뀌지 않는지 확인한다.
  4. 라벨이 다시 `WAITING_INPUT`이 된 뒤 새 방향을 입력 → 다음 턴으로 정상 진행하는지 확인한다.
- 결정 사항: 임시 HUD는 `scripts/ui/DebugHud.gd`가 state·gravity·turn 신호를 구독하며, 화면 표시용 settle 경과만 `_process()`에서 `TurnManager`의 내부 누적값을 읽는다. T4·T5는 동일한 240Hz 물리 delta를 보존하면서 실행 시간을 줄이기 위해 `--fixed-fps 240`으로 측정했다.
- 남은 것 · 질문: 실제 창 수동 QA는 미실행이다. 공개 API·밸런스 수치 변경과 알려진 문제는 없다.

### [2026-09-28] 대상 #3 — M2 입력 추상화
- 상태: 완료
- 브랜치 / PR: `m2-input-abstraction` / [PR #3](https://github.com/jeongmo-dot/gravity_orb/pull/3)
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
