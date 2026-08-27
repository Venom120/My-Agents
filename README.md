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
    "github:Venom120/My-Agents#main"
  ]
}
```

With this setup you can delete the local clone and opencode will fetch the
whole repo as a plugin and register agents + skills on startup. To pin a
commit/branch, replace `#main` with e.g. `#v1.0.0` or a full commit SHA.

> Note: load the **whole repo**, not a subpath (e.g. `#main::path:plugin`); a
> subpath spec produces an empty checkout and nothing registers.

Restart opencode after changing config.

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

| Agent | Workspace |
|---|---|
| researcher | `.opencode/agent-files/researcher/` |
| designer | `.opencode/agent-files/designer/` |
| implementer | `.opencode/agent-files/implementer/` |
| optimizer | `.opencode/agent-files/optimizer/` |
| tester | `.opencode/agent-files/tester/` |
| reviewer | `.opencode/agent-files/reviewer/` |
| master | `.opencode/agent-files/master/` |

The Master Agent orchestrates the pipeline and reconstructs state from the
root `AGENTS.md` / `PLAN.md` / `TODO.md`, the agent workspaces, and git
state. `REPORT.md` always uses the same filename per agent; the directory
identifies the agent.
