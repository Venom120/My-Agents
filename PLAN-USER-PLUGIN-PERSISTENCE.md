# Plan: User-added plugins must survive profile switches

## What we have today

**Files (repo root, JSONC):**
- `opencode.my-agents.jsonc` — my-agents template
- `opencode.ecc.jsonc` — ecc-universal template
- `opencode.example.jsonc` — community example, single-profile style

**Loader (`plugin/load-agents.ts`):**
- Reads `agents/*.md` → registers agents on the `config.agent` object.
- Reads `options.externalSkills` (the second element of the
  `["my-agents@git+...", { "externalSkills": [...] }]` tuple) → clones
  those repos to `~/.cache/opencode/packages/<name>` and adds the
  `skills/` folder to `config.skills.paths`.
- Does **not** read or write `config.plugin`. Other plugins (superpowers,
  ecc-universal, etc.) are loaded by OpenCode's own plugin loader, not
  by us.

**Tray (`setup/start-omniroute.vbs`):**
- Switches the active config by copying the chosen template
  (`opencode.my-agents.jsonc` or `opencode.ecc.jsonc`) over the live
  `~/.config/opencode/opencode.jsonc` inside WSL, then restarting
  `opencode.service`.

## The problem (user's question)

If a user runs `opencode plugin add foo` while on the **My-Agents**
profile:

1. OpenCode rewrites the live `~/.config/opencode/opencode.jsonc` to
   include `"foo"` in its `plugin` block.
2. The two templates (`opencode.my-agents.jsonc`,
   `opencode.ecc.jsonc`) in the repo are unchanged.
3. Next time the user switches profiles — say My-Agents → ECC → back
   to My-Agents — the tray copies the **template** over the live
   `opencode.jsonc`, so `foo` is silently lost.

This breaks the user's mental model. They added a plugin once, the
tray should keep it.

## The real separation

Each profile template only owns its own **base** `plugin` entry:

| Profile | Base plugin entry |
|---|---|
| `my-agents` | `[["my-agents@git+...#main", { "externalSkills": [] }]]` |
| `ecc`      | `["ecc-universal"]` |

Everything **else** in the `plugin` block (user-added plugins, custom
external skills) belongs to the user, not the profile. Same for the
`provider` block — we ship one OmniRoute block per profile because
that's the only place profile identity lives, and if the user wants
to add another provider they should, not have it nuked by switching.

## Three solution options

### Option 1 — **Layered merge on switch** (recommended)

Keep the templates clean (only the base entry). On every switch, the
tray does:

1. Read the **current** live `opencode.jsonc` and split it into:
   - `base` — the entries that match one of the known profile bases
     (hash-equality of each entry).
   - `userExtras` — every other entry in the `plugin` block.
