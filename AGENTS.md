# AGENTS.md

Project rules for the **My-Agents** repository. This repository is the single
source of truth for the OpenCode agent definitions, the OpenCode loader plugin,
and the DeepSeek Harness preset integration.

## Rules

1. Agent definitions and the loader plugin live in this repository and are
   shared through `plugin/load-agents.ts`.

2. One `.md` file defines each OpenCode agent under `agents/`.

3. The repository must not contain a separate model-router agent or
   model-router skill. Model/provider routing is handled by OmniRoute.

4. The canonical pipeline is:
   Researcher → Designer → Implementer → Optimizer → Tester → Reviewer.

5. `master.md` is the control-plane agent. Master orchestrates the pipeline,
   selects the appropriate OmniRoute worker, obtains user approval when
   required, and keeps the selected route locked for the task.

6. The six pipeline workers are route-specific execution workers:

   - `pipeline-worker-deep` → `omniroute/free-coding-deep`
   - `pipeline-worker-standard` → `omniroute/free-coding-standard`
   - `pipeline-worker-fast` → `omniroute/free-coding-fast`
   - `pipeline-worker-reasoning` → `omniroute/free-reasoning`
   - `pipeline-worker-context` → `omniroute/free-context`
   - `pipeline-worker-vision` → `omniroute/free-vision`

7. Route selection happens once per task. After the user approves the route,
   the route is locked for the entire pipeline unless the user explicitly
   approves a change.

8. Pipeline workers must not route to other workers, invoke the router, or
   change the locked model/combo. OmniRoute is responsible for provider/model
   selection, retries, cooldowns, resilience, and configured compression.

9. OpenCode loads this repository through the plugin package. Changes to agent
   definitions must therefore keep `plugin/load-agents.ts` compatible with the
   agent files in `agents/`.

10. DeepSeek Harness uses the same repository as its source. Its DSH integration
    synchronizes the bundled My-Agents preset into the user's DSH preset area;
    do not maintain a second unrelated copy of the agent architecture.

11. Project-specific `AGENTS.md` files remain separate from this repository's
    global rules. Do not overwrite a user's project-level instructions merely
    because this repository is installed globally.

12. Pipeline workspaces, when used, belong under
    `.agents/agent-files/<agent>/`. Handoff artifacts should use the standard
    `REPORT.md` filename so the next stage can consume them consistently.

13. **Prefer tools over shell.** When editing or writing files, use the
    appropriate `edit` or `write` tool. When reading a single file, use the
    `read` tool. When searching, use `grep` or `glob`. Fall back to shell only
    when the appropriate tool is unavailable.

14. Do not add obsolete routing logic, fixed provider lists, or direct model
    assignments to the agent definitions. OmniRoute's configured combos are the
    source of truth for actual provider/model routing.

15. **Strict separation of duties** between pipeline stages:

    - **Tester** is **report-only**. It only runs test commands, captures
      failures, and writes a diagnostic report. It **never modifies code**.
      If a test fails, the Tester presents findings to the Master and stops.

    - **Optimizer** is **report-only**. It only analyzes code/configuration
      and writes an optimization report describing what could be improved.
      It **never modifies code**. If it identifies optimizations, it
      presents findings to the Master and stops.

    - **Master** orchestrates sub-branches when Tester or Optimizer report
      issues. It pauses the parent pipeline, presents the findings and a
      proposed fix/optimization plan to the user, and waits for explicit
      user approval before invoking the Implementer.

    - **Implementer** is the **only** stage that modifies code or project
      files. It executes exactly the changes approved by the Master after
      user approval. It does not decide *what* to fix or optimize — only
      *how* to apply the approved change.

    - After the Implementer finishes a fix or optimization branch, the
      Master **re-invokes the Tester or Optimizer** to verify the change
      before resuming the parent pipeline. This forms a verifiable
      sub-branch that the user must approve entry into and exit from.

16. No automated tool, worker, or subagent may modify code outside the
    Implementer stage. The Tester, Optimizer, Designer, and Researcher
    stages all operate read-only against the codebase.