#!/usr/bin/env bash
# skill_stats.sh — スキルのライフサイクル統計を表示する（skill-ops）
#
# Usage:
#   skill_stats.sh <skill-name>     # 単一スキルの状態
#   skill_stats.sh --all            # meta.yaml を持つ全スキルの一覧

set -euo pipefail
SKILLS_DIR="${HOME}/.claude/skills"

getval() { grep "^$2:" "$1" | head -1 | sed "s/^$2: *//" | tr -d '"'; }

show_one() {
  local skill="$1"
  local meta="${SKILLS_DIR}/${skill}/meta.yaml"
  [[ -f "$meta" ]] || { echo "  (管理外: meta.yaml なし)"; return; }

  local status version inv succ fail score base last evo
  status="$(getval "$meta" status)"
  version="$(getval "$meta" version)"
  inv="$(getval "$meta" invocation_count)"
  succ="$(getval "$meta" success_count)"
  fail="$(getval "$meta" failure_count)"
  score="$(getval "$meta" current_quality_score)"
  base="$(getval "$meta" baseline_quality_score)"
  last="$(getval "$meta" last_invoked)"
  evo="$(getval "$meta" evolution_threshold)"

  local rate="n/a"
  if [[ "${inv:-0}" -gt 0 ]]; then
    rate="$(awk "BEGIN{printf \"%.0f\", (${succ:-0}/${inv})*100}")%"
  fi
  local next="n/a"
  if [[ "${evo:-0}" -gt 0 && "${inv:-0}" -ge 0 ]]; then
    next=$(( evo - (inv % evo) ))
  fi

  local emoji="❓"
  case "$status" in
    draft) emoji="📝" ;; active) emoji="✅" ;; evolving) emoji="🔄" ;;
    graduated) emoji="🎓" ;; retired) emoji="🗄" ;;
  esac

  printf "  状態: %s %s   v%s\n" "$emoji" "$status" "$version"
  printf "  呼び出し: %s回 (成功率 %s)\n" "${inv:-0}" "$rate"
  printf "  品質: with-skill=%s / baseline=%s\n" "${score:-未評価}" "${base:-未評価}"
  printf "  最終呼び出し: %s\n" "${last:-なし}"
  printf "  次回進化まで: %s回\n" "$next"
}

if [[ "${1:-}" == "--all" ]]; then
  printf "%-22s | %-9s | %-5s | %-8s | %-6s\n" "スキル" "状態" "ver" "呼び出し" "スコア"
  echo "-----------------------|-----------|-------|----------|-------"
  for d in "$SKILLS_DIR"/*/; do
    skill="$(basename "$d")"
    meta="${d}meta.yaml"
    [[ -f "$meta" ]] || continue
    printf "%-22s | %-9s | %-5s | %-8s | %-6s\n" \
      "$skill" \
      "$(getval "$meta" status)" \
      "$(getval "$meta" version)" \
      "$(getval "$meta" invocation_count)" \
      "$(getval "$meta" current_quality_score)"
  done
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: skill_stats.sh <skill-name> | --all" >&2
  exit 1
fi

echo "📋 スキル「$1」"
show_one "$1"
