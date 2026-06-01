# Workflow: graduate — 卒業プローブ

---

## 目的

モデルの能力向上によりスキルが冗長になっていないかをチェックし、
条件を満たす場合は卒業（Graduated）を提案する。

---

## Step 1: 前提確認

```
meta.yaml.status == "active"
meta.yaml.invocation_count >= graduation_threshold（デフォルト100）
meta.yaml.eval_test_cases >= 3
```

条件未達の場合は早期終了:
```
ℹ️ 卒業プローブの条件未達:
   invocation_count: {count} / {threshold}回必要
   評価テストケース: {cases}件 / 3件必要
```

## Step 2: 卒業プローブ実行

`judge.md` の Step 2-3 と同じ評価を実行し、現時点の gap を計算:

```
gap = (baseline_score / with_skill_score) * 100
```

## Step 3: 判定

```
gap >= 90%: 卒業候補 → ユーザーに提案
gap >= 80%: 注意（スキル価値が低下） → ログのみ
gap < 80%:  スキルの価値が大きい → 卒業なし
```

## Step 4: 卒業提案（gap >= 90% の場合）

```
📊 スキル「{name}」の卒業プローブ結果
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

with-skill 平均スコア: {ws}点
baseline 平均スコア:   {b}点
スキル貢献度:          {gap}% の類似性

💡 判定: 卒業候補
   Claude {model}はこのスキルの機能の大部分を
   ネイティブに実行できるようになっています。

このスキルを卒業させますか？
[1] 卒業させる（tombstoneを残置してgradulated状態に）
[2] 継続使用（利用頻度が高い場合はこちら）
[3] 評価ケースを追加して再評価（スキル価値が過小評価されている可能性）
```

ユーザーが [1] を選択した場合 → Step 5 へ。

## Step 5: 卒業実行

1. **SKILL.md に卒業バナーを追加** (先頭):
   ```markdown
   > ⚠️ **GRADUATED** — {today}
   > Claude {model} 以降でネイティブに処理可能です。
   > 卒業時スコア: with-skill={ws}点 / baseline={b}点 (差{gap}%)
   > 総呼び出し回数: {count}回
   ```

2. **meta.yaml 更新**:
   ```yaml
   status: graduated
   graduated_at: "{today}"
   graduation_model: "claude-sonnet-4-6"
   graduation_evidence:
     with_skill_score: {ws}
     baseline_score: {b}
     gap_pct: {gap}
   ```

3. **子スキルへの通知**:
   `lineage.yaml.children_skills` が存在する場合:
   → 各子スキルの meta.yaml に `parent_graduated: true` を追加
   → 次回の invocation_count チェック時に卒業プローブを前倒し実行

4. **中央フィードバックHub連携**（任意・統合している場合）:
   → 「このスキルが卒業した」シグナルを中央Hubに送信（分散型スキル共有を運用している場合のみ）

## 完了メッセージ

```
🎓 スキル「{name}」が卒業しました！

このスキルは{count}回の実行と{n}回の改善サイクルを経て、
Claudeのネイティブ能力として定着しました。

スキルはtombstoneとして保存されています:
  ~/.claude/skills/{name}/SKILL.md

再活性化: /skill-ops activate {name}
```
