# oh-my-openagent 작업 세션 로그

> 작성일: 2026-05-01  
> 목적: DS 반도체 소프트웨어 엔지니어 사내 배포용 커스터마이징 작업 기록

---

## 사용자 요청 히스토리

1. `https://github.com/code-yeongyu/oh-my-openagent` 클론
2. `/init` — CLAUDE.md 생성
3. 로컬 빌드 및 기동 가능 여부 확인
4. Bun 설치 → 소스 빌드 → OpenCode 플러그인 등록
5. Gemini 인증 방법 안내
6. **Sisyphus 에이전트 이름 변경** (DS + Ultra 합성어 추천 요청)
7. 이름 후보 선정: Ultradus (Ultra + DS + `-us` 라틴 접미사) 채택
8. 모델 연결 없이 CLI에서 이름 변경 확인
9. **사내 폐쇄망 배포 패키지** 제작 (`deploy/` 폴더)

---

## 완료된 작업

### 1. 환경 구성

| 항목 | 내용 |
|------|------|
| 클론 위치 | `C:\OMA\oh-my-openagent` |
| Bun 버전 | 1.3.13 (설치 완료) |
| OpenCode 버전 | 1.2.27 → **1.14.30** 업그레이드 |
| 플러그인 등록 | `~/.config/opencode/opencode.json` → `"oh-my-openagent"` |

**npm link 체인:**
```
opencode.json: "oh-my-openagent"
  → npm global: oh-my-openagent (Junction)
    → oh-my-opencode (npm link)
      → C:\OMA\oh-my-openagent\dist\index.js  ← 로컬 빌드
```

**OpenCode 플러그인 캐시 위치:**
```
C:\Users\SDS\.cache\opencode\packages\oh-my-openagent@latest\node_modules\oh-my-openagent\dist\index.js
```
→ 빌드 후 이 파일도 교체해야 OpenCode가 변경사항을 인식함

---

### 2. Sisyphus → Ultradus 에이전트 이름 변경

#### 변경 내용 요약

| 항목 | 이전 | 이후 |
|------|------|------|
| config key | `sisyphus` | `ultradus` |
| 서브에이전트 config key | `sisyphus-junior` | `ultradus-junior` |
| UI 표시 이름 | `Sisyphus - Ultraworker` | `Ultradus - DS Ultra Worker` |
| 기본 에이전트 | `sisyphus` | `ultradus` |
| 상태 저장 디렉토리 | `.sisyphus/` | `.ultradus/` |
| 프롬프트 자기소개 | `"You are Sisyphus..."` | `"You are Ultradus..."` |

#### 변경된 파일 목록

```
src/config/schema/agent-names.ts          - enum 값 변경
src/agents/types.ts                        - BuiltinAgentName 타입 변경
src/shared/agent-display-names.ts          - 표시 이름 + 레거시 매핑
src/shared/migration/agent-names.ts        - 하위 호환 alias 추가
src/shared/model-requirements.ts           - AGENT_MODEL_REQUIREMENTS 키
src/cli/run/agent-resolver.ts              - DEFAULT_AGENT, CORE_AGENT_ORDER
src/cli/run/continuation-state.ts          - getAgentConfigKey 참조
src/hooks/agent-usage-reminder/hook.ts     - ORCHESTRATOR_AGENTS Set
src/features/boulder-state/constants.ts    - .sisyphus → .ultradus 디렉토리
src/shared/excluded-dirs.ts                - 제외 디렉토리 목록
src/agents/builtin-agents.ts               - agentSources 레지스트리 키
src/agents/builtin-agents/sisyphus-agent.ts - 내부 키 참조
src/agents/builtin-agents/general-agents.ts - skip 조건
src/agents/sisyphus.ts                     - 메타데이터, 프롬프트 자기소개
src/agents/sisyphus/default.ts             - 프롬프트 자기소개
src/agents/sisyphus/claude-opus-4-7.ts     - 프롬프트 자기소개
src/agents/sisyphus/gpt-5-4.ts             - 프롬프트 자기소개
src/agents/sisyphus/gpt-5-5.ts             - 프롬프트 자기소개
src/agents/sisyphus/kimi-k2-6.ts           - 프롬프트 자기소개
```

> **주의**: 파일명(`sisyphus.ts`, `sisyphus/` 디렉토리)은 내부 구현이므로 변경하지 않음.  
> config key와 표시 이름만 변경함.

#### 하위 호환성 (구 이름 → 새 이름 자동 매핑)

