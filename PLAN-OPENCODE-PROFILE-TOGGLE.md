# Plan — OpenCode Profile Toggle via the Windows Tray

> **Status:** FINAL. Awaiting user approval before any code is written
> and before any commits / pushes.
>
> **Amendment 1 (user-plugin persistence):** The original plan
> naively overwrites the live `opencode.json` with the template on
> every switch. That would silently drop any user-added plugin
> (`opencode plugin add foo`) the next time the user switches away
> and back. The fix — layered merge (template base + user extras,
> with `opencode.json.bak` rollback) — is documented in
> [`PLAN-USER-PLUGIN-PERSISTENCE.md`](./PLAN-USER-PLUGIN-PERSISTENCE.md)
> and has been applied in the same change set.
> **Workstream:** C of the ECC + My-Agents integration
> (see [HANDOFF-ECC.md](./HANDOFF-ECC.md)).
> **Scope:** Switching between the **My-Agents** profile and the **ECC**
> profile in **OpenCode** running inside **WSL** from a **Windows host**,
> via the existing tray launcher.

---

## 1. User flow (the bar)

Right-click the tray icon → **OpenCode** → **Profile** → click
**My-Agents** or **ECC** → menu item shows ✓ next to the active one →
`opencode.service` restarts inside WSL → done. The whole round trip
takes a few seconds, never opens a terminal, and never asks the user
to edit a file by hand.

---

## 2. Where the config files live (Option 3)

All config files live **inside the WSL distro** at fixed, well-known
paths. The repo (this My-Agents checkout) is a **source of truth for
templates only**, not a runtime location.

| File (inside WSL) | Purpose | Created by |
|---|---|---|
| `~/.config/opencode/profile.my-agents.json` | My-Agents profile (template, not loaded) | Tray, on first run |
| `~/.config/opencode/profile.ecc.json` | ECC profile (template, not loaded) | Tray, on first run |
| `~/.config/opencode/opencode.jsonc` | **Active** profile (this is what OpenCode actually reads) | Tray, on every switch |

The tray holds the two templates **embedded inside the VBS** (PowerShell
heredocs) so the user does not have to keep this repo at a specific
path for the toggle to work. The repo can move, get deleted, or stay
uninitialized; the toggle keeps working.

If the repo is present, the tray prefers the on-disk template files
(`opencode.my-agents.json` and `opencode.ecc.json` at the repo root).
That makes the templates version-controlled and editable. If a file is
missing, the tray falls back to the embedded copy and logs a warning.

---

## 3. Profile templates (in this repo)

Two new JSON files at the My-Agents repo root:

### `opencode.my-agents.json`

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    ["my-agents@git+https://github.com/Venom120/My-Agents.git#main", {
      "externalSkills": []
    }]
  ],
  "provider": {
    "omniroute": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "OmniRoute",
      "options": {
        "baseURL": "http://127.0.0.1:20128/v1",
        "apiKey": "{env:OMNIROUTE_API_KEY}"
      },
      "models": {
        "free-reasoning":        { "name": "OmniRoute — Reasoning" },
        "free-coding-deep":      { "name": "OmniRoute — Deep Coding" },
        "free-coding-standard":  { "name": "OmniRoute — Standard Coding" },
        "free-coding-fast":      { "name": "OmniRoute — Fast Coding" },
        "free-context":          { "name": "OmniRoute — Large Context" },
        "free-vision":           { "name": "OmniRoute — Vision" }
      }
    }
  }
}
```

### `opencode.ecc.json`

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "ecc-universal"
  ],
  "provider": {
    "omniroute": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "OmniRoute",
      "options": {
        "baseURL": "http://127.0.0.1:20128/v1",
        "apiKey": "{env:OMNIROUTE_API_KEY}"
      },
      "models": {
        "free-reasoning":        { "name": "OmniRoute — Reasoning" },
        "free-coding-deep":      { "name": "OmniRoute — Deep Coding" },
        "free-coding-standard":  { "name": "OmniRoute — Standard Coding" },
        "free-coding-fast":      { "name": "OmniRoute — Fast Coding" },
        "free-context":          { "name": "OmniRoute — Large Context" },
        "free-vision":           { "name": "OmniRoute — Vision" }
      }
    }
  }
}
```

Notes:

- The My-Agents profile uses the **plugin tuple form** so future
  per-plugin options (e.g. `externalSkills`) can be added without
  breaking the toggle.
- The ECC profile uses the **plain npm package name** because
  `ecc-universal` is published on npm and OpenCode resolves
  `ecc-universal` as a plugin entry.
