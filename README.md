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
WSL and Windows — paths differ only by mount prefix):

```jsonc
{
  // ...
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
