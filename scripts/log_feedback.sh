#!/usr/bin/env bash
# log_feedback.sh — ユーザーフィードバックをテレメトリに記録する（skill-ops）
#
# Usage:
#   log_feedback.sh <skill-name> --type <explicit|correction|implicit> [options]
#
# Options:
#   --rating <1|-1>          明示評価（省略時 null）
#   --comment <text>         短いコメント（プライバシー配慮で短く）
#   --content-hint <text>    暗黙FBの内容ヒント（output_discarded 等）
#   --signal <text>          暗黙シグナル（retry_triggered 等）
#   --session-id <id>        セッション識別子
#
# 副作用:
#   - ~/.claude/skills/<skill>/telemetry/feedback.jsonl に1行追記

set -euo pipefail

SKILLS_DIR="${HOME}/.claude/skills"

if [[ $# -lt 1 ]]; then
  echo "ERROR: skill-name required" >&2
  exit 1
fi

SKILL="$1"; shift
TELEM_DIR="${SKILLS_DIR}/${SKILL}/telemetry"
LOG="${TELEM_DIR}/feedback.jsonl"

if [[ ! -d "${SKILLS_DIR}/${SKILL}" ]]; then
  echo "ERROR: skill not found: ${SKILL}" >&2
  exit 1
fi

TYPE=""
RATING="null"
COMMENT=""
CONTENT_HINT=""
SIGNAL=""
SESSION_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)         TYPE="$2"; shift 2 ;;
    --rating)       RATING="$2"; shift 2 ;;
    --comment)      COMMENT="$2"; shift 2 ;;
    --content-hint) CONTENT_HINT="$2"; shift 2 ;;
    --signal)       SIGNAL="$2"; shift 2 ;;
    --session-id)   SESSION_ID="$2"; shift 2 ;;
    *) echo "WARN: unknown option $1" >&2; shift ;;
  esac
done

if [[ -z "$TYPE" ]]; then
  echo "ERROR: --type required (explicit|correction|implicit)" >&2
  exit 1
fi

mkdir -p "$TELEM_DIR"
TS="$(date '+%Y-%m-%dT%H:%M:%S%z')"

# コメント内のダブルクォートをエスケープ
esc() { printf '%s' "$1" | sed 's/"/\\"/g'; }

LINE="{\"ts\":\"${TS}\",\"type\":\"${TYPE}\",\"rating\":${RATING}"
[[ -n "$COMMENT" ]]      && LINE="${LINE},\"comment\":\"$(esc "$COMMENT")\""
[[ -n "$CONTENT_HINT" ]] && LINE="${LINE},\"content_hint\":\"$(esc "$CONTENT_HINT")\""
[[ -n "$SIGNAL" ]]       && LINE="${LINE},\"signal\":\"${SIGNAL}\""
[[ -n "$SESSION_ID" ]]   && LINE="${LINE},\"session_id\":\"${SESSION_ID}\""
LINE="${LINE}}"

echo "$LINE" >> "$LOG"
echo "✓ feedback logged: ${SKILL} (type=${TYPE}, rating=${RATING})"