- The `provider` block is **identical in both files**. Both profiles
  route through the local OmniRoute. The `free-reasoning` model is
  the default; the other five combos are listed so agents and
  commands can pick them by name.
- The user's My-Agents preset for DSH lives in `~/.dsh/`, completely
  separate from OpenCode's config. This file only affects OpenCode.

---

## 4. Tray menu change

Add a **Profile** submenu under the existing **OpenCode** menu. New
shape:

```text
OpenCode
  Open
  Start
  Restart
  Stop
  ─────
  Profile
    My-Agents [✓]   <-- ✓ marks the currently active profile
    ECC
    ─────
    Re-deploy templates
  Startup [✓]
```

`Re-deploy templates` is a recovery action — it copies the templates
from the repo (or the embedded fallback) to `~/.config/opencode/`
without changing the active profile. Useful when the templates got
accidentally edited or are missing.

The `DSH` and `OmniRoute` submenus are unchanged. The active DSH
profile is still managed via `dsh plugin --profile web add` (terminal
command) — out of scope for this workstream.

---

## 5. Tray logic — switch action

When the user clicks **Profile → My-Agents** or **Profile → ECC**, the
tray does the following (all in PowerShell, executed from the existing
`powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden`
launcher at the bottom of the VBS):

1. **Resolve the WSL config root.**
   ```powershell
   $wslConfigRoot = & wsl.exe -d $WSLDistro -- bash -lc '
       if [ -n "$OPENCODE_CONFIG_DIR" ]; then echo "$OPENCODE_CONFIG_DIR"
       elif [ -n "$XDG_CONFIG_HOME" ]; then echo "$XDG_CONFIG_HOME/opencode"
       else echo "$HOME/.config/opencode"
       fi
   '
   ```
2. **Deploy the two profile templates** (idempotent — only if missing
   or hash differs from the embedded / repo version). Source of truth
   priority:
   - If `wsl.exe test -f "/mnt/d/Github/My-Agents/opencode.<name>.json"`
     exists, use that.
   - Else use the embedded copy inside the VBS.
   - Target: `$wslConfigRoot/profile.<name>.json`.
3. **If the clicked profile is `ecc`, run the install / build check**
   (see section 6 below).
4. **Copy the chosen profile to the active file.**
   ```powershell
   Invoke-WslBash "cp '$wslConfigRoot/profile.<name>.json' '$wslConfigRoot/opencode.jsonc'"
   ```
5. **Restart OpenCode** (existing helper):
   ```powershell
   Invoke-WslSystemctl @('restart','opencode')
   ```
6. **Wait for `opencode.service` to settle.** Poll
   `Get-WslServiceState 'opencode'` every 500 ms for up to 30 s. If
   the state goes `active`, success. If it goes `failed`, show an
   error balloon and stop.
7. **Update the menu checkmark.** The next 2-second status tick
   re-evaluates the active profile from a hash comparison.

### 5a. Active-profile detection (hash-based)

The tray keeps three SHA-256 hashes, computed **inside the VBS** (no
external tools needed, `.NET` has `SHA256` built-in):

- `MY_AGENTS_HASH` — hash of the My-Agents template.
- `ECC_HASH` — hash of the ECC template.
- `ACTIVE_HASH` — hash of the live `$wslConfigRoot/opencode.jsonc` read
  fresh each status tick.

The 2-second status tick (already in the tray) is extended to:

```powershell
$activeHash = (Get-WslFileHash $activeConfigPath)
switch ($activeHash) {
    $MY_AGENTS_HASH { $myAgentsItem.Checked = $true; $eccItem.Checked = $false }
    $ECC_HASH        { $myAgentsItem.Checked = $false; $eccItem.Checked = $true }
    default          { $myAgentsItem.Checked = $false; $eccItem.Checked = $false
                        $unknownProfileItem.Visible = $true }
}
```

The checkmark on the active profile is **always derived from the
disk**, never from in-memory state. This makes the menu honest even
if the user edits `opencode.jsonc` by hand while the tray is running.

### 5b. Click-on-active is a no-op

If the user clicks the already-active profile, the tray logs
`[my-agents] profile 'my-agents' already active, no action` and
returns. No copy, no restart, no checkmark flicker.

---

## 6. ECC install / build check (Option A — automatic, with logging)

Because the tray runs on Windows but OpenCode + ECC live inside WSL,
all install / build steps are **forwarded into WSL via `wsl.exe`**.

When the user clicks **Profile → ECC**, before writing the config:

