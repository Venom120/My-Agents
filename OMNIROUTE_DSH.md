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

### Strict separation of duties

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
