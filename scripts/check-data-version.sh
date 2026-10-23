#!/usr/bin/env bash
# fetch-data.sh가 받는 전달본 폴더를, 고정된 backend의 복원 스크립트가 실제로 찾는지 확인합니다.
# (submodule 포인터와 Release 데이터 버전이 어긋나면 새 설치에서 복원이 조용히 건너뛰어집니다.)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
status=0
while read -r package; do
    [ "$package" = "rag-csv" ] && continue  # 확인용 CSV, 복원 대상 아님
    if grep -rqs "data/rag-dump/$package" "$ROOT/backend/scripts"; then
        echo "OK   $package"
    else
        echo "FAIL $package: 고정된 backend 복원 스크립트가 이 전달본을 찾지 않습니다 (submodule 포인터 확인)" >&2
        status=1
    fi
done < <(grep -oE 'TMP/[a-z0-9_-]+[.]tar' "$ROOT/scripts/fetch-data.sh" | sed 's#TMP/##; s#[.]tar##')
exit "$status"
