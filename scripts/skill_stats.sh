#!/usr/bin/env bash
# skill_stats.sh — スキルのライフサイクル統計を表示する（skill-ops v0.2）
#
# Usage:
#   skill_stats.sh <skill-name>     # 単一スキルの状態
#   skill_stats.sh --all            # meta.yaml を持つ全スキルの一覧
#
# 設計（v0.2）: 呼び出し回数・成功率は meta.yaml ではなく JSONL の集計から算出する
# （「ログが単一の真実」）。meta.yaml は設定値・品質スコア・状態のみ保持。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

emoji_for() {
  case "$1" in
    draft) printf '📝' ;; active) printf '✅' ;; evolving) printf '🔄' ;;
    graduated) printf '🎓' ;; retired) printf '🗄' ;; *) printf '❓' ;;
  esac
}

show_one() {
  local skill="$1"
  [ -f "$(meta_file "$skill")" ] || { echo "  (管理外: meta.yaml なし)"; return; }

  local status version score base evo
  status="$(meta_get "$skill" status)"
  version="$(meta_get "$skill" version)"
  score="$(meta_get "$skill" current_quality_score)"
  base="$(meta_get "$skill" baseline_quality_score)"
  evo="$(meta_get "$skill" evolution_threshold)"; evo="${evo:-20}"

  # JSONL から集計（真実の単一ソース）
  local inv succ fail evals last rate next
  inv="$(count_invocations "$skill")"
  succ="$(count_outcome "$skill" success)"
  fail="$(count_outcome "$skill" failure)"
  evals="$(count_eval_runs "$skill")"
  last="$(tail -n 1 "$(telemetry_dir "$skill")/invocations.jsonl" 2>/dev/null | grep -o '"ts":"[^"]*"' | head -1 | cut -d'"' -f4)"

  rate="n/a"
  [ "$inv" -gt 0 ] && rate="$(awk "BEGIN{printf \"%.0f\", ($succ/$inv)*100}")%"
  next="n/a"
  [ "$evo" -gt 0 ] && next=$(( evo - (inv % evo) ))

  printf "  状態: %s %s   v%s\n" "$(emoji_for "$status")" "${status:-?}" "${version:-?}"
  printf "  呼び出し: %s回 (成功率 %s)   [評価実行 %s回は別計上]\n" "$inv" "$rate" "$evals"
  printf "  品質: with-skill=%s / baseline=%s\n" "${score:-未評価}" "${base:-未評価}"
  printf "  最終呼び出し: %s\n" "${last:-なし}"
  printf "  次回進化まで: %s回\n" "$next"
}

if [ "${1:-}" = "--all" ]; then
  printf "%-22s | %-9s | %-5s | %-8s | %-6s\n" "スキル" "状態" "ver" "呼び出し" "スコア"
  echo "-----------------------|-----------|-------|----------|-------"
  for d in "$SKILLS_DIR"/*/; do
    skill="$(basename "$d")"
    [ -f "${d}meta.yaml" ] || continue
    printf "%-22s | %-9s | %-5s | %-8s | %-6s\n" \
      "$skill" \
      "$(meta_get "$skill" status)" \
      "$(meta_get "$skill" version)" \
      "$(count_invocations "$skill")" \
      "$(meta_get "$skill" current_quality_score)"
  done
  exit 0
fi

if [ $# -lt 1 ]; then
  echo "Usage: skill_stats.sh <skill-name> | --all" >&2
  exit 1
fi

echo "📋 スキル「$1」"
show_one "$1"
