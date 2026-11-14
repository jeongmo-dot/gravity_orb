# Claude → Codex 인수인계

**Claude만 이 파일을 쓴다.** Codex는 읽기만 하고, 답변은 `jeongmo_codex_to_claude.md`에 적는다.
서로의 파일을 고치지 않는 것이 이 창구의 유일한 규칙이다.

## 작성 규칙

- 새 항목은 **「대기 중」 맨 위**에 추가한다. 번호는 계속 증가하며 **재사용하지 않는다**
- 상태는 **Claude가** 갱신한다. Codex의 회신을 확인한 뒤 `완료`로 바꾸고 「처리 완료」로 옮긴다
- **긴 명세는 여기에 붙여넣지 않는다.** `technical_design.md` 또는 별도 문서에 두고 **링크와 요약만** 적는다
- Codex는 「대기 중」에서 **번호가 가장 낮은 항목 하나만** 처리한다 (항목에 "먼저"라고 적힌 예외는 그것부터)
- 항목 검증용 Windows 빌드는 `-Debug`로 (`build/windows-debug/`). 릴리스 이름 파일은 빌드 항목에서만 만든다 ([technical_design.md](technical_design.md) §10.5.1)
- 완료 항목이 30건을 넘으면 `docs/archive/`로 옮긴다 — #1~#100은 [archive/claude_to_codex_001-100.md](archive/claude_to_codex_001-100.md) (2026-10-25)
- **고리 모양 연출·그림 금지** (사용자 2026-10-25 "고리를 그리는 거 다 지워", "다시 사용하지 마") — 도넛·원 테두리·타원 선 모양은 만들지 않는다. **명세에 없는 연출·기능은 넣지 않는다** ([technical_design.md](technical_design.md) §12-ONE.4)

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

