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

## スキルデータディレクトリ構造（管理対象）

```
~/.claude/skills/{skill-name}/
├── SKILL.md              ← 常に best_skill.md と同一
├── best_skill.md         ← 最高evalスコアのバージョン
├── meta.yaml             ← ライフサイクル状態・統計
├── lineage.yaml          ← 継承関係・バージョン履歴
├── telemetry/
│   ├── invocations.jsonl ← 呼び出しログ（append-only）
│   └── feedback.jsonl    ← ユーザーFBログ（append-only）
└── evals/
    ├── test-cases.json   ← 評価テストケース
    ├── contrast-buffer.jsonl ← 却下提案の記録
    └── results/
        └── {version}.json
```

## meta.yaml スキーマ（参照用）

→ `schemas/meta.yaml.schema` を参照（このスキルディレクトリ内）

## 計測スクリプト

skill-ops は3つのシェルスクリプトでテレメトリを記録する。プラグインとしてインストールされた場合 `${CLAUDE_PLUGIN_ROOT}/scripts/` に配置される:

- `${CLAUDE_PLUGIN_ROOT}/scripts/log_invocation.sh <skill> --outcome <success|failure|partial> [--rating <1|-1>] [--tool-calls N]`
- `${CLAUDE_PLUGIN_ROOT}/scripts/log_feedback.sh <skill> --type <explicit|correction|implicit> [--rating <1|-1>] [--content-hint <text>]`
- `${CLAUDE_PLUGIN_ROOT}/scripts/skill_stats.sh <skill> | --all`

これらは管理対象スキル（`~/.claude/skills/<skill>/`）の telemetry/meta.yaml を読み書きする。スクリプト自身の場所には依存せず、引数のスキル名から書き込み先を解決する。

**重要（パス安定性）**: 管理対象スキルの SKILL.md へ計測セクションを埋め込む際は、`${CLAUDE_PLUGIN_ROOT}` を**埋め込み時点で絶対パスへ解決**してから書き込むこと。対象スキルが起動された時の `${CLAUDE_PLUGIN_ROOT}` は別プラグインを指すため。埋め込みテンプレートは `templates/telemetry-section.md.template`。

## 重要な設計原則

1. **コンテキスト分離**: generator と judge は別サブエージェントで実行（確証バイアス防止）
2. **Bounded edits**: 1イテレーション4-8操作に制限（SkillOpt知見）
3. **Strict validation**: 同点は採用しない、contrast bufferに記録
4. **Fast/slow分離**: slow-state（推論パターン）とfast-state（セッション情報）を分ける
5. **Privacy-first**: テレメトリには入出力テキストを記録しない、行動パターンのみ
