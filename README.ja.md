# skill-ops

*[English](./README.md) · 日本語*

> [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) のための自己進化型スキル・ライフサイクル管理ツール。Agent Skill を「生き物」として扱う：**作成 → 計測 → 進化 → 卒業**。

skill-ops は *メタスキル* — 他のスキルを管理するスキルです。各スキルのパフォーマンス（利用テレメトリ＋ユーザーフィードバック）を記録し、評価ゲート付きの改善ループを `SKILL.md` に回します。さらに、あるスキルが冗長になった（モデルがネイティブにこなせるようになった）と判断したら、そのスキルを**卒業**させることもできます。

設計は3つの研究を融合しています：

- **SkillOpt**（Microsoft Research, arXiv:2605.23904）— `SKILL.md` を訓練可能なテキストパラメータとして扱う。bounded edits・厳格な検証ゲート・contrast buffer・fast/slow セクション分離。
- **TPGO "Learning to Evolve"**（arXiv:2604.20714）— 生ログをクラスタリングする前に「一般化された失敗診断（δ⁻）」へ変換し、1回限りの失敗による過学習を防ぐ。
- **Anthropic の評価駆動スキル開発** — baseline vs with-skill のスコア比較、Claude-A / Claude-B（作成役 / テスト役）の分離。

---

## 仕組み

### ライフサイクル状態機械

```
 create ─► draft ─► active ─► evolving ─► active（ループ）
                       │
                [卒業プローブ: モデル ≈ スキル]
                       ▼
                  graduated ─► retired（tombstone を残置）
```

| 状態 | 意味 | 遷移条件 |
|------|------|---------|
| `draft` | 作成済み、baseline 未計測 | `create` / `retrofit` 直後 |
| `active` | 通常稼働、テレメトリ記録中 | テストケース3件以上を評価、with-skill > baseline、スコア ≥ 70 |
| `evolving` | 改善サイクル実行中（書き込みロック） | `evolution_threshold` 回ごと（デフォルト20） |
| `graduated` | モデルがネイティブ処理可能 → スキル冗長 | 卒業ギャップ < 10% ＋ ユーザー確認 |
| `retired` | 非推奨、tombstone として保存 | 手動、または30日間未使用 |

### 進化ループ（SkillOpt ベース）

```
テレメトリ（直近N件の失敗）
   └─► skill-reflector  → δ⁻（一般化された失敗パターン）
        └─► クラスタリング（1回限りのノイズを破棄）
             └─► skill-optimizer → SKILL.md への ≤8操作の bounded edits
                  └─► skill-judge → 提案版 vs 現行版を採点（ブラインド）
                       ├─ PASS（厳格な改善）→ バージョン更新、best_skill.md 更新
                       └─ FAIL → contrast-buffer.jsonl に記録、現行維持
```

作成役（`skill-optimizer`）とレビュー役（`skill-judge`）は常に**別サブエージェント**として実行し、確証バイアスを防ぎます。

---

## インストール

```bash
# 1. このリポジトリをプラグインマーケットプレイスとして追加
/plugin marketplace add ikrfun/skill-ops

# 2. プラグインをインストール
/plugin install skill-ops@ikrfun-skills
```

ローカル開発用：

```bash
claude --plugin-dir /path/to/skill-ops
```

---

## 使い方

```
/skill-ops create <name>                     7ステップTDDフローで新規スキル作成
/skill-ops retrofit <name>                   既存スキルを計測対象に変換
/skill-ops judge <name>                      品質計測（with-skill vs baseline）
/skill-ops evolve <name>                     改善サイクルを実行
/skill-ops graduate <name>                   卒業プローブを実行
/skill-ops inherit <child> --from <parent>   親スキルから改善を継承
/skill-ops status <name>                     単一スキルのライフサイクル状態を表示
/skill-ops list                              管理対象スキルの一覧
```

### クイックスタート：既存スキルを計測する

```
/skill-ops retrofit research      # meta.yaml / telemetry/ / evals/ を追加し、計測セクションを末尾に追記
/skill-ops judge research         # with-skill vs baseline を採点 → draft から active へ昇格
```

---

## スキルの計測方法

管理対象の各スキルには、`SKILL.md` と並んでサイドカーファイルが生成されます：

```
~/.claude/skills/<skill>/
├── SKILL.md                  # 本体は無変更。末尾に計測セクションのみ追記
├── best_skill.md             # 最高スコアの検証済みバージョン
├── meta.yaml                 # ライフサイクル状態・カウンタ・閾値
├── lineage.yaml              # 親子関係・バージョン履歴
├── telemetry/
│   ├── invocations.jsonl     # 呼び出し1回=1行（行動のみ — 入出力テキストは記録しない）
│   └── feedback.jsonl        # explicit / correction / implicit フィードバック
└── evals/
    ├── test-cases.json       # expected_properties 付きの現実的なケース3件以上
    ├── contrast-buffer.jsonl # 却下された提案（失敗からの学習）
    └── results/<version>.json
```

