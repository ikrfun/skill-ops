#!/usr/bin/env bash
# log_feedback.sh — ユーザーフィードバックをテレメトリに記録する（skill-ops v0.2）
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
# 設計（v0.2）:
#   - 評価モード（judge/evolve 中）は feedback.jsonl ではなく eval-feedback.jsonl に分離。
#   - sed 不使用（json_escape は lib.sh のパラメータ展開版）。Mac/Linux 両対応。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ $# -lt 1 ]; then
  echo "ERROR: skill-name required" >&2
  exit 1
fi

SKILL="$1"; shift

if [ ! -d "$(skill_dir "$SKILL")" ]; then
  echo "ERROR: skill not found: $SKILL" >&2
  exit 1
fi

TYPE=""; RATING="null"; COMMENT=""; CONTENT_HINT=""; SIGNAL=""; SESSION_ID=""
while [ $# -gt 0 ]; do
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

if [ -z "$TYPE" ]; then
  echo "ERROR: --type required (explicit|correction|implicit)" >&2
  exit 1
fi

ensure_telemetry "$SKILL"
TS="$(now_iso)"

LINE="{\"ts\":\"${TS}\",\"type\":\"$(json_escape "$TYPE")\",\"rating\":${RATING}"
[ -n "$COMMENT" ]      && LINE="${LINE},\"comment\":\"$(json_escape "$COMMENT")\""
[ -n "$CONTENT_HINT" ] && LINE="${LINE},\"content_hint\":\"$(json_escape "$CONTENT_HINT")\""
[ -n "$SIGNAL" ]       && LINE="${LINE},\"signal\":\"$(json_escape "$SIGNAL")\""
[ -n "$SESSION_ID" ]   && LINE="${LINE},\"session_id\":\"$(json_escape "$SESSION_ID")\""
LINE="${LINE}}"

TDIR="$(telemetry_dir "$SKILL")"

if is_eval_mode "$SKILL"; then
  printf '%s\n' "$LINE" >> "${TDIR}/eval-feedback.jsonl"
  echo "✓ [eval] feedback logged（評価モードのため分離）: ${SKILL}"
  exit 0
fi

printf '%s\n' "$LINE" >> "${TDIR}/feedback.jsonl"
echo "✓ feedback logged: ${SKILL} (type=${TYPE}, rating=${RATING})"
exit 0
