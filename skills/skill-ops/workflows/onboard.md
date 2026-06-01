# Workflow: onboard — 初回セットアップ案内

skill-ops を初めて使うユーザーに、できること・できないことを説明し、
管理対象スキルを一緒に設定する。完了したら `onboarded = true` にして、
以降はこの flow をスキップする。

---

## Step 0: 状態確認

```bash
bash ~/.claude/skills/skill-ops/scripts/state.sh is-onboarded
```

- `true` の場合: 「すでにセットアップ済みです。もう一度 onboarding を実行しますか？（通常は不要）」と確認。希望しなければ終了。
- `false` の場合: Step 1 へ。

---

## Step 1: 歓迎と全体像

以下を簡潔に伝える（読み上げるのではなく要点を会話的に）:

```
👋 skill-ops へようこそ。

skill-ops は「スキルを管理するスキル（メタスキル）」です。
あなたの Claude Code スキルを “生き物” として扱い、使うほどに育てます:

  作成 → 計測 → 進化 → 卒業

具体的には、各スキルが「素の Claude より良い結果を出しているか」を
計測し、ログが溜まったら SKILL.md を自動改善し、やがてモデルが
賢くなってスキルが不要になったら「卒業」させます。
```

## Step 2: できること / できないこと

```
✅ skill-ops にできること
  - 既存スキルを計測対象にする（retrofit）
  - 品質を計測する（judge: with-skill vs スキルなし baseline をスコア比較）
  - スキルを自律改善する（evolve: 失敗ログから SKILL.md を最小編集で改善）
  - 卒業を判定する（graduate: モデルがネイティブにこなせるなら引退提案）
  - スキル間で改善を継承する（inherit）
  - 新規スキルを TDD で作る（create）

🚫 skill-ops がしないこと
  - スキル自体の「実行」はしない（管理・計測・改善だけ。実行は各スキルの仕事）
  - 無人で勝手に進化しない（閾値に達したら “推奨” を出すだけ。実行はあなたの判断）
  - 入力／出力テキストは記録しない（行動パターン＝時間・ツール数・成否・評価のみ）
  - skill-ops 自身は管理対象外（メタなので）
```

## Step 3: 既存スキルのスキャンと管理対象の選択

`~/.claude/skills/` 配下のスキル（skill-ops 自身を除く）を一覧する:

```bash
ls -1 ~/.claude/skills/ | grep -v '^skill-ops$'
```

すでに管理対象（meta.yaml を持つ）かどうかも示す:

```bash
for d in ~/.claude/skills/*/; do
  s=$(basename "$d"); [ "$s" = "skill-ops" ] && continue
  [ -f "$d/meta.yaml" ] && echo "$s [管理中]" || echo "$s [未管理]"
done
```

**AskUserQuestion** で「どのスキルを継続改善の対象にしますか？」と複数選択させる
（multiSelect）。よく使うスキル・育てたいスキルを2〜4個選んでもらうとよい。
「あとで `/skill-ops retrofit <name>` でいつでも追加できます」と添える。

## Step 4: 選んだスキルを retrofit

選ばれた各スキルに `migrate.sh`（= retrofit の中核）を適用:

```bash
bash ~/.claude/skills/skill-ops/scripts/migrate.sh <skill>
```

または計測対象が未作成（meta.yaml 無し）の場合は `workflows/retrofit.md` を実行して
test-cases.json / meta.yaml / telemetry を生成する。

適用後、state に記録:

```bash
bash ~/.claude/skills/skill-ops/scripts/state.sh add-managed <skill>
```

## Step 5: 次の一歩を案内（任意）

```
これで計測が始まります。次にできること:

  /skill-ops judge <skill>   … baseline と比較してスキルの価値を数値化（draft→active 昇格）
  /skill-ops list            … 管理スキルの状態一覧
  /skill-ops create <name>   … 新しいスキルをゼロから作る

スキルを普通に使うたびにログが溜まり、{evolution_threshold}回で
「進化してみては？」と提案します。
```

新規スキルを作りたい意向があれば `workflows/create.md` へ。

## Step 6: onboarding 完了

```bash
bash ~/.claude/skills/skill-ops/scripts/state.sh set-onboarded
```

```
🎉 セットアップ完了！

以降は onboarding をスキップして、すぐにコマンドが使えます。
もう一度説明を見たいときは /skill-ops onboard を実行してください。
```

---

## 設計メモ

- `onboarded` フラグは `~/.claude/skill-ops/state.json` に保存（ユーザー固有・同期OK）。
- 完了後は SKILL.md の Step 0 ガードが onboarding をスキップする。
- ユーザーが「説明はいらない、すぐ使いたい」と言えば、Step 2-5 を飛ばして
  Step 6 だけ実行（onboarded=true にして通常利用へ）してもよい。