### [2026-11-14 #148] 시한 젤리·굳은 젤리 숫자를 또렷하게
- 상태: 대기 (#147 병합됨 `2371786` — main 위에서)
- 근거: [technical_design.md](technical_design.md) **§12-ONE.39**
- 배경: 굳은 젤리 위 '18'이 '13'·'1目'처럼 뭉개진다 — 흰 획 대부분 밝기 175~224 (몸통 124~154), 숫자 둘레가 어두운 상자처럼 보인다 (Claude 캡처 `205` ×5 확대·줄별 밝기, 두 비율). 추정 원인: `font_size` 7로 그린 글자를 화면에서 약 3배로 늘림 (Orbitron MSDF 꺼짐), `outline_size` 4가 화면 약 12px. 사용자 (2026-11-14) "병합 + 후속: 숫자 고치기"
- 앵커: `scenes/Orb3D.tscn` `TimedLabel`, `scripts/spike/Orb3D.gd` (`_timed_label.font_size`·`outline_size`), `assets/fonts/Orbitron[wght].ttf.import` (바꾸면 HUD 영향 확인), `tests/test_timed_jelly.gd`, `tests/spike/capture_screens.gd`
- 요구 (§12-ONE.39 1~8):
  1. 화면 크기는 그대로, 글자를 화면 크기에 가깝게 그리기 (화면 글자 높이 ÷ 그리는 크기 ≤ 1.2, 또는 MSDF) — 원인 확인·고른 방법과 이유를 회신에
  2. 외곽선 화면 2~3px, 색 그대로
  3. 540×960 L5 흰 획 높이 18~22px, 눈 아래 2px 이상, 윤곽 안 3px 이상 여유 (두 자리 포함)
  4. 읽힘: 모든 획 가운데 밝기 225 이상, '8'·'0' 구멍 가운데 175 미만, 외곽선이 몸통보다 40 이상 어둡다 — 굳은 '18'·'10'·'1', 시한 (노랑) '4'·'1'
  5. 캡처 `199`·`200`·`205`·`207`·새 `210` (굳은 10), 두 비율 + 숫자별 ×5 확대 조각 `artifacts/screens/<비율>/zoom/`
- 수치 (Claude): 외곽선 2~3px, 비율 1.2, 읽힘 밝기 기준. 크기·자리는 #145 기준 그대로
- 건드리지 말 것: 글꼴·굵기·흰 글자·외곽선 색, 굳은 젤리 몸통 색, 숫자 자리 규칙, NEXT·THEN 숫자, HUD 글자, 규칙·수치 전부, 연출 (명세에 없는 것 금지, 숫자 뒤 원판·고리 금지), 사용자 저장 파일, `project.godot` 버전·`build/windows/` Release 파일 (**빌드 없음**), `docs/` (회신 파일 제외)
- **회신 맨 앞에**: 읽힘 기준을 못 맞춘 숫자, 흰 획 높이 18~22px 밖, 눈·윤곽과 겹침, HUD 등 다른 글자 모양 바뀜, 해시 바뀜
- Done-when:
  - [ ] 테스트 통과 (비율 ≤ 1.2·외곽선 두께·두 자리 눈 아래/윤곽 안), 해시 모두 그대로
  - [ ] 캡처 두 비율 + ×5 확대 조각, 숫자별 4번 측정값
- QA: §12-ONE.39 4·6·7번
- 커밋: 항목 단위 브랜치 (`timed-number-crisp`), **push·PR까지** (병합은 Claude 검수 뒤)

---

## 처리 완료

### [2026-11-14 #147] 시한 젤리가 0이 되면 회색 굳은 젤리 — 완료
- 상태: 완료 (2026-11-14 사용자 "병합 + 후속: 숫자 고치기" · [PR #147](https://github.com/jeongmo-dot/gravity_orb/pull/147) 병합 `2371786`. [PR #146](https://github.com/jeongmo-dot/gravity_orb/pull/146) 닫음)
- 검수: 코드 diff, 테스트 diff, 회신 판 균형표 (S6·S12·S18 × 5봇 × 20판 + #145 K5-4), 캡처 `202`·`205`·`207`·`208`·`209` 두 비율 직접 확인·`205` ×5 확대와 줄별 밝기 (캡처 파일만 읽음). 테스트 362/4/5·해시·스모크·Debug 빌드는 Codex 관측 (Claude 재실행 없음). 빌드 없음 (`project.godot` 변경 0). 맨 앞 경고 0건 — 규칙대로 S18 (자동 D-save 197.00턴, 같은 색 대비 −28%). 굳은 젤리 반응 0. Claude 지적: 굳은 젤리 위 두 자리 숫자 ('18')가 뭉개져 읽기 어려움 → 사용자 "병합 + 후속: 숫자 고치기" (#148). 결과: §12-ONE.38 "#147 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.38**
- 배경: 0이 되면 L1을 쏟는 벌은 약했다 — 같은 색 (#145)은 바로 L5로 다시 뭉치고, 다른 색 (#146)도 0이 될 때마다 1.5~1.9쌍이 합쳐지며 콤보·칭찬 (`x8 COMBO 4`·`NICE!`)이 떴고 봇 판 길이도 줄지 않았다 (§12-ONE.37 "#146 결과"). 사용자 (2026-11-14) "병합 보류·벌 다시 설계" → "회색 돌로 굳기"
- 앵커: `scripts/core/TurnManager.gd` `_advance_timed_jellies()`·`_spawn_timed_burst()`·`_on_settled()`, `scripts/core/CollisionResolver.gd` `_pair_can_react()`·청소 대상 고르기, `scenes/Orb3D.tscn` `TimedLabel`·`scripts/spike/Orb3D.gd`, `scripts/ui/Hud.gd` 시한 젤리 안내 줄, `config/GameConfig.gd`·`default_config.tres` 새 필드, `tests/test_timed_jelly.gd`, `tests/tools/run_timed_jelly_balance.ps1`, `tests/spike/capture_screens.gd`
- 요구 (§12-ONE.38 1~9):
  1. 숫자 0 → 그 자리에서 굳은 젤리 (자리·레벨·크기·질량 그대로, L1 없음, 점수 없음)
  2. 굳은 젤리는 어떤 반응에도 안 들어감 (합체·대폭발·터치 청소·색 청소·터치 소폭발). 물리·입구·경고·게임 오버는 보통 젤리처럼
  3. 남은 턴 `jelly_timed_stone_turns` — 굳은 턴 끝에는 줄지 않고 그 뒤 턴 끝마다 −1, 0이면 사라짐 (점수 없음) → 정착 한 번 더
  4. 그림: 몸통만 회색 sRGB (0.55, 0.57, 0.60), 얼굴·하이라이트 그대로, `%TimedLabel`에 남은 턴. 새 연출 없음 (사라짐은 지금 있는 그림 하나 — 회신에 이름)
  5. 첫 굳은 젤리 때 안내 한 줄 `굳은 젤리: <N>턴 동안 합칠 수 없음`
  6. 새 필드 `jelly_timed_stone_enabled` (true, false = #145 그대로 — K5-4 해시 `bc86d257…`)·`jelly_timed_stone_turns`
  7. 판 균형 S6·S12·S18 × 5봇 × 20판, 600턴 상한, §12-ONE.36과 같은 칸 + 판당 굳은 젤리·동시 최대·끝날 때 판에 있던 수·굳은 젤리 반응 수
  8. 새 기본 = 자동 D-save·R D-save 성공 둘 다 40~60% **그리고** 자동 D-save 평균 176.4턴 이상인 이름 중 **남은 턴이 가장 긴 것**. **없으면 S6** + 회신 맨 앞
  9. 캡처 `204`·`205`·새 `207`·`208`·`209`·`202` (숫자 기본값), 두 비율
- 수치 (Claude): 위 세 이름의 남은 턴, 기본 고르는 규칙, 회색 기준값, 안내 문구. 그 밖의 값은 그대로
- 건드리지 말 것: 시한 젤리 규칙 나머지 (차례·숫자 4·성공 +1·L5·미리보기·시한 젤리 안내 문구), 판 위 숫자 자리·모양, 지금 규칙·수치 전부, 그림·연출 (명세에 없는 것 금지, 고리·파편 금지), 사용자 저장 파일, `project.godot` 버전·`build/windows/` Release 파일 (**빌드 없음**), `docs/` (회신 파일 제외)
- **회신 맨 앞에**: 규칙에 맞는 이름 없음 (S6 기본), 굳은 젤리가 반응에 들어간 일, 판 밖 이탈, 시한 젤리를 끈 해시 바뀜, false 주입 K5-4 해시 바뀜
- Done-when:
  - [ ] 테스트 통과, 시한 젤리를 끈 해시·false 주입 K5-4 해시 그대로, 새 기본 해시 고정
  - [ ] 판 균형표 S6·S12·S18 (+ #145 K5-4)와 고른 기본, 굳은 젤리 반응 0
  - [ ] 캡처 `204`·`205`·`207`·`208`·`209`·`202` (두 비율)
- QA: §12-ONE.38 6·7·8번
- 커밋: 항목 단위 브랜치 (`timed-stone`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-13 #146] 시한 젤리가 0이 되면 다른 색 L1 — 완료 (병합 안 함)
- 상태: 완료 — **병합 안 함** (2026-11-14 사용자 "병합 보류·벌 다시 설계" → "회색 돌로 굳기", #147로 대체. [PR #146](https://github.com/jeongmo-dot/gravity_orb/pull/146)은 2026-11-14 #147 병합 때 닫음 — 브랜치 `timed-burst-colors`는 남김)
- 검수: 코드 diff, 테스트 diff, 회신 판 균형표 (B10·B8·B6 × 5봇 × 20판 + #145 K5-4), 캡처 `202`·`205`·`207` 두 비율 직접 확인 (캡처 파일만 읽음). 테스트 361/4/5·해시·스모크·Debug 빌드는 Codex 관측 (Claude 재실행 없음). 구현은 명세대로. 맨 앞 경고 한 건 — B10에서 터진 L1끼리 0이 될 때마다 1.5~1.9쌍 합체. Claude 추가 지적: `207` 실패 직후 `x8 COMBO 4`·`NICE!`·`+32`, 봇 판 길이로 벌이 보이지 않음. 결과: §12-ONE.37 "#146 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.37**
- 배경: 0이 되면 원본 색 L1 10개가 원래 자리에 거의 붙어 (간격 52.5, L1 지름 50) 놓여 유령이 풀리자마자 서로 합쳐진다 — L5 언저리로 돌아가고 콤보·점수까지 붙어 벌이 되지 않는다 (Claude 코드 읽기). 사용자 (2026-11-13) "같은 색깔로 L1이 생기면 아무 의미가 없잖아. 바로 합쳐지는데" → "다른 색 L1로"
- 앵커: `scripts/core/TurnManager.gd` `_spawn_timed_burst()`·`_timed_burst_offsets()`·`_hex_ring_offsets()`, `config/GameConfig.gd` `color_count_for_turn()`·새 필드, `config/default_config.tres`, `tests/test_timed_jelly.gd`, `tests/tools/run_timed_jelly_balance.ps1`, `tests/spike/capture_screens.gd`
- 요구 (§12-ONE.37 1~7):
  1. 0이 되면 터진 L1은 그 차례에 나오는 색 중 시한 젤리 색을 뺀 색 (4색이면 3색). 자리·개수·유령 시작·점수 없음은 그대로
  2. 육각 격자 이웃끼리 색이 다르게 — 권장: 칸 = (q − r) mod 3, 색 = (원본 색 + 1 + 칸) mod 색 수. 새 난수 없음
  3. 새 필드 `jelly_timed_burst_other_colors` (bool, 기본 true). false = #145 그대로 — K5-4 해시 `bc86d257…` 유지
  4. 판 균형 B10·B8·B6 (다른 색 규칙, L5·숫자 4, L1 수만 다름) × 5봇 × 20판, 600턴 상한, §12-ONE.36과 같은 칸 + **0이 된 정착 안 터진 L1끼리 합친 수**·판 위 다른 젤리와 합친 수
  5. 새 기본 = 자동 D-save·R D-save 성공 둘 다 40~60% **그리고** 자동 D-save 평균 176.4턴 이상인 이름 중 **L1 수가 가장 많은 것**. **없으면 B10 그대로** + 회신 맨 앞
  6. 캡처 `205` 다시·**새 `207`** (0이 된 정착이 끝난 뒤)·`202` 숫자를 기본값으로, 두 비율
  7. 테스트·해시: 색 규칙·이웃 색 다름·false 주입 K5-4 해시. 시한 젤리를 끈 묶음 (T3·C4E·Z1·G2)·CLASSIC 그대로, 켠 묶음 (H8·K5-8)은 바뀌면 옛 값·새 값 함께
- 수치 (Claude): 위 세 이름의 L1 수, 기본 고르는 규칙, 색 칸 규칙. 그 밖의 값은 그대로
- 건드리지 말 것: 시한 젤리 규칙 나머지 (차례·숫자 4·성공 +1·L5·뭉쳐 놓는 자리·유령 시작·점수 없음·안내 문구), 판 위 숫자, 지금 규칙·수치 전부, 그림·연출 (명세에 없는 것 금지, 고리 금지 — 색만 바뀐다), 사용자 저장 파일, `project.godot` 버전·`build/windows/` Release 파일 (**빌드 없음**), `docs/` (회신 파일 제외)
- **회신 맨 앞에**: 규칙에 맞는 이름 없음 (B10 유지), 터진 L1끼리 합체가 0이 됨 한 번당 평균 1건 이상, 판 밖 이탈, 시한 젤리를 끈 해시 바뀜, false 주입 K5-4 해시 바뀜
- Done-when:
  - [ ] 테스트 통과, 시한 젤리를 끈 해시·false 주입 K5-4 해시 그대로, 새 기본 해시 고정
  - [ ] 판 균형표 B10·B8·B6 (+ #145 K5-4)와 고른 기본, 터진 L1끼리 합친 수
  - [ ] 캡처 `205`·`207`·`202` (두 비율)
- QA: §12-ONE.37 4·5·6번
- 커밋: 항목 단위 브랜치 (`timed-burst-colors`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-12 #145] 시한 젤리 숫자 자리·외곽선, 숫자 (턴) 다시 재기 — 완료
- 상태: 완료 (2026-11-13 사용자 "인박스 확인" · [PR #145](https://github.com/jeongmo-dot/gravity_orb/pull/145) 병합 `53487f0`)
- 검수: 코드 diff, 테스트 diff, 회신 판 균형표 (K5-7·K5-6·K5-5·K5-4 × 5봇 × 20판 + #144 K5-8), 캡처 `199`~`206` 두 비율 직접 확인·`199` 줄별 픽셀 측정 (캡처 파일만 읽음). 테스트 358/4/5·해시·스모크·Debug 빌드는 Codex 관측 (Claude 재실행 없음). 빌드 없음 (`project.godot` 변경 0). 맨 앞 경고 0건 — 규칙대로 K5-4 (자동 49.8% · R 46.2%). 숫자는 눈 아래 (Claude 측정 사이 2줄, Codex 3px — 기준 2px 충족), 외곽선 보임 (원인: `outline_render_priority` −1 → 126). 작은 흠: 캡처 `202`가 숫자 8 고정 (게임 영향 없음). 사용자가 함께 보라고 준 외부 검토 페이지는 로그인 화면이라 읽지 못함. 결과: §12-ONE.36 "#145 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.36**
- 배경: #144 K5-8은 40~60% 규칙에 맞는 이름이 없어 평균이 가장 가까운 값으로 골라짐 (65.4% / 62.0%). 판 위 숫자는 32~35px로 커졌지만 눈과 10~11줄 겹치고 어두운 외곽선이 캡처에 보이지 않음 (Claude 캡처 픽셀 측정, §12-ONE.35 "#144 결과") → 사용자 (2026-11-12) "병합 + 후속 #145"
- 앵커: `scenes/Orb3D.tscn` `TimedLabel`·`scripts/spike/Orb3D.gd` `_update_visual_transform()`, `config/default_config.tres` (`jelly_timed_turns` 기본), `tests/tools/run_timed_jelly_balance.ps1`, `tests/test_timed_jelly.gd`·`tests/test_config.gd`, `tests/spike/capture_screens.gd`
- 요구 (§12-ONE.36 1~7):
  1. 판 위 숫자: 540×960 L5에서 흰 획 높이 18~22px, 외곽선 포함 전체가 눈 아래 끝보다 2px 이상 아래·젤리 윤곽 안 (2px 여유), 입·하이라이트와도 안 겹침
  2. 어두운 외곽선이 캡처에 보이게 — 안 보이던 원인을 회신에 적고 고침. 노랑·초록·빨강 젤리에서 테두리·몸통 밝기 (0~255)
  3. 판 균형 K5-7·K5-6·K5-5·K5-4 (L5·L1 10개, 숫자만 다름) × 5봇 × 20판, 600턴 상한, §12-ONE.35와 같은 칸. K5-8은 #144 값 사용
  4. 새 기본 = 자동 D-save·R D-save 성공 둘 다 40~60% **그리고** 자동 D-save 평균 176.4턴 이상 (여럿이면 평균이 50%에 가장 가까운 것, 같으면 숫자가 큰 것). **없으면 K5-8 그대로** + 회신 맨 앞
  5. 해시: T3·C4E·Z1·G2·H8·CLASSIC 그대로, 기본이 바뀌면 K5-8 `0aade400…` 주입으로 그대로, 새 기본 고정
  6. 테스트 (숫자 위 끝 < 눈 아래 끝, 같은 좌표계)·캡처 `199`~`206` 두 비율 — 눈·숫자 y 범위·간격·획 높이를 캡처 픽셀로 잰 값
- 수치 (Claude): 위 네 이름의 숫자, 기본 고르는 규칙, 숫자 18~22px·간격 2px. 그 밖의 값은 그대로
- 건드리지 말 것: 시한 젤리 규칙 (차례·숫자 줄어드는 때·성공 +1·0이 되면 L1 뭉쳐 놓기·점수 없음·안내 문구 형식), 레벨 5·L1 10개, NEXT·THEN 숫자, 지금 규칙·수치 전부, 그림·연출 (명세에 없는 것 금지, 숫자 뒤 원판·고리 금지), 사용자 저장 파일, `project.godot` 버전·`build/windows/` Release 파일 (**빌드 없음**), `docs/` (회신 파일 제외)
- **회신 맨 앞에**: 규칙에 맞는 이름 없음 (K5-8 유지), 판 밖 이탈, 숫자가 눈·입·하이라이트와 겹침 또는 획 높이 18~22px 밖, 외곽선이 캡처에 안 보임, 예전 해시 (K5-8 포함) 바뀜
- Done-when:
  - [ ] 테스트 통과, 예전 해시 그대로, (기본이 바뀌면) 새 기본 해시 고정
  - [ ] 판 균형표 K5-7·K5-6·K5-5·K5-4 (+ #144 K5-8)와 고른 기본
  - [ ] 캡처 (두 비율) — 숫자·눈 픽셀 측정값, 외곽선 밝기
- QA: §12-ONE.36 2·3·4·6번
- 커밋: 항목 단위 브랜치 (`timed-number`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-12 #144] 시한 젤리 다듬기 — 짝이 드문 레벨·큰 숫자·뭉친 L1 — 완료
- 상태: 완료 (2026-11-12 사용자 "병합 + 후속 #145" · [PR #144](https://github.com/jeongmo-dot/gravity_orb/pull/144) 병합 `bd2ccbe`)
- 검수: 코드 diff, 테스트 diff, 회신 판 균형표 (K4-8·K5-8·K5-10·K6-10 × 5봇 × 20판), 캡처 `199`~`206` (540×960)·`199`·`200` (540×1170) 직접 확인·픽셀 측정 (캡처 파일만 읽음). 테스트 357/4/5·해시·스모크·Debug 빌드는 Codex 관측 (Claude 재실행 없음). 빌드 없음 (`project.godot` 변경 0). 맨 앞 경고 한 건 — 40~60%에 맞는 이름 없음 → K5-8 (평균 63.69%). Claude 지적: 판 위 숫자가 눈과 10~11줄 겹침·어두운 외곽선 안 보임 (Codex는 "겹치지 않음"). 뭉친 L1 (`205`)·캡처 잔여 제거는 명세대로. → Claude가 물음 → 사용자 "병합 + 후속 #145". 결과: §12-ONE.35 "#144 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.35**
- 배경: #143 H8은 봇이 노리지 않아도 성공 74~93%, 놓인 뒤 평균 1.5턴 만에 저절로 합쳐짐. 판 위 숫자가 작아 읽기 어려움 (`199`·`200`), 0이 되면 L1 6개가 원형으로 놓임 (`205`) → 사용자 (2026-11-12) "병합 + 후속에서 다듬기"
- 앵커: `config/default_config.tres` (`jelly_timed_level`·`jelly_timed_turns`·`jelly_timed_burst_count` 기본), `scenes/Orb3D.tscn` `TimedLabel`·`scripts/spike/Orb3D.gd` `_update_visual_transform()`, `scripts/core/TurnManager.gd` `_spawn_timed_burst()`, `tests/tools/run_timed_jelly_balance.ps1`, `tests/test_timed_jelly.gd`·`tests/test_jelly_regression.gd`, `tests/spike/capture_screens.gd`
- 요구 (§12-ONE.35 1~7):
  1. 판 균형 K4-8 (L4·8·8)·K5-8 (L5·8·10)·K5-10 (L5·10·10)·K6-10 (L6·10·14) × 5봇 × 20판, 600턴 상한, §12-ONE.34와 같은 칸
  2. 새 기본 = 자동 D-save·R D-save 성공이 둘 다 40~60%인 이름 (여럿이면 평균이 50%에 가장 가까운 것, 같으면 낮은 레벨). 없으면 평균이 50%에 가장 가까운 것 + 회신 맨 앞
  3. 판 위 숫자: 540×960에서 글자 높이 18px 이상, 굵은 서체, 흰 글자 + 어두운 외곽선 4 이상, 젤리 아래쪽 절반 가운데 (눈·하이라이트와 안 겹침)
  4. 0이 되면 L1을 원본 원 안을 채우듯 뭉쳐 놓기 (같은 간격 원형 배치 금지)
  5. 해시: 예전 JELLY 묶음·H8 `af427045…` 그대로 (주입), 새 기본 고정, CLASSIC 그대로
  6. 테스트·캡처 (§12-ONE.35 4·6번) — 캡처 장면 사이 잔여 지우기 포함
- 수치 (Claude): 위 네 이름의 값과 기본 고르는 규칙. 그 밖의 값은 그대로
- 건드리지 말 것: 시한 젤리 규칙 (차례·숫자 줄어드는 때·성공 +1·0이 되면 L1·점수 없음·안내 문구 형식), 지금 규칙·수치 전부, 그림·연출 (명세에 없는 것 금지, 고리 모양 금지), 사용자 저장 파일, `project.godot` 버전·`build/windows/` Release 파일 (**빌드 없음**), `docs/` (회신 파일 제외)
- **회신 맨 앞에**: 40~60% 규칙에 맞는 이름 없음, 새 기본 자동 D-save 평균 176.4턴 미만, 판 밖 이탈, 숫자 18px 미만·눈/하이라이트와 겹침, 예전 해시 (H8 포함) 바뀜
- Done-when:
  - [ ] 테스트 통과, 예전 JELLY 해시 (T3·C4E·Z1·G2·H8)·CLASSIC 그대로, 새 기본 해시 고정
  - [ ] 판 균형표 K4-8·K5-8·K5-10·K6-10과 고른 기본
  - [ ] 캡처 (두 비율) — 숫자 글자 높이 px, 뭉친 L1
- QA: §12-ONE.35 1·4·6번
- 커밋: 항목 단위 브랜치 (`timed-tune`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-11 #143] 시한 젤리 (숫자가 0이 되기 전에 합치기) — 완료
- 상태: 완료 (2026-11-12 사용자 "병합 + 후속에서 다듬기" · [PR #143](https://github.com/jeongmo-dot/gravity_orb/pull/143) 병합 `d738bfa`)
- 검수: 코드 diff, 회신 판 균형표 (H8·H6·H10·H8-L2 × 5봇 × 20판), 캡처 `199`·`200`·`201`·`204`·`205` (540×960)·`200` (540×1170) 직접 확인. 테스트 354/4/5·해시·스모크는 Codex 관측 (Claude 재실행 없음). 빌드 없음 (Release 미생성 확인). 맨 앞 경고 한 건 — H8 성공 90% 넘는 행 셋. Claude 지적: 판 위 숫자 읽기 어려움 (`199`·`200`), L1 6개 원형 배치 (`205`, 명세 표현 탓), 캡처 잔여 (`204`·`205`). → Claude가 물음 → 사용자 "병합 + 후속에서 다듬기" (#144). 결과: §12-ONE.34 "#143 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.34**
- 배경: 사용자 (2026-11-11) "전략성과 긴장감이 과제야" → "지금 있는 걸 바꾸는게 아니라 새로운 시도가 필요해. 그리고 매번 빌드를 만들 필요는 없어" → "시한 젤리"
- 앵커: `scripts/core/Spawner.gd` `_draw_batch()`·`try_spawn()`·`_public_batch()`·`sync_next_batch_size()`, `scripts/core/TurnManager.gd` `_on_settled()`, `scripts/core/ReactionRules.gd` `_classify_jelly()`·`scripts/core/CollisionResolver.gd` (합체 결과), `scripts/spike/Orb3D.gd` (시한 상태·숫자), NEXT·THEN 미리보기, `scripts/ui/Hud.gd` (안내 한 줄), `config/GameConfig.gd`·`default_config.tres`, 판 균형 측정 도구, `tests/` (해시·새 테스트), `tests/spike/capture_screens.gd`
- 요구 (§12-ONE.34 1~13):
  1. 새 필드 7개: `jelly_timed_enabled` true, `first_turn` 20, `interval_turns` 12, `level` 3, `turns` 8, `burst_count` 6, `bonus_levels` 1 (모두 `jelly_timed_` 접두)
  2. 차례 20·32·44…의 묶음 첫 젤리 = 시한 젤리 (새 난수 없음, 레벨만 3). 미리보기에도 숫자
  3. 턴이 끝날 때마다 숫자 −1 (입구 대기 중 제외)
  4. 0 전에 합치면 결과 레벨 +1 (L3 + L3 → L5)
  5. 0이 되면 그 자리에 같은 색 L1 6개 (유령으로 시작), 점수 없음, 정착 뒤 입구 대기 판정
  6. 숫자 그림 (고리 금지, 새 연출 없음), 첫 안내 한 줄 `시한 젤리: 8턴 안에 합치면 한 단계 더`
  7. 판 균형 H8·H6·H10·H8-L2 × 5봇 × 20판, 600턴 상한. 시한 젤리 성공·0이 됨·남음 비율 포함
  8. 해시: 예전 JELLY 묶음 (T3·C4E·Z1·G2)은 false 주입으로 그대로, H8 고정, CLASSIC 그대로
  9. 테스트·캡처 (§12-ONE.34 11·12번)
- 수치 (Claude): 위 7개 값. 그 밖의 값은 그대로
- 건드리지 말 것: 지금 규칙·수치 전부, 그림·연출 (명세에 없는 것 금지, 고리 모양 금지), 사용자 저장 파일, `project.godot` 버전·`build/windows/` Release 파일 (**빌드 없음**), `docs/` (회신 파일 제외)
- **회신 맨 앞에**: H8 성공 비율 20% 미만 또는 80% 초과, H8 자동 D-save 평균 176.4턴 미만, 판 밖 이탈, 숫자 읽기 어려움·젤리 밖, 안내 잘림, 예전 해시 바뀜
- Done-when:
  - [ ] 테스트 통과, 예전 JELLY 해시 (T3·C4E·Z1·G2)·CLASSIC 그대로, H8 해시 고정
  - [ ] 판 균형표 H8·H6·H10·H8-L2 (시한 젤리 항목 포함)
  - [ ] 캡처 (두 비율)
- QA: §12-ONE.34 9~12번
- 커밋: 항목 단위 브랜치 (`timed-jelly`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-09 #142] 안내 한 줄이 넘칠 때만 글자 줄이기·빌드 0.16.10 — 완료
- 상태: 완료 (2026-11-09 사용자 "확인" · [PR #142](https://github.com/jeongmo-dot/gravity_orb/pull/142) 병합 `f9324e2`)
- 검수: 코드 diff, 테스트 diff, 캡처 `188` (두 비율)·`187` (540×960), `build/windows/GravityOrb_v0.16.10.exe` 크기·SHA-256·`_BUILD.txt` (커밋 `4218717` = 브랜치 끝, Release) 직접 확인. 테스트 348/4/5·해시·글자 크기 수치·스모크·`save.cfg`는 Codex 관측 (Claude 재실행 없음). 맨 앞 경고 없음. 초록 안내 64 → 56, 나머지 64 그대로. 결과: §12-ONE.33 "#142 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.33**
- 배경: #141 새 안내 `초록 L8: 휴식 · 위쪽 초록 L1 2개 청소`가 두 비율 모두 오른쪽 끝이 잘림 (캡처 `188`) → 사용자 (2026-11-09) "병합 + 넘칠 때만 글자 줄이기"
- 앵커: `scripts/ui/Hud.gd` `_apply_responsive_layout()`·`_callout_layout_rect()`·`_show_callout()`·`_show_planet_unlock()`·`_show_jelly_tap_effect()`·`_layout_planet_callout_visual()`, `scenes/UI.tscn` `CalloutLabel` (읽기), `tests/test_callouts.gd`, `tests/spike/capture_screens.gd`, `project.godot`
- 요구 (§12-ONE.33 1~5):
  1. 세 안내 함수에서 문구를 넣은 직후, 잰 문구 폭 (+ 외곽선 × 2)이 칸 폭보다 크면 그 안내만 글자 크기를 폭에 맞게 줄인다 (하한 `CALLOUT_FONT_MIN` 28). 넘치지 않는 안내는 0.16.9와 같은 크기
  2. 문구·칸 자리·높이·여백·색·연출·시간은 그대로
  3. 테스트 (§12-ONE.33 3번)
  4. 캡처: 전체 다시, 두 비율. `188` 양 끝 화면 안 (여유 px), 다른 안내 글자 크기 0.16.9와 비교
  5. 버전 **0.16.10**, 커밋 뒤 깨끗한 트리에서 Release. 보고는 #136과 같다
- 수치 (Claude): 하한은 기존 `CALLOUT_FONT_MIN` 28, 버전 **0.16.10**. 그 밖의 값은 그대로
- 건드리지 말 것: 모든 안내 문구, `CALLOUT_SIDE_MARGIN`·`CALLOUT_FONT_MIN`·`CALLOUT_FONT_MAX`, 칸 자리·높이, 색·외곽선·연출·시간, 게임 규칙·수치·생성·물리, 그림 (명세에 없는 것 금지, 고리 모양 금지), 사용자 저장 파일, `docs/` (회신 파일 제외)
- **회신 맨 앞에**: `188`이 여전히 잘림, 28로도 넘치는 안내, 넘치지 않는 안내의 글자 크기가 바뀜, 규칙 해시가 바뀜, `0.16.10` 이름·비교 문제
- Done-when:
  - [ ] 테스트 통과, 규칙 해시 (G2·Z1·T3·C4E·CLASSIC) 그대로
  - [ ] 캡처 (두 비율) — `188` 양 끝 화면 안
  - [ ] `build/windows/GravityOrb_v0.16.10.exe` (`mode=Release`, `_BUILD.txt` 커밋 = 브랜치 끝), 0.16.1~0.16.9 파일 그대로
- QA: §12-ONE.33 3~5번
- 커밋: 항목 단위 브랜치 (`callout-fit`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-08 #141] 초록 휴식 청소는 위쪽 초록 L1 2개·빌드 0.16.9 — 완료
- 상태: 완료 (2026-11-09 사용자 "병합 + 넘칠 때만 글자 줄이기" · [PR #141](https://github.com/jeongmo-dot/gravity_orb/pull/141) 병합 `d138c85`)
- 검수: 코드 diff, 회신 판 균형표 (Z1·G2·G3 × 5봇 × 20판, 색별), 캡처 `188` (두 비율)·`195`·`196` (540×960), `build/windows/GravityOrb_v0.16.9.exe` 크기·SHA-256·`_BUILD.txt` (커밋 `25c1857` = 브랜치 끝, Release) 직접 확인. 테스트 347/4/5·해시·스모크·`save.cfg`는 Codex 관측 (Claude 재실행 없음). 맨 앞 경고 한 건 — 새 초록 안내 오른쪽 끝 잘림 → Claude가 물음 → 사용자 "병합 + 넘칠 때만 글자 줄이기" (#142). Z1 = §12-ONE.31, G2 초록 0개 8.2%, 판 길이 −0.3%. 결과: §12-ONE.32 "#141 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.32**
- 배경: #140 Z1 초록 청소 0개 터치 96.3% (입구 쪽 띠에 초록 L1이 거의 없음) → 사용자 (2026-11-08) "병합 + 초록 조건 다시" → "위쪽 초록 L1 2개"
- 앵커: `scripts/core/CollisionResolver.gd` `_jelly_tap_clean_targets()`·`_matches_jelly_tap_clean_rule()`, `config/GameConfig.gd`·`default_config.tres`, `scripts/ui/Hud.gd` `_jelly_tap_effect_callout_text()`, 판 균형 측정 도구 (`tests/tools/run_four_color_balance.ps1` 등), `tests/test_jolt_3d.gd`·`tests/test_config.gd`·`tests/test_callouts.gd`·`tests/test_jelly_regression.gd`, `tests/spike/capture_screens.gd`, `project.godot`
- 요구 (§12-ONE.32 1~7):
  1. 새 필드 `jelly_tap_rest_clean_count` (2): 규칙 true이고 값 > 0이면 REST 청소 = 청소 후보 조건을 만족하는 같은 색 젤리를 입구 벽까지 거리 오름차순 (같으면 `stable_spawn_id`)으로 세워 앞에서 N개. 판 어디든. 0 이하 = 0.16.8 띠 규칙
  2. 안내 한 줄: `초록 L8: 휴식 · 위쪽 초록 L1 2개 청소` (값 0이면 0.16.8 문구)
  3. 판 균형 Z1 (다시 잼)·G2·G3 × 5봇 × 20판, 600턴 상한, §12-ONE.31과 같은 항목
  4. 해시: 예전 JELLY 묶음 (T3·C4E)·Z1은 값 0 주입으로 그대로, G2 고정, CLASSIC 그대로
  5. 테스트 (§12-ONE.32 5번)
  6. 캡처: 전체를 새 기본값으로 + 초록 청소 전·후 (`195`·`196`)·초록 안내 (`188`), 두 비율. 장면 사이 팝업·칭찬 글자·콤보 잔여 지우기 (캡처 도구만)
  7. 버전 **0.16.9**, 커밋 뒤 깨끗한 트리에서 Release. 보고는 #136과 같다
- 수치 (Claude): `jelly_tap_rest_clean_count` **2**, 버전 **0.16.9**. 그 밖의 값은 그대로
- 건드리지 말 것: 4색·효과 배정·효과 값, 청소 L1·분홍·파랑·노랑 조건과 값, `jelly_tap_rest_clean_band_factor` 0.4, 터치 후보 조건, 사방 밀기, 소폭발·청소 그림, 점수 계산, 생성, 합치는 레벨, 대폭발, 물리, 그림·연출 (명세에 없는 것 금지, 고리 모양 금지), 사용자 저장 파일, `docs/` (회신 파일 제외)
- **회신 맨 앞에**: Z1 다시 잰 값이 §12-ONE.31과 다름, G2 초록 청소 0개 비율 30% 이상, G2 자동 D-save 평균 턴이 Z1 353.70의 ±10% 밖, 안내 한 줄 잘림
- Done-when:
  - [ ] 테스트 통과, 예전 JELLY 해시 (T3·C4E)·Z1·CLASSIC 그대로, G2 해시 고정
  - [ ] 판 균형표 Z1·G2·G3 (색별 항목 포함)
  - [ ] 캡처 (두 비율)
  - [ ] `build/windows/GravityOrb_v0.16.9.exe` (`mode=Release`, `_BUILD.txt` 커밋 = 브랜치 끝), 0.16.1~0.16.8 파일 그대로
- QA: §12-ONE.32 3·7번
- 커밋: 항목 단위 브랜치 (`green-top-clean`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-08 #140] 청소는 L1만·색마다 자리 조건·안내 한 줄에 조건·빌드 0.16.8 — 완료
- 상태: 완료 (2026-11-08 사용자 "병합 + 초록 조건 다시" · [PR #140](https://github.com/jeongmo-dot/gravity_orb/pull/140) 병합 `264c85a`)
- 검수: 코드 diff, 회신 판 균형표 (C4E·C4E-L1·Z2·Z1 × 5봇 × 20판, 색별), 캡처 `180`·`181`·`186`~`198` (540×960), `build/windows/GravityOrb_v0.16.8.exe` 크기·SHA-256·`_BUILD.txt` (커밋 `0e40f0a` = 브랜치 끝, Release) 직접 확인. 테스트 345/4/5·해시·스모크·`save.cfg`는 Codex 관측 (Claude 재실행 없음). 맨 앞 경고 세 건 — Z1 자동 D-save 353.70턴 (C6 +177%), L-합체 D-all 20/20 미완료, 초록 청소 0개 96.3% → Claude가 물음 → 사용자 "병합 + 초록 조건 다시" → "위쪽 초록 L1 2개" (#141). 흠: 캡처 `192`~`198`에 앞 장면 팝업·콤보 잔여. 결과: §12-ONE.31 "#140 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.31**
- 배경: 사용자 (2026-11-08, #139 병합 뒤) "청소를 항상 하는 것이 아니라, 다른 조건을 만드는게 좋을 것 같아. 색깔별로 다르면 더 좋고. 그리고 l1만 청소하는게 좋을 것 같고" → "효과 따라 자리", "조건도 짧게". 4색이 된 뒤 판이 C6의 약 3배 (§12-ONE.30)
- 앵커: `scripts/core/CollisionResolver.gd` `_jelly_tap_clean_targets()`·`apply_jelly_tap_blast()`, `scripts/spike/Board3D.gd` `gravity_direction()` (판정에 읽기만), `config/GameConfig.gd`·`default_config.tres`, `scripts/ui/Hud.gd` `_jelly_tap_effect_callout_text()`, 판 균형 측정 도구 (`tests/tools/run_four_color_balance.ps1` 등), `tests/test_jolt_3d.gd`·`tests/test_config.gd`·`tests/test_callouts.gd`·`tests/test_jelly_regression.gd`, `tests/spike/capture_screens.gd`, `project.godot`
- 요구 (§12-ONE.31 1~8):
  1. `jelly_tap_clean_max_level` 2 → **1**
  2. 새 필드 `jelly_tap_clean_zone_rule` (true): 분홍 = 288px 안 **모든 색** L1, 파랑 = **바닥에 닿은** 파랑 L1 (판 어디든), 초록 = **입구 벽에서 384px 안** 초록 L1, 노랑 = **480px 안** 노랑 L1. 조건 0개여도 터치·효과·턴·사라짐은 그대로. false = 0.16.7 규칙
  3. 안내 한 줄: `분홍 L8: 폭탄 · 주변 L1 청소`·`파랑 L8: 지진 · 바닥 파랑 L1 청소`·`초록 L8: 휴식 · 입구 쪽 초록 L1 청소`·`노랑 L8: 자석 · 끌린 노랑 L1 청소` (효과·설정에서 만든다)
  4. 판 균형 C4E (다시 잼)·C4E-L1·Z2·Z1 × 5봇 × 20판, 600턴 상한. 색별 터치 수·청소/터치·청소 0개 비율·휴식 턴
  5. 해시: 예전 JELLY 묶음 (T3·C4E 포함)은 규칙 false·L2 주입으로 그대로, Z1 고정, CLASSIC 그대로
  6. 테스트 (§12-ONE.31 6번)
  7. 캡처: 전체를 새 기본값으로 + 네 색 청소 전·후 + 네 색 안내 한 줄, 두 비율. `180` TURN 칸 갱신 (캡처 도구만)
  8. 버전 **0.16.8**, 커밋 뒤 깨끗한 트리에서 Release. 보고는 #136과 같다
- 수치 (Claude): `jelly_tap_clean_max_level` **1**, `jelly_tap_clean_zone_rule` **true**, `jelly_tap_quake_floor_margin` **8.0**, `jelly_tap_rest_clean_band_factor` **0.4**, `jelly_tap_magnet_clean_radius_factor` **0.5**, 분홍은 기존 `jelly_tap_blast_radius_factor` 0.3, 버전 **0.16.8**. 그 밖의 값은 그대로
- 건드리지 말 것: 4색·효과 배정·효과 값, 터치 후보 조건, 사방 밀기, 소폭발 그림, 청소 그림·점수 계산, 생성, 합치는 레벨, 대폭발, 물리, 그림·연출 (명세에 없는 것 금지, 고리 모양 금지), 사용자 저장 파일, `docs/` (회신 파일 제외)
- **회신 맨 앞에**: C4E 다시 잰 값이 §12-ONE.30과 다름, Z1 자동 D-save 평균 턴이 C6 127.85의 ±30% 밖, Z1 L-합체 D-all 미완료 3판 이상, 청소 0개 터치 90% 이상인 색, 안내 한 줄 잘림
- Done-when:
  - [ ] 테스트 통과, 예전 JELLY 해시 (T3·C4E 포함)·CLASSIC 그대로, Z1 해시 고정
  - [ ] 판 균형표 C4E·C4E-L1·Z2·Z1 (색별 항목 포함)
  - [ ] 캡처 (두 비율)
  - [ ] `build/windows/GravityOrb_v0.16.8.exe` (`mode=Release`, `_BUILD.txt` 커밋 = 브랜치 끝), 0.16.1~0.16.7 파일 그대로
- QA: §12-ONE.31 4·8번
- 커밋: 항목 단위 브랜치 (`clean-zones`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-07 #139] 색은 4가지로·네 색 소폭발 효과 다시 정리 (폭탄·지진·휴식·자석)·빌드 0.16.7 — 완료
- 상태: 완료 (2026-11-08 사용자 "그대로 병합" · [PR #139](https://github.com/jeongmo-dot/gravity_orb/pull/139) 병합 `bdbdce4`)
- 검수: 코드 diff, 회신 판 균형표 (C6·C4·C4E·C4E-S5 × 5봇 × 20판), 캡처 `180`~`190` (두 비율), `build/windows/GravityOrb_v0.16.7.exe` 크기·SHA-256·`_BUILD.txt` (커밋 `7a9d2d0` = 브랜치 끝, Release) 직접 확인. 테스트 343/4/5·해시·스모크·`save.cfg`는 Codex 관측 (Claude 재실행 없음). 휴식 램프 경계는 지금 구현이 이미 미리보기 = 실제. 맨 앞 경고 두 건 — C4E 자동 D-save 367.50턴 (C6 +187%), L-합체 D-all 20/20 미완료 → Claude가 물음 → 사용자 "그대로 병합". 흠: 캡처 `180` TURN 칸이 207 (HUD 미갱신). 결과: §12-ONE.30 "#139 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.30**
- 배경: 사용자 (2026-11-07) "색상 종류 지금 6가지 인거 4가지로 줄이자", (0.16.6 플레이) "녹색은 터치가 안되네?" → "녹색도 터질 수 있게 함" → "늘 사라짐", "4개의 색깔 터짐 효과 다시 정리" → "폭탄·지진·휴식·자석"
- 앵커: `config/GameConfig.gd`·`default_config.tres` `turn_color_unlock_turns`·`jelly_tap_effect_modes`, `GameConfig.color_count_for_turn()`·`newly_unlocked_color_for_turn()`, `scripts/core/Spawner.gd` `_draw_candidate_for_turn()`, `scripts/core/TurnManager.gd` (REST·미리보기), `scripts/core/CollisionResolver.gd` `apply_jelly_tap_blast()`·`is_jelly_tap_blast_candidate()`, `scripts/ui/Hud.gd` `JELLY_TAP_EFFECT_CALLOUTS`·`_on_jelly_tap_effect_unlocked()`·`_track_preview_unlocks()`, 판 균형 측정 도구, `tests/test_config.gd`·`tests/test_spawner.gd`·`tests/test_jolt_3d.gd`·`tests/test_callouts.gd`·`tests/test_jelly_regression.gd`, 캡처, `project.godot`
- 요구 (§12-ONE.30 1~8):
  1. `turn_color_unlock_turns` [30, 60] → **[]**: 판 내내 분홍·파랑·초록·노랑
  2. `jelly_tap_effect_modes` → **[2, 3, 7, 6, 1, 1]**: 분홍 폭탄·파랑 지진·**초록 휴식**·**노랑 자석** (보라·주황 NONE). 성장·보너스 코드는 남김. 모든 색에서 터치한 젤리는 사라지고 초록도 늘 터치 후보. 휴식이 램프 경계에 걸려도 미리보기 = 실제 (지금 동작을 회신에, 다르면 고침)
  3. 안내 한 줄을 효과로 만든다: `<색> L8: 터치하면 <효과>` (기본 네 색: 폭탄·지진·휴식·자석)
  4. 판 균형 C6·C4·C4E·C4E-S5 (자동 D-save·D-all, R D-save, L-합체 D-save·D-all × 20, 600턴 상한). 색별 소폭발 수·청소/회 평균·휴식 턴 수 추가
  5. 해시: 예전 JELLY 묶음 (T3 포함) 그대로, CLASSIC 생성 진행은 새 값 고정 (회신에), C4E 고정
  6. 테스트 (§12-ONE.30 6번)
  7. 캡처: 전체를 새 기본값으로 + 초록 휴식·노랑 자석·네 색 안내 한 줄, 두 비율. 보라·주황·새 색 반짝임 고정 장면은 남기고 목록을 회신에
  8. 버전 **0.16.7**, 커밋 뒤 깨끗한 트리에서 Release. 보고는 #136과 같다
- 수치 (Claude): `turn_color_unlock_turns` **[]**, `jelly_tap_effect_modes` **[2, 3, 7, 6, 1, 1]**, 버전 **0.16.7**. 그 밖의 값은 그대로
- 건드리지 말 것: 색 그림·표시 색·시작 4색 순서, 공통 청소·사방 밀기, 폭탄 반경·지진·자석 값, 휴식 동작 (경계 말고), 생성 비율·상한·램프, 합치는 레벨, 대폭발, 점수, 물리, 그림·연출 (명세에 없는 것 금지, 고리 모양 금지), 사용자 저장 파일, `docs/` (회신 파일 제외)
- **회신 맨 앞에**: C4E L-합체 D-all 미완료 3판 이상, C4E 자동 D-save 평균 턴이 C6과 30% 넘게 다름, 휴식이 램프 경계에서 미리보기와 다르게 들어옴
- Done-when:
  - [ ] 테스트 통과, 예전 JELLY 해시 그대로, CLASSIC 생성 진행·C4E 해시 고정
  - [ ] 판 균형표 C6·C4·C4E·C4E-S5
  - [ ] 캡처 (두 비율)
  - [ ] `build/windows/GravityOrb_v0.16.7.exe` (`mode=Release`, `_BUILD.txt` 커밋 = 브랜치 끝), 0.16.1~0.16.6 파일 그대로
- QA: §12-ONE.30 4·8번
- 커밋: 항목 단위 브랜치 (`four-colors`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-07 #138] 소폭발은 사방으로 크게 — 위로 터짐 끄기·소폭발 전용 반경·속도·빌드 0.16.6 — 완료
- 상태: 완료 (2026-11-07 사용자 "병합" · [PR #138](https://github.com/jeongmo-dot/gravity_orb/pull/138) 병합 `80c3c9c`)
- 검수: 코드 diff, 회신 측정표 (밀림 L9·T0~T4·판 균형 T3), 캡처 `165`·`169`·`173`·`177`·`178`, `build/windows/GravityOrb_v0.16.6.exe` 크기·SHA-256·`_BUILD.txt` (커밋 `93e19f9` = 브랜치 끝, Release) 직접 확인. 테스트 341/4/5·해시·스모크·`save.cfg`는 Codex 관측 (Claude 재실행 없음). 맨 앞 경고 최대 관통 34px은 모든 이름이 같은 값 (측정 장면 배치 탓) → Claude가 물음 → 사용자 "병합". 꽉 찬 판 가운데 0.4초 중앙값 23 → 40px (목표 100px에 못 미침), 캡처에서는 사방 벽까지 퍼짐. 판 길이 +2.4%. 결과: §12-ONE.29 "#138 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.29**
- 배경: 사용자 (2026-11-07, 0.16.5 뒤) "위로 터지는게 아니라 사방으로 크게". #136 사방 밀기는 가운데에서도 0.4초 뒤 중앙값 47px — 반경 288px 밖의 젤리에 막힌다
- 앵커: `scripts/spike/Board3D.gd` `apply_blast_with_radius_factor()` (소폭발 경로), `scripts/core/CollisionResolver.gd` `apply_jelly_tap_blast()` (청소 반경 `_jelly_tap_clean_targets()`·그림 `blast_radius_factor`는 그대로), `config/GameConfig.gd`·`default_config.tres`, 밀림·판 균형 측정 도구, `tests/test_jolt_3d.gd`·`tests/test_config.gd`·`tests/test_jelly_regression.gd`, `tests/spike/capture_screens.gd`, `project.godot`
- 요구 (§12-ONE.29 1~9):
  1. `jelly_tap_lift_speed` 900 → **0** (사방으로)
  2. 새 필드 `jelly_tap_push_radius_factor` **0.5**: 소폭발 밀기 반경·감쇠 R. 0이면 `jelly_tap_blast_radius_factor`. 분홍 폭탄 청소 반경·소폭발 그림 크기는 0.3 그대로
  3. 새 필드 `jelly_tap_push_speed` **1800**: 소폭발 밀기 속도. 0이면 `blast_speed`. 대폭발은 1350 그대로
  4. 밀림 측정 L9·T0~T4 (가운데·바닥 더미 위 노랑, T3 대폭발 한 번). 바깥쪽 거리, 50px·100px 이상 비율, 최대 속도·관통·이탈
  5. 판 균형 T3 (자동 D-save·D-all, R D-save, L-합체 D-save·D-all), S4-G1 옆
  6. 해시: 예전 10종·CLASSIC 생성 진행 그대로, T3 고정
  7. 테스트 (§12-ONE.29 7번)
  8. 캡처: 가운데·더미 위 노랑 L9·T0·T3 × 0·0.1·0.2·0.4초, 두 비율, 앞 장면 팝업·호령·콤보 지운 뒤 (캡처 도구만), 마지막 전체
  9. 버전 **0.16.6**, 커밋 뒤 깨끗한 트리에서 Release. 보고는 #136과 같다
- 수치 (Claude): `jelly_tap_lift_speed` **0**, `jelly_tap_push_radius_factor` **0.5**, `jelly_tap_push_speed` **1800**, 버전 **0.16.6**. 그 밖의 값은 그대로
- 건드리지 말 것: 대폭발, `blast_speed`·`blast_far_factor`·무중력, 색 청소·색별 효과·분홍 폭탄 청소 반경, 소폭발 그림 크기, 생성·합치는 레벨, 물리, 그림·연출 (명세에 없는 것 금지, 고리 모양 금지), 사용자 저장 파일, `docs/` (회신 파일 제외)
- **회신 맨 앞에**: T3 판 밖 이탈 1회 이상 또는 최대 관통 30px 초과, T3 가운데 노랑 0.4초 중앙값이 대폭발보다 큼, T3 자동 D-save 평균 턴이 S4-G1 (124.85)과 20% 넘게 다름, T3 L-합체 D-all 미완료 3판 이상
- Done-when:
  - [ ] 테스트 통과, 예전 해시 10종·CLASSIC 생성 진행 그대로, T3 해시 고정
  - [ ] 밀림 측정표 L9·T0~T4, 판 균형표 T3 (S4-G1 옆)
  - [ ] 캡처 (두 비율)
  - [ ] `build/windows/GravityOrb_v0.16.6.exe` (`mode=Release`, `_BUILD.txt` 커밋 = 브랜치 끝), 0.16.1~0.16.5 파일 그대로
- QA: §12-ONE.29 4·5·9번
- 커밋: 항목 단위 브랜치 (`tap-push-wide`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-07 #137] 소폭발은 위로 터지게·들어오는 공 줄이기·합치는 레벨 3 × 3 측정 — 완료
- 상태: 완료 (2026-11-07 사용자 "S4-G1" · [PR #137](https://github.com/jeongmo-dot/gravity_orb/pull/137) 병합 `2aab05c`)
- 검수: 코드 diff (1차·추가 요구 1), 회신 측정표 (3 × 3·위로 터짐) — 측정 JSON 요약은 Claude가 직접 읽음, 캡처 `149`·`152`·`153`, `build/windows/GravityOrb_v0.16.5.exe` 크기·SHA-256·`_BUILD.txt` (커밋 `62db2c1` = 브랜치 끝, Release) 직접 확인. 테스트·해시·스모크·`save.cfg`는 Codex 관측 (Claude 재실행 없음 — 회신의 테스트 줄은 1차와 같은 글자라 추가 요구 1 뒤 전체 실행인지 불명). 위로 터짐 900: 더미 위 50px 이상 6% → 100%. S4-G1: 다섯 봇 100판 모두 끝남, 자동 D-save 103 → 125턴, 대폭발 4 → 11. 결과: §12-ONE.28 "#137 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.28**
- 배경: 사용자 (2026-11-07, 0.16.4 뒤) "1. 소폭발도 위로 터지게 2. 한 턴에 들어오는 공 수 줄이기 3. 합치는 레벨 고민". 더미 위 소폭발은 50px 넘게 6%만 밀린다 (#136). G1은 L8 이상이 드물다 (#135)
- 앵커: `scripts/spike/Board3D.gd` `apply_blast_with_radius_factor()` (소폭발 경로), `scripts/core/CollisionResolver.gd` `apply_jelly_tap_blast()`, `scripts/core/ReactionRules.gd` `can_react()`·`_classify_jelly()`, `config/GameConfig.gd`·`default_config.tres`, 측정 도구 (`run_jolt_3d_measurement.gd`·`run_blast_push_measurement.gd`·`run_jelly_measurement.ps1`), `tests/test_rules.gd`·`tests/test_jolt_3d.gd`·`tests/test_jelly_regression.gd`, 캡처
- 요구 (§12-ONE.28 1~8):
  1. 새 필드 `jelly_tap_lift_speed` **900**: 소폭발 밀기에서 중력 쪽 성분을 버리고 중력 반대쪽 속도를 더한다 (거리 감쇠 같음). 대폭발은 그대로. 0이면 #136
  2. `spawn_count_max` 5 → **4** (임시 기본 — 최종은 표를 보고)
  3. 새 필드 `jelly_merge_wide_gap_min_level` **0** (끔): 0보다 크면 같은 색 레벨 차가 `jelly_merge_level_gap + 1`이고 큰 쪽이 이 레벨 이상이어도 합쳐진다. `ReactionRules` 두 곳만 읽는다
  4. 측정 3 × 3 (상한 5·4·3 × G1·G2·H6) — 자동 D-save·D-all, R D-save, L-합체 D-save·D-all. L8 이상이 나온 판·판당 L8 이상 생성 수 포함
  5. 밀림 측정: lift 0·600·900·1200, 가운데·바닥 더미 위 노랑. 중력 반대쪽으로 간 거리 추가
  6. 해시: 예전 9종 (K4 포함) 그대로, 새 기본 (S4-G1 + lift 900) 고정
  7. 테스트 (§12-ONE.28 7번)
  8. 캡처: 바닥 더미 위 노랑 lift 0·900 × 0·0.1·0.2·0.4초, 두 비율, 마지막 전체 캡처
- 수치 (Claude): `jelly_tap_lift_speed` **900**, `spawn_count_max` **4** (임시), `jelly_merge_wide_gap_min_level` **0** (측정 H6 = 6). 그 밖의 값은 그대로
- 건드리지 말 것: 대폭발 밀기, #136 값 (무중력 0.2·속도 1350 / 0.5), 색별 효과·색 청소, 생성 램프 간격·시작 수·L2 비율, 대폭발 조건, 점수, 물리, 그림·연출 (명세에 없는 것 금지, 고리 모양 금지), 사용자 저장 파일, `docs/` (회신 파일 제외)
- **이번에는 Release 빌드를 만들지 않는다** (값이 정해진 뒤 추가 요구에서 0.16.5). 검증 빌드는 `-Debug`
- 1차 결과 ([PR #137](https://github.com/jeongmo-dot/gravity_orb/pull/137) `ce2ed5d`): 위로 터짐 900은 더미 위 50px 이상 6% → 100%. 3 × 3에서 다섯 봇 100판이 모두 끝나는 것은 S5-G1·S4-G1뿐 (S4-G1: 자동 D-save 103 → 125턴, 대폭발 4 → 11). Claude 검수에서 대기 판정 범위 빈틈 (H 규칙 짝을 못 봄 — 명세 탓, 기본값 영향 없음). [§12-ONE.28](technical_design.md) 「#137 1차 결과」
- **추가 요구 1** (사용자 2026-11-07 표를 본 뒤 "S4-G1"): [§12-ONE.28](technical_design.md) 「추가 요구 1」
  1. 값은 PR 기본값 그대로 확정 (`spawn_count_max` 4, 레벨 차 1, `jelly_tap_lift_speed` 900, `jelly_merge_wide_gap_min_level` 0)
  2. `CollisionResolver._has_pending_jelly_reactions()`의 같은 색 후보 레벨 범위를 `can_react()`가 허용하는 레벨 차 전부로 (H 켜짐이면 ±(gap + 1)). 따로 적은 곳이 또 있으면 회신에 목록
  3. 테스트: H6에서 잠긴 같은 색 L6 + L4 → 대기 true, L5 + L3 → false, H 0이면 L6 + L4 → false
  4. 해시 모두 그대로. 측정·캡처 다시 하지 않음
  5. 버전 **0.16.5**, 커밋 뒤 깨끗한 트리에서 Release. 보고는 #136과 같다
- Done-when:
  - [ ] 테스트 통과, 예전 해시 9종 그대로, 새 기본 해시 고정
  - [ ] 3 × 3 측정표, 밀림 측정표 (lift 4값)
  - [ ] 캡처 (두 비율)
  - [ ] 추가 요구 1: 대기 판정 테스트, 해시 그대로, `build/windows/GravityOrb_v0.16.5.exe` (`mode=Release`, `_BUILD.txt` 커밋 = 브랜치 끝), 0.16.1~0.16.4 파일 그대로
- QA: §12-ONE.28 4·5번
- 커밋: 항목 단위 브랜치 (`tap-lift-spawn-merge`), **push·PR까지**. 추가 요구 1도 같은 브랜치·PR (병합은 Claude 검수 뒤)

### [2026-11-07 #136] 소폭발·대폭발이 주변 젤리를 확실히 밀기·빌드 0.16.4 — 완료
- 상태: 완료 (2026-11-07 Claude 검수 · [PR #136](https://github.com/jeongmo-dot/gravity_orb/pull/136) 병합 `22f1017`)
- 검수: 코드 diff, 회신 측정표 (밀림 K0~K4·판 균형·성능), 캡처 `132`·`136`·`140`·`144`, `build/windows/GravityOrb_v0.16.4.exe` 크기·SHA-256·`_BUILD.txt` (커밋 `9b20ab9` = 브랜치 끝, Release) 직접 확인. 테스트 338/4/5·해시·스모크·격리 창·`save.cfg`는 Codex 관측 (Claude 재실행 없음). 맨 앞 조건 없음. 대폭발 0.4초 바깥 이동 중앙값 132 → 204px, 탁 트인 곳 소폭발 31 → 47px, 더미 위 소폭발은 거의 안 밀림 (50px 넘게 6%). 판 길이·점수 거의 그대로. 결과: §12-ONE.27 "#136 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.27**
- 배경: 사용자 (2026-11-07, 0.16.3 뒤) "소폭발과 대폭발 모두 확실하게 주변 젤리들을 밀어냈으면 좋겠어". 지금 소폭발은 분홍만 밀고, 밀린 젤리는 중력 3600에 바로 눌린다 (위로 900 px/s → 약 112px)
- 앵커: `scripts/core/CollisionResolver.gd` `apply_jelly_tap_blast()`, `scripts/spike/Board3D.gd` `apply_blast_with_radius_factor()`·`start_tap_magnet()`·`_advance_tap_magnet()`·`set_gravity()`·`_apply_actual_gravity_to_orbs()`·`is_gravity_transition_active()`, `scripts/spike/Orb3D.gd` `set_gravity_vector()`, `config/GameConfig.gd`·`default_config.tres`, 측정 도구, `tests/test_jelly_regression.gd`, 캡처, `project.godot`
- 요구 (§12-ONE.27 1~10):
  1. 새 필드 `jelly_tap_common_push` **true**: 모든 색 소폭발이 반경 0.3 안을 민다 (터치한 젤리 제외, 분홍은 한 번만, 파랑은 밀기 + 지진, 보라는 밀기 → 무중력 → 자석)
  2. 새 필드 `blast_gravity_pause_time` **0.2**: 대폭발·소폭발로 밀린 젤리는 0.2초 무중력, 끝나면 그때 중력. 지진·합체 충격파는 걸지 않음
  3. 값: `blast_speed` 900 → **1350**, `blast_far_factor` 0.4 → **0.5**
  4. 밀림 측정 K0~K4 (바깥쪽 이동 거리 0.1·0.2·0.4·0.8초, 50px 이상 비율, 최대 속도·관통·이탈)
  5. 판 균형 측정 K4 (G1과 같은 조건·항목, 밀려서 생긴 반응 수)
  6. 성능: 공 100개 이상 + 대폭발 장면 K0·K4
  7. 해시: 예전 8종 (G1 포함) 그대로, K4 고정
  8. 테스트 (§12-ONE.27 8번)
  9. 캡처: K0·K4 대폭발·노랑 소폭발 0·0.1·0.2·0.4초, 두 비율, 마지막 전체 캡처
  10. 버전 **0.16.4**, 커밋 뒤 깨끗한 트리에서 Release (그 전 검증 빌드는 `-Debug`). 보고는 #135와 같다
- 수치 (Claude): `jelly_tap_common_push` **true**, `blast_gravity_pause_time` **0.2**, `blast_speed` **1350**, `blast_far_factor` **0.5**, 버전 **0.16.4**. 그 밖의 값은 그대로
- 건드리지 말 것: 대폭발·소폭발 조건·반경·점수, 색 청소·색별 효과 (1번 말고), 합체 충격파, 물리 값, 생성, 그림·연출 (명세에 없는 것 금지, 고리 모양 금지), 사용자 저장 파일, `docs/` (회신 파일 제외)
- **회신 맨 앞에**: K4 판 밖 이탈 1회 이상 또는 최대 관통 30px 초과, K4 자동 D-save 평균 턴이 G1 (101.70)과 20% 넘게 다름, K4 L-합체 D-all 미완료 3판 이상
- Done-when:
  - [ ] 테스트 통과, 예전 해시 8종 그대로, K4 해시 고정
  - [ ] 밀림 측정표 K0~K4, 판 균형표 K4 (G1 옆), 성능표
  - [ ] 캡처 (두 비율)
  - [ ] `build/windows/GravityOrb_v0.16.4.exe` (`mode=Release`, `_BUILD.txt` 커밋 = 브랜치 끝), 0.16.1~0.16.3 파일 그대로
- QA: §12-ONE.27 4~6·10번
- 커밋: 항목 단위 브랜치 (`blast-push`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-07 #135] 같은 색 합체는 레벨 차 1까지·턴 대기 판정 정리·빌드 0.16.3 — 완료
- 상태: 완료 (2026-11-07 사용자 "그대로 병합" · [PR #135](https://github.com/jeongmo-dot/gravity_orb/pull/135) 병합 `1001f14`)
- 검수: 코드 diff, 회신 측정표, 캡처 `100`·`102` (같은 색 L7 + L6 → L8 — 회신의 "L7만 남는"은 표기 잘못), `build/windows/GravityOrb_v0.16.3.exe` 크기·SHA-256·`_BUILD.txt` (커밋 `dce78a4` = 브랜치 끝, Release) 직접 확인. 테스트 336/4/5·해시·스모크·격리 창·`save.cfg`는 Codex 관측 (Claude 재실행 없음). G1: 모든 봇 약 100~120턴에 끝남, 대신 대폭발 63 → 3·점수 −87% (#128 1차 B와 비슷) — Claude가 병합 전에 사용자에게 물음. 결과: §12-ONE.26 "#135 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.26**
- 배경: 사용자 (2026-11-07) "정리 명세 넘겨줘", "이제 게임이 장기화 되니까 합체 규칙을 더 좁혀서, 1레벨 차이만 합치게 해줘"
- 앵커: `config/GameConfig.gd`·`config/default_config.tres` `jelly_merge_level_gap`, `scripts/core/CollisionResolver.gd` `_has_pending_jelly_reactions()`, `scripts/core/ReactionRules.gd` `can_react()` (규칙 기준 — 판정은 그대로), `tests/test_config.gd`·`tests/test_rules.gd`·`tests/test_jelly_regression.gd`, `tests/spike/capture_screens.gd`, 측정 도구, `project.godot`
- 요구 (§12-ONE.26 1~7):
  1. 기본 `jelly_merge_level_gap` 2 → **1** (`GameConfig.gd`·`default_config.tres`)
  2. `_has_pending_jelly_reactions()`가 `_pair_can_react()`로 짝을 정한다 (레벨 ±1·같은 레벨 대폭발을 따로 적지 않음). 레벨 차·대폭발 조건을 따로 적은 곳 목록을 회신에
  3. 해시: 예전 6종 그대로, 지금 기본은 묶음 F2 (`4c4ab4aa…`)로 남기고, 새 기본 G1 해시 고정
  4. 테스트: 기본값 판정, `can_react()` = `classify()`, 대기 판정 (합체 과정 0 묶음)
  5. 측정 G1: 자동·R·G·L-합체 × D-save·D-all (F2와 같은 조건·항목). **L-합체 D-all 미완료 3판 이상이면 회신 맨 앞**
  6. 캡처: 레벨 차에 따라 달라지는 장면을 새 기본값으로 (같은 색 L7이 L6을 먹는 과정), 두 비율, 마지막 전체 캡처
  7. 버전 **0.16.3**, 커밋 뒤 깨끗한 트리에서 Release 빌드. 그 전 검증 빌드는 `-Debug`. 보고는 #134와 같다
- 수치 (Claude): `jelly_merge_level_gap` **1**, 버전 **0.16.3**. 그 밖의 값은 그대로
- 건드리지 말 것: 다른 규칙·수치, 그림·연출 (명세에 없는 것 금지, 고리 모양 금지), 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when:
  - [ ] 테스트 통과, 예전 해시 6종·F2 그대로, G1 해시 고정
  - [ ] G1 측정표 (F2 옆)
  - [ ] 캡처 (두 비율)
  - [ ] `build/windows/GravityOrb_v0.16.3.exe` (`mode=Release`, `_BUILD.txt` 커밋 = 브랜치 끝), 0.16.1·0.16.2 파일 그대로
- QA: §12-ONE.26 5·7번
- 커밋: 항목 단위 브랜치 (`merge-gap-1`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-06 #134] Windows 빌드 0.16.2 (#133 포함)·0.16.1 복구·Release 덮어쓰기 막기·초록 안내 문구 — 완료
- 상태: 완료 (2026-11-06 Claude 검수 · [PR #134](https://github.com/jeongmo-dot/gravity_orb/pull/134) 병합 `eecfcec`)
- 검수: `build/windows/GravityOrb_v0.16.2.exe` (111,123,264바이트) 크기·해시·`_BUILD.txt` (커밋 `0e6a3f7` = 브랜치 끝), 0.16.1 복구 (111,111,824바이트, 해시 = zip 안 exe) 직접 확인. 코드 diff, 캡처 `115`·`116` 확인. Release 보호 실제 명령·테스트 333/4/5·스모크·격리 창·`save.cfg`는 Codex 관측 (Claude 재실행 없음). 시작 화면 JELLY 카드 실제 클릭은 못 함. 다른 버전 파일 12개는 사용자가 지웠다 (2026-11-06 사용자 확인, §10.5.1). 결과: §12-ONE.25 "#134 결과"
- 근거: [technical_design.md](technical_design.md) **§12-ONE.25 "#134"**, §10.5.1 (버전 기록 0.16.1 줄)
- 배경: 사용자 (2026-11-06) #133 표를 본 뒤 "병합하고 플레이". #133 추가 요구 1의 검증 빌드가 `-Debug` 없이 돌아 `build/windows/GravityOrb_v0.16.1.exe`가 덮였다 (§10.5.1 "항목 검증용 빌드는 `-Debug`로" 위반, 회신에 경고 없음)
- 앵커: `tools/build_windows.ps1`, `tests/test_build_script.gd`, `scripts/ui/Hud.gd` `JELLY_TAP_EFFECT_CALLOUTS`·`_show_jelly_tap_effect()`, `tests/test_callouts.gd`, `project.godot`
- 요구 (§12-ONE.25 "#134" 1~7):
  1. 맨 먼저 zip으로 0.16.1 exe 복구 (111,111,824바이트), `_BUILD.txt` 커밋 `0081c59`로
  2. Release 빌드 막기: 작업 트리가 깨끗하지 않으면, 같은 버전 exe가 있으면 멈춘다. 일부러 다시 만들 때만 `-ReplaceSameVersion`. `-Debug`는 그대로
  3. 문구 `초록 L8: 작은 초록 3개면 성장` (숫자는 `jelly_tap_grow_min_clean`에서)
  4. 테스트: 표시 중인 안내를 콤보가 덮으면 되살아나지 않고, 큐의 다음 안내는 다음 입력 대기 때
  5. 버전 `0.16.2`, 커밋 뒤 깨끗한 트리에서 Release 빌드
  6. 보고: §12-ONE.25 "#134" 6번 전부, 같은 명령 재실행이 멈추는 것 포함
  7. 회신: #132 회신의 다른 버전 파일 12개를 Codex가 지웠는지 (기록이 없으면 "모름"). 되살리지 않는다
- 수치 (Claude): 버전 **0.16.2**, 초록 문구는 위 그대로
- 건드리지 말 것: 규칙·수치·그림·측정 도구, 해시, 사용자 저장 파일, 명세에 없는 연출·표시, `docs/` (회신 파일 제외)
- Done-when: 위 보고. `build/windows/GravityOrb_v0.16.2.exe`로 사용자가 바로 플레이할 수 있고, 0.16.1은 원본으로 돌아옴
- 커밋: 항목 단위 브랜치 (`build-0.16.2`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-04 #133] 색 청소 소폭발 — 색마다 다른 효과 — 완료
- 상태: 완료 (2026-11-06 사용자 확인 · [PR #133](https://github.com/jeongmo-dot/gravity_orb/pull/133) 병합 `3760aed`)
- 검수: 코드 diff·회신 수치·성능 JSON·캡처 `114`·`116`·`126`·`127`·`128` (Claude 재실행 없음). F2: L-합체 D-all 미완료 12/20, 자동 초록 비율 71% → 49%, 위기에만 쓰면 모든 봇이 끝남. 사용자 표를 본 뒤 "병합하고 플레이". Release 빌드 규칙 위반으로 0.16.1 exe가 덮임 → #134. 결과 전체: §12-ONE.25 "#133 결과"
- 추가 요구 1: [technical_design.md](technical_design.md) **§12-ONE.25 "#133 1차 결과"** 1~7 — 표를 본 사용자 "L2 + 초록 3개 이상" (E3 L-합체 D-all 15/20 미완료, 소폭발의 약 70%가 초록)
  1. 기본 청소 L3 → **L2**
  2. 새 필드 `jelly_tap_grow_min_clean` **3**: 초록 L8·L9는 청소 대상 3개 이상일 때만 터치 후보
  3. 호령 되돌리기: `_pending_turn_callouts`를 없애 콤보 호령은 main처럼 앞 호령을 바로 바꾼다 (명세에 없는 변경이었다)
  4. 안내 한 줄은 입력을 기다릴 때 (`WAITING_INPUT`) 띄운다. 상수 8 → `jelly_tap_blast_min_level`
  5. 성능: `--full-board-performance`에 공 100개 이상 + 보라 소폭발 장면 (#121과 같은 지표)
  6. 다시 재기 **F2**: 자동·R·G·L-합체 × D-save·D-all, 색별 소폭발 수, 보라 같은 턴 대폭발 (D-save 따로). L-합체 D-all 미완료 3판 이상이면 회신 맨 앞
  7. 테스트·해시·캡처 `108`~`128` 다시
- 근거: [technical_design.md](technical_design.md) **§12-ONE.25**
- 배경: 사용자 (2026-11-04, 0.16.1 플레이 뒤) "중반 이후 공이 좀 찾을 때부터 전략적인 부분이 없어지고 루즈해지는 것 같아" → Claude 후보 5개 → "1번을 하되 색깔마다 효과가 다르게 할 수 있을까" → Claude 표 → "해보자"
- 앵커: `scripts/core/CollisionResolver.gd` `apply_jelly_tap_blast()`·`is_jelly_tap_blast_candidate()`, `scripts/core/TurnManager.gd` `_start_turn()`·`try_tap_blast_orb()`, `scripts/core/ScoreManager.gd` `points_for()`, `scripts/spike/Board3D.gd` (`apply_blast_with_radius_factor()`·`is_gravity_transition_active()`), `scripts/spike/Orb3D.gd` (`set_jelly_mass()`·`update_merge_visual()`), `scripts/ui/Hud.gd` (`_show_planet_unlock()` 큐), `scripts/fx/FeedbackDirector.gd`, `config/GameConfig.gd`·`default_config.tres`, 측정 도구, 회귀 해시, 캡처
- 수치 (Claude): 청소 레벨 ≤ **3**, 청소 점수 배율 **1.0**, 청소 그림 **0.25**초, 지진 **900** px/s, 보너스 젤리당 **100**, 자석 **0.5**초, 폭탄 반경은 지금 **0.3**
- 요구 (§12-ONE.25 "바꿀 것" 1~5):
  1. 공통: L8 이상 터치 → 같은 색 L3 이하 전부 사라짐 (공통에서는 밀지 않음)
  2. 색별: 분홍 폭탄 (주변 다른 색 L3 이하도 + 밀기), 파랑 지진 (판 전체 흔들기), 초록 성장 (L8·L9는 터지지 않고 자람, 빈 터치 없음), 노랑 보너스 (청소 수 × 100), 보라 자석 (0.5초 터진 자리로 중력), 주황 휴식 (그 턴 새 젤리 없음)
  3. 점수 식, 안내 한 줄 (판당 색마다 처음 한 번, 글자만), 청소 그림 (끌려가며 작아짐)
  4. 예전 값 묶음은 청소 0·PUSH로 해시 그대로, 새 기본 해시 고정
  5. 측정 J·C3·C2·E3·E2, 테스트, 캡처 (§12-ONE.25)
- 건드리지 말 것: 소폭발 판정·턴 쓰기·반경·점수 배율 0.5, 대폭발·잭팟·합체 규칙과 점수, 콤보·위험 배수, 생성, 물리·마찰, 합체 색 효과 (`shock_color_*`), 랭킹 (저장 형식·기록), 사용자 저장 파일, 명세에 없는 연출·표시 (고리 모양 금지), `docs/` (회신 파일 제외)
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 예전 해시 그대로, 새 기본 해시 상수 고정, 측정 표 보고, 캡처 (실제 창, 마지막은 전체 캡처) 보고, 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**. 기본값은 E3. 청소 범위·값은 측정을 사용자와 본 뒤 정하고 병합한다

### [2026-11-02 #132] Windows 빌드 0.16.1 — 0.16.0 뒤 JELLY 변경 (#111~#131) — 완료
- 상태: 완료 (2026-11-03 Claude 검수 · [PR #132](https://github.com/jeongmo-dot/gravity_orb/pull/132) 병합 `0df48e3`)
- 검수: `build/windows/GravityOrb_v0.16.1.exe` (111,111,824바이트) + `.console.exe` + `_BUILD.txt` (커밋 `0081c59` = 브랜치 끝, 커밋 14초 뒤 빌드, 코드는 main과 같고 다른 것은 버전 한 줄) 직접 확인. 스모크 2종·격리 창 (시작 화면·`--mode=jelly`)·사용자 `save.cfg` 해시 동일·묶음 검사·래퍼 331/331·다른 버전 파일 12개 이름·크기·해시 그대로 (Codex). 시작 화면 JELLY 카드 실제 클릭은 이번에도 못 함 (사용자 입력과 충돌해 중단). 0.16.0 파일 경위는 "모름" (§10.5.1). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§10.5·§10.5.1** (버전 기록 0.16.0·0.16.1 줄)
- 배경: 사용자 (2026-11-02) "빌드해줘" — 0.16.0 (10-26) 뒤 병합된 JELLY 변경을 직접 해 볼 빌드. 기획서 0.16.16
- 요구:
  1. `project.godot` `application/config/version` `0.16.0` → **`0.16.1`** (Claude 결정 값 — 기획서 0.16, PATCH +1)
  2. 버전을 커밋한 뒤 **깨끗한 작업 트리에서** 릴리스 빌드 `.\tools\build_windows.ps1` → `build/windows/GravityOrb_v0.16.1.exe` + `.console.exe` + `_BUILD.txt`. 다른 버전 파일은 남긴다
  3. 내보낸 콘솔 exe로 스모크 2종 (기본·`-- --mode=jelly`) 종료 코드 0·`SCRIPT ERROR` 0
  4. 격리 창에서 시작 화면·JELLY 직접 실행 확인 (실제 클릭이 안 되면 그 사실과 대신 확인한 방법)
  5. 지금 `build/windows/GravityOrb_v0.16.0.exe`는 원래 0.16.0이 아니다 (`_BUILD.txt` 커밋 `8aabebd`, 2026-11-01 17:56 — §10.5.1 0.16.0 줄). 그때 Codex가 Release 빌드를 돌렸는지 회신에 적는다 (기록이 없으면 "모름"). 파일은 그대로 둔다
- 검수: 빌드 결과 줄·파일 크기, `_BUILD.txt` 커밋 = 이 브랜치 마지막 커밋, 사용자 `save.cfg` 해시 전후 동일, 묶음에 `tests/`·`artifacts/`·`docs/` 없음, 래퍼 통과, 다른 버전 파일 이름·크기 그대로
- 건드리지 말 것: 버전 외 모든 파일, 사용자 저장 파일, 다른 버전 빌드 파일 (0.16.0 포함), `docs/` (회신 파일 제외)
- Done-when: 위 검수 보고
- 커밋: 항목 단위 브랜치 (`build-0.16.1`), **push·PR까지** (병합은 Claude 검수 뒤)

### [2026-11-01 #131] 잭팟을 대폭발보다 크게 — 같은 색 L10 둘 640 → 5,120 — 완료
- 상태: 완료 (2026-11-01 Claude 검수 · [PR #131](https://github.com/jeongmo-dot/gravity_orb/pull/131) 병합 `2b0ced1`)
- 검수: 명세대로 — 기본값 40 (잭팟 5,120, 콤보 3·점유율 70%에서 81,920 테스트), 래퍼 331/331, M·B·C8·D·ST 해시 그대로, 새 기본 해시 `3254c77f…` 고정 (Codex). `98` 캡처에서 실제 점수 경로로 금색 +5,120 팝업이 두 비율 모두 보드 안. 측정 없음 (명세대로). Claude 재실행 없음 (§12-ONE.24 결과)
- 근거: [technical_design.md](technical_design.md) **§12-ONE.24**
- 배경: #130에서 대폭발 배율을 5 → 15로 올려 (L8+L8 1,620 ~ L10+L10 3,840) 잭팟 640이 모든 대폭발보다 작아졌다. 사용자 "다음 차례에 올리기"
- 앵커: `config/GameConfig.gd`·`default_config.tres` (`max_merge_bonus_factor`), `scripts/core/ScoreManager.gd` `points_for()` (`MAX_CLEAR` — 식은 그대로), 회귀 해시 (`tests/test_jelly_regression.gd`), `tests/test_score.gd`·`tests/test_config.gd`, 캡처 (`tests/spike/capture_screens.gd`)
- 수치 (Claude): `max_merge_bonus_factor` 5 → **40** (잭팟 128 × 40 = 5,120)
- 요구:
  1. 기본값 변경 (`GameConfig.gd`·`default_config.tres` 함께)
  2. 예전 값 묶음 (M·B·C8·D·ST)은 5로 두어 해시 그대로, 새 기본 해시 상수 고정
  3. §12-ONE.24 테스트·캡처. 측정은 하지 않는다
- 건드리지 말 것: 잭팟 판정·충격파·연출, 대폭발·소폭발·합체 점수, 콤보·위험 배수, 소폭발 턴 쓰기, 레벨표·마찰·생성, 랭킹 (저장 형식·기록), 사용자 저장 파일, 새 연출·표시 (고리 모양 금지), `docs/` (회신 파일 제외)
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 예전 해시 그대로, 새 기본 해시 상수 고정, 캡처 (실제 창, 마지막은 전체 캡처) 보고, 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**. 병합은 Claude 검수 뒤

### [2026-11-01 #130] 대폭발 점수를 소폭발보다 확실히 크게·소폭발에 턴 쓰기 — 생존이냐 점수냐 — 완료
- 상태: 완료 (2026-11-01 Claude 검수 · [PR #130](https://github.com/jeongmo-dot/gravity_orb/pull/130) 병합 `3bf113e`)
- 검수: 코드·테스트·캡처는 명세대로 — 스와이프와 소폭발이 같은 `_start_turn()`을 지나고 소폭발은 중력만 안 바꾼다. 래퍼 331/331, M·B·C8·D 해시 그대로, 새 기본 ST `f3ff9347…` 고정 (Codex). 측정: 턴 쓰기로 L-합체 바로 쓰기 600턴 미완료 8 → 1판·중앙값 546.5 → 309턴, 자동 1 → 0판. 아끼기 ÷ 바로 쓰기 총점 비 (×15) 자동 1.53·R 2.15·G 1.41·L 1.14 (중앙값으로는 자동·L 0.92~0.94). 위기에만 쓰기가 모든 봇에서 평균 1등. 전략 봇 숫자는 Claude가 측정 파일로 대조. Claude 재실행 없음 (§12-ONE.23 결과)
- 근거: [technical_design.md](technical_design.md) **§12-ONE.23**
- 배경: 사용자 (2026-11-01, #129 병합 뒤) "L8,9,10 대폭발 점수를 소폭발 보다 확실히 커질 수 있게 해줘", "생존을 선택하냐 점수를 선택하느냐 전략이 될 수 있게", "잠깐 그럼 소폭발의 대가는 뭐가 있을까" → Claude 후보 중 "턴 쓰기". #129 측정에서 바로 쓰기 (D-all)는 판이 거의 끝나지 않아 (L-합체 20판 중 8판 600턴) 총점도 이겼다
- 앵커: `config/GameConfig.gd`·`default_config.tres` (`blast_score_factor`·`jelly_tap_blast_score_factor` 기본값, 새 필드), `scripts/core/ScoreManager.gd` `points_for()`, `scripts/core/TurnManager.gd` `try_tap_blast_orb()`·`on_swipe()`·`_on_settled()` (`_is_tap_blast_settle`), 봇·측정 도구 (`tests/spike/run_jolt_3d_measurement.gd`, `tests/run_jelly_physics_autoplay.ps1`, `tests/tools/run_jelly_measurement.ps1`), 회귀 해시 (`tests/test_jelly_regression.gd`), 캡처 (`tests/spike/capture_screens.gd`)
- 수치 (Claude):
  - `blast_score_factor` 5 → **15** (L8+L8 1,620 · L8+L10 2,730 · L10+L10 3,840)
  - `jelly_tap_blast_score_factor` 1.0 → **0.5** (L8 27 · L9 42 · L10 64)
  - 새 `jelly_tap_blast_uses_turn` **true**
- 요구:
  1. 두 점수 기본값 변경 (`GameConfig.gd`·`default_config.tres` 함께)
  2. 턴 쓰기: 입력 대기 중 소폭발이 그 턴의 입력이 된다 — 소폭발 + `on_swipe()`와 같은 턴 시작 (`turn_index` +1, 콤보 0, 지금 중력 방향 입구로 NEXT 묶음 생성, 중력 그대로), 정착 뒤 게임 오버·FINAL MOVE 판정. FINAL MOVE 대기 중 소폭발은 그 FINAL MOVE를 쓴 것 (새 젤리 없이 판정). false면 #129 그대로
  3. 예전 값 묶음 (M·B·C8·D)은 5 / 1.0 / 턴 안 씀으로 두어 해시 그대로
  4. §12-ONE.23 측정 (S × D-0·D-save·D-all, ST × D-save·D-all — 자동 20시드·전략 R·G·L × 20, 반응 종류별 점수, 배율 10·20 환산, 아끼기 ÷ 바로 쓰기 총점 비)·테스트·캡처
- 건드리지 말 것: 소폭발 판정·반경·여백, 대폭발 규칙, 잭팟 점수, 합체 점수, 콤보·위험 배수, 레벨표, 마찰, 생성 값, 랭킹 (저장 형식·기록), 사용자 저장 파일, 새 연출·표시 (고리 모양 금지), `docs/` (회신 파일 제외)
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), M·B·C8·D 해시 그대로, 새 기본 해시 상수 고정, 측정 표·캡처 (실제 창, 마지막은 전체 캡처) 보고, 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**. 기본값은 ST로 두고, 병합은 측정을 사용자와 본 뒤 (배율 10·15·20, 턴 쓰기 여부) → 사용자 "ST ×15 그대로", 잭팟은 "다음 차례에 올리기" (#131)

### [2026-11-01 #129] L8~L10 터치 소폭발·L8 이상 다른 색은 레벨 상관없이 대폭발·레벨별 공끼리 마찰 — 완료
- 상태: 완료 (2026-11-01 Claude 검수 · [PR #129](https://github.com/jeongmo-dot/gravity_orb/pull/129) 병합 `0fab3b2`)
- 검수: 코드·테스트·캡처는 명세대로. 래퍼 328/328, M·B·C8 해시 그대로, 새 기본 해시 `2cdf7947…` 고정 (Codex). 측정: 마찰만 (F) 판 길이 −3%, 레벨 다른 대폭발 20판에 13번 더, 소폭발 위기에만 (D-save) 141.7턴, 생기면 바로 (D-all) 218턴·1판 미완료, L-합체 봇 중앙값 546.5턴·20판 중 8판 600턴 미완료 (Claude가 측정 파일로 확인), 대폭발 63 → 7번. 마찰 작은 값 규칙은 재질 값·`rough` 끔까지 테스트, 실제 접촉은 재지 않음. 사용자가 표를 본 뒤 "그대로 병합". Claude 재실행 없음 (§12-ONE.22 결과)
- 근거: [technical_design.md](technical_design.md) **§12-ONE.22**
- 배경: 사용자 (2026-11-01, #128 병합 뒤 플레이) "L8 공 터치했는데 안터지는데" → "L8~L10 싱글 폭발 가능. 소폭발.", "L8~L10 서로 다른 색깔과 충돌시 대폭발" (Claude 질문에 "레벨 상관없이"), "공끼리의 마찰은 L1~L3 는 마찰 0.3 L4~L7은 0.4, L8~L10 은 0.5 로 마찰 계수 바꿔줘"
- 앵커: `scripts/core/CollisionResolver.gd` `is_jelly_tap_blast_candidate()`·`apply_jelly_tap_blast()`, `scripts/core/TurnManager.gd` `on_tap()`, `scripts/core/ScoreManager.gd` `points_for()` (`TAP_BLAST`), `scripts/core/ReactionRules.gd` `_classify_jelly()`·`can_react()`, `scripts/spike/Orb3D.gd` `_shared_physics_material()`·레벨이 바뀌는 곳, `config/GameConfig.gd`·`default_config.tres` 새 필드, 봇·측정 도구, 회귀 해시 (`tests/test_jelly_regression.gd`), 캡처 (`tests/spike/capture_screens.gd`)
- 수치 (Claude):
  - 새 `jelly_tap_blast_min_level` **8** (소폭발 점수 = 터진 레벨 점수 × 1.0 → L8 54·L9 84·L10 128, 반경 0.3 그대로)
  - 새 `jelly_blast_requires_same_level` **false** (다른 색 둘 다 L8 이상이면 레벨이 달라도 대폭발, 점수 `(sA + sB) × 5`, 범위·연출은 큰 레벨)
  - 새 `orb_friction_by_level` **[0.3, 0.3, 0.3, 0.4, 0.4, 0.4, 0.4, 0.5, 0.5, 0.5]** (길이가 다르면 `orb_friction` 하나). 두 젤리 사이는 엔진 규칙 (작은 값 — Jolt에서 확인해 회신에), 벽은 0.3 그대로
- 요구:
  1. L8 이상 터치 소폭발 (그 밖의 조건·턴 안 씀·FINAL MOVE 유지 등은 #128 그대로). 반응의 레벨·점수·연출 레벨은 터진 젤리 레벨, 연출 세기 절반
  2. 다른 색 대폭발에서 같은 레벨 조건을 값으로 끔. 같은 색 흡수가 먼저, `can_react()`도 같은 규칙
  3. 젤리 물리 재질을 레벨별로. 흡수·합체로 레벨이 바뀌면 재질도 바꾼다
  4. 예전 값 묶음 (M·B·C8)은 예전 동작 (같은 레벨만, 소폭발은 꼭대기만, 마찰 하나)으로 두어 해시 그대로
  5. §12-ONE.22 측정 1~5 (F·D-0·D-save·D-all, 전략 봇 D-0·D-save·D-all, 캡처 — L8 소폭발은 주변 젤리가 밀리는 모습이 보이게, `06`·`07` 이름 정리)
- 건드리지 말 것: 레벨표·흡수 레벨 차 2·대폭발 기준 L8·잭팟, 소폭발 반경·점수 배율·터치 여백, 벽 마찰, 튕김, 생성, FINAL MOVE·게임 오버, 랭킹, 사용자 저장 파일, 새 연출·터치 표시 (고리 모양 금지), `docs/` (회신 파일 제외)
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), M·B·C8 해시 그대로, 새 기본값 해시 상수 고정, 엔진 마찰 섞기 규칙 확인, 측정 표·캡처 (실제 창, 마지막은 전체 캡처) 보고, 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**. 기본값은 새 값으로 두고, 병합은 측정을 사용자와 본 뒤 → 사용자 "그대로 병합"

### [2026-11-01 #128] 레벨 L10까지 잘게 (L10 = 지금 L7 크기)·다른 색 대폭발은 L10끼리만·L10 터치 소폭발 — 완료
- 상태: 완료 (2026-11-01 Claude 검수 · [PR #128](https://github.com/jeongmo-dot/gravity_orb/pull/128) 병합 `79e12b9`)
- 검수: 1차 (A·B, 다른 색 대폭발 L10끼리만) → 봇이 L10을 못 만들어 대폭발·소폭발 0회, B 93턴 → 추가 요구 1 (`jelly_merge_level_gap`, C10·C9·C8) → 사용자 "C8" → 추가 요구 2 (기본값 레벨 차 2·L8). 새 기본 해시 `8c1a02e9…` 고정, M·B 해시 그대로, 래퍼 326/326 (Codex). C8 봇: 131.5턴·점수 91,390·대폭발 56·실력 비 1.25 / 1.30, L-합체 봇 20판 중 5판 L10. 기본값 = 2차 C8 측정 인자인 것은 Claude가 config diff와 측정 JSON으로 확인. 캡처 `06`·`07` 이름은 #120 그대로 (내용은 새 값) — 다음 캡처 항목에서. Claude 재실행 없음 (§12-ONE.21 결과)
- 근거: [technical_design.md](technical_design.md) **§12-ONE.21** (「#128 1차 결과」·「추가 요구 1」)
- 1차 결과 요약: 코드·테스트·캡처는 명세대로. 측정에서 A·B 모두 봇이 L10을 못 만들어 소폭발·대폭발·잭팟 0회. B는 판 93턴 (M 139)·점수 약 ¼·실력 비 1.04, A는 223턴이지만 최고 L8
- **추가 요구 1** (사용자 2026-11-01 "B + 레벨 차 2까지 먹기로 재측정", 대폭발 "낮춘 기준도 같이 재기"):
  1. 새 필드 `jelly_merge_level_gap` (int, 기본 1 = 지금). 앵커 `scripts/core/ReactionRules.gd` `_classify_jelly()`·`can_react()`의 `absi(level_a - level_b) <= 1`. 봇·측정 도구에서 레벨 차 1을 따로 쓰는 곳도 이 값으로 (회신에 목록)
  2. 측정: C = B 레벨표 + 레벨 차 2. **C10-0 / C10** (L10끼리만, 소폭발 안 씀 / 씀), **C9** (L9부터), **C8** (L8부터) — 자동 20시드 4개, 전략 봇 R·G·L × 20은 C10·C9·C8. M·B는 해시가 같으면 1차 숫자. 대폭발은 레벨별, L10이 나온 판 수·소폭발 수 추가
  3. 테스트: 레벨 차 1·2 판정, M·B 해시 그대로, C10 해시 출력. 캡처: 같은 색 L7이 L5를 먹는 과정 0·50·100%, 다른 색 L8+L8 대폭발 (두 비율, 실제 창, 마지막 전체)
  4. 기본값은 1차 그대로 (B, 레벨 차 1, L10끼리만). 최종 값은 결과를 보고 사용자가 고른다
- 2차 결과 요약: C10 101턴·C9 107턴·**C8 131턴** (M 139). C8은 점수 9.1만 (M 9.3만), 대폭발 56회, 실력 비 1.25 / 1.30, L-합체 봇 20판 중 5판에서 L10·소폭발 6회. 레벨 차 2만으로는 +8%에 그쳤다
- **추가 요구 2** (사용자 2026-11-01 "C8"): [§12-ONE.21](technical_design.md) 「추가 요구 2」
  1. 기본값 `jelly_merge_level_gap` 1 → **2**, `jelly_blast_min_level` 10 → **8** (`default_config.tres`·`GameConfig.gd` 함께)
  2. 기본값을 가정한 테스트를 새 기본값으로. 새 기본 (C8) 해시 상수 고정 (2차 C8 인자 실행과 같은 해시), M·B 해시는 값 묶음 검사로 남김
  3. 기준·레벨 차에 따라 바뀌는 회귀·캡처 장면은 새 기본값으로 (이름 바꾼 것은 회신에). 두 비율 전체 캡처. 측정은 다시 하지 않는다
- 배경: 사용자 (2026-11-01) "같은 색 L7 은 대폭발 유지, 다른 색의 경우 L7의 경우만 유지", "L2 부터 L7의 단계를 더욱 세분화 L10 까지 늘리는 대신 L10 의 크기를 현재 L7 사이즈로", "L10 이 되면 해당 젤리를 터치해서 소폭발을 할 수 있게 해줘". 1번의 L7은 새 L10이다 (사용자 확인). L10까지 드는 양은 A (단계마다 2배, L10 = 512)·B (L10 = 64) 둘 다 재서 사용자가 고른다
- 앵커: `config/GameConfig.gd` `jelly_mass_for_level()`·`jelly_level_for_mass()`·`blast_enabled_for_level()`·새 필드, `config/default_config.tres`, `scripts/spike/Orb3D.gd` `_jelly_fill_fraction_for_mass()`, `scripts/core/JellyOrbArt.gd` (레벨 7 하드코딩·밝기), `scripts/fx/FeedbackDirector.gd` (레벨 기준·대폭발 연출), `scripts/autoload/InputRouter.gd` `_end_pointer_gesture()` (터치), `scripts/core/TurnManager.gd` (소폭발 뒤 안정), `scripts/core/CollisionResolver.gd`·`scripts/spike/Board3D.gd` `apply_blast()`, `scripts/core/ScoreManager.gd`, 봇·측정 도구, 캡처 (`tests/spike/capture_screens.gd`)
- 수치 (기본 = B):
  - `orb_max_level` 10, 새 `jelly_level_masses` [1, 2, 3, 5, 7, 11, 17, 27, 42, 64], `level_radii` [25, 40, 52, 68, 80, 92, 102, 115, 128, 140], `level_scores` [2, 4, 6, 10, 14, 22, 34, 54, 84, 128]
  - A (측정용 값 묶음): 질량 [1, 2, 4, 8, 16, 32, 64, 128, 256, 512], 반지름 [25, 40, 47, 55, 64, 75, 88, 102, 120, 140], 점수 [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]
  - `jelly_blast_min_level` 6 → 10, `blast_push_radius_by_level` [0, 0, 0, 0.3, 0.55, 1, 1, 1, 1, 1], `gravity_level_scale` 0.05 → 0.0333, `shock_level_scale` 0.3 → 0.2
  - 새 `jelly_tap_blast_radius_factor` 0.3, `jelly_tap_blast_score_factor` 1.0, `jelly_tap_blast_touch_margin` 16
- 요구:
  1. 레벨 10단계, 질량 표 (`jelly_level_masses` — 길이가 다르면 2^(L−1)), 배 속 비율도 표 기준
  2. 꼭대기 규칙: 같은 색 L10+L10 잭팟, 다른 색은 L10+L10만 대폭발
  3. 레벨에 묶인 그림·연출 값은 L10 = 지금 L7. 꼭대기를 뜻하는 7은 `orb_max_level`로, 그 밖의 레벨 숫자 기준은 같은 반지름 이상인 첫 레벨로 바꾸고, 바꾼 곳 전부를 회신에 표로 적는다
  4. L10 터치 소폭발: 입력 대기 중 80px 미만 터치로 L10 하나를 터뜨려 반경 0.3 × 판 안을 밀어낸다. 턴·생성·중력 그대로, 판이 안정되면 입력 대기로 돌아온다. 연출은 기존 대폭발 연출을 한 젤리분·세기 절반으로 (새 연출 없음)
  5. §12-ONE.21 측정 1~5 (M / A0 / A1 / B0 / B1)
- 건드리지 말 것: 생성 (L1·L2·비용·램프·상한), 흡수 판정 (레벨 차는 새 필드로만, 기본 1), 합체 과정 0.3초, 색 효과, 물리 (위 두 값 빼고), FINAL MOVE·게임 오버, 랭킹, 사용자 저장 파일, 새 연출 (고리 모양 금지), `docs/` (회신 파일 제외). 측정이 어떻게 나와도 기본값은 B로 두고 보고한다
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), M 값에서 해시 `ee67b19c…` 그대로, 새 기본값 해시 상수 고정, 측정 표·캡처 (실제 창 포함, 마지막은 전체 캡처) 보고, 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**. 최종 값은 C8 (사용자 선택) — 추가 요구 2 검수 뒤 Claude가 병합

### [2026-10-31 #127] 합쳐지는 과정이 보이게 — 완료
- 상태: 완료 (2026-11-01 Claude 검수 · [PR #127](https://github.com/jeongmo-dot/gravity_orb/pull/127) 병합 `953459e`)
- 검수: 닿음 → 0.3초 과정 → 완성. 먹히는 쪽은 물리를 끈 그림으로 결과 뒤로 끌려가고, 결과는 smoothstep으로 그림 = 물리 반지름 함께 커진다. 반응·점수·연출은 완성 때 한 번. 중간 리뷰 4건 반영 (안정 sweep이 과정을 시작하면 턴 계속, 미뤄진 합체 계측, 테스트 보강, 닿은 상태 캡처). 해시 T = 0 `5e00b1f7…` 그대로, T = 0.3 `ee67b19c…` (상수 고정 안 됨 — 다음 항목에서). 20시드 T = 0 → 0.3: 판 130.05 → 139.10턴, 점수 107,291 → 92,665, 늦어진 턴 21.4% (평균 0.146초), 입력 대기 판에 닿은 합체 쌍 0.8% → 3.0% (상한 뒤 다음 턴으로 미룸 — 그대로 둠), 최대 관통 39.4 → 20.7px. 성능 차이 없음. 래퍼 317/317 (Codex). Claude가 캡처 `72`~`86` 두 비율을 직접 확인했다. Claude 재실행 없음 (§12-ONE.20 결과)
- 근거: [technical_design.md](technical_design.md) **§12-ONE.20**
- 배경: 지금은 닿은 물리 프레임에 두 젤리를 지우고 결과를 만들어 "닿음 → 결과"가 한 프레임에 끝난다. 같은 레벨은 중점에 다 큰 결과가 바로 나타나고, 흡수는 작은 쪽 대신 빛 덩어리가 미끄러진다. 사용자 (2026-10-31) "공과 공이 합쳐질 때 너무 순식간에 합쳐지는 느낌이야. 합쳐지는 과정이 눈에 보였으면 좋겠어"
- 앵커: `scripts/core/CollisionResolver.gd` `flush()`·`has_pending_reactions()`·`_lock_reaction_result()`, `scripts/core/TurnManager.gd` 안정·1.5초 상한 판정, `scripts/spike/Orb3D.gd` `set_jelly_mass()`·`_advance_growth()`·`JELLY_ABSORPTION_GROWTH_DURATION`·`disable_physics()`, `scripts/spike/Board3D.gd` `spawn_orb()`·`remove_orb()`, `scripts/fx/FeedbackDirector.gd` 합체 연출 (`play_visual_punch`·`_create_jelly_absorption_trails`), `config/GameConfig.gd` (새 필드)·`config/default_config.tres`, 테스트·봇 (`tests/run_jelly_physics_autoplay.ps1`)·캡처 (`tests/spike/capture_screens.gd`)
- 수치: 새 필드 `jelly_merge_duration` 기본 **0.3** (후보). 측정은 0·0.3
- 요구:
  1. 닿음 (규칙 판정·두 젤리 예약) → 과정 T → 완성 (지금 닿는 순간 하던 일 전부). T = 0이면 지금과 같다
  2. 과정: 먹히는 쪽은 물리를 끄고 그림만 결과의 지금 위치로 `p²`로 끌려가며 크기 1 → 0.2, 늘어남 `1 + 0.25p`·옆 `1 − 0.15p`, 결과 뒤에 그린다. 같은 레벨은 중점에 결과를 `R[L]` → `R[L+1]`로 키우며 둘 다 끌려간다. 흡수로 레벨이 오르면 먹는 쪽을 T 동안 키운다. 커지는 반지름은 매 프레임 그림 = 물리
  3. 반응 잠금은 닿는 순간부터 센다. 턴은 진행 중 합체가 완성된 뒤 끝난다 (1.5초 상한 포함, 상한 뒤 새 합체 없음)
  4. `JellyAbsorptionTrail` 삭제
  5. §12-ONE.20 측정 1~5
- 건드리지 말 것: 규칙·점수·콤보 배수·결과 위치 규칙, 대폭발, `chain_reaction_delay` 값, 생성·FINAL MOVE·게임 오버 판정, 젤리 그림·다른 연출 (새 연출 없음, 고리 모양 금지), 다른 모드, 사용자 저장 파일, `docs/` (회신 파일 제외). 측정이 어떻게 나와도 기본값은 0.3으로 두고 보고한다
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 해시 보고 (0에서 그대로), 측정 표·캡처 (실제 창 포함, 마지막은 전체 캡처) 보고, 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-31 #126] 들어오는 수량을 L1 기준으로 (L2는 2개 또는 3개분)·최대 5 — 완료
- 상태: 완료 (2026-10-31 Claude 검수 · [PR #126](https://github.com/jeongmo-dot/gravity_orb/pull/126) 병합 `919ce0e`, 사용자가 M2 선택)
- 검수: `spawn_cost_for_level()` (없거나 1 미만이면 1), `_draw_level_for_budget()`이 남은 예산보다 비싼 레벨을 빼고 뽑는다 ([1, 1]은 예전 RNG 순서 그대로), `_draw_batch()`·`sync_next_batch_size()`가 예산을 정확히 채운다 (넘치면 끝에서 뺌). `×n` = 젤리 개수. 600턴 상한에서 B·M0·M2·M3 80판 모두 게임 오버 — M2 평균 130.05턴·점수 107,291, L÷R 길이 1.46 (§12-ONE.19 결과). 해시 `5e00b1f7…` 그대로, 래퍼 314/314 (Codex). Claude가 캡처 `65`·`71`을 직접 확인했다 (§12-ONE.18 캡처 불일치도 해소). M2 최대 관통 39.4px는 #118 38.3px보다 조금 커서 지켜본다. Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.19**
- 배경: 지금은 턴 수량만큼 젤리를 뽑고 레벨을 따로 정해서, L2가 섞이면 같은 수량이라도 덩치가 커진다. 수량에 상한이 없다. 사용자 (2026-10-31) "공이 들어올 때 L1 공이면 1개로 취급, L2 공이면 2개나 3개로 취급해서 수량 계산해줘", "그리고 공 수량 최대값은 5개를 맥스로 해줘"
- 앵커: `config/GameConfig.gd` (새 필드 `spawn_level_costs`)·`config/default_config.tres`, `scripts/core/Spawner.gd` `_draw_batch()`·`_draw_candidate_for_turn()`·`sync_next_batch_size()`·`_batch_size_for_index()`, `scripts/ui/Hud.gd` 미리보기 `×n` (`_next_count_label`·`_then_count_label` — 젤리 개수 그대로인지 확인), `tests/test_spawner.gd`·`tests/test_config.gd`, 봇 `tests/run_jelly_physics_autoplay.ps1`·`tests/tools/run_jelly_blast_measurement.ps1`, 캡처 `tests/spike/capture_screens.gd`
- 수치: `spawn_count_max` 0 → **5** (사용자), `spawn_level_costs` 새 필드 기본 **[1, 2]** (후보). 측정은 B (지금)·M0 (5, [1, 1])·M2 (5, [1, 2])·M3 (5, [1, 3]). 나머지 그대로
- 요구:
  1. `spawn_level_costs` 추가 (없거나 1 미만이면 1, [1, 1]이면 지금과 같은 묶음)
  2. 턴 수량을 L1 환산 예산으로: 남은 예산 안에 드는 레벨만 후보로 `spawn_level_weights`를 다시 나눠 뽑고, 비용만큼 예산을 줄여 0이 될 때까지. 색·위치·해금 첫 젤리 새 색은 그대로
  3. NEXT·THEN `×n`은 젤리 개수 그대로. `sync_next_batch_size()`도 같은 규칙 (넘치면 끝에서 빼고 모자라면 더 뽑기)
  4. `spawn_count_max` 0 → 5 (41턴부터 수량 5, 기존 상한 처리 그대로)
  5. §12-ONE.19 측정 1~5 (B·M0·M2·M3 나란히, **600턴 상한** — 안 끝난 판은 따로 센다)
- 건드리지 말 것: 수량 램프 (10턴마다 +1)·`spawn_level_weights`·시작 배치·색 해금, 생성 위치·입구 대기·FINAL MOVE·게임 오버, 규칙·점수·물리, 그림·연출 (새 연출 없음), 사용자 저장 파일, `docs/` (회신 파일 제외). 판 길이·점수가 어떻게 나와도 (판이 끝나지 않아도) 값은 M2로 두고 보고한다
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), JELLY 기준 해시 보고, 측정 표·캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만. **병합은 결과를 보고 사용자가 2·3을 고른 뒤**
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-31 #125] 위에 턴 수·막힘 글자 삭제·랭킹은 턴 — 완료
- 상태: 완료 (2026-10-31 Claude 검수 · [PR #125](https://github.com/jeongmo-dot/gravity_orb/pull/125) 병합 `aa355bd`)
- 검수: 소리 버튼과 SCORE 사이 `TURN` 판 (1080 기준 156~288), 숫자 = 입력 대기 중 `turn_index + 1`·그 밖 `turn_index` (0이면 1), `state_changed`마다 갱신·연출 없음. 막힘 글자 판·레이아웃 키·글자 처리 삭제, 판 둘레 표시 그대로. 랭킹 `턴` 열 = `turns`. 해시 `5e00b1f7…` 그대로, 래퍼 310/310 (Codex). Claude가 캡처 `71`·`30`·`02`를 직접 확인했다. 캡처 `65`·`71`은 장면의 턴과 미리보기가 맞지 않는다 (캡처만의 일, §12-ONE.18 결과). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.18**
- 배경: 사용자 (2026-10-31) "상단에 턴 수도 넣어주고 랭킹에도 최고 턴 값 기록해줘", 미리보기 칸 위 "↑ ← → 막힘" 스크린샷과 함께 "이 막힘 표시는 없애줘", 랭킹 스크린샷과 함께 "랭킹에서 final move 는 빼고 턴 수 넣어줘"
- 앵커: `scripts/ui/Hud.gd` `hud_layout()`·`_apply_layout()`·`_on_warning_changed()`, `scenes/UI.tscn` (`Hud/BestPanel`·`BestTitleLabel`·`BestLabel`을 본뜸, `Hud/BlockedPanel`·`BlockedLabel` 삭제), `scripts/ui/RankingPanel.gd` `_refresh()`, `scripts/core/TurnManager.gd` (`turn_index`·`state_changed`·`turn_started` — 읽기만), 테스트 `tests/test_screen_layout.gd`·`tests/scenarios/test_score_flow.gd`·`tests/test_jelly_shell.gd`·`tests/test_rankings.gd`
- 수치: 턴 판 가로 = 소리 버튼 끝 + 12 ~ SCORE 판 시작 − 12 (1080 기준 156~288), 세로 = SCORE·BEST 판과 같은 줄 (높이 150), 숫자 글꼴 BEST와 같은 40~18
- 요구:
  1. 위 줄의 소리 버튼과 SCORE 판 사이에 BEST 모양의 `TURN` 판을 둔다. 다른 HUD 요소는 그대로
  2. 숫자는 입력 대기 중 `turn_index + 1`, 공이 움직이는 동안과 게임 오버 뒤에는 `turn_index` (시작 정착 중 1). 게임 오버 때 숫자 = 랭킹 `turns`. 바뀔 때 연출 없음
  3. 미리보기 칸 위 막힘 글자 판 (`BlockedPanel`·`BlockedLabel`)을 지운다. 판 둘레 빨간 화살표·✕와 막힘 계산은 그대로
  4. 랭킹 JELLY의 `FINAL MOVE` 열을 `턴` (기록의 `turns`)으로 바꾼다. 저장 형식은 그대로 (`final_moves`도 계속 저장)
  5. §12-ONE.18 확인 1~3
- 건드리지 말 것: 다른 HUD 요소의 위치와 모양, NEXT·THEN 위치, 결과 화면·시작 화면, 저장 형식, 규칙·물리·생성, 새 연출 (턴 숫자 튀기·반짝임·소리 없음), 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), JELLY 기준 해시 그대로 (`5e00b1f7…`), 캡처 보고 (실제 창, 두 비율, 마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-31 #120] 대폭발은 L7끼리만 → L6부터 — 완료
- 상태: 완료 (2026-10-31 Claude 검수 · [PR #124](https://github.com/jeongmo-dot/gravity_orb/pull/124) 병합 `32ee9d8`, 최종 값 6 — 사용자 결정)
- 검수: 1차 J7은 봇 120판 동안 대폭발 0번 (실력 비 1.02)이라 보류 → 추가 요구 1로 J6. 봇 20판 J5 / J6 / J7 = 112.8 / 87.9 / 83.0턴, 점수 41.4만 / 9.1만 / 4.7만, 대폭발 204 / 18 / 0. 전략 봇 실력 비 (길이 / 점수) 1.20 / 2.42 → 1.14 / 2.60 → 1.02 / 1.13. 사용자가 세 값을 보고 "L6부터로 병합". 회귀 대폭발 사건 L6 쌍, 새 해시 `5e00b1f7…`, 래퍼 308/308 (Codex). Claude가 캡처 `06`을 직접 확인했다 (§12-ONE.13 결과). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.13**
- 배경: 지금 JELLY는 다른 색·같은 레벨 젤리가 둘 다 L5 이상이면 닿을 때 대폭발한다 (`jelly_blast_min_level` 5). 사용자 (2026-10-31) "폭발이 L7 이었으면 L7과 L7이 만났을 때만 폭발"
- 앵커: `config/default_config.tres`·`config/GameConfig.gd`의 `jelly_blast_min_level`, `scripts/core/ReactionRules.gd` `_classify_jelly()`, `GameConfig.blast_enabled_for_level()`, `tests/test_config.gd` (기본값 5 확인), `tests/test_rules.gd`, JELLY 회귀 (`test_jelly_regression`), `tests/tools/run_jelly_blast_measurement.ps1`
- 수치: `jelly_blast_min_level` 5 → 7. 나머지 그대로
- 요구:
  1. `jelly_blast_min_level` 5 → 7 (규칙 코드는 그대로)
  2. 테스트 (기본값에서): 다른 색 L5+L5·L6+L6 반응 없음, 다른 색 L7+L7 대폭발, 같은 색 L7+L7 잭팟, L5·L6 보통 얼굴 (`is_blast_armed()` 거짓), L7 MAX 얼굴 그대로
  3. JELLY 회귀 7가지 사건의 "L5 대폭발"을 "L7 대폭발 (다른 색 L7+L7)"로 바꾼다. 새 기준 해시
  4. §12-ONE.13 측정 1~5 (5는 #121 측정기 `--full-board-performance`의 장면 ③을 J7로 한 번)
- 건드리지 말 것: 흡수·잭팟 규칙, 대폭발 범위·속도·점수, 물리 값, #119 값, 색 해금, 그림·연출 (새 연출 없음, 얼굴 코드 지우지 않음), CLASSIC `blast_min_level`, 사용자 저장 파일, `docs/` (회신 파일 제외). 판이 짧아지거나 실력 비가 떨어져도 값은 그대로 두고 보고한다
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 새 JELLY 기준 해시, 측정 표·캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**
- **추가 요구 1** (2026-10-31, [PR #124](https://github.com/jeongmo-dot/gravity_orb/pull/124) 1차 검수 — 병합 보류): 1차 (J7)는 명세대로지만 봇 120판 동안 대폭발이 0번이었다 (판 113 → 83턴, 점수 41만 → 4.7만, 실력 비 1.20 → 1.02). 사용자 결정 "L6부터로 다시 재기" → 같은 브랜치·PR에서 [technical_design.md](technical_design.md) §12-ONE.13 **추가 요구 1**:
  1. `jelly_blast_min_level` 7 → **6** (다른 색 L5 반응 없음, 다른 색 L6·L7 대폭발, 같은 색 L7 잭팟)
  2. 테스트·얼굴 (L6 `><`, L5 보통, L7 MAX)·회귀 대폭발 사건을 L6 쌍으로, 새 기준 해시
  3. 봇 20판·전략 봇 R·G·L × 20을 J6으로, 1차의 J5·J7과 나란히 (대폭발은 레벨별)
  4. 캡처 `06`·`07`·`15`를 L6 기준으로 (이름은 내용에 맞게), 두 비율 전체 캡처 (마지막에)
  - 값은 6으로 두고 보고한다. 병합 여부와 최종 값은 결과를 보고 사용자와 정한다

### [2026-10-31 #124] 같은 방향으로는 밀 수 없게 — 완료
- 상태: 완료 (2026-10-31 Claude 검수 · [PR #123](https://github.com/jeongmo-dot/gravity_orb/pull/123) 병합 `99240c2`)
- 검수: `allow_same_direction_swipe` false, 같은 방향 입력은 잠그지 않고 무시 (턴·중력·생성·미리보기·신호 그대로, 첫 턴 아래·FINAL MOVE도 막힘), 입력 대기 중 지금 방향 화살표·막힘 표시 숨김. 봇은 같은 방향 입력 0. 봇 20판 111.1 → 112.8턴, 점수 37.4만 → 41.4만, 최대 관통 31.6px (#118 범위 안). 새 해시 `935908ce…`, 래퍼 308/308 (Codex). Claude가 캡처 `31` 두 비율 중 540×960을 직접 확인했다. Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.17**
- 배경: 지금은 지금 중력과 같은 방향으로 밀어도 턴이 넘어가 새 공만 들어온다. 사용자 (2026-10-31) "방향 입력 할 때 이전에 입력한 방향을 그대로 유지는 못하게 막아줘"
- 앵커: `config/default_config.tres`·`config/GameConfig.gd`의 `allow_same_direction_swipe`, `scripts/core/TurnManager.gd` `on_swipe()`, `scripts/ui/TurnInputIndicator.gd` `_draw()`, `tests/test_config.gd` (기본값 true 확인), `tests/scenarios/test_turn_manager.gd`, `tests/spike/run_jolt_3d_measurement.gd` `DIRECTION_PATTERN`, 전략 봇 (`tests/tools/run_jelly_blast_measurement.ps1`이 쓰는 경로), JELLY 회귀 (`test_jelly_regression`)
- 수치: `allow_same_direction_swipe` true → false
- 요구:
  1. `allow_same_direction_swipe` true → false (판정은 지금 코드 그대로 — 지금 중력과 같으면 잠그지 않고 무시)
  2. 입력을 기다리는 동안 지금 중력 방향의 화살표·막힘 표시를 그리지 않는다. 같은 방향 입력에 새 소리·연출 없음
  3. 봇: 자동 플레이는 차례 방향이 지금 중력과 같으면 순서의 다음 방향, 전략 봇은 지금 방향을 후보에서 뺀다
  4. 테스트 (기본값에서): 같은 방향 입력은 턴·중력·생성이 그대로이고 입력 잠금도 안 걸림, 첫 턴 아래 막힘, FINAL MOVE에서도 막힘, 다른 세 방향은 지금처럼, 입력 대기 중 지금 방향 화살표 없음
  5. §12-ONE.17 측정 1·2
- 건드리지 말 것: 스와이프 판정 (4방향·거리·우세 비율), 중력 전환 (#118), 생성·규칙·점수·물리, 그림·연출 (화살표 하나 숨기기 말고는), 사용자 저장 파일, `docs/` (회신 파일 제외). 판 길이가 어떻게 나와도 값은 그대로 두고 보고한다
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 새 JELLY 기준 해시, 측정 표·캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-31 #123] 공 늘어나는 간격 5턴 → 10턴 — 완료
- 상태: 완료 (2026-10-31 Claude 검수 · [PR #122](https://github.com/jeongmo-dot/gravity_orb/pull/122) 병합 `3336886`)
- 검수: `spawn_count_ramp_turns` 10, 경계 테스트 1/1/2/2/3/5/6/10/11. 봇 20판 약 80 → 111.1턴 (99~124턴, 턴당 10~13개가 들어올 때 끝남), 점수 37.4만 (#119 60.5만), 턴당 합체 4.85, FINAL MOVE 성공 9.1%. JELLY 해시는 회귀 장면이 생성 램프와 무관해 그대로 (`ce7054b6…`). `65` 캡처는 91턴 `×10`. 래퍼 306/306 (Codex). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.16**
- 배경: #119부터 5턴마다 공이 1개씩 늘어 봇 기준 한 판이 약 80턴이다. 사용자 (2026-10-31) "들어오는 공의 수가 늘어나는 턴 기준도 5턴이 아니라 10턴 단위로 바꿔줘"
- 앵커: `config/default_config.tres`·`config/GameConfig.gd`의 `spawn_count_ramp_turns`, `tests/test_config.gd`·`tests/test_spawner.gd` (5턴 램프 확인), JELLY 회귀 (`test_jelly_regression`), 캡처 `65_jelly_preview_double_digit`
- 수치: `spawn_count_ramp_turns` 5 → 10 (상한 없음 그대로)
- 요구:
  1. `spawn_count_ramp_turns` 5 → 10
  2. 테스트: 1·10·11·20·21·50·51·100·101턴의 생성 수 1/1/2/2/3/5/6/10/11
  3. §12-ONE.16 측정 1·2 (새 해시, `65` 캡처는 91턴 이후로)
- 건드리지 말 것: 시작 배치, 색 해금, 크기 비율, 미리보기, 물리 값, 규칙·점수·대폭발, 사용자 저장 파일, `docs/` (회신 파일 제외). 판 길이가 어떻게 나와도 값은 그대로 두고 보고한다
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 새 JELLY 기준 해시, 측정 표·캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-31 #122] 미리보기를 판과 같은 크기로 — 완료
- 상태: 완료 (2026-10-31 Claude 검수 · [PR #121](https://github.com/jeongmo-dot/gravity_orb/pull/121) 병합 `6469966`)
- 검수: 미리보기 배율 = 판 투영 너비 ÷ `board_size` (개수와 무관), THEN 0.6배 삭제·알파 0.5 그대로, 칸이 모자라면 간격을 줄이고 그다음 겹침. 판 위와 NEXT·THEN의 L1·L2 화면 지름이 두 비율 모두 같다 (51.551 / 82.482px, 차이 0%). 해시 `ce7054b6…` 그대로, 래퍼 306/306 (Codex). Claude가 캡처 `66`·`70`을 직접 확인했다. 겹침은 명세와 달리 뒤 젤리가 위지만 일정해서 받아들임 (§12-ONE.15 결과). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.15**
- 배경: 미리보기가 칸에 맞춰 최대 2배로 커지고 개수에 따라 배율이 달라, NEXT의 L2가 판 위 L4처럼 보였다. 사용자 (2026-10-31) "이렇게 나오는데 L1, L2 만 들어온다고?" → 시안 A 선택, "A로 해줘. NEXT도 같은 크기로"
- 앵커: `scripts/ui/Hud.gd` `_render_preview()`·`PREVIEW_REGION_SIZE`·`PREVIEW_GAP`·`_projected_board_rect()`, `scenes/UI.tscn` `ThenPreview` (scale 0.6, modulate 알파 0.5)
- 수치: 미리보기 배율 = 판 투영 너비 ÷ `board_size` (고정, 개수와 무관). THEN 0.6배 → 1.0, 알파 0.5 그대로
- 요구:
  1. NEXT·THEN 젤리를 판 위 같은 레벨과 같은 화면 크기로 그린다. 창 크기·비율이 바뀌면 다시 계산
  2. THEN도 같은 크기, 흐림 그대로
  3. 칸이 모자라면 간격을 줄이고, 그래도 넘치면 크기는 그대로 겹쳐 놓는다 (배율을 줄이지 않는다)
  4. 테스트: 개수 1·2·5개에서 같은 레벨의 그린 크기가 같음, 배율이 판 투영과 같음, 넘칠 때 크기 그대로·칸 안
  5. 캡처 (두 비율): ① 판 위 L1·L2와 NEXT·THEN의 L1·L2가 한 화면에 (판 위와 미리보기 몸통 화면 지름을 픽셀로 재서 회신에) ② NEXT 1개·2개·5개 ③ THEN에 L2 5개 (겹침). 기존 미리보기 캡처는 다시 찍는다. 두 비율 전체 캡처 (마지막에)
- 건드리지 말 것: 미리보기 개수·`×n` 규칙, 미리보기 젤리 그림, 판·규칙·물리·생성, 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 판 위와 미리보기 크기 차이 5% 이내, JELLY 기준 해시 그대로, 캡처 보고, 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-31 #121] 공이 많을 때 느려짐 — 가볍게 — 완료
- 상태: 완료 (2026-10-31 Claude 검수 · [PR #120](https://github.com/jeongmo-dot/gravity_orb/pull/120) 병합 `12bf7a3`)
- 검수: 먼저 잰 결과 꽉 찬 판 + 입구 대기 16개에서 물리 스텝마다 스크립트가 12.3ms (예산 8.33ms)라 엔진이 스텝을 몰아 돌려 프레임 105ms, 게임 0.64배 속도였다 (기다리는 공 자리 찾기 6.9ms + 닿은 쌍 찾기 7.5ms). 결과가 같은 고침 (정수·`Vector2i` 키, 앞쪽 5칸, `can_react()`, 막는 구간, 프레임마다 한 번 모으기)으로 세 장면 모두 프레임 p99 4.3~5.6ms, 게임 1.00배. 해시 `ce7054b6…` 그대로, 봇 20판 20/20 같음, 같음 테스트 4개, 래퍼 304/304 (Codex). 합체가 몰리는 장면의 Jolt 한 스텝 4ms는 엔진 모니터 한계로 확인 못 함 (§12-ONE.14 결과). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.14**
- 배경: #119부터 판 끝 무렵 공이 약 120개가 되고, 판이 차면 들어오지 못한 공이 입구에서 기다린다. 사용자 (2026-10-31) "공이 많아졌을 때 화면을 채울 때 쯤 많이 느려지네, 좀 더 빠르고 가볍게 할 수 없을까"
- 앵커: `scripts/spike/Board3D.gd` `_update_entrance_waiters()`·`find_free_spawn_slot()`·`_update_ghost_orbs()`·`get_orbs()`·`blocked_spawn_directions()`, `scripts/core/CollisionResolver.gd` `flush()`·`_scan_geometric_contacts()`·`has_pending_reactions()`·`_current_reaction_partners()`, `scripts/core/TurnManager.gd` `_all_below_threshold()`, `scripts/core/ReactionRules.gd`
- 수치: 없음 (값을 바꾸지 않는다)
- 요구:
  1. 고치기 전에 실제 창에서 장면 ①~③을 잰다 (§12-ONE.14 방법 1). 위 앵커와 그리기 중 어디가 비싼지 항목별로
  2. 비싼 순서대로, 결과가 같은 고침만 한다 (JELLY 기준 해시 그대로). 결과가 바뀌어야만 되는 고침·물리 주기·그림 줄이기는 하지 않고 효과 추정과 함께 보고한다
  3. 목표: 장면 ①~③에서 물리 한 스텝 (스크립트 포함) p99 4ms 이하, 전체 프레임 p99 16.7ms 이하, 게임이 실제 시간보다 느려지지 않음. 못 미치면 남은 비용을 보고
  4. 테스트: 고친 함수마다 고치기 전과 같은 결과를 내는지 (기다리는 공 자리 찾기·닿은 쌍 찾기·반응 대기 판정·유령 해제)
  5. §12-ONE.14 측정 1~4
- 건드리지 말 것: 규칙·점수, 물리 값·물리 주기 (120Hz), #119 값, 그림·연출, 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), JELLY 기준 해시 그대로, 자동 플레이 20시드가 #119와 같음, 고치기 전·후 측정 표, 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-30 #119] 공이 빨리 늘어나게, 시작은 색마다 하나씩 — 완료
- 상태: 완료 (2026-10-31 Claude 검수 · [PR #119](https://github.com/jeongmo-dot/gravity_orb/pull/119) 병합 `5b77ece`)
- 검수: 램프 5턴, 시작은 4색 L1을 시드 RNG로 섞어 바닥에 같은 간격으로 놓는다 (`initial_orb_count`는 필드만 남음). 봇 20판 한 판 337 → 79.6턴 (72~87턴, 턴당 15~18개가 들어올 때 끝남), 점수 45.7만 → 60.5만, 턴당 합체 3.53 → 6.59, FINAL MOVE 성공 15% → 4.8% (§12-ONE.12 결과). 새 해시 `ce7054b6…`, 래퍼 300/300 (Codex). Claude가 캡처 `64`·`65` 두 비율을 직접 확인했다. 측정 도구의 물리 프레임 시간 (25.6 → 32.3ms)은 실제 게임 값이 아니어서 실제 창에서 다시 잰다 (→ 사용자가 느려짐을 알려 #121). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.12**
- 배경: 지금은 50턴마다 공이 1개씩 늘어나고, 무작위 구체 2개로 시작한다. 사용자 (2026-10-30) "첫번째 1개씩 5턴 그 다음부터 매 5턴 마다 공 한개씩 추가", "시작할 때 아래에 색깔별로 공 하나씩 배치된 상태로 시작"
- 앵커: `config/default_config.tres`·`config/GameConfig.gd`의 `spawn_count_ramp_turns`, `scripts/core/Spawner.gd` `spawn_initial()`
- 수치: `spawn_count_ramp_turns` 5 (상한 없음 그대로). 시작은 시작 색 (4색)마다 L1 하나씩
- 요구:
  1. `spawn_count_ramp_turns` 50 → 5
  2. 시작 배치: `color_count_for_turn(1)`의 색마다 L1 하나씩, 바닥 줄에 지금 `spawn_initial()`과 같은 간격으로 놓는다. 색 순서는 Spawner 시드 RNG로 섞는다. `initial_orb_count`는 쓰지 않는다 (필드를 지울지는 Codex 판단, 남기면 회신에 적는다)
  3. 테스트: 1·5·6·10·11·50·51·100턴의 생성 수 1/1/2/2/3/10/11/20, 시작 배치 (4개, 색이 모두 다름, 모두 L1, 바닥 줄), 같은 시드면 같은 시작 순서
  4. §12-ONE.12 측정 1~3
- 건드리지 말 것: 물리 값, 색 해금 턴, 크기 비율, 미리보기 개수·모양, 규칙·점수·FINAL MOVE, `stable_*`·`max_settle_time`, 그림·연출, 사용자 저장 파일, `docs/` (회신 파일 제외). 판이 너무 짧아져도 값은 그대로 두고 보고한다
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 새 JELLY 기준 해시, 측정 표·캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-30 #118] 90° 꺾을 때 대각선을 지나게 — 왼→아래와 오른→아래를 다르게 — 완료
- 상태: 완료 (2026-10-30 Claude 검수 · [PR #118](https://github.com/jeongmo-dot/gravity_orb/pull/118) 병합 `e8450cc`)
- 검수: 최종 방향과 실제 방향을 분리하고, 90° 꺾기만 0.15초 대각선 (정규화, 세기 같음)을 건다. 같은·반대 방향은 곧장 바꾸고, 전환 중에는 안정 시간을 쌓지 않는다. 공 하나가 234px 옆으로 휘고 왼→아래·오른→아래가 정확히 대칭이다. 더미 무게중심도 −84 / +107px로 갈린다 (0은 −59 / +69). 봇 20판은 337턴·점수 46만·턴당 합체 3.53으로 #117과 비슷하다 (§12-ONE.11 결과). 새 해시 `58e00b4b…`, 래퍼 299/299 (Codex). Claude가 캡처 `61`~`63`을 직접 확인했다. 남은 것: 최대 관통 38.3px (합체 직후). 대각선이 실제로는 17스텝일 수 있다 (`call_deferred` 끝내기, 체감 차이 없음). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.11**
- 배경: 지금은 스와이프하면 공의 중력이 그 프레임에 바로 새 방향이 되어, 왼→아래와 오른→아래가 같은 과정 (곧장 아래)을 거친다. 사용자 (2026-10-30) "8방향으로 늘려서 좌에서 하로 갈 때와 우에서 하로 갈 때가 다른 중력 변화 과정을 거치게", 반대 방향은 "곧장 뒤집기"
- 앵커: `scripts/spike/Board3D.gd` `set_gravity()`·`spawn_orb()`·`_update_entrance_waiters()`, `scripts/spike/Orb3D.gd` `set_gravity()`·`set_jelly_mass()` (`constant_force`에서 방향을 되찾는 부분)·`release_entrance_wait()`, `scripts/core/TurnManager.gd` `on_swipe()`·`_physics_process()` (안정 판정), `config/GameConfig.gd`·`config/default_config.tres`
- 수치: 새 필드 `gravity_turn_diagonal_time` 0.15 (초, 물리 프레임으로 셈, 0이면 지금과 같음). 나머지는 그대로
- 요구:
  1. 90° 꺾을 때 처음 0.15초 동안 공에 거는 중력을 두 방향 사이 대각선으로 한다 (세기는 곧은 방향과 같게 정규화). 그다음 최종 방향. 반대·같은 방향은 곧장
  2. 판은 최종 방향 (`_gravity_direction`, 4방향)과 따로, 공에 거는 실제 중력 방향을 갖는다. 전환 중에 새로 나온 공·합체로 커진 공·입구에서 풀려난 공도 그 순간의 실제 중력을 받는다
  3. 나머지 (`TurnManager.gravity`, 신호는 최종 방향으로 한 번, 입구·스폰 위치, 막힘·경고, FINAL MOVE, 띄우기 방향, 판 기울임, 중력장·테두리 빛, 배경 시차, HUD)는 최종 방향 그대로
  4. 전환이 끝나기 전에는 안정 판정을 쌓지 않는다. 1.5초 상한은 스와이프부터 (그대로)
  5. 테스트: 90° 꺾기 8가지 각각 (전환 중 대각선·세기 같음·끝나면 최종), 반대·같은 방향은 곧장, 전환 중 새로 나온 공, 최종 방향 기준 항목, 전환 중 턴이 끝나지 않음, 0이면 지금과 같음
  6. §12-ONE.11 측정 1~4 — 대각선 시간 0.1·0.15·0.25 각각과 지금 (0) 기준. 설정에는 0.15만 넣는다
- 건드리지 말 것: 중력·튕김·마찰·회전 감쇠, 스와이프 판정 (4방향), `JELLY_*`, 규칙·점수·난도, `stable_*`·`max_settle_time`, 색 효과 세기, 그림·연출 (새 연출 없음), CLASSIC (`scripts/core/Board.gd`), 사용자 저장 파일, `docs/` (회신 파일 제외). 0.15에서 너무 휘거나 덜 휘어도 값은 그대로 두고 보고한다
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 새 JELLY 기준 해시, 측정 표 (대각선 시간마다 한 줄)·캡처 보고 (새 캡처 3장, 마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-30 #117] 다시 구르게, 금방 멈추게 — 벽에 선 젤리 탑 없애기 — 완료
- 상태: 완료 (2026-10-30 Claude 검수 · [PR #117](https://github.com/jeongmo-dot/gravity_orb/pull/117) 병합 `ab4a7d8`)
- 검수: 회전 잠금 줄 삭제·`orb_angular_damp` 15만 바꿈. 밀린 L1이 30 px/s 아래까지 0.68초·125px (계산 0.7초·135px). 아래 중력 뒤 가장 긴 줄이 1초에 2 (회전 잠금은 10). 봇 20판 340턴·점수 48만·턴당 합체 3.49로 #115 전 수준 (§12-ONE.10 결과). 새 해시 `a1f64302…`, 래퍼 295/295 (Codex). Claude 캡처 `55`·`56` 두 비율 확인 — 벽 탑 없음. 남은 것: 1.5초 강제 안정 97.7%, 최대 관통 32.9px (합체 직후), 1 px/s 아래로 멈추지 않는 아주 느린 구름 (원인 미확인). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.10**
- 배경: #116 캡처 `55`에서 중력을 왼쪽 → 아래로 바꾼 뒤 왼쪽 벽에 L1 11개가 한 줄로 선 탑이 나왔다. 원인은 #115의 회전 잠금이다 (꼭대기에 얹힌 젤리가 굴러 떨어지지 못함). 사용자 (2026-10-30) "다시 구르게, 금방 멈추게"
- 앵커: `scripts/spike/Orb3D.gd` `setup()` (`axis_lock_angular_z`), `config/default_config.tres`·`config/GameConfig.gd`의 `orb_angular_damp`
- 수치: 회전 잠금 해제, `orb_angular_damp` 15.0. 나머지 (중력 3600·레벨 0.05·튕김 0.06·마찰 0.3)는 그대로
- 요구:
  1. JELLY 회전 잠금 해제 (#115 전처럼 평면 안에서 구른다). 잠금 테스트는 "잠금 없음"을 확인하는 테스트로 바꾼다
  2. `orb_angular_damp` 15.0
  3. §12-ONE.10 측정 1~5 — 회전 감쇠 5·15·30 각각과 지금 (회전 잠금) 기준. 설정에는 15만 넣는다
- 건드리지 말 것: 중력·튕김·마찰, 그림 (얼굴 똑바로·몸 회전 안 보임), `JELLY_*`, 규칙·점수·난도, `stable_*`·`max_settle_time`, 색 효과 세기, 다른 연출, 사용자 저장 파일, `docs/` (회신 파일 제외). 15에서 탑이 남아도 값은 그대로 두고 보고한다
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 새 JELLY 기준 해시, 측정 표 (회전 감쇠마다 한 줄)·캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-30 #116] 마찰 낮추기 — 덜 붙고 조금 퍼지게 — 완료
- 상태: 완료 (2026-10-30 Claude 검수 · [PR #116](https://github.com/jeongmo-dot/gravity_orb/pull/116) 병합 `fd53a87`)
- 검수: 마찰 두 값만 0.3. 마찰 0.15·0.3·0.45·0.6 측정 표 (§12-ONE.9 결과). 0.3은 0.6보다 판 길이 192 → 272턴, 점수 4.9만 → 26만, 턴당 합체 1.87 → 2.76. 쌓인 판 격자 ±10px 흐트림, 새 해시 `d1f7ca9a…`. 래퍼 295/295 (Codex). Claude 캡처 `55` 확인에서 왼쪽 벽에 L1 11개가 한 줄로 선 탑 발견 (회전 잠금 때문, 마찰 0.15에서도 남는 것으로 보임) → 사용자 결정 대기. 최대 관통 15.8px 남음. Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.9**
- 배경: #115 뒤 봇 20판에서 턴당 합체 −46%, 게임 오버까지 335 → 192턴, 점수 −89%. 젤리가 꼭대기에 31°까지 얹혀 있을 수 있다. 사용자 (2026-10-30) "마찰 낮추기"
- 앵커: `config/default_config.tres`·`config/GameConfig.gd` 기본값, `tests/` (쌓인 판 캡처·측정)
- 수치: `orb_friction` 0.3, `wall_friction` 0.3. 나머지 (#115의 중력·튕김·회전 잠금)는 그대로
- 요구:
  1. 위 값으로 바꾸기
  2. 쌓인 판 캡처·측정의 격자를 가로 ±10px 흐트려 떨어뜨리기 (고정 시드)
  3. §12-ONE.9 측정 1~5 — 마찰 0.15·0.3·0.45 각각 (쌓인 판은 0.6도). 설정에는 0.3만 넣는다
- 건드리지 말 것: 중력·튕김·회전 잠금, `JELLY_*`, 규칙·점수·난도 값, `stable_*`·`max_settle_time`, 색 효과 세기, 다른 연출, 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 새 JELLY 기준 해시, 측정 표 (마찰마다 한 줄)·캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-29 #115] JELLY 물리 — 단단한 구슬에서 젤리로 (더 빠르게·살짝만 튀게·구르지 않게) — 완료
- 상태: 완료 (2026-10-30 Claude 검수 · [PR #115](https://github.com/jeongmo-dot/gravity_orb/pull/115) 병합 `cf3630f`. 번호 #113·#114는 PR 번호와 겹쳐 건너뜀)
- 검수: 값 6개·젤리 회전 잠금만 바꿈. 떨어짐 L1 1.04 → 0.73초, 실제 튕김 0.25 → 0.12 (첫 튐 46 → 10px), 쌓인 더미 너비 960 → 437px, 관통 27.7 → 9.9px, 이탈 0, 색 효과 네 가지 모두 남음, 새 해시 `88cc180c…` (같은 시드로 7가지 사건). 대신 봇 20판에서 턴당 합체 −46%, 335 → 192턴, 점수 −89% → 난도는 사용자 플레이 뒤 결정. 래퍼 295/295 (Codex). Claude 캡처 직접 확인, 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.8**
- 배경: 사용자 (2026-10-29) 편집기 플레이에서 "물리 엔진이 좀 이상해" — 튕김·미끄러짐, 속도·무게감 (중력 바꿔 떨어질 때). JELLY 물리값이 모두 CLASSIC (M1) 그대로다. 튕김은 섞으면 0.25~0.30, 구체가 구르는데 그림은 돌지 않아 얼음처럼 미끄러져 보이고, L1이 판을 가로지르는 데 1.0초 걸린다
- 앵커: `config/default_config.tres`·`config/GameConfig.gd` 기본값, `scripts/spike/Orb3D.gd` `setup()` (회전 잠금)
- 수치: `gravity_strength` 3600, `gravity_level_scale` 0.05, `orb_bounce` 0.06, `wall_bounce` 0.06, `orb_friction` 0.6, `wall_friction` 0.6, 회전 잠금 (`axis_lock_angular_z = true` — 새 설정 필드 없음)
- 요구:
  1. 위 값으로 바꾸기
  2. 젤리 몸 회전 잠금
  3. §12-ONE.8 측정 1~8 (바꾸기 전 → 후)
- 건드리지 말 것: 젤리 말랑함 상수 (`JELLY_*`), 규칙·점수·흡수, `orb_linear_damp`·`stable_*`·`max_settle_time`, 색 효과 세기, 다른 연출, 사용자 저장 파일, `docs/` (회신 파일 제외). 측정 2의 튕김 비율이 0.12 ± 0.03을 벗어나도 값은 그대로 두고 보고한다
- Done-when: 테스트 통과 (`.\tests\run_tests.ps1`), 새 JELLY 기준 해시 (같은 조건을 모두 지나는 시드), 측정·캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-26 #112] 호령·점수 팝업을 얼굴 밖으로 · 배경 유성 삭제 — 완료
- 상태: 완료 (2026-10-27 Claude 검수 · [PR #114](https://github.com/jeongmo-dot/gravity_orb/pull/114) 병합 `c93b468`)
- 검수: 호령 얼굴·보드 겹침 0 (두 비율, 캡처 다섯 단계 직접 확인), 팝업 70%·젤리 옆, 유성 삭제 (`meteor` 0건). 붐비는 판에서 팝업이 옆 얼굴을 덮는 것 (최대 100%·0.892초)은 사용자 "지금처럼 두기". 래퍼 294/294, 해시 그대로 (Codex). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE.7**
- 배경: #108 측정 — 붐비는 판에서 호령·점수 팝업이 젤리 얼굴을 최대 100%·1초 중 0.908초 덮음. 사용자 (2026-10-26) "보드 밖 위쪽으로 옮기기". 배경 유성 (`SpaceBackdrop.gd` `meteor`) → 사용자 "없애기"
- 요구:
  1. 호령을 보드 밖 위쪽 — 콤보 표시 아래와 보드 위쪽 가장자리 사이 빈 공간 가운데, 보드·HUD·콤보와 겹치지 않게 글자 크기를 그 공간에 맞춤 (두 비율). 생김새·소리·조건 그대로
  2. 점수 팝업은 합쳐진 젤리 옆에 작게 — 글자 70%, 오른쪽 (`r + 12px`) 먼저, 보드 밖·다른 얼굴을 더 덮으면 왼쪽·위·아래 중 얼굴을 가장 적게 덮는 쪽. 시간·움직임 그대로
  3. 배경 유성 코드째 삭제 (나머지 배경 그대로)
- 검수: 겹침 측정 다시 (호령 ↔ 얼굴·보드 0, 팝업 ↔ 얼굴 비율·시간), 캡처 두 비율 (호령 단계별, 팝업 작은 것·큰 것, 붐비는 판), 소스 `meteor` 0, 테스트, 해시 그대로 (`2891601…`)
- 건드리지 말 것: 규칙·점수 계산·호령 조건·소리, 다른 연출, 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과(`.\tests\run_tests.ps1`), 측정·캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-25 #108] JELLY 테스트·캡처 되살리기 + 검수 빈틈 메우기 — 완료
- 상태: 완료 (2026-10-27 Claude 검수 · [PR #113](https://github.com/jeongmo-dot/gravity_orb/pull/113) 병합 `a7625d4`)
- 검수: 호령 테스트 5개 (성능 5/5)·캡처 31장 (두 비율 56장)·JELLY 기준 해시 `2891601…` (흡수·대폭발·L7 먹기·잭팟·FINAL MOVE 성공/실패를 모두 지나는 시드 `1085050`)·`ObjectDB` 경고 0·호령/팝업 겹침 측정 (최대 100%·0.908초 → #112)·흰 줄 = 배경 유성 (→ #112)·회신 #100 이하 보관 (Claude 확인 빠진 줄 0)·빌드 보존 검사. 추가 요구 1 — 착지 띠·쌓인 판·오른쪽 중력을 실제 물리로 (Claude 캡처 직접 확인). 래퍼 293/293 (Codex). Claude 재실행 없음
- 1차 상태: 추가 요구 1 (2026-10-26)
- 추가 요구 1: [technical_design.md](technical_design.md) §12-ONE "#108 1차 결과" — 8가지는 좋다. 움직임 캡처가 이름과 내용이 다르다: `44~53` 착지 띠 10장이 모두 같은 동그란 젤리, `55` 쌓인 판·`56` 오른쪽 중력은 공중 격자
  1. 착지 띠 — 실제 중력으로 떨어뜨려 (턴 진행 중) 떨어짐·착지·돌아옴 10장, 장마다 몸통 가로·세로 배율을 회신에
  2. 쌓인 판 — 실제로 떨어뜨려 바닥·벽·구석까지 맞닿은 더미
  3. 오른쪽 중력 — 쌓인 더미에서 중력을 바꾼 뒤 움직이는 도중
  4. 캡처 검사가 "장마다 다름"·"실제 접촉 쌍 수"를 확인
- 근거: [technical_design.md](technical_design.md) §12-ONE "#106 결과"
- 배경 (Claude 검수, PR #108): `tests/test_callouts.gd`를 통째로 지워 BLITZ가 아닌 테스트까지 사라졌고, 캡처가 105장 → 12장으로 줄며 JELLY 장면도 빠졌다. 레거시 원본은 태그 `legacy-four-modes`에 있다. 4~8번은 2026-10-25 인박스 전체 점검 ([technical_design.md](technical_design.md) §12-ONE.5)에서 나온 검수 빈틈
- 요구:
  1. `test_callouts.gd`의 BLITZ가 아닌 테스트를 JELLY로 되살린다 — 새 젤리 미리보기·안내가 젤리 그림·이름을 쓰는지, 턴 호령이 한 연쇄에 한 번, 효과음 음소거·호령 음높이, 호령 끄기 + 상태 해시 보존, 호령 프레임 비용 (성능 시험 4 → 5)
  2. 캡처에 JELLY 장면을 되살린다 (태그의 같은 이름 장면을 JELLY로): 설정 (`19_settings`), 기록 없는 시작 화면 (`20_start_no_record`), 중력 전환·위험·막힘 (`16`·`17`·`18`), 입력 표시 준비·계산·거절 (`44`·`45`·`46`), 호령·점수 팝업 (`30`·`31`·`32`·`33`), `53_jelly_look_*` (레벨 나란히·붐비는 판·MAX·늘어남·흡수·새 젤리 안내), `55_jelly_motion_*` (착지 띠·숨쉬기 최고점·쌓인 판·오른쪽). 번호는 새로 매겨도 된다 — 목록과 옛 이름 대응표를 회신에
  3. BLITZ·SLIME·CLASSIC 행성 전용 장면은 되살리지 않는다
  4. **JELLY 회귀 기준 해시를 새로 정한다** — 지금 JELLY 해시 (`5c96a80c…`, 그림 켠·끈)는 #101~#109 내내 같았다. #104에서 크기 (물리)가 바뀌었는데도 그대로라 흡수·대폭발·FINAL MOVE를 지나지 않는 장면이다. 흡수 (레벨 그대로·레벨 오름)·대폭발 (L5부터)·FINAL MOVE (성공·실패)·L7이 L6 먹기를 모두 지나는 고정 시드 판의 마지막 상태 해시를 기준값으로 테스트에 넣고 (그림 켠·끈 같음), 지나간 사건 수와 함께 회신에 적는다
  5. **캡처 끝 `ObjectDB instances leaked` 경고** (#95·#98 회신에 4건, 그 뒤 처리 안 됨) — 지금도 나오는지, 원인, 테스트·캡처 코드 쪽이면 고친다. 런타임 쪽이면 원인만 보고
  6. **호령·점수 팝업이 젤리 얼굴을 덮는지 잰다** — `57_jelly_full_eat_02` 캡처에서 "NICE!"가 젤리 얼굴을 덮는다. 붐비는 판에서 호령·팝업이 뜰 때 젤리 얼굴과 겹치는 비율·시간을 재서 보고만 한다 (위치·크기는 바꾸지 않는다 — 결정은 사용자)
  7. `57_jelly_full_right` 캡처 보드 왼쪽의 흰 줄이 무엇인지 보고 (배경 연출이면 그 이름)
  8. **회신 파일 정리** — `jeongmo_codex_to_claude.md`의 #100 이하 회신을 `docs/archive/codex_to_claude_001-100.md`로 그대로 옮긴다 (Codex 파일이라 Codex가 한다)
  9. **사라진 이전 빌드 파일** — `build/windows/`에서 0.11.1·0.13.0·0.13.1·0.14.0 파일 (0.13.1.zip 포함 13개)이 없다. #100 회신 (10-24)에는 "유지"였고 #103 회신 (10-25)부터는 0.15.x만 적혔다. 그 사이 어떤 명령이 지웠는지 (빌드 스크립트·정리 명령·`git clean` 등) 찾아 보고하고, 같은 일이 다시 없게 막는다 (빌드 스크립트가 다른 버전 파일을 지우지 않음을 확인하는 테스트, 작업 중 `build/`를 지우는 정리 명령 금지). 다시 만들지는 말 것 — 필요하면 Claude가 따로 항목으로 낸다
- 검수: 래퍼 통과 (성능 5/5), 되살린 테스트 이름 목록, 캡처 두 비율 전체 (Claude가 직접 본다), 새 JELLY 기준 해시와 지나간 사건 수, `ObjectDB` 경고 결과, 호령·팝업 겹침 측정, 흰 줄 정체, 회신 파일 보관 결과, 사라진 빌드 파일 경위와 막는 장치
- 건드리지 말 것: 런타임 코드·수치 (테스트·캡처 도구만 — 5번이 런타임이면 보고만), 사용자 저장 파일, `docs/` (회신 파일과 8번 보관 파일 제외)
- Done-when: 테스트 통과(`.\tests\run_tests.ps1`), 캡처 보고 (마지막은 전체 캡처)
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-26 #111] 가장자리 젤리의 어두운 테두리 — 후보를 하나씩 꺼서 원인 찾고 고치기 — 완료
- 상태: 완료 (2026-10-26 Claude 검수 · [PR #112](https://github.com/jeongmo-dot/gravity_orb/pull/112) 병합 `9e546c6`)
- 검수: 원인 (보드 유리판 그리기 순서 + 몸통 그림자, 둘 다 원근으로 끝·구석에서만) 분리 표, 그림자 끔 (설정 0건), 아홉 자리 띠 0, 늘어남 축 기울어짐 버그 (최대 84~90°) 고침, 판 어긋남 0. 추가 요구 1 — 볼·배 속 젤리·MAX 반짝임 복구 (그리기 순서 10~14), 배 속 젤리만 부드럽게 회전. 래퍼 286/286, 해시 그대로 (Codex). Claude 캡처 직접 확인. Claude 재실행 없음
- 1차 상태: 추가 요구 1 (2026-10-26)
- 근거: [technical_design.md](technical_design.md) **§12-ONE.6**
- 추가 요구 1: §12-ONE.6 "#111 1차 결과" — 원인 분리·그림자 끔·띠 0은 좋다. 그런데 몸통만 `render_priority = 10`이라 **볼·배 속 젤리가 몸통에 덮여 사라졌다** (`06_jelly_blast_down`·`08_jelly_full_down`)
  1. 배 속·얼굴·문양 재질을 몸통보다 나중에 (예: 11·12·13), 볼·배 속 젤리 픽셀 확인 (노랑 L5 볼 `(247,133,126)` ±12 등)
  2. 몸통 앞에 보여야 할 연출이 덮이지 않는지 확인 (덮이면 그 재질도 나중에)
  3. 배 속 젤리 위치는 예전처럼 부드럽게 (`delta × 8`) — 늘어남 축만 즉시
  4. 1차 측정 다시·캡처 두 비율 전체 (볼·배 속·연출 확대 포함)
- 배경: 사용자 (2026-10-26, #110 뒤 편집기 실행) — 구석 초록 젤리 둘레 어두운 고리 스크린샷, "시작부터 만들어저 있어", "공을 좌우로 보내면 좌우 끝에서 고리가 보이고, 가운데서는 안보이는게 그림자 처럼 느껴져". 고리 연출 코드는 #110에서 다 지웠다 → 연출이 아니라 자리 (좌우 끝·구석)에 따라 생기는 렌더링 문제. Codex 캡처 `55_jelly_motion_rest`에서도 왼쪽 끝 젤리만 바깥쪽 어두운 테두리
- 요구:
  1. **재현**: 그림을 켠 실제 창 (편집기 또는 Debug 빌드, 두 비율)에서 같은 레벨·색의 젤리를 보드 **왼쪽 끝·가운데·오른쪽 끝·네 구석**에 각각 놓고 (정지·턴 입력 대기), 몸통 바깥 `1.0r~1.3r` 띠와 몸통 안쪽 `0.7r~1.0r` 띠의 픽셀을 잰다 (배경·몸통 색과 비교). 끝·구석에서 띠가 생기고 가운데에서 없는지 먼저 확인
  2. **후보를 하나씩 꺼서 비교** (§12-ONE.6 후보 1~5): ① 보드 `Backing`·`GravityField` 숨김 ② 젤리 몸통 재질을 불투명으로 (알파 1) 또는 반투명 그리기 순위 (`render_priority`)를 판보다 뒤로 ③ `KeyLight` 그림자 끔·젤리 `cast_shadow` 끔 ④ 벽 `InnerGlow`·`OuterGlow` 숨김 ⑤ 얼굴·배 속 판 숨김 ⑥ 카메라를 직교 (orthographic)로 바꿔 보기 (원근 탓인지 가르는 시험 — 고침이 아니라 진단). 어느 것을 끌 때 띠가 사라지는지 표로
  3. **그림자는 원인이든 아니든 끈다** — 사용자 (2026-10-26) "그런데 나는 그런 그림자를 그리라고 한 적이 없어". `Main3D.tscn` `KeyLight` `shadow_enabled = false`, `Orb3D.tscn` `Mesh`를 비롯한 모든 메시 `cast_shadow` 끔 (그림자는 #20에서 들어온 것). 2번 비교는 그림자를 켠 채·끈 채 둘 다 적는다
  4. **고치기**: 원인을 없앤다. 젤리 그림·보드 그림의 생김새는 바꾸지 않는다 (가장자리 반투명·유리판·중력장·빛 띠는 그대로 두고, 그리기 순서·깊이·그림자 설정 등으로). 생김새를 바꿔야만 고쳐지면 고치지 말고 후보와 전·후 캡처를 보고 (사용자 결정 — 그림자 끄기는 이미 결정됨)
  6. **움직이는 동안 원 → 타원 검사** — 사용자 (2026-10-26) "위아래, 좌우로 움직이는 동안 공의 형태도 원에서 타원으로 변하는 게 있어. 그것도 같이 검사해". 실제 창 (두 비율)에서 젤리를 위·아래·왼쪽·오른쪽으로 보내며 (가운데·끝 둘 다) 프레임마다 화면에 그려진 몸통 윤곽의 긴 축·짧은 축·기울기를 재고, 원인별로 나눠 표로: ① 의도된 말랑함 (중력 쪽 늘어남 최대 19%·부딪힘 가로 18%·숨쉬기·부풀기) ② 원근 왜곡 (같은 젤리를 가운데·끝에 정지해 둔 차이) ③ 중력이 바뀔 때 틀이 도는 동안 비스듬한 늘어남 ④ 몸통·얼굴·배 속 판 어긋남. ②~④처럼 의도하지 않은 것은 고친다. ①은 바꾸지 말고 최대·평균·지속 시간만 보고 (사용자 결정)
  7. **원칙** — 사용자 (2026-10-26) "늘어나더라도 공이 늘어나야지. 저렇게 그림자가 생기거나 다른 외곽선이 생기는 것은 전혀 예뻐보이지 않아". 늘어나고 찌그러지는 것은 공 자체 (몸통·얼굴·배 속 젤리가 함께)만이다. 공 바깥에 생기는 어두운 띠·그림자·외곽선은 원인을 찾아 모두 없앤다. 젤리 몸통 셰이더의 가장자리 밝힘 (`rim` 항)이 외곽선처럼 보이는지는 고치지 말고 켠·끈 확대 캡처 (가운데·끝, 정지·움직임)만 보고 (사용자에게 보여 결정)
  8. 고친 뒤 1번 재현을 다시 — 끝·구석·가운데 모두 띠 0, 그림자 설정 0건 (소스 검색 `shadow_enabled = true`·`cast_shadow = 1`·`SHADOW_CASTING_SETTING_ON` 0)
- 검수: 1번 표 (자리별 띠 픽셀), 2번 표 (후보별 사라짐 여부), 6번 표 (원인별 타원 정도·지속 시간), 7번 가장자리 밝힘 켠·끈 캡처, 원인·코드 위치, 전·후 캡처 (끝·구석·가운데, 두 비율, 확대), 다시 생기지 않게 하는 테스트, 해시 그대로
- 건드리지 말 것: 규칙·물리·수치, 젤리·보드 생김새 (3번 참고), 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과(`.\tests\run_tests.ps1`), 재현·후보 표·고친 뒤 0 보고, 캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-25 #107] Windows 빌드 0.16.0 — JELLY 단일 앱 첫 빌드 — 완료
- 상태: 완료 (2026-10-26 Claude 검수 · [PR #111](https://github.com/jeongmo-dot/gravity_orb/pull/111) 병합 `cad9727`)
- 검수: `build/windows/GravityOrb_v0.16.0.exe` (111,069,840바이트) + `.console.exe` + `_BUILD.txt` (커밋 `75ef9fc` = 브랜치 끝, 커밋 10초 뒤 빌드, 코드는 main과 같음) 직접 확인. 스모크 2종·내보낸 Release GPU 프레임 (시작 화면·`--mode=jelly`)·사용자 `save.cfg` 해시 동일·묶음에 BLITZ·SLIME 흔적 0·래퍼 284/284 (Codex). 시작 화면 JELLY 버튼 실제 클릭은 이번에도 자동화 실패. **0.14.0 이전 빌드 파일이 사라진 것을 발견** (회신의 "이전 버전 유지"는 0.15.x만) → #108 9번. Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§10.5·§10.5.1** (버전 기록 0.16.0 줄), §12-ONE
- 요구:
  1. 버전은 **`0.16.0` 그대로** (#106에서 이미 올림 — 바꾸지 않는다)
  2. 깨끗한 작업 트리에서 릴리스 빌드 `.\tools\build_windows.ps1` → `build/windows/GravityOrb_v0.16.0.exe` + `.console.exe` + `_BUILD.txt`. 이전 버전 파일 (0.15.2 — 네 모드 보관본 포함)은 남긴다
  3. 내보낸 콘솔 exe로 스모크 2종 (기본·jelly) 종료 코드 0·`SCRIPT ERROR` 0
  4. 격리 창에서 시작 화면·JELLY 직접 실행 확인 (실제 클릭이 안 되면 그 사실과 대신 확인한 방법)
- 검수: 빌드 결과 줄·파일 크기, `_BUILD.txt` 커밋 = 이 브랜치 마지막 커밋, 사용자 `save.cfg` 해시 전후 동일, 묶음에 `tests/`·`artifacts/`·`docs/`·BLITZ·SLIME 문자열 없음, 래퍼 통과
- 건드리지 말 것: 모든 파일 (회신 파일 제외), 사용자 저장 파일, 다른 버전 빌드 파일
- Done-when: 위 검수 보고
- 커밋: 항목 단위 브랜치 (`build-0.16.0`), **push·PR까지** (바뀐 파일이 회신뿐이어도 PR)

### [2026-10-25 #110] 고리 연출·그림 전부 삭제 — 다시 쓰지 않는다 — 완료
- 상태: 완료 (2026-10-26 Claude 검수 · [PR #110](https://github.com/jeongmo-dot/gravity_orb/pull/110) 병합 `3e80e1d`)
- 검수: 고리 코드 0건, 실제 창 측정 — 삭제 전 고리는 매 턴 새로 생겨 남아 보였고 몸통이 물리보다 작게 그려져 빈틈 (최대 14px)이 있었다 → 고친 뒤 빈틈 0·고리 0. 추가 요구 1 (말랑함 유지·작아지지 않게, 부풀기 1.0 → 1.06 → 1.0, 별가루 무작위) 반영. 겹침 최대 40.8px·약 1.27초 (떨어질 때 늘어남 19% — #101부터 있던 것). 래퍼 284/284, 해시 그대로 (Codex). Claude 재실행 없음
- 1차 상태: 추가 요구 1 (2026-10-25)
- 추가 요구 1: [technical_design.md](technical_design.md) §12-ONE "#110 1차 결과" 1~6 — 고리 삭제·측정은 좋다. 그런데 빈틈을 없애려고 JELLY 몸통 배율을 늘 1로 둔 것은 명세에 없는 디자인 변경 (말랑함이 사라짐) → 사용자 "말랑함 유지, 작아지지만 않게". 흡수 때 색 효과 별가루 12개가 같은 간격 원 (점선 고리) → 사용자 "무작위로 흩어지게"
  1. 몸통 그림 배율을 축마다 `max(1, 변형값)` (늘어남·넓어짐은 그대로, 줄어듦은 1로, 숨쉬기도, z도)
  2. 합체 부풀기: 0.88 → 1 대신 **1.0 → 1.06 (0.08초) → 1.0 (0.10초)**
  3. 얼굴·배 속 젤리는 몸통과 같은 배율 (얼굴은 똑바로, z는 몸통 앞면 기준)
  4. 9번 측정 다시 — 빈틈 0, 겹침 최대·지속 시간 보고 (부딪힐 때 잠깐 눌려 겹치는 것은 의도)
  5. 색 효과 별가루: 방향 0~360° 무작위·거리 0.6~1.0·속도 0.7~1.0 무작위 (효과마다 씨앗을 둔 지역 난수, 전역 난수 금지, 해시 그대로)
  6. 캡처 다시 — 착지 띠·흡수/합체 순간·붐비는 쉬는 판, 두 비율
- 근거: [technical_design.md](technical_design.md) **§12-ONE.4**
- 배경: 사용자 (2026-10-25) "완전히 삭제하고 다시 사용하지 마", "다 지워", "고리를 그리는 거 다 지워" — #109에서 JELLY의 `ModeRing`만 끈 것으로 끝내지 않고, 고리를 그리는 코드를 모두 지운다
- 요구 (코드째 삭제 — 숨기기·끄기 아님):
  1. `ColorEffectVisual`의 `ModeRing` — 노드·`TorusMesh`·재질·`ring_layer_count`·`set_ring_enabled`·빨강 밀기 두께 분기. 색 효과 별가루 (`ModeStardust`)·보드 흔들림·당김 펀치·물리 효과는 그대로
  2. `FeedbackDirector`의 고리 연출 전부 — `_create_ring`·`_new_ring_node`·`_blast_ring_mesh`·"ring" 풀·그룹·`active_ring_count`와 모든 호출 (합체 고리 대체 경로, CLASSIC 합체 고리, 탄생 고리, JELLY MAX 흰 고리, 대폭발·잭팟 충격파 고리 두 겹). 같은 연출의 별가루·빛·섬광·흔들림·멈칫은 그대로
  3. 연출 빛 셰이더 (`_new_effect_glow_shader`)의 고리 띠 `shell`·`rim` — 부드러운 구름만 남긴다 (흡수 잔상·탄생 빛 등이 테두리 고리 원판으로 보이지 않게)
  4. 행성 고리 — `CelestialOrbArt` 고리 장식 (`has_adornment`·`RING_TILT_RADIANS`·고리 셰이더), `OrbVisual._draw_planet_ring`·`_draw_tilted_atmosphere_ring`, `Orb3D`의 `Adornment` 노드
  5. `BlastOutline` 고리 셰이더와 노드 (CLASSIC·BLITZ용 대폭발 가능 고리 — JELLY는 이미 숨김)
  6. 아무도 쓰지 않는 `scripts/ui/CosmicRing2D.gd`
  7. 시작 화면 `OrbitStage`의 궤도 선 (타원 두 줄) — 도는 작은 천체는 그대로, 선만 지운다
  8. 이 고리들만 확인하던 테스트·캡처 검사는 지우고, 대신 다시 생기지 않게 하는 테스트를 넣는다
  9. **고리가 차지하던 공간 확인 (삭제 전에 먼저)** — 사용자: "이미 그 만큼 다 공간을 잡아먹고 있고 몇턴씩 남아있는데?". #109의 "0.3~0.4초 연출" 설명은 이 두 관찰과 맞지 않는다. #109 이전 코드 (`9157b6c`)로 그림을 켠 실제 창에서 흡수·합체 뒤 5턴 이상을 보며 ① 고리가 몇 프레임·몇 턴 남는지 (남는다면 왜 — 어떤 노드가 왜 안 사라지는지) ② 모든 젤리의 **물리 충돌 반지름** (`SphereShape3D.radius`)과 **그린 몸통 반지름** (메시 반지름 × 배율)을 프레임마다 기록해 1px 넘게 다른 젤리·기간 ③ 맞닿은 이웃 두 젤리의 중심 거리와 그린 반지름 합의 차이 (빈틈) 를 잰다. 물리가 그림보다 크거나 빈틈이 있으면 원인을 고친다 (그림 = 물리). 이 PR 뒤 같은 측정에서 차이 0·빈틈 0
- 검수: 9번 측정 보고 (전: 고리 지속 시간·원인, 물리·그림 반지름 차이·빈틈 / 후: 0), 소스 검색 `TorusMesh`·`_create_ring`·`ModeRing`·`draw_arc`·`Adornment`·`BlastOutline` 0건 (남는 것이 있으면 이유), 테스트 (합체·흡수·대폭발·잭팟·MAX 직후 씬 트리에 고리 노드·`TorusMesh` 0), #109 실제 창 고리 측정 0, 캡처 두 비율 (합체·흡수·대폭발·잭팟·MAX 순간, 시작 화면), 모든 해시 그대로 (그림만 바뀜)
- 건드리지 말 것: 규칙·물리·수치, 고리가 아닌 연출 (§12-ONE.4 "남기는 것"), 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과(`.\tests\run_tests.ps1`), 캡처 보고 (마지막은 전체 캡처), 스모크 2종 (기본·jelly), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-25 #109] JELLY 젤리 둘레 반투명 고리 — 원인 찾고 고치기 (다시) — 완료
- 상태: 완료 (2026-10-25 Claude 검수 · [PR #109](https://github.com/jeongmo-dot/gravity_orb/pull/109) 병합 `f440d10`)
- 검수: 원인 `ColorEffectVisual/ModeRing` (실제 창 후보 숨김으로 확인), JELLY에서 그 고리만 끔. 고리 영역 픽셀 8,120 → 0 (합체·흡수 20번 + 턴 60번), 전·후 캡처 `jelly_halo_post/*/case_01_before·after` 직접 확인. 래퍼 283/283, JELLY 해시 그대로 (Codex). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-JE.10** (앞선 조사 §12-JE.9 4번·"#104 결과")
- 배경: 사용자 (2026-10-25, 편집기에서 main 실행) "합쳐진 이후로 이 다음 커질 상태가 미리 나오는 것 같은데" + 스크린샷 — 젤리 둘레에 제 색 × 약 0.22 고리가 약 1.2r까지 (Claude 픽셀 분석). 빛 판은 #104부터 숨김인데도 나온다 → 원인은 다른 노드
- 요구:
  1. **그림을 켠 실제 창**에서 재현한다 (편집기 또는 Debug 빌드, 기본 창 크기, 실제 턴 진행 — 봇 입력 가능, 흡수·합체 뒤 3턴). 그림 `_process`를 끈 측정으로는 안 된다
  2. 고리가 보이는 프레임에서 후보를 하나씩 숨겨 원인 노드를 찾는다 (§12-JE.10 후보 목록). 노드·코드 위치·왜 그 크기·투명도로 몇 턴 남는지 보고
  3. 원인을 없앤다. 고친 뒤 같은 재현에서 고리 0회 (흡수·합체 뒤 3턴 × 20번 이상, 고리 영역 픽셀 검사)
- 검수: 원인 보고, 같은 장면 전·후 캡처 (두 비율), 픽셀 검사 결과 (전: 고리 있음 / 후: 0회), 다시 남지 않게 하는 테스트, JELLY 해시 그대로
- 건드리지 말 것: 규칙·물리·수치, 다른 그림 (원인 노드 말고), 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과(`.\tests\run_tests.ps1`), 재현·원인·고친 뒤 0회 보고, 캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-25 #106] JELLY 단일 앱 — 다른 모드는 레거시 (태그) — 완료
- 상태: 완료 (2026-10-25 Claude 검수 · [PR #108](https://github.com/jeongmo-dot/gravity_orb/pull/108) 병합 `9157b6c`)
- 검수: Codex 캡처 `01_jelly_start` 두 비율·`02_jelly_ranking`·`03_jelly_result` — 큰 JELLY 버튼 하나·랭킹 JELLY 하나·"처음 화면". 삭제 76개 파일·런타임 삭제 함수는 BLITZ·SLIME 전용 확인. 래퍼 282/282, JELLY 해시 그대로, 묶음 문자열 검사·저장 파일 불변 (Codex). JELLY 테스트·캡처가 함께 지워진 것은 #108. Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-ONE** (기획서 0.16)
- 배경: 사용자 (2026-10-25) "일단 이 버전을 킵 하고, 젤리 모드 외에는 모두 레거시로 보관해줘. 지금 이후 부터는 젤리 모드 하나만 잡고 개선하자" → 태그로 보관·main은 JELLY만, 시작 화면은 큰 시작 버튼 하나
- 요구 (§12-ONE.2):
  1. BLITZ·SLIME을 main에서 지운다 — 코드·씬·HUD·설정 필드·`config/slime_config.tres`·테스트·캡처 장면·측정 도구 (지운 파일 목록 보고)
  2. CLASSIC은 고를 수 없게 (시작 카드·랭킹 탭·실행 인자 없음). CLASSIC 규칙·턴·물리·반응·생성 코드와 공통 경로 회귀 테스트는 남긴다 (정리는 다음 항목)
  3. `GameMode` 값 그대로 (JELLY = 3), 쓰지 않는 값은 레거시 주석. 앱은 늘 JELLY, `--mode`는 없거나 `jelly`만
  4. 시작 화면: 로고 그대로 + 큰 JELLY 시작 버튼 하나 (위 두 카드 + 간격 너비, 높이 200, L3 분홍 젤리 얼굴·"JELLY"·"작은 것도 먹고 자라요"·BEST·`#FF7595`) + 아이콘 줄 (랭킹·소리·설정)
  5. 랭킹은 JELLY 하나 (탭 없음). 결과 화면 "모드 선택" → "처음 화면"
  6. 사용자 저장 파일의 다른 모드 기록·키는 지우지도 바꾸지도 않는다
  7. `docs/.gdignore` (빈 파일)를 만든다 — Godot가 `docs/mockups/*.png`를 가져와 `*.png.import`가 생기는 것을 막는다 (`docs/` 안에서 이 파일만 예외로 만든다)
- 검수: 테스트 통과, JELLY 해시 그대로 (그림 켠·끈, #104 뒤 기준), 캡처 두 비율 (시작 화면·랭킹·결과 + JELLY 장면 전체), 사용자 저장 파일 바이트 불변, 내보낸 묶음에 BLITZ·SLIME 흔적 없음 (문자열 검사), 지운 파일 목록
- 건드리지 말 것: JELLY 규칙·물리·그림·수치, 사용자 저장 파일, 이전 버전 빌드 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과(`.\tests\run_tests.ps1`), 캡처 보고 (마지막은 전체 캡처), 스모크 2종 (기본·jelly), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-25 #105] Windows 빌드 0.15.2 — 완료
- 상태: 완료 (2026-10-25 Claude 검수 · [PR #107](https://github.com/jeongmo-dot/gravity_orb/pull/107) 병합 `4271f88`, 태그 `legacy-four-modes`)
- 검수: `build/windows/GravityOrb_v0.15.2.exe` (111,221,024바이트) + `.console.exe` + `_BUILD.txt` (커밋 `a9f9a35` = 브랜치 끝, 커밋 38초 뒤 빌드, 코드는 main과 같고 다른 것은 버전 한 줄) 직접 확인. 스모크 5종·격리 창·사용자 `save.cfg` 해시 동일·묶음 검사·래퍼 381/381·0.15.0·0.15.1 파일 유지 (Codex). 시작 화면 → JELLY 실제 클릭은 자동화 못 함. Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§10.5·§10.5.1** (버전 기록 0.15.2 줄)
- 배경: 0.15.1 플레이 뒤 JELLY 크기 레벨 고정·배 속 젤리·뒤 빛 삭제 (#104) — 사용자가 직접 확인할 빌드 (어두운 띠가 다시 나오는지도). **네 모드가 들어간 마지막 버전** — 병합 뒤 Claude가 태그 `legacy-four-modes` (§12-ONE.1)
- 요구:
  1. `project.godot` `application/config/version` `0.15.1` → **`0.15.2`** (Claude 결정 값 — 기획서 0.15.2, PATCH +1)
  2. 버전을 커밋한 뒤 **깨끗한 작업 트리에서** 릴리스 빌드 `.\tools\build_windows.ps1` → `build/windows/GravityOrb_v0.15.2.exe` + `.console.exe` + `_BUILD.txt`. 다른 버전 파일은 남긴다
  3. 내보낸 콘솔 exe로 스모크 5종 (기본·turn·blitz·slime·jelly) 종료 코드 0·`SCRIPT ERROR` 0
  4. 격리 창에서 시작 화면·JELLY 직접 실행 확인 (실제 클릭이 안 되면 그 사실과 대신 확인한 방법)
- 검수: 빌드 결과 줄·파일 크기, `_BUILD.txt` 커밋 = 이 브랜치 마지막 커밋, 사용자 `save.cfg` 해시 전후 동일, 묶음에 `tests/`·`artifacts/`·`docs/` 없음, 래퍼 통과
- 건드리지 말 것: 버전 외 모든 파일, 사용자 저장 파일, 다른 버전 빌드 파일, `docs/` (회신 파일 제외)
- Done-when: 위 검수 보고
- 커밋: 항목 단위 브랜치 (`build-0.15.2`), **push·PR까지**

### [2026-10-25 #104] JELLY 크기 레벨 고정 · 배 속에 먹은 젤리 · 뒤 빛 삭제 · 어두운 띠 — 완료
- 상태: 완료 (2026-10-25 Claude 검수 · [PR #106](https://github.com/jeongmo-dot/gravity_orb/pull/106) 병합 `b314221`)
- 검수: Codex 캡처 `57_jelly_full_down`·`_right`·`_eat_00~02` — 크기 레벨 고정 (60 → 60 → 85), 배 속 젤리 `f` 순서·중력 쪽, 빛 판 없음. 측정 R 256.5턴·실력 비 1.45·초반 0.738 (범위 안). 어두운 띠는 재현 못 함 — 빛 판을 숨긴 뒤 0회, 0.15.2 플레이로 다시 확인. 래퍼 381/381, 다른 모드 해시 그대로 (Codex). Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§12-JE.9**, 시안 [mockups/jelly_full_marks.png](mockups/jelly_full_marks.png) **C** (기획서 0.15.2)
- 배경: 사용자 (2026-10-25, 0.15.1) "두 단계 이상 차이나도 합쳐지는 것 같은데", "3레벨 차이부터 안합쳐지는 거 같아", "레벨 말고 크기가 달라질 이유가 있나" — 규칙은 맞고, 크기가 질량으로 레벨 사이를 보간해 먹은 젤리가 다음 레벨처럼 보인다 (L3 질량 7 = 78.75 ≈ L4 85). 사용자 선택: "크기는 레벨에 고정" + 시안 C, 뒤 빛 "없애기". 보통 얼굴 젤리 둘레 어두운 띠 ("2,3번 움직이는 동안 계속 있다가 어느 순간 사라졌어", "다른 색깔들도 나와")
- 요구 (§12-JE.9 "바꿀 것" 1~4):
  1. 크기 = 레벨 반지름 (물리·그림), 질량은 규칙에만. 흡수 성장 0.10초는 레벨이 오를 때만
  2. 배 속에 먹은 젤리 — 채움 `f`, 중력 쪽 `0.44r`·가로 `+0.12r`, 반지름 `0.54r × √f`, 몸통 색 0.35 밝게·알파 0.85·반사점, 몸통 앞·얼굴 뒤, 몸통 윤곽으로 자름, 틀 회전 + `deform`, 바뀔 때 0.15초
  3. JELLY 대폭발 가능 뒤 빛 (`BlastOutline`) 삭제 — 터질 듯한 얼굴만
  4. 어두운 띠 재현·원인 보고 (프레임마다 보이는 자식 메시·알파, 젤리 근처에 오래 남는 연출 노드) → 3번 뒤에도 나오면 고친다
- 검수: 테스트 (질량별 반지름 = 레벨 반지름, 레벨 그대로 흡수는 크기 불변, 레벨 오를 때 0.10초 성장, `f`·배 속 젤리 크기·위치, JELLY에서 `BlastOutline` 숨김), 어두운 띠 재현 결과와 원인·고친 뒤 0회, 측정 (§12-JE.9 — R·G·L × 시드 1~20, #98·#101과 나란히), CLASSIC·BLITZ·SLIME 해시 그대로 (JELLY 새 해시 보고), 캡처 `57_jelly_full` 두 비율 (중력 아래 L3 `f` 0·0.5·0.75 나란히 — 시안 C와 비교, L5 터질 듯한 얼굴 + `f` 0.5, 중력 오른쪽 판, L3이 L2를 두 번 먹는 띠 — 크기 그대로 + 배 속 젤리 → 레벨 오름)
- 건드리지 말 것: 규칙·점수·질량 계산, 대폭발 L5부터, 터질 듯한·보통·MAX 얼굴 그림, CLASSIC·BLITZ·SLIME, 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과(`.\tests\run_tests.ps1`), 측정·재현 보고, 캡처 보고 (마지막은 전체 캡처), 스모크 5종 (기본·turn·blitz·slime·jelly), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-25 #103] Windows 빌드 0.15.1 — 완료
- 상태: 완료 (2026-10-25 Claude 검수 · [PR #105](https://github.com/jeongmo-dot/gravity_orb/pull/105) 병합 `91ebce9`)
- 검수: `build/windows/GravityOrb_v0.15.1.exe` (111,219,904바이트) + `.console.exe` + `_BUILD.txt` (커밋 `b76927e` = 브랜치 끝, 커밋 15초 뒤 빌드, 코드는 main과 같고 다른 것은 버전 한 줄) 직접 확인. 스모크 5종·격리 창 (시작 화면·`--mode=jelly`)·사용자 `save.cfg` 해시 동일·묶음 검사·래퍼 380/380·0.15.0 파일 유지 (Codex). 시작 화면 → JELLY 실제 클릭은 자동화 안 함. Claude 재실행 없음
- 근거: [technical_design.md](technical_design.md) **§10.5·§10.5.1** (버전 기록 0.15.1 줄)
- 배경: 0.15.0 플레이 뒤 JELLY 움직임 (#101)·대폭발 가능 얼굴 (#102)을 고쳤다 — 사용자가 직접 확인할 빌드
- 요구:
  1. `project.godot` `application/config/version` `0.15.0` → **`0.15.1`** (Claude 결정 값 — 기획서 0.15.1, PATCH +1)
  2. 버전을 커밋한 뒤 **깨끗한 작업 트리에서** 릴리스 빌드 `.\tools\build_windows.ps1` → `build/windows/GravityOrb_v0.15.1.exe` + `.console.exe` + `_BUILD.txt`. 다른 버전 파일은 남긴다
  3. 내보낸 콘솔 exe로 스모크 5종 (기본·turn·blitz·slime·jelly) 종료 코드 0·`SCRIPT ERROR` 0
  4. 격리 창에서 시작 화면·JELLY 직접 실행 확인 (실제 클릭이 안 되면 그 사실과 대신 확인한 방법)
- 검수: 빌드 결과 줄·파일 크기, `_BUILD.txt` 커밋 = 이 브랜치 마지막 커밋, 사용자 `save.cfg` 해시 전후 동일, 묶음에 `tests/`·`artifacts/`·`docs/` 없음, 래퍼 통과
- 건드리지 말 것: 버전 외 모든 파일, 사용자 저장 파일, 다른 버전 빌드 파일, `docs/` (회신 파일 제외)
- Done-when: 위 검수 보고
- 커밋: 항목 단위 브랜치 (`build-0.15.1`), **push·PR까지**

### [2026-10-25 #102] JELLY 대폭발 가능 표시 — 터질 듯한 얼굴 — 완료
- 상태: 완료 (2026-10-25 Claude 검수 · [PR #104](https://github.com/jeongmo-dot/gravity_orb/pull/104) 병합 `d06d898`)
- 검수: 추가 요구 1의 1~4 반영 확인 (Codex 캡처 `56_jelly_blast_face_down`·`_right`·`_glow_min/max`, 볼·빛 픽셀 값) — 시안 C와 같음, 빛 보임 (휘도 0.17~0.25 / 배경 0.08), 볼 분홍, 얼굴 늘 똑바로. 래퍼 380/380, 모든 해시 그대로 (Codex). Claude 재실행 없음
- 1차 상태: 추가 요구 1 (2026-10-25)
- 추가 요구 1: [technical_design.md](technical_design.md) §12-JE.8 "#102 1차 결과" 1~4
  1. 뒤 빛이 안 보임 — 빛 판이 `−(앞면 + 0.004)`라 L5~L7 (반지름 1.0 m 이상)은 보드 배경판 (z −0.34 m)보다 뒤 → 배경판·격자보다 앞, 몸통 앞면보다 뒤로 (예: z −0.30 m)
  2. 볼이 탁함 (초록 L5 볼 `(147,133,137)`) — 볼 색을 얼굴 어두운 색과 섞음 → 볼 색 그대로·알파로만, MAX 얼굴도
  3. **얼굴을 늘 똑바로** (사용자 "똑바로 고정") — 모든 JELLY 얼굴·문양 회전 0, 말랑함은 중력 기준 그대로 (얼굴 판 = `R(θ)·S(deform)·R(−θ)`), 몸통·빛 판은 지금처럼
  4. 캡처 다시 — 중력 아래 노랑 L5 + 보라 L5·L6·L7 (시안 C와 비교), 중력 오른쪽 붐비는 판, 빛 확대 (알파 최저·최고)
  - 검수: 빛 픽셀 밝기·볼 픽셀 값 보고, 테스트 (얼굴 판 회전 0·중력 오른쪽 얼굴 판 배율), 모든 모드 해시 그대로, 래퍼·스모크 5종·`-Debug` 빌드
- 근거: [technical_design.md](technical_design.md) **§12-JE.8**, 시안 [mockups/jelly_blast_marks.png](mockups/jelly_blast_marks.png) **C**
- 배경: 사용자 (2026-10-25) L5 젤리 둘레 어두운 고리에 "완전히 바꿔. 대폭발 가능 표시가 뭐 이래" → 시안 A~D 중 **C. 터질 듯한 얼굴** 선택
- 요구:
  1. JELLY에서 링 셰이더 대폭발 표시를 없앤다 (CLASSIC·BLITZ 그대로)
  2. 대폭발 가능 L5·L6: 보통 눈 대신 터질 듯한 얼굴 — 눈 `>` `<`·입 `o`·볼 (좌표·굵기·색 §12-JE.8 표, 얼굴 판 배율 1.0, 깜빡임 없음)
  3. 대폭발 가능 L5·L6·L7: 몸통 뒤 은은한 제 색 빛 (가장자리 밖 `0.25r`까지, 알파 0.22 ↔ 0.40, 1.6초 사인). L7은 MAX 얼굴 그대로
  4. 얼굴 회전·말랑함은 보통 얼굴과 같음 (#101 틀·`deform`)
- 검수: 캡처 `56_jelly_blast_face` 두 비율 (노랑 L5 + 보라 L5 나란히·L6·L7, 붐비는 판, 중력 오른쪽 — 시안 C와 비교), 테스트 (L4·L5/L6·L7 얼굴, JELLY 링 꺼짐, CLASSIC 표시 그대로, 빛 알파 프레임 변화 0.02 이하), 모든 모드 해시 그대로
- 건드리지 말 것: 규칙·물리, 보통·MAX 얼굴 그림, 다른 모드 그림, 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과(`.\tests\run_tests.ps1`), 캡처 보고 (마지막은 전체 캡처), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**

### [2026-10-25 #101] JELLY 움직임 다듬기 — 지글거림·툭툭 튐 — 완료
- 상태: 완료 (2026-10-25 Claude 검수 · [PR #103](https://github.com/jeongmo-dot/gravity_orb/pull/103) 병합 `f02e8ad`)
- 검수: 추가 요구 1의 1~4 반영 확인 (Codex 캡처 `55_jelly_motion_land_06~08`·`breathe_max`·`rest`·`right`) — 납작할 때도 얼굴 보임, 새 젤리 틀 바로 맞춤, 흡수 6 → 8 성장, 실제 쌓인 판 측정 (움직이는 동안 크기 변화 26.9% → 2.56%·틀 회전 1.72 → 0.105 rad). 래퍼 377/377, 다른 모드 해시 그대로 (Codex). Claude 재실행 없음
- 1차 상태: 추가 요구 1 (2026-10-25)
- 추가 요구 1: [technical_design.md](technical_design.md) §12-JE.7 "#101 1차 결과" 1~4
  1. 납작해질 때 얼굴이 몸통에 가려짐 (`land_06~10` 눈·입 사라짐 — 몸통 z 배율 = `deform.x` 최대 1.18 > 얼굴 판 `r + 0.006`, L7은 숨쉬기만으로도) → 얼굴 판·문양 z를 몸통 앞면 기준으로 (또는 몸통 z 배율 1 이하)
  2. 새 젤리가 돌면서 나타남 (틀 회전 0에서 시작) → 생성·합체 결과는 첫 중력 설정 때 틀을 목표 각으로 바로
  3. 레벨이 오르는 흡수는 아직 한 번에 커짐 (시작 반지름이 결과 레벨 반지름) → 먹는 쪽 지금 반지름에서 시작, 테스트 질량 6 → 8
  4. 측정·`rest` 캡처를 실제로 떨어뜨려 쌓인 40개 (서로 닿음)에서 다시 + 움직이는 동안 (중력 바꾼 뒤 1.5초) 프레임 사이 크기·틀 회전 변화 — main·PR 전후
  - 검수: `land_06~08` 눈·입 보임, L7 숨쉬기 최고점 캡처, 테스트 (얼굴 판 z > 몸통 앞면·생성 직후 틀 각·질량 6 → 8 성장), 측정 표, 해시 (JELLY 새 값), 래퍼·스모크 5종·`-Debug` 빌드
- 근거: [technical_design.md](technical_design.md) **§12-JE.7**
- 배경: 사용자 (2026-10-25, 0.15.0 플레이) "젤리 모드 공이 움직이는 동안 이질감이 크네.. 자연스럽지가 않고 툭 툭 튀는 느낌이야", "지글거림이 있어. 불쾌한 느낌이야". Claude 진단 (§12-JE.7 표): 말랑함이 SLIME 수치만 같고 방식이 다르다 — 닿을 때마다 찌그러짐을 새로 시작 (최소 0.18, 벽 포함, 즉시 크기 변경 + `TRANS_BACK`), 늘어남이 속력에서 바로·회전 순간 전환, 찌그러짐 축 반대, 숨쉬기 켜짐/꺼짐, 얼굴·몸통 축 어긋남, 흡수 즉시 커짐, 164Hz 화면에서 물리 보간 없음
- 요구 (§12-JE.7 "고칠 것" 1~7):
  1. 젤리 틀 — 중력 쪽 회전 하나를 몸통·얼굴이 함께 (`delta × 8`), 속도 방향 회전 없음. 얼굴이 중력 쪽으로 도는 것은 그대로
  2. 모양 `deform` 하나가 목표를 `delta × 11`로 따라감 — 떨어짐 늘어남 `v·g ÷ 5800` (최대 0.19), 찌그러짐 `(1 + 0.18i, 1 − 0.20i)`, 멈추면 `(1, 1)`
  3. 찌그러짐 세기는 접촉 이벤트가 아니라 물리 스텝마다 속력이 줄어든 양 `÷ 1000` (0.06 미만 무시, `−4.8/s`로 감소)
  4. 숨쉬기는 판이 멈춘 동안만, 가중치를 `delta × 4`로 켜고 끔, 가로·중력 쪽 반대로
  5. 얼굴 판은 몸통과 같은 틀·같은 `deform`
  6. 흡수한 쪽 반지름 (물리·그림)을 0.10초에 걸쳐 키움
  7. 그림 위치를 물리 두 스텝 사이로 보간 (3D 모드 전체, 렌더만), 순간 이동은 보간 초기화
- 검수: §12-JE.7 검수 — 측정 전·후 (쉬는 판 찌그러짐 시작 0회/초, 프레임 사이 크기 변화 0.5% 이하), 내려앉음 납작·얼굴 축·건너뛰기 없음·보간 테스트, CLASSIC·BLITZ·SLIME 해시 그대로 (JELLY 새 해시 보고), JELLY 무작위 판 길이 중앙 223.5턴 ±10%, 캡처 `55_jelly_motion_{land,rest}` + 중력 오른쪽 판 두 비율
- 건드리지 말 것: 규칙·점수·대폭발 판정, 젤리 셰이더·색·얼굴 그림, 대폭발 가능 표시 (따로 항목), SLIME, 사용자 저장 파일, `docs/` (회신 파일 제외)
- Done-when: 테스트 통과(`.\tests\run_tests.ps1`), 측정 보고, 캡처 보고 (마지막은 전체 캡처), 스모크 5종 (기본·turn·blitz·slime·jelly), 검증 빌드는 `-Debug`만
- 커밋: 항목 단위 브랜치, **push·PR까지**
