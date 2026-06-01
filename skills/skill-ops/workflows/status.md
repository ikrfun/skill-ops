# Workflow: status / list — ライフサイクル状態表示

---

## status: 単一スキルの状態確認

`/skill-ops status {name}`

`~/.claude/skills/{name}/meta.yaml` を読み込み表示:

```
📋 スキル「{name}」の状態
━━━━━━━━━━━━━━━━━━━━━━━━

バージョン: {version}
ステータス: {status_emoji} {status}
親スキル:   {parent | なし}
子スキル:   {children | なし}

📊 使用統計:
  呼び出し回数:  {invocation_count}
  成功率:        {success_rate}%
  最終呼び出し: {last_invoked}

🔬 品質:
  最新スコア:   {current_quality_score | 未評価}
  ベースライン: {baseline_quality_score | 未評価}
  最終評価:     {last_evaluated | 未実施}

🔄 進化:
  最終改善:    {last_evolved | 未実施}
  次回トリガー: {next_evolution} 回後
  連続失敗数:  {evolution_consecutive_failures}

Status絵文字:
  draft      → 📝
  active     → ✅
  evolving   → 🔄
  graduated  → 🎓
  retired    → 🗄️
```

---

## list: 全スキルの一覧

`/skill-ops list`

`~/.claude/skills/` 以下の全ディレクトリを走査し、`meta.yaml` を読み込む:

```
📋 スキル一覧
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
スキル名             | 状態 | v    | 呼び出し | スコア | 次回進化
---------------------|------|------|----------|--------|--------
research             | ✅   | 2.1  | 247      | 85     | 13回後
restaurant-finder    | ✅   | 1.5  | 89       | 78     | 11回後
research-jp          | ✅   | 1.2  | 42       | 81     | 18回後
skill-ops        | 📝   | 0.1  | 0        | -      | 未設定
create-slide         | 🎓   | 3.0  | 312      | 91     | (卒業済)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
アクティブ: 3  ドラフト: 1  卒業済: 1  合計: 5
```

---

## 注意

`meta.yaml` が存在しないスキルは「ライフサイクル管理外」として一覧に `(管理外)` と表示。
