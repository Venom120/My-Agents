# PLAN

## Task

Maintain the My-Agents repository: the shared source of truth for opencode
agents and skills, loaded into every project via `plugin/load-agents.ts`.

## Objectives

- Keep agent definitions (`agents/*.md`) and skills (`skills/*/SKILL.md`) clear,
  consistent, and well-documented.
- Enforce the agent-workspace + REPORT.md handoff protocol so the pipeline is
  predictable and resumable.
- Support all three environments (WSL, Windows, every project) from one repo.

## Approach

- Edit `agents/<name>.md` to change an agent; commit and push.
- Add `agents/<name>.md` to add an agent (frontmatter: description, mode, model,
  permission; body is the system prompt).
- Add `skills/<skill-name>/SKILL.md` to add a skill.

## Expected Deliverables

- Working agent definitions that follow the pipeline and workspace protocol.
- Accurate README and AGENTS.md documenting structure and workflow.

## Dependencies

- `plugin/load-agents.ts` must register `agents/*.md` at opencode startup.

## Constraints

- Changes are shared globally; keep them general and safe.
