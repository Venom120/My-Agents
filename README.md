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

`AGENTS.md`, project instructions, and project `.opencode/agent-files/`
artifacts remain project-level concerns and are not bundled here.