1. **Check if `ecc-universal` is globally installed inside WSL:**
   ```bash
   wsl.exe -d $WSLDistro -- npm ls -g ecc-universal --depth=0
   ```
   - If exit code is 0 and version is present → step 2.
   - If missing → log `[my-agents] ecc-universal not installed, installing…`
     and run:
     ```bash
     wsl.exe -d $WSLDistro -- npm install -g ecc-universal
     ```
     - If install succeeds, continue to step 2.
     - If install fails, show a balloon:
       *"Failed to install `ecc-universal`. Check `npm` access inside
       WSL. See logs at `%LOCALAPPDATA%\My-Agents\ecc-install.log`."*
       and abort the switch.
2. **Check if the local build artifact is present** (ECC ships a
   pre-built `dist/`, but the npm tarball may not include it):
   ```bash
   wsl.exe -d $WSLDistro -- bash -lc \
     'test -f "$(npm root -g)/ecc-universal/dist/index.js"'
   ```
   - If present → done, continue to section 5 step 4.
   - If missing → log `[my-agents] ecc-universal dist missing, building…`
     and run:
     ```bash
     wsl.exe -d $WSLDistro -- bash -lc \
       'cd "$(npm root -g)/ecc-universal" && npm run build'
     ```
     - If build succeeds, continue to section 5 step 4.
     - If build fails, show the same error balloon and abort.

Every step writes a line to a **persistent log file** so the user can
debug after the fact:

```text
%LOCALAPPDATA%\My-Agents\tray.log
```

Format:

```text
[2026-09-12 14:22:01] [my-agents] tray launched
[2026-09-12 14:22:01] [my-agents] mutex acquired
[2026-09-12 14:22:35] [my-agents] profile switch requested: my-agents -> ecc
[2026-09-12 14:22:35] [my-agents] deploying profile templates to /root/.config/opencode
[2026-09-12 14:22:35] [my-agents]   - /root/.config/opencode/profile.my-agents.json  (unchanged)
[2026-09-12 14:22:35] [my-agents]   - /root/.config/opencode/profile.ecc.json        (deployed from repo)
[2026-09-12 14:22:35] [my-agents] checking ecc-universal install inside WSL
[2026-09-12 14:22:36] [my-agents] ecc-universal already installed at 2.2.0
[2026-09-12 14:22:36] [my-agents] ecc-universal dist present, skipping build
[2026-09-12 14:22:36] [my-agents] activating ecc
[2026-09-12 14:22:36] [my-agents]   cp profile.ecc.json -> opencode.jsonc
[2026-09-12 14:22:36] [my-agents]   systemctl restart opencode
[2026-09-12 14:22:39] [my-agents] opencode.service -> active after 2.7s
[2026-09-12 14:22:39] [my-agents] profile switch complete
```

The log file is **truncated to the last 5 MB** on each tray launch so
it doesn't grow forever.

---

## 7. Edge cases — all logged

| # | Case | Tray behavior | Log entry |
|---|---|---|---|
| 1 | WSL distro not running | Show balloon: "WSL is not running. Start your distro first." Abort. | `WSL distro '$WSLDistro' not running` |
| 2 | OpenCode not installed inside WSL | Show balloon: "OpenCode is not installed in WSL. See `setup/opencode/README.md`." Abort. | `opencode binary not found in WSL` |
| 3 | ECC submodule not present, but user clicks ECC | This case doesn't actually happen because the tray uses the **npm package**, not the submodule. Logged for clarity. | `ecc profile sourced from npm package, not submodule` |
| 4 | `ecc-universal` install fails (no network, bad npm) | Show balloon with the npm error tail. Abort. Active profile unchanged. | `npm install -g ecc-universal FAILED: <error>` |
| 5 | `ecc-universal` build fails (TS errors, missing deps) | Show balloon with the build error tail. Abort. Active profile unchanged. | `npm run build for ecc-universal FAILED: <error>` |
| 6 | Active `opencode.jsonc` doesn't match either template hash | Both menu items show no checkmark. A new "Unknown active profile" item appears at the top of the Profile submenu. Clicking it re-deploys the My-Agents template. | `active opencode.jsonc does not match any known template (hash=<sha>)` |
| 7 | User clicks the already-active profile | No-op. No restart, no log noise except a single info line. | `profile '<name>' already active, no action` |
| 8 | Two switches requested in rapid succession | The status-tick poll ignores requests while `opencode.service` is in `activating` / `deactivating` state. The first switch completes before the second is accepted. | `switch ignored: opencode.service is <state>` |
| 9 | `opencode.service` restart takes > 30 s | Tray shows balloon: "OpenCode did not become active within 30 s. Check `journalctl -u opencode` inside WSL." Active profile reverts to whatever the user picked (config has been written), but the service is still restarting. | `opencode.service restart timed out after 30s` |
| 10 | Both template files are missing on disk AND in the VBS embed | The tray was built without templates. Show balloon: "Tray templates missing. Re-install the latest `start-omniroute.vbs` from the My-Agents repo." Abort. | `embedded templates missing, VBS is corrupted` |
| 11 | `OMNIROUTE_API_KEY` not set inside WSL | OpenCode will refuse to start; tray logs the failed state from `systemctl`. Show balloon: "OpenCode failed to start. Check that `OMNIROUTE_API_KEY` is set inside WSL." | `opencode.service -> failed; likely missing OMNIROUTE_API_KEY` |
| 12 | Repo templates and embedded templates diverge | Repo wins. Embedded is only a fallback. Logged so the user can see which source was used. | `deployed <name> from repo`, or `deployed <name> from embedded fallback (repo file missing)` |

