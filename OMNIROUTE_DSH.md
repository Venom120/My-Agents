# My-Agents + OmniRoute — DeepSeek Harness

This repository can also be installed as a DSH bundle.

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
Route-specific Pipeline Worker
 ↓
OmniRoute
 ↓
Provider / Model Pool
```

The Master remains on:

```text
omniroute/free-reasoning
```

There is no separate OmniRoute routing component or skill in this package.

The canonical pipeline remains:

```text
Researcher → Designer → Implementer → Optimizer → Tester → Reviewer
```

The six route-specific workers are:

```text
pipeline_worker_deep
pipeline_worker_standard
pipeline_worker_fast
pipeline_worker_reasoning
pipeline_worker_context
pipeline_worker_vision
```

Each DSH subagent tool has a fixed `agentOptions.provider/model` pair, so the
approved route remains locked during execution.

## Preset installation/update

The bundle contains:

```text
dsh/agent-presets/my-agents/
├── agent.cordis.yml
└── preset.yml
```

When the bundle is loaded, `dsh/sync-preset.js` synchronizes those files into:

```text
$DSH_HOME/.agent-presets/my-agents/
```

With the user's existing DSH setup, that is:

```text
/root/.dsh/.agent-presets/my-agents/
```

This makes the Git repository the source of truth for the user preset. Reloading
the bundle updates the generated user preset files.

## Important

The ZIP does not contain a `skills/` directory. Skills remain supported by the
OpenCode loader but are intentionally supplied separately.
