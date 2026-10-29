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
- Done-when 대조 (1차):
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

### [2026-10-30] 대상 #116 — JELLY 마찰 낮추기
- 상태: 완료 — 최신 `origin/main` `da19a0b`에서 항목 브랜치를 만들고 `orb_friction`·`wall_friction`만 `0.6 → 0.3`으로 변경함. 고정 시드 가로 흐트림 더미, 네 마찰 후보 물리·20시드 자동 플레이, 새 해시, 전체 테스트·Debug 빌드·두 비율 전체 캡처를 완료함
- 브랜치 / PR: `codex/lower-jelly-friction` / PR 생성 후 링크 갱신
- 변경 파일: `config/{GameConfig.gd,default_config.tres}`, `tests/{test_config.gd,test_jelly_regression.gd,run_jelly_physics_measurement.ps1,run_jelly_physics_autoplay.ps1,run_jelly_friction_sweep.ps1}`, `tests/spike/{capture_screens.gd,run_jelly_physics_measurement.gd,run_jolt_3d_measurement.gd}`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] `orb_friction=0.3`, `wall_friction=0.3`을 리소스와 `GameConfig.gd` 기본값에 동일 적용 — 자동 설정 회귀
  - [x] #115의 중력 `3600`, 레벨 보정 `0.05`, 공·벽 튕김 `0.06`, JELLY 회전 잠금과 나머지 설정은 유지 — 자동 전체 회귀 및 변경 차이 확인
  - [x] 쌓인 판 측정·캡처의 40개 격자 x좌표를 고정 시드 `11620261030`으로 각각 `±10px` 흐트림 — 자동 로그·캡처
  - [x] 마찰 `0.15/0.3/0.45/0.6`의 흐트린 더미, 바닥 500px/s 미끄럼, 20시드 자동 플레이, 색 효과 네 가지를 같은 조건으로 측정 — 자동, 아래 표
  - [x] 새 JELLY 해시에서 시드 `1085050`이 사건 7종을 각각 1회 통과하고 렌더링 켬/끔 동일 — 자동
  - [x] 마찰 `0.3`으로 두 화면비 전체 캡처를 마지막에 생성하고 더미·오른쪽 중력 장면을 직접 관측 — 자동 캡처 + 직접 관측
  - [x] 일반·장기·성능 테스트, 소스/내보낸 Debug 스모크, Debug 빌드 통과. Release 빌드는 미실행
- 후보별 물리 측정 (`Godot 4.8-dev3 Standard`, Jolt, 120Hz, 더미 40개·가로 흐트림 시드 `11620261030`):
  - 마찰 `0.15`: 더미 너비/높이 `961.773/591.850px`, 오른쪽 중력 안정 `2.5000초`; 바닥 500px/s 정지 `0.9417초·204.110px`; 색 효과 최대 이동 빨강/파랑/보라/노랑 `356.252/69.059/239.499/62.114px`
  - 마찰 `0.3` **설정값**: 더미 `802.451/483.883px`, 오른쪽 안정 `1.4500초`; 바닥 정지 `0.5333초·106.888px`; 색 효과 `354.092/35.119/130.817/62.114px`
  - 마찰 `0.45`: 더미 `668.115/489.713px`, 오른쪽 안정 `1.4500초`; 바닥 정지 `0.3917초·71.985px`; 색 효과 `302.841/23.300/88.358/62.114px`
  - 마찰 `0.6` (#115 기준): 더미 `596.290/391.612px`, 오른쪽 안정 `1.3500초`; 바닥 정지 `0.3250초·54.023px`; 색 효과 `230.597/17.293/66.426/62.114px`
  - 네 후보 모두 더미가 5초 강제 종료 없이 안정됐고 색 효과 네 종류의 대상 이동거리는 0보다 큼. 미끄럼 정지는 수평 속도 `≤1px/s`가 12프레임 유지된 시점으로 기록함
- 후보별 20시드 자동 플레이 (`101~120`, 같은 방향 패턴, 120Hz, 400턴 상한):
  - 마찰 `0.15`: 게임오버 `16/20`, 게임오버 판 평균 `350.562턴·483,976.5점` (4판은 400턴 상한으로 평균 제외), 평균 턴 `1.5052초`, 강제 안정 `6,920턴·95.991%`, 턴당 합체 `3.6586`, 모든 공 쌍 최대 침투 `34.076px` (`merge_immediate`, 시드 109), 이탈 `0`
  - 마찰 `0.3` **설정값**: 게임오버 `20/20`, 평균 `272.350턴·263,684.7점`, 평균 턴 `1.4770초`, 강제 안정 `4,587턴·84.211%`, 턴당 합체 `2.7648`, 최대 침투 `15.846px` (`normal_pile`, 시드 119), 이탈 `0`
  - 마찰 `0.45`: 게임오버 `20/20`, 평균 `218.150턴·101,182.25점`, 평균 턴 `1.4359초`, 강제 안정 `2,807턴·64.336%`, 턴당 합체 `2.1813`, 최대 침투 `22.116px` (`merge_immediate`, 시드 102), 이탈 `0`
  - 마찰 `0.6`: 게임오버 `20/20`, 평균 `191.600턴·49,208.5점`, 평균 턴 `1.3912초`, 강제 안정 `1,913턴·49.922%`, 턴당 합체 `1.8672`, 최대 침투 `9.853px` (`normal_pile`, 시드 105), 이탈 `0`
  - `0.3`은 `0.6`보다 평균 생존 `+80.75턴`, 점수 약 `5.36배`, 턴당 합체 약 `1.48배`로 회복됐지만 평균 턴 시간·강제 안정 비율과 관측 최대 침투가 증가함. 수치는 임의 조정하지 않고 명세의 `0.3`을 설정함
- JELLY 새 기준 해시:
  - 시드 `1085050`, SHA-256 `d1f7ca9a50c6da515e15421bcea76ed96f6f15fad2e2498cc6626e4aa3cca3a1`, 렌더링 켬/끔 동일
  - 사건 수: 흡수 레벨 유지 1, 흡수 레벨 상승 1, L5 대폭발 1, L7이 L6 흡수 1, MAX CLEAR 1, FINAL MOVE 성공 1, 실패 1
- 최종 캡처 관측:
  - `tests/capture_screens.ps1` → `540×960`, `540×1170` 각 60장, 합계 120장; 착지 `44~53` PNG SHA 고유 각 `10/10`
  - 두 비율 `55_jelly_motion_rest`: 고정 시드로 흐트린 실제 40개 L1이 네모 블록 대신 바닥과 왼쪽 벽을 따라 불규칙하게 퍼짐. 실제 공 접촉쌍 `45`, 바닥 접촉 `14`, 벽 `12`, 코너 `1`
  - 두 비율 `56_jelly_motion_right`: 같은 더미에서 0.22초 뒤 이동 `40/40`, 접촉쌍 `42`, 최대 속도 `764.594px/s`; 오른쪽으로 휜 중력 격자와 이동 중인 더미를 직접 확인
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `tests/run_tests.ps1` → 일반 `285/285`, 장기 `5/5`, 성능 `5/5`, 합계 `295/295`, 종료 코드 0, 총 `62.174초`; 장기 표준 22시드 최대 침투 `9.423px`, 이탈·발산 `0`
  - 소스 기본·`--mode=jelly` `--quit-after 300` → 각각 종료 코드 0, 오류 표식 0건
  - `tools/build_windows.ps1 -Debug` → 종료 코드 0, `version=0.16.0`, Debug exe `104,947,088`바이트, 다른 버전 파일 18개 보존. 내보낸 Debug 기본·JELLY 스모크 각각 종료 코드 0. Release 미실행
  - 규칙 검색 → `Input`/`InputEvent`는 `InputRouter.gd`·`Haptics.gd`만, 기존 전용 지역 RNG 밖 신규 런타임 전역 난수 사용 0건, `git diff --check` 오류 0건
  - 사용자 `save.cfg`는 `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D`로 #115 전후와 동일
- 수동 확인 절차:
  1. `tests/capture_screens.ps1` 후 두 화면비의 `55_jelly_motion_rest`를 연다 → 40개 L1이 규칙적인 네모 블록이 아니라 바닥과 왼쪽 벽을 따라 높낮이가 다른 불규칙한 더미로 퍼져야 한다.
  2. 같은 폴더의 `56_jelly_motion_right`를 연다 → 동일한 색·배치의 더미가 오른쪽으로 움직이는 중이고 중력 격자가 오른쪽으로 휘어야 한다.
  3. 실제 JELLY를 여러 턴 플레이한다 → #115의 빠른 낙하·작은 반동·회전 잠금은 유지되면서, 공끼리와 벽에서 `0.6` 때보다 덜 붙고 미끄러져 조금 더 넓게 퍼져야 한다.
- 결정 사항: 고정 시드는 항목 번호와 날짜를 식별할 수 있는 `11620261030`으로 정하고 측정·캡처 양쪽에 동일 적용했다. 측정의 후보값은 프로세스 인자로만 덮어쓰며 설정 리소스에는 `0.3`만 기록했다. 중력·튕김·회전 잠금, `JELLY_*`, 규칙·점수·난도, `stable_*`·`max_settle_time`, 색 효과 세기와 다른 연출은 변경하지 않았다
- 남은 것 · 질문: 설정값 `0.3`에서 20시드 모든 공 쌍 최대 침투가 `15.846px`로 #115의 `0.6` `9.853px`보다 증가했고 강제 안정 비율도 `84.211%`다. 명세대로 추가 물리·난도 수치는 조정하지 않았으며 최종 합격/불합격과 후속값 판정을 요청함

### [2026-10-30] 대상 #115 — JELLY 물리: 빠른 낙하·작은 반동·회전 잠금
- 상태: 완료 — `origin/main` `7730c00`에서 항목 브랜치를 만들고 명세의 중력·반발·마찰 6개 값과 JELLY 평면 회전 잠금만 반영함. 물리값 전후 측정, 같은 20시드 자동 플레이, 두 비율 전체 캡처, 새 물리 기준 해시, 전체 테스트와 Debug 빌드를 완료함
- 브랜치 / PR: `codex/jelly-physics` / https://github.com/jeongmo-dot/gravity_orb/pull/115
- 변경 파일: `config/{GameConfig.gd,default_config.tres}`, `scripts/spike/Orb3D.gd`, `tests/{test_config.gd,test_jelly_regression.gd,test_jolt_3d.gd,run_jelly_physics_measurement.ps1,run_jelly_physics_autoplay.ps1}`, `tests/spike/{JellyPhysicsMeasurement.tscn,run_jelly_physics_measurement.gd}`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] `gravity_strength=3600`, `gravity_level_scale=0.05`, `orb_bounce=0.06`, `wall_bounce=0.06`, `orb_friction=0.6`, `wall_friction=0.6`을 리소스와 `GameConfig.gd` 기본값에 동일 적용 — 자동 설정 회귀
  - [x] JELLY 몸만 `axis_lock_angular_z=true`, 유지된 CLASSIC 분기는 기존처럼 false — 자동 (`test_jelly_orbs_lock_plane_rotation_without_changing_classic`), 새 설정 필드 없음
  - [x] §12-ONE.8 측정 1~6을 변경 전 `origin/main`과 변경 후 같은 조건으로 실행 — 자동, 아래 수치. 반발비 변경 후 `0.1198~0.1213`으로 목표 `0.12±0.03` 안
  - [x] 두 비율의 착지 `44~53`, 실제 40개 더미 `55`, 같은 더미 오른쪽 중력 `56`을 마지막 전체 캡처에서 생성하고 직접 관측 — 자동 캡처 + 직접 관측
  - [x] 규칙 사건 7종을 모두 지나는 시드 `1085050`을 유지하고, 물리 6개 값과 JELLY 회전 잠금을 해시 입력에 넣어 새 기준 SHA-256 생성. 렌더링 켬/끔 동일 — 자동
  - [x] 일반·장기·성능 전체 테스트, 소스/내보낸 Debug 스모크, Debug 빌드 통과. Release 빌드는 미실행
- 물리 전후 측정 (`Godot 4.8-dev3 Standard`, Jolt, 120Hz):
  - 판 가로지르기 시간 / 닿는 속도: L1 `1.0417초 / 1669.43px/s` → `0.7333초 / 2405.49px/s`; L4 `0.7333 / 2104.81` → `0.6333 / 2403.72`; L7 `0.5667 / 2345.58` → `0.5583 / 2404.41`
  - L1 튐: 첫/둘째 높이 `45.69 / 2.42px` → `10.50 / 0.00px`; 실제 첫/둘째 반발비 `0.2496 / 0.2496` → `0.1213 / 0.1198`
  - L7 튐: 첫/둘째 높이 `36.03 / 1.44px` → `9.73 / 0.00px`; 실제 첫/둘째 반발비 `0.2496 / 0.2496` → `0.1198 / 0.1198`. 둘째 높이 0은 되튄 속도는 검출됐지만 120Hz 표본에서 접촉 위치보다 위로 분리되지 않은 관측값
  - 40개 L1 더미: 정지 너비/높이 `960.04 / 187.75px` → `437.40 / 255.78px`; 오른쪽 중력 뒤 안정까지 `4.0333초` → `1.2250초`; 두 조건 모두 5초 강제 종료 없이 안정
  - 색 효과 대상 최대 이동거리: 밀기(빨강) `356.25` → `230.60px`, 흔들기(파랑) `137.35` → `17.29px`, 끌기(보라) `282.69` → `66.43px`, 띄우기(노랑) `123.93` → `62.11px`. 전부 0보다 크고 최종 캡처 `13`·`14`·`16`·`17`에서 별가루/판 흔들림/끌기/띄우기 연출이 보임
- 20시드 자동 플레이 전후 (`101~120`, 같은 방향 패턴, 120Hz, 400턴 상한):
  - 평균 스와이프→입력 재개 `1.5148` → `1.3912초`; 1.5초 강제 안정 `6716턴, 99.305%` → `1913턴, 49.922%`
  - 턴당 합체 `3.4497` → `1.8672`
  - 게임오버 `19/20` → `20/20`; 게임오버 판만의 평균 턴 `334.89` → `191.60`, 평균 점수 `462,848.68` → `49,208.50`. 변경 전 1판은 400턴 상한까지 게임오버가 아니어서 게임오버 평균에서 제외
  - 20시드 턴 종료 모든 공 쌍의 최대 침투 `27.744` → `9.853px`; 변경 후 10px 이하. 별도 장기 22시드 표준 더미 최대 침투 `9.423px`. 판 밖 이탈 전후 모두 `0`, 중단 `0`
  - 관측상 강제 안정과 관통은 줄었지만 턴당 합체·생존 턴·점수가 크게 줄어 판이 더 빨리 차는 위험이 실제로 나타남. 명세대로 밸런스값은 추가 조정하지 않았고 최종 판정/후속 수치는 Claude에 남김
- JELLY 새 물리 기준 해시:
  - 시드 `1085050`, SHA-256 `88cc180cae29a69f766a3ad87f9faabfccfd7edf6592ab218988f6346a84c7a0`, 렌더링 켬/끔 동일
  - 사건 수: 흡수 레벨 유지 1, 흡수 레벨 상승 1, L5 대폭발 1, L7이 L6 흡수 1, MAX CLEAR 1, FINAL MOVE 성공 1, 실패 1
  - 해시 입력에 중력·반발·마찰 6개 값과 `jelly_axis_lock_angular_z`를 추가해 이후 물리 기준 변경도 회귀로 검출
