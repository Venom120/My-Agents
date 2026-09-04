# Plan — Cross-OS profile switcher (Option D: a single Node.js CLI)

> **Status:** DEFERRED. This plan is **not part of Workstream C**.
> It documents the v2 direction (a cross-OS CLI) so that the next
> maintainer has a starting point, but **no package is created, no
> code is written, no npm publish happens** in the current
> workstream. Workstream C is complete with the Windows-tray
> implementation in `setup/start-omniroute.vbs`; pure-Linux and
> macOS users continue to use the 10-line manual recipe in
> `setup/opencode/README.md` until the CLI ships.

## The gap

Today, the **entire** profile-switch UX lives inside
`setup/start-omniroute.vbs` → emitted PowerShell:

- `Deploy-ProfileTemplates` — copies the two `opencode.<profile>.jsonc`
  templates from the repo into `~/.config/opencode/profile.<name>.json`
  inside WSL.
- `Switch-OpenCodeProfile` — layered merge (base + user extras),
  `opencode.json.bak` backup, `npm install -g ecc-universal` +
  `npm run build` for ECC, then `systemctl restart opencode` and a
  30 s wait for active.
- `Get-WslFileHash` — SHA-256 of the live config, used by the
  2 s status tick to set the menu checkmark.
- All logging to `%LOCALAPPDATA%\My-Agents\tray.log` with 5 MB rotation.

`plugin/load-agents.ts` does **none** of this. It's a pure transform
that walks `agents/*.md` and clones `options.externalSkills` repos
into `~/.cache/opencode/packages/<name>/`. It does not read or
write `~/.config/opencode/opencode.json` — OpenCode's own plugin
loader owns that file, and our loader is downstream of it. The
README already says "do not modify the loader to mutate the
runtime config."

This means: **anyone who is not on Windows + WSL** has no
profile-switch UX at all. The current `setup/opencode/README.md`
"Manually on Linux/WSL" block is a 10-line `cp + npm + systemctl`
recipe with no persistence, no backup, no log, no checkmark, and
no ECC install/build. macOS is a 404. CI is a 404.

## Scope decision (user-approved)

This plan is **deferred**. Workstream C is done with the VBS as
the only running implementation. The CLI is a v2 effort in a
separate repo (`Venom120/my-agents-opencode`), to be created
later. This document exists so that the design is captured and
so that the next maintainer has a starting point, but **no code,
no scaffolding, no npm publish happens in Workstream C**.

The VBS in this repo keeps the layered-merge, ECC install, log
rotation, and checkmark logic. Pure-Linux and macOS users keep
the 10-line manual recipe from `setup/opencode/README.md` until
the CLI ships.

The remaining sub-sections of this plan (design, command surface,
file layout, acceptance criteria) are forward-looking notes for
the next iteration. Do not start on them as part of Workstream C.

## Why a CLI, not a shell script or an in-loader hook

| Option | Verdict | Why |
|---|---|---|
| **A. NPM package** doing what VBS does, in JS | ✓ (with D) | Same toolchain as the plugin, same distribution, cross-OS for free, testable. |
| **B. POSIX shell script + per-OS wrappers** | ✗ | JSONC parsing in shell, WSL boundary, ECC install/build — pain on pain. Two implementations of the merge to keep aligned. |
| **C. Script inside the plugin repo, run from loader** | ✗ | The loader should stay read-only against the runtime config (rule 16). Coupling the loader to `~/.config/opencode/opencode.json` is the same anti-pattern as letting any other plugin rewrite that file silently. |
| **D. Single cross-OS CLI, VBS becomes a thin Windows shim that calls it** | **✓ recommended** | One canonical implementation, three OSes, the VBS shrinks to "icon + menu + status poll", the merge is no longer trapped in PowerShell. |

## Recommended design (Option D)

### New package

A small Node.js (TypeScript) CLI published on npm:

