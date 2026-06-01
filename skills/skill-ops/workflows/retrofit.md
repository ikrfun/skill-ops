# Workflow: retrofit — 既存スキルを計測対象に変換

既存の（skill-ops管理外の）スキルに、サイドカーファイル群を追加してライフサイクル管理下に置く。
**既存の SKILL.md 本体は一切書き換えず、末尾への追記とサイドカー生成のみ行う。**

---

## Step 0: 対象確認

`~/.claude/skills/{name}/` が存在すること。既に `meta.yaml` がある場合は「すでに管理対象です」と通知して終了。

## Step 1: SKILL.md を読んで理解する

対象スキルの目的・ワークフロー・出力形式を把握する。

## Step 2: evals/test-cases.json を作成（最低3件）

このスキルの典型ユースケースを表す現実的なテストケースを設計する。

```json
{
  "skill": "{name}",
  "version_created": "0.1.0",
  "cases": [
    { "id": 1, "description": "...", "prompt": "<実際にユーザーが打ちそうな依頼>", "expected_properties": ["...","...","..."], "min_quality_score": 70 }
  ]
}
```

ケースは多様性を持たせる（典型・エッジ・失敗しやすいケース）。各 `expected_properties` は3項目以上。

## Step 3: meta.yaml を作成

`templates/meta.yaml.template` の `{{SKILL_NAME}}` `{{DATE}}` を置換し、`eval_test_cases` を実際の件数に設定。
`status` は `draft`（baseline未計測のため）。

## Step 4: lineage.yaml を作成

```yaml
skill: {name}
parent: null
children: []
version_history:
  - version: "0.1.0"
    date: "{today}"
    note: "skill-ops 管理下に登録（retrofit）"
    parent_version: null
inheritance_policy:
  auto_inherit: false
  inherit_sections: []
  override_sections: []
```

## Step 5: telemetry / evals を初期化

```bash
mkdir -p ~/.claude/skills/{name}/telemetry ~/.claude/skills/{name}/evals/results
touch ~/.claude/skills/{name}/telemetry/invocations.jsonl
touch ~/.claude/skills/{name}/telemetry/feedback.jsonl
touch ~/.claude/skills/{name}/evals/contrast-buffer.jsonl
```

## Step 6: 計測セクションを SKILL.md 末尾に追記（本体は変更しない）

最も確実なのは `migrate.sh`（マーカー付き・冪等・FAST_STATE 保持）:

```bash
bash ~/.claude/skills/skill-ops/scripts/migrate.sh {name}
```

手動の場合は `templates/telemetry-section.md.template` を読み、`{{SKILL_NAME}}` を対象スキル名、`{{SKILLOPS_SCRIPTS}}` を `~/.claude/skills/skill-ops/scripts`（別配置なら環境変数 `SKILL_OPS_SCRIPTS_PATH`）に置換して末尾に追記する。`<!-- SKILLOPS_TELEMETRY_BEGIN/END -->` マーカーを残すこと。

埋め込み後、本体の見出し数が変わっていないこと（追記のみ）を確認する。

## Step 7: 完了報告

```
✅ {name} を skill-ops 計測対象に変換しました

📁 追加: meta.yaml / lineage.yaml / telemetry/ / evals/
📝 SKILL.md 末尾に計測セクションを追記（本体は無変更）

現在の状態: draft（baseline未計測）
→ /skill-ops judge {name} で baseline を計測し、active 昇格へ
```
