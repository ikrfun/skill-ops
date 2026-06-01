# Workflow: inherit — スキル継承

親スキルの改善を子スキルに取り込む。プログラミングの継承に相当。

---

## 使い方

```
/skill-ops inherit <child> --from <parent> [--sections "all" | "セクション名,..."]
```

## Step 0: 前提チェック

- 親・子どちらも `~/.claude/skills/` に存在し、`meta.yaml` を持つこと
- **循環継承の禁止**: 親の系譜に子が含まれていないか `lineage.yaml` を辿って確認
- **継承深度3まで**: 親の祖先が2階層以上ある場合は中止（複雑化防止）

## Step 1: 継承対象セクションの決定

`--sections` の指定、または親 `lineage.yaml` の `inheritance_policy.inherit_sections` を参照。

- `all`: 親の SLOW_STATE セクション全体
- セクション名指定: 該当する `## 見出し` のみ

子の `override_sections` に該当するセクションは**継承しない**（子固有の特殊化を保護）。

## Step 2: 親から該当セクションを抽出

親の `best_skill.md`（なければ `SKILL.md`）から、対象セクションのテキストを抽出する。

## Step 3: 子へのマージ提案（確認付き）

子の SKILL.md の対応セクションを、親のセクションで置換または追記する提案を生成。
**ユーザーに差分を提示して確認を取る**（自動適用しない）。

```
📬 継承提案: {parent} → {child}
   対象セクション: 「## 評価基準」
   --- 現在（子） ---
   ...
   --- 提案（親から継承） ---
   ...
   適用しますか? [y/n]
```

## Step 4: 適用と記録

承認された場合:

1. 子の SKILL.md を更新（SLOW_STATE 内のみ。FAST_STATE は触らない）
2. 子の `lineage.yaml.version_history` に追記:
   ```yaml
   - version: "{new_version}"
     date: "{today}"
     note: "親から継承: {セクション名}"
     parent_version: "{parent_version}"
     inherited_from: "{parent}@{parent_version}"
   ```
3. 子の `meta.yaml` の `version` をインクリメント（semver minor）

## Step 5: 継承後の品質確認

`/skill-ops judge {child}` を推奨。継承で品質が落ちていないかを評価ゲートで確認する。

---

## 卒業連鎖との関係

親スキルが `graduated` になった場合、`inherit` ではなく `graduate.md` のロジックで子に卒業プローブが前倒し実行される。継承は「生きている親」からのみ行う。
