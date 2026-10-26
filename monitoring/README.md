# 모니터링 (Prometheus + Grafana)

backend 네트워크(`BACKEND_NETWORK`, 기본 `backend_default`)에 붙어 서비스 이름으로 15초마다 수집합니다. `./scripts/up.sh`로 스택을 띄운 뒤 실행합니다.

```bash
docker compose -f monitoring/compose.yaml up -d
```

- Grafana: http://localhost:3000 (`admin` / `admin`. `GRAFANA_ADMIN_USER`·`GRAFANA_ADMIN_PASSWORD`로 변경). 데이터소스와 대시보드는 파일로 자동 등록되며 UI에서 바꾼 내용은 저장되지 않습니다.
- Prometheus: http://localhost:9090 (`Status → Targets`에서 수집 상태 확인)

## 수집 대상

| job | 주소 | 주요 지표 |
| --- | --- | --- |
| backend | `backend:8080/actuator/prometheus` | `mro_request_transitions_total{to,reason,actor}`, HTTP 요청·지연, JVM, Hikari |
| ai | `ai:8100/metrics` | `mro_ai_runs_total{outcome,reason}`, `mro_ai_run_duration_seconds`, `mro_ai_llm_calls_total{schema,result}`, `mro_ai_tool_calls_total{tool,outcome}` |
| mcp | `business-mcp:8101/metrics`, `rag-mcp:8102/metrics` | `mro_mcp_tool_calls_total{server,tool,status,error}`, `mro_mcp_tool_call_duration_seconds`, `mro_mcp_tool_warnings_total{code}` |
| rabbitmq | `rabbitmq:15692/metrics/per-object` | 큐별 `rabbitmq_queue_messages_ready`·`_unacked`, `rabbitmq_queue_consumers` |

## 대시보드 "MRO 정비요청 Agent"

| 구역 | 패널 |
| --- | --- |
| 서비스 상태 | 수집 대상 UP, 기간 내 실행 수, 자동 배정 비율, 실행 중, DLQ 적재 |
| AI 에이전트 | 결과·사유별 실행, 실행 시간 p50/p95, LLM 호출 결과·지연(스키마별), 도구 호출 |
| MCP 도구 서버 | 도구 호출 상태, 지연 p95, 경고 코드(`VECTOR_UNAVAILABLE` 등) |
| Backend · 큐 | 요청 상태 전이, API 요청 수·지연 p95, 큐 메시지·AI 소비자 수, JVM 힙, DB 커넥션 풀 |

대시보드 JSON은 `grafana/dashboards/mro-overview.json`입니다. 패널을 바꾸려면 Grafana에서 편집한 뒤 JSON을 내보내 이 파일에 덮어씁니다.

## 주의

- 지표 엔드포인트는 인증 없이 열려 있습니다. 레이블에는 상태·결과 코드, 스키마·도구 이름만 담고 요청 본문, 모델 출력, 사용자 정보는 담지 않습니다. 운영 배포에서는 게이트웨이에서 외부 접근을 막아야 합니다.
- AI·MCP 카운터는 컨테이너를 재시작하면 0부터 다시 셉니다. 대시보드는 `increase()`로 계산하므로 재시작 구간도 이어서 보입니다.
- 알림 규칙(Alertmanager)은 아직 없습니다.
