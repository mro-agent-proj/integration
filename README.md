# 항공기 정비요청 Agent: integration

정비 신고를 같은 기체의 수리이력과 SDR 사례로 분류하고 담당 정비 부서에 배정하는 AI Agent입니다.
이 레포는 서비스 레포 4개를 submodule로 묶어 **함께 검증을 통과한 커밋 조합**을 고정하고, 로컬 실행·데이터·평가·모니터링 구성을 둡니다.

| 폴더 | 레포 | 역할 |
| --- | --- | --- |
| `frontend/` | [dashboard](https://github.com/mro-agent-proj/dashboard) | 신고자·정비팀·관리자 화면 (Vue 3, :5173) |
| `backend/` | [backend](https://github.com/mro-agent-proj/backend) | 계정·요청·배정, DB·RabbitMQ, MCP 토큰 발급 (Spring Boot, :8080) |
| `mcp/` | [agent](https://github.com/mro-agent-proj/agent) | business-mcp(:8101)·rag-mcp(:8102), 읽기 전용 |
| `ai/` | [LLM](https://github.com/mro-agent-proj/LLM) | LLM1 분류 → LLM2 독립 조사 → LLM3 검토 (FastAPI + LangGraph, :8100) |
| `monitoring/` | 이 레포 | Prometheus(:9090) + Grafana(:3000) |

```
[frontend] ─/api─▶ [backend] ──mro.agent.run (+MCP 토큰 2개)──▶ [ai]
                      ▲   └─ Postgres(업무 + RAG)                │ Bearer
                      └──── mro.agent.events ◀──────────────────┤──▶ [business-mcp]
                                                                 └──▶ [rag-mcp]
```

## 빠른 시작

```bash
git clone --recurse-submodules https://github.com/mro-agent-proj/integration.git
cd integration
./scripts/fetch-data.sh                       # RAG 전달본 (data 레포 읽기 권한, gh 로그인 필요)
cp mcp/.env.mcp.example mcp/.env.mcp          # 값 채우기
cp ai/.env.example ai/.env                    # LLM_API_KEY, AI_MODE=rabbit
./scripts/up.sh                               # backend → MCP 2개 → AI 순서로 기동, 헬스 확인
cd frontend && pnpm install && pnpm dev       # http://localhost:5173
```

- `mcp/.env.mcp`의 JWT 비밀값은 backend local 기본값과 같게 둡니다(예시 파일 주석 참고). `RAG_OPENAI_API_KEY`를 넣으면 R02가 하이브리드 검색을, 비우면 단어 검색만 합니다.
- 시드 계정 비밀번호는 모두 `test1234`입니다. 신고자 `reporter1@kal.test`, 정비팀 `sys@mro.test` 등, 관리자 `admin@mro.test` (전체: `backend/data/seed/users.csv`).
- AI 없이 화면만 보려면 `cd backend && docker compose up -d` (기본 `AI_MODE=mock`, 키워드 기반 가짜 판단).
- `.env`·키·덤프는 커밋하지 않습니다. 기존 DB·큐·AI 상태 볼륨은 지우지 않습니다.

### 모니터링 (선택)

```bash
docker compose -f monitoring/compose.yaml up -d
```

Grafana http://localhost:3000 (`admin` / `admin`, `GRAFANA_ADMIN_PASSWORD`로 변경)에 "MRO 정비요청 Agent" 대시보드가 열립니다. 수집 대상과 패널은 [monitoring/README.md](monitoring/README.md).

## 데이터

RAG 데이터는 용량·저작권 때문에 git이 아니라 비공개 레포 [`data`](https://github.com/mro-agent-proj/data)의 Release `data-2026-10-22`에 둡니다. `fetch-data.sh`가 `backend/data/` 아래에 풀고, backend 기동 시 `rag-restore`가 덤프를 DB에 자동 복원합니다.

| 첨부파일 | 풀리는 위치 | 내용 |
| --- | --- | --- |
| `sdr-jasc-amm_v2.tar` (57MB) | `rag-dump/sdr-jasc-amm_v2/` | SDR 71,741 · JASC 548 · AMM 참조 35,396 · 근거 107,137 (Flyway V8+) |
| `airbus-safety-first_v2.tar` (3MB) | `rag-dump/airbus-safety-first_v2/` | 기술자료(R04): Safety First 61편, 조각·임베딩 496 (Flyway V8+) |
| `sdr-embeddings_v1.tar` (317MB) | `rag-dump/sdr-embeddings_v1/` | R02용 SDR 임베딩 71,741 (OpenAI text-embedding-3-large, 1024차원, Flyway V7+) |
| `rag-csv.tar` (134MB) | `rag-csv/` | 위 덤프를 사람이 보는 CSV로 (확인·공유용, 복원에 안 씀) |

git에 있는 데이터는 backend 레포 `data/` 아래입니다: 업무 시드(`seed/`, 수리이력 v2 1,600건 포함), 서비스 평가 200건(`eval/service/`), 접수 검증 6건(`eval/scenario/`), FAA SDR 기반 단위 평가(`eval/sdr/`). 자세한 내용은 `backend/data/README.md`.

고정된 backend와 데이터 Release 버전은 짝이 맞아야 하며 CI의 `scripts/check-data-version.sh`가 확인합니다.

## 평가

스택을 띄운 상태에서 실제 요청을 보내므로 DB에 기록이 쌓이고 OpenAI 비용이 발생합니다. AI 소비자가 하나라서 순차 실행(`--workers 1`)이 기본입니다.

```bash
cd backend
python3 scripts/scenario_eval.py --workers 1                 # 200건 + 접수 검증 6건
python3 scripts/scenario_eval.py --split test --workers 1
python3 scripts/scenario_eval.py --only SV-A-001,SV-B-002,V2
```

결과는 `backend/data/eval/service/results/<시각>.json`에 남습니다. 채점 정의는 `backend/data/eval/service/README.md`, 단위 평가는 `backend/data/eval/sdr/README.md`를 따릅니다. 실행 전 `maintenance_history_v2.csv`와 DB 이력이 같은지 확인하세요(manifest·CI는 파일 조합만 검사).

평가 결과 원자료는 [deliverables 평가 번들](https://github.com/mro-agent-proj/deliverables/tree/main/evaluations/2026-10-23-isolated-200)에 있습니다.

## 조합 갱신 흐름

코드 변경은 각 서비스 레포에 PR로 올립니다. 이 레포의 main은 봇(`mro-release-bot`)만 갱신합니다.

```
서비스 레포 PR → CI → main 병합 → Release(이미지 ECR push) → 이 레포에 알림
  → Sync: 네 submodule을 각 main 최신으로 → 통합 검증 → 통과하면 봇 커밋 + verified-<시각> 태그
  → infra 레포에 release PR → 병합·승인 후 운영 배포
```

- 통합 검증: 시작 스크립트·채점 계약 테스트, 데이터 버전 검사, backend 스택(mock AI) 기동·헬스 확인. 실패하면 커밋하지 않습니다.
- 최신 조합은 main의 submodule 포인터와 최신 `verified-*` 태그로 확인합니다. 수동 갱신은 Actions → Sync(workflow_dispatch).
- 이 레포의 문서·스크립트를 고칠 때만 관리자가 PR을 열어 병합합니다.

### 로컬 스택을 새 조합으로 올리기

1. 신규 접수를 멈추고 진행 중인 AI 실행·이벤트 반영이 끝나기를 기다립니다(`up.sh`는 실행을 비우지 않음).
2. `git pull && git submodule update --init --recursive`. 로컬 변경은 먼저 보존합니다.
3. 업무 시드는 users가 있으면 다시 적재되지 않습니다. 시드가 바뀌었으면 Backend 담당 갱신 절차나 별도 빈 DB를 씁니다.
4. 볼륨을 보존한 채 `./scripts/up.sh`로 재빌드합니다. workflow 버전이 바뀌었으면 미완료 구버전 요청은 담당자가 확인합니다.
5. 네 서비스 헬스와 `AI_MODE=rabbit`, MCP 계정·토큰 설정을 확인한 뒤 접수를 재개합니다.

## 관리 규칙

- RAG 전달본이 바뀌면 `data`에 새 Release 태그로 올리고 `scripts/fetch-data.sh` 기본 태그와 위 데이터 표를 고칩니다.
- 업무 시드·서비스 평가셋이 바뀌면 Backend의 manifest와 안내를 함께 갱신합니다.
- 보고서·발표자료는 [deliverables](https://github.com/mro-agent-proj/deliverables), 운영 인프라는 [infra](https://github.com/mro-agent-proj/infra)에서 관리합니다.