- 캡처 관측:
  - `tests/capture_screens.ps1` 최종 → `540×960`, `540×1170` 각 60장, 합계 120장, 착지 PNG SHA 고유 각 `10/10`
  - 두 비율 `44~53`: 실제 L7이 위에서 빠르게 낙하해 5번에서 바닥 접촉, 6번 접촉 유지, 7번 짧은 반동, 8~10번 눌림이 복원돼 정지. 몸체 x/y 배율은 `1.000000/1.021828`, `1.000000/1.099876`, `1.000000/1.167054`, `1.000000/1.184575`, `1.000000/1.152539`, `1.000000/1.093002`, `1.023458/1.011257`, `1.064960/1.000000`, `1.031193/1.000000`, `1.003104/1.000000`
  - 두 비율 `55`: 실제 접촉쌍 56, 바닥 8, 벽 4, 코너 1인 40개 더미가 이전처럼 넓게 굴러 퍼지지 않고 왼쪽 아래에 높게 쌓임. `56`: 0.22초 뒤 이동 젤리 `40/40`, 접촉쌍 56, 최대 속도 `763.968px/s`; 같은 더미가 오른쪽으로 이동하고 중력 격자가 오른쪽으로 휜 모습 직접 확인
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `tests/run_tests.ps1` → 일반 `285/285`, 장기 `5/5`, 성능 `5/5`, 합계 `295/295`, 종료 코드 0, 총 `64.318초`
  - 소스 기본·`--mode=jelly` `--quit-after 300` → 각각 종료 코드 0, 오류 표식 0건
  - `tools/build_windows.ps1 -Debug` → 종료 코드 0, `version=0.16.0`, Debug exe `104,947,104`바이트, 다른 버전 파일 18개 보존. 내보낸 Debug 기본·JELLY 스모크 각각 종료 코드 0. Release 미실행
  - 규칙 검색 → `Input`/`InputEvent`는 `InputRouter.gd`·`Haptics.gd`만, 기존 전용 RNG 밖 신규 전역 난수 사용 0건, `git diff --check` 오류 0건
  - 사용자 `save.cfg`는 `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D`로 이전 #112 보고와 동일
- 수동 확인 절차:
  1. `tests/capture_screens.ps1` 후 두 화면비의 `44~53`을 순서대로 연다 → L7이 빠르게 떨어져 5번에서 닿고 한 번만 살짝 반동한 뒤 10번까지 붙어 안정되며, 10장 모두 위치·몸체 비율이 달라야 한다.
  2. `55_jelly_motion_rest`를 연다 → L1 40개가 구르며 판 전체로 퍼지지 않고 바닥·왼쪽 벽·코너에 접촉한 높이 있는 더미여야 한다. `56_jelly_motion_right`를 열면 같은 더미가 오른쪽으로 이동 중이고 격자도 오른쪽 중력을 보여야 한다.
  3. `13_jelly_merge_effect`, `14_jelly_absorption_effect`, `16_jelly_jackpot_effect`, `17_jelly_max_effect`와 실제 플레이를 본다 → 회전 잠금·마찰 증가 뒤에도 파랑 흔들기, 초록 밀기, 보라 끌기, 노랑 띄우기 연출과 물리 이동이 보여야 한다.
  4. 편집기에서 여러 번 중력을 바꾼다 → L1이 약 0.73초, L4/L7이 약 0.56~0.63초로 벽에 닿고, 첫 반동만 약 10px 보인 뒤 구르지 않고 더미에 붙어야 한다.
- 결정 사항: 회전 잠금은 요구의 “젤리 몸” 범위에 맞춰 JELLY일 때만 켜고 숨겨진 CLASSIC 분기의 기존 회전은 보존했다. 물리 전후 측정은 명세값을 직접 적용한 독립 프로세스와 변경 전 `origin/main` 임시 워크트리를 사용했다. `JELLY_*`, `orb_linear_damp`, `stable_*`, `max_settle_time`, 규칙·점수·흡수·색 효과 세기·다른 연출은 변경하지 않았다
- 남은 것 · 질문: 같은 20시드에서 생존 턴과 점수가 크게 감소했다. 수치 변경 권한은 Claude에 있으므로 현재 명세값 그대로 PR에 올리며, 최종 합격/불합격 및 난도 후속 여부 판정을 요청함

