| 번호 | 등록부호 | 기대 경로 | 실제 경로 | 기대 부서 | 실제 부서 / 사유 | 근거 ID | 처리 시간 | 판정 |
|---|---|---|---|---|---|---|---|---|
| S01 | HL7701 | LLM1 → 배정 | LLM2 → LLM3 → 사람 검토 | SYS | 사람 검토 (SYSTEM_ERROR) | - | 10.8초 | ❌ |
| S02 | HL7702 | LLM1 → 배정 | LLM1 → 배정 | STR | STR | MH-001453 | 4.7초 | ✅ |
| S03 | HL7703 | LLM1 → 배정 | LLM1 → 배정 | AVI | AVI | MH-001487 | 3.7초 | ✅ |
| S04 | HL7704 | LLM1 → 배정 | LLM1 → 배정 | ENG | ENG | MH-001498, MH-000451, MH-000818 | 4.1초 | ✅ |
| S05 | HL7705 | LLM1 → 배정 | LLM1 → 배정 | CAB | CAB | MH-001482, MH-001203, MH-000751 | 4.1초 | ✅ |
| S06 | HL7706 | LLM1 → 배정 | LLM2 → LLM3 → 배정 | ENG | SYS | MH-001483, MH-001388 | 11.9초 | ❌ |
| S07 | HL7711 | LLM2 → LLM3 → 배정 | LLM2 → LLM3 → 배정 | AVI | FCS | MH-001530, MH-001571 | 12.2초 | ❌ |
| S08 | HL7719 | LLM2 → LLM3 → 배정 | LLM2 → LLM3 → 배정 | ELE | ELE | MH-001417 | 11.3초 | ✅ |
| S09 | HL7709 | LLM2 → LLM3 → 배정 | LLM1 → 배정 | ENG | ENG | MH-001447 | 3.6초 | ✅ |
| S10 | HL7717 | LLM2 → LLM3 → 배정 | LLM2 → LLM3 → 배정 | HYD | HYD | MH-001497 | 11.8초 | ✅ |
| S11 | HL7714 | LLM2 → LLM3 → 배정 | LLM2 → LLM3 → 사람 검토 | SYS | 사람 검토 (VALIDATION_FAILED) | - | 9.2초 | ❌ |
| S12 | HL7707 | LLM2 → LLM3 → 배정 | LLM2 → LLM3 → 배정 | STR | STR | MH-001475, MH-001462 | 11.7초 | ✅ |
| S13 | HL7708 | LLM2 → LLM3 → 배정 | LLM2 → LLM3 → 배정 | CAB | CAB | MH-001259 | 11.0초 | ✅ |
| S14 | HL7716 | LLM2 → LLM3 → 배정 | LLM2 → LLM3 → 배정 | SYS | SYS | MH-001303 | 11.8초 | ✅ |
| S15 | HL7718 | LLM2 → LLM3 → 배정 | LLM2 → LLM3 → 사람 검토 | SYS | 사람 검토 (SYSTEM_ERROR) | - | 10.0초 | ❌ |
| S16 | HL7710 | 재조사 후 사람 검토 | LLM2 → LLM3 → 사람 검토 | ENG / HYD / SYS 후보 | 사람 검토 (VALIDATION_FAILED) | - | 6.3초 | ✅ |
| S17 | HL7712 | 재조사 후 사람 검토 | LLM2 → LLM3 → 배정 | SYS / ENG 후보 | SYS | MH-001007 | 8.8초 | ❌ |
| S18 | HL7713 | 재조사 후 사람 검토 | LLM2 → LLM3 → 배정 | SYS / AVI 후보 | AVI | MH-001126 | 11.0초 | ❌ |
| S19 | HL7715 | 재조사 후 사람 검토 | LLM2 → LLM3 (재조사 1회) → 배정 | HYD / AVI 후보 | HYD | MH-001258 | 19.0초 | ❌ |
| S20 | HL7714 | 재조사 후 사람 검토 | LLM2 → LLM3 → 배정 | CAB / STR 후보 | STR | MH-001439 | 10.6초 | ❌ |
| S21 | HL7705 | LLM1 연결 금지 → LLM2 → LLM3 → 배정 | LLM2 → LLM3 → 배정 | HYD | HYD | MH-001305 | 11.8초 | ✅ |
| S22 | HL7703 | LLM1 연결 금지 → LLM2 → LLM3 → 배정 | LLM2 → LLM3 → 배정 | SYS | SYS | MH-001341 | 10.8초 | ✅ |
| S23 | HL7713 | LLM1 → 배정 (비행 조종) | LLM1 → 배정 | FCS | FCS | MH-001574, MH-001567 | 4.2초 | ✅ |
| V1~V6 | - | 422 보완 안내 | V1 422 · V2 422 · V3 422 · V4 422 · V5 422 · V6 422 | - | V1 tail_number:NOT_FOUND; V2 airline_code:MISMATCH(KAL); V3 aircraft_model:MISMATCH(A321-253N); V4 tail_number:INACTIVE; V5 symptom_text:REQUIRED; V6 tail_number:FORBIDDEN_AIRLINE | - | - | ✅ 6/6 |
