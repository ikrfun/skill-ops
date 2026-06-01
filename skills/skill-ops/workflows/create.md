# Workflow: create — 新規スキル作成（7ステップTDDフロー）

Anthropic公式 Evaluation-Driven Development + SkillOpt初期化フロー。

---

## Step 0: 前準備

引数からスキル名を取得。`~/.claude/skills/{name}/` が既に存在する場合は上書き確認。

## Step 1: Intent 定義

以下をヒアリング（未指定の場合のみ）:

```
目的: スキルが解決する問題（1-2文）
対象タスク: どんな入力に対して動くか
期待出力: どんな形式・品質の出力を返すか
親スキル: 既存スキルを継承するか（任意）
```

## Step 2: テストケース作成（最低3件）

ユーザーと協議して、または自動生成:

```json
{
  "skill": "{name}",
  "version_created": "0.1.0",
  "cases": [
    {
      "id": 1,
      "description": "典型的な成功ケース",
      "prompt": "...",
      "expected_properties": ["期待する特性1", "期待する特性2"],
      "min_quality_score": 70
    },
    {
      "id": 2,
      "description": "エッジケース",
      ...
    },
    {
      "id": 3,
      "description": "失敗しやすいケース",
      ...
    }
  ]
}
```

`~/.claude/skills/{name}/evals/test-cases.json` に保存。

## Step 3: ベースライン計測

**@skill-judge** を起動してベースライン（スキルなし）スコアを計測:

```
skill-judgeへの指示: 以下のテストケースを「スキルなし」で実行し、
quality_scoreを付けてください。スキルは使わず、素のClaude能力で回答してください。
```

結果を `meta.yaml.baseline_quality_score` に記録。

## Step 4: 最小限のSKILL.md を作成

SkillOpt推奨: **最初は最小限**。過剰な設計は避ける。

### SKILL.md テンプレート

```markdown
---
name: {name}
description: >
  （スキルが自動トリガーされるための明確な説明。
   ユーザーが「XXXして」と言ったときに起動すること）
---

# {name}

（スキルの目的・概要 1-2行）

<!-- SLOW_STATE_BEGIN -->
## 評価基準

（このタスクで「良い結果」とは何かの定義）

## 実行パターン

（推奨アプローチ・手順）
<!-- SLOW_STATE_END -->

<!-- FAST_STATE_BEGIN -->
## 最新の注意事項

（直近の改善サイクルで追加された注意点）
<!-- FAST_STATE_END -->
```

**SLOW_STATE**: 変更頻度が低い推論パターン・ガイドライン
**FAST_STATE**: 変更頻度が高い最新注意事項・セッション情報

## Step 5: 初回eval 実行

**@skill-judge** を起動してwith-skill スコアを計測。
ベースラインと比較。

期待:
- `with_skill_score > baseline_score` (スキルが実際に貢献している)
- `with_skill_score >= 70`

## Step 6: meta.yaml + lineage.yaml を作成

```yaml
# meta.yaml
name: {name}
version: "0.1.0"
status: draft  # テスト3件未満の場合。3件以上かつeval合格でactive
parent_skill: {parent | null}
children_skills: []
invocation_count: 0
success_count: 0
failure_count: 0
last_invoked: null
last_evaluated: "{today}"
last_evolved: null
evolution_threshold: 20
graduation_threshold: 100
graduation_score_gap_pct: 10
evolution_consecutive_failures: 0
evolution_cooldown_multiplier: 1
eval_test_cases: {n}
current_quality_score: {score}
baseline_quality_score: {baseline}
created_at: "{today}"
```

## Step 7: description 最適化

スキルの `description` は**発動確率に最大影響を与える**要素。

以下を確認:
- ユーザーが実際に使う言葉（「調べて」「リサーチして」等）が含まれているか
- 具体的なトリガーフレーズが3つ以上含まれているか
- 1024文字以内か

必要に応じて description を改善し、再テスト。

## 完了報告

```
✅ スキル「{name}」を作成しました

📊 初回eval結果:
  with-skill: {score}点
  baseline: {baseline}点
  スキル貢献度: +{delta}点

📁 作成ファイル:
  ~/.claude/skills/{name}/SKILL.md
  ~/.claude/skills/{name}/meta.yaml
  ~/.claude/skills/{name}/evals/test-cases.json

🔄 次のステップ:
  実際に使ってみてフィードバックを蓄積する
  {evolution_threshold}回呼び出し後に自動改善サイクルが発動
```
