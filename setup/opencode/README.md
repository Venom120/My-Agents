# OpenCode — Install + Service Guide

OpenCode is one of the two host applications that can run the
My-Agents pipeline. (The other is **DeepSeek Harness**; see
[`../dsh/README.md`](../dsh/README.md).)

This guide assumes you have **already installed OmniRoute** (see
[`../omniroute/README.md`](../omniroute/README.md)). OpenCode talks to
OmniRoute over `http://127.0.0.1:20128/v1`; it will not work without
it.

---

## What OpenCode does in this stack

- Loads the My-Agents preset from `github:Venom120/My-Agents#main`
  via the `plugin/load-agents.ts` plugin loader.
- Discovers seven agents (Master + six hidden pipeline workers).
- Exposes the Master on a web UI at `http://localhost:4096`.
- The Master dispatches each stage to the right hidden worker, which
  is pinned to a single OmniRoute combo.

---

## 1. Install OpenCode

### Linux (systemd)

```bash
# 1. Install the OpenCode binary
curl -fsSL https://get.opencode.ai | sh

# 2. Install the bundled systemd unit
sudo cp setup/opencode/opencode.service /etc/systemd/system/
sudo systemctl daemon-reload

# 3. Make sure /etc/opencode/opencode.env exists
sudo mkdir -p /etc/opencode
sudo tee /etc/opencode/opencode.env > /dev/null <<'EOF'
OPENCODE_CONFIG_DIR=/root/.opencode
OPENCODE_DATA_DIR=/root/.opencode
OMNIROUTE_API_KEY=same-key-you-gave-omniroute
EOF
sudo chmod 600 /etc/opencode/opencode.env

# 4. Enable and start
sudo systemctl enable --now opencode
systemctl status opencode
```

OpenCode listens on `0.0.0.0:4096`. Confirm with:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:4096
# expect 200
```

### Linux (without systemd)

```bash
export OPENCODE_ENABLE_EXA=1
export OMNIROUTE_API_KEY=...
nohup opencode web --hostname 0.0.0.0 --port 4096 \
  > /tmp/opencode.log 2>&1 &
```

### Windows / WSL

If you run OpenCode from **WSL**, install it inside the WSL distro
using the Linux instructions above, then manage it from Windows using
[`../start-omniroute.vbs`](../start-omniroute.vbs). The tray has a
dedicated "OpenCode" submenu with Open / Start / Restart / Stop /
Startup (✓).

If you do not want the tray, run OpenCode inside WSL as a background
process and browse to `http://localhost:4096` from Windows.

### macOS / Docker

Follow the official OpenCode install instructions at
<https://opencode.ai>. The My-Agents preset is loaded the same way
regardless of host.

---

## 2. Install the My-Agents preset

OpenCode loads the My-Agents preset from GitHub. You do **not** clone
the repository manually; the host downloads it.

### From the OpenCode CLI

```bash
opencode plugin add github:Venom120/My-Agents#main
```

### From the OpenCode config

Add this to your OpenCode config (`~/.config/opencode/config.json` or
`OPENCODE_CONFIG_DIR/opencode.json`):

```json
{
  "plugin": ["github:Venom120/My-Agents#main"]
}
```

Restart OpenCode after the change:

```bash
sudo systemctl restart opencode
```

The plugin loader (`plugin/load-agents.ts`) registers:

| Agent | Model | Purpose |
|---|---|---|
| `master` | `omniroute/free-reasoning` | Control plane. Always runs first. |
| `pipeline-worker-deep` | `omniroute/free-coding-deep` | complex coding |
| `pipeline-worker-standard` | `omniroute/free-coding-standard` | normal coding |
| `pipeline-worker-fast` | `omniroute/free-coding-fast` | quick edits |
| `pipeline-worker-reasoning` | `omniroute/free-reasoning` | reasoning |
| `pipeline-worker-context` | `omniroute/free-context` | long context |
| `pipeline-worker-vision` | `omniroute/free-vision` | images / vision |

The `setup/` folder inside the plugin is **excluded** by the loader —
it will not be copied into OpenCode's package cache.

---

## 3. Verify

After installing:

1. Open `http://localhost:4096` in a browser.
2. Select the **master** agent.
3. Type a small task, e.g. `summarize this repo`.
4. The Master should propose a route and a pipeline mode.
5. Approve. The matching hidden worker should pick up the task and
   produce a `REPORT.md` under
   `.agents/agent-files/<stage>/REPORT.md` in the project you are
   working on.

If the Master reports `model not found`, re-run
`python3 omniroute_free_combos.py` in the `setup/omniroute/` folder
to make sure the six combos are registered.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Master says `model not found` | The six Engine Combos are missing. Re-run `setup/omniroute/omniroute_free_combos.py`. |
| OpenCode UI loads but agents are empty | The plugin failed to load. Run `opencode plugin list` and look for errors. |
| `setup/` files appear in OpenCode's cache | They should not — the plugin loader is hard-coded to only walk `agents/`. If you do see them, file a bug. |
| Tray on Windows says OpenCode is `failed` | Click tray → OpenCode → Start. systemd must be running inside WSL. |
| Worker writes `REPORT.md` in the wrong folder | The worker violated the strict file location rules. See `AGENTS.md` rule 12. |
