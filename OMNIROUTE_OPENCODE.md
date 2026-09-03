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

## Strict separation of duties

The pipeline enforces a **strict separation of duties** to ensure safe
collaboration between stages and predictable user control:

- **Tester** is report-only. It only runs test commands, captures failures,
  and writes a diagnostic report. It never modifies code. If a test fails,
  the Tester presents findings to the Master and stops. The Master then
  presents the report to the user, waits for approval, and only then calls
  the **Implementer** to fix the issue. After the fix, the Tester is
  re-invoked to verify.
- **Optimizer** is report-only. It only analyzes code/configuration and
  writes an optimization report describing what could be improved. It
  never modifies code. If it identifies optimizations, it presents
  findings to the Master and stops. The Master presents the proposal to
  the user, waits for approval, and only then calls the **Implementer**
  to apply the change. After the change, the Optimizer is re-invoked to
  verify the improvement.
- **Implementer** is the only stage that may modify code or project
  files, and it does so only after the Master has presented a plan to
  the user and received explicit approval.
- The **Master** orchestrates sub-branches (fix / optimization) and only
  resumes the parent pipeline once a sub-branch is complete and verified.

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
