# DeepSeek Harness (DSH) — Install + Service Guide

DeepSeek Harness (DSH) is the second host application that can run
the My-Agents pipeline. (The other is **OpenCode**; see
[`../opencode/README.md`](../opencode/README.md).)

This guide assumes you have **already installed OmniRoute** (see
[`../omniroute/README.md`](../omniroute/README.md)). DSH talks to
OmniRoute over `http://127.0.0.1:20128/v1`; it will not work without
it.

---

## What DSH does in this stack

- Loads the My-Agents preset from
  `github:Venom120/My-Agents#main` via the DSH plugin loader.
- Discovers one master agent + six hidden pipeline workers.
- Exposes the Master on a web UI at `http://localhost:3080`.
- The Master dispatches each stage to the right hidden worker, which
  is pinned to a single OmniRoute combo.

---

## 1. Install DSH

### Linux (systemd)

```bash
# 1. Install DSH globally
npm install -g @deepseek-ai/dsh

# 2. Install the bundled systemd unit
sudo cp setup/dsh/dsh.service /etc/systemd/system/
sudo systemctl daemon-reload

# 3. Make sure /root/.dsh exists and is writable by the dsh user
sudo mkdir -p /root/.dsh
sudo chown -R root:root /root/.dsh

# 4. Enable and start
sudo systemctl enable --now dsh
systemctl status dsh
```

DSH listens on `0.0.0.0:3000` by default. Confirm with:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000
# expect 200
```

### Linux (without systemd)

```bash
export NODE_OPTIONS=--max-old-space-size=8192
nohup dsh web --no-open > /tmp/dsh.log 2>&1 &
```

### Windows / WSL

If you run DSH from **WSL**, install it inside the WSL distro using
the Linux instructions above, then manage it from Windows using
[`../start-omniroute.vbs`](../start-omniroute.vbs). The tray has a
dedicated "DeepSeek Harness" submenu with Open / Start / Restart /
Stop / Startup (✓).

If you do not want the tray, run DSH inside WSL as a background
process and browse to `http://localhost:3000` from Windows.

### macOS / Docker

```bash
npm install -g @deepseek-ai/dsh
dsh web --no-open
```

---

## 2. Install the My-Agents preset

DSH loads the My-Agents preset from GitHub. The host downloads it —
you do **not** clone the repository manually.

### From the DSH CLI

```bash
# Add the My-Agents preset
dsh plugin --profile web add github:Venom120/My-Agents#main

# To update it later
dsh plugin --profile web update github:Venom120/My-Agents#main

# To remove it
dsh plugin --profile remove github:Venom120/My-Agents#main
```

### What this does

When the bundle is loaded, `dsh/sync-preset.js` synchronizes the
files under `dsh/agent-presets/my-agents/` into:

```text
$DSH_HOME/.agent-presets/my-agents/
```

With the default DSH install that is:

```text
/root/.dsh/.agent-presets/my-agents/
```

This makes the Git repository the single source of truth for the
preset. Reloading the bundle updates the generated user files.

The `setup/` folder inside the plugin is **excluded** by the DSH
preset loader; only `dsh/agent-presets/my-agents/` and
`dsh/sync-preset.js` are pulled in.

---

## 3. Verify the OmniRoute provider is registered

DSH needs to know about the six OmniRoute Engine Combos. The bundled
`settings.yaml` does this for you, but you can confirm by opening
DSH and checking the model picker.

```bash
# Confirm the file is in place
cat setup/dsh/settings.yaml
```

The provider block should include six models:

| Model id | Purpose |
|---|---|
| `free-coding-deep` | deep coding |
| `free-coding-standard` | normal coding |
| `free-coding-fast` | quick edits |
| `free-reasoning` | reasoning / control plane |
| `free-context` | long context |
| `free-vision` | images / vision |

The default agent model is `omniroute/free-reasoning`, which is the
Master's locked control plane.

If you need to change the `apiKeyEnv` or `baseURL` (e.g. you run
OmniRoute on a non-default port), edit `settings.yaml` and reload
DSH.

---

## 4. Verify

After installing:

1. Open `http://localhost:3000` in a browser.
2. Select the **master** agent.
3. Type a small task, e.g. `summarize this repo`.
4. The Master should propose a route and a pipeline mode.
5. Approve. The matching hidden worker should pick up the task and
   produce a `REPORT.md` under
   `.agents/agent-files/<stage>/REPORT.md` in the project you are
   working on.

If the Master reports `model not found`, re-run
`python3 omniroute_free_combos.py` in the `setup/omniroute/` folder
to make sure the six combos are registered with OmniRoute.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Master says `model not found` | The six Engine Combos are missing. Re-run `setup/omniroute/omniroute_free_combos.py`. |
| DSH UI loads but agents are empty | The preset failed to sync. Run `dsh plugin --profile web update github:Venom120/My-Agents#main` and restart DSH. |
| `setup/` files appear in `~/.dsh/.agent-presets/my-agents/` | They should not — only `dsh/agent-presets/my-agents/` is synchronized. If you see them, file a bug. |
| Tray on Windows says DSH is `failed` | Click tray → DeepSeek Harness → Start. systemd must be running inside WSL. |
| Worker writes `REPORT.md` in the wrong folder | The worker violated the strict file location rules. See `AGENTS.md` rule 12. |
| `dsh` command not found after npm install | Restart your shell or run `hash -r`. Make sure your global npm bin is on `$PATH`. |