### [2026-10-27] 대상 #112 — 호령·점수 팝업 얼굴 밖 배치와 배경 유성 삭제
- 상태: 완료 — `origin/main` 최신 상태에서 호령을 보드 위 빈 공간으로 옮기고, 점수 팝업 글자 크기를 70%로 줄여 합쳐진 젤리의 오른쪽을 우선하되 보드·얼굴 겹침이 더 적은 방향을 고르도록 변경함. 배경 유성 및 남아 있던 미사용 동명 함수까지 삭제함
- 브랜치 / PR: `codex/callout-popup-layout` / https://github.com/jeongmo-dot/gravity_orb/pull/114
- 변경 파일: `scripts/core/OrbVisual.gd`, `scripts/fx/SpaceBackdrop.gd`, `scripts/ui/{Hud,ScorePopup}.gd`, `tests/{capture_screens.ps1,test_callouts.gd,test_score_popups.gd,test_space_board_visuals.gd}`, `tests/spike/capture_screens.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] 호령 NICE/GREAT/AMAZING/INCREDIBLE/UNSTOPPABLE을 콤보 아래와 투영된 보드 위 사이 가운데에 배치하고, 상승 경로 전체가 콤보·보드와 겹치지 않게 가용 높이에 맞춰 글자 크기를 제한 — 자동 배치 테스트 + 두 비율 실제 창 캡처 + 직접 관측
  - [x] 호령 색·금색 반짝임·소리·발동 조건·지속 시간은 유지 — 기존 호령 회귀 5종과 성능 시험 통과
  - [x] 점수 글자 크기를 기존의 `70%`로 축소하고, 실제 글리프의 확대·상승 전체 경로를 기준으로 결과 젤리의 오른쪽 `r + 12px`를 우선 배치. 오른쪽이 보드 밖이거나 다른 얼굴을 더 덮으면 왼쪽·위·아래 후보 중 보드 안이면서 얼굴 합계 겹침이 가장 작은 후보를 선택 — 자동 (`test_3d_reaction_popup_starts_right_of_orb_and_stays_inside_board`) + 실제 창 캡처
  - [x] 팝업 표시 시간·60px 상승·사라짐·같은 프레임 근접 점수 병합은 유지 — 자동 점수 팝업 회귀 전체 통과
  - [x] `SpaceBackdrop.gd`의 유성 주기·지속·셰이더 계산·그리기를 삭제하고, 사용되지 않던 `_draw_meteor`도 제거해 `scripts/`, `scenes/`의 대소문자 무시 `meteor` 검색 0건 — 자동 검색
  - [x] 두 비율에서 호령 단계별 5장, 작은 팝업, 큰 팝업, 붐비는 판 팝업을 포함해 각 60장·총 120장을 마지막 단계에 전체 캡처 — 자동 + 직접 관측
  - [x] 전체 테스트, 소스 스모크, Debug 빌드, JELLY 기준 해시 불변 확인 — 자동
- 겹침 관측:
  - 두 화면비 모두 호령 ↔ 얼굴 최대 비율 `0.0000`, 겹침 `0.000초 / 1.000초`; 호령 ↔ 보드 최대 비율 `0.0000`, 겹침 `0.000초 / 1.000초`
  - 점수 팝업은 투명 컨트롤 전체가 아닌 실제 글리프 사각형으로 다시 측정. 붐비는 5×5 판에서 두 화면비 모두 얼굴 최대 비율 `1.0000`, 겹침 `0.892초 / 1.000초`, 보드 밖 최대 면적 `0.000px²`. 작은 얼굴 하나를 글자가 완전히 덮는 순간은 남지만, 캡처 시점에는 반응 위치 중앙이 아니라 오른쪽 후보의 얼굴 사이 빈 공간에 표시됨
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `tests/run_tests.ps1` 최종 → 일반 `284/284`, 장기 `5/5`, 성능 `5/5`, 합계 `294/294`, 종료 코드 0, 총 `62.113초`; 호령 p50/p95 `1/1µs`, 점수 팝업 p50/p95 `16/17µs`
  - JELLY 회귀 기준 → 시드 `1085050`, 사건 7종 모두 1회, SHA-256 `2891601066178f822af63ef863edf9f40f82933979680ea5196ebe0033fa62a8` 유지
  - 소스 기본·`--mode=jelly` `--quit-after 300` → 각각 종료 코드 0, 오류 표식 0건
  - `tools/build_windows.ps1 -Debug` → 종료 코드 0, `version=0.16.0`, exe `104,946,816`바이트, 다른 버전 파일 18개 보존. Release 빌드는 미실행
  - `tests/capture_screens.ps1` 최종 → `540×960`, `540×1170` 각 60장, 총 120장, 종료 코드 0; 착지 띠 PNG 고유 각 `10/10`
  - 규칙 검색 → 허용 파일 밖 `Input`/`InputEvent` 신규 사용 0건, 기존 전용 RNG 밖 신규 전역 난수 사용 0건, `scripts/`·`scenes/` `meteor` 0건, `git diff --check` 오류 0건
- 수동 확인 절차:
  1. 두 화면비의 `57_callout_nice`, `34_callout_great`, `58_callout_amazing`, `35_callout_incredible`, `59_callout_unstoppable`을 연다 → 다섯 호령이 콤보 표시 아래·보드 위 빈 공간 가운데에 있고 보드 선·젤리 얼굴과 겹치지 않으며 단계별 색과 금색 반짝임이 유지되어야 한다.
  2. `36_popup_merge`, `37_popup_blast_big`을 연다 → 작은 흰 점수와 큰 금색 점수가 기존보다 70% 크기로 젤리 얼굴이 아닌 인접 빈 공간에 있고, 큰 점수의 수식·반짝임이 유지되어야 한다.
  3. `60_popup_crowded`을 연다 → `+1,280`이 중앙 반응 젤리 위가 아니라 그 오른쪽의 얼굴 사이에 보이고 보드 밖으로 나가지 않아야 한다.
  4. 게임을 30초 이상 두고 배경을 본다 → 별·성운·시차는 유지되고 왼쪽에서 지나던 흰 대각 유성은 나타나지 않아야 한다.
- 결정 사항: 후보 판정은 보이지 않는 308×126 컨트롤 전체가 아니라 실제 글리프·외곽선이 1.1배 팝인하고 60px 상승하는 전체 사각형을 사용했다. 같은 프레임 근접 팝업 병합은 시각 배치점이 아니라 원래 반응 위치 40px 기준으로 유지했다. 새 밸런스 수치·공개 신호/API·게임 규칙·점수·효과음은 변경하지 않았다
- 남은 것 · 질문: 붐비는 판의 아주 작은 얼굴은 팝업이 떠오르는 도중 최대 100% 덮이는 순간이 `0.892초` 동안 관측됐다. 명세는 이 값의 보고만 요구하며 허용 기준은 정하지 않았으므로 수치를 그대로 보고하고 최종 판정은 Claude에 남김

### [2026-10-26] 대상 #108 — JELLY 테스트·캡처 복원과 검수 빈틈 보완
- 상태: 완료 (추가 요구 1 반영) — 레거시 네 모드 태그에서 JELLY에 필요한 호령 테스트와 화면을 선별 복원하고, 규칙 경로 해시·누수 진단·HUD 겹침 계측·빌드 보존 장치를 추가함. `44~53`, `55`, `56`은 수동 배치가 아닌 실제 물리 낙하·접촉·복원·중력 전환으로 다시 캡처함. 런타임 코드·수치·사용자 저장 파일은 변경하지 않음
- 브랜치 / PR: `jelly-test-capture-recovery` / https://github.com/jeongmo-dot/gravity_orb/pull/113
- 변경 파일: `tests/{test_callouts.gd,test_jelly_regression.gd,test_build_script.gd,capture_screens.ps1}`, `tests/spike/capture_screens.gd`, `tools/build_windows.ps1`, `docs/{jeongmo_codex_to_claude.md,archive/codex_to_claude_001-100.md}`
- Done-when 대조:
  - [x] BLITZ 전용 검사는 되살리지 않고 JELLY 호령 5종을 복원 — 자동. 턴 호령 연쇄당 1회, JELLY 미리보기·새 젤리 이름/그림, SFX 음소거·단계별 음높이, 호령 끄기와 상태 보존, 프레임 비용을 각각 검사
  - [x] JELLY 캡처 31장을 추가해 두 화면비 각 56장, 총 112장으로 복원 — 자동 캡처 + 직접 관측. BLITZ·SLIME·CLASSIC 행성 전용 장면은 추가하지 않음
  - [x] 흡수(레벨 유지·상승), L5 대폭발, L7이 L6 흡수, MAX CLEAR, FINAL MOVE 성공·실패를 한 고정 시드 경로에서 모두 지나고 렌더링 켬/끔 마지막 해시가 같음을 고정 기준으로 추가 — 자동 (`test_jelly_regression`)
  - [x] `ObjectDB instances leaked`를 verbose로 재현해 `AudioStreamPlaybackWAV`가 테스트 종료 직전 SFX 재생에서 남는 것을 확인. 비음향 테스트·캡처는 SFX를 재생하지 않고 음향 테스트는 voice를 정리한 뒤 두 프레임 대기하도록 수정해 복원 테스트와 마지막 캡처에서 경고 0건 — 자동
  - [x] 붐비는 판에서 호령/점수 팝업과 젤리 얼굴의 사각형 겹침을 1초 동안 계측. 두 화면비 모두 최대 비율 `1.0000`, 겹침 `0.908초 / 1.000초`; 위치·크기는 바꾸지 않고 수치만 보고
  - [x] 옛 `57_jelly_full_right`의 보드 왼쪽 흰 줄은 `SpaceBackdrop.gd` 배경 셰이더의 `meteor`로 확인 — 30초 주기 중 0.6초 동안 왼쪽에서 오른쪽 아래로 지나는 유성 배경 연출
  - [x] 회신 #100 이하를 원문 그대로 `docs/archive/codex_to_claude_001-100.md`로 이동. 옮긴 본문 SHA-256 `72E6E04F4BE4980BAE373F208594A56C6B1240994E73267F9EE97DE3081D5334`; 현재 회신은 #101부터 유지
  - [x] 사라진 Release 빌드 조사와 재발 방지 — 아래 경위. 빌드 스크립트에 다른 버전 경로·크기 전후 검사를 넣고 정적 회귀 테스트와 실제 Debug 빌드로 확인. 없어진 파일은 다시 만들지 않음
  - [x] 전체 래퍼·소스/내보낸 Debug 스모크·Debug 빌드·두 비율 전체 캡처·저장 파일 불변을 확인 — 자동
- 추가 요구 1 대조:
  - [x] `44~53`을 실제 L7 RigidBody3D 한 개가 `y=-330`에서 낙하해 바닥과 접촉하고 반동·복원하는 연속 10장으로 교체 — 자동 실제 창 캡처 + 직접 관측. 캡처 도구가 10개 물리 상태와 5개 이상 몸체 비율을 요구하고, PowerShell이 두 화면비 각각 PNG SHA-256 고유 `10/10`을 검사
  - [x] 실제 물리 프레임의 몸체 `scale x/y` 기록 — 두 화면비 동일하게 `01 1.000000/1.020989`, `02 1.000000/1.096035`, `03 1.000000/1.165135`, `04 1.000000/1.184121`, `05 1.000000/1.152720`, `06 1.000000/1.093151`, `07 1.023402/1.011359`, `08 1.064934/1.000000`, `09 1.018799/1.000000`, `10 1.006299/1.000000`
  - [x] 첫 실제 접촉은 5번 프레임에서 검출(`contacts=1`), 6번도 접촉 유지 후 7~9번 반동, 10번은 `y=340`, 속도 `0`, 접촉 `1`로 안정화. 직접 관측에서 1~4 낙하 세로 늘어남, 5~6 접촉, 7~9 가로 눌림·반동, 10 안정화가 서로 다른 화면으로 보임
  - [x] `55`를 실제 L1 젤리 40개가 중력 순환 후 아래로 쌓인 물리 더미로 교체 — 실제 젤리 접촉쌍 `54`, 바닥 접촉 `17`, 벽 접촉 `4`, 바닥+벽 코너 접촉 `2`. 모두 0보다 커야 캡처 성공
  - [x] 같은 더미를 오른쪽 중력으로 바꾸고 `0.22초` 뒤 `56` 캡처 — 이동 젤리 `39/40`, 실제 접촉쌍 `56`, 최대 속도 `403.376`; 직접 관측에서 배경 중력 변형과 더미 이동 상태를 확인
  - [x] 런타임 코드·설정값은 바꾸지 않고 캡처/검증 코드와 회신만 변경. `CollisionResolver`는 캡처 중에만 멈춰 실제 접촉 더미가 반응 합체로 사라지지 않게 하고 종료 전에 대기 상태로 복원
- 복원 테스트 이름:
  - `test_jelly_turn_callout_stages_fire_once_per_chain`
  - `test_jelly_preview_and_unlock_use_jelly_art_and_names`
  - `test_callout_sound_uses_sfx_mute_and_stage_pitch`
  - `test_callout_toggle_hides_callout_and_preserves_jelly_state_hash`
  - `test_callout_frame_cost_report` — 성능 묶음 4개에서 5개로 복구
- 캡처 옛 이름 → 새 이름 대응:
  - `19_settings` → `26_settings`, `20_start_no_record` → `27_start_no_record`, `16_gravity_switch` → `28_gravity_switch`, `17_board_danger` → `29_board_danger`, `18_board_blocked` → `30_board_blocked`
  - `44_turn_ready` → `31_turn_input_ready`, `45_turn_busy_a/b` → `32_turn_input_busy`, `46_turn_rejected` → `33_turn_input_rejected`
  - `30_callout_great_a/b` → `34_callout_great`, `31_callout_unstoppable_a/b` → JELLY 턴 호령 `35_callout_incredible`, `32_popup_merge` → `36_popup_merge`, `33_popup_blast_big` → `37_popup_blast_big`
  - `53_jelly_look_{levels,crowded,max,stretch,absorption,unlock}` → `38~43_jelly_look_*`
  - `55_jelly_motion_land_01~10` → `44~53_jelly_motion_land_01~10`, `55_jelly_motion_breathe_max` → `54_jelly_motion_breathe_max`, `55_jelly_motion_rest` → `55_jelly_motion_rest`, `55_jelly_motion_right` → `56_jelly_motion_right`
- JELLY 회귀 관측:
  - 시드 `1085050`, 렌더링 켬/끔 SHA-256 `2891601066178f822af63ef863edf9f40f82933979680ea5196ebe0033fa62a8`
  - 사건 수: 흡수 레벨 유지 1, 흡수 레벨 상승 1, L5 대폭발 1, L7이 L6 흡수 1, MAX CLEAR 1, FINAL MOVE 성공 1, 실패 1
- 이전 빌드 파일 조사:
  - Git 이력에서 최초 스크립트 `ec02c6e`는 출력 폴더 전체를 `Remove-Item ... -Recurse -Force`로 지웠으나, `87b75cc`(2026-10-11 19:27 +09:00)에서 같은 버전 파일만 지우도록 이미 교체됨. #100(2026-10-24)에서 0.11.1·0.13.0·0.13.1·0.14.0 Release 13개 유지를 기록했으므로 이 옛 구현이 이번 소실의 직접 명령일 수는 없음
  - PowerShell 기록·Codex 실행 기록·Git 이력에서 10-24~10-25 사이 `build/windows/` 옛 파일을 지운 정확한 명령은 찾지 못함. 현재 Release에는 0.15.0 이후만 있지만 Debug 폴더에는 0.11.1·0.13.0·0.13.1·0.14.0이 모두 남아 있어 전체 `build/` 삭제가 아니라 Release 경로만 대상으로 한 외부/수동 정리였다는 범위까지만 확인
  - 재발 방지: 빌드 시작 전 다른 버전의 경로·크기를 스냅샷하고 내보내기 후 누락/크기 변경이면 실패. `test_windows_build_preserves_other_version_artifacts`가 다른 버전 보존·재귀 출력 폴더 삭제 금지 계약을 검사. 이번 Debug 빌드에서 보존 대상 18개, 기존 Release 12개 SHA-256 변경 0건
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `tests/run_tests.ps1` 최종 → 일반 `283/283`, 장기 `5/5`, 성능 `5/5`, 합계 `293/293`, 종료 코드 0, 총 `69.106초`; 호령 p50/p95 `1/1µs`
  - 복원 테스트 verbose 재검증 → 호령 `5/5`, 새 JELLY 해시 `1/1`, `ObjectDB instances leaked` 0건
  - 소스 기본·`--mode=jelly` `--quit-after 300` → 각각 종료 코드 0, 오류 표식 0건
  - `tools/build_windows.ps1 -Debug` → 종료 코드 0, `version=0.16.0`, exe `104,940,432`바이트, 다른 버전 18개 보존; 내보낸 Debug 기본·JELLY 스모크 각각 종료 코드 0
  - `tests/capture_screens.ps1` 최종 → 두 비율 각 56장, 총 112장, 종료 코드 0. 두 비율 모두 실제 낙하 PNG 고유 `10/10`, 물리 상태 고유 `10/10`, 몸체 비율 고유 `10종`; 실제 더미 접촉쌍·바닥·벽·코너 접촉과 오른쪽 중력 이동 수치를 확인. 설정·기록 없는 시작·중력/위험/막힘·입력 3상태·호령/팝업·JELLY 외형/움직임을 직접 확인; 오류 표식·ObjectDB 누수 0건
  - 사용자 `save.cfg`는 검증 전후 `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D` 동일
  - 규칙 검사 → 새 허용 밖 `Input`/`InputEvent` 호출 0건, 새 전역 난수 호출 0건, `git diff --check` 오류 0건
- 수동 확인 절차:
  1. `tests/capture_screens.ps1` 뒤 두 화면비의 `44~53`을 순서대로 연다 → 실제 젤리가 위에서 떨어져 5번에서 바닥에 닿고, 세로 늘어남에서 가로 눌림·반동을 거쳐 10번에서 안정화되며 10장이 모두 달라야 한다.
  2. 두 화면비의 `55_jelly_motion_rest`와 `56_jelly_motion_right`를 연다 → 55는 작은 젤리 40개가 바닥과 양쪽 벽·아래 코너에 실제로 접촉해 쌓이고, 56은 같은 더미가 오른쪽 중력으로 움직이는 상태여야 한다.
  3. `artifacts/screens/540x960`과 `540x1170`의 `26~43`, `54`를 연다 → 설정·무기록 시작·중력/경고·입력 상태·GREAT/INCREDIBLE·점수 팝업·레벨/붐빔/MAX/늘어남/흡수/새 젤리·호흡이 두 비율에서 잘림 없이 보여야 한다.
  4. `34_callout_great`, `35_callout_incredible`, `36_popup_merge`, `37_popup_blast_big`을 본다 → 붐비는 판에서 문구가 얼굴을 덮는 장면이 있으며 계측 결과 최대 100%, 0.908초임을 위치 변경 전 사용자 결정 자료로 확인한다.
  5. 옛 `57_jelly_full_right`를 본다 → 왼쪽의 흰 대각선은 젤리/보드 선이 아니라 배경을 지나는 유성이며 다음 캡처 시점에는 사라질 수 있어야 한다.
- 결정 사항: 새 밸런스 수치·공개 API·런타임 표현은 바꾸지 않았다. 옛 BLITZ `UNSTOPPABLE` 캡처 자리는 JELLY에서 실제 가능한 두 번째 턴 호령 `INCREDIBLE`로 대응했다. 빌드 보존 검사는 내용 해시 계산 대신 경로·크기를 사용해 큰 exe를 매 빌드마다 다시 읽는 비용을 피했고, 실제 검증에서 별도로 SHA-256 불변을 확인했다
- 남은 것 · 질문: 사라진 Release 13개의 정확한 삭제 명령은 남은 기록에서 특정하지 못했으며 재생성하지 않았다. 호령/팝업 겹침은 지시대로 보고만 했고 위치·크기 결정을 기다린다. 최종 합격/불합격 판정은 Claude에 남김

### [2026-10-26] 대상 #111 — 가장자리 젤리 어두운 띠 원인 분리·제거
- 상태: 완료 (추가 요구 1 반영) — 1차의 어두운 띠·그림자·변형축·판 시차 수정을 유지하면서 몸통에 덮인 볼·배·문양·전경 연출을 복구하고, 배 위치만 `delta × 8`로 부드럽게 회전하도록 분리함
- 브랜치 / PR: `jelly-edge-dark-rim` / https://github.com/jeongmo-dot/gravity_orb/pull/112
- 변경 파일: `scenes/{Main3D,Orb3D}.tscn`, `scripts/core/{JellyOrbArt,OrbSymbols}.gd`, `scripts/fx/{ColorEffectVisual,FeedbackDirector}.gd`, `scripts/spike/Orb3D.gd`, `tests/{capture_screens.ps1,test_color_effect_visuals.gd,test_feedback.gd,test_jelly_visuals.gd,test_orb_symbols.gd}`, `tests/run_jelly_edge_rendering_diagnostic.ps1`, `tests/spike/{capture_screens.gd,JellyEdgeRenderingDiagnostic.tscn,run_jelly_edge_rendering_diagnostic.gd}`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] 같은 초록 L3를 가운데·네 변·네 구석에 두고 실제 창 `540×960`·`540×1170`에서 몸통 바깥 `1.0r~1.3r`, 안쪽 `0.7r~1.0r`, 몸통 중심을 픽셀 계측 — 자동 실제 창 진단 + 직접 관측
  - [x] 보드판·몸통 알파·렌더 순서·그림자·벽 빛·얼굴/배·직교 카메라를 각각 비교 — 자동. 원인은 (1) 기본 거리 정렬에서 보드 반투명판이 끝의 몸통 가장자리 일부만 덮음, (2) 몸통이 보드에 드리운 그림자가 원근 시차로 끝에서 삐져나옴의 중첩
  - [x] `KeyLight.shadow_enabled=false`, Orb3D의 모든 메시 `cast_shadow=OFF`; 금지된 그림자 켜기 소스 검색 0건 — 자동 + 회귀 테스트
  - [x] JELLY 몸통 `render_priority=10`으로 보드 유리판 뒤/앞이 위치에 따라 바뀌지 않게 함. 중앙의 기존 내부 가장자리 휘도 약 `0.729`를 유지하면서 두 비율·아홉 위치 범위를 `0.728720~0.733358`로 통일 — 자동 + 직접 관측
  - [x] 얼굴·배 판을 몸통 중심에서 카메라 광선 방향으로 옮기되 기존 z 앞면 거리를 보존해 화면 중심 시차를 제거 — 자동 + 실제 창 계측
  - [x] 중력 전환 시 변형틀을 새 중력축에 즉시 맞춰 비스듬한 늘어남을 제거. 낙하·충돌의 의도된 최대 `1.189475`와 109/120프레임 지속은 유지 — 자동 + 실제 창 계측
  - [x] 림 켬/끔을 가운데·오른쪽 아래, 정지·오른쪽 이동에서 두 비율 확대 캡처. 림은 몸통 표면 밝기만 바꾸며 바깥 띠를 만들지 않음을 직접 확인하고 제작 셰이더는 유지 — 자동 캡처 + 직접 관측
  - [x] 수정 후 두 비율의 가운데·네 변·네 구석에서 어두운 바깥 띠 0px, 그림자 켜기 설정 0건. 전체 테스트·스모크·전체 캡처·Debug 빌드·저장 파일 불변 확인 — 자동
- 추가 요구 1 대조:
  - [x] 투명 렌더 순서를 몸통 `10` → 배 `11` → 얼굴 `12` → 문양 `13`으로 고정. 실제 창 볼 중심 RGB는 두 비율에서 노랑 L5 `246,132,125`, 초록 L5 `192,131,142`, 파랑 L5 `200,112,171`로 각각 명세 기대값 ±12 안 — 자동 픽셀 검사 + 확대 캡처 직접 관측
  - [x] 배 채움 `0.50`·`0.75`를 실제 창에서 각각 확대 캡처하고, 배 판을 잠시 숨긴 같은 좌표와 RGB를 비교. 두 비율 모두 보임 `144,233,197`, 숨김 `91,210~211,162~163`, 채널 최대 차이 `53`으로 채움이 몸통에 덮이지 않음 — 자동 픽셀 검사 + 직접 관측
  - [x] 전경 별가루·MAX 반짝임의 재질 우선순위를 `14`로 두고 깊이 검사를 끄며, 몸 뒤의 부드러운 빛 구름은 기존 깊이/우선순위를 유지. 합체·흡수·대폭발·잭팟·MAX 전체 및 MAX 확대 캡처에서 전경 입자가 몸통 위에, 빛 구름은 뒤에 보임 — 자동 회귀 + 직접 관측
  - [x] 몸통 변형틀은 중력 변경 즉시 맞추고 `_jelly_belly_rotation`만 기존 `lerp_angle(..., delta × 8)`로 분리. 새 공은 첫 중력에 즉시 초기화되고 기존 공의 배 위치는 이전 각도와 목표 각도 사이를 부드럽게 이동 — 자동 (`test_jelly_frame_stays_aligned_with_current_gravity`)
  - [x] 1차 실제 창 진단을 두 비율에서 재실행: 아홉 자리 어두운 바깥 띠 모두 0px, 변형축 최대 오차 `0.00000501°`, 얼굴/배 판 중심 최대 오프셋 `0.00006104px`, 의도된 늘어남 최대 `1.189475`, 원근 축비 최대 `1.000001973`으로 1차 수정 상태 유지 — 자동 실제 창 측정
  - [x] 두 비율 전체 캡처를 각 25장으로 확장해 합계 50장 생성. 기존 19장 전부과 볼 3색·배 0.50/0.75·MAX 연출 확대 6장을 직접 열어 확인 — 자동 캡처 + 직접 관측
- 원인 후보 표 (실제 창 직접 관측; 수정 전 그림자 수치는 `origin/main af9c4a6`, 반투명 순서 수치는 같은 진단의 후보 토글):
  - 기본값 → `540×960` 어두운 바깥 픽셀 45, `540×1170` 67; 중앙 0이고 아래·구석·오른쪽 끝에만 발생. 내부 띠 휘도 위치 범위 `0.376018~0.731463`
  - `Backing`·`GravityField` 숨김 → 몸통색 띠는 사라지지만 그림자 45/67은 남음
  - 몸통 알파 1 → 몸통색 띠는 사라지지만 그림자 45/67은 남고 의도된 반투명 가장자리가 바뀌므로 제작값으로 쓰지 않음
  - 몸통 우선순위 `-10` → 위치별 띠는 사라지나 내부 띠가 `0.258954~0.284334`로 전체적으로 어두워져 폐기
  - 몸통 우선순위 `+10` → 위치별 띠가 사라지고 내부 띠 `0.728716~0.733358`, 중앙 기존 밝기 유지 — 제작값으로 채택
  - 그림자 끔 → 수정 전 어두운 바깥 픽셀 45/67 → 0/0, 단 기본 거리 정렬의 몸통색 띠는 남음 — 제작값으로 채택
  - 벽 `InnerGlow`·`OuterGlow` 숨김 / 얼굴·배 숨김 / 림 끔 → 수정 전 그림자 45/67과 몸통색 띠가 각각 그대로여서 원인 아님
  - 직교 카메라 → 두 종류 모두 사라져 원근 시차 문제임을 확인했으나 원근 몸통 왜곡 최대가 `1.000001973`뿐이고 기존 생김새를 바꾸므로 진단 전용
- 자리별 바깥 띠 관측:
  - 수정 전 `540×960`: 가운데·왼쪽·오른쪽·위·좌상·우상 0, 아래 14, 좌하 16, 우하 15 = 45px
  - 수정 전 `540×1170`: 가운데·왼쪽·위·좌상 0, 오른쪽 7, 아래 14, 우상 9, 좌하 16, 우하 21 = 67px
  - 수정 후 두 비율: 가운데·왼쪽·오른쪽·위·아래·좌상·우상·좌하·우하 모두 어두운 바깥 띠 0px. 바깥 윤곽의 정상 안티앨리어싱 표본 68px는 모든 위치에서 동일하고 어두운 띠가 아니며, 내부 띠 위치 편차는 최대 `0.004638`
- 움직임 원인별 관측 (두 비율, 네 방향 각 120프레임):
  - 의도된 말랑함 → 화면 장·단축비 평균 `1.098680~1.098681`, 최대 `1.189473~1.189475`, 변형 지속 109프레임. 수치 변경 없음
  - 원근 왜곡 → 최대 축비 `1.000001973` (약 `0.000197%`), 제작 카메라 유지
  - 이전 `delta×8` 변형틀 회전 → 오른쪽/왼쪽 평균 기울기 `10.40299°`, 최대 `83.99998°`; 위 평균 `14.87368°`, 최대 `89.70998°`. 수정 후 네 방향 최대 `0.0000051°`
  - 얼굴/배 판 원근 시차 → 수정 전 최대 얼굴 `3.1902px`, 배 `3.1743px`; 수정 후 얼굴·배 모두 최대 `0.0000611px`
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `tests/run_tests.ps1` 최종 → 일반 `277/277`, 장기 `5/5`, 성능 `4/4`, 합계 `286/286`, 종료 코드 0, 총 `60.922초`; JELLY 그림 ON/OFF 상태 해시 `5c96a80c71c632fb8e727cf1be541757c464b436dd83d6c8d0737b1211347df1` 유지
  - 소스 기본·`--mode=jelly` `--quit-after 300` → 각각 종료 코드 0, 오류 표식 0건
  - `tests/run_jelly_edge_rendering_diagnostic.ps1` → 두 비율 종료 코드 0; 위치 9개·후보 11개·움직임 전후·림 전후 보고서와 캡처 생성
  - `tests/capture_screens.ps1` → 두 비율 각 25장, 총 50장, 종료 코드 0. 기존 전체 장면과 볼 3색·배 0.50/0.75·MAX 반짝임 확대를 직접 확인: 끝·구석 바깥 띠 0, 볼·배·문양·전경 별가루 보임, 뒤 빛 구름 유지
  - `tools/build_windows.ps1 -Debug` → 종료 코드 0, `build/windows-debug/GravityOrb_v0.16.0.exe` `104,940,432`바이트; Release 미실행. 내보낸 Debug 기본·JELLY 스모크 각각 종료 코드 0
  - 그림자 검색 `shadow_enabled = true`·`cast_shadow = 1`·`SHADOW_CASTING_SETTING_ON` → `scenes/`, `scripts/`, `tests/` 0건
  - 사용자 `save.cfg`는 검증 전후 `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D` 동일
  - 규칙 검사 → 허용 파일 외 `Input`/`InputEvent` 0건, Spawner 외 신규 전역 난수 호출 0건, `git diff --check` 오류 0건
- 수동 확인 절차:
  1. Debug 빌드에서 JELLY를 시작하고 같은 색·레벨 젤리를 중앙과 네 변·네 구석에 정지시킨다 → 중앙과 끝 모두 몸통 가장자리 밝기가 같고, 몸통 바깥에 어두운 띠·그림자·외곽선이 없어야 한다.
  2. 중력을 아래·오른쪽·위·왼쪽으로 바꾸며 젤리를 끝까지 보낸다 → 젤리 자체만 중력축/충돌축으로 늘어나고 비스듬한 중간 변형, 얼굴·배 중심 어긋남, 바깥 그림자가 없어야 한다.
  3. 중력을 연속으로 바꾸며 배가 찬 젤리를 관찰한다 → 몸통 늘어남 축은 즉시 새 중력에 맞고, 배 속 젤리 위치만 새 아래쪽으로 짧게 부드럽게 돌아가야 한다.
  4. 합체·흡수·L7 MAX 생성을 만든다 → 별가루·MAX 반짝임은 몸통 위에서 보여야 하고, 부드러운 빛 구름은 기존처럼 몸 뒤에 있어야 한다.
  5. 진단의 `baseline_*_zoom.png`와 `rim_off_*_zoom.png`, `motion_right_*_zoom.png`와 `motion_rim_off_right_*_zoom.png`를 비교한다 → 림 켬은 몸통 표면에만 은은한 밝기를 더하고 바깥 띠를 만들지 않아야 한다.
- 결정 사항: 새 밸런스 수치·공개 API·카메라 투영·보드/몸통 셰이더는 바꾸지 않았다. 1차의 몸통 `10` 뒤로 명세 예시 순서 `11/12/13`을 적용하고, 실제 확대에서 몸 안 전경 입자가 깊이 버퍼에 막히는 것을 확인해 전경 별가루만 `14`·`depth_test_disabled`로 배치했다. 뒤 빛 구름의 재질은 바꾸지 않았다
- 남은 것 · 질문: 자동 검증·두 비율 전체/확대 캡처 직접 관측을 완료했으며 최종 합격/불합격 판정은 Claude에 남김

### [2026-10-26] 대상 #107 — Windows 빌드 0.16.0 · JELLY 단일 앱 첫 Release
- 상태: 완료 — `origin/main`의 #110 병합 상태에서 버전 `0.16.0`을 유지하고 JELLY 단일 앱 Release Windows 패키지를 생성·검증함
- 브랜치 / PR: `build-0.16.0` / https://github.com/jeongmo-dot/gravity_orb/pull/111
- 변경 파일: `docs/jeongmo_codex_to_claude.md` (Release 산출물은 `build/windows/`, git 추적 제외)
- Done-when 대조:
  - [x] `application/config/version=0.16.0`을 바꾸지 않고 깨끗한 작업 트리에서 Release `GravityOrb_v0.16.0.exe`·`.console.exe`·`_BUILD.txt` 생성 — 자동
  - [x] 내보낸 콘솔 exe 기본·`--mode=jelly` 스모크가 격리 `APPDATA`에서 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 0건 — 자동
  - [x] 내보낸 Release의 기본 실행 시작 화면과 `--mode=jelly` 직접 실행을 각각 격리 `APPDATA`에서 실제 GPU 렌더 5프레임으로 캡처해 직접 확인 — 자동 캡처 + 직접 관측. 실제 JELLY 버튼 클릭은 아래 제한 때문에 미실행
  - [x] 사용자 `save.cfg` 크기·SHA-256 불변, 패키지에서 `tests/`·`artifacts/`·`docs/`·BLITZ·SLIME 표식 각 0건 — 자동
  - [x] 0.15.0·0.15.1·0.15.2 Release 산출물 9개를 유지하고 전체 테스트·소스 스모크·규칙 검사를 통과 — 자동
  - [x] 회신 커밋 뒤 깨끗한 작업 트리에서 최종 재빌드해 `_BUILD.txt` 커밋과 브랜치 마지막 커밋 일치 확인 — 자동
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` → 정상 권한 재실행 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 0건. 샌드박스 실행은 AppData·`artifacts/` 쓰기 거부로 오류 7건이어서 결과에서 제외
  - `tests/run_tests.ps1` → 일반 `275/275` (`11.699초`), 장기 `5/5` (`40.266초`), 성능 `4/4` (`2.708초`), 합계 `284/284`, 종료 코드 0, 총 `54.673초`
  - JELLY 시각 ON/OFF 상태 해시 → `5c96a80c71c632fb8e727cf1be541757c464b436dd83d6c8d0737b1211347df1`, #104·#106·#109·#110 기준과 동일
  - 소스 기본·`--mode=jelly` `--quit-after 300` → 둘 다 격리 `APPDATA`에서 종료 코드 0, 오류 표식 0건
  - `tools/build_windows.ps1` Release → 종료 코드 0, 결과 줄 `version=0.16.0 mode=Release exit=0 bytes=111069840`
  - 산출물 → `GravityOrb_v0.16.0.exe` `111,069,840`바이트, `.console.exe` `50,176`바이트, `_BUILD.txt` `159`바이트, PCK 별도 파일 0개
  - 내보낸 콘솔 exe 기본·JELLY → 둘 다 격리 `APPDATA`에서 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 0건
  - 내보낸 Release GPU 렌더 → 기본·JELLY 직접 실행 각각 OpenGL 3.3 / NVIDIA GeForce RTX 4070 Ti SUPER, `540×960`, 60 FPS 고정, 5프레임 PNG 기록, 종료 코드 0. 기본 마지막 프레임은 로고·큰 JELLY 버튼 하나·아이콘 3개, JELLY 직접 실행 마지막 프레임은 점수 HUD·보드·분홍 젤리 2개·NEXT/THEN 미리보기로 관측
  - 실제 버튼 클릭은 미실행 — 컴퓨터 사용 스킬의 기본 CUA와 보조 Sky 경로가 모두 `failed to write kernel assets: 지정된 경로를 찾을 수 없습니다. (os error 3)`로 초기화되지 않음. 대신 같은 Release exe의 기본 시작 프레임, `test_frontend`의 단일 JELLY 버튼·모드 파서, `--mode=jelly` 직접 실행 프레임을 확인
  - 패키지 문자열 검사 → `res://tests/`·`res://artifacts/`·`res://docs/`·`BLITZ`·`SLIME`·`BlitzManager`·`BlitzTimeBar`·`SlimeMain`·`SlimeConfig`·`scripts/slime`·`slime_config.tres` 각 0건
  - 이전 버전 유지 → 0.15.0 `111,213,584`바이트, 0.15.1 `111,219,904`바이트, 0.15.2 `111,221,024`바이트의 exe와 각 `.console.exe` `50,176`바이트·`_BUILD.txt`를 그대로 보존, 삭제 0건
  - 사용자 `save.cfg`는 검증 전후 `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D` 동일
  - 규칙 검사 → 허용 파일 외 `Input`/`InputEvent` 0건, Spawner 외 전역 난수 호출 0건, `git diff --check` 오류 0건
