# ECC + My-Agents Integration

This repository integrates with **[affaan-m/ECC](https://github.com/affaan-m/ECC)**
("Elite Claude Code") as a **second agent profile**. Both profiles
share the same OmniRoute gateway and the same six free Engine Combos.

| Profile | Host | Pipeline |
|---|---|---|
| `my-agents` | DSH or OpenCode | My-Agents 6-stage: Researcher → Designer → Implementer → Optimizer → Tester → Reviewer |
| `ecc` | DSH or OpenCode | ECC's orchestrator + specialist swarm (68 agents, 286 skills, 94 commands) |

The `ECC/` directory in this repo is a **git submodule** that
mirrors the user's fork (`Venom120/ECC`). Additions to ECC that
are My-Agents-specific (DSH adapter, OmniRoute fallbacks) live
inside that submodule on a feature branch.

## Quick links

- **[HANDOFF-ECC.md](HANDOFF-ECC.md)** — full integration plan,
  workstreams, decisions, acceptance criteria, and open questions.
- **[ECC README](ECC/README.md)** — upstream project documentation.
- **[DSH preset for my-agents](dsh/agent-presets/my-agents/)** —
  the existing My-Agents preset.
- **[OMNIROUTE_DSH.md](OMNIROUTE_DSH.md)** and
  **[OMNIROUTE_OPENCODE.md](OMNIROUTE_OPENCODE.md)** — host-specific
  My-Agents documentation.

## Status

- [x] Workstream A — register ECC as a git submodule
- [ ] Workstream B — add a DSH adapter to ECC (upstream PR-friendly)
- [ ] Workstream C — OpenCode profile toggle
- [ ] Workstream D — document the integration end-to-end

See [HANDOFF-ECC.md](HANDOFF-ECC.md) for full details on each
workstream, the critical invariants that must not be broken, and
the acceptance criteria.
