# 항공기 정비요청 Agent: 통합 레포

정비 신고를 같은 기체의 수리이력과 SDR 사례로 분류하고 담당 정비 부서에 배정하는 AI Agent입니다.
이 레포는 네 개의 레포를 **submodule로 묶어 서로 맞춰 돌아가는 커밋 조합**을 기록하고, 전체 실행 순서·데이터 받는 법·최종보고서를 함께 둡니다.

| 폴더 | 레포 | 역할 |
| --- | --- | --- |
| `frontend/` | [dashboard](https://github.com/mro-agent-proj/dashboard) | 신고자·정비팀·관리자 화면 (Vue 3, :5173) |
| `backend/` | [backend](https://github.com/mro-agent-proj/backend) | 계정·요청·배정, DB·RabbitMQ, MCP 토큰 발급 (Spring Boot, :8080) |
| `mcp/` | [agent](https://github.com/mro-agent-proj/agent) | business-mcp(:8101)·rag-mcp(:8102), 읽기 전용 |
| `ai/` | [LLM](https://github.com/mro-agent-proj/LLM) | LLM1 분류 → LLM2 조사 → LLM3 검토 (FastAPI + LangGraph, :8100) |
| `report/` | 이 레포 | 최종 결과보고서(PDF·HTML), 화면 캡처, 테스트 원자료, 트러블슈팅 |

```
[frontend] ─/api─▶ [backend] ──mro.agent.run (+MCP 토큰 2개)──▶ [ai]
                      ▲   └─ Postgres(업무 + RAG)                │ Bearer
                      └──── mro.agent.events ◀──────────────────┤──▶ [business-mcp]
                                                                 └──▶ [rag-mcp]
```

## 처음 받기

```bash
git clone --recurse-submodules https://github.com/mro-agent-proj/mro-agent-integration.git
cd mro-agent-integration
./scripts/fetch-data.sh          # RAG 전달본·원문 데이터 (gh 로그인 필요)
```

이미 받은 상태에서 각 레포 최신으로 맞추기: `git pull && git submodule update --init --recursive`

## 실행

1. 비밀값 파일을 만듭니다. git에 올리지 않습니다.
   - `mcp/.env.mcp` ← `mcp/.env.mcp.example` (JWT 비밀값은 backend local 기본값과 같게 두면 됨, 예시 파일 주석 참고)
   - `ai/.env` ← `ai/.env.example` (`LLM_API_KEY`에 OpenAI 키, `AI_MODE=rabbit`)
2. 전체 스택을 띄웁니다. backend(실제 AI 모드) → MCP 두 개 → AI 서버 순서입니다.
   ```bash
   ./scripts/up.sh
   ```
3. 화면을 띄웁니다.
   ```bash
   cd frontend && pnpm install && pnpm dev    # http://localhost:5173
   ```

시드 계정은 모두 비밀번호 `test1234`입니다. 신고자 `reporter1@kal.test`, 정비팀 `sys@mro.test`·`fcs@mro.test` 등, 관리자 `admin@mro.test`. 전체 목록은 `backend/data/seed/users.csv`.

- AI 없이 화면만 보려면 `cd backend && docker compose up -d` (기본 `AI_MODE=mock`, 키워드 기반 가짜 판단).
- 처음부터 다시: `cd backend && docker compose down -v` 후 `./scripts/up.sh`. 시드·RAG는 자동으로 다시 적재되고, 그동안 만든 요청·가입 계정은 지워집니다.

## 데이터

데이터는 용량 때문에 git이 아니라 **Release [`data-2026-10-22`](https://github.com/mro-agent-proj/mro-agent-integration/releases/tag/data-2026-10-22)** 첨부파일로 둡니다. `scripts/fetch-data.sh`가 받아서 `backend/data/` 아래에 풉니다.

| 첨부파일 | 풀리는 위치 | 내용 |
| --- | --- | --- |
| `rag-data-v1-20261021.tar` (124MB) | `backend/data/rag/2026-10-21-rag-v1/` | RAG 복원용 덤프: SDR 71,741 · JASC 548 · AMM 참조 35,396 · 근거 107,137 · 임베딩 31,678 |
| `rag-tech-v1-20261021.tar` (1MB) | `backend/data/rag/mro-tech-handoff-20261021-v1/` | 기술자료(R04) 덤프: Airbus Safety First 61편, 조각·임베딩 496 |
| `rag-source-20261022.tar` (134MB) | `backend/data/source/` | DB 원문을 CSV로 뽑은 것: SDR 원본 연도별 CSV(Airbus 기종), 테이블별 CSV. 확인·공유용 |

backend가 뜰 때 `rag-restore` 서비스가 `data/rag/`의 덤프를 자동으로 DB에 복원합니다. `data/source/`는 복원에 쓰지 않습니다.

git에 있는 데이터 (backend 레포 `data/` 아래):

| 폴더 | 내용 |
| --- | --- |
| `backend/data/seed/` | 항공사 3, 기체 20, 부서 8, 계정 15, 수리이력 1,577 |
| `backend/data/eval/` | 평가셋: AI 경로 시나리오 23건(`scenarios.jsonl`)과 접수 검증 6건(`validation.jsonl`), 원본 표 `scenarios.md` |

## 평가

스택을 띄운 상태에서 평가셋을 실제로 보내 채점합니다. 요청이 DB에 쌓이고 OpenAI 비용이 듭니다(23건 약 6분).

```bash
cd backend && python3 scripts/eval.py      # 결과: backend/data/eval/results/<시각>.json
```

배정 정답, 사람 검토 전환, 경로 일치, 자동 배정률, 평균 소요, 접수 검증 일치를 출력합니다. 항목 설명은 `backend/data/eval/README.md`.

## 최종 결과보고서

- `report/항공기_정비요청_Agent_최종결과보고서.pdf` (26쪽)
- `report/final_report.template.html`: 원본 HTML. 고친 뒤 Chrome으로 PDF 인쇄
- `report/images/`: 아키텍처·LangGraph 그림, 화면 캡처 13장 (시연 데이터 11건으로 촬영)
- `report/raw/`: 시나리오 실행 결과(`scenario_results.json`), S10 에이전트 추적, 인증·DLQ·테스트 기록
- `report/트러블슈팅.md`: 통합하며 겪은 문제 20건과 해결
- `report/v1/`: 팀이 처음 쓴 v1 보고서와 체크리스트

## 이 레포 갱신 규칙

- 각 레포 작업은 각 레포에 커밋합니다. 이 레포에는 "함께 동작을 확인한 조합"이 될 때 submodule 포인터를 올립니다.
  ```bash
  git submodule update --remote          # 네 레포 main 최신으로
  ./scripts/up.sh                        # 동작 확인
  git add frontend backend mcp ai && git commit -m "submodule: <무엇을 맞췄는지>"
  ```
- 데이터가 바뀌면 새 Release 태그로 올리고 `scripts/fetch-data.sh` 기본 태그와 이 표를 고칩니다.
- `.env`·키·덤프 파일은 커밋하지 않습니다.
