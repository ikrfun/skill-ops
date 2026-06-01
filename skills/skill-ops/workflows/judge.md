# Workflow: judge — スキル品質評価

---

## 目的

`with-skill` vs `baseline`（スキルなし）の品質を比較し、スキルの実際の貢献度を定量化。

---

## Step 1: テストケース読み込み

`~/.claude/skills/{name}/evals/test-cases.json` を読み込む。

テストケースがない場合:
→ 「評価テストケースが未設定です。3件以上のテストケースを作成してください」

## Step 2: Baseline 実行

**@skill-judge** サブエージェントを「スキルなし」モードで起動:

```
指示:
「以下のテストケースをClaude Codeのデフォルト機能のみで実行してください。
 skill-opsや{name}スキルは使わずに、素のClaude能力で回答してください。
 各回答に quality_score (0-100) を付けてください」

採点基準:
- 完全性 30点: 期待コンポーネントが揃っているか
- 正確性 30点: 事実・推論の正確さ
- 構造性 20点: 整理・読みやすさ
- 効率性 20点: 余分な情報が少ない
```

## Step 3: with-skill 実行

**@skill-judge** を「with-skill」モードで起動（別サブエージェント）:

```
指示:
「以下のテストケースを{name}スキルを使って実行してください。
 各回答に quality_score (0-100) を付けてください」
```

## Step 4: 結果集計・レポート生成

```
📊 スキル「{name}」品質評価レポート
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

バージョン: {version}
評価日: {today}

テストケース別スコア:
  Case 1: with-skill {ws1}点 / baseline {b1}点 (+{d1})
  Case 2: with-skill {ws2}点 / baseline {b2}点 (+{d2})
  Case 3: with-skill {ws3}点 / baseline {b3}点 (+{d3})

総合:
  with-skill 平均: {ws_avg}点
  baseline 平均:  {b_avg}点
  スキル貢献度:   +{delta_avg}点 ({contribution_pct}%)

卒業ギャップ: {gap}% (閾値: 10%未満で卒業候補)

判定:
  {quality_status}  ← ◎良好 / ○普通 / △改善余地 / ×要見直し
  {graduation_hint} ← 卒業候補の場合のみ表示
```

## Step 5: 結果保存

`evals/results/{version}.json` に保存し、`meta.yaml` を更新:

```yaml
current_quality_score: {ws_avg}
baseline_quality_score: {b_avg}
last_evaluated: "{today}"
```

---

## オプション: --add-cases

`/skill-ops judge {name} --add-cases` の場合:
評価後、「追加テストケースを作成しますか？」と確認し、必要に応じて追加。