- 수동 확인 절차:
  1. `build/windows/GravityOrb_v0.16.0.exe`를 실행 → 로고 아래 큰 JELLY 버튼 하나와 랭킹·소리·설정 아이콘만 보여야 한다.
  2. JELLY 버튼을 실제 클릭 → 점수 HUD·젤리 보드·NEXT/THEN이 있는 JELLY 게임으로 바로 진입해야 한다.
  3. 앱을 닫고 `GravityOrb_v0.16.0.console.exe -- --mode=jelly` 실행 → 시작 화면을 거치지 않고 같은 JELLY 보드로 직접 진입해야 한다.
- 결정 사항: 버전·게임 코드·설정·다른 빌드 파일은 바꾸지 않았다. GUI 대체 검증용 GPU 프레임과 격리 AppData는 git 추적 대상에서 제외하고, 프로젝트가 임포트하지 않도록 작업 폴더 밖 임시 경로로 옮긴 뒤 작업 폴더의 임시 폴더만 삭제했다
- 남은 것 · 질문: 실제 JELLY 버튼 클릭만 컴퓨터 사용 커널 초기화 실패로 미실행이며 위 수동 절차로 남김. 나머지 자동 검증과 두 실행 경로의 실제 GPU 프레임 직접 관측 완료. 최종 합격/불합격 판정은 Claude에 남김

### [2026-10-25] 대상 #110 — 고리 연출·그림 전부 삭제 및 충돌 공간 일치
- 상태: 완료 — 1차 고리 삭제를 유지하고 추가 요구 1의 비축소 말랑 변형·합체 펀치·별가루 산개·공간 재측정·캡처를 반영함
- 브랜치 / PR: `remove-all-rings` / https://github.com/jeongmo-dot/gravity_orb/pull/110
- 변경 파일: `config/{GameConfig.gd,default_config.tres}`, `scenes/Orb3D.tscn`, `scripts/core/{Board,CelestialOrbArt,OrbVisual}.gd`, `scripts/fx/{ColorEffectVisual,FeedbackDirector}.gd`, `scripts/spike/Orb3D.gd`, `scripts/ui/{CosmicRing2D,OrbitStage}.gd`, `tests/`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] #109 이전 `9157b6c` 코드에서 실제 그래픽 창·실제 합체/흡수·후속 스와이프 5턴을 두 비율로 선행 측정 — 자동 창 측정 + 캡처 직접 관측
  - [x] `ColorEffectVisual`·`FeedbackDirector`의 고리 메시·풀·그룹·API·호출, 빛 셰이더의 `shell`/`rim`, 행성 장식, `BlastOutline`, 2D 대폭발 원 테두리, `CosmicRing2D`, 시작 화면 타원 궤도선과 전용 진단을 코드째 삭제 — 자동 소스 검색 + 직접 관측
  - [x] 합체·흡수·대폭발·잭팟·MAX 직후 씬 트리에서 이름에 ring/adornment가 있는 노드와 Torus 메시가 0인지 회귀 검사. 별가루·흡수 잔상·빛 구름·섬광·흔들림·멈칫·얼굴은 유지 — 자동 (`test_feedback`, `test_color_effect_visuals`, `test_jelly_visuals`, `test_celestial_orbs`)
  - [x] 수정 뒤 두 비율 실제 창에서 물리/그림 반지름 차이 0px, 맞닿은 젤리 빈틈 0px, 합체·흡수와 후속 5턴 고리 0프레임 — 자동 창 측정
  - [x] 두 비율 시작 화면·합체·흡수·대폭발·잭팟·MAX 순간 포함 1차 전체 34장 캡처를 생성하고 직접 확인 — 자동 + 직접 관측
  - [x] 전체 테스트·임포트·소스/Debug 패키지 스모크·Debug 빌드·사용자 저장 불변 — 자동
