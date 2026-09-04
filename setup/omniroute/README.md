# OmniRoute — Install + Combo Guide

OmniRoute is the local AI gateway. My-Agents subagents talk to
OmniRoute over `http://127.0.0.1:20128/v1`, and OmniRoute forwards each
request to the real provider (OpenRouter, Mistral, Groq, NVIDIA,
Antigravity, Gemini, OpenCode, etc.).

Without OmniRoute, **no agent in this stack can run**.

---

## What OmniRoute is responsible for

- Provider/model selection inside a named **Engine Combo**.
- Retries, cooldowns, model lockout.
- Request queueing, compression.
- Provider health monitoring and resilient failover.

It is **not** responsible for picking the route / combo. The My-Agents
Master decides the route (one of the six combos) and OmniRoute does
the rest.

---

## 1. Install OmniRoute

### Linux (systemd)

```bash
# 1. Download and install the binary
curl -fsSL https://get.omniroute.ai | sh

# 2. Install the bundled systemd unit
sudo cp setup/omniroute/omniroute.service /etc/systemd/system/
sudo systemctl daemon-reload

# 3. Make sure /etc/omniroute/omniroute.env exists
sudo mkdir -p /etc/omniroute
sudo tee /etc/omniroute/omniroute.env > /dev/null <<'EOF'
OMNIROUTE_API_KEY=paste-your-inference-key-here
OMNIROUTE_MANAGE_KEY=paste-your-admin-key-here
EOF
sudo chmod 600 /etc/omniroute/omniroute.env

# 4. Enable and start
sudo systemctl enable --now omniroute
systemctl status omniroute
```

OmniRoute listens on `0.0.0.0:20128` by default. Confirm with:

```bash
curl -s http://127.0.0.1:20128/v1/models | head -c 200
```

### Linux (without systemd)

If you do not want systemd, just run the binary directly:

```bash
export OMNIROUTE_API_KEY=...
export OMNIROUTE_MANAGE_KEY=...
nohup omniroute > /tmp/omniroute.log 2>&1 &
```

### Windows / WSL

If you run OmniRoute from Windows itself, the bundled
[`../start-omniroute.vbs`](../start-omniroute.vbs) tray launcher is the
easiest way to manage it. See the [top-level README](../README.md) for
where to put the file and how to edit the distro name.

If you run OmniRoute from **WSL**, install it inside the WSL distro
using the Linux instructions above, then drop the tray launcher in
your Windows Startup folder. The tray will manage the systemd
services inside WSL.

### macOS / Docker

For macOS or container-only environments, follow the official
OmniRoute install instructions at <https://get.omniroute.ai>. The two
Python scripts in this folder work the same way regardless of host.

---

## 2. Build the six My-Agents Engine Combos

Once OmniRoute is running, create the six Engine Combos that
My-Agents subagents route against.

```bash
# 1. Install Python requests
pip install requests

# 2. Export the management key
export OMNIROUTE_MANAGE_KEY='paste-your-admin-key-here'

# 3. Run the combo builder
cd setup/omniroute
python3 omniroute_free_combos.py
```

The script is **idempotent**: it creates missing combos and updates
existing ones. Unrelated combos are never touched.

The six combos it creates are:

| Combo | Pinned worker | Use |
|---|---|---|
| `free-coding-deep` | `pipeline-worker-deep` | complex multi-step coding, hard debugging |
| `free-coding-standard` | `pipeline-worker-standard` | normal coding, most Implementer/Designer work |
| `free-coding-fast` | `pipeline-worker-fast` | quick edits, small fixes, trivial work |
| `free-reasoning` | `pipeline-worker-reasoning` | Master control plane, planning, Reviewer |
| `free-context` | `pipeline-worker-context` | huge context (1M+), full-repo audits |
| `free-vision` | `pipeline-worker-vision` | images, screenshots, diagrams |

The combo names are **locked** — do not rename a combo in this script
without also renaming the matching `model:` field in the
corresponding `pipeline-worker-*.md` (and the `agent.cordis.yml`
persona).

---

## 3. (Optional) Refresh the model list

If you want to see the current provider/model pool (e.g. before
auditing the combo file), run:

```bash
cd setup/omniroute
export OMNIROUTE_MANAGE_KEY='paste-your-admin-key-here'
python3 list-models-omniroute.py
```

This produces four files in the current directory:

- `omniroute_models.csv`
- `omniroute_providers.csv`
- `omniroute_models_raw.json`
- `omniroute_providers_raw.json`

These are gitignored. They are not consumed by any agent; they exist
only for human review. If a model disappears from OmniRoute, the combo
builder will simply skip it and move to the next priority entry.

---

## 4. Verify

After installing OmniRoute and running the combo builder:

```bash
# List all configured engines
curl -s http://127.0.0.1:20128/v1/engines | jq

# Should include:
#   free-coding-deep
#   free-coding-standard
#   free-coding-fast
#   free-reasoning
#   free-context
#   free-vision
```

If all six combos show up, the OpenCode and DSH hosts will be able
to dispatch tasks through the My-Agents pipeline.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `OMNIROUTE_MANAGE_KEY is not set` | The combo builder needs the **management** key, not the inference key. Export it before running. |
| `Connection refused` on `127.0.0.1:20128` | OmniRoute is not running. Run `systemctl status omniroute` (Linux) or start it manually. |
| A combo is missing | Re-run `omniroute_free_combos.py`. It is idempotent. |
| `401 Unauthorized` | Wrong API key. Re-issue from the OmniRoute dashboard. |
| Tray on Windows reports `failed` for OmniRoute | Open the tray menu → OmniRoute → Start. The tray uses `systemctl` under the hood, so systemd must be running inside WSL. |
