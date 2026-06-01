# Workflow: evolve — スキル進化サイクル（SkillOpt統合版）

---

## 前提チェック

```
meta.yaml.status == "active" であること
telemetry/invocations.jsonl が存在し、失敗ログが5件以上あること
evolving 状態でないこと（ロック確認）
cooldown_multiplier が2以上の場合は警告（頻繁な失敗が続いている）
```

## Step 1: ステータスをevolvingに変更

```yaml
# meta.yaml
status: evolving
```

## Step 2: テレメトリ収集

`telemetry/invocations.jsonl` から直近 N=20件を読み込み。
その中から「失敗（outcome=failure）または低評価（user_rating=-1）」のみ抽出、最大5-8件。

不足の場合（失敗ログ < 5件）→ Step 8にスキップ（変更なし）

## Step 3: Reflector Agent 実行

**@skill-reflector** を別サブエージェントとして起動:

```
入力:
- 失敗ログ5-8件（具体的タスク内容は除去、行動パターンのみ）
- feedback.jsonl の低評価コメント
- contrast-buffer.jsonl（これまでの却下提案）← 重要: 何が機能しなかったかを参照

指示:
「タスク固有の情報を除去し、一般化された行動パターンとしてδ⁻を生成せよ。
 contrast-bufferの却下パターンと重複するδ⁻は優先度を下げること」

出力: { "error_list": [...], "experience_list": [...] }
```

## Step 4: クラスタリング（LLMベース）

δ⁻テキスト群を意味的グループに分類。孤立δ⁻（1回のみ出現）はノイズとして破棄。

## Step 5: Optimizer Agent 実行

**@skill-optimizer** を別サブエージェントとして起動:

```
入力:
- 現在の SKILL.md 全文
- error_clusters（Step 4の結果）

制約（SkillOpt bounded edits）:
- 変更操作は最大8件（add/delete/replace）
- SLOW_STATE セクションへの変更は FAST_STATE の2倍のコスト（慎重に）
- ユーザー固有情報・具体的タスク内容を埋め込まない

出力: {
  "proposal_skill_md": "...",
  "changes": ["変更1", "変更2", ...],
  "rationale": "...",
  "sections_modified": ["SLOW_STATE"|"FAST_STATE"]
}
```

## Step 6: 評価ゲート（Strict Validation）

評価実行を実利用に混ぜないため、まず eval ロックを取得（Step 8 で解放）:

```bash
bash ~/.claude/skills/skill-ops/scripts/eval_lock.sh acquire {name}
```

**@skill-judge** を起動して proposal_skill_md を評価:

```
with_proposal_score を計算（evals/test-cases.json の全テストケース）
current_score と比較

PASS条件（SkillOpt: 厳密な改善のみ採用）:
  delta_avg > 0 （同点は FAIL）
  regression_cases == 0
  with_proposal_score >= min_quality_score

FAILの場合: contrast-buffer.jsonl に記録して破棄
PASSの場合: 次ステップへ
```

## Step 7: SKILL.md 更新

PASSした場合:

```
1. versions/{new_version}.md として現在の SKILL.md を保存
2. SKILL.md を proposal_skill_md で上書き
3. best_skill.md も更新
4. meta.yaml を更新:
   - version: バージョンインクリメント（semver patch）
   - last_evolved: today
   - current_quality_score: with_proposal_score
   - evolution_consecutive_failures: 0
   - cooldown_multiplier: max(1, current - 1)  ← 成功で緩和
```

## Step 8: ステータスをactiveに戻す＋評価ロック解放

```yaml
status: active
```

```bash
bash ~/.claude/skills/skill-ops/scripts/eval_lock.sh release {name}
```

## Step 9: Epoch-level Slow Update チェック

`invocation_count % (evolution_threshold * 5) == 0` の場合:

**@skill-optimizer** で SLOW_STATE セクションの全体整合性チェックを実施。
断片化・矛盾・冗長記述を整理（大幅な書き換えではなく「整頓」）。

## 完了報告

```
🔄 スキル「{name}」の進化サイクル完了

結果: {PASS|FAIL}

{PASSの場合}
📈 スコア: {current} → {new} (+{delta})
🔧 変更: {changes}
📌 version: {old} → {new}

{FAILの場合}
📊 スコア差分が不十分（同点/後退）
📚 提案はcontrast-bufferに保存済み
⏭ 次の進化サイクルで参照します
```

---

## 連続失敗時のクールダウン

3回連続でFAILした場合:

```
⚠️ 3回連続で進化できませんでした。

可能性:
1. テストケースが現実のユースケースを捉えられていない
2. スキルの設計自体に根本的な問題がある
3. データが不足している（失敗ログ < 5件）

推奨アクション:
[1] テストケースを見直す (/skill-ops judge {name} --add-cases)
[2] 設計を根本から見直す (/skill-ops create {name} --reset)
[3] しばらく使い続けてデータを蓄積する（次回は{cooldown}回後）
```

`meta.yaml`:
```yaml
evolution_consecutive_failures: 3
evolution_cooldown_multiplier: 2  # 次のtriggerを2倍遠くに
```