| | |
|---|---|
| **Package name** | `@my-agents/opencode-cli` (scoped, matches ECC's `ecc-universal` style) |
| **Bin name** | `my-agents-opencode` (with `mao` as a short alias if you want it) |
| **Repo location** | New separate repo `Venom120/my-agents-opencode` (user-approved). |
| **Runtime** | Node 18+. No native bindings. |
| **Dependencies** | `commander` (or `yargs`) for the CLI, `@iarna/toml` if we ever need it (we don't yet), nothing else heavyweight. |
| **Test framework** | `vitest` (already common, fast, ESM-native). |
| **Versioning** | `0.0.1-alpha.1` first release. Prerelease tag `alpha` on npm. No CI auto-publish — release by explicit git tag. |

### Scope beyond profile switching (user-approved)

The CLI is **not** profile-switch-only. It is the **whole My-Agents
setup/control surface** for both stacks:

- **OpenCode + OmniRoute:** service start/stop, profile switch,
  doctor checks.
- **DSH + OmniRoute:** service start/stop, OmniRoute combo setup,
  doctor checks. **No** DSH agent-preset switching from the CLI —
  the DSH UI is the only way to swap presets, on purpose.

So a user runs `npm install -g @my-agents/opencode-cli` and gets
a single entry point that lets them pick which stack they're
running (OpenCode or DSH) and control the rest from there.

### v1 scope (CLI)

Per user direction:

- **Linux + Windows-via-WSL only.** macOS support is a v2.
- **CLI only on Linux, no tray.** No `systemtray` lib in v1. Linux
  users run the CLI in a terminal or wire it up themselves.
- **No scaffolding in Workstream C.** This document is the
  deliverable for now. Code goes in a later workstream when the
  separate repo is created.

### Command surface

```text
my-agents-opencode deploy
  # Reads the two templates from --repo-root (default: ~/.cache/opencode/packages/my-agents)
  # and copies them to --config-dir (default: ~/.config/opencode) as profile.<name>.json.
  # Idempotent. Reports byte count + path.

my-agents-opencode switch <my-agents|ecc>
  # Layered-merge logic ported verbatim from Switch-OpenCodeProfile:
  #   1. Read live opencode.json and the target template.
  #   2. Split live plugin block into base (matches template) + user extras.
  #   3. Build merged: targetBase + userExtras; preserve non-template providers.
  #   4. Back up live to opencode.json.bak.
  #   5. If ecc: run `npm ls -g ecc-universal` + `test -f dist/index.js`; if missing,
  #      `npm install -g ecc-universal` then `cd $(npm root -g)/ecc-universal && npm run build`.
  #   6. Restart the opencode service (systemd on Linux, launchd on macOS, or a no-op
  #      when --no-restart is set).
  #   7. Wait up to --wait 30 for the service to become active.
  #   8. Log every step to the configured log file (default: ~/.local/share/my-agents/tray.log
  #      on Linux, ~/Library/Logs/my-agents/tray.log on macOS).
  # Exit codes: 0 ok, 2 no-op (already on that profile), 3 WSL not ready, 4 ecc install failed,
  #             5 restart timed out, 6 read/write error. Each maps to a one-line human message.

my-agents-opencode status [--json]
  # Prints: opencode service state, active profile (my-agents | ecc | unknown),
  #         ecc install state, log file path.
  # Default human output, --json for the tray to consume.

my-agents-opencode log [-n 50] [-f]
  # Streams the log. -f for follow (like tail -f).

my-agents-opencode doctor
  # Sanity-checks: Node version, OpenCode config dir exists, OmniRoute reachable, six
  # combos registered. Prints a checklist. No side effects.
```

### How the VBS changes (v2 of this plan, NOT in Workstream C)

The VBS stops owning the merge, the ECC install, the restart
logic. It becomes a Windows-tray shim:

- Renders the tray icon and the OpenCode → Profile submenu.
- Every 2 s: runs `wsl.exe -d $WSLDistro -- bash -lc "my-agents-opencode status --json"`
  and parses the JSON to set the checkmark.
- On a menu click: runs `wsl.exe -d $WSLDistro -- bash -lc "my-agents-opencode switch ecc"`
  and shows a balloon with the result.

Net result: the VBS shrinks from ~1260 lines to maybe 350. The
merge logic is **only** in the CLI. PowerShell becomes a thin
IPC layer.

**This is v2.** Not in scope for Workstream C.

### How the loader sits in this design

`plugin/load-agents.ts` is unchanged. It remains a pure transform:
read `agents/*.md`, register on `config.agent`; clone
`options.externalSkills` repos, append to `config.skills.paths`.
It never reads or writes `~/.config/opencode/opencode.json` — that
file is OpenCode's, mutated only by the CLI.

If a first-time user installs the plugin and has no profile
template deployed yet, the loader will still load (because the
plugin reference in the live config is the `["my-agents@git+..."]`
tuple, not a local file path). The CLI's `deploy` is what
materializes the templates on disk; the loader is what consumes
them. If the templates don't exist, that's a "Re-deploy" menu
item away from being fixed, same as today.

### How a pure-Linux user invokes this (v2, not in Workstream C)

```bash
# One-time install (npm-published)
npm install -g @my-agents/opencode-cli

# Verify
my-agents-opencode doctor

# Deploy templates (writes ~/.config/opencode/profile.<name>.json)
my-agents-opencode deploy

# Switch
my-agents-opencode switch my-agents
my-agents-opencode switch ecc

# Status
my-agents-opencode status
```

Or, for a no-install path, `npx -y @my-agents/opencode-cli switch ecc`.

### How a macOS user invokes this (v2, not in Workstream C)

Same as Linux. The CLI detects `process.platform === 'darwin'` and:

- Uses `~/Library/Application Support/opencode/` as the default
  config dir if `XDG_CONFIG_HOME` is not set.
- Uses `~/Library/Logs/my-agents/tray.log` as the default log.
- Restarts OpenCode via `launchctl kickstart -k gui/$(id -u)/com.opencode`
  if a launchd plist is found, otherwise falls back to a plain
  process kill (`pgrep opencode && pkill -HUP opencode`).

### How CI / scripted users invoke this (v2, not in Workstream C)

```bash
# CI: ensure my-agents profile is active, fail if not
my-agents-opencode switch my-agents
```

Exit codes 2 (no-op) is success; 0 is success after a real switch;
anything ≥ 3 is a hard failure.

## File layout (if we go single-repo, packages/cli/)

```text
packages/cli/
├── package.json          # name: @my-agents/opencode-cli, bin: { my-agents-opencode, mao }
├── tsconfig.json
├── README.md             # user-facing, ~150 lines
├── src/
│   ├── index.ts          # commander setup, command registration
│   ├── deploy.ts         # template copy (was Deploy-ProfileTemplates)
│   ├── switch.ts         # layered merge + restart (was Switch-OpenCodeProfile)
│   ├── status.ts         # service state + active profile (was Get-WslServiceState + Get-WslFileHash)
│   ├── log.ts            # log rotation + writer (was Write-TrayLog + Rotate-TrayLog)
│   ├── ecc.ts            # npm ls / install / build (was Test-EccInstallReady + Install-EccPackage + Build-EccPlugin)
│   ├── jsonc.ts          # safe JSON read/write that preserves JSONC comments
│   ├── paths.ts          # XDG / macOS / Windows path resolution (was Get-WslConfigRoot)
│   ├── service.ts        # systemd / launchctl / no-op restart (was Invoke-WslSystemctl + Wait-OpenCodeActive)
│   └── doctor.ts         # sanity checks
├── test/
│   ├── switch.test.ts    # layered-merge matrix (10+ cases from the existing edge cases)
│   ├── ecc.test.ts       # mock `npm` / `test`, verify install + build only when needed
│   ├── jsonc.test.ts     # comment preservation, trailing-comma tolerance
│   └── status.test.ts    # hash compare, "unknown active profile" detection
└── .github/workflows/
    └── ci.yml            # vitest on Node 18, 20, 22; npm publish on tag
```

If we go **separate repo**, the layout is the same but at
`Venom120/my-agents-opencode/`.

## What changes — file by file — when we do this (v2, not in Workstream C)

| File | Change |
|---|---|
| `plugin/load-agents.ts` | **none.** Remains a pure transform. |
| `opencode.my-agents.jsonc` | **none.** |
| `opencode.ecc.jsonc` | **none.** |
| `setup/start-omniroute.vbs` | shrink from ~1260 lines to ~350. All merge/ecc/restart logic replaced with `wsl.exe -d $WSLDistro -- bash -lc "my-agents-opencode ..."` calls. |
| `setup/README.md` | updated Windows-tray section to point at the CLI for the actual work. |
| `setup/opencode/README.md` | the "Manually on Linux/WSL" block becomes `npm i -g @my-agents/opencode-cli && my-agents-opencode switch my-agents`. |
| New: `Venom120/my-agents-opencode` (separate repo) | the CLI itself. |
| `PLAN-OPENCODE-PROFILE-TOGGLE.md` | amendment note pointing here. |
| `PLAN-USER-PLUGIN-PERSISTENCE.md` | updated "Implementation sketch" section: helpers move to the CLI, not into the VBS. |
| `HANDOFF-ECC.md` | new workstream D, scoped above. |

## Acceptance criteria (v2, not in Workstream C)

1. `npm install -g @my-agents/opencode-cli` works on Linux, macOS,
   and inside WSL from Windows.
2. `my-agents-opencode switch ecc` from a fresh install:
   - Installs `ecc-universal` if missing.
   - Builds it if `dist/index.js` is missing.
   - Backs up `opencode.json` to `opencode.json.bak`.
   - Writes the merged config (target base + user extras).
   - Restarts OpenCode.
   - Logs every step.
3. `my-agents-opencode status --json` returns:
   ```json
   {
     "opencode": { "state": "active", "pid": 1234 },
     "activeProfile": "ecc",
     "ecc": { "installed": true, "built": true },
     "log": "/home/u/.local/share/my-agents/tray.log"
   }
   ```
4. `vitest run` is green. Test matrix covers: 8 switch scenarios
   (already-active, user-extras present, no live file, malformed
   JSON, ecc not installed, ecc installed not built, etc.).
5. The Windows tray still works; the VBS is ≤ 400 lines.
6. `plugin/load-agents.ts` is unchanged.
7. `opencode.my-agents.jsonc` and `opencode.ecc.jsonc` are unchanged.

## Open questions for you

1. **Package name:** `@my-agents/opencode-cli` (scoped, ECC-style),
   `my-agents-opencode` (unscoped, simpler), or something else?
2. **Bin name:** `my-agents-opencode` (verbose) or a short alias
   like `mao` / `maoc`?
3. **Repo location:** a **new repo** `Venom120/my-agents-opencode`
   (cleaner CI, independent versioning, no submodule entanglement)
   or a **`packages/cli/` workspace inside this repo** (one less
   repo to maintain, single release channel for plugin + CLI)?
4. **macOS scope:** ship full macOS support (launchd integration,
   `~/Library/Logs/...`) in v1, or scope to **Linux + Windows-via-WSL
   only** for v1 and add macOS in v2?
5. **First-class tray on Linux:** v1 = CLI only, no tray on Linux
   (users call the CLI from a terminal, or set up `systemd --user`
   + a polling script if they want a checkmark). Or v1 = CLI +
   a simple `node` tray using `systemtray` (Node lib) so Linux
   users get a real tray? macOS tray is feasible via `systemtray`
   too, but a real macOS menu-bar app is a Swift/AppKit job
   (out of scope).
6. **Publish trigger:** publish from CI on a git tag
   (`v0.1.0` → npm `@0.1.0`)? Or on every merge to `main`
   (`@0.0.0-dev.<sha>`)? The former is what `ecc-universal` does.
