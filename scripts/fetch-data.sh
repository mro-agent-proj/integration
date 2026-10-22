#!/usr/bin/env bash
# GitHub Release에서 RAG 전달본·원문 데이터를 받아 backend/data/ 아래에 풉니다.
# 사용: ./scripts/fetch-data.sh [release 태그]   (기본: data-2026-10-22)
set -euo pipefail
TAG="${1:-data-2026-10-22}"
REPO="mro-agent-proj/mro-agent-integration"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

gh release download "$TAG" --repo "$REPO" --dir "$TMP"
(cd "$TMP" && shasum -a 256 -c SHA256SUMS)

DATA="$ROOT/backend/data"
mkdir -p "$DATA/rag-dump"
tar -xf "$TMP/sdr-jasc-amm_v1.tar"        -C "$DATA/rag-dump"   # SDR·JASC·AMM 복원용 덤프
tar -xf "$TMP/airbus-safety-first_v1.tar" -C "$DATA/rag-dump"   # 기술자료 복원용 덤프
tar -xf "$TMP/sdr-embeddings_v1.tar"      -C "$DATA/rag-dump"   # R02 하이브리드용 SDR 임베딩 (Flyway V7 필요)
tar -xf "$TMP/rag-csv.tar"                -C "$DATA"            # 확인용 CSV
echo "완료: $DATA/{rag-dump,rag-csv}"
