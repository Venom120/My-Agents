# OpenCode + OmniRoute Pipeline Architecture Plan

## 1. Objective

Build a clean OpenCode development-agent architecture in which:

- the Master owns orchestration
- the model-router selects an appropriate free OmniRoute Engine Combo
- the user approves the route
- the approved route is locked for the task
- hidden pipeline workers execute the development stages
- OmniRoute remains responsible for provider/model routing and resilience

The goal is to combine intelligent model routing with the existing Researcher → Designer → Implementer → Optimizer → Tester → Reviewer workflow without creating a separate route for every stage.

---

## 2. Architecture

```text
                         USER
                           │
                           ▼
                        MASTER
                           │
                           ▼
                    MODEL ROUTER
                           │
             ┌─────────────┼─────────────┐
             │             │             │
          route         pipeline      improved
       recommendation     mode          prompt
             │             │             │
             └─────────────┴─────────────┘
                           │
                           ▼
                     USER APPROVAL
                           │
                           ▼
                      ROUTE LOCK
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
       WORKER           WORKER           WORKER
       stage N          stage N+1        stage N+2
          │                │                │
          └────────────────┼────────────────┘
                           ▼
                       OMNIROUTE
                           │
                           ▼
                 PROVIDER / MODEL POOL
```

---

## 3. Master Model Strategy

The Master uses a stable reasoning-oriented OmniRoute combo:

```text
model: omniroute/free-reasoning
```

The Master is intentionally **not** dynamically routed through the six task routes.

This creates two distinct planes:

```text
CONTROL PLANE
Master
  ↓
omniroute/free-reasoning

EXECUTION PLANE
Pipeline Worker
  ↓
approved route
  ↓
OmniRoute Engine Combo
```

This separation keeps orchestration behavior consistent while allowing the actual
pipeline execution to use the route best suited to the user's task.

The Master should remain on `free-reasoning` even when the selected execution route
is `omni-fast`, `omni-context`, `omni-vision`, or another route.

---

## 4. Separation of Responsibilities

### Master

The Master is the top-level controller.

It is responsible for:

- understanding the user request
- invoking the router
- presenting the route recommendation
- obtaining approval
- locking the route
- selecting the correct worker
- sequencing pipeline stages
- checking reports
- handling approval gates
- producing the final result

The Master does not manually choose raw provider models.

### Model Router

The model-router is an advisor.

It is responsible for:

- classifying the task
- choosing one approved route
- choosing the appropriate pipeline mode
- explaining the choice
- producing an improved execution prompt

It does not execute the task.

### Pipeline Worker

A worker is an execution wrapper around one route.

It is responsible for:

- executing the stage assigned by the Master
- following the canonical stage definition
- producing stage artifacts
- reporting results to the Master

It does not perform routing or orchestration.

### OmniRoute

OmniRoute is the runtime routing layer.

It handles:

- provider/model selection within the selected Engine Combo
- retries
- cooldowns
- resilience
- model lockout
- request queueing
- compression
- provider health and related routing behavior

---

## 5. Six Automatic Routes

The architecture exposes exactly six automatic routes:

| Route | Combo | Primary Use |
|---|---|---|
| `omni-deep` | `free-coding-deep` | complex coding and difficult implementation |
| `omni-standard` | `free-coding-standard` | normal coding and implementation |
| `omni-fast` | `free-coding-fast` | simple and quick tasks |
| `omni-reasoning` | `free-reasoning` | difficult analysis and diagnosis |
| `omni-context` | `free-context` | large-context/repository-wide tasks |
| `omni-vision` | `free-vision` | screenshots, images, and visual UI work |

The existing `ClaudeCode-Stack` combo remains outside automatic routing.

---

## 6. Why Six Workers Instead of One Worker Per Stage

OpenCode's task/subagent mechanism does not provide the clean architecture we want for dynamically selecting an arbitrary model for every invocation.

Therefore, use six fixed hidden workers:

```text
pipeline-worker-deep
pipeline-worker-standard
pipeline-worker-fast
pipeline-worker-reasoning
pipeline-worker-context
pipeline-worker-vision
```

Each worker is permanently associated with one OmniRoute combo.

The worker receives the stage dynamically from the Master.

This avoids creating:

```text
6 routes × 6 stages = 36 worker definitions
```

Instead, there are only six workers.

For example:

```text
approved route = omni-deep

pipeline:
Researcher
   ↓
pipeline-worker-deep
   ↓
Designer
   ↓
pipeline-worker-deep
   ↓
Implementer
   ↓
pipeline-worker-deep
...
```

The worker is therefore a route wrapper, not a duplicate stage definition.

---

## 7. Canonical Pipeline

The normal pipeline is:

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

Existing canonical stage agent definitions remain the source of truth for the actual responsibilities of those stages.

The new workers should not duplicate those prompts.

Instead, the Master tells a worker:

```text
Route: omni-deep
Stage: Implementer

Execute the Implementer stage according to the canonical
Implementer agent definition.

Task:
<approved task>

Previous report:
<previous stage report>
```

---

## 8. Route Selection

The model-router uses this priority:

```text
vision
  ↓
context
  ↓
reasoning
  ↓
deep coding
  ↓
standard coding
  ↓
fast/simple
```

