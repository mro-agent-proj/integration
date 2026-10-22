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

mkdir -p "$ROOT/backend/data/rag"
tar -xf "$TMP/rag-data-v1-20261021.tar" -C "$ROOT/backend/data/rag"
tar -xf "$TMP/rag-tech-v1-20261021.tar" -C "$ROOT/backend/data/rag"
tar -xf "$TMP/rag-source-20261022.tar"  -C "$ROOT/backend/data"
echo "완료: $ROOT/backend/data/{rag,source}"
