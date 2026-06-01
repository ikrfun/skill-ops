#!/usr/bin/env bash
# log_invocation.sh — スキル呼び出しをテレメトリに記録する（skill-ops）
#
# Usage:
#   log_invocation.sh <skill-name> [options]
#
# Options:
#   --outcome <success|failure|partial>   主観的完了度（デフォルト: success）
#   --rating <1|-1>                        ユーザー明示評価（省略時 null）
#   --tool-calls <N>                       ツール呼び出し数（省略時 null）
#   --duration-ms <N>                      実行時間ミリ秒（省略時 null）
#   --error-hint <text>                    失敗原因カテゴリ（任意）
#   --session-id <id>                      セッション識別子（任意）
#
# 副作用:
#   - ~/.claude/skills/<skill>/telemetry/invocations.jsonl に1行追記
#   - meta.yaml の invocation_count / success_count / failure_count / last_invoked を更新
#   - evolution_threshold に到達したら「進化サイクル推奨」を通知（stdout）
#
# プライバシー: 入出力テキストは記録しない。行動パターンのみ。

set -euo pipefail

SKILLS_DIR="${HOME}/.claude/skills"

if [[ $# -lt 1 ]]; then
  echo "ERROR: skill-name required" >&2
  echo "Usage: log_invocation.sh <skill-name> [--outcome X] [--rating N] [--tool-calls N] [--duration-ms N] [--error-hint X] [--session-id X]" >&2
  exit 1
fi

SKILL="$1"; shift
SKILL_DIR="${SKILLS_DIR}/${SKILL}"
META="${SKILL_DIR}/meta.yaml"
TELEM_DIR="${SKILL_DIR}/telemetry"
LOG="${TELEM_DIR}/invocations.jsonl"

if [[ ! -d "$SKILL_DIR" ]]; then
  echo "ERROR: skill not found: $SKILL_DIR" >&2
  exit 1
fi
if [[ ! -f "$META" ]]; then
  echo "ERROR: meta.yaml not found (skill-ops管理対象外): $META" >&2
  exit 1
fi

# デフォルト値
OUTCOME="success"
RATING="null"
TOOL_CALLS="null"
DURATION="null"
ERROR_HINT=""
SESSION_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --outcome)     OUTCOME="$2"; shift 2 ;;
    --rating)      RATING="$2"; shift 2 ;;
    --tool-calls)  TOOL_CALLS="$2"; shift 2 ;;
    --duration-ms) DURATION="$2"; shift 2 ;;
    --error-hint)  ERROR_HINT="$2"; shift 2 ;;
    --session-id)  SESSION_ID="$2"; shift 2 ;;
    *) echo "WARN: unknown option $1" >&2; shift ;;
  esac
done

mkdir -p "$TELEM_DIR"
TS="$(date '+%Y-%m-%dT%H:%M:%S%z')"

# JSONL行を組み立て
LINE="{\"ts\":\"${TS}\",\"duration_ms\":${DURATION},\"tool_calls\":${TOOL_CALLS},\"user_rating\":${RATING},\"outcome\":\"${OUTCOME}\""
[[ -n "$SESSION_ID" ]] && LINE="${LINE},\"session_id\":\"${SESSION_ID}\""
[[ -n "$ERROR_HINT" ]] && LINE="${LINE},\"error_hint\":\"${ERROR_HINT}\""
LINE="${LINE}}"
echo "$LINE" >> "$LOG"

# meta.yaml カウンタ更新（フラットYAMLなのでsedで行更新）
bump() {
  local key="$1"
  local cur
  cur="$(grep "^${key}:" "$META" | head -1 | awk '{print $2}')"
  [[ -z "$cur" || "$cur" == "null" ]] && cur=0
  local new=$((cur + 1))
  sed -i '' "s/^${key}: .*/${key}: ${new}/" "$META"
  echo "$new"
}

INV_COUNT="$(bump invocation_count)"
if [[ "$OUTCOME" == "success" ]]; then
  bump success_count >/dev/null
elif [[ "$OUTCOME" == "failure" ]]; then
  bump failure_count >/dev/null
fi
sed -i '' "s/^last_invoked: .*/last_invoked: \"${TS}\"/" "$META"

# 進化トリガー判定
EVO_THRESHOLD="$(grep '^evolution_threshold:' "$META" | head -1 | awk '{print $2}')"
GRAD_THRESHOLD="$(grep '^graduation_threshold:' "$META" | head -1 | awk '{print $2}')"
COOLDOWN="$(grep '^evolution_cooldown_multiplier:' "$META" | head -1 | awk '{print $2}')"
[[ -z "$COOLDOWN" || "$COOLDOWN" == "null" ]] && COOLDOWN=1
EFFECTIVE_THRESHOLD=$((EVO_THRESHOLD * COOLDOWN))

echo "✓ logged: ${SKILL} #${INV_COUNT} (outcome=${OUTCOME}, rating=${RATING})"

if (( INV_COUNT > 0 && INV_COUNT % EFFECTIVE_THRESHOLD == 0 )); then
  echo "🔄 進化サイクル推奨: ${SKILL} が ${INV_COUNT} 回呼び出されました → /skill-ops evolve ${SKILL}"
fi
if (( GRAD_THRESHOLD > 0 && INV_COUNT > 0 && INV_COUNT % GRAD_THRESHOLD == 0 )); then
  echo "🎓 卒業プローブ推奨: ${SKILL} が ${INV_COUNT} 回到達 → /skill-ops graduate ${SKILL}"
fi