- 추가 요구 1 대조:
  - [x] JELLY 몸통을 축별 `max(1, deform)`로 렌더링해 낙하 세로 늘어남·충돌 가로 넓어짐·숨쉬기는 유지하고, 가로/세로/z 축소만 1에서 제한. 얼굴과 배 속 젤리에 같은 x/y 배율·펀치를 적용하고 얼굴은 기존 `R·S·R^-1` 똑바른 기준, z는 확대된 몸통 앞면 기준 — 자동 (`test_jelly_visuals`) + 캡처 직접 관측
  - [x] JELLY 합체 펀치를 `1.0 → 1.06 / 0.08초 → 1.0 / 0.10초`로 변경 — 자동 (`test_jelly_merge_punch_uses_non_shrinking_006_peak_timing`)
  - [x] 색 효과 별가루에 효과별 지역 `RandomNumberGenerator` 씨앗을 두고 각 점 방향 `0~360°`, 거리 `0.6~1.0`, 속도 `0.7~1.0`을 따로 추출. 같은 씨앗의 방향·계수·프레임 변환 재현 및 등간격 원이 아님을 검사 — 자동 (`test_stardust_uses_seeded_scatter_with_bounded_distance_and_speed`)
  - [x] 9번 공간 측정을 두 비율에서 다시 실행해 그린 반지름이 물리 반지름보다 작은 프레임 0, 접촉 빈틈 0을 확인하고 확대 겹침 최대·연속 시간을 기록 — 자동 실제 창 측정
  - [x] 합체·흡수 순간과 새 착지 띠·붐비는 쉬는 판을 포함한 전체 캡처를 두 비율 각 19장, 합계 38장 다시 생성해 직접 확인 — 자동 + 직접 관측
- 삭제 전 원인·측정 (`9157b6c` + 측정 도구만 적용):
  - 단일 `ModeRing`의 실제 수명은 합체 `293.069~294.185ms` (`46`프레임), 흡수 `234.240~240.594ms` (`35`프레임). 같은 노드가 5턴 남은 것은 아니지만, 후속 턴마다 새 반응이 고리를 다시 만들어 5개 턴의 가시 프레임이 각각 `12, 121, 93, 36, 75`, 입력 경계 가시는 `1, 0, 1, 1, 0`이었다. 5턴 뒤 씬 트리에 이름 고리 노드 `5`, 풀을 포함한 Torus 메시 `21`개가 남았다
  - `Orb3D._mesh.scale`에 JELLY `deform`·펀치를 곱하면서 `SphereShape3D.radius`는 고정한 것이 숨은 공간의 원인. `1,007`프레임 중 반지름 차이 `899`프레임, 최대 `14.067139px`; 접촉 표본 `7,127`개에서 빈틈 프레임 `209`, 최대 `7.811546px`였다
- 수정 뒤 실제 창 측정:
  - `540×960`: `1,825`프레임, 접촉 표본 `9,522`; 반지름 차이 프레임/최대 `0 / 0.0px`, 빈틈 프레임/최대 `0 / 0.0px`, 합체·흡수 가시 고리 `0`프레임, 5턴 각 가시 고리 `0`프레임, 최종 이름 고리 노드/Torus `0 / 0`
  - `540×1170`: `1,828`프레임, 접촉 표본 `9,487`; 반지름 차이 프레임/최대 `0 / 0.0px`, 빈틈 프레임/최대 `0 / 0.0px`, 합체·흡수 가시 고리 `0`프레임, 5턴 각 가시 고리 `0`프레임, 최종 이름 고리 노드/Torus `0 / 0`
- 추가 요구 1 뒤 실제 창 재측정 (커밋 `3af6313`, 표본 구성은 합체·흡수 + 접촉 격자 후 5턴):
  - `540×960`: `1,510`프레임, 접촉 표본 `7,127`; 물리보다 작게 그린 프레임/최대 `0 / 0.0px`, 빈틈 프레임/최대 `0 / 0.0px`, 확대 겹침 최대 `40.757114px`, 겹침 관측 `910`프레임·`5,792`쌍 표본, 한 쌍 최장 연속 `1,267.698ms`; 합체·흡수 및 후속 5턴 가시 고리 `0`프레임
  - `540×1170`: 같은 프레임·접촉·빈틈·최대 겹침 값, 한 쌍 최장 연속 `1,273.757ms`; 최종 이름 고리 노드/Torus `0 / 0`
  - `40.757114px`/약 `1.27초`는 충돌 순간만 분리한 값이 아니라 축소를 막은 충돌 변형과 접촉 격자의 서로 다른 위상 숨쉬기 확대를 함께 포함한 전체 관측 최댓값·최장값이다. 물리 반지름·중심 거리·충돌 판정은 바꾸지 않았다
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` → 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 0건
  - `tests/run_tests.ps1` 최종 → 일반 `275/275` (`14.430초`), 장기 `5/5` (`48.672초`), 성능 `4/4` (`2.916초`), 합계 `284/284`, 종료 코드 0, 총 `66.018초`
  - JELLY 시각 ON/OFF 상태 해시 → `5c96a80c71c632fb8e727cf1be541757c464b436dd83d6c8d0737b1211347df1`, #104·#106·#109 기준과 동일. CLASSIC staged difficulty 해시도 기존 `cf6172428c7901c43eb74f417e6880dc3ad375a329e669a8904234f5d38d1031` 유지
  - `tests/capture_screens.ps1` 최종 → `540×960`, `540×1170` 각각 19장, 합계 38장, 종료 코드 0. `13_jelly_merge_effect`, `14_jelly_absorption_effect`, `18_jelly_landing_strip`, `19_jelly_crowded_rest`를 두 비율에서 직접 열어 별가루 등간격 원 0건, 세로 늘어남·가로 넓어짐 유지, 접촉 빈틈 0건, 잔여 이펙트 0건, HUD 잘림 0건 관측
  - 소스 및 Debug 콘솔 exe의 기본·`--mode=jelly` 스모크 → 네 실행 모두 종료 코드 0, 오류 표식 0건
  - `tools/build_windows.ps1 -Debug` → `version=0.16.0`, 종료 코드 0, `GravityOrb_v0.16.0.exe` `104,939,664`바이트, `.console.exe` `50,176`바이트
  - 사용자 `save.cfg` → `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D`로 작업 전후 동일
  - 지정 소스 검색 → `TorusMesh`, `_create_ring`, `ModeRing`, `Adornment`, `BlastOutline` 각 0건. `draw_arc`는 `OrbVisual.gd`에 10건 남으며 모두 MAX 입(반원 2개), 행성 표면 구름/명암의 열린 부분 선으로 시작·끝 각도가 `TAU` 전체가 아닌 비고리 그림이다. `SphereMesh.rings` 1건은 구의 세로 세그먼트 수 API로 고리 메시가 아니다
  - 규칙 검사 → 허용 파일 외 `Input`/`InputEvent` 0건. 전역 난수 호출 0건; 추가 요구가 명시한 예외로 `ColorEffectVisual` 안에 효과별 지역 RNG와 `randf_range` 3곳이 있고 Spawner RNG에는 접근하지 않음. `git diff --check` 오류 0건
- 수동 확인 절차:
  1. Debug 빌드 시작 화면을 연다 → 작은 천체는 계속 움직이되 그 경로를 두른 타원 선 두 줄은 보이지 않아야 한다.
  2. JELLY에서 같은 색 합체와 한 단계 흡수를 만든다 → 별가루·흡수 이동 잔상은 보이되 젤리 바깥 원 테두리와 몸통-접촉 사이 빈 공간은 없어야 한다.
  3. L6 다른 색 대폭발, L7 같은 색 잭팟, L7 결과 생성을 차례로 만든다 → 입자·부드러운 빛 구름·섬광·흔들림·터질 듯한/MAX 얼굴은 남고 원형 충격파/흰 고리/외곽선은 어느 프레임에도 없어야 한다.
  4. 다섯 번 이상 중력을 바꾼다 → 이전 반응 위치나 젤리 둘레에 고리가 다시 나타나지 않고 서로 맞닿은 몸통 사이에 투명한 틈이 없어야 한다.
  5. 착지·충돌·정지 숨쉬기를 관찰한다 → 젤리는 중력축 또는 충돌 가로축으로 커지되 어느 축도 충돌 반지름보다 작게 오므라들지 않고, 얼굴·배 속 젤리가 몸통과 함께 변하면서 얼굴은 똑바로 있어야 한다.
- 결정 사항: 추가 요구의 `max(1, 변형값)`를 몸통 local x/y와 앞뒤 z(x 기준), 얼굴·배 속 젤리 x/y, JELLY의 기존 PULL 펀치 축소에도 동일 적용했다. 별가루 씨앗은 반응 종류·색·레벨·위치·해당 Director의 효과 순번으로 계산해 실행 간 재현성과 효과 간 변화를 함께 유지한다. 밸런스·규칙·점수·질량·충돌 반지름 값은 변경하지 않았고 측정·캡처 산출물은 git 추적에서 제외했다
- 남은 것 · 질문: 자동 검증·실제 창 측정·전체 캡처·직접 관측 완료. 최종 합격/불합격 판정은 Claude에 남김

### [2026-10-25] 대상 #109 — JELLY 젤리 둘레 반투명 고리 제거
- 상태: 완료 — 실제 창에서 원인 노드를 분리 재현하고 JELLY에서 해당 링 한 겹만 숨김
- 브랜치 / PR: `jelly-halo-fix` / https://github.com/jeongmo-dot/gravity_orb/pull/109
- 변경 파일: `scripts/fx/{ColorEffectVisual,FeedbackDirector}.gd`, `tests/test_color_effect_visuals.gd`, `tests/spike/{JellyHaloDiagnostic.tscn,run_jelly_halo_measurement.gd}`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] 최신 `origin/main`을 먼저 병합하고 Godot Standard 실제 창·그림 ON 상태에서 합체·흡수를 재현 — 자동 창 측정 + 캡처 직접 관측
  - [x] 원인은 `FeedbackDirector`가 합체마다 만드는 `ColorEffectVisual/ModeRing`. 파랑(SHAKE)·초록(PUSH)은 링이 있고 노랑(LIFT)은 원래 숨기는 분기가 사용자 화면과 일치 — 후보별 숨김 비교
  - [x] JELLY에서 `ModeRing`만 숨기고 합체 별가루·방향 별가루·보드 흔들림·PULL 메시 펀치·물리 색 효과는 유지. 비-JELLY 경로 링은 유지 — 자동 (`test_jelly_hides_color_mode_ring_but_keeps_other_feedback` + 기존 색 효과 테스트)
  - [x] 수정 후 합체·흡수 20회와 각 반응 뒤 실제 스와이프 3턴(총 60턴)에서 링 재등장 0회. 고리 영역 픽셀 수정 전 8,120 → 수정 후 0 — 자동 실제 창 측정
  - [x] 두 비율 전·후 캡처와 마지막 전체 캡처 완료, JELLY 그림 ON/OFF 해시는 #104 기준 그대로 — 자동 + 직접 관측
  - [x] 전체 테스트·소스/Debug 패키지 스모크·Debug 빌드·사용자 저장 불변 — 자동
- 원인 관측:
  - `ColorEffectVisual.play()`가 LIFT 외 색 효과에서 `ModeRing`을 보이게 하고, 결과 반지름에서 색 효과 반지름까지 PUSH/SHAKE는 `0.3/0.4초` 동안 확장, PULL은 `0.3초` 동안 수축시켰다. 링 색은 결과 젤리색이고 알파는 `1-progress`라 반응 직후 `1.0r~1.3r` 구간에서 다음 크기 예고처럼 보였다
  - 실제 창 80ms 후보 분리: `JellyAbsorptionTrail`만 숨겨도 큰 고리는 남고 `ColorEffectVisual/ModeRing`을 숨기면 사라짐. 보이는 다른 후보는 몸통·배·얼굴, 합체 별가루였음
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` → 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 0건
  - `tests/run_tests.ps1` → 일반 `274/274` (`12.246초`), 장기 `5/5` (`41.569초`), 성능 `4/4` (`2.918초`), 합계 `283/283`, 종료 코드 0, 총 `56.732초`
  - JELLY 시각 ON/OFF 상태 해시 → `5c96a80c71c632fb8e727cf1be541757c464b436dd83d6c8d0737b1211347df1`, #104·#106 기준과 동일
  - `JellyHaloDiagnostic.tscn` 실제 창 `540×960` → 합체/흡수 20회, 후속 실제 턴 60회, 수정 전 고리 영역 차이 8,120픽셀, 수정 상태·재숨김 차이 0픽셀, `normal_ring_occurrences=0`, 종료 코드 0
  - 같은 실제 창 `540×1170` → 합체/흡수 20회, 수정 전 고리 영역 차이 7,975픽셀, 수정 상태·재숨김 차이 0픽셀, `normal_ring_occurrences=0`, 종료 코드 0
  - `tests/capture_screens.ps1` 최종 → 두 비율 각 12장, 합계 24장, 종료 코드 0. `04_jelly_gameplay`·`11_jelly_eat_01` 두 비율을 직접 열어 고리 0건, 다른 젤리 그림·HUD 잘림/겹침 0건 관측
  - 소스와 Debug 콘솔 exe의 기본·`--mode=jelly` 스모크 → 네 실행 모두 종료 코드 0, 오류 표식 0건
  - `tools/build_windows.ps1 -Debug` → `version=0.16.0`, 종료 코드 0, `GravityOrb_v0.16.0.exe` `104,960,320`바이트, `.console.exe` `50,176`바이트
  - 사용자 `save.cfg` → `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D`로 작업 전과 동일
  - 규칙 검사 → 허용 파일 외 `Input`/`InputEvent` 0건, Spawner 외 전역 난수 0건, `git diff --check` 오류 0건
- 수동 확인 절차:
  1. Debug 빌드에서 JELLY를 시작하고 같은 색 젤리를 합체·흡수 → 젤리 둘레에 제 색 원형 고리가 생기지 않아야 한다
  2. 분홍·파랑·초록 합체 → 합체 별가루와 PUSH 방향 별가루 또는 파랑 보드 흔들림은 기존대로 보여야 한다
  3. 세 번 더 스와이프 → 이전 반응 위치나 움직이는 젤리 둘레에 고리가 남거나 다시 나타나지 않아야 한다
- 결정 사항: 규칙·물리·수치와 다른 연출은 바꾸지 않고 JELLY 표시에서 `ModeRing` 가시성만 끔. 측정 캡처 산출물은 git 추적에서 제외함
- 남은 것 · 질문: 자동 검증과 화면 직접 관측 완료. 최종 합격/불합격 판정은 Claude에 남김

