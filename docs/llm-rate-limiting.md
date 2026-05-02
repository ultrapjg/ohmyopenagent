# LLM 호출 빈도 제어 설정 가이드

oh-my-openagent(oh-my-opencode)에서 LLM 호출 빈도를 제어하는 설정 항목과 기본값, 폐쇄망 권장값을 정리한 문서입니다.

---

## 설정 파일 위치

| 범위 | 경로 |
|------|------|
| 프로젝트별 | `.opencode/oh-my-opencode.jsonc` |
| 사용자 전역 | `~/.config/opencode/oh-my-opencode.jsonc` |

---

## background_task — 백그라운드 에이전트 동시 실행 제어

백그라운드 태스크(delegate-task, background-task 도구로 생성되는 서브에이전트)의 동시 LLM 호출 수를 제어합니다.

| 설정 키 | 기본값 | 폐쇄망 권장값 | 설명 |
|---------|--------|--------------|------|
| `defaultConcurrency` | `5` | `1` | 동시 실행 백그라운드 태스크 최대 수 |
| `providerConcurrency.anthropic` | `3` | `1` | Anthropic API 동시 호출 수 |
| `providerConcurrency.openai` | `3` | `1` | OpenAI API 동시 호출 수 |
| `providerConcurrency.google` | `5` | `1` | Google API 동시 호출 수 |
| `providerConcurrency.opencode` | `10` | `1` | OpenCode 라우터 동시 호출 수 |
| `maxToolCalls` | `4000` | `300` | 세션당 최대 도구 호출 횟수 (무한 루프 방지) |
| `staleTimeoutMs` | `2700000` (45분) | `600000` (10분) | 진행 없는 태스크를 stale로 처리하는 시간 |
| `messageStalenessTimeoutMs` | `3600000` (60분) | `1200000` (20분) | 메시지 응답 대기 최대 시간 |
| `taskTtlMs` | `1800000` (30분) | `900000` (15분) | 태스크 전체 최대 수명 |
| `sessionGoneTimeoutMs` | `60000` (1분) | `120000` (2분) | 세션 소멸 감지 대기 시간 |
| `circuitBreaker.enabled` | `true` | `true` | 연속 실패 시 자동 차단 |
| `circuitBreaker.consecutiveThreshold` | `20` | `5` | 차단 전 허용 연속 실패 횟수 |

---

## runtime_fallback — API 오류 시 폴백 제어

API 호출 실패(rate limit, timeout 등) 시 폴백 모델로 재시도하는 동작을 제어합니다.

| 설정 키 | 기본값 | 폐쇄망 권장값 | 설명 |
|---------|--------|--------------|------|
| `enabled` | `true` | `false` | 폴백 자동 재시도 활성화 여부 |
| `max_fallback_attempts` | `3` | `1` | 최대 폴백 재시도 횟수 |
| `cooldown_seconds` | `60` | `300` | 재시도 사이 대기 시간 (초) |
| `timeout_seconds` | `30` | `60` | 단일 호출 타임아웃 (초, 0=비활성화) |

---

## 주요 설정 설명

### defaultConcurrency
백그라운드에서 동시에 실행되는 서브에이전트(LLM 세션) 수를 제한합니다.  
폐쇄망 내부 LLM 서버는 동시 연결이 제한적이므로 `1`로 설정하면 순차 실행됩니다.

### providerConcurrency
각 AI 제공자별로 동시에 열리는 LLM 호출 수를 제한합니다.  
내부 LLM 서버(예: opencode 라우터)가 부하에 민감한 경우 `1`로 설정합니다.

### maxToolCalls
하나의 세션에서 실행할 수 있는 도구 호출(LLM 요청 포함) 총 횟수 상한선입니다.  
폐쇄망에서는 배치 호출이 내부 서버 부하를 급격히 높일 수 있으므로 낮게 설정합니다.

### circuitBreaker
연속 실패가 임계값을 초과하면 해당 프로바이더로의 요청을 일시 차단합니다.  
임계값을 낮추면 내부 LLM 서버 장애 상황에서 더 빨리 차단되어 과부하를 방지합니다.

### runtime_fallback
API 오류 시 다른 모델로 자동 전환합니다.  
폐쇄망에서는 대체 모델이 없거나 동일 서버로 재요청되어 의미 없는 재시도가 반복될 수 있으므로 비활성화를 권장합니다.

---

## 설정 우선순위

```
프로젝트 설정 (.opencode/oh-my-opencode.jsonc)
    ↓ 덮어씀
사용자 전역 설정 (~/.config/opencode/oh-my-opencode.jsonc)
    ↓ 덮어씀
코드 기본값 (src/features/background-agent/constants.ts)
```

---

## 참고 파일

- `docs/examples/default.jsonc` — 일반 개발 환경 기본 설정 예시
- `docs/examples/closed-network.jsonc` — 폐쇄망 환경 권장 설정 예시
- `src/features/background-agent/constants.ts` — 기본값 상수 정의
- `src/config/schema/background-task.ts` — 설정 스키마 정의
- `src/config/schema/runtime-fallback.ts` — 폴백 스키마 정의
