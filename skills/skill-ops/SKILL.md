---
name: skill-ops
description: >
  自己進化するClaudeスキルのライフサイクル管理。新規スキル作成（TDDフロー）、
  進化サイクル実行、品質評価、卒業判定を統括する。
  「スキル作って」「skill-ops create」「スキルを進化させて」「skill evolve」
  「スキルの品質チェック」「卒業判定」などで起動。
---

# skill-ops

自己進化するClaudeスキルのメタ管理システム。SkillOpt / TPGO / Anthropic公式TDDフロー統合版。

## コマンド一覧

```
/skill-ops create <name>      新規スキルを7ステップTDDで作成
/skill-ops evolve <name>      進化サイクルを手動実行
/skill-ops judge <name>       品質評価（with-skill vs baseline）
/skill-ops graduate <name>    卒業プローブを実行
/skill-ops status [name]      スキルのライフサイクル状態を表示
/skill-ops inherit <child> --from <parent>  継承を実行
/skill-ops retrofit <name>    既存スキルを計測対象に変換（サイドカー生成）
/skill-ops migrate <name>|--all  既存スキルを最新形式へ移行（冪等）
/skill-ops list               全スキルの状態一覧
```

## 実行フロー

コマンドを受け取ったら `workflows/` の対応するワークフローを読み込む:

- `create` → `workflows/create.md`
- `evolve` → `workflows/evolve.md`
- `judge` → `workflows/judge.md`
- `graduate` → `workflows/graduate.md`
- `status` / `list` → `workflows/status.md`
- `inherit` → `workflows/inherit.md`
- `retrofit` → `workflows/retrofit.md`
- `migrate` → `scripts/migrate.sh`（直接実行・冪等）

## スキルデータディレクトリ構造（管理対象）

```
~/.claude/skills/{skill-name}/
├── SKILL.md              ← 常に best_skill.md と同一
├── best_skill.md         ← 最高evalスコアのバージョン
├── meta.yaml             ← ライフサイクル状態・統計
├── lineage.yaml          ← 継承関係・バージョン履歴
├── telemetry/
│   ├── invocations.jsonl ← 実利用ログ（append-only・集計の真実）
│   ├── feedback.jsonl    ← ユーザーFBログ（append-only）
│   ├── eval-runs.jsonl   ← 評価実行ログ（実利用と分離・カウント外）
│   └── eval-feedback.jsonl ← 評価中のFB（分離）
└── evals/
    ├── test-cases.json   ← 評価テストケース
    ├── contrast-buffer.jsonl ← 却下提案の記録
    └── results/
        └── {version}.json

（注: invocation_count 等は meta.yaml に持たず invocations.jsonl から集計）
```

## meta.yaml スキーマ（参照用）

→ `schemas/meta.yaml.schema` を参照（このスキルディレクトリ内）

## 計測スクリプト（scripts/）

skill-ops は POSIX シェルスクリプトでテレメトリを記録する（Mac/Linux 両対応、`sed -i` 不使用、外部依存なし）。デフォルト配置は `~/.claude/skills/skill-ops/scripts/`:

- `log_invocation.sh <skill> --outcome <success|failure|partial> [--rating <1|-1>] [--tool-calls N]`
- `log_feedback.sh <skill> --type <explicit|correction|implicit> [--content-hint <text>]`
- `skill_stats.sh <skill> | --all`
- `eval_lock.sh acquire|release|status <skill>` — 評価実行を実利用と分離
- `migrate.sh [--dry-run] <skill>|--all` — 既存スキルを最新形式へ移行
- `lib.sh` — 共通ライブラリ（各スクリプトが source）

これらは管理対象スキル（`~/.claude/skills/<skill>/`）の telemetry を読み書きし、スキル名から書き込み先を解決する（スクリプト自身の場所に非依存）。

### 「ログが単一の真実」（v0.2）

呼び出し回数・成功率は meta.yaml に書き戻さず、`telemetry/invocations.jsonl` の行数から `skill_stats.sh` が都度集計する。JSONL 追記は並行アトミックなので、複数セッション／マシン同時利用でも lost-update が起きない。

### 評価の分離

`judge`/`evolve` が対象スキルを実行する区間は `eval_lock.sh acquire` で囲む。その間の計測は `eval-runs.jsonl` に分離記録され、実利用カウントに混ざらない。ロックは同期されないマシンローカル（`$TMPDIR`）にスキル名スコープで作られる。

### 埋め込みパス

管理対象スキルへ埋め込む計測コマンドのパスはデフォルト `~/.claude/skills/skill-ops/scripts/`。別配置の場合は環境変数 `SKILL_OPS_SCRIPTS_PATH` で `migrate`/`retrofit` の埋め込み先を変更できる。テンプレートは `templates/telemetry-section.md.template`、移行は `migrate.sh`（`<!-- SKILLOPS_TELEMETRY_BEGIN/END -->` マーカー間を冪等再生成）。

## 重要な設計原則

1. **コンテキスト分離**: generator と judge は別サブエージェントで実行（確証バイアス防止）
2. **Bounded edits**: 1イテレーション4-8操作に制限（SkillOpt知見）
3. **Strict validation**: 同点は採用しない、contrast bufferに記録
4. **Fast/slow分離**: slow-state（推論パターン）とfast-state（セッション情報）を分ける
5. **Privacy-first**: テレメトリには入出力テキストを記録しない、行動パターンのみ
