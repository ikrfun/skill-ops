# Changelog

All notable changes to skill-ops are documented here.
This project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-06-01

3観点の adversarial 設計レビューで初期の bin/env 方式の破綻を発見し、最小堅牢版に再設計。

### Changed
- **「ログが単一の真実」**: meta.yaml の invocation_count / success_count / failure_count / last_invoked を廃止し、`telemetry/invocations.jsonl` の集計に変更（並行 lost-update レースを構造的に排除）。
- `sed -i` を全廃し Mac/Linux 両対応に（共通処理を `scripts/lib.sh` に集約）。
- 埋め込みパスを現状固定（`~/.claude/skills/skill-ops/scripts/`、`SKILL_OPS_SCRIPTS_PATH` で上書き可）に変更し、bin ブートストラップ案を破棄。

### Added
- `scripts/eval_lock.sh`: 評価実行（judge/evolve）を実利用と分離。スキル名スコープ・同期されないマシンローカルのロック。評価中の計測は `eval-runs.jsonl` / `eval-feedback.jsonl` へ。
- `scripts/migrate.sh`: 既存スキルを最新形式へ冪等移行（FAST_STATE 改善メモは保持）。
- 計測セクションを `<!-- SKILLOPS_TELEMETRY_BEGIN/END -->` マーカーで囲み、機械的に再生成可能に。
- 埋め込みコマンドに `bash` プレフィックス＋失敗時 `|| echo '⚠️'` でサイレント故障を可視化。

### Fixed
- `log_invocation.sh` の `sed -i ''` が Linux(GNU sed) で計測を落とすバグ（`.claude` が Syncthing 同期される環境で顕在）。
- meta.yaml カウンタの lost-update レース（実測: 20並行で18件ロスト）。
- `count_invocations` の空ファイル時の二重出力。

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
