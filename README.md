# 항공기 정비요청 Agent: 통합 레포

정비 신고를 같은 기체의 수리이력과 SDR 사례로 분류하고 담당 정비 부서에 배정하는 AI Agent입니다.
이 레포는 네 개의 레포를 **submodule로 묶어 서로 맞춰 돌아가는 커밋 조합**을 기록하고, 전체 실행 순서·데이터 받는 법·최종보고서를 함께 둡니다.

| 폴더 | 레포 | 역할 |
| --- | --- | --- |
| `frontend/` | [dashboard](https://github.com/mro-agent-proj/dashboard) | 신고자·정비팀·관리자 화면 (Vue 3, :5173) |
| `backend/` | [backend](https://github.com/mro-agent-proj/backend) | 계정·요청·배정, DB·RabbitMQ, MCP 토큰 발급 (Spring Boot, :8080) |
| `mcp/` | [agent](https://github.com/mro-agent-proj/agent) | business-mcp(:8101)·rag-mcp(:8102), 읽기 전용 |
| `ai/` | [LLM](https://github.com/mro-agent-proj/LLM) | LLM1 맥락 분류 → LLM2 독립 조사 → LLM3 판단·근거 대조 (FastAPI + LangGraph, :8100) |
| `report/` | 이 레포 | 최종 결과보고서(PDF·HTML), 화면 캡처, 테스트 원자료, 트러블슈팅 |

```
[frontend] ─/api─▶ [backend] ──mro.agent.run (+MCP 토큰 2개)──▶ [ai]
                      ▲   └─ Postgres(업무 + RAG)                │ Bearer
                      └──── mro.agent.events ◀──────────────────┤──▶ [business-mcp]
                                                                 └──▶ [rag-mcp]
```

AI의 직접 배정 경로는 유지합니다. LLM1은 동일 기체 이력의 대상·현상·부정·상충을
비교하고, 실행기가 각각의 원문 인용과 현재 부서 담당 범위를 검증합니다.
추가 조사가 필요하면 LLM2에는 LLM1의 ATA·제안 부서·판단 설명을 넣지 않습니다.
LLM3는 두 판단과 실제 근거를 비교해 통과·재조사·사람 검토를 결정합니다.
설계와 검증 한계는 [AI 판단 분리 문서](ai/docs/contextual-handoff.md)에 있습니다.

현재 조합은 SDR 모델 범위를 단계적으로 넓히고 LLM3가 기종 차이를 검토하는 버전입니다.
LLM2 첫 R02 검색은 동일 기본 모델·ceo/neo 세대, 추가 조사는 같은 A320 계열의 Backend 허용 목록을 사용합니다.
R05·Backend 최종 검증도 같은 목록을 따르며 최종 인계에 구성 미확인을 표시합니다.
정확 모델 검색(EXACT)과 기존 NULL 정책의 정확 모델 동작은 유지합니다.
자세한 계약은 [모델 검색 범위](ai/docs/MODEL_SCOPE.md)에 있습니다.

| 구성 | 고정 커밋 | 포함 변경 |
| --- | --- | --- |
| Backend | `4c54f97` | Flyway V11, 모델 허용 목록·context_version=2, 최종 근거 검증 |
| dashboard | `3fa231e` | 기존 관리자 인원 현황 화면 |
| agent | `9ed1484` | B01 범위 전달, R02 키워드·벡터 범위 확대, R05·AMM 인계 검증 |
| LLM | `ce17850` | 기본 검색 선행, 확장 모델 검토, 최종 결과 표시 |

[Backend PR #15](https://github.com/mro-agent-proj/backend/pull/15),
[agent PR #13](https://github.com/mro-agent-proj/agent/pull/13),
[LLM PR #6](https://github.com/mro-agent-proj/LLM/pull/6)을 먼저 병합한 뒤 이 통합 PR을 반영합니다.
squash/rebase로 커밋이 달라지면 이 포인터들도 해당 병합 커밋으로 갱신합니다.
진행 중 작업을 마친 뒤 Backend(V11)·MCP·AI를 함께 교체하고 새 작업을 받습니다.
공유 DB 마이그레이션·시드는 Backend가 수행하며 기존 임베딩은 다시 만들지 않습니다.

로컬 검증: Backend 43건, 실제 PostgreSQL·조회 전용 계정·MCP HTTP/JWT를 포함한 agent 47건,
합성 모델·도구를 사용한 AI 168건, 통합 스크립트 3건 통과.
실제 OpenAI 분류 정확도 및 전체 실서비스 200건 평가, 공유 DB 적용은 이번 변경에서 실행하지 않았습니다.

`python3 -m unittest discover -s scripts/tests -v`는 Docker나 외부 접속 없이 준비 대기 만료와
각 서비스 health check 실패 시 비정상 종료되는지 검사하며 통합 CI에서도 실행합니다.
이 조합의 실제 모델·MCP HTTP·RabbitMQ 전체 종단간 시나리오는 아직 실행하지 않았습니다.

진행 중인 AI 실행을 마친 후 버전을 교체하세요. 구버전 직접 배정 checkpoint에
새 맥락 비교 자료가 없으면 최종 검증에서 사람 검토로 전환됩니다.
R02의 이전 커서는 재사용할 수 없으며 새 검색으로 시작해야 합니다.
하이브리드 검색은 단어·벡터 각각 상위 50건의 고정 합집합을 페이지로 나눕니다.
순위나 검색 방식이 바뀌면 기존 offset을 적용하지 않고 `INVALID_CURSOR`를 반환합니다.

서비스 평가셋은 `backend/data/eval/service/scenarios.jsonl`에 있습니다(A 64/B 96/C 16/D 24,
dev 80/test 120). 기체·항공사·정확 모델, 부서 코드, 이력 참조를 현재 업무 시드와 대조했고
새 인원 현황 변경과의 파일 충돌은 없습니다. 원본 평가셋은 변경하지 않았습니다.
정답 라벨은 154건이 `not_reviewed`, 31건이 `needs_final_review`, 15건이 `decided`입니다.
`expected`, `source`, `label_check`는 평가 메타데이터이며 AI 입력에 포함하지 않습니다.
`model_match=family` 54건도 RAG의 정확 모델 검색 범위를 넓히라는 지시로 해석하지 않습니다.

## 처음 받기

```bash
git clone --recurse-submodules https://github.com/mro-agent-proj/mro-agent-integration.git
cd mro-agent-integration
./scripts/fetch-data.sh          # RAG 전달본·원문 데이터 (gh 로그인 필요)
```

이미 받은 상태에서 이 레포가 고정한 커밋으로 맞추기: `git pull && git submodule update --init --recursive`

- 이 명령은 각 레포의 최신 `main`이 아니라, 이 레포가 **함께 검증해 고정한 커밋**을 내려받습니다. 각 레포 최신으로 가려면 아래 "이 레포 갱신 규칙"의 `--remote`를 씁니다.
- 고정된 backend와 Release 데이터 버전은 짝이 맞아야 합니다(예: v2 전달본은 Flyway V8 이상). CI의 `scripts/check-data-version.sh`가 확인합니다.

## 실행

1. 비밀값 파일을 만듭니다. git에 올리지 않습니다.
   - `mcp/.env.mcp` ← `mcp/.env.mcp.example` (JWT 비밀값은 backend local 기본값과 같게 두면 됨, 예시 파일 주석 참고)
   - `ai/.env` ← `ai/.env.example` (`LLM_API_KEY`에 OpenAI 키, `AI_MODE=rabbit`)
   - R02 하이브리드 검색을 쓰려면 `mcp/.env.mcp`의 `RAG_OPENAI_API_KEY`에도 OpenAI 키를 넣습니다(질의 임베딩용). 비우면 단어 검색만 합니다.
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
| `sdr-jasc-amm_v2.tar` (57MB) | `backend/data/rag-dump/sdr-jasc-amm_v2/` | RAG 복원용 덤프 6개 테이블: SDR 71,741 · JASC 548 · AMM 참조 35,396 · 근거 107,137 (backend Flyway V8 필요) |
| `airbus-safety-first_v2.tar` (3MB) | `backend/data/rag-dump/airbus-safety-first_v2/` | 기술자료(R04) 복원용 덤프: Airbus Safety First 61편, 조각 496, OpenAI 임베딩 496 (Flyway V8 필요) |
| `sdr-embeddings_v1.tar` (317MB) | `backend/data/rag-dump/sdr-embeddings_v1/` | R02 하이브리드 검색용 SDR 원문 임베딩 71,741건 (OpenAI text-embedding-3-large, 1024차원). backend Flyway V7 필요 |
| `rag-csv.tar` (134MB) | `backend/data/rag-csv/` | 위 덤프 내용을 사람이 보는 CSV로: `sdr-by-year/`(SDR 원본 연도별, 검색용 corpus 71,741건), `db-tables/`(테이블별). 확인·공유용 |

backend가 뜰 때 `rag-restore` 서비스가 `rag-dump/`의 덤프를 자동으로 DB에 복원합니다. `rag-csv/`는 복원에 쓰지 않습니다. 폴더 전체 설명은 `backend/data/README.md`.

git에 있는 데이터 (backend 레포 `data/` 아래):

| 폴더 | 내용 |
| --- | --- |
| `backend/data/seed/` | 항공사 3, 기체 20, 부서 8, 계정 15, 수리이력 1,577 |
| `backend/data/eval/scenario/` | 통합 평가셋: 손으로 만든 한국어 시나리오 23건 + 접수 검증 6건 |
| `backend/data/eval/sdr/` | 단위 평가셋: FAA 공개 SDR 2019~2020 기반 검색 400 · LLM1 분류 200 · LLM2 부서 200 · JASC 매핑 548 |

## 평가

스택을 띄운 상태에서 평가셋을 실제로 보내 채점합니다. 요청이 DB에 쌓이고 OpenAI 비용이 듭니다(23건 약 6분).

```bash
cd backend && python3 scripts/scenario_eval.py      # 통합 평가, 결과: backend/data/eval/scenario/results/<시각>.json
```

배정 정답, 사람 검토 전환, 경로 일치, 자동 배정률, 평균 소요, 접수 검증 일치를 출력합니다. 항목 설명은 `backend/data/eval/scenario/README.md`. 단위 평가셋(`sdr/`)의 지표와 사용법은 `backend/data/eval/sdr/README.md`.

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
