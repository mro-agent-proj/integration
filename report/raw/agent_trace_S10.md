| 순서 | 단계 | 종류 | 도구 / 이벤트 | 입력 요약 | 결과 |
|---|---|---|---|---|---|
| 1 | LLM1 분류 | 이벤트 | STAGE_STARTED | - | - |
| 2 | LLM1 분류 | MCP 호출 | `get_request_context` | {} | OK |
| 3 | LLM1 분류 | MCP 호출 | `search_departments` | {"limit": 20} | OK |
| 4 | LLM1 분류 | MCP 호출 | `get_aircraft_history` | {"limit": 100} | OK, 83건 (MH-001497, MH-001485, MH-001436) |
| 5 | LLM1 분류 | 이벤트 | STAGE_RESULT | - | ATA 32, 연결 이력 0건, sufficient=False → 조사로 |
| 6 | LLM2 조사 | 이벤트 | STAGE_STARTED | - | - |
| 7 | LLM2 조사 | MCP 호출 | `get_request_context` | {} | OK |
| 8 | LLM2 조사 | MCP 호출 | `search_departments` | {"query": "착륙 후 지상 이동 중 브레이크를 밟을 때마다 기체 전체에 반복적인 진동과 덜컹거림이 느껴짐.", "lim… | OK |
| 9 | LLM2 조사 | AI 판단 | NextStep: FINISH | 현재 신고 증상은 ATA 32(착륙장치/브레이크) 계통으로 볼 수 있는가, 그리고 동일 기체에서 관련 재발 이력이 없는 상태에… | 조사 종료 요청 → 근거 없음으로 반려(FINISH_WITHOUT_EVIDENCE) |
| 10 | LLM2 조사 | AI 판단 | NextStep: CALL → search_sdr_cases | 브레이크 사용 시 지상 활주 중 반복 진동/덜컹거림과 가장 유사한 SDR 사례가 있는지 확인해야 하는가?… | 도구 선택 |
| 11 | LLM2 조사 | MCP 호출 | `search_sdr_cases` | {"query": "brake vibration taxi", "search_mode": "explore", "limit": 5… | OK, 5건 (EV-SDR-ecdb00b3c949d4bc6ccd, EV-SDR-44c7c329863866bf6fa1, EV-SDR-dcf9ab1ad7ab73b11c9c) |
| 12 | LLM2 조사 | AI 판단 | NextStep: FINISH | 현재 증상은 ATA 32(유압·착륙장치)로 충분히 분류 가능한가, 그리고 브레이크 계통을 담당하는 부서(HYD)와 점검 포인트… | 조사 종료 요청 |
| 13 | LLM2 조사 | 이벤트 | STAGE_RESULT | - | ATA 32, 심각도 MEDIUM, 제안 HYD, 근거 EV-SDR-3ea130b4e691a19c88ad, EV-SDR-a8acf7f0e70d25a42461 |
| 14 | LLM3 검토 | 이벤트 | STAGE_STARTED | - | - |
| 15 | LLM3 검토 | MCP 호출 | `get_request_context` | {} | OK |
| 16 | LLM3 검토 | MCP 호출 | `search_departments` | {"query": "착륙 후 지상 이동 중 브레이크를 밟을 때마다 기체 전체에 반복적인 진동과 덜컹거림이 느껴짐.", "lim… | OK |
| 17 | LLM3 검토 | AI 판단 | NextStep: FINISH | 브레이크 적용 시 택싱 중 반복 진동·덜컹거림 증상이 HYD(ATA 32/29) 후속 점검 인계에 충분한가?… | 조사 종료 요청 |
| 18 | LLM3 검토 | 이벤트 | STAGE_RESULT | - | PASS → HYD |
| 19 | 최종 재검증 | MCP 호출 | `get_request_context` | {} | OK |
| 20 | 최종 재검증 | MCP 호출 | `search_departments` | {"query": "착륙 후 지상 이동 중 브레이크를 밟을 때마다 기체 전체에 반복적인 진동과 덜컹거림이 느껴짐.", "lim… | OK |
| 21 | 최종 재검증 | MCP 호출 | `get_evidence` | {"evidence_id": "EV-SDR-3ea130b4e691a19c88ad"} | OK, 1건 (EV-SDR-3ea130b4e691a19c88ad) |
| 22 | 최종 재검증 | MCP 호출 | `get_evidence` | {"evidence_id": "EV-SDR-a8acf7f0e70d25a42461"} | OK, 1건 (EV-SDR-a8acf7f0e70d25a42461) |
| 23 | 완료 | 이벤트 | COMPLETED | - | ASSIGN → HYD |
