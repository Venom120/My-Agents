# My-Agents

Single source of truth for opencode agents and skills, shared across WSL,
Windows, and every project via a tiny loader plugin.

```
My-Agents/
├── agents/          one .md file per agent (frontmatter + prompt body)
├── skills/          one folder per skill containing SKILL.md
└── plugin/
    └── load-agents.ts   registers agents/*.md into opencode at startup
```

## Wiring it up (once per machine)

Add to the **global** config (`~/.config/opencode/opencode.json` on both
WSL and Windows — paths differ only by mount prefix).

### Option A — local checkout (recommended while editing agents/skills)

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "<repo>/plugin/load-agents.ts"
  ],
  "skills": {
    "paths": ["<repo>/skills"]
  }
}
```

| Environment | `<repo>` path |
|---|---|
| Windows | `D:/github/My-Agents` |
| WSL | `/mnt/d/github/My-Agents` |

### Option B — load directly from GitHub (no local clone needed)

The loader plugin (a proper opencode plugin package — see the repo's
`package.json` `main`) registers both `agents/` and `skills/` from the repo, so
a single plugin entry is enough. Copy **`opencode.example.jsonc`** from this repo
into your global config directory, then adjust the owner/branch if you forked or
renamed the repo:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "my-agents@git+https://github.com/Venom120/My-Agents.git#main"
  ]
}
```

With this setup you can delete the local clone and opencode will fetch the
whole repo as a plugin and register agents + skills on startup. To pin a
commit/branch, replace `#main` with e.g. `#v1.0.0` or a full commit SHA.

> Note: load the **whole repo**, not a subpath (e.g. `#main::path:plugin`); a
> subpath spec produces an empty checkout and nothing registers.

Restart opencode after changing config.

### External skills

The plugin supports **external skill repos** via plugin options (tuple form).
Each entry is auto-cloned (shallow, cached at
`~/.cache/opencode/external-skills/<name>/`) and registered on startup:

```jsonc
{
  "plugin": [
    ["my-agents@git+https://github.com/Venom120/My-Agents.git#main", {
      "externalSkills": [
        { "name": "shopify-ai-toolkit", "url": "https://github.com/Shopify/shopify-ai-toolkit.git", "ref": "main", "skillsPath": "skills" }
      ]
    }]
  ]
}
```

Fields: `name` (cache folder), `url` (git URL), `ref` (branch/tag/SHA, default
`main`), `skillsPath` (subfolder containing `SKILL.md` files, default `skills`).

To add more repos, append to `externalSkills` — no plugin code changes needed.
On first startup each repo is cloned; subsequent starts reuse the cache.

> You can also put an `external-skills.json` file in the repo root (same
> format) as a fallback if you prefer not to use plugin options.

## Editing

- **Change an agent:** edit `agents/<name>.md`, commit, push. Pull on other
  machines; every project picks it up on next opencode start.
- **Add an agent:** create `agents/<name>.md`. Frontmatter fields:
  `description`, `mode` (`subagent`/`primary`/`all`), `model`, `permission`
  (nested map of tool → allow/ask/deny). Body below the frontmatter is the
  system prompt. The filename is the agent name.
- **Add a skill:** create `skills/<skill-name>/SKILL.md` with `name` and
  `description` frontmatter, then commit/push.

## Agent Pipeline

Agents run as a handoff pipeline. Each agent owns a workspace under
`.opencode/agent-files/<agent>/` containing three files: `PLAN.md`,
`TODO.md`, and `REPORT.md`. The `REPORT.md` is the standard handoff
artifact consumed by the next stage.

    Researcher → Designer → Implementer → Optimizer → Tester → Reviewer → Master

### Direct OpenCode Specialists (Preserved)

These models are fixed assignments for specific pipeline agents — they do **not** route through OmniRoute.

| Agent | Direct Model | Role |
|---|---|---|
| researcher | `opencode/muse-spark-1.2-contributor-free` | Deep exploration, architecture research |
| designer | `opencode/nemotron-3-ultra-free` | Architecture/design reasoning |
| implementer | `opencode/mimo-v2.5-free` | Multi-file implementation |
| optimizer | `opencode/muse-spark-1.2-contributor-free` | Performance/security optimization |
| tester | `opencode/muse-spark-1.2-contributor-free` | Test creation, coverage analysis |
| reviewer | `opencode/mimo-v2.5-free` | Independent quality review |
| master | `opencode/nemotron-3-ultra-free` | Pipeline orchestration, final integration |

### OmniRoute Combos (Interchangeable Layer)

For workloads **outside** the fixed specialist domains, the `model-router` skill selects an OmniRoute combo:

| Combo | Strategy | Purpose |
|---|---|---|
| `agent-deep` | `priority` | Architecture, deep debugging, complex repo work, multi-file changes |
| `agent-coding` | `priority` | Implementation, refactoring, code generation, existing-code modifications |
| `agent-reasoning` | `priority` | Planning, architecture, trade-offs, difficult reasoning |
| `agent-vision` | `priority` | Screenshots, UI debugging, visual inspection, multimodal coding |
| `agent-context` | `context-optimized` | Whole-repo analysis, large documents, long sessions |
| `agent-fast` | `auto` | Small fixes, quick questions, simple sub-agent tasks |
| `agent-fallback` | `lkgp` | Recovery, last-known-good continuation |

**Hard constraints:** tool calling mandatory for agent combos; thinking variants precede no-think; free models only; removed providers (DeepSeek, Cerebras, Moonshot) never reintroduced; NVIDIA GPT-OSS without tool calling excluded.

The Master Agent invokes `model-router` for every new task. The router classifies the workload and recommends either a direct specialist or an OmniRoute combo, with an improved prompt.

The Master Agent orchestrates the pipeline and reconstructs state from the
root `AGENTS.md` / `PLAN.md` / `TODO.md`, the agent workspaces, and git
state. `REPORT.md` always uses the same filename per agent; the directory
identifies the agent.