### [2026-10-25] 대상 #106 — JELLY 단일 앱 · 다른 모드 레거시 보관
- 상태: 완료 — `legacy-four-modes` 태그 뒤 main을 JELLY 단일 앱으로 전환하고 0.16.0 Debug 패키지까지 검증함
- 브랜치 / PR: `jelly-single-app` / https://github.com/jeongmo-dot/gravity_orb/pull/108
- 변경 파일: `config/{GameConfig.gd,default_config.tres}`, `project.godot`, `scenes/{Main.tscn,Main3D.tscn,UI.tscn}`, `scripts/{core,fx,spike,ui}`, `tests/`, `docs/.gdignore`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] BLITZ·SLIME 런타임 코드·씬·HUD·설정 필드·전용 테스트·캡처 장면·측정 도구 삭제. CLASSIC의 공통 규칙·턴·물리·반응·Spawner와 회귀 테스트는 유지 — 자동 (소스 검색·전체 테스트)
  - [x] `GameMode` 숫자 `TURN=0`, `BLITZ=1`, `SLIME=2`, `JELLY=3` 고정 및 레거시 주석. 앱 시작·즉시 실행·재시작은 JELLY로 강제하고 CLI는 없음/`jelly`만 허용 — 자동 (`test_frontend`)
  - [x] 기존 로고·부제·행성 그림 아래 936×200 기준의 L3 분홍 JELLY 단일 버튼과 랭킹·소리·설정 아이콘 줄 구성. 랭킹은 탭 없는 JELLY 열만, 결과 버튼은 `처음 화면` — 자동 레이아웃 테스트 + 두 비율 캡처 직접 관측
  - [x] 다른 모드 저장 키를 삭제·변경하지 않고 JELLY 저장 시에도 그대로 보존 — 자동 (`test_frontend`, `test_rankings`) + 실제 사용자 저장 바이트 비교
  - [x] 빈 `docs/.gdignore` 추가, 프로젝트 버전은 §12-ONE.2 결정 값 `0.16.0` 적용 — 자동
  - [x] JELLY 그림 ON/OFF 상태 해시가 #104 기준과 동일하고, 전체 테스트·두 스모크·Debug 빌드·패키지 문자열 검사·최종 전체 캡처 통과 — 자동
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` 최종 정상 권한 실행 → 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 0건
  - `tests/run_tests.ps1` → 일반 `273/273` (`14.307초`), 장기 `5/5` (`43.423초`), 성능 `4/4` (`3.393초`), 합계 `282/282`, 종료 코드 0, 총 `61.123초`
  - JELLY 시각 ON/OFF 상태 해시 → 두 경로 모두 `5c96a80c71c632fb8e727cf1be541757c464b436dd83d6c8d0737b1211347df1`; #104 기준과 동일
  - 소스와 내보낸 Debug 콘솔 exe의 기본·`--mode=jelly` `--quit-after 300` → 네 실행 모두 종료 코드 0, 오류 표식 0건
  - 최종 `tests/capture_screens.ps1` → `540×960`, `540×1170` 각각 시작·랭킹·결과·게임플레이·FINAL MOVE·대폭발 얼굴 2방향·배 속 젤리 2방향·흡수 3단계의 12장, 합계 24장, 종료 코드 0. 시작/랭킹/결과/게임플레이를 직접 열어 레거시 카드·탭·HUD 0건, 잘림·겹침 0건 관측
  - `tools/build_windows.ps1 -Debug` → `version=0.16.0`, 종료 코드 0, `build/windows-debug/GravityOrb_v0.16.0.exe` `104,959,904`바이트, `.console.exe` `50,176`바이트
  - 내보낸 exe 문자열 검사 → `BlitzManager`, `BlitzTimeBar`, `SlimeMain`, `SlimeConfig`, `SlimeGame/Hud/Sim/View`, `SlimeCardIcon`, `scripts/slime`, `slime_config.tres` 각 0건. `res://tests/`, `res://artifacts/`, `res://docs/` 각 0건. 저장 호환용 키 문자열은 의도대로 유지
  - 사용자 `save.cfg`는 전후 `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D` 동일
  - 규칙 검사 → 허용 파일 외 `Input`/`InputEvent` 0건, Spawner 외 전역 난수 0건, `git diff --check` 오류 0건
- 삭제 파일 목록 (`76`개):
  - 설정·씬·런타임 `18`개: `config/SlimeConfig.gd{,.uid}`, `config/slime_config.tres`, `scenes/SlimeMain.tscn`, `scripts/core/BlitzManager.gd{,.uid}`, `scripts/slime/{SlimeGame,SlimeHud,SlimeSim,SlimeView}.gd{,.uid}`, `scripts/ui/BlitzTimeBar.gd{,.uid}`, `scripts/ui/SlimeCardIcon.gd{,.uid}`
  - 전용 테스트 `19`개: `tests/test_{blitz_manager,blitz_time_bar,slime_config,slime_game,slime_shell,slime_sim,slime_visuals}.gd{,.uid}`, `tests/test_callouts.gd{,.uid}`, `tests/spike/{BlitzMeasurement,RunBlitzResponsivenessMeasurement,SlimeWindowMeasurement}.tscn`
  - 루트 측정 도구 `9`개: `tests/run_{blast_l4_range,blitz_clock,blitz,blitz_responsiveness,blitz_survival,gravity_comparison,jolt_rid_robustness,slime_visual_render_test,slime_window}_measurement.ps1`
  - spike 측정 `10`개: `tests/spike/run_{blitz_measurement,blitz_responsiveness_measurement,jolt_rid_robustness,reaction_latency_measurement,slime_window_measurement}.gd{,.uid}`
  - tools 측정·비교 `20`개: `tests/tools/capture_slime_original_comparison.ps1`, `run_mode_preview_measurement.ps1`, `run_mode_skill_measurement.ps1`, `run_mode_skill_slime_measurement.gd{,.uid}`, `run_slime_bot_measurement.{gd,gd.uid,ps1}`, `run_slime_parity.ps1`, `run_staged_difficulty_measurement.ps1`, `slime_original_capture_{driver,game}.gd{,.uid}`, `slime_parity_{candidate,original_driver,original_game}.gd{,.uid}`
- 수동 확인 절차:
  1. `build/windows-debug/GravityOrb_v0.16.0.exe` 실행 → 로고 아래 큰 JELLY 버튼 하나와 랭킹·소리·설정 아이콘만 보여야 한다.
  2. JELLY 버튼 클릭 → 즉시 JELLY 판이 열리고 기존 JELLY 규칙·말랑함·얼굴·배 속 젤리가 유지되어야 한다.
  3. 시작 화면의 랭킹 아이콘 클릭 → 탭 없이 JELLY 순위·점수·최대 콤보·FINAL MOVE·날짜 열만 보여야 한다.
  4. 게임 오버 뒤 `처음 화면` 클릭 → 단일 JELLY 시작 화면으로 돌아와야 한다.
- 결정 사항: BLITZ·SLIME save key 읽기/쓰기 호환 코드는 실제 사용자 파일 보존을 위해 남겼고 앱 경로에서는 호출하지 않음. CLASSIC 전용 정리는 §12-ONE.3 다음 항목으로 남김. 캡처 산출물은 git 추적 대상에서 제외함
- 남은 것 · 질문: 자동 검증과 화면 직접 관측 완료. 최종 합격/불합격 판정은 Claude에 남김

### [2026-10-25] 대상 #105 — Windows 빌드 0.15.2
- 상태: 완료 — 최신 `origin/main`의 #104 반영 상태에서 프로젝트 버전을 `0.15.2`로 올리고, 네 모드가 포함된 마지막 보관용 Godot 4.8 Standard Release Windows 패키지를 생성·검증함
- 브랜치 / PR: `build-0.15.2` / https://github.com/jeongmo-dot/gravity_orb/pull/107
- 변경 파일: `project.godot`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] 최신 `origin/main` `18073c2`에서 전용 브랜치를 만들고 `application/config/version`을 `0.15.1`에서 Claude 결정 값 `0.15.2`로 변경 — 자동
  - [x] 버전 변경을 먼저 독립 커밋한 뒤 깨끗한 작업 트리에서 Release `GravityOrb_v0.15.2.exe`·`.console.exe`·`_BUILD.txt` 생성 — 자동
  - [x] 소스 및 내보낸 콘솔 exe의 기본·TURN·BLITZ·SLIME·JELLY 다섯 경로 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 0건 — 자동
  - [x] 격리 `APPDATA`에서 시작 화면과 JELLY 직접 실행 창을 각각 5초 확인: 두 프로세스 생존, 창 제목 `Gravity Orb`, 창 핸들 0 아님, `godot.log` 오류 0건 — 자동. 시작 화면 JELLY 카드 실제 클릭은 아래 수동 절차로 남김
  - [x] 사용자 `save.cfg` 크기·SHA-256 불변, 패키지에서 `tests/`·`artifacts/`·`docs/`와 테스트·캡처·인박스·설계 문서 표식 각 0건 — 자동
  - [x] 0.15.0·0.15.1 Release 산출물 6개를 유지하고 전체 테스트·규칙 검사를 통과 — 자동
  - [x] 회신 커밋 뒤 깨끗한 작업 트리에서 최종 재빌드해 `_BUILD.txt` 커밋과 브랜치 마지막 커밋 일치 확인 — 자동
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` → 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 각 0건
  - `tests/run_tests.ps1` → 일반 `371/371` (`26.125초`), 장기 `5/5` (`42.675초`), 성능 `5/5` (`3.890초`), 합계 `381/381`, 종료 코드 0, 총 `72.690초`
  - Godot 소스 기본·TURN·BLITZ·SLIME·JELLY `--quit-after 300` → 5개 모두 종료 코드 0, 오류 표식 0건
  - `tools/build_windows.ps1` Release → 종료 코드 0, 결과 줄 `version=0.15.2 mode=Release exit=0 bytes=111221024`
  - 산출물 → `GravityOrb_v0.15.2.exe` `111,221,024`바이트, `.console.exe` `50,176`바이트, `_BUILD.txt` `159`바이트; PE 파일·제품 버전 `0.15.2.0`, 제품 이름 `Gravity Orb`
  - 내보낸 콘솔 exe 기본·TURN·BLITZ·SLIME·JELLY → 5개 모두 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 0건
  - 격리 GUI → 시작 화면·`--mode=jelly` 각각 5초 생존, 창 제목 `Gravity Orb`, 창 핸들 각각 0 아님, 로그 파일 각각 1개, 오류 표식 각 0건; 임시 `APPDATA` 두 폴더는 확인 뒤 삭제
  - 패키지 문자열 검사 → `res://tests/`·`res://artifacts/`·`res://docs/`·`run_tests.gd`·`capture_screens.gd`·인박스·설계 문서 표식 각 0건; `JellyOrbArt.gdc`·`Main3D.scn`·`StartScreen.gdc` 각 2건
  - 이전 0.15.0·0.15.1의 exe·console exe·BUILD txt 6개 유지, 삭제 0건
  - 사용자 `save.cfg`는 검증 전후 `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D` 동일
  - 규칙 검사 → 코드 변경이 없어 신규 `Input`/`InputEvent`·전역 난수 호출 0건, `git diff --check` 오류 0건. 버전·회신만 바꿔 화면 캡처는 미실행
- 수동 확인 절차:
  1. `build/windows/GravityOrb_v0.15.2.exe`를 실행한다 → 시작 화면에 BLITZ·CLASSIC·JELLY·SLIME 카드 4장이 보이고 .NET 폴더 확인 경고가 없어야 한다.
  2. JELLY 카드를 누른다 → JELLY 판이 열리고 레벨 고정 크기·배 속 젤리·터질 듯한 얼굴이 표시되며 창이 종료되지 않아야 한다.
  3. 같은 색 L3이 L2를 두 번 먹게 하고 여러 번 중력을 바꾼다 → 크기는 60→60→85로 바뀌고 배 속 젤리가 중력 쪽을 따르며, 몸통 바깥 뒤 빛·어두운 띠는 다시 나타나지 않아야 한다.
  4. BLITZ·CLASSIC·SLIME 카드도 각각 연다 → 0.15.2가 네 모드를 포함한 마지막 보관 버전으로 모두 실행되어야 한다.
- 결정 사항: 명세대로 버전 한 줄과 Codex 회신만 변경함. 규칙·물리·그림·밸런스·사용자 저장 파일·기존 빌드 파일은 변경하지 않음
- 남은 것 · 질문: `computer-use` 스킬의 Windows 제어 런타임이 `kernel assets` 경로 오류로 초기화와 재시도 모두 실패해 시작 화면에서 JELLY 카드를 실제 포인터로 누르는 동작은 자동화하지 못함. 대신 격리 시작 화면 창과 격리 `--mode=jelly` 실제 Release 창을 각각 실행해 생존·창·로그를 확인함. 최종 합격/불합격 판정은 Claude에 남김

