# DS 커스터마이징 작업 로그

oh-my-openagent(oh-my-opencode 포크)를 폐쇄망 사내 환경에 맞게 커스터마이징한 전체 내역입니다.  
브랜치: `ds-ultradus-branding`  
날짜: 2026-05-03

---

## 목차

1. [LLM 서버에 노출되는 정보 분석](#1-llm-서버에-노출되는-정보-분석)
2. [브랜딩 변경 — 표시 이름 전체 목록](#2-브랜딩-변경--표시-이름-전체-목록)
3. [변경된 파일 목록 및 상세 내용](#3-변경된-파일-목록-및-상세-내용)
4. [LLM 호출 빈도 제어 설정](#4-llm-호출-빈도-제어-설정)
5. [자동 업데이트 차단 방법](#5-자동-업데이트-차단-방법)
6. [오프라인 배포 패키지 구조](#6-오프라인-배포-패키지-구조)
7. [변경하지 않은 것 (주의)](#7-변경하지-않은-것-주의)

---

## 1. LLM 서버에 노출되는 정보 분석

### 조사 목적
폐쇄망 내부 LLM 서버의 모니터링에서 오픈소스 프로젝트 식별자가 노출될 수 있는지 확인

### HTTP 레벨 (헤더/메타데이터)

| 항목 | 노출 여부 | 내용 |
|------|----------|------|
| 커스텀 HTTP 헤더 | **조건부** | `x-initiator: agent` — GitHub Copilot 전용, 에이전트 이름 없음 |
| User-Agent | ❌ 없음 | SDK 기본값만 사용 |
| API 바디 메타데이터 | ❌ 없음 | 에이전트 식별 필드 없음 |
| `x-opencode-agent-name` | ✅ 표시명 | OpenCode 프레임워크가 주입하는 헤더. 현재 "DS-Atlas" 등 변경된 이름 사용 |

**결론**: HTTP 헤더 레벨에서는 원래 프로젝트 이름이 거의 노출되지 않음.

### 시스템 프롬프트 레벨

**노출됨** — 모든 에이전트가 system prompt 앞부분에 `<agent-identity>` 블록을 삽입함:

```xml
<!-- 변경 전 -->
<agent-identity>
Your designated identity for this session is "Sisyphus".
You are "Sisyphus" - Powerful AI Agent with orchestration capabilities from OhMyOpenCode.
</agent-identity>

<!-- 변경 후 -->
<agent-identity>
Your designated identity for this session is "Ultradus".
You are "Ultradus" - Powerful AI Agent with orchestration capabilities from DS-OhMyCloseAgent.
</agent-identity>
```

**위험도 평가**:
- 내부 LLM 서버가 system prompt를 **로깅하지 않음** → 🟢 안전
- 내부 LLM 서버가 system prompt를 **로깅함** → 🟡 변경된 이름("DS-*")이 기록됨
- **요청 횟수/속도 기준** 모니터링 → 🟢 HTTP 헤더에 에이전트 정보 없음

### 노출 위치 전체 목록 (변경 전)

| 파일 | 노출 문자열 | 종류 |
|------|-----------|------|
| `src/agents/sisyphus*.ts` | `"Sisyphus"`, `"OhMyOpenCode"` | system prompt identity |
| `src/agents/hephaestus/agent.ts` | `"Hephaestus"`, `"OhMyOpenCode"` | system prompt + description |
| `src/agents/atlas/agent.ts` 등 | `"Atlas"`, `"OhMyOpenCode"` | system prompt + description |
| `src/agents/prometheus/*.ts` | `"Prometheus"`, `"OhMyOpenCode"` | system prompt + description |
| `src/agents/*/agent.ts` | `"OhMyOpenCode"` | AgentConfig.description |
| `src/hooks/auto-update-checker/hook.ts` | `"Sisyphus on steroids is steering OpenCode."` | 시작 토스트 메시지 |
| `src/hooks/auto-update-checker/hook/spinner-toast.ts` | `"OhMyOpenCode {version}"` | 시작 토스트 제목 |
| `src/hooks/auto-update-checker/hook/update-toasts.ts` | `"OhMyOpenCode {ver}"`, `"OhMyOpenCode Updated!"` | 업데이트 알림 |
| `src/shared/agent-display-names.ts` | `"Hephaestus - Deep Agent"` 등 | UI 에이전트 선택 목록 |

---

## 2. 브랜딩 변경 — 표시 이름 전체 목록

### 에이전트 UI 선택 목록 (`AGENT_DISPLAY_NAMES`)

| Config Key (변경 안 함) | 변경 전 표시명 | 변경 후 표시명 |
|------------------------|--------------|--------------|
| `sisyphus` | Sisyphus - Ultraworker | **Ultradus - DS Ultra Worker** |
| `sisyphus-junior` | Sisyphus-Junior | **Ultradus-Junior** |
| `hephaestus` | Hephaestus - Deep Agent | **DS-Hephaestus - Deep Agent** |
| `prometheus` | Prometheus - Plan Builder | **DS-Prometheus - Plan Builder** |
| `atlas` | Atlas - Plan Executor | **DS-Atlas - Plan Executor** |
| `metis` | Metis - Plan Consultant | **DS-Metis - Plan Consultant** |
| `momus` | Momus - Plan Critic | **DS-Momus - Plan Critic** |
| `oracle` | oracle | **DS-Oracle** |
| `librarian` | librarian | **DS-Librarian** |
| `explore` | explore | **DS-Explore** |
| `multimodal-looker` | multimodal-looker | **DS-Multimodal-Looker** |
| `athena` | Athena - Council | **DS-Athena - Council** |
| `athena-junior` | Athena-Junior - Council | **DS-Athena-Junior - Council** |

### 시스템 프롬프트 identity 문자열

| 에이전트 | 변경 전 | 변경 후 |
|--------|--------|--------|
| sisyphus (5개 파일) | `"Sisyphus"` / `Ultradus` | `Ultradus` (이전 세션에서 변경됨) |
| sisyphus-junior (6개 파일) | `Sisyphus-Junior` | `Ultradus-Junior` |
| hephaestus | `Hephaestus` | `DS-Hephaestus` |
| atlas | `Atlas` | `DS-Atlas` |
| prometheus | `Prometheus` | `DS-Prometheus` |
| oracle | `Oracle` | `DS-Oracle` |

### "OhMyOpenCode" → "DS-OhMyCloseAgent" (system prompt 내 출처 문자열)

모든 에이전트의 system prompt에서 `from OhMyOpenCode` → `from DS-OhMyCloseAgent`  
변경 파일 19개:
- `sisyphus.ts`, `sisyphus/{claude-opus-4-7, default, gpt-5-4, gpt-5-5, kimi-k2-6}.ts`
- `sisyphus-junior/{default, gemini, gpt, gpt-5-3-codex, gpt-5-4, kimi-k2-6}.ts`
- `atlas/{agent, default-prompt-sections, gemini-prompt-sections, gpt-prompt-sections}.ts`
- `hephaestus/agent.ts`
- `prometheus/{gemini, gpt}.ts`

### AgentConfig.description 필드 (task 도구 에이전트 목록)

| 변경 전 | 변경 후 |
|--------|--------|
| `(Sisyphus-Junior - OhMyOpenCode)` | `(Ultradus-Junior - DS-OhMyCloseAgent)` |
| `(Hephaestus - OhMyOpenCode)` | `(Hephaestus - DS-OhMyCloseAgent)` |
| `(Atlas - OhMyOpenCode)` | `(Atlas - DS-OhMyCloseAgent)` |
| `(Oracle - OhMyOpenCode)` | `(Oracle - DS-OhMyCloseAgent)` |
| `(Prometheus - OhMyOpenCode)` | `(Prometheus - DS-OhMyCloseAgent)` |
| `(Explore - OhMyOpenCode)` | `(Explore - DS-OhMyCloseAgent)` |
| `(Librarian - OhMyOpenCode)` | `(Librarian - DS-OhMyCloseAgent)` |
| `(Metis - OhMyOpenCode)` | `(Metis - DS-OhMyCloseAgent)` |
| `(Momus - OhMyOpenCode)` | `(Momus - DS-OhMyCloseAgent)` |
| `(Multimodal-Looker - OhMyOpenCode)` | `(Multimodal-Looker - DS-OhMyCloseAgent)` |
| `(Ultradus - OhMyOpenCode)` | `(Ultradus - DS-OhMyCloseAgent)` |

### 시작/업데이트 토스트 메시지

| 위치 | 변경 전 | 변경 후 |
|------|--------|--------|
| 시작 토스트 제목 | `• OhMyOpenCode 3.17.11` | `• DS-OhMyCloseAgent 3.17.11` |
| 시작 메시지 | `Sisyphus on steroids is steering OpenCode.` | `DS-OhMyCloseAgent is steering OpenCode.` |
| 업데이트 알림 제목 | `OhMyOpenCode {버전}` | `DS-OhMyCloseAgent {버전}` |
| 업데이트 완료 알림 | `OhMyOpenCode Updated!` | `DS-OhMyCloseAgent Updated!` |

---

## 3. 변경된 파일 목록 및 상세 내용

### `src/shared/agent-display-names.ts`
- `AGENT_DISPLAY_NAMES`: 모든 에이전트 표시명에 "DS-" 접두사 추가
- `LEGACY_DISPLAY_NAMES`: 이전 표시명(변경 전)을 호환성 alias로 추가
  - 이유: 기존 세션이 "Prometheus - Plan Builder" 등 이전 이름을 참조할 경우 정상 동작 보장

### `src/agents/dynamic-agent-core-sections.ts`
- `buildAgentIdentitySection(agentName, roleDescription)`: 변경 없음 (함수 자체는 그대로)
- 호출부에서 넘기는 `agentName` 문자열만 변경

### `src/agents/sisyphus-junior/agent.ts`
- `description` 필드: `(Sisyphus-Junior - OhMyOpenCode)` → `(Ultradus-Junior - DS-OhMyCloseAgent)`

### `src/tools/delegate-task/subagent-resolver.ts`
- 에러 메시지: `"Sisyphus-Junior is spawned automatically..."` → `"Ultradus-Junior is spawned automatically..."`
- 주의: `SISYPHUS_JUNIOR_AGENT = getAgentDisplayName("sisyphus-junior")` = `"Ultradus-Junior"` (자동 반영)

### `src/hooks/auto-update-checker/hook.ts`
- `isSisyphusEnabled` 분기의 토스트 메시지 문자열 변경

### `src/hooks/auto-update-checker/hook/spinner-toast.ts`
- 시작 시 표시되는 스피너 토스트 제목 변경

### `src/hooks/auto-update-checker/hook/update-toasts.ts`
- 업데이트 감지/완료 토스트 제목 변경

### `src/plugin-handlers/prometheus-agent-config-builder.ts`
- Prometheus 동적 에이전트 description 접미사 변경

### `deploy/install.ps1`
- 완전 오프라인 설치 스크립트 (npm/Node.js/인터넷 불필요)
- `$PLUGIN_TAG = "3.17.11-ds"` — npm에 존재하지 않는 태그로 자동 업데이트 차단

### `deploy/plugin/package.json`
- 플러그인 메타데이터 (name, version, main 경로)
- UTF-8 BOM 없이 저장 (OpenCode JSON 파서 요구사항)

---

## 4. LLM 호출 빈도 제어 설정

> 상세 내용: `docs/llm-rate-limiting.md`  
> 폐쇄망 설정 예시: `docs/examples/closed-network.jsonc`

### background_task 핵심 설정값

| 설정 키 | 기본값 | 폐쇄망 권장값 | 상수 위치 |
|---------|--------|--------------|---------|
| `defaultConcurrency` | `5` | `1` | `src/features/background-agent/constants.ts` |
| `providerConcurrency.anthropic` | `3` | `1` | `docs/examples/default.jsonc` |
| `providerConcurrency.openai` | `3` | `1` | 위 동일 |
| `providerConcurrency.google` | `5` | `1` | 위 동일 |
| `providerConcurrency.opencode` | `10` | `1` | 위 동일 |
| `maxToolCalls` | `4000` | `300` | `DEFAULT_MAX_TOOL_CALLS` 상수 |
| `staleTimeoutMs` | `2,700,000` (45분) | `600,000` (10분) | `DEFAULT_STALE_TIMEOUT_MS` |
| `messageStalenessTimeoutMs` | `3,600,000` (60분) | `1,200,000` (20분) | `DEFAULT_MESSAGE_STALENESS_TIMEOUT_MS` |
| `taskTtlMs` | `1,800,000` (30분) | `900,000` (15분) | `TASK_TTL_MS` |
| `sessionGoneTimeoutMs` | `60,000` (1분) | `120,000` (2분) | `DEFAULT_SESSION_GONE_TIMEOUT_MS` |
| `circuitBreaker.enabled` | `true` | `true` | — |
| `circuitBreaker.consecutiveThreshold` | `20` | `5` | `DEFAULT_CIRCUIT_BREAKER_CONSECUTIVE_THRESHOLD` |

### runtime_fallback 핵심 설정값

| 설정 키 | 기본값 | 폐쇄망 권장값 |
|---------|--------|--------------|
| `enabled` | `true` | `false` |
| `max_fallback_attempts` | `3` | `1` |
| `cooldown_seconds` | `60` | `300` |
| `timeout_seconds` | `30` | `60` |

### 폐쇄망 최소 설정 (opencode 설정 파일에 추가)

설정 파일 위치: `~/.config/opencode/oh-my-opencode.jsonc` (전역) 또는 `.opencode/oh-my-opencode.jsonc` (프로젝트)

```jsonc
{
  "background_task": {
    "defaultConcurrency": 1,
    "providerConcurrency": { "anthropic": 1, "openai": 1, "google": 1, "opencode": 1 },
    "maxToolCalls": 300,
    "staleTimeoutMs": 600000,
    "circuitBreaker": { "enabled": true, "consecutiveThreshold": 5 }
  },
  "runtime_fallback": {
    "enabled": false
  }
}
```

---

## 5. 자동 업데이트 차단 방법

### 문제
OpenCode는 시작 시 Bun을 통해 `~/.cache/opencode/packages/bun.lock`을 참조해 플러그인을 업데이트한다.  
`oh-my-openagent@latest` 태그 사용 시 npm의 최신 버전(upstream)으로 덮어씌워져 커스터마이징이 무효화된다.

### 해결책: 존재하지 않는 npm 태그 사용

`opencode.json`에 등록할 때 npm에 존재하지 않는 버전 태그를 사용:

```json
{
  "plugin": [ "oh-my-openagent@3.17.11-ds" ]
}
```

- `3.17.11-ds` 태그는 npm에 없으므로 Bun이 resolve에 실패 → 업데이트 시도 자체가 차단됨
- 플러그인은 수동으로 배포한 캐시 경로(`~/.cache/opencode/packages/oh-my-openagent@3.17.11-ds/`)에서 로드됨

### 캐시 경로 구조

```
~/.cache/opencode/packages/
└── oh-my-openagent@3.17.11-ds/
    └── node_modules/
        └── oh-my-openagent/
            ├── package.json      ← 버전 정보
            └── dist/
                └── index.js      ← 빌드된 플러그인 번들 (단일 파일, 의존성 없음)
```

`dist/index.js`는 완전한 ESM 번들(4.17 MB)로 런타임 의존성이 없다.

---

## 6. 오프라인 배포 패키지 구조

### 파일 구성 (`deploy/` 디렉토리)

```
deploy/
├── install.ps1              # 설치 스크립트 (PowerShell 5 호환)
├── .gitignore               # *.exe 제외 (GitHub 100MB 제한)
├── plugin/
│   ├── package.json         # 플러그인 메타데이터 (UTF-8 no BOM)
│   └── dist/
│       └── index.js         # 빌드된 플러그인 번들 ← bun run build 후 복사
└── (별도 USB 배포)
    ├── opencode.exe          # OpenCode 바이너리 (174 MB)
    └── oh-my-opencode.exe   # oh-my-opencode CLI (129 MB)
```

### install.ps1 동작 순서

1. **파일 확인**: `opencode.exe`, `oh-my-opencode.exe`, `plugin/dist/index.js`, `plugin/package.json` 존재 여부
2. **bin 디렉토리 생성**: `~/.local/bin` 생성 + PATH 등록 (레지스트리)
3. **바이너리 복사**: `opencode.exe` → `~/.local/bin/opencode.exe` (실행 중이면 skip)
4. **플러그인 캐시 배포**:
   - `plugin/dist/index.js` → `~/.cache/opencode/packages/oh-my-openagent@3.17.11-ds/node_modules/oh-my-openagent/dist/index.js`
   - `plugin/package.json` → 동일 경로의 `package.json`
5. **opencode.json 등록**: `~/.config/opencode/opencode.json`에 `"oh-my-openagent@3.17.11-ds"` 추가

### PowerShell 5 호환성 주의사항

| 문제 | 원인 | 해결 |
|------|------|------|
| JSON BOM 오류 | PS5 `-Encoding UTF8`이 BOM 추가 | `New-Object System.Text.UTF8Encoding $false` |
| `$schema` 파싱 실패 | PS5 `ConvertFrom-Json`이 `$`를 변수로 해석 | regex 문자열 조작으로 대체 |
| ReadAllText 첫 바이트 손상 | CRLF 파일 round-trip 버그 | `Copy-Item` 직접 사용 |
| `??` 연산자 미지원 | PS5는 null-coalescing 없음 | `if ($null -eq ...)` 명시적 분기 |

---

## 7. 변경하지 않은 것 (주의)

아래 항목은 **절대 변경하면 안 됨** — OpenCode 플러그인 연동 및 내부 로직에 직결됨:

| 항목 | 예시 | 이유 |
|------|------|------|
| 플러그인 등록 이름 | `oh-my-openagent` | opencode.json 연동 식별자 |
| npm 패키지명 | `oh-my-opencode` | Bun 캐시 경로 |
| 내부 config key | `sisyphus`, `atlas`, `hephaestus` | YAML/JSON 설정 파일 키 |
| TypeScript 타입명 | `OhMyOpenCodeConfig`, `OhMyOpenCodeConfigSchema` | 코드 컴파일 |
| 함수/변수명 | `createSisyphusAgent`, `SISYPHUS_JUNIOR_AGENT` | 코드 로직 |
| 파일명 | `sisyphus-agent.ts` | 임포트 경로 |
| Zod 스키마 키 | `"sisyphus"` in agent enum | 설정 검증 |
| boulder 디렉토리명 | `.sisyphus/` | 파일시스템 경로 |
| 테스트 더미 데이터 | `agent-identity.test.ts` 내 문자열 | 테스트 입력값 (로직 무관) |

---

## 커밋 이력 요약 (ds-ultradus-branding 브랜치)

| 커밋 | 내용 |
|------|------|
| 초기 커밋들 | 내부 config key 복원 (sisyphus), 표시명만 Ultradus로 변경 |
| `96cf9dbe` | 오프라인 설치 스크립트 (`deploy/install.ps1`) |
| `0473a0e0` | LLM rate limiting 가이드 + 폐쇄망 설정 예시 |
| `24492726` | 시스템 프롬프트 에이전트 이름에 DS- 접두사 적용 |
| `193661b9` | system prompt 내 "OhMyOpenCode" → "DS-OhMyCloseAgent" |
| `8879fb13` | AgentConfig.description 내 "OhMyOpenCode" → "DS-OhMyCloseAgent" |
| `e6a6f088` | 시작/업데이트 토스트 메시지 DS 브랜딩 적용 |
| `e9a1ebbe` | AGENT_DISPLAY_NAMES 전체 DS- 접두사 추가 |
