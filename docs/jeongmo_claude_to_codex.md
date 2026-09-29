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

### [2026-09-29 #9] 물리 안정성 — 새 구체 점진 성장
- 상태: 대기
- 근거: [technical_design.md](technical_design.md) §12 M5+ "알려진 위험", 아래 Claude 진단
- 배경: 연속 턴에서 25px 초과 관통(안전장치 발동)이 120턴에 5~73회, 20턴 최대 42.6px
- **Claude 진단** (스크래치, 120턴 `test_turn_time` 경로, 실시간 실행): 안전장치 6건 **전부가 `spawn_orb` 직후 1~2 물리 프레임** 안에 발생. 밀려난 구체는 5건이 오래된 이웃(나이 314~6376프레임), 1건은 새 구체 자신. 관통 25.6~62.0px, L1~L3
  → 새 구체(스와이프 생성·합체 결과)가 기존 구체와 **겹친 채 최종 크기로 한 번에** 나타나 솔버가 한 프레임에 강하게 밀어내고, 그 반동으로 이웃이 벽에 박힌다
- 요구:
  1. **진단 로그 유지** — `[ESCAPE_GUARD]` 경고에 구체 나이(물리 프레임)와 마지막 `spawn_orb` 이후 프레임 수를 추가
  2. **점진 성장** — `Board.spawn_orb`로 생기는 모든 구체(스와이프 생성·합체 결과·규칙 C 잔존, 초기 배치는 제외 가능)는 충돌 반지름을 `최종 × grow_start_ratio`에서 시작해 `grow_duration`초 동안 최종 반지름까지 선형으로 키운다
     - `Orb`에서 매 물리 프레임 `CircleShape2D.radius` 갱신 (인스턴스 전용 shape이므로 안전). 스케일된 시간 기준
     - `Visual`도 같은 현재 반지름으로 그린다 (M8의 합체 팝 연출은 이것과 별개로 나중에 얹는다)
     - 질량은 생성 즉시 최종값
     - `get_radius()`는 **최종 반지름**을 반환하고, 현재 반지름용 `get_current_radius()`를 추가
  3. `GameConfig` 새 필드 `grow_duration`, `grow_start_ratio`
  4. **스윕**: `grow_duration` 0.06 / 0.12 / 0.20 × `grow_start_ratio` 0.3 / 0.6 (6조합) + 성장 없음(기준). 각 조합을 **독립 프로세스**로:
     - 120턴 (`test_turn_time` 경로) — `--fixed-fps 240` **와** 실시간 둘 다
     - 20턴 (시드 4242), 물리 22시드, 겹침 생성
  5. 선택: 모든 실행에서 **안전장치 0**, 120턴·20턴 최대 관통 ≤ 12px, 기존 회귀 통과. 만족 조합 중 `grow_duration` 최소 → `grow_start_ratio` 큰 쪽. 없으면 기본값을 성장 없음으로 두고 `상태: 질문` (진단 로그 요약 포함)
  6. 선택값이 정해지면 20턴·120턴 테스트의 안전장치 수를 **assert 0**으로 되돌린다
- 수치: 선택 규칙에 따른다. 기존 값 변경 금지
- 건드리지 말 것: `docs/` (회신 파일 제외), 물리 틱·접촉 설정, `gravity_strength`, 턴 규칙, 합체 규칙
- Done-when:
  - [ ] 선택 기본값으로 모든 회귀에서 안전장치 0 (fixed-fps·실시간 120턴 포함)
  - [ ] 120턴·20턴 최대 관통 ≤ 12px
  - [ ] 성장 단위 시나리오: 생성 직후 충돌 반지름 = 최종 × ratio, `grow_duration` 후 = 최종 (±1 tick)
  - [ ] 전체 테스트 통과, §10.1 명령 3종 에러 0
- QA: 7행 표 (조합 × fixed/실시간 120턴 안전장치·최대 관통, 20턴, 22시드, 겹침), 선택 근거, 남은 안전장치 이벤트가 있으면 진단 로그
- 수동 확인 절차: 새 공과 합체 결과가 작게 나타나 커지는 모습이 어색하지 않은지, 벽에 파고드는 공이 사라졌는지
- 커밋: 항목 단위 브랜치, push까지

---

## 처리 완료

