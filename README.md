# My-Agents

My-Agents is the shared agent architecture for OpenCode and DeepSeek Harness
using OmniRoute as the model routing layer.

## Architecture

```text
User
  ↓
Master
  ↓
Route Selection
  ↓
User Approval
  ↓
Route Lock
  ↓
Pipeline Worker
  ↓
OmniRoute
  ↓
Provider / Model Pool
```

## Pipeline

There are **six canonical pipeline stages**:

```text
Researcher
    ↓
Designer
    ↓
Implementer
    ↓
Optimizer
    ↓
Tester
    ↓
Reviewer
```

There are **six route workers**:

```text
pipeline-worker-deep
pipeline-worker-standard
pipeline-worker-fast
pipeline-worker-reasoning
pipeline-worker-context
pipeline-worker-vision
```

The route workers are not additional pipeline stages. They are six fixed
execution-model variants that execute the currently assigned stage.

### Strict Separation of Duties

The pipeline enforces a **strict separation of duties** to ensure safe
collaboration between stages and predictable user control:

| Stage | Role | Modifies code? |
|---|---|---|
| **Researcher** | Read-only investigation and scoping. | ❌ No |
| **Designer** | Read-only design and planning. | ❌ No |
| **Implementer** | **Only stage** that modifies code or project files. | ✅ Yes |
| **Optimizer** | Read-only analysis that produces an optimization report. | ❌ No |
| **Tester** | Read-only; runs commands and produces a failure report. | ❌ No |
| **Reviewer** | Read-only validation of the final result. | ❌ No |

Key rules:

- **Tester** never modifies code. If a test fails, the Tester writes a
  diagnostic report and stops. The Master then presents the report to the
  user, waits for approval, and only then calls the **Implementer** to
  fix the issue. After the fix, the Tester is re-invoked to verify.
- **Optimizer** never modifies code. If it identifies an optimization,
  it writes a report and stops. The Master presents the proposal to the
  user, waits for approval, and only then calls the **Implementer** to
  apply the change. After the change, the Optimizer is re-invoked to
  verify the improvement.
- **Implementer** is the only stage that may modify code or project
  files, and it does so only after the Master has presented a plan to
  the user and received explicit approval.
- The **Master** orchestrates sub-branches (fix / optimization) and only
  resumes the parent pipeline once a sub-branch is complete and verified.

## Routes

| Route | OmniRoute combo | Worker |
|---|---|---|
| `omni-deep` | `free-coding-deep` | `pipeline-worker-deep` |
| `omni-standard` | `free-coding-standard` | `pipeline-worker-standard` |
| `omni-fast` | `free-coding-fast` | `pipeline-worker-fast` |
| `omni-reasoning` | `free-reasoning` | `pipeline-worker-reasoning` |
| `omni-context` | `free-context` | `pipeline-worker-context` |
| `omni-vision` | `free-vision` | `pipeline-worker-vision` |

The Master is fixed to `omniroute/free-reasoning`.

## OpenCode

The package entry point is:

```text
plugin/load-agents.ts
```

It loads the Markdown agents and preserves the existing skill-loading and
external-skill-repository support.

The ZIP intentionally contains no `skills/` directory.

## DeepSeek Harness

The same repository is a DSH bundle. Its DSH preset is stored in:

```text
dsh/agent-presets/my-agents/
```

The bundle synchronizes it into:

```text
$DSH_HOME/.agent-presets/my-agents/
```

so the installed user preset is generated/updated from this repository.

## Files

```text
agents/
├── master.md
├── pipeline-worker-deep.md
├── pipeline-worker-standard.md
├── pipeline-worker-fast.md
├── pipeline-worker-reasoning.md
├── pipeline-worker-context.md
├── pipeline-worker-vision.md
└── subagent-prompt-template.md

plugin/
└── load-agents.ts

dsh/
├── cordis.patch.yml
├── sync-preset.js
└── agent-presets/
    └── my-agents/
        ├── agent.cordis.yml
        └── preset.yml
```

`AGENTS.md`, project instructions, and project `.agents/agent-files/`
artifacts remain project-level concerns and are not bundled here.