`src/shared/migration/agent-names.ts`에 등록됨:
```
sisyphus, Sisyphus, omo, OmO, "Sisyphus (Ultraworker)", "Sisyphus - Ultraworker"
  → 모두 "ultradus"로 자동 변환
sisyphus-junior, "Sisyphus-Junior"
  → "ultradus-junior"로 자동 변환
```

#### 빌드 명령

```bash
bun run build
# → dist/index.js 갱신
# → ~/.cache/opencode/packages/oh-my-openagent@latest/.../dist/index.js 도 교체 필요
```

---

### 3. 다른 에이전트 이름 변경 시 참고

동일한 패턴으로 변경 가능. 각 에이전트별 변경 위치:

| 에이전트 | config key | 관련 파일 |
|---------|------------|----------|
| Hephaestus | `hephaestus` | `src/agents/hephaestus.ts`, `src/agents/builtin-agents/hephaestus-agent.ts` |
| Prometheus | `prometheus` | `src/agents/prometheus.ts` (있는 경우) |
| Atlas | `atlas` | `src/agents/atlas.ts`, `src/agents/builtin-agents/atlas-agent.ts` |
| Oracle | `oracle` | `src/agents/oracle.ts` |
| Librarian | `librarian` | `src/agents/librarian.ts` |
| Explore | `explore` | `src/agents/explore.ts` |
| Metis | `metis` | `src/agents/metis.ts` |
| Momus | `momus` | `src/agents/momus.ts` |
| Multimodal-Looker | `multimodal-looker` | `src/agents/multimodal-looker.ts` |

**변경 시 체크리스트:**
- [ ] `src/config/schema/agent-names.ts` — `BuiltinAgentNameSchema`, `OverridableAgentNameSchema` enum
- [ ] `src/agents/types.ts` — `BuiltinAgentName` 타입
- [ ] `src/shared/agent-display-names.ts` — `AGENT_DISPLAY_NAMES` 키/값, `LEGACY_DISPLAY_NAMES`
- [ ] `src/shared/migration/agent-names.ts` — `AGENT_NAME_MAP`, `BUILTIN_AGENT_NAMES`
- [ ] `src/shared/model-requirements.ts` — `AGENT_MODEL_REQUIREMENTS` 키
- [ ] `src/agents/builtin-agents.ts` — `agentSources` 레지스트리
- [ ] `src/agents/<agent-name>.ts` — 프롬프트 자기소개 (`PROMPT_METADATA.promptAlias`, `"You are ..."`)
- [ ] `bun run typecheck` — 타입 오류 없는지 확인
- [ ] `bun run build` — 빌드
- [ ] OpenCode 캐시 교체

---

### 4. 폐쇄망 배포 패키지

**위치:** `C:\OMA\oh-my-openagent\deploy\`

```
deploy/
├── install.ps1                            # 원클릭 설치 스크립트
├── oh-my-opencode-3.17.11.tgz            # 플러그인 본체 (1.4MB)
└── oh-my-opencode-windows-x64-3.17.11.tgz # CLI 바이너리 (46MB)
```

**대상 PC 설치:**
```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

**스크립트 동작:**
1. `npm install -g` — CLI 바이너리 + 메인 패키지 글로벌 설치
2. OpenCode 플러그인 캐시 배포 (`~/.cache/opencode/packages/oh-my-openagent@latest/...`)
3. `~/.config/opencode/opencode.json` 플러그인 자동 등록

**배포 패키지 갱신 방법 (소스 수정 후):**
```bash
# 1. 소스 수정
# 2. 빌드
bun run build

# 3. 재패킹
npm pack --pack-destination deploy/

# 4. 구 tgz 삭제 후 새 tgz로 교체
# deploy/ 에 새 oh-my-opencode-x.x.x.tgz 생성됨
```

---

## 다음 세션에서 이어할 작업 (예상)

- 다른 에이전트 이름 변경 (Hephaestus, Atlas, Prometheus 등)
- 위 "에이전트 이름 변경 체크리스트" 참고

---

## 주요 경로 정리

| 항목 | 경로 |
|------|------|
| 소스 | `C:\OMA\oh-my-openagent\` |
| 빌드 산출물 | `C:\OMA\oh-my-openagent\dist\index.js` |
| OpenCode 설정 | `C:\Users\SDS\.config\opencode\opencode.json` |
| OpenCode 플러그인 캐시 | `C:\Users\SDS\.cache\opencode\packages\oh-my-openagent@latest\node_modules\oh-my-openagent\` |
| 배포 패키지 | `C:\OMA\oh-my-openagent\deploy\` |
| OpenCode 로그 | `C:\Users\SDS\.local\share\opencode\log\` |
| 플러그인 런타임 로그 | `/tmp/oh-my-opencode.log` |
