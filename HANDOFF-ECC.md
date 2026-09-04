# ECC + My-Agents Integration — Handoff Summary

> **Purpose.** This document captures the plan for integrating the
> **affaan-m/ECC** (Elite Claude Code) repo as a **second profile** that
> runs alongside the existing My-Agents pipeline. It is the single source
> of truth for the next session / another developer to pick this work
> up. All decisions below are **user-approved**.

---

## 1. Goal

| Host | Profile 1 (today) | Profile 2 (new) |
|---|---|---|
| **DeepSeek Harness (DSH)** | `my-agents` (Master + 6 pipeline workers) | `ecc` (ECC's 68 agents via a new DSH adapter) |
| **OpenCode** | `my-agents` plugin | `ecc` plugin |

Both profiles share the **same OmniRoute gateway** and the **same six
free Engine Combos** (`free-coding-deep`, `free-coding-standard`,
`free-coding-fast`, `free-reasoning`, `free-context`, `free-vision`).

The My-Agents 6-stage pipeline (Researcher → Designer → Implementer →
Optimizer → Tester → Reviewer) is **retained for the `my-agents`
profile**. The `ecc` profile uses ECC's own orchestrator + specialist
swarm.

---

## 2. Decisions (user-approved)

| # | Decision | Choice |
|---|---|---|
| 1 | Where does ECC live? | **Git submodule** of this repo, pointing to the user's fork `Venom120/ECC`. |
| 2 | How does OpenCode switch between profiles? | **Toggle.** Maintain two `opencode.json` files (`opencode.json` = My-Agents, `opencode.ecc.json` = ECC) and let the user / tray swap which one is active. |
| 3 | Where are the OmniRoute fallbacks changed? | **Inside ECC.** Update ECC's `agent.yaml` and the per-host config so its preferred model is `omniroute/free-reasoning` and the fallbacks are the six OmniRoute combos. Affects both OpenCode and DSH usage of ECC. |

---

## 3. Repository state at handoff

- **Working dir:** `/mnt/d/Github/My-Agents`
- **Branch:** `main`, last commit `fc284f8`.
- **Untracked:** `ECC/` is an untracked directory that already contains a **full clone** of the user's fork `https://github.com/Venom120/ECC` (verified with `git remote -v`).
- **Not yet registered:** `ECC/` is NOT yet a git submodule. The next step in this plan is `git submodule add` to register it.
- **Plugin loader contract:** `plugin/load-agents.ts` is hard-coded to only walk the `agents/` folder. It will not pick up ECC. New profile mechanism must be **explicit** — never a generic repo walk.

---

## 4. Workstreams

### Workstream A — Register ECC as a git submodule

- Run `git submodule add https://github.com/Venom120/ECC.git ECC` in the repo root.
- Commit the new `.gitmodules` file and the ECC submodule pointer.
- Document the submodule in a new `ECC/README.md` (forwarded into the
  submodule's working tree via a symlink or just kept at the My-Agents
  repo root).

### Workstream B — Add a DSH adapter to ECC (upstream-friendly)

Goal: `dsh plugin --profile web add github:Venom120/ECC#main` should
install ECC as a second DSH preset alongside `my-agents`.

Files to add inside the `ECC/` submodule (these edits are *inside* the
fork, so they can later be PR'd upstream to `affaan-m/ECC`):

1. **`scripts/lib/install-targets/dsh-home.js`** — new adapter
   modeled on `opencode-home.js`. Translates ECC's module manifest
   into DSH's expected shape:
   - `dsh/agent-presets/ecc/agent.cordis.yml`
   - `dsh/agent-presets/ecc/preset.yml`
   - `dsh/sync-preset.js` (per-profile; each profile gets its own)

   Resolves the DSH install root from `$DSH_HOME` or
   `~/.dsh/.agent-presets/ecc/`.

2. **`scripts/lib/install-manifests.js`** — add `'dsh'` to
   `SUPPORTED_INSTALL_TARGETS` and add a DSH row to
   `LEGACY_COMPAT_BASE_MODULE_IDS_BY_TARGET` so the manifest layer
   recognizes the new target.

3. **`scripts/install-apply.js`** — the help text lists
   `SUPPORTED_INSTALL_TARGETS` automatically, so the only change
   needed is the constant update above.

4. **`agent.yaml`** — change `model.preferred` to
   `omniroute/free-reasoning` and add the six combos to
   `model.fallback` (per Decision 3). The combos are the same six
   already built by `setup/omniroute/omniroute_free_combos.py` in
   this repo, so ECC agents route through the same provider pool.

5. **`.claude/settings.json` template** (if it ships in ECC) — point
   the OpenAI-compatible base URL at `http://127.0.0.1:20128/v1` and
   use `OMNIROUTE_API_KEY` as the apiKeyEnv.

6. **`.opencode` plugin adapter** — ECC already has a compiled
   `.opencode/dist/` payload; verify it still works when base URL
   points at OmniRoute. The plugin loader that lives inside ECC
   (NOT this repo) is the right place to register the
   `omniroute` provider.

### Workstream C — OpenCode profile toggle

Goal: A user can flip between My-Agents and ECC without editing
`opencode.json` by hand.

Approach:
1. Keep two config files in the repo root (or in the user setup dir):
   - `opencode.my-agents.json` — current `plugin:
     ["github:Venom120/My-Agents#main"]`
   - `opencode.ecc.json` — `plugin: ["github:Venom120/ECC#main"]`
2. Add a small `scripts/switch-opencode-profile.{sh,ps1}` that
   symlinks or copies the chosen file to the active config location
   (`~/.config/opencode/opencode.json` on Linux, `%APPDATA%\opencode\opencode.json` on Windows).
3. Optionally add a third item to the Windows tray
   (`setup/start-omniroute.vbs`) under a new "Profile" submenu
   that runs the switch script.

This way:
- `dsh plugin --profile web add github:Venom120/My-Agents#main` — gets
  the `my-agents` DSH preset.
- `dsh plugin --profile web add github:Venom120/ECC#main` — gets the
  `ecc` DSH preset (after Workstream B is done).
- For OpenCode, the user picks one profile at a time via the toggle.

### Workstream D — Document everything

Add a top-level `docs/ECC-INTEGRATION.md` (or extend
`OMNIROUTE_DSH.md` / `OMNIROUTE_OPENCODE.md`) covering:

- Why two profiles exist.
- How to install both DSH presets.
- How to switch the OpenCode profile.
- That both share OmniRoute (and that OmniRoute must be running).
- That the My-Agents 6-stage pipeline is **not** used by ECC.

---

## 5. Critical invariants — DO NOT BREAK

These are the existing rules that the ECC integration must not violate:

- **AGENTS.md rules 1–16** — the My-Agents agent files in
  `agents/` are unchanged.
- **`plugin/load-agents.ts`** — still walks only `agents/`. Never
  read from `ECC/agents/` or anywhere else. ECC is its own plugin.
- **DSH preset format** — each profile lives in its own
  `dsh/agent-presets/<profile>/` directory with its own
  `agent.cordis.yml` and `preset.yml`. Profiles do not cross-
  reference each other.
- **OmniRoute combos** — the six combo names are LOCKED. ECC's
  `model.fallback` must use these exact names.
- **Strict separation of duties** — applies to the `my-agents`
  profile only. ECC has its own governance (hooks, commands,
  workflows) that is independent of the My-Agents pipeline rules.
- **DSH management key** — never embedded. The DSH adapter
  inherits the env-var pattern from the existing `setup/dsh/`.

---

## 6. Open questions for the next session

1. **DSH adapter placement.** Should the new
   `dsh/agent-presets/ecc/` files be **vendored** into the ECC
   submodule (so the whole preset ships with ECC), or generated
   **at install time** by the adapter script? Vendoring is simpler
   but causes drift. Generating requires the adapter to know the
   DSH persona shape precisely. Recommended: **generated at install
   time** by `dsh-home.js`, reading the ECC agent `.md` files and
   converting them to DSH persona entries.
2. **Submodule vs. plain directory.** The user said "add this as a
   submodule". Submodule is the right call so upstream changes
   can be pulled. But it also means editing files in `ECC/`
   requires either (a) a feature branch on the fork, or (b) an
   in-place commit that lives only on the fork. The handoff
   document specifies (a).
3. **OpenCode toggle UX.** Symlink vs. file copy. On Windows,
   symlinks need admin / developer mode. Recommend file copy.
4. **ECC's preferred model.** The user said "remember the fallbacks"
   — confirmed we update fallbacks. But should we ALSO change
   `model.preferred` from `claude-opus-4-6` to `omniroute/free-reasoning`?
   Recommended: yes, since OmniRoute is the only local model
   gateway in this setup. Direct Anthropic API calls would not
   work anyway because no Anthropic key is configured.

---

## 7. Acceptance criteria

When this handoff is complete:

1. `git submodule status` shows `ECC` as registered with the user's
   fork URL.
2. Inside `ECC/`, a new branch (suggested name `dsh-adapter`) has
   the files listed in Workstream B and a commit message like
   `feat: add dsh install target + omniroute fallbacks`.
3. Running `dsh plugin --profile web add github:Venom120/ECC#main`
   from the user's box installs the `ecc` profile into
   `~/.dsh/.agent-presets/ecc/`.
4. Running `dsh plugin --profile web add github:Venom120/My-Agents#main`
   from the same box still installs the `my-agents` profile into
   `~/.dsh/.agent-presets/my-agents/`.
5. The two DSH profiles can be selected independently in
   `~/.dsh/settings.yaml` via `agent-presets.default: ecc` or
   `agent-presets.default: my-agents`.
6. For OpenCode, running `bash scripts/switch-opencode-profile.sh ecc`
   replaces the active config with the ECC plugin; running it with
   `my-agents` restores the current one.
7. Both profiles route model calls to the same OmniRoute instance
   (verify by tailing OmniRoute logs and seeing traffic from both).
8. The My-Agents 6-stage pipeline still works in the `my-agents`
   profile (smoke test: ask the Master for a small task and
   confirm it dispatches to a hidden pipeline worker).
9. ECC's orchestrator works in the `ecc` profile (smoke test: run
   an ECC command like `/plan` and confirm the right agent picks
   it up).

---

## 8. What is NOT in this handoff

- **No code is written yet.** This document is the plan. The next
  step is to start Workstream A (register the submodule) and
  Workstream B (the DSH adapter), in that order.
- **No commits are made yet.** Submodule add will produce one
  commit. Adapter work happens on a branch inside `ECC/`.
- **No push happens yet.** The fork push is the last step of
  Workstream B, after the adapter is tested locally.