2. Read the **target** template and take its base entry.
3. Write a merged file: `targetBase + userExtras` for `plugin`,
   `targetProvider` for `provider` (providers are profile-specific,
   so the user's other providers stay — they're not in the template
   anyway, so we just preserve the **whole** provider block from
   the live file when it doesn't conflict).
4. Backup → atomic copy → restart.

User-added plugins persist across profile switches. Skill configs
under `config.skills.paths` are already merged by OpenCode's
`config()` hook, so the loader side needs no change.

**Trade-off:** the tray becomes responsible for "what's mine vs
yours". The base-vs-extras split is detected by structural
equality (object compare, not hash of the whole file), so a
hand-edited base that drifts from the template will still be
recognized.

### Option 2 — **Per-profile user-add file**

Add a sibling file per profile in the repo:

- `opencode.my-agents.user.jsonc`
- `opencode.ecc.user.jsonc`

User additions land in the `*.user.jsonc` for the currently active
profile. The tray deep-merges on switch: template + matching
user file → live `opencode.jsonc`. This is what `.gitignore`-style
split configs do.

**Trade-off:** user has to remember which profile they were on
when they ran `opencode plugin add`. If they switch and add,
they need to add to both `.user.jsonc` files (or the tray
prompts "also add to the other profile?"). Less automatic.

### Option 3 — **Manifest + reconcile**

A single `opencode.user.jsonc` in the repo that lists everything
the user wants globally (plugins + skills + custom providers).
The tray always starts from `template + user-manifest`. `opencode
plugin add` is intercepted (replaced by a tray action or a wrapper
script) to write to the manifest instead of the live config.

**Trade-off:** cleanest, but requires replacing the
`opencode plugin add` UX, which is invasive. Users who run plain
`opencode plugin add` outside the tray bypass the manifest and
break things.

## Why I recommend Option 1

- **Zero UX change.** `opencode plugin add` still works.
- **Zero template change.** `opencode.my-agents.jsonc` stays clean.
- **Single source of truth at runtime** — the live
  `opencode.jsonc`. Backups, hashing, status-tick detection all
  keep working.
- **No new repo files** to maintain.
- The detection is **structural** (compare each plugin entry
  against the template's base entries), so hand-edits to a base
  that drift from the template are still correctly classified as
  the base.

## Implementation sketch (Option 1)

In `setup/start-omniroute.vbs` (VBS-emitted PowerShell), replace
`Switch-OpenCodeProfile` with a layered-merge version:

```powershell
function Switch-OpenCodeProfile {
    param([string]$ProfileName)

    # ... existing guards: WSL ready, service not in transition ...

    $root = Deploy-ProfileTemplates
    if ($null -eq $root) { return }

    $livePath   = $root + '/opencode.jsonc'
    $tmplPath   = $root + '/profile.' + $ProfileName + '.json'
    $backupPath = $root + '/opencode.jsonc.bak'

    $live   = Read-JsonFile $livePath
    $tmpl   = Read-JsonFile $tmplPath
    if ($null -eq $live -or $null -eq $tmpl) { return }

    # ── Split live into base + user-extras ─────────────────────
    $liveBase, $userExtras = Split-PluginBlock $live.plugin $tmpl.plugin

    # ── Identity check: same profile already active? ──────────
    if (-not $userExtras -and (PluginBlockEqual $liveBase $tmpl.plugin)) {
        Write-TrayLog ('profile ' + $ProfileName + ' already active, no action')
        return
    }

    # ── Build merged config ───────────────────────────────────
    $merged = $tmpl.PSObject.Copy()
    $merged.plugin = $tmpl.plugin + $userExtras   # base first, user after
    # provider: preserve live providers the template didn't have
    if ($live.provider) {
        $mergedProviders = $tmpl.provider.PSObject.Copy()
        foreach ($k in $live.provider.Keys) {
            if (-not $mergedProviders.ContainsKey($k)) {
                $mergedProviders[$k] = $live.provider[$k]
            }
        }
        $merged.provider = $mergedProviders
    }

    # ── Backup + atomic write ─────────────────────────────────
    Copy-Item $livePath $backupPath -Force
    $mergedJson = $merged | ConvertTo-Json -Depth 20
    Set-Content -Path $livePath -Value $mergedJson -Encoding UTF8

    # ── Restart + wait ────────────────────────────────────────
    # ... existing restart block ...
}
```

New helpers needed in the VBS:

- `Read-JsonFile($path)` — read + parse; returns `$null` on error.
- `Split-PluginBlock($live, $templateBase)` — returns
  `($matched, $extras)`. Compares each live entry against each
  template-base entry by deep structural equality (or by the
  existing hash compare per entry).
- `PluginBlockEqual($a, $b)` — same.
- `Merge-ProviderBlock` — merged provider logic.

**What the user sees:** a `opencode.jsonc.bak` next to the live
config (so they can recover a hand-edit if the merge surprises
them), one line in `tray.log`:
```
merge: kept 2 user plugin(s): superpowers, foo
cp profile.ecc.json + 2 user extras -> opencode.jsonc
```

**Edge cases:**
- User ran `opencode plugin add` **before** the tray was upgraded
  → the live `opencode.jsonc` already has extras; first switch
  after upgrade preserves them. ✓
- User clears a profile by hand → live `plugin` block is empty
  but template has the base → first switch re-adds the base
  cleanly. ✓
- User duplicates the base manually with a different `ref` →
  the structural compare sees them as different; the duplicate
  is treated as a user-extra. Acceptable; logged as
  `merge: kept 1 user plugin(s) that overlap template base`.
- User adds a plugin that **replaces** the base (e.g. forks
  my-agents and uses their fork) → live `plugin[0]` no longer
  matches template `plugin[0]`; tray keeps the user's version
  (correct behavior — user override wins). The checkmark
  refresh will then show "Unknown active profile" until the
  user updates the template. ✓

## What changes — file by file

| File | Change |
|---|---|
| `plugin/load-agents.ts` | **No change.** The loader is already profile-agnostic — it only reads `agents/` and `options.externalSkills`. The new merge logic lives in the tray, not the loader. |
| `opencode.my-agents.jsonc` | **No change.** Keep clean. |
| `opencode.ecc.jsonc` | **No change.** Keep clean. |
| `setup/start-omniroute.vbs` | Replace `Switch-OpenCodeProfile` body with the layered-merge version above. Add `Read-JsonFile`, `Split-PluginBlock`, `PluginBlockEqual`, `Merge-ProviderBlock` helpers. Update the comment block (lines 256–259) to mention user-extras preservation. |
| `setup/README.md` | Update the "Switching OpenCode profiles" section to note that user-added plugins (`opencode plugin add …`) survive switches. |
| `setup/opencode/README.md` | Same update in the Profiles section. |
| `PLAN-OPENCODE-PROFILE-TOGGLE.md` | Add a "Amendment" note pointing at this plan. |

## Acceptance criteria

1. `opencode plugin add foo` while on my-agents → switch to ECC
   → switch back to my-agents → `foo` is still in the live
   `opencode.jsonc` `plugin` block. (Verified by `cat` of the
   live file before and after.)
2. `opencode.jsonc.bak` exists from the most recent switch and
   contains the pre-switch contents.
3. `tray.log` shows the merge line:
   `merge: kept N user plugin(s): …`.
4. Status-tick checkmark still works (hash of the live file
   compared against the two template hashes).
5. The two templates in the repo remain byte-identical to the
   pre-amendment versions (only the VBS changes).
6. `plugin/load-agents.ts` is unchanged.
