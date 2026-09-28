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

### [2026-09-28 #2] M1 보드와 구체 물리
- 상태: 대기
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
  - [ ] 방향키 4개로 중력이 바뀌고 모든 구체가 그 벽으로 굴러간다
  - [ ] 구체가 벽을 뚫거나 보드 밖으로 나가지 않는다
  - [ ] 레벨이 다른 구체의 크기가 눈에 띄게 다르다
  - [ ] `test_config.gd`: `radius_for_level(1..7)`이 50 × {1.00, 1.25, 1.5625, 1.953125, 2.44140625, 3.0517578125, 3.814697265625} (오차 1e-3), `mass_for_level(2)` = 1.5625
  - [ ] §10.1 명령 3종 에러 0, 테스트 종료 코드 0
- QA:
  - 자동: §10.1 명령 3종. 가능하면 헤드리스 시나리오로 **보드 밖 이탈 0건**을 수치로 확인 — 테스트 구체 배치 후 중력을 DOWN→RIGHT→UP→LEFT 순으로 각 120 물리 프레임씩 바꿔가며 4바퀴, 매 프레임 모든 구체 중심이 `|x|,|y| <= half`인지 검사. 이탈 건수·최대 속도를 회신
  - 수동: 방향키 조작·크기 차이 확인 절차를 회신에 적는다

---

## 처리 완료

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