Every error case shows a **balloon with a one-line message and a
"Show log" button** that opens `%LOCALAPPDATA%\My-Agents\tray.log` in
Notepad. (This adds a small `Add-Type` block to the VBS to wrap the
existing `MessageBox` calls — backwards compatible.)

---

## 8. Files to create / modify

All in the My-Agents repo (NOT in the ECC submodule). No commits
until the user approves.

| File | Action | Purpose |
|---|---|---|
| `opencode.my-agents.json` | **create** | My-Agents profile template |
| `opencode.ecc.json` | **create** | ECC profile template |
| `setup/start-omniroute.vbs` | **modify** | Add Profile submenu, switch logic, install/build check, hash detection, logging |
| `setup/README.md` | **modify** | Add "Switching OpenCode profiles" section, mention `%LOCALAPPDATA%\My-Agents\tray.log` |
| `setup/opencode/README.md` | **modify** | Add "Profiles" section explaining the tray toggle |
| `.gitignore` | **modify** | Ignore the local `%LOCALAPPDATA%\My-Agents\` (Windows-side, not actually git-tracked, but include for completeness) |

**No changes** to:
- `plugin/load-agents.ts` (My-Agents OpenCode plugin is unchanged).
- `dsh/*` (DSH profile switching stays out-of-band).
- `ECC/*` (this workstream does not depend on or modify the ECC
  submodule; Workstream B is independent).

---

## 9. Acceptance criteria

1. **First-time install:** On a clean machine, after the WSL tray
   boots for the first time with `WSL_DISTRO = "Ubuntu"` and OpenCode
   installed, the tray creates
   `~/.config/opencode/profile.{my-agents,ecc}.json` inside WSL
   without changing the active `opencode.jsonc`.
2. **Switch to My-Agents:** Click Profile → My-Agents. `opencode.jsonc`
   becomes a copy of `profile.my-agents.json`. `opencode.service`
   restarts. After ~3 s, the menu shows ✓ next to My-Agents.
3. **Switch to ECC, npm missing:** Click Profile → ECC on a machine
   without `ecc-universal`. Tray installs it (logs each step), builds
   it if needed (logs), switches the config, restarts, and shows ✓
   next to ECC.
4. **Switch to ECC, already installed:** Click Profile → ECC. Tray
   skips the install step, switches the config, restarts, shows ✓.
5. **Click already-active:** No-op, single log line.
6. **Rapid double-click:** Second click is rejected with
   `switch ignored: opencode.service is activating`.
7. **Manual edit survives:** User edits `opencode.jsonc` by hand. Next
   2-s tick detects the hash mismatch and unchecks both items, shows
   the "Unknown active profile" recovery item.
8. **Repo templates update:** User updates
   `opencode.ecc.json` in the repo. Next switch to ECC deploys the
   new template. Logged.
9. **ECC build fails:** Tray aborts the switch, leaves the previous
   active profile in place, shows a balloon, writes a full error to
   `tray.log`.
10. **Service restart times out:** Tray shows the timeout balloon,
    leaves the (just-written) config in place, logs the timeout.

---

## 10. Out of scope (explicit)

- DSH profile switching via the tray (use `dsh plugin --profile web
  add` from a terminal instead).
- Changing ECC's `agent.yaml` to add OmniRoute fallbacks
  (**Workstream B**).
- Adding a Linux tray launcher (the existing VBS is Windows-only by
  design; Linux users manage the systemd services directly or via
  `scripts/switch-opencode-profile.sh` from a future helper).
- A CLI fallback that does the same switch without the tray
  (e.g. `scripts/switch-opencode-profile.{sh,ps1}`). Mentioned in
  the handoff for Workstream C, but **not built in this pass** —
  add it later if the user asks.
