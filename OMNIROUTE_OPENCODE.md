# My-Agents + OmniRoute — OpenCode

My-Agents keeps the current OpenCode architecture: one Master control-plane
agent and six hidden route-specific pipeline workers.

## Agents

- `master`
- `pipeline-worker-deep`
- `pipeline-worker-standard`
- `pipeline-worker-fast`
- `pipeline-worker-reasoning`
- `pipeline-worker-context`
- `pipeline-worker-vision`

The six workers are execution routes, not six pipeline stages.

The canonical stages are:

```text
Researcher → Designer → Implementer → Optimizer → Tester → Reviewer
```

Those stages are instructions executed by the selected worker; they are not
separate OpenCode agent registrations.

## OmniRoute

| Route | OmniRoute combo | OpenCode worker |
|---|---|---|
| omni-deep | `omniroute/free-coding-deep` | `pipeline-worker-deep` |
| omni-standard | `omniroute/free-coding-standard` | `pipeline-worker-standard` |
| omni-fast | `omniroute/free-coding-fast` | `pipeline-worker-fast` |
| omni-reasoning | `omniroute/free-reasoning` | `pipeline-worker-reasoning` |
| omni-context | `omniroute/free-context` | `pipeline-worker-context` |
| omni-vision | `omniroute/free-vision` | `pipeline-worker-vision` |

The Master stays on `omniroute/free-reasoning`.

## Plugin loading

Add the Git repository/package to `opencode.jsonc` as an OpenCode plugin. The
package entry point is `plugin/load-agents.ts`.

The loader uses OpenCode's agent transform API to register every Markdown
agent under `agents/`. The ZIP intentionally does **not** contain a `skills/`
directory because this package no longer owns a model routing skill or any
other skill.
