# 항공기 정비요청 Agent: integration

정비 신고를 같은 기체의 수리이력과 SDR 사례로 분류하고 담당 정비 부서에 배정하는 AI Agent입니다.
이 레포는 서비스 레포 4개를 submodule로 묶어 **함께 검증을 통과한 커밋 조합**을 기록하고, 로컬 실행·데이터·평가 스크립트를 둡니다.
main은 봇이 자동으로 갱신하며, 사람은 이 레포에 PR을 올리지 않습니다.

## 레포 구성

| 레포 | 이 레포 폴더 | 역할 |
| --- | --- | --- |
| [dashboard](https://github.com/mro-agent-proj/dashboard) | `frontend/` | 신고자·정비팀·관리자 화면 (Vue 3, :5173) |
| [backend](https://github.com/mro-agent-proj/backend) | `backend/` | 계정·요청·배정, DB·RabbitMQ, MCP 토큰 발급 (Spring Boot, :8080) |
| [agent](https://github.com/mro-agent-proj/agent) | `mcp/` | business-mcp(:8101)·rag-mcp(:8102), 읽기 전용 |
| [LLM](https://github.com/mro-agent-proj/LLM) | `ai/` | LLM1 맥락 분류 → LLM2 독립 조사 → LLM3 판단·근거 대조 (FastAPI + LangGraph, :8100) |
| **integration** | | **이 레포.** 검증된 커밋 조합, 실행·데이터·평가 스크립트 |
| [infra](https://github.com/mro-agent-proj/infra) | | AWS 인프라(Terraform)와 운영 배포. 배포는 여기서만 합니다 |
| [deliverables](https://github.com/mro-agent-proj/deliverables) | | 최종 결과보고서, 아키텍처 다이어그램 등 산출물 |
| [data](https://github.com/mro-agent-proj/data) (비공개) | | RAG 데이터 전달본 (외부 저작물 가공 데이터 포함) |

## 시스템 흐름

```
[frontend] ─/api─▶ [backend] ──mro.agent.run (+MCP 토큰 2개)──▶ [ai]
                      ▲   └─ Postgres(업무 + RAG)                │ Bearer
                      └──── mro.agent.events ◀──────────────────┤──▶ [business-mcp]
                                                                 └──▶ [rag-mcp]
```

## 운영 흐름

코드 변경은 각 서비스 레포에 PR로 올립니다. main에 병합되면 이 레포가 자동으로 갱신되고, 운영 배포는 infra에서 합니다.

```
서비스 레포 PR → CI 통과 → main 병합 → Release(이미지 ECR push) → 이 레포에 알림
  → Sync: 네 submodule을 각 레포 main 최신으로 → 통합 검증 → 통과하면 봇이 커밋 + verified-<시각> 태그
  → infra 레포에 조합 전달 → release PR → 병합·승인 후 배포
```

- 통합 검증: 시작 스크립트·채점 계약 테스트, 데이터 전달본 버전 검사, backend 스택(mock AI) 기동·헬스 확인.
  실패하면 아무것도 커밋하지 않습니다. 짝이 맞아야 하는 변경(예: backend와 LLM)은 나머지 레포까지 병합되어 검증을 통과할 때 함께 반영됩니다.
- 최신 검증 조합은 main의 submodule 포인터와 최신 `verified-*` 태그로 확인합니다.
- 수동 갱신이 필요하면 Actions → Sync를 직접 실행합니다(workflow_dispatch).

## 처음 받기

```bash
git clone --recurse-submodules https://github.com/mro-agent-proj/integration.git
cd integration
./scripts/fetch-data.sh          # RAG 전달본·원문 데이터 (gh 로그인 필요)
```

이미 받은 상태에서 이 레포가 고정한 커밋으로 맞추기: `git pull && git submodule update --init --recursive`

- 이 명령은 각 레포의 최신 `main`이 아니라, 이 레포가 **함께 검증해 고정한 커밋**을 내려받습니다. 최신 검증 조합은 봇이 자동으로 올리므로 `git pull`이면 됩니다.
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
- 기존 DB·큐·AI 상태 볼륨은 삭제하지 않습니다. 데이터 교체는 아래 "로컬 환경 갱신"을 따릅니다.

## 데이터

데이터는 용량과 저작권 때문에 git이 아니라 **비공개 레포 [`data`](https://github.com/mro-agent-proj/data)의 Release `data-2026-10-22`** 첨부파일로 둡니다(읽기 권한 필요). `scripts/fetch-data.sh`가 받아서 `backend/data/` 아래에 풉니다.

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
| `backend/data/seed/` | 항공사 3, 기체 20, 부서 8, 계정 15, 수리이력 v2 1,600 |
| `backend/data/eval/service/` | 현재 통합 평가 200건과 시드·평가셋 파일 manifest |
| `backend/data/eval/scenario/` | 접수 검증 6건 + 과거 23건 설명(실행용 JSONL 삭제) |
| `backend/data/eval/sdr/` | 단위 평가셋: FAA 공개 SDR 2019~2020 기반 검색 400 · LLM1 분류 200 · LLM2 부서 200 · JASC 매핑 548 |

## 평가

스택을 띄운 상태에서 실제 요청을 보내므로 DB에 기록이 쌓이고 OpenAI 비용이 발생합니다.
단일 AI 소비자에서는 순차 실행을 기본으로 합니다. 병렬 접수는 큐 대기로 TTL과 평가 시간 제한을 초과할 수 있습니다.

```bash
cd backend
python3 scripts/scenario_eval.py --workers 1           # 200건 + 접수 검증 6건
python3 scripts/scenario_eval.py --split test --workers 1
python3 scripts/scenario_eval.py --only SV-A-001,SV-B-002,V2
```

기본 결과는 `backend/data/eval/service/results/<시각>.json`입니다. [채점 정의](backend/data/eval/service/README.md)는
잘못된 부서·금지 이력·사람 검토 누락을 구분하며, 자동배정 정밀도에는 모든 ASSIGNED 결과를 포함합니다.
추적 조회 실패나 FINAL 누락은 평가 오류로 남겨 통과시키지 않습니다. 정상 HUMAN_REVIEW의 근거 목록 생략은 허용합니다.
실행 전 `maintenance_history_v2.csv`와 DB 이력의 동일성을 확인하세요. manifest/CI는 파일 조합만 검사합니다.
단위 평가(`sdr/`)의 사용법은 [별도 README](backend/data/eval/sdr/README.md)를 참고하세요.

## 로컬 환경 갱신

이미 띄워 둔 로컬 스택을 새 조합으로 올릴 때입니다.

1. 신규 접수를 중단하고 진행 중인 AI 실행·이벤트 반영을 완료합니다. `up.sh`는 실행을 자동으로 비우지 않습니다.
2. `git pull` 후 `git submodule update --init --recursive`로 검증된 포인터를 받습니다. 로컬 변경이 있으면 먼저 보존합니다.
3. Backend DB의 업무 시드 버전을 확인합니다. users가 있으면 SeedLoader가 업무 시드를 건너뛰므로,
   CSV 교체·이미지 재빌드만으로 기존 이력이 바뀌지 않습니다. Backend 담당자의 갱신 절차나 별도 빈 평가 DB를 사용합니다.
4. DB·RabbitMQ·AI 상태 볼륨을 보존하고 `./scripts/up.sh`로 이미지를 재빌드합니다.
   workflow 버전이 바뀐 경우 미완료 구버전 요청은 담당자가 결과·이벤트 상태를 확인하고 복구 방식을 결정합니다.
5. 네 서비스 health와 AI의 `AI_MODE=rabbit`, 두 MCP의 조회 계정·위임 토큰 설정을 확인한 뒤 접수를 재개합니다.

## 기록: 2026-10-23 조합과 검증 결과

자동 갱신을 도입하기 전 마지막으로 사람이 확인해 고정한 조합과, 그 조합으로 실행한 평가 결과입니다.

LLM1의 동일 기체 이력 비교와 직접 배정 경로는 유지합니다. 조사로 전환하면 LLM2는
LangGraph의 전용 `InvestigatorState`와 `llm2_context`만 받아 원본 신고·자체 RAG 자료로 판단합니다.
LLM1 분류·수리이력·B02 조회 기록은 LLM2에 전달되지 않고 B02 호출 및 HISTORY 인용도 차단됩니다.
`merge_for_review`가 LLM3 직전에 자료를 합치며 요청·버전·검색 범위·스냅샷을 검사합니다.
LLM3의 이력 확인과 최종 B02/R05 검증은 유지합니다.

재조사에는 LLM3 자유문장 대신 LLM2 자체 자료와 고정된 독립 재검토 지시를 사용합니다.
상세 보완 과제를 안전하게 전달하는 계약은 후속 과제입니다. [AI 판단 분리 문서](ai/docs/contextual-handoff.md)를 참고하세요.

R02 기본 검색은 동일 기본 모델·ceo/neo 세대, 추가 조사는 Backend가 허용한 A320 계열 범위입니다.
R05·Backend 최종 검증도 같은 목록을 따릅니다. R02 검색 범위 확대와 LLM2 이력 격리는 별개의 규칙입니다.
[모델 검색 범위 계약](ai/docs/MODEL_SCOPE.md)은 이번 변경에서 수정하지 않습니다.

| 구성 | 고정 커밋 | 포함 변경 |
| --- | --- | --- |
| Backend | `c6479cf` | V11 및 수리이력 v2 1,600건, 서비스 200건 평가·채점 보정 |
| dashboard | `1491195` | 기존 화면·API 유지, 현재 평가 입력 안내 |
| agent | `80554ce` | 기존 모델 범위·조회 계약 유지, B02 호출 역할 설명 정정 |
| LLM | `d83ee96` | LLM2 상태 격리·B02 차단, 현재 평가 안내와 폐기된 평가셋 기록 분리 |

2026-10-23 각 하위 저장소의 main에 위 커밋이 반영된 것을 확인한 조합입니다.
이후 조합은 Sync 워크플로가 통합 검증을 통과한 경우에만 커밋하고 `verified-*` 태그를 붙입니다(위 "운영 흐름").
위 표는 2026-10-23 기준 기록이며, 최신 조합은 submodule 포인터와 최신 `verified-*` 태그로 확인합니다. 폐기된 평가셋의 성적·기대 분기는 [AI 과거 기록](ai/docs/archive/legacy-scenarios-2026-10-21.md)에 분리했으며 현재 평가에 사용하지 않습니다.

2026-10-23 LLM2 격리 변경 때 구버전 workflow 체크포인트(`llm123-isolated-v2` / `llm23-isolated-v2`)는 자동 승계하지 않았고,
RAG 전달본은 `data-2026-10-22`를 그대로 썼습니다(재임베딩·새 Flyway DDL 불필요). R02 검색 정책·색인이 달라진 이전 커서는 재사용하지 않습니다.

### 검증 결과

실제 Backend → RabbitMQ → AI(gpt-5.4-mini) → HTTP MCP → Docker PostgreSQL 경로로
서비스 시나리오 200건과 별도 접수 검증 6건을 실행했습니다. 시스템 오류·클라이언트 시간 초과 0건,
접수 검증 6/6, LLM2 HISTORY 기록·B02 호출 0건이었습니다. AI 단위·회귀 테스트는 173건 통과했습니다.

| 지표 | 결과 | 범위 |
| --- | --- | --- |
| 전체 평가 통과 | 97/200 (48.5%) | 기대 상태·허용 부서·금지 이력 조건 |
| 자동배정 정밀도 | 96/145 (66.2%) | 사람 검토 기대인데 배정한 2건도 분모·실패에 포함 |
| LLM2 마지막 부서 일치 | 71/82 (86.6%) | 조사 출력이 있고 부서 배정이 정답인 사례 |
| 정답 부서 예측 후 보류 | 42건 | 적절한 사람 검토인지 별도 판단 필요; 성공에 합산하지 않음 |

200건 실행 이후 추가된 변경은 안내 문서와 오프라인 채점·파일 버전 검사입니다. 서비스 실행 코드와
시드·평가 입력은 해당 실행 기준 그대로입니다. 기존 결과 200건을 새 채점기로 다시 집계해 수치를 확인했습니다.
공유 DB에 대한 배포·복원을 수행했다는 의미는 아닙니다.

최초 로컬 검증에서는 Backend 의존성 다운로드 오류 때문에 호스트의 Gradle 캐시로 최신 소스를 빌드해
런타임 이미지를 만들었습니다. 이후 2026-10-25 Sync 워크플로가 깨끗한 GitHub 러너에서 저장소 Dockerfile로
backend를 빌드·기동해 온라인 빌드도 확인했습니다. 로컬 `.local-runtime-build` / `compose.override.yaml`은 배포 구성에 포함하지 않습니다.

통합 CI는 시작 스크립트의 실패 처리, 데이터 전달본 경로와 Backend 오프라인 채점·manifest 계약을 검사합니다.
실제 모델 호출·서비스 연결·실행 DB의 내용 검증은 별도입니다. 평가 정의는 [서비스 평가 README](backend/data/eval/service/README.md)를 따릅니다.

서비스 평가셋은 A 64/B 96/C 16/D 24, dev 80/test 120입니다. 라벨은 `not_reviewed` 161,
`needs_final_review` 24, `decided` 15건입니다. `expected`, `source`, `label_check`는 AI 입력에 포함하지 않습니다.
실제 항공사 운영 성능이나 개선 전후 성능으로 일반화하지 않습니다.

## 관리 규칙

- main에는 봇(GitHub App `mro-release-bot`)만 push합니다. 이 레포 자체(문서·스크립트)를 고칠 때는 관리자가 PR을 열어 병합합니다.
- RAG 전달본이 바뀌면 `data`에 새 Release 태그로 올리고 `scripts/fetch-data.sh` 기본 태그와 위 데이터 표를 고칩니다.
- 업무 시드·서비스 평가셋이 바뀌면 Backend의 manifest와 안내를 함께 갱신합니다. RAG 전달본 변경과 구분합니다.
- 보고서·발표자료 같은 산출물은 [deliverables](https://github.com/mro-agent-proj/deliverables)에서 관리합니다.
- `.env`·키·덤프 파일·개인 평가용 compose override는 커밋하지 않습니다.
