# OpenCode + OmniRoute Agent Pipeline

## Purpose

This repository defines a free-only OpenCode coding-agent system built around OmniRoute Engine Combos and a structured multi-stage pipeline.

The design separates four responsibilities:

1. **Master** — owns the user task, approval gates, pipeline orchestration, and final result. It is fixed to `omniroute/free-reasoning`.
2. **Model Router** — classifies the task and recommends one OmniRoute Engine Combo.
3. **Pipeline Workers** — execute the individual pipeline stages while remaining pinned to the approved combo.
4. **OmniRoute** — performs the actual provider/model routing, retries, cooldowns, resilience, and compression.

The Master remains fixed on `omniroute/free-reasoning` as the control plane. The
selected task route is used by the pipeline workers as the execution plane.

The model route is selected once for a user task and is then locked for the pipeline unless the Master explicitly changes it.

---

## Pipeline

The standard pipeline is:

```text
User Task
   │
   ▼
Master
   │
   ▼
Model Router
   │
   ├── route recommendation
   ├── task classification
   ├── improved task prompt
   └── pipeline mode
   │
   ▼
User Approval
   │
   ▼
Route Lock
   │
   ├── Researcher
   ├── Designer
   ├── Implementer
   ├── Optimizer
   ├── Tester
   └── Reviewer
   │
   ▼
Master Final Review
```

For simple tasks, the router may recommend `REDUCED` or `DIRECT` execution instead of the full pipeline.

---

## OmniRoute Routes

The six approved automatic routes are:

| Route | OmniRoute Combo | Intended Use |
|---|---|---|
| `omni-deep` | `free-coding-deep` | difficult implementation, architecture, complex debugging |
| `omni-standard` | `free-coding-standard` | normal coding and implementation |
| `omni-fast` | `free-coding-fast` | lightweight edits, simple tasks, quick iteration |
| `omni-reasoning` | `free-reasoning` | difficult reasoning, diagnosis, planning |
| `omni-context` | `free-context` | large-context analysis, repository-wide understanding |
| `omni-vision` | `free-vision` | image/UI/screenshot/visual tasks |

The existing `ClaudeCode-Stack` combo is not used by this automatic pipeline.

---

## Route Selection

The router uses this priority:

1. Visual/image/UI requirement → `omni-vision`
2. Large-context/repository-wide requirement → `omni-context`
3. Reasoning-heavy diagnosis/planning → `omni-reasoning`
4. Complex/deep coding → `omni-deep`
5. Normal coding → `omni-standard`
6. Lightweight/simple task → `omni-fast`

The router recommends a route; it does not execute the task.

---

## Pipeline Workers

Six hidden workers correspond to the six routes:

```text
pipeline-worker-deep
pipeline-worker-standard
pipeline-worker-fast
pipeline-worker-reasoning
pipeline-worker-context
pipeline-worker-vision
```

Each worker is pinned to exactly one OmniRoute combo.

The Master chooses the worker after the route has been approved and tells the worker which pipeline stage it is executing.

Workers do not:

- invoke other workers
- invoke the model router
- change their model
- select another route
- bypass the Master
- create an independent pipeline

Workers follow the canonical stage definitions already present in the repository.

---

## Stage Responsibilities

### Researcher

Investigates the problem, existing implementation, relevant documentation, constraints, and risks.

### Designer

Turns research into an implementation design, architecture, interfaces, and concrete execution plan.

### Implementer

Makes the required code/configuration changes according to the approved design.

### Optimizer

Reviews the implementation for correctness, simplicity, performance, maintainability, and unnecessary complexity.

### Tester

Validates the result through appropriate tests, commands, static checks, and targeted verification.

### Reviewer

Performs the final technical review and reports remaining issues, regressions, or release blockers.

---

## Shared Stage Artifacts

Pipeline work is recorded under:

```text
.opencode/agent-files/<stage>/
```

Typical files:

```text
PLAN.md
TODO.md
REPORT.md
```

Each stage should leave enough information for the next stage to understand what was done and what remains.

---

## Route Lock

The route is selected once for the user task.

Example:

```text
User task
   ↓
model-router
   ↓
omni-deep
   ↓
APPROVED
   ↓
route locked
   ↓
Researcher → Designer → Implementer → Optimizer → Tester → Reviewer
```

The pipeline should not independently re-route every stage. This keeps the execution consistent and prevents the route from changing unexpectedly in the middle of a task.

A new routing decision may be made only when the Master explicitly determines that the task requirements have materially changed.

---

## Approval Gates

The Master must obtain user approval before executing the selected route.

The Master may also pause for approval when:

- the task scope materially changes
- a destructive or risky operation is required
- an important architectural decision is ambiguous
- the pipeline discovers a requirement that conflicts with the original task

Routine stage-to-stage execution should not require unnecessary approval.

---

## Configuration Target

This repository targets the user's installed OpenCode configuration style and should not blindly migrate configuration syntax to a newer OpenCode generation.

The OpenCode agent definitions therefore remain compatible with the installed setup unless a deliberate migration is requested.

---

## Design Principle

The important separation is:

```text
Master
  = orchestration + approvals

Model Router
  = classification + route recommendation

Pipeline Worker
  = stage execution

OmniRoute
  = provider/model routing + resilience
```

No layer should silently take over the responsibilities of another layer.
