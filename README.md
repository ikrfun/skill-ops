# skill-ops

> A self-evolving skill lifecycle manager for [Claude Code](https://docs.claude.com/en/docs/claude-code/overview). Treat your Agent Skills as living artifacts: **create → measure → evolve → graduate**.

skill-ops is a *meta-skill* — a skill that manages other skills. It records how each of your skills performs (usage telemetry + user feedback), runs an evaluation-gated improvement loop on the `SKILL.md`, and can even decide when a skill has become redundant (the model now does it natively) and **graduate** it.

The design fuses three lines of work:

- **SkillOpt** (Microsoft Research, arXiv:2605.23904) — treat `SKILL.md` as a trainable text parameter; bounded edits, strict validation gate, contrast buffer, fast/slow section split.
- **TPGO "Learning to Evolve"** (arXiv:2604.20714) — turn raw logs into generalized failure diagnoses (δ⁻) before clustering, so one-off failures don't cause overfitting.
- **Anthropic's evaluation-driven skill development** — baseline vs. with-skill scoring, the Claude-A / Claude-B (author / tester) separation.

---

## How it works

### Lifecycle state machine

```
 create ─► draft ─► active ─► evolving ─► active (loop)
                       │
                [graduation probe: model ≈ skill]
                       ▼
                  graduated ─► retired (tombstone kept)
```

| State | Meaning | Transition |
|-------|---------|-----------|
| `draft` | Created, baseline not yet measured | after `create` / `retrofit` |
| `active` | Running normally, logging telemetry | ≥3 test cases evaluated, with-skill > baseline, score ≥ 70 |
| `evolving` | Improvement cycle running (write-locked) | every `evolution_threshold` invocations (default 20) |
| `graduated` | Model handles it natively → skill redundant | graduation gap < 10% + user confirmation |
| `retired` | Deprecated, kept as a tombstone | manual, or unused for 30 days |

### The evolution loop (SkillOpt-based)

```
telemetry (last N failures)
   └─► skill-reflector  → δ⁻ generalized failure patterns
        └─► cluster (drop one-off noise)
             └─► skill-optimizer → ≤8 bounded edits to SKILL.md
                  └─► skill-judge → score proposal vs current (blind)
                       ├─ PASS (strict improvement) → bump version, update best_skill.md
                       └─ FAIL → store in contrast-buffer.jsonl, keep current
```

Author (`skill-optimizer`) and reviewer (`skill-judge`) always run as **separate sub-agents** to avoid confirmation bias.

---

## Installation

```bash
# 1. Add this repo as a plugin marketplace
/plugin marketplace add ikrfun/skill-ops

# 2. Install the plugin
/plugin install skill-ops@ikrfun-skills
```

Or for local development:

```bash
claude --plugin-dir /path/to/skill-ops
```

---

## Usage

```
/skill-ops create <name>                     Create a new skill via 7-step TDD flow
/skill-ops retrofit <name>                   Bring an existing skill under measurement
/skill-ops judge <name>                      Measure quality (with-skill vs baseline)
/skill-ops evolve <name>                     Run an improvement cycle
/skill-ops graduate <name>                   Run the graduation probe
/skill-ops inherit <child> --from <parent>   Inherit improvements from a parent skill
/skill-ops status <name>                     Show one skill's lifecycle state
/skill-ops list                              List all managed skills
```

### Quick start: measure an existing skill

```
/skill-ops retrofit research      # adds meta.yaml, telemetry/, evals/, appends a measurement section
/skill-ops judge research         # scores with-skill vs baseline → promotes draft → active
```

---

## How skills are measured

Each managed skill gets sidecar files alongside its `SKILL.md`:

```
~/.claude/skills/<skill>/
├── SKILL.md                  # body untouched; measurement section appended at the end
├── best_skill.md             # highest-scoring validated version
├── meta.yaml                 # lifecycle state, counters, thresholds
├── lineage.yaml              # parent/child relations, version history
├── telemetry/
│   ├── invocations.jsonl     # one line per run (behavior only — never input/output text)
│   └── feedback.jsonl        # explicit / correction / implicit feedback
└── evals/
    ├── test-cases.json       # ≥3 realistic cases with expected_properties
    ├── contrast-buffer.jsonl # rejected proposals (learned-from-failure)
    └── results/<version>.json
```

A run is recorded by the bundled scripts:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/log_invocation.sh <skill> --outcome success --tool-calls 8 [--rating 1]
${CLAUDE_PLUGIN_ROOT}/scripts/log_feedback.sh  <skill> --type correction --content-hint "..."
${CLAUDE_PLUGIN_ROOT}/scripts/skill_stats.sh   <skill> | --all
```

**Privacy by design:** telemetry stores *behavior* (duration, tool count, outcome, rating) only. Your prompts and the skill's outputs are never written to disk.

### The judge (evaluation gate)

`skill-judge` scores each test case on four axes (completeness / accuracy / structure / efficiency, 25 pts each). It compares **with-skill** vs **baseline** (no skill). A change is accepted only on a *strict* improvement with **no regressions** — ties are rejected and stored in the contrast buffer.

Example from the bundled `research` skill (case: "How to choose a vector DB for RAG"):

| | completeness | accuracy | structure | efficiency | total |
|---|---|---|---|---|---|
| with-skill | 25 | 24 | 23 | 23 | **95** |
| baseline | 19 | 22 | 24 | 24 | **78** |

`delta = +17`, gate = PASS, graduation gap = 82% (< 90% → the skill clearly adds value, far from graduation).

---

## Architecture

| Component | Role | Model |
|-----------|------|-------|
| `skill-ops` (SKILL.md + workflows) | Orchestrator / commands | — |
| `agents/skill-reflector.md` | Turn failure logs into generalized δ⁻ patterns | Sonnet |
| `agents/skill-optimizer.md` | Propose ≤8 bounded edits to SKILL.md | Opus |
| `agents/skill-judge.md` | Blind, independent quality scoring | Opus |
| `scripts/*.sh` | Telemetry logging & stats (no external deps) | — |
| `templates/`, `schemas/` | meta.yaml / SKILL.md / measurement-section templates | — |

---

## Design principles

1. **Context separation** — generator and judge are different sub-agents (no confirmation bias).
2. **Bounded edits** — at most 4–8 edit operations per iteration (SkillOpt: removing this caused performance collapse).
3. **Strict validation** — ties are rejected; rejected proposals feed a contrast buffer.
4. **Fast/slow split** — stable reasoning patterns (`SLOW_STATE`) are protected from volatile session notes (`FAST_STATE`).
5. **Privacy-first** — only behavioral telemetry is stored, never input/output text.

---

## Known limitations

- **Plugin path stability for embedded scripts.** When `retrofit`/`create` embeds the measurement section into a managed skill's `SKILL.md`, it must resolve `${CLAUDE_PLUGIN_ROOT}` to an **absolute path** at embed time, because at the managed skill's runtime `${CLAUDE_PLUGIN_ROOT}` points to a different plugin. Re-installing skill-ops from a marketplace can change that path; if you re-install, re-run `retrofit` or keep skill-ops at a stable location. (A future version may copy scripts to a stable `${CLAUDE_PLUGIN_DATA}` directory.)
- **Evaluation runs count as invocations.** A `judge`/`evolve` run that actually executes the skill will be logged like a normal use. A `--no-log` mode for evaluation is planned.
- **Single-sample noise.** A one-case judge result is indicative, not conclusive — promote to `active` only after all test cases are evaluated.
- **No automatic scheduler yet.** Evolution is triggered on-demand or when the invocation threshold is hit and surfaced as a recommendation; it does not run unattended.

---

## License

MIT © ikrfun. See [LICENSE](./LICENSE).