### [2026-10-25] 대상 #104 — JELLY 레벨 고정 크기 · 배 속 젤리 · 뒤 빛 삭제 · 어두운 띠 조사
- 상태: 완료 — JELLY의 물리·그림 반지름을 표시 레벨에 고정하고, 흡수한 질량은 배 속 젤리로 표시함. JELLY `BlastOutline`은 대폭발 가능 여부와 관계없이 숨기고, 어두운 띠 재현 계측·60판 규칙 측정·두 비율 전체 캡처까지 완료함
- 브랜치 / PR: `jelly-level-fixed-belly` / https://github.com/jeongmo-dot/gravity_orb/pull/106
- 변경 파일: `config/GameConfig.gd`, `scenes/Orb3D.tscn`, `scripts/core/JellyOrbArt.gd`, `scripts/spike/Orb3D.gd`, `tests/{capture_screens.ps1,test_config.gd,test_jelly_visuals.gd,test_jolt_3d.gd}`, `tests/spike/{capture_screens.gd,run_jolt_3d_measurement.gd}`, `tests/tools/run_jelly_measurement.ps1`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] `jelly_radius_for_mass(m)`을 `radius_for_level(jelly_level_for_mass(m))`으로 변경해 물리·그림 크기를 레벨 반지름에 고정. 같은 레벨 흡수는 60→60으로 크기 불변, L3 질량 6이 L2를 한 번 더 먹어 L4 질량 8이 될 때만 60→85를 0.10초 성장 — 자동 (`test_config`, `test_jolt_3d`)
  - [x] 배 속 젤리 채움 `f=(m-base)/base`, 틀 기준 위치 `(가로 +0.12r, 중력 +0.44r)`, 반지름 `0.54r×sqrt(f)`, 몸통색 0.35 밝게·알파 0.85·좌상단 흰 반사점 알파 0.70, 몸통 앞/얼굴 뒤·몸통 원 안 클립·몸통과 같은 틀/`deform`·0.15초 전환 적용. L7은 질량 상한으로 `f=0` — 자동 (`test_jelly_visuals`, `test_jolt_3d`) + 캡처 직접 관측
  - [x] JELLY에서는 L4~L7 및 armed/unarmed 모두 `BlastOutline`을 숨기고 터질 듯한 얼굴은 유지. CLASSIC·BLITZ 외곽 표시는 기존 경로 유지 — 자동 (`test_jelly_visuals`, `test_jolt_3d`) + 캡처 직접 관측
  - [x] 프레임마다 보이는 자식 메시 수·외곽 표시 프레임·비무장 외곽 표시·최대 알파와 0.5초 초과 피드백 노드를 계측. R/G/L-합체 60판에서 JELLY 외곽 표시 프레임 0·비무장 표시 0·최대 알파 0, 실제 두 번 흡수 캡처에서 0.5초 초과 피드백 0 — 자동 측정
  - [x] R·G·L-합체 × 시드 1~20 × 600턴 측정 완료. 무작위 판 길이 중앙 256.5, 실력 비 길이 1.446·점수 2.800, 초반 합체율 0.738로 §12-JE.4 바라는 범위 세 항목 모두 충족 — 자동 측정
  - [x] `57_jelly_full_{down,right,eat_00,eat_01,eat_02}`를 두 비율에서 마지막 전체 캡처. 아래 중력 L3 f=0/0.5/0.75와 L5 f=0.5, 오른쪽 중력 추종, 실제 L3+L2 두 번의 60→60→85를 총 10장에서 직접 확인 — 자동 캡처 + 직접 관측
  - [x] CLASSIC·BLITZ·SLIME 회귀 해시 유지, JELLY 시각 ON/OFF 해시 동일. 전체 테스트·5경로 스모크·Debug Windows 빌드·사용자 저장 불변 확인 — 자동
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`), 작업 시작 기준 `origin/main`과 브랜치 기준 모두 `b57a372`
  - `godot --headless --path . --import` 최종 실행 → 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 각 0건
  - `tests/run_tests.ps1` → 일반 `371/371` (`24.743초`), 장기 `5/5` (`43.247초`), 성능 `5/5` (`3.268초`), 합계 `381/381`, 종료 코드 0, 총 `71.258초`
  - JELLY 단일 회귀 재확인 → `18/18`, 시각 ON/OFF 상태 해시 `5c96a80c71c632fb8e727cf1be541757c464b436dd83d6c8d0737b1211347df1`. TURN `a27323b13e998dd0f41ff351aec47262dbe08108184d2d988af79aa829e8a724`, BLITZ `92eedf120de217f8760de532bd55bf12ad1ae82dff9bd4bc218e42a553ccbc80`; 기존 CLASSIC·SLIME 회귀 테스트도 통과
  - 규칙 측정 60판 결과:

    | 전략 | 턴 중앙 | 점수 중앙 | 1~30턴 합체/턴 | FINAL MOVE 성공/발생 | 한 단계 흡수 비율 | L7 판 비율 | 외곽 표시 프레임/비무장/최대 알파 |
    |---|---:|---:|---:|---:|---:|---:|---:|
    | R | 256.5 | 200,746 | 0.7383 | 1/21 (4.76%) | 0.5479 | 0.00 | 0 / 0 / 0.0 |
    | G | 327.0 | 301,083.5 | 0.7617 | 0/20 | 0.5423 | 0.05 | 0 / 0 / 0.0 |
    | L-합체 | 371.0 | 562,031.5 | 0.7800 | 0/20 | 0.5487 | 0.30 | 0 / 0 / 0.0 |

  - 비교 → #98 J5 `R 223.5 / L 328 / 길이비 1.468 / 점수비 4.15 / 초반 0.725`, #101 뒤 `R 230.5`; 현재 `R 256.5 / L 371 / 길이비 1.446 / 점수비 2.800 / 초반 0.738`. 같은 시드 L 우세율 길이 95%, 점수 90%; 길이비 1.3 이상·R 150~300·초반 CLASSIC C2 0.595 초과 모두 관측됨
  - 어두운 띠 조사 → 사용자 묘사와 크기·색이 일치하는 가장 강한 코드 후보는 #102의 `BlastOutline` 1.25r 제 색 빛 판이었으나, 이전 코드의 가시 조건은 armed뿐이라 “보통 얼굴”에서 켜진 정확한 경로는 재현하지 못함. 변경 뒤 R/G/L 60판 프레임 계측과 실제 흡수 2회에서 외곽 표시 0회, 비무장 표시 0회, 최대 알파 0, 0.5초 초과 근접 피드백 노드 0회; 두 비율 직접 관측에서도 띠 0건
  - `tests/capture_screens.ps1` 최종 전체 실행 → 두 비율×105개=`210`개 요구 캡처, 종료 코드 0. #104 10장 직접 확인: L3 f 증가에 따른 내부 젤리 증가, L5 얼굴 뒤 배치, 오른쪽 중력 쪽 이동·변형 추종, 실제 흡수 60→60→85, 외곽 빛·어두운 띠·얼굴 가림 각 0건. 캡처 테스트의 기존 TURN 점수 직접 대입 뒤 HUD 신호 누락도 함께 보강
  - 기본·TURN·BLITZ·SLIME·JELLY `--quit-after 300` → 5개 모두 종료 코드 0, 오류 표식 0건
  - `tools/build_windows.ps1 -Debug` → 종료 코드 0, `build/windows-debug/GravityOrb_v0.15.1.exe` `105,090,848`바이트; Release 미실행
  - 사용자 `save.cfg`는 검증 전후 `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D` 동일
  - 규칙 검사 → 허용 파일 외 신규 `Input`/`InputEvent` 0건, 본 변경의 신규 전역 난수 호출 0건, `git diff --check` 오류 0건. 전체 검색의 `SlimeSim`/`SlimeGame` 명시적 RNG는 기존 코드이며 diff 없음
- 수동 확인 절차:
  1. `--mode=jelly`에서 같은 색 L3과 L2를 한 번 합친다 → 먹는 L3의 몸통·충돌 크기는 L3 그대로이고, 배 속 중력 쪽에 밝은 같은 색 젤리가 약 0.15초에 걸쳐 나타나야 한다.
  2. 같은 L3이 같은 색 L2를 한 번 더 먹게 한다 → 표시 레벨이 L4로 바뀌면서 몸통·물리 반지름이 L3 60에서 L4 85로 약 0.10초 성장하고, 새 레벨의 `f=0`이 되어 배 속 젤리는 약 0.15초에 걸쳐 사라져야 한다.
  3. 중력을 네 방향으로 바꾼다 → 배 속 젤리는 몸통과 함께 변형되며 항상 중력 쪽으로 돌고, 얼굴은 화면 위를 유지하며 배 속 젤리보다 앞에 보여야 한다.
  4. L5·L6·L7을 만들고 여러 번 움직인다 → L5·L6의 터질 듯한 얼굴은 남지만 몸통 뒤 제 색 빛·어두운 외곽 띠는 어느 프레임에도 보이지 않아야 한다. CLASSIC·BLITZ 대폭발 표시는 기존처럼 보여야 한다.
- 결정 사항: 명세 수치만 사용했고 밸런스·규칙·점수·질량 계산·공개 API는 변경하지 않음. 측정의 60개 미리보기 월드는 시각 `_process`만 끄고 물리·규칙은 유지해 병렬 실행 시간을 줄였으며, 결과 판단은 Claude에 남김
- 남은 것 · 질문: 자동 검증·측정·전체 캡처·직접 관측을 완료함. 사용자 보고의 “보통 얼굴에서 나타난” 정확한 과거 활성화 경로는 재현되지 않았고, 시각적 후보인 `BlastOutline`을 JELLY에서 무조건 숨긴 뒤 재현 0회를 관측함. 최종 합격/불합격 판정은 Claude에 남김

### [2026-10-25] 대상 #103 — Windows 빌드 0.15.1
- 상태: 완료 — 최신 `origin/main`의 #101·#102 반영 상태에서 프로젝트 버전을 `0.15.1`로 올리고 Godot 4.8 Standard Release Windows 패키지를 생성·검증함
- 브랜치 / PR: `build-0.15.1` / https://github.com/jeongmo-dot/gravity_orb/pull/105
- 변경 파일: `project.godot`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] 최신 `origin/main` `e925494`에서 전용 브랜치를 만들고 `application/config/version`을 `0.15.0`에서 Claude 결정 값 `0.15.1`로 변경 — 자동
  - [x] 버전 변경을 먼저 독립 커밋한 뒤 깨끗한 작업 트리에서 Release `GravityOrb_v0.15.1.exe`·`.console.exe`·`_BUILD.txt` 생성 — 자동
  - [x] 내보낸 콘솔 exe 기본·TURN·BLITZ·SLIME·JELLY 다섯 경로 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 0건 — 자동
  - [x] 격리 `APPDATA`에서 시작 화면과 JELLY 직접 실행 창을 각각 5초 확인: 두 프로세스 생존, 창 제목 `Gravity Orb`, 창 핸들 0 아님, `godot.log` 오류 0건 — 자동. 시작 화면 JELLY 카드 실제 클릭은 아래 수동 절차로 남김
  - [x] 사용자 `save.cfg` 크기·SHA-256 불변, 패키지에서 `tests/`·`artifacts/`·`docs/`와 테스트·캡처·인박스·설계 문서 표식 각 0건 — 자동
  - [x] 0.15.0 Release 산출물 3개를 유지하고 전체 테스트·소스 5경로 스모크·규칙 검사를 통과 — 자동
  - [x] 회신 커밋 뒤 깨끗한 작업 트리에서 최종 재빌드해 `_BUILD.txt` 커밋과 브랜치 마지막 커밋 일치 확인 — 자동
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` → 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 각 0건
  - `tests/run_tests.ps1` → 일반 `370/370` (`28.015초`), 장기 `5/5` (`52.133초`), 성능 `5/5` (`3.466초`), 합계 `380/380`, 종료 코드 0, 총 `83.614초`
  - Godot 소스 기본·TURN·BLITZ·SLIME·JELLY `--quit-after 300` → 5개 모두 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 0건
  - `tools/build_windows.ps1` Release → 종료 코드 0, 결과 줄 `version=0.15.1 mode=Release exit=0 bytes=111219904`
  - 산출물 → `GravityOrb_v0.15.1.exe` `111,219,904`바이트, `.console.exe` `50,176`바이트, `_BUILD.txt` `159`바이트; PE 파일·제품 버전 `0.15.1.0`, 제품 이름 `Gravity Orb`
  - 내보낸 콘솔 exe 기본·TURN·BLITZ·SLIME·JELLY → 5개 모두 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 0건
  - 격리 GUI → 시작 화면·`--mode=jelly` 각각 5초 생존, 창 제목 `Gravity Orb`, 창 핸들 각각 0 아님, 로그 파일 각각 1개, 오류 표식 각 0건; 임시 `APPDATA` 두 폴더는 확인 뒤 삭제
  - 패키지 문자열 검사 → `res://tests/`·`res://artifacts/`·`res://docs/`·`run_tests.gd`·`capture_screens.gd`·인박스·설계 문서 표식 각 0건; `JellyOrbArt.gdc`·`Main3D.scn`·`StartScreen.gdc` 각 2건
  - 이전 `0.15.0`의 exe·console exe·BUILD txt 3개 유지, 삭제 0건
  - 사용자 `save.cfg`는 검증 전후 `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D` 동일
  - 규칙 검사 → 허용 파일 외 신규 `Input`/`InputEvent` 0건, 신규 전역 난수 호출 0건, `git diff --check` 오류 0건. 버전·회신만 바꿔 화면 캡처는 미실행
- 수동 확인 절차:
  1. `build/windows/GravityOrb_v0.15.1.exe`를 실행한다 → 시작 화면에 BLITZ·CLASSIC·JELLY·SLIME 카드 4장이 보여야 한다.
  2. JELLY 카드를 누른다 → JELLY 판이 열리고 젤리 얼굴·대폭발 가능 얼굴·뒤 빛이 보이며 창이 종료되지 않아야 한다.
  3. JELLY에서 중력을 여러 번 바꾼다 → 젤리 움직임이 지글거리거나 툭 튀지 않고 얼굴·문양은 화면 위쪽을 유지해야 한다.
- 결정 사항: 명세대로 버전 한 줄과 Codex 회신만 변경함. 규칙·물리·그림·밸런스·사용자 저장 파일·기존 빌드 파일은 변경하지 않음
- 남은 것 · 질문: 시작 화면과 JELLY 직접 실행 창은 각각 검증했으나 시작 화면에서 JELLY 카드를 실제 포인터로 누르는 동작은 자동화하지 않음. 최종 합격/불합격 판정은 Claude에 남김