### Vision

Choose `omni-vision` when the task depends materially on images, screenshots, visual layouts, or visual UI interpretation.

### Context

Choose `omni-context` when understanding a large repository or many interacting files is the dominant difficulty.

### Reasoning

Choose `omni-reasoning` for diagnosis, ambiguous behavior, difficult planning, or analysis-heavy tasks.

### Deep

Choose `omni-deep` for complex coding, architecture, difficult refactoring, and hard implementation work.

### Standard

Choose `omni-standard` for ordinary coding and configuration tasks.

### Fast

Choose `omni-fast` for small, straightforward tasks.

---

## 9. Pipeline Mode

The router also returns one of:

### FULL

Use:

```text
Researcher → Designer → Implementer → Optimizer → Tester → Reviewer
```

### REDUCED

Use only the stages that materially help.

### DIRECT

Handle trivial work directly rather than creating unnecessary orchestration overhead.

The Master makes the final execution decision after the route is approved.

---

## 10. Route Lock

Routing occurs once for the user task.

Example:

```text
User request
     ↓
Router
     ↓
omni-deep
     ↓
User approves
     ↓
ROUTE LOCKED
     ↓
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

All stages use the same approved route.

This gives the pipeline:

- consistent model behavior
- predictable execution
- less routing overhead
- easier debugging
- fewer unexpected model changes

A new route should be selected only when the Master determines that the requirements have materially changed.

---

## 11. Stage Artifacts

The pipeline uses:

```text
.opencode/agent-files/<stage>/
```

with:

```text
PLAN.md
TODO.md
REPORT.md
```

The exact contents can follow the existing repository conventions.

The important rule is that each stage leaves a report that the next stage can consume.

---

## 12. Stage Handoff

A stage handoff should contain:

```text
Original objective
Approved route
Pipeline mode
Current stage
Previous stage report
Relevant files/context
Current constraints
Expected output
```

The next worker should not have to reconstruct the entire history from scratch when a concise report already exists.

---

## 13. Approval Flow

The Master presents:

```text
ROUTE
omni-deep

COMBO
omniroute/free-coding-deep

PIPELINE
FULL

WHY
The task requires complex implementation and debugging.

IMPROVED PROMPT
<router-generated prompt>
```

The Master waits for approval.

After approval:

```text
route = locked
pipeline = approved
```

Routine transitions do not require repeated approval.

The Master pauses only when:

- scope materially changes
- a destructive operation is required
- a major architecture decision is ambiguous
- a discovered requirement conflicts with the original request

---

## 14. Worker Rules

Every pipeline worker must:

- remain pinned to its configured OmniRoute combo
- execute only the stage assigned by the Master
- follow the canonical stage definition
- write/report the expected artifacts
- report blockers instead of silently changing scope

Every worker must not:

- invoke model-router
- invoke another pipeline worker
- select another model
- change its route
- create a second pipeline
- override the Master

---

## 15. Failure Handling

If a worker fails:

1. The worker reports the failure.
2. The Master inspects the report/error.
3. The Master may retry the same stage.
4. If the route itself appears unsuitable, the Master may request a new routing decision.
5. A new route is treated as a meaningful change and should be surfaced to the user before continuing.

OmniRoute remains responsible for normal provider-level retries, cooldowns, and fallback behavior inside the selected combo.

---

## 16. Why Routing Once Is Better

Re-routing every stage would allow:

```text
Researcher → context
Designer   → reasoning
Implementer → deep
Optimizer  → standard
Tester     → fast
Reviewer   → reasoning
```

That sounds flexible, but it creates several problems:

- inconsistent reasoning style
- route churn
- harder debugging
- more complicated state management
- harder user approval
- less predictable pipeline behavior

The preferred design is:

```text
one task
  ↓
one route
  ↓
one route lock
  ↓
multiple stages
```

The Master can still intentionally change the route if the task fundamentally changes.

---

## 17. Implementation Files

The implementation consists of:

```text
README.md
agents/master.md
skills/model-router/SKILL.md

agents/pipeline-worker-deep.md
agents/pipeline-worker-standard.md
agents/pipeline-worker-fast.md
agents/pipeline-worker-reasoning.md
agents/pipeline-worker-context.md
agents/pipeline-worker-vision.md

OMNIROUTE_MODEL_ROUTER_PLAN.md
```

The six worker files are hidden execution wrappers.

The existing stage agents remain the canonical definitions for:

```text
Researcher
Designer
Implementer
Optimizer
Tester
Reviewer
```

---

## 18. Final Architecture

```text
                    ┌─────────────────┐
                    │      USER       │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │     MASTER      │
                    │ orchestration   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  MODEL ROUTER   │
                    │ classify/select  │
                    └────────┬────────┘
                             │
                      user approval
                             │
                             ▼
                    ┌─────────────────┐
                    │   ROUTE LOCK    │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        hidden worker   hidden worker   hidden worker
              │              │              │
              └──────────────┼──────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │    OMNIROUTE    │
                    │ Engine Combo    │
                    └────────┬────────┘
                             │
                             ▼
                    provider/model pool
```

This is the target architecture for the implementation.

