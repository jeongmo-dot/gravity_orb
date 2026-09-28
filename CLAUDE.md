# CLAUDE.md — Gravity Orb

Godot 4 / GDScript 턴제 물리 퍼즐 프로토타입. Codex와 역할을 나눠 진행한다.

## 역할 분담

| 담당 | 역할 | 편집 대상 |
|---|---|---|
| **Claude** | 설계·명세, 코드 리뷰, QA 판정, 병합 | `docs/technical_design.md`, `docs/jeongmo_claude_to_codex.md`, `config/default_config.tres`의 **기존 값** |
| **Codex** | 구현, 테스트 작성·실행, QA 관측 | `.gd` · `.tscn` · `.tres` · `project.godot` · `tests/` · `GameConfig` **새 필드**, `docs/jeongmo_codex_to_claude.md` |

- 코드 **읽기·진단·리뷰·병합**은 Claude가 한다. **코드 편집은 하지 않는다.** 한 줄 수정도 명세로 적어 Codex에게 넘긴다
- **수치는 기획이다.** 값은 Claude가 정하고, `default_config.tres` 값 변경은 `technical_design.md` 4장 갱신과 **같은 커밋**에 넣는다
- QA 실행은 Codex, 결과 해석과 합격 판정은 Claude

## 핸드오프 창구 — 고정 파일 2개

| 파일 | 쓰는 쪽 |
|---|---|
| `docs/jeongmo_claude_to_codex.md` | **Claude** (지시·명세 링크) |
| `docs/jeongmo_codex_to_claude.md` | **Codex** (결과·QA 관측값·질문) |

- **각자 자기 파일만 쓴다.** 상대 파일은 고치지 않는다
- 긴 명세는 `technical_design.md`에 두고 인박스에는 링크와 요약만 적는다
- Codex 회신을 확인하면 내 파일에서 해당 항목을 `완료`로 바꾸고 「처리 완료」로 옮긴다
- 상세 규칙: `AGENTS.md`

## 문서

- 구현 기준: `docs/technical_design.md`
- 기획 원본: `C:\Workspace\context\game-design\Gravity_Orb\` (git 밖). 저장소의 `docs/reference/`는 그 사본이다.
  원본을 고치면 `docs/reference/`로 다시 복사해 커밋한다

## git

- 원격: https://github.com/jeongmo-dot/gravity_orb
- Codex 작업은 항목 단위 브랜치 → PR. 병합 전 리뷰와 Done-when 대조를 한다
- 워킹트리를 공유할 때는 git 상태를 바꾸는 명령 전에 `git status`를 확인하고, 내가 만들지 않은 변경이 있으면 파괴적 명령(`reset --hard`, `checkout --`, `clean`, `push --force`)을 실행하지 않는다
