# Changelog

All notable changes to skill-ops are documented here.
This project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-06-01

### Added
- Initial release.
- `skill-ops` meta-skill with commands: `create`, `retrofit`, `judge`, `evolve`, `graduate`, `inherit`, `status`, `list`.
- Lifecycle state machine: `draft → active → evolving → graduated/retired`.
- Evolution pipeline based on SkillOpt (bounded edits, strict validation gate, contrast buffer, fast/slow section split) and TPGO (δ⁻ generalization before clustering).
- Sub-agents: `skill-reflector`, `skill-optimizer`, `skill-judge` (context-separated to avoid confirmation bias).
- Telemetry scripts: `log_invocation.sh`, `log_feedback.sh`, `skill_stats.sh` (behavior-only, privacy-first).
- Templates and schemas: `meta.yaml`, `SKILL.md`, measurement-section.
- Plugin packaging: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`.

### Known limitations
- `${CLAUDE_PLUGIN_ROOT}` path stability for embedded measurement scripts (see README).
- Evaluation runs are counted as invocations (`--no-log` planned).
- No unattended scheduler; evolution is triggered on-demand.
