# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**oh-my-openagent** (npm: `oh-my-opencode`) is an OpenCode plugin that extends the OpenCode AI coding environment with enterprise-grade agent orchestration, specialized tools, and multi-model support. It is a TypeScript plugin published to npm and compiled into 11 platform-specific binaries.

## Commands

**Runtime**: Bun only — never npm or yarn.

```bash
bun test                        # Run full test suite
bun run build                   # ESM build + TypeScript declarations + schema
bun run build:all               # Build + compile all 11 platform binaries
bun run build:binaries          # Platform-specific binaries only
bun run build:schema            # Regenerate JSON schema from Zod config
bun run build:model-capabilities # Refresh model capabilities from models.dev
bun run typecheck               # TypeScript strict check (tsc --noEmit)
bun run clean                   # Remove dist/

# CLI (after install)
bunx oh-my-opencode install     # Interactive setup
bunx oh-my-opencode doctor      # Health diagnostics
bunx oh-my-opencode run         # Non-interactive session
```

Tests are co-located with source as `*.test.ts`. CI test isolation is handled by `script/run-ci-tests.ts` via `mock.module()`.

## Architecture

### Plugin Initialization (`src/index.ts`)

The plugin initializes in 5 steps via `pluginModule.server()`:

1. `loadPluginConfig()` — JSONC parse → project/user merge → Zod validate → migrate
2. `createManagers()` — TmuxSessionManager, BackgroundManager, SkillMcpManager, ConfigHandler
3. `createTools()` — SkillContext + ToolRegistry (26 tools)
4. `createHooks()` — 52 hooks across 3 tiers (43 core + 7 continuation + 2 skill)
5. `createPluginInterface()` — 10 OpenCode hook handlers → PluginInterface

### 10 OpenCode Hook Handlers

| Handler | Purpose |
|---------|---------|
| `config` | 6-phase: provider → plugin-components → agents → tools → MCPs → commands |
| `tool` | Registers all 26 tools |
| `chat.message` | First-message setup, keyword detection (ultrawork/search/analyze) |
| `chat.params` | Anthropic effort level, think mode, runtime fallback |
| `chat.headers` | Copilot x-initiator header injection |
| `event` | Session lifecycle events, openclaw dispatch |
| `tool.execute.before` | Pre-tool hooks (file guard, label truncator, rules injector) |
| `tool.execute.after` | Post-tool hooks (output truncation, comment checker, hashline enhancer) |
| `experimental.chat.messages.transform` | Context injection, thinking validation |
| `experimental.session.compacting` | Context + todo preservation during compaction |

### Key Source Directories

- `src/agents/` — 11 agents: Sisyphus, Hephaestus, Oracle, Librarian, Explore, Atlas, Prometheus, Metis, Momus, Multimodal-Looker, Sisyphus-Junior
- `src/tools/` — 26 tools including `ast-grep`, `hashline-edit`, `interactive-bash`, `lsp`, `background-task`, `delegate-task`
- `src/hooks/` — 52 lifecycle hooks (3 tiers)
- `src/features/` — 19 feature modules (background-agent, tmux, skill-loader, mcp-oauth, etc.)
- `src/config/` — Zod v4 schema system (37 files)
- `src/shared/` — Utilities: logger (→ `/tmp/oh-my-opencode.log`), config, model resolution, cache
- `src/mcp/` — 3 built-in MCPs: websearch (Exa), context7 (docs), grep_app (GitHub search)
- `src/cli/` — CLI commands via Commander.js
- `src/plugin/` — OpenCode hook composition

### Config System

Multi-level JSONC merged at startup:
```
Project: .opencode/oh-my-opencode.jsonc
    ↓ deep merge (agents/categories) + Set union (disabled_*)
User: ~/.config/opencode/oh-my-opencode.jsonc
    ↓
Defaults: hard-coded in src/config/
```

Validated via Zod v4. Config keys use `snake_case`.

### Three-Tier MCP System

| Tier | Source | Mechanism |
|------|--------|-----------|
| 1 | `src/mcp/` | 3 remote HTTP MCPs (always available) |
| 2 | `.mcp.json` | Claude Code native integration |
| 3 | `SKILL.md` YAML front-matter | Skill-embedded, stdio/HTTP, per-session scope |

### Agent Category Routing

Agents are routed by category, each mapped to model configurations:
- `visual-engineering` → Frontend/UI models
- `deep` → Research + execution models
- `quick` → Single-file quick-fix models
- `ultrabrain` → Hard logic/architecture (GPT-5.4 xhigh)

Model resolution: override → category-default → provider-fallback → system-default

## Code Conventions (enforced by architecture rules)

- **Runtime**: Bun only — never Node.js APIs, never `npm`/`yarn`
- **Files**: kebab-case filenames and directories
- **Config keys**: snake_case
- **Exports**: `index.ts` barrel files only — no `utils.ts` or `helpers.ts`
- **Factories**: `createXXX()` pattern for tools, hooks, agents
- **Imports**: relative paths only — no path aliases (`@/` is forbidden)
- **Types**: no `as any`, `@ts-ignore`, or `@ts-expect-error`
- **File size**: 200 LOC soft limit per file
- **Comments**: No AI-generated comment patterns (enforced by comment checker hook)

## Telemetry

Anonymous PostHog telemetry is enabled by default. Disable with:
```bash
OMO_SEND_ANONYMOUS_TELEMETRY=0
# or
OMO_DISABLE_POSTHOG=1
```
