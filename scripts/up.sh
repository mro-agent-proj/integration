#!/usr/bin/env bash
# 전체 스택을 순서대로 띄웁니다: backend(실제 AI 모드) → MCP 두 개 → AI 서버.
# 먼저 ./scripts/fetch-data.sh 로 데이터를 받고, mcp/.env.mcp · ai/.env 를 채워 두세요.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for f in mcp/.env.mcp ai/.env; do
  [ -f "$ROOT/$f" ] || { echo "$f 가 없습니다. ${f}.example 을 복사해 채우세요." >&2; exit 1; }
done
[ -d "$ROOT/backend/data/rag-dump/sdr-jasc-amm_v2" ] || echo "경고: RAG 전달본이 없습니다. ./scripts/fetch-data.sh 를 먼저 실행하세요." >&2

(cd "$ROOT/backend" && AI_MODE=rabbit docker compose up -d --build)   # rag-restore가 데이터 복원 후 종료
echo "backend 준비 대기..."
backend_ready=false
for _ in $(seq 1 60); do
  if curl --connect-timeout 2 --max-time 3 -sf http://127.0.0.1:8080/actuator/health >/dev/null; then
    backend_ready=true
    break
  fi
  sleep 3
done
if [ "$backend_ready" != true ]; then
  echo "backend 준비 시간 초과: backend 로그와 RAG 복원 상태를 확인하세요." >&2
  exit 1
fi
(cd "$ROOT/mcp" && docker compose --env-file .env.mcp -f compose.mcp.yaml up -d --build --wait)
(cd "$ROOT/ai" && docker compose up -d --build --wait)

for service in backend:8080 business:8101 rag:8102 ai:8100; do
  name="${service%:*}"
  port="${service#*:}"
  path=/health/ready
  [ "$name" != backend ] || path=/actuator/health
  if ! curl --connect-timeout 2 --max-time 3 -sf "http://127.0.0.1:$port$path" >/dev/null; then
    echo "$name :$port 상태 확인 실패" >&2
    exit 1
  fi
  echo "$name :$port OK"
done
echo "화면: cd frontend && pnpm install && pnpm dev  →  http://localhost:5173"