### [2026-10-25] 대상 #102 — JELLY 대폭발 가능 표시: 터질 듯한 얼굴
- 상태: 완료 — 추가 요구 1까지 반영. JELLY의 어두운 대폭발 링을 제거하고, L5·L6에는 시안 C의 얼굴, L5·L6·L7에는 보드보다 앞·몸통보다 뒤인 제 색 빛을 적용함. 모든 JELLY 얼굴·문양은 화면 위쪽으로 고정하고 중력 기준 말랑함만 유지함
- 브랜치 / PR: `jelly-blast-face` / https://github.com/jeongmo-dot/gravity_orb/pull/104
- 변경 파일: `scripts/core/JellyOrbArt.gd`, `scripts/spike/Orb3D.gd`, `tests/{capture_screens.ps1,test_jelly_visuals.gd,test_jolt_3d.gd}`, `tests/spike/capture_screens.gd`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] JELLY 대폭발 가능 표시에서 기존 어두운 링을 제거하고 CLASSIC·BLITZ 경로는 변경하지 않음 — 자동 (`test_jelly_visuals`) + 캡처 직접 관측
  - [x] 대폭발 가능 L5·L6에 §12-JE.8의 정확한 좌표·굵기·색·얼굴 판 1.0 배율을 사용한 고정 얼굴을 표시하고 깜빡임을 끔. L4는 보통 얼굴, L7은 기존 MAX 얼굴 유지 — 자동 (`test_jelly_visuals`, `test_jolt_3d`) + 캡처 직접 관측
  - [x] L5·L6·L7 뒤 빛을 z `-0.30m`에 두어 보드 배경판·격자보다 앞, 몸통보다 뒤에 보이게 함. 0..1 UV 판과 인스턴스 `glow_alpha`로 1.25r·알파 0.22↔0.40·1.6초 사인을 그대로 적용하고 프레임당 알파 변화 0.02 이하 유지 — 자동 (`test_jelly_visuals`) + 확대 캡처 픽셀 관측
  - [x] 대폭발 얼굴과 MAX 얼굴의 볼은 `#FF4F7F`를 얼굴 어두운 색과 섞지 않고 각각의 명세 알파로만 합성 — 자동 (`test_jelly_visuals`) + 노랑·초록·파랑 L5 픽셀 관측
  - [x] 모든 JELLY 얼굴·문양의 회전은 화면 기준 0이고, 얼굴 판 말랑함은 정확히 `R(θ)·S(deform)·R(−θ)`로 적용. 몸통·빛은 기존 중력 틀 유지 — 자동 (상·하·좌·우 및 오른쪽 중력 축 배율 테스트) + 캡처 직접 관측
  - [x] `jelly_blast_min_level=0`이면 얼굴·빛 표시 없음 — 자동 (`test_jelly_visuals`, `test_jolt_3d`)
  - [x] TURN·BLITZ·CLASSIC·SLIME·JELLY 상태 해시 유지 — 자동
  - [x] 두 비율에서 `56_jelly_blast_face_down`(노랑·보라·초록·파랑 L5, L6, L7), `face_right`(오른쪽 중력 붐비는 판), `glow_min/max` 확대를 마지막 전체 캡처 — 자동 캡처 + 8장 직접 관측
  - [x] 전체 래퍼, 5경로 스모크, Debug Windows 빌드, 사용자 저장 해시 불변 — 자동
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - 추가 요구 확인 전 `origin/main` `b3a9b4f`를 병합 (`5194291`)한 뒤 구현
  - `godot --headless --path . --import` 최종 정상 권한 실행 → 종료 코드 0, `ERROR`·`SCRIPT ERROR`·`Parse Error` 각 0건
  - `tests/run_tests.ps1` → 일반 `370/370` (`27.902초`), 장기 `5/5` (`48.972초`), 성능 `5/5` (`3.283초`), 합계 `380/380`, 종료 코드 0, 총 `80.158초`
  - 해시 → TURN `a27323b13e998dd0f41ff351aec47262dbe08108184d2d988af79aa829e8a724`, BLITZ `92eedf120de217f8760de532bd55bf12ad1ae82dff9bd4bc218e42a553ccbc80`, CLASSIC 단계 `cf6172428c7901c43eb74f417e6880dc3ad375a329e669a8904234f5d38d1031`, SLIME 단계 `7ebe5d76b8c4843fa739e5c10405da172b577fdea1caca2047ed176b07455e97`, JELLY 시각 `5c96a80c71c632fb8e727cf1be541757c464b436dd83d6c8d0737b1211347df1`
  - 기본·TURN·BLITZ·SLIME·JELLY `--quit-after 300` → 5개 모두 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `tests/capture_screens.ps1` 최종 전체 실행 → 두 비율×102장=`204`장, 종료 코드 0. #102 추가 요구 4장씩 총 8장을 직접 확인: 얼굴·빛 잘림 0건, 어두운 링 0건, 아래·오른쪽 중력 모두 얼굴·문양 회전 0
  - 볼 픽셀(두 화면비 동일, 실제/몸통/예상 알파 합성) → 노랑 L5 `(247,133,126)/(235,215,124)/(247,133,126)`, 초록 L5 `(192,131,142)/(96,210,164)/(191,131,142)`, 파랑 L5 `(200,112,170)/(117,161,234)/(200,112,170)`; 채널 허용 오차 12 이내, 측정 실패 0건
  - 빛 픽셀(두 화면비 동일, 몸통 중심에서 1.1r 지점/배경 1.38r) → 최저 알파 RGB `(26,48,57)`, 휘도 `0.17308`; 최고 알파 `(36,72,73)`, 휘도 `0.25150`; 배경 휘도 `0.07769`. 최저>배경, 최고>최저 검증 실패 0건
  - `tools/build_windows.ps1 -Debug` → 종료 코드 0, `build/windows-debug/GravityOrb_v0.15.0.exe` `105,089,728`바이트; Release 미실행
  - 사용자 `save.cfg`는 검증 전후 `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D` 동일
  - 규칙 검사 → 허용 파일 외 신규 `Input`/`InputEvent` 0건, 본 변경의 신규 전역 난수 호출 0건, `git diff --check` 오류 0건. 전체 검색의 `SlimeSim`/`SlimeGame` 명시적 RNG는 기존 코드이며 diff 없음
- 수동 확인 절차:
  1. `56_jelly_blast_face_down` 또는 같은 JELLY 판에서 노랑·보라 L5와 L6·L7을 본다 → 어두운 링 없이 L5·L6은 `>`·`<` 눈, `o` 입, 선명한 분홍 볼, L7은 기존 MAX 얼굴이어야 한다.
  2. 중력을 오른쪽으로 바꾸고 붐비는 판을 움직인다 → 몸통과 뒤 빛은 중력 틀을 따르지만 모든 얼굴·문양은 화면 위쪽을 유지하고, 찌그러짐 축만 중력 기준으로 보여야 한다.
  3. `56_jelly_blast_glow_min/max` 또는 같은 L5를 1.6초 이상 본다 → 빛이 격자·배경판 앞이면서 몸통 뒤에서 가장자리 밖 0.25r까지 보이고, 은은하게 밝아졌다 어두워져야 한다.
  4. `jelly_blast_min_level=0`으로 실행한다 → L5·L6의 터질 듯한 얼굴과 L5~L7 뒤 빛이 모두 없어야 한다.
- 결정 사항: 빛의 색은 §12-JE.8의 “제 색보다 약간 밝게”를 기존 `LEVEL_LIGHTEN_AMOUNT`로 적용함. 빛 판은 기존 천체용 4..5 UV 메시 대신 얼굴용 0..1 UV 판을 재사용하고, 투명도는 인스턴스 셰이더 매개변수로 전달함. 새 밸런스 수치·공개 API 변경 없이 규칙·물리·점수·다른 모드 그림·설정 값을 유지함
- 남은 것 · 질문: 자동 검증·전체 캡처·직접 관측을 완료했으며 최종 합격/불합격 판정은 Claude에 남김

### [2026-10-25] 대상 #101 — JELLY 움직임 다듬기 (지글거림·툙툙 튀)
- 상태: 완료 — 추가 요구 1까지 반영. 변형된 몸통의 실제 앞면을 기준으로 얼굴·기호를 배치하고, 새 젤리의 첫 중력 틀은 즉시 맞추되 이후 중력 전환만 부드럽게 회전시킴. 흡수 레벨업은 흡수자 현재 반지름에서 0.10초 성장하며, 실제 접촉 더미로 전후 측정·캡처를 다시 수행함
- 브랜치 / PR: `jelly-motion-smoothing` / https://github.com/jeongmo-dot/gravity_orb/pull/103
- 변경 파일: `scripts/core/{CollisionResolver,TurnManager}.gd`, `scripts/spike/{Board3D,Orb3D}.gd`, `tests/{capture_screens.ps1,run_jelly_motion_measurement.ps1,test_jelly_visuals.gd,test_jolt_3d.gd}`, `tests/scenarios/test_ui_fixes.gd`, `tests/spike/{capture_screens.gd,JellyMotionMeasurement.tscn,run_jelly_motion_measurement.gd}`, `docs/jeongmo_codex_to_claude.md`
- Done-when 대조:
  - [x] JELLY 틀을 중력 방향으로 `delta×8`, 단일 `deform`을 `delta×11`로 보간하고 몸통·얼굴에 같이 적용; 속도 방향 회전·즉시 스케일·`TRANS_BACK` 제거 — 자동 (`test_jelly_visuals`) + 캡처 직접 관측
  - [x] 추가 요구 1: 최대 눌림·L7 호흡 최대·합체 펀치에서도 얼굴·기호 Z를 변형 몸통 실제 앞면보다 앞으로 배치 — 자동 (`test_jelly_face_and_symbol_stay_in_front_of_deformed_body`) + 캡처 직접 관측
  - [x] 추가 요구 1: 새 JELLY는 생성 당시 첫 중력 각도에 즉시 맞고, 이미 존재하는 JELLY만 이후 중력 변경을 `delta×8`로 보간 — 자동 (`test_new_jelly_frame_starts_at_first_gravity_then_turns_smoothly`)
  - [x] 낙하 `v·g/5800`(최대 0.19), 속력 감소 `/1000`의 충돌 강도·0.06 미만 무시·`4.8/s` 감쇠, 입력 대기에서만 `delta×4` 숨쉬기 — 자동 (`test_jelly_deform_*`, `test_jelly_impact_*`, `test_jelly_frame_*`)
  - [x] 흡수 결과의 물리·그림 반지름을 흡수자 현재 반지름→신규 반지름으로 0.10초 동안 증가. 질량 6(`72.5`) + 2 → 8(L4 `85.0`)은 0.05초 `78.75`, 0.10초 `85.0` — 자동 (`test_jelly_absorption_keeps_larger_position_mass_and_interpolated_radius`)
  - [x] CLASSIC·BLITZ·JELLY 3D 그림 위치를 이전/현재 물리 위치와 `Engine.get_physics_interpolation_fraction()`으로 보간하고 생성·입구 대기/해제·순간이동·물리 끄기에서 기록 초기화 — 자동 (`test_visual_position_interpolates_and_teleport_resets_history`, `test_interpolation_smooths_120hz_physics_for_164hz_rendering`, `test_3d_symbol_uses_interpolated_fast_body_position_before_render`)
  - [x] 실제로 떨어뜨린 40개를 5회 중력 전환 후 접촉 더미로 만든 뒤 정지·1.5초 이동을 전후 측정. 변경 후 접촉쌍 68개, 정지 충돌 시작 0회/초, 정지 최대 크기 변화 0.0270%, 이동 최대 크기 변화 2.5587%, 틀 변화 0.104720rad — 자동 측정
  - [x] CLASSIC·BLITZ·SLIME 기준 해시 유지, JELLY 시각 켜기/끄기 해시 동일, 흡수 성장이 반영된 JELLY 신규 시드 1 마지막 상태 해시 보고 — 자동
  - [x] JELLY 무작위 R 20시드×600턴 상한 재측정, 중앙값 `230.5`턴으로 #98 J5 `223.5±10%` 범위 `201.15~245.85` 안 — 자동 측정
  - [x] 두 비율 `55_jelly_motion_land_01~10`·`breathe_max`·`rest`·`right`와 실제 40개 접촉 더미(3턴 이상)를 마지막 전체 캡처로 실행 — 자동 캡처 + 착지 6~8·L7 호흡 최대·정지·오른쪽 이동 직접 관측
  - [x] 전체 래퍼, 5경로 스모크, 실제 GPU 창 측정, Debug Windows 빌드, 사용자 저장 해시 불변 — 자동
- QA 관측값:
  - Godot `4.8.dev3.official.51105ccbe` Standard (`C:\work\GodotStandard\Godot_v4.8-dev3_win64_console.exe`)
  - `godot --headless --path . --import` 최종 권한 실행 → 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - 실제 접촉 더미 측정(`orbs=40`, `turns=5`): `origin/main`은 접촉쌍 `69`, 정지 충돌 시작 `0.000000/s`, 정지 크기 변화 `0.000270`, 1.5초 이동 크기 변화 `0.268981`, 틀 회전 변화 `1.724097rad`; 변경 후 접촉쌍 `68`, `0.000000/s`, `0.000270`, `0.025587`, `0.104720rad`, 호흡 전환 `0.000666`. 즉 이동 중 최대 크기 변화는 `26.8981%→2.5587%`, 틀 변화는 `1.724097→0.104720rad`
  - `tests/run_tests.ps1` → 일반 `367/367` (`25.315초`), 장기 `5/5` (`43.798초`), 성능 `5/5` (`3.380초`), 합계 `377/377`, 종료 코드 0, 총 `72.493초`
  - 해시 → TURN `a27323b13e998dd0f41ff351aec47262dbe08108184d2d988af79aa829e8a724`, BLITZ `92eedf120de217f8760de532bd55bf12ad1ae82dff9bd4bc218e42a553ccbc80`, CLASSIC 단계 `cf6172428c7901c43eb74f417e6880dc3ad375a329e669a8904234f5d38d1031`, SLIME 단계 `7ebe5d76b8c4843fa739e5c10405da172b577fdea1caca2047ed176b07455e97` 기존 기준 동일. JELLY 시각 ON/OFF `5c96a80c71c632fb8e727cf1be541757c464b436dd83d6c8d0737b1211347df1` 동일; 추가 요구 반영 신규 시드 1은 `209`턴 종료, 마지막 상태 `95ecb85998dc11d3b1b7aeed67728fbb78f1a4d1104e799e3ccbeaac42e4e8b0`
  - JELLY R 20시드 완료 턴 → 중앙 `230.5`, 최소 `202`, 최대 `260`; 요구 범위 안
  - 실제 창(RTX 4070 Ti SUPER, VSync off) JELLY 40개 → `2,406`표본, p99 `2.854ms`, 최대 `5.091ms`, `16.7ms`/`33.3ms` 초과 각 0프레임, draw call 최대 `253`. 표시장치 실제 주사율은 자동 보고에 포함되지 않아 미측정
  - `tests/capture_screens.ps1` 최종 전체 실행 → 두 비율×98장=`196`장, 종료 코드 0. 캡처의 실제 더미는 40개·접촉쌍 71개·중력 전환 5회. `land_06~08`과 `breathe_max`에서 MAX 얼굴이 몸통 앞에 선명하게 유지되고, `rest`는 바닥에 닿아 쌓인 실제 더미, `right`는 오른쪽으로 이동·적층 중인 실제 더미임을 두 화면비에서 직접 확인; 얼굴 겹침·잘림 0건
  - 기본·TURN·BLITZ·SLIME·JELLY `--quit-after 300` → 5개 모두 종료 코드 0, `SCRIPT ERROR`·`Parse Error` 0건
  - `tools/build_windows.ps1 -Debug` → 종료 코드 0, `build/windows-debug/GravityOrb_v0.15.0.exe` `105,086,640`바이트; Release 미실행
  - 사용자 `save.cfg` 캡처·창·빌드 검증 전후 `1,488`바이트, SHA-256 `4D8C75B028AD8710E8B24779A35283848845F75D9A97D238B9D24419BD1FB14D` 동일
  - 규칙 검사 → 본 항목의 신규 `Input`/`InputEvent`·전역 난수 호출 0건, `git diff --check` 오류 0건. 전체 검색의 `SlimeSim`/`SlimeGame` 명시적 RNG는 기존 코드이며 diff 없음
- 수동 확인 절차:
  1. `--mode=jelly`로 실행해 상·하·좌·우로 스와이프한다 → 이동 중 얼굴과 몸통이 서로 어긋나지 않고, 속도 방향으로 틀이 돌지 않으며, 중력 방향을 부드럽게 함께 따라가야 한다.
  2. 떨어지는 젤리가 벽에 내려앉는 순간을 본다 → 낙하 중에는 중력 축으로 늘어나고, 충돌 순간에는 중력 축으로 납작해진 뒤 튀지 않고 이어서 원형으로 복귀해야 한다.
  3. 붐비는 대기 판을 3초 이상 본다 → 접촉이 재연결될 때마다 찌그러지거나 숨쉬기가 급격히 켜지고 꺼지는 지글거림이 없어야 한다.
  4. 같은 색 단계 차 1 젤리를 흡수시킨다 → 먹는 쪽의 물리·그림 크기가 한 프레임에 튀지 않고 약 0.10초 동안 커져야 한다.
  5. 아래/왼쪽/오른쪽 중력 상태에서 새 JELLY를 만든다 → 생성 프레임부터 해당 중력 각도로 보이고, 그 뒤 중력을 바꿀 때만 부드럽게 회전해야 한다.
- 결정 사항: `origin/main` `6eee55c`를 먼저 병합함. 실제 물리와 독립된 렌더 보간 기록을 `Orb3D` 내부에 두었고, 턴 상태는 `TurnManager → Board3D → Orb3D` 호출로 전파함. 흡수자 반지름은 `CollisionResolver`가 기존 소스 반지름 기록에서 결과 `Orb3D`에 전달함. 밸런스 수치·규칙·점수·SLIME은 변경하지 않음
- 남은 것 · 질문: 자동 검증·실제 창·전체 캡처·직접 관측을 완료했으며 최종 합격/불합격 판정은 Claude에 남김