### [2026-09-28 #8] 턴 소요 시간 튜닝 — 완료 (구름 저항 폐기, 1.5초 상한 규칙)
- 상태: 완료 (2026-09-29 Claude 검수 통과 · [PR #8](https://github.com/jeongmo-dot/gravity_orb/pull/8) 병합 `c61f9f3`)
- 검수: 56/56, 120턴 전부 1.504초, forced settle 0 Claude 재실행 일치. 추가 요구 1~3 과정의 질문 판단이 모두 정확했다. 수동 확인은 사용자 부재로 [manual_qa_pending.md](manual_qa_pending.md)에 보류
- 후속: 120턴 안전장치 5~73회 → #9
- 근거: [technical_design.md](technical_design.md) §12 "M5+. 턴 소요 시간 튜닝" (Claude 측정값·진단 포함)
- 배경: 현재 기본값으로 턴(스와이프 → `WAITING_INPUT`)의 96%가 3초 강제 안정으로 끝난다. GodotPhysics2D에 구름 저항이 없어 벽·바닥을 따라 구르는 공이 멈추지 않는 것이 원인이다 (측정 속도 = 실제 이동, 떨림 아님)
- 요구:
  1. **측정 도구 먼저** — `tests/scenarios/test_turn_time.gd`: `Board`+`Spawner`+`CollisionResolver`+`TurnManager` 실제 조립(합체 **연결 유지**), 시드 **101~106** × **20턴**, 방향 순서 `DOWN, RIGHT, UP, LEFT, DOWN, LEFT, UP, RIGHT` 반복. 턴별 소요 시간(시뮬레이션 초)을 모아 **강제 안정 수 / 평균 / p50 / p90 / 최대**, 최종 구체 수 평균을 출력. `--fixed-fps 240` 전제
  2. **구름 저항 구현** — `Orb`에서 매 물리 프레임(`_integrate_forces` 권장): 접촉 중(`get_contact_count() > 0`)이면 속도의 **중력 수직 성분**에 크기 `rolling_resistance × gravity_strength`의 감속을 건다. 한 틱에 그 성분의 부호를 넘기지 않게 0에서 멈춘다. 각속도도 같은 비율로 줄여 구름이 유지되지 않게 한다. 중력 방향 성분(낙하)은 건드리지 않는다
  3. **저속 제동 (선택)** — 접촉 중이고 속도 < `rest_speed`이면 선·각 감쇠를 `rest_damp`로 올린다. 구름 저항만으로 목표를 달성하면 `rest_speed = 0`(비활성)으로 둔다
  4. `GameConfig` 새 필드: `rolling_resistance`, `rest_speed`, `rest_damp` (기존 필드 이름 변경 금지)
  5. **스윕** — 아래 격자를 측정 도구로 돌려 표로 보고한다. 기존 감쇠·마찰·임계값은 스윕 축으로만 바꾼다:
     - `rolling_resistance`: 0, 0.1, 0.2, 0.3, 0.5
     - `rest_speed / rest_damp`: 0/0, 60/8, 120/10
     - `stable_linear_speed / stable_angular_speed`: 12/1, 30/3
     - 감쇠·마찰은 현재값(0.1 / 1 / 0.3) 고정
  6. **기본값 선택 규칙** — 목표를 만족하는 조합 중 `rolling_resistance`가 가장 작은 것, 동률이면 `rest_speed`가 작은 것, 그다음 임계값이 엄격한(작은) 것. 이 조합을 `default_config.tres`에 반영하고 근거 표와 함께 회신한다. **목표를 만족하는 조합이 없으면 기본값을 바꾸지 말고 `상태: 질문`** 으로 표를 올린다
- 목표 (Claude 결정): 120턴 기준 **강제 안정 ≤ 6 (5%)**, **p50 ≤ 1.6초**, **p90 ≤ 2.2초**
- 건드리지 말 것: `docs/` (회신 파일 제외), `gravity_strength`, 물리 틱·접촉 설정, 턴 흐름, `Spawner` RNG 순서, 합체 규칙
- Done-when:
  - [ ] `test_turn_time.gd`가 목표를 assert하고 통과한다 (선택된 기본값으로)
  - [ ] 기존 물리 회귀 22시드: 이탈 0, 관통 ≤ 10px (기존 테스트가 쓰는 감쇠 조건 그대로 + 새 기본값 적용 상태 둘 다 보고)
  - [ ] 겹침 생성·합체·턴 테스트 전부 통과
  - [ ] 전체 테스트의 `forced settle` 횟수 보고 (T5 의도적 1건 제외 목표 0에 가깝게)
  - [ ] §10.1 명령 3종 에러 0
- QA: 스윕 전체 표 (30조합 × 강제/평균/p50/p90/최대/최종 구체 수), 선택 조합과 선택 근거, 선택 조합의 방향별(DOWN/RIGHT/UP/LEFT) p50
- 수동 확인 절차: 기울이면 여전히 시원하게 쏟아지는지(낙하가 느려지지 않았는지), 멈출 때 딱 멈추는지, 다음 입력까지 기다림이 짧아졌는지

**추가 요구 1 (2026-09-29) — 속도 덮어쓰기 제거, 스윕·기본값 경로 일치, 회귀를 선택 조건에**

질문 회신 검수: 선택 규칙을 지켜 기본값을 바꾸지 않고 질문으로 올린 것은 정확하다. 목표 p50 1.6초는 Claude가 너무 빡빡하게 잡았다 → **p50 ≤ 1.9초로 완화** (강제 ≤ 6, p90 ≤ 2.2 유지).
Claude가 스크래치에서 격자 최선 조합(`0.5 / 120·10 / 30·3`)을 **`default_config.tres` 기본값으로 넣고** 전체 테스트를 돌린 결과:

| 항목 | 결과 |
|---|---|
| 턴 시간 (기본값 경로) | 강제 **7**/120, p50 1.800, p90 **2.254** — 스윕 표의 같은 조합(0 / 1.842 / 2.175)과 **불일치** |
| 물리 회귀 22시드 | 관통 **12.275px** (시드 1008·1011·1018·1019가 10px 초과) |
| 20턴 연속 (시드 4242) | **중심 이탈 1건** |
| 겹침 생성 | 관통 1.781px, 이상 없음 |

원인 추정: `_physics_process`에서 `linear_velocity`·`angular_velocity`를 **직접 덮어써** 솔버의 겹침 해소 보정까지 지운다.

1. **구름 저항을 힘으로** — 속도 대입을 제거하고, 접촉 중일 때 중력 수직 성분 반대 방향으로 `apply_central_force(-dir × min(rolling_resistance × gravity_strength, rolling_speed / delta) × mass)`, 각속도는 `apply_torque`로 같은 비율 감속. 저속 제동(감쇠 전환)은 유지해도 된다. `_integrate_forces` 관통 악화 관측(3.149 → 27.014px)은 회신에 그대로 남긴다
2. **스윕 = 기본값 경로** — 스윕은 조합마다 `Config.data`를 설정한 **뒤** 픽스처를 새로 만들고 `start_game()`까지 기본값 경로와 똑같이 진행한다. 선택 조합을 `default_config.tres`에 넣고 돌린 기본값 검증 수치가 스윕 수치와 **정확히 같아야** 한다 (결정적). 다르면 원인을 찾는다
3. **회귀를 선택 조건에 포함** — 후보 조합마다 턴 시간 목표 + **물리 회귀 22시드(이탈 0, 관통 ≤ 10px)** + **20턴 연속(이탈 0)** + 겹침 생성(이탈 0, 관통 ≤ 10px)을 모두 만족해야 "충족"이다
4. 격자: `rolling_resistance` **0.3, 0.5, 0.7, 1.0** × `rest` 0/0, 60/8, 120/10 × 임계 30/3 (12/1은 제외 — 1차 스윕에서 전부 강제 ≥ 8)
5. 선택 규칙은 기존과 같다 (저항 최소 → rest_speed 최소). 충족 조합이 없으면 기본값을 바꾸지 말고 `상태: 질문`
6. `test_turn_time.gd` 목표 상수 p50 1.9로 갱신. `test_config.gd`의 기본값 검증은 선택 결과에 맞춘다

- Done-when (추가 요구 1):
  - [ ] 구름 저항이 속도를 대입하지 않는다 (`linear_velocity =`·`angular_velocity =` 대입 0건, `Orb.gd`)
  - [ ] 스윕 표의 선택 조합 수치 = 기본값 검증 수치
  - [ ] 선택 기본값으로 전체 테스트 통과 (턴 시간 목표·물리 회귀·20턴·겹침 포함)
- QA: 12조합 표 (턴 시간 + 22시드 최대 관통 + 20턴 이탈 + 겹침 관통), 선택 조합과 근거
- 커밋: 같은 브랜치 `m5-turn-time-tuning`

**추가 요구 2 (2026-09-29) — Claude가 기본값 지정**

추가 요구 1 회신 검수: 힘 기반 전환·기본값 경로 스윕·회귀 포함 측정 모두 정확하다. 저항이 클수록 관통이 늘어나는 경향(더미가 퍼지지 않아 하단 압력 증가 추정)도 확인했다. 선택 규칙 대신 **Claude가 직접 지정**한다.

1. `default_config.tres`: `rolling_resistance = 1.0`, `rest_speed = 0.0`, `rest_damp = 0.0`, `stable_linear_speed = 30.0`, `stable_angular_speed = 3.0`
   - 근거: 강제 0/120, p50 1.733, p90 2.046, 20턴 이탈 0, 겹침 4.693px. 장치 하나(저속 제동 없음)로 가장 단순하다
2. **관통 기준 10px → 12px** — `test_board_physics.gd`, 겹침 생성, `test_turn_time.gd`의 선택 조건 상수 모두. (10px는 M1에서 임의로 정한 값이며 12px는 보드의 1.25%)
3. 선택 규칙·스윕 코드는 유지하되, 기본값 검증 테스트는 위 지정값을 목표(강제 ≤ 6, p50 ≤ 1.9, p90 ≤ 2.2)로 assert
4. **스윕 = 기본값 일치 확인**: 지정 조합을 기본값으로 둔 검증 수치가 추가 요구 1 표의 `1.0 / 0·0` 행(강제 0, p50 1.733333, p90 2.045833, 관통 10.450)과 같은지 보고. 다르면 차이와 원인
5. `test_config.gd` 기본값 검증을 지정값으로 갱신

- Done-when (추가 요구 2):
  - [ ] 지정 기본값으로 전체 테스트 통과 (`forced settle`은 T5 의도 1건 외 몇 건인지 보고)
  - [ ] 기본값 검증 수치 = 추가 요구 1 표 `1.0 / 0·0` 행
  - [ ] §10.1 명령 3종 에러 0
- 수동 확인 절차: 기울이면 쏟아지는 속도가 줄지 않았는지, 벽을 따라 구르다 딱 멈추는지, 끈적하게 느껴지지 않는지
- 커밋: 같은 브랜치, **push까지**

**추가 요구 3 (2026-09-29) — 바닥 한정 구름 저항 + 이탈 안전장치**

추가 요구 2 회신 검수: 질문으로 멈춘 판단이 옳다. 57px 관통은 기준 완화로 넘길 수 없다. 원인은 Claude 설계 결함으로 본다 — 구름 저항을 **구체끼리의 접촉에도** 걸어 더미가 퍼지지 못하고 하단 압력이 커졌다. 실행 순서 의존성(솔버 순서)은 엔진 특성으로 받아들이고, **독립 실행 결과를 기준**으로 한다.

1. **구름 저항은 바닥 접촉에만** — "바닥" = 현재 중력 방향 쪽 벽. 판정은 기하로 한다: `position.dot(g) >= half - r - floor_contact_tolerance` (새 필드 `floor_contact_tolerance`, 기본 2.0px). 이 조건일 때만 중력 수직 성분에 힘 기반 감속(추가 요구 1 방식 그대로). 구체끼리만 닿아 있는 구체에는 걸지 않는다. `get_contact_count()` 조건은 제거
2. **이탈 안전장치** — 새 필드 `escape_guard_depth` (기본 **25.0px**, 레벨1 반지름의 절반). 매 물리 프레임 각 축에서 `abs(pos) + r - half > escape_guard_depth`이면 그 축 위치를 `±(half - r)`로 되돌리고 벽 방향 속도 성분을 0으로 한다. 발동마다 카운터 증가 + `push_warning("[ESCAPE_GUARD] ...")` (레벨·축·깊이). 테스트가 읽을 수 있게 발동 수를 노출 (예: `Board.escape_guard_count`)
   - 위치 되돌림은 `PhysicsServer2D.body_set_state(get_rid(), BODY_STATE_TRANSFORM, ...)`로 한다
   - 안전장치는 **증상 은폐용이 아니다**. 회귀 테스트는 발동 0을 요구한다
3. **측정 기준 = 독립 실행** — 선택 조합을 기본값에 넣고 **별도 프로세스**로 돌린 결과로 판정한다. 스윕과의 exact parity assert는 제거하고 두 수치를 나란히 보고만 한다
4. 스윕: `rolling_resistance` **0.5, 1.0, 1.5** × 저속 제동 0/0 × 임계 30/3 (3조합). 각 조합을 **독립 프로세스**로 기본값 검증 경로에서 측정 (스크립트 반복 실행 허용)
5. 선택: 시간 목표(강제 ≤ 6, p50 ≤ 1.9, p90 ≤ 2.2) + 물리 22시드(이탈 0, 관통 ≤ 12px) + 20턴(이탈 0) + 겹침(이탈 0, 관통 ≤ 12px) + **모든 회귀에서 안전장치 발동 0**. 만족 조합 중 저항 최소. 없으면 기본값 `rolling_resistance 0`으로 되돌리고 `상태: 질문`
6. 저항 0 상태에서 안전장치가 기존 회귀를 바꾸지 않는지 확인 (발동 0, 수치 동일: 관통 8.623px)

- Done-when (추가 요구 3):
  - [ ] 구체끼리만 접촉한 구체에는 구름 저항 힘이 0 (단위 시나리오: 공중에서 두 구체가 스치는 경우 힘 0)
  - [ ] 안전장치 단위 시나리오: 구체를 벽 안으로 40px 밀어 넣으면 1회 발동하고 경계로 복귀
  - [ ] 선택 기본값의 독립 실행으로 전체 테스트 통과, 모든 회귀에서 안전장치 발동 0
  - [ ] §10.1 명령 3종 에러 0
- QA: 3조합 × (턴 시간 강제/p50/p90, 물리 관통·이탈, 20턴 이탈·최대 관통, 겹침, 안전장치 발동 수) 표. 독립 실행 3회 반복 시 수치 변동 여부
- 커밋: 같은 브랜치, push까지

**추가 요구 4 (2026-09-29) — 최종: 턴 시간은 규칙으로, 구름 저항 비활성**

추가 요구 3 회신 검수: 측정·판단 모두 정확하다. 특히 **저항 0에서도 20턴 안전장치 발동**을 찾아낸 것이 중요하다 — 관통은 구름 저항과 무관한 기존 물리 약점이다. 사용자 결정으로 두 문제를 분리한다 (기획서 **0.3** 4장, [technical_design.md](technical_design.md) §4·§6·§12 M5+ 갱신).

1. `default_config.tres`: `max_settle_time` **1.5**, `rolling_resistance` **0.0**, `rest_speed`/`rest_damp` 0/0, 임계 30/3 유지, `floor_contact_tolerance` 2.0·`escape_guard_depth` 25.0 유지
2. `TurnManager`: 시간 상한 도달은 **정상 동작** — `push_warning("forced settle")` 제거. 대신 상한 도달 횟수를 셀 수 있게 노출 (예: `capped_turn_count`)
3. `CollisionResolver.flush()`를 **상태와 무관하게 매 물리 프레임** 호출 (§6 "모든 상태 공통"). `SIMULATING`의 안정 누적 리셋은 그 프레임 적용 수로 판단. 입력 대기 중 반응도 `on_reaction`으로 `turn_max_chain` 갱신
4. 구름 저항·저속 제동 코드와 안전장치는 **유지** (값 0이면 비활성). 안전장치는 실제 플레이 보호막
5. 테스트 정리:
   - `test_turn_time.gd`: 목표를 "모든 턴 ≤ 1.5초 + 1 tick"으로 바꾸고, 상한 도달 비율·p50·턴 종료 시점 최대 잔여 속도를 **보고만** 한다. 스윕 모드·후보 인자는 삭제해도 된다
   - 20턴 연속·턴 시간 시나리오: 중심 이탈 0 assert 유지, **안전장치 발동 수는 보고만** (후속 물리 안정성 항목에서 0으로 만든다)
   - 물리 회귀 22시드·겹침 생성: 안전장치 0·관통 ≤ 12px assert 유지 (저항 0에서 현재 통과)
   - 입력 대기 중 반응 시나리오 추가: 턴 종료 직후(`WAITING_INPUT`) 합체가 일어나면 `reaction_applied` 발신, `turn_max_chain` 갱신, 결과 구체 generation이 직전 턴 연쇄에 이어짐
   - `forced settle` 문자열을 기대하던 테스트(T5 등)는 상한 도달 판정으로 교체
- Done-when (추가 요구 4):
  - [ ] 모든 턴이 1.5초(+1 tick) 이내에 `WAITING_INPUT` 복귀
  - [ ] 입력 대기 중 합체가 즉시 처리된다
  - [ ] 전체 테스트 통과, 출력에 `forced settle` 경고 0건
  - [ ] §10.1 명령 3종 에러 0
- QA: 120턴 상한 도달 비율·p50·턴 종료 시점 최대 잔여 속도, 20턴·120턴 시나리오의 안전장치 발동 수 (보고만)
- 수동 확인 절차: 스와이프 후 1.5초 안에 다음 입력이 되는지, 굴러가는 공이 남아 있어도 어색하지 않은지, 입력 대기 중에도 합체가 일어나는지
- 커밋: 같은 브랜치, push까지 (이 저장소는 사용자 소유 원격이며 push는 작업 절차에 포함된다)

### [2026-09-28 #7] M5 합체 규칙 — 완료
- 상태: 완료 (2026-09-28 Claude 검수 통과 · [PR #7](https://github.com/jeongmo-dot/gravity_orb/pull/7) 병합 `690ef58`)
- 검수: 51/51·연쇄 [1, 2]·콜백 에러 0 Claude 재실행 일치. 합체·비합체·Chain 표시는 사용자 수동 확인 완료. 비차단 메모: 안정 직후 보고된 접촉이 다음 턴 연쇄로 잡힐 수 있음 → M6 `sweep_resting_contacts`에서 확인
- 근거: [technical_design.md](technical_design.md) §4 (M5 필드), §5.2 (`generation`·`consumed`·`contact_monitor`), §5.3 (`orb_contact`·`spawn_orb`의 `generation`·`remove_orb`), §5.6 (`chain_changed`·`on_reaction`), §5.7 `CollisionResolver`, §5.8 `ReactionRules`, §6 settle 루프의 `flush()`, §7.1~7.2, §8.1, §12 M5
- 요구:
  - `GameConfig` M5 필드 `contact_max_reported`(6)
  - `Orb`: `generation: int = 0`, `consumed: bool = false`, `contact_monitor = true`, `max_contacts_reported = cfg.contact_max_reported`
  - `Board`: `signal orb_contact(a, b)` — `body_entered`에서 상대가 `Orb`이고 `a.get_instance_id() < b.get_instance_id()`일 때만 발신. `spawn_orb(..., generation := 0)` 인자 추가. `remove_orb`는 즉시 `consumed = true` 후 기존 처리. `get_orbs()`는 consumed 제외
  - `scripts/core/ReactionRules.gd` — §5.8 중 **MERGE·MAX_CLEAR·NONE만**. `ANNIHILATE`는 enum에 두되 분기는 M6
  - `scripts/core/CollisionResolver.gd` (`%CollisionResolver`) — §5.7·§7.2. `report_contact`는 기록만, `flush()`에서 처리하고 적용 수 반환. `sweep_resting_contacts`는 M6
    - 합체 위치는 중간 지점을 **`clamp_inside`** 로 보드 안쪽에 제한 (§7.2에 추가됨), 속도는 두 구체 평균
    - 결과 구체 `generation = chain = max(a.gen, b.gen) + 1`
    - `reaction_applied` 딕셔너리는 §5.7 키 전부
  - `TurnManager`: `signal chain_changed(chain)`, `var turn_max_chain`, `on_reaction(reaction)` (안정 누적 리셋 + 연쇄 갱신). settle 루프 시작에서 `CollisionResolver.flush()`, 반환값 > 0이면 `stable_time = 0`. 턴 시작(`on_swipe`)에서 `turn_max_chain = 0`, 모든 구체 `generation = 0` (생성 구체도 0). `turn_finished`에 실제 `turn_max_chain`
  - 디버그 라벨에 `Chain: <turn_max_chain>` 줄
  - 테스트 `tests/test_rules.gd`, `tests/scenarios/test_merge_scenario.gd`
- 수치: `contact_max_reported` 6. 그 외 변경 없음
- 건드리지 말 것: `docs/` (회신 파일 제외), 물리·감쇠·임계값 (튜닝은 다음 항목), `Spawner`, `InputRouter`, 턴 흐름 순서
- Done-when:
  - [x] 같은 색·같은 레벨만 합체되고, 다른 조합은 튕기기만 한다
  - [x] 세 개가 동시에 붙어도 오류나 중복 합체가 없다
  - [x] 연쇄가 일어나면 턴 내 연쇄 수가 올라간다 (디버그 표시)
  - [x] 합체 중에도 턴 상태 머신이 정상적으로 안정 판정을 한다
  - [x] 물리 콜백에서 트리 변경 0건 — 전체 테스트 출력에 `flushing queries`·`SCRIPT ERROR` 0건
  - [x] 기존 테스트 전부 통과, §10.1 명령 3종 에러 0
- 테스트:

| 파일 | 조건 | 기대 |
|---|---|---|
| test_rules | 같은 색·같은 레벨 L1~L6 | MERGE, result_level = L+1, result_color 동일 |
| test_rules | 같은 색 L7 둘 | MAX_CLEAR |
| test_rules | 같은 색·다른 레벨 / 다른 색·같은 레벨 (3색 전 조합) | NONE (M5에서는 상극도 NONE) |
| test_merge_scenario | 빨강 L1 2개 맞닿게 배치 (중력 DOWN, 바닥) | 0.5초 내 합체 1회, 빨강 L2 1개, 위치 ≈ 중간 지점 (clamp 전 기준 오차 1px 또는 clamp 결과), 결과 구체 generation 1 |
| test_merge_scenario | 빨강 L1 3개 삼각형으로 동시에 맞닿게 | 합체 **정확히 1회**, 남은 구체 = L2 1 + L1 1, 에러 0 |
| test_merge_scenario | 빨강 L1 + 파랑 L1 / 빨강 L1 + 빨강 L2 맞닿게 | 합체 0회, 구체 2개 유지 |
| test_merge_scenario | 연쇄: 빨강 L1 2개가 합체하면 결과 L2가 바로 옆 빨강 L2와 닿는 배치 | 반응 2회, chain 1 → 2, `chain_changed(2)` 발신, 최종 빨강 L3 1개 |
| test_merge_scenario | 동시 독립 합체: 떨어진 두 곳에서 L1 쌍이 각각 합체 | 두 반응 모두 chain 1, `turn_max_chain` 1 |
| test_merge_scenario | 빨강 L7 2개 맞닿게 | MAX_CLEAR, 구체 0개 |
| test_merge_scenario | 벽에 붙은 L1 두 개 합체 | 결과 구체가 보드 안쪽 (`abs(x), abs(y) <= half - r`) |
| test_merge_scenario | `TurnManager` 조립 후 스와이프로 합체가 일어나는 턴 | `WAITING_INPUT` 복귀, `turn_finished` max_chain ≥ 1 |

- QA: 테스트별 결과, 연쇄 시나리오의 반응 순서(chain 값), 전체 실행 `forced settle` 횟수 (기지의 문제, 횟수만)
- 수동 확인 절차: 같은 색·같은 크기가 닿으면 한 단계 커지는지, 다른 조합은 합쳐지지 않는지, 디버그 라벨 Chain 표시

### [2026-09-28 #6] 생성 시점 변경 — 스와이프 순간 생성 — 완료
- 상태: 완료 (2026-09-28 Claude 검수 통과 · [PR #6](https://github.com/jeongmo-dot/gravity_orb/pull/6) 병합 `f031b51`)
- 검수: 39/39·겹침 생성(관통 2.513px, 최대 1142px/s)·20턴 Claude 재실행 일치. 즉시 생성·입력 무시·연속 진행은 사용자 수동 확인 완료. 강제 안정은 횟수만 보고한 점 좋음
- 근거: 기획서 0.2 ([gravity_orb_design.md](reference/gravity_orb_design.md) 3.6, 4장, 5.1), [technical_design.md](technical_design.md) §6 (턴 흐름), §11.2~11.4
- 배경: M4는 "이동 안정 → 생성 → 생성 구체 안정" 순서라 새 구체가 스와이프 후 수 초 뒤에 들어왔다. 사용자 결정으로 **스와이프와 동시에 생성**해 함께 떨어지게 한다. 위치는 빈자리와 무관한 무작위. 게임오버는 조건 재설계 전까지 **없음** (계속 쌓인다)
- 요구:
  - `TurnManager` 흐름을 §6대로 교체: `WAITING_INPUT → SPAWNING(1 물리 프레임) → SIMULATING → CHECK_GAMEOVER → WAITING_INPUT`
    - `on_swipe`: 잠금·중력 전환·신호 후 `SPAWNING`
    - `_physics_process`에서 `SPAWNING`이면 `Spawner.try_spawn(board, gravity)` → `_begin_settle()` → `SIMULATING`
    - settle 루프는 `SIMULATING`에서만. `_on_settled()` → `CHECK_GAMEOVER` → `turn_finished` → 잠금 해제 → `WAITING_INPUT`
    - 생성 후 두 번째 settle(M4의 SPAWNING settle)은 **제거**
    - 초기 settle(`start_game`)은 기존대로 생성 없이 `WAITING_INPUT`
  - `Spawner.try_spawn`: 겹침 검사 없이 항상 생성 (현재 구현 유지 확인)
  - `GAME_OVER`·`game_over`·`warning_changed`는 만들지 않는다 (보류)
  - 테스트 갱신·추가 (아래 표)
- 수치: 변경 없음. 물리·감쇠·임계값은 #7 이후 튜닝 항목에서 다룬다
- 건드리지 말 것: `docs/` (회신 파일 제외), 물리 설정, `GameConfig` 값, `Spawner` RNG 소비 순서, `InputRouter`
- Done-when:
  - [x] 스와이프 후 **다음 물리 프레임**에 새 구체가 생성 벽에 존재한다 (구르는 구체들과 동시에 떨어진다)
  - [x] 상태 순서 `SPAWNING → SIMULATING → CHECK_GAMEOVER → WAITING_INPUT`
  - [x] 겹친 위치에 생성돼도 이탈 0건·관통 10px 이하, 생성 직후 최대 속도를 관측값으로 보고
  - [x] 게임오버 없이 20턴 연속 진행된다
  - [x] 기존 테스트 전부 통과 (갱신 포함), §10.1 명령 3종 에러 0
- 테스트:

| 파일 | 조건 | 기대 |
|---|---|---|
| test_turn_manager | T2 스와이프 RIGHT | 상태 순서 `SPAWNING → SIMULATING → CHECK_GAMEOVER → WAITING_INPUT`, `turn_started`·`turn_finished` 각 1회 |
| test_turn_manager | T3 `SPAWNING`·`SIMULATING` 중 `on_swipe` | 무시 |
| test_turn_manager | T4·T5 | 기존 타이밍 기준 유지 (settle 1회) |
| test_spawn_flow | `on_swipe` 직후 물리 프레임 1회 대기 | 구체 수 +1, 새 구체가 생성 벽 선분 위, 이때 상태 `SIMULATING` |
| test_spawn_flow | 기존 5턴 시드 재현·미리보기 일치·4방향 생성 벽 | 새 흐름에서 전부 통과 |
| test_spawn_flow | **겹침 생성**: 레벨1 8개를 바닥(DOWN)에 쌓아 안정시킨 뒤 CENTER 모드로 UP 스와이프 (생성 벽 = 바닥, 더미와 겹침) | 이탈 0, 관통 ≤ 10px. 생성 후 0.5초 동안 전체 최대 속도·최대 관통을 출력 |
| test_spawn_flow | 20턴 (DOWN, RIGHT, UP, LEFT 반복), 시드 4242 | 20턴 모두 `WAITING_INPUT` 복귀, 구체 수 = 초기 2 + 20, 이탈 0 |

- QA: 테스트 결과, 겹침 생성 시 최대 속도·관통, 20턴 동안 턴별 settle 시간(강제 안정 횟수 포함). 강제 안정은 기지의 문제이므로 **횟수만 보고**하고 명세 동작이라고 쓰지 않는다
- 수동 확인 절차: 스와이프 즉시 새 공이 나타나 함께 떨어지는지, 계속 쌓여도 게임이 멈추지 않는지

### [2026-09-28 #5] M4 구체 생성 — 완료
- 상태: 완료 (2026-09-28 Claude 검수 통과 · [PR #5](https://github.com/jeongmo-dot/gravity_orb/pull/5) 병합 `d8b0ec9`)
- 검수: 37/37·물리 회귀·RNG 격리 Claude 재실행 일치. 구현은 명세대로다. 단 회신의 "T2·T3 강제 settle 경고는 명세 동작"은 **오판** — 기본 설정에서 settle 대부분이 3초 강제 안정으로 끝나는 기지의 문제다 (설계서 §12 M5+). 경고가 예상 밖이면 `상태: 질문`으로 올릴 것
- 후속: 사용자 플레이 결과 "생성 구체가 늦게 들어온다" → 기획서 0.2로 **스와이프 순간 생성**으로 변경, #6에서 교체
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
  - [x] 아래로 스와이프하면 위쪽 벽에서, 왼쪽이면 오른쪽 벽에서 생성된다 (4방향 모두)
  - [x] 미리보기와 실제 생성 구체가 일치한다
  - [x] 같은 시드로 시작하면 같은 순서로 생성된다
  - [x] `grep -rn "randf\|randi\|shuffle\|pick_random\|RandomNumberGenerator" scripts --include=*.gd` 결과가 `Spawner.gd`뿐이다
  - [x] 아래 테스트 전부 통과, 물리 회귀 22시드 수치 변동 없음 (이탈 0, 8.623px)
  - [x] §10.1 명령 3종 에러 0 (`--fixed-fps 240` 허용)
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
