# AGENTS.md

Project rules for the **My-Agents** repository (the single source of truth for
opencode agents and skills). These rules apply to any agent working inside this
repo and override agent-specific rules when they conflict.

## Rules

1. Agents, skills, and the loader plugin live in this repo and are shared across
   WSL, Windows, and every project via `plugin/load-agents.ts`.
2. One `.md` file per agent under `agents/`; the filename is the agent name.
3. One folder per skill under `skills/<skill-name>/` containing `SKILL.md`.
4. Every pipeline agent owns a workspace at
   `.opencode/agent-files/<agent>/` with `PLAN.md`, `TODO.md`, and `REPORT.md`.
5. `REPORT.md` is the standard handoff artifact — always that filename; the
   directory identifies the agent.
6. The pipeline order is:
   Researcher → Designer → Implementer → Optimizer → Tester → Reviewer → Master.
7. Root `AGENTS.md` / `PLAN.md` / `TODO.md` describe overall project state and
   override agent rules when they conflict.
8. Commit and push changes to this repo so other machines pick them up on the
   next opencode start.
9. The Master Agent is the user's sole interface. After every pipeline stage it
   must gate on critical changes or out-of-scope work and obtain explicit user
   approval before proceeding, and must ask clarifying questions liberally
   during planning rather than assuming intent.
10. Agents may edit only their own workspace under
    `.opencode/agent-files/<agent>/`; editing anywhere else is denied by
    default. Each agent writes its own PLAN.md, TODO.md, and REPORT.md there.
11. After every subagent stage the Master Agent must verify that agent's
    PLAN.md, TODO.md, and REPORT.md exist and that REPORT.md is COMPLETED
    before advancing.
12. **Prefer tools over shell.** When editing or writing files, always use the
    `edit` or `write` tool instead of shell commands. When reading a single
    file, always use the `read` tool. When searching, always use `grep` or
    `glob` tools. Fall back to shell commands only when the appropriate tool
    is not available.

13. **Model Routing Policy.** The `model-router` skill is the central model-selection
    authority. Direct OpenCode specialists are preserved for specific agents:
    Researcher → Muse Spark 1.2 Contributor, Designer → Nemotron 3 Ultra,
    Implementer → MiMo V2.5, Optimizer → Muse Spark 1.2 Contributor,
    Tester → Muse Spark 1.2 Contributor, Reviewer → MiMo V2.5,
    Master → Nemotron 3 Ultra. For all other workloads, the router selects
    an OmniRoute combo: `agent-deep`, `agent-coding`, `agent-reasoning`,
    `agent-vision`, `agent-context`, `agent-fast`, `agent-fallback`.
    Hard constraints: tool calling mandatory for agent combos; thinking variants
    precede no-think; free models only; removed providers (DeepSeek, Cerebras,
    Moonshot) never reintroduced; NVIDIA GPT-OSS without tool calling excluded.
    Context length does not equal codebase understanding.