呼び出しは同梱スクリプトで記録します：

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/log_invocation.sh <skill> --outcome success --tool-calls 8 [--rating 1]
${CLAUDE_PLUGIN_ROOT}/scripts/log_feedback.sh  <skill> --type correction --content-hint "..."
${CLAUDE_PLUGIN_ROOT}/scripts/skill_stats.sh   <skill> | --all
```

**プライバシー設計**：テレメトリには*行動*（実行時間・ツール数・成否・評価）のみ記録します。あなたのプロンプトやスキルの出力がディスクに書かれることはありません。

### ジャッジ（評価ゲート）

`skill-judge` は各テストケースを4軸（完全性 / 正確性 / 構造性 / 効率性、各25点）で採点します。**with-skill** と **baseline**（スキルなし）を比較し、*厳格な*改善かつ**後退ゼロ**の場合のみ変更を採用します — 同点は却下し contrast buffer に記録します。

同梱の `research` スキルでの実例（ケース：「RAG向けベクトルDBの選び方」）：

| | 完全性 | 正確性 | 構造性 | 効率性 | 合計 |
|---|---|---|---|---|---|
| with-skill | 25 | 24 | 23 | 23 | **95** |
| baseline | 19 | 22 | 24 | 24 | **78** |

`delta = +17`、ゲート = PASS、卒業ギャップ = 82%（< 90% → スキルは明確に価値があり、卒業はまだ遠い）。

---

## アーキテクチャ

| コンポーネント | 役割 | モデル |
|-----------|------|-------|
| `skill-ops`（SKILL.md + workflows） | オーケストレーター / コマンド | — |
| `agents/skill-reflector.md` | 失敗ログを一般化された δ⁻ パターンに変換 | Sonnet |
| `agents/skill-optimizer.md` | SKILL.md への ≤8操作の bounded edits を提案 | Opus |
| `agents/skill-judge.md` | ブラインドかつ独立した品質採点 | Opus |
| `scripts/*.sh` | テレメトリ記録・統計（外部依存なし） | — |
| `templates/`, `schemas/` | meta.yaml / SKILL.md / 計測セクションのテンプレート | — |

---

## 設計原則

1. **コンテキスト分離** — generator と judge は別サブエージェント（確証バイアスなし）。
2. **Bounded edits** — 1イテレーションあたり最大4〜8操作（SkillOpt：これを外すと性能崩壊）。
3. **厳格な検証** — 同点は却下。却下された提案は contrast buffer に蓄積。
4. **Fast/slow 分離** — 安定した推論パターン（`SLOW_STATE`）を変動の激しいセッションメモ（`FAST_STATE`）から保護。
5. **プライバシー優先** — 行動テレメトリのみ記録、入出力テキストは記録しない。

---

## 既知の制約

**v0.2 で解決**（3観点の adversarial 設計レビューを経て）:
- ~~プラグインパスの不安定性~~ → 埋め込みパスはデフォルト `~/.claude/skills/skill-ops/scripts/`（`SKILL_OPS_SCRIPTS_PATH` で上書き可）。`migrate` が冪等に再生成。
- ~~評価実行が実利用としてカウント~~ → `judge`/`evolve` は実行区間を `eval_lock.sh` で囲み、その間の計測は `eval-runs.jsonl` に分離（実利用カウント外）。
- ~~カウンタの lost-update レース / `sed -i` の Linux 破綻~~ → カウンタを廃止（JSONL が真実の単一ソース）。`sed -i` も全廃し Mac/Linux 両対応に。

**残る制約:**
- **単一サンプルのノイズ。** 1ケースのジャッジ結果は参考であり確定ではありません — 全テストケースを評価してから `active` へ昇格させてください。
- **自動スケジューラは未実装。** 進化はオンデマンド、または閾値到達時にレコメンドとして提示され、無人実行はされません。
- **Linux 実機未検証。** スクリプトは Mac/Linux 両対応で記述（`sed -i` 不使用、`stat -f`/`-c` フォールバック）し macOS で検証済みですが、Linux での実行確認を推奨します。
- **デフォルト以外の配置。** skill-ops を `~/.claude/skills/skill-ops/` 以外（マーケットプレイス経由など）に置く場合は、埋め込まれる計測コマンドが正しく解決されるよう `SKILL_OPS_SCRIPTS_PATH` を設定してください。

---

## ライセンス

MIT © ikrfun. [LICENSE](./LICENSE) を参照。
