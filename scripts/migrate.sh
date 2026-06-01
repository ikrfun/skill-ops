#!/usr/bin/env bash
# migrate.sh — 既存の skill-ops 管理スキルを v0.2 形式へ移行（skill-ops）
#
# Usage:
#   migrate.sh [--dry-run] <skill-name>
#   migrate.sh [--dry-run] --all
#
# やること（冪等）:
#   1. meta.yaml から廃止カウンタ行を削除（invocation_count/success_count/
#      failure_count/last_invoked。v0.2 は JSONL 集計が真実のため）
#   2. SKILL.md の計測セクションを <!-- SKILLOPS_TELEMETRY_BEGIN/END --> マーカー
#      付きの新形式に再生成（旧パス・bash プレフィックス無し・失敗握り潰しを修正）。
#      FAST_STATE（改善メモ）は保持する。
#
# sed -i は使わない（一時ファイル + mv）。Mac/Linux 両対応。

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# 管理対象スキルに埋め込む skill-ops scripts の絶対パス（現状の単一ソース）
SKILLOPS_SCRIPTS="${SKILL_OPS_SCRIPTS_PATH:-${HOME}/.claude/skills/skill-ops/scripts}"

DRY=0
TARGET=""
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --all)     TARGET="--all" ;;
    -*)        echo "WARN: unknown option $a" >&2 ;;
    *)         TARGET="$a" ;;
  esac
done
[ -n "$TARGET" ] || { echo "Usage: migrate.sh [--dry-run] <skill>|--all" >&2; exit 1; }

# 末尾の空行と '---' のみの行を除去
trim_trailing() {
  awk '{ a[NR]=$0 } END { n=NR; while(n>0 && (a[n]=="" || a[n]=="---")) n--; for(i=1;i<=n;i++) print a[i] }'
}

# 計測セクション本文（FAST_STATE は含めない。マーカー間のみ）を出力
render_telemetry() {
  local skill="$1"
  printf '\n---\n\n'
  cat <<EOF
<!-- SKILLOPS_TELEMETRY_BEGIN -->
## 📊 計測（skill-ops 管理対象）

このスキルは skill-ops のライフサイクル管理下にあります。**タスク完了時に必ず**呼び出しを記録してください:

\`\`\`bash
bash ${SKILLOPS_SCRIPTS}/log_invocation.sh ${skill} --outcome <success|failure|partial> [--rating <1|-1>] [--tool-calls <概算数>] \\
  || echo '⚠️ skill-ops 計測失敗（スクリプト不在/権限）' >&2
\`\`\`

- \`--outcome\`: タスク完遂度（success / partial / failure）
- \`--rating\`: ユーザーが明示的に評価した場合のみ（褒め=1 / 不満=-1）

ユーザーから修正指示・不満があれば追加で:

\`\`\`bash
bash ${SKILLOPS_SCRIPTS}/log_feedback.sh ${skill} --type correction --content-hint "<短い要約>"
\`\`\`

記録されるのは行動パターンのみ（実行時間・ツール数・成否・評価）。**入力／出力テキストは記録しません**。
<!-- SKILLOPS_TELEMETRY_END -->
EOF
}

migrate_one() {
  local skill="$1"
  local md;   md="$(skill_dir "$skill")/SKILL.md"
  local meta; meta="$(meta_file "$skill")"
  [ -f "$md" ] || { echo "  skip（SKILL.md なし）: $skill"; return; }

  local meta_changed=0
  if [ -f "$meta" ] && grep -qE '^(invocation_count|success_count|failure_count|last_invoked):' "$meta"; then
    meta_changed=1
  fi

  # 計測セクション開始の境界（新マーカー優先、無ければ旧見出し）
  local boundary
  boundary="$(grep -n -E '^<!-- SKILLOPS_TELEMETRY_BEGIN -->|^## 📊 計測' "$md" | head -1 | cut -d: -f1)"

  if [ "$DRY" = "1" ]; then
    echo "  [dry-run] ${skill}: meta_counters_removed=${meta_changed}, telemetry_boundary=${boundary:-none(末尾に新規追記)}"
    return
  fi

  if [ "$meta_changed" = "1" ]; then
    grep -vE '^(invocation_count|success_count|failure_count|last_invoked):' "$meta" > "${meta}.tmp" \
      && mv "${meta}.tmp" "$meta"
  fi

  if [ -n "$boundary" ]; then
    head -n $(( boundary - 1 )) "$md" | trim_trailing > "${md}.tmp"
  else
    trim_trailing < "$md" > "${md}.tmp"
  fi
  render_telemetry "$skill" >> "${md}.tmp"
  mv "${md}.tmp" "$md"
  echo "  ✓ migrated: ${skill}（meta_counters_removed=${meta_changed}）"
}

if [ "$TARGET" = "--all" ]; then
  for d in "$SKILLS_DIR"/*/; do
    s="$(basename "$d")"
    [ -f "${d}meta.yaml" ] || continue
    [ "$s" = "skill-ops" ] && continue   # skill-ops 自身は管理対象外
    migrate_one "$s"
  done
else
  migrate_one "$TARGET"
fi
