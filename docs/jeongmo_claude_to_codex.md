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

### [2026-09-28 #1] M0 프로젝트 셋업
- 상태: 대기
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
  - [ ] 실행하면 세로 창(540×960)에 빈 화면이 뜬다
  - [ ] 창 크기를 바꿔도 1080×1920 비율이 유지된다 (레터박스)
  - [ ] `Config.data`가 `GameConfig` 인스턴스로 접근된다
  - [ ] §10.1 명령 3종이 에러 없이 끝나고 테스트 러너 종료 코드 0
- QA: §10.1 명령 3종의 종료 코드와 출력 요약. 창 비율 확인은 수동 확인 절차로 회신에 적는다

---

## 처리 완료

_(없음)_
