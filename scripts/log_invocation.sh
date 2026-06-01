#!/usr/bin/env bash
# log_invocation.sh — スキル呼び出しをテレメトリに記録する（skill-ops v0.2）
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
# 設計（v0.2 / レビュー反映）:
#   - meta.yaml にカウンタを書き戻さない。JSONL 追記のみ（並行アトミック・lost-update なし）。
#   - 評価モード（judge/evolve 中）は eval-runs.jsonl に分離記録し、実利用に混ぜない。
#   - sed -i 不使用。Mac/Linux 両対応。
#
# プライバシー: 入力/出力テキストは記録しない。行動パターンのみ。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ $# -lt 1 ]; then
  echo "ERROR: skill-name required" >&2
  echo "Usage: log_invocation.sh <skill> [--outcome X] [--rating N] [--tool-calls N] [--duration-ms N] [--error-hint X] [--session-id X]" >&2
  exit 1
fi

SKILL="$1"; shift

if [ ! -d "$(skill_dir "$SKILL")" ]; then
  echo "ERROR: skill not found: $(skill_dir "$SKILL")" >&2
  exit 1
fi
if [ ! -f "$(meta_file "$SKILL")" ]; then
  echo "ERROR: meta.yaml not found (skill-ops 管理対象外): $(meta_file "$SKILL")" >&2
  exit 1
fi

OUTCOME="success"; RATING="null"; TOOL_CALLS="null"; DURATION="null"; ERROR_HINT=""; SESSION_ID=""
while [ $# -gt 0 ]; do
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

ensure_telemetry "$SKILL"
TS="$(now_iso)"

# JSONL 行を組み立て（追記はアトミック）
LINE="{\"ts\":\"${TS}\",\"duration_ms\":${DURATION},\"tool_calls\":${TOOL_CALLS},\"user_rating\":${RATING},\"outcome\":\"${OUTCOME}\""
[ -n "$SESSION_ID" ] && LINE="${LINE},\"session_id\":\"$(json_escape "$SESSION_ID")\""
[ -n "$ERROR_HINT" ] && LINE="${LINE},\"error_hint\":\"$(json_escape "$ERROR_HINT")\""
LINE="${LINE}}"

TDIR="$(telemetry_dir "$SKILL")"

# 評価モードなら eval-runs.jsonl に分離記録（invocation としてカウントしない）
if is_eval_mode "$SKILL"; then
  printf '%s\n' "$LINE" >> "${TDIR}/eval-runs.jsonl"
  echo "✓ [eval] logged（評価モードのため実利用カウント外）: ${SKILL}"
  exit 0
fi

# 通常の実利用: invocations.jsonl に追記（カウンタは meta.yaml に書き戻さない）
printf '%s\n' "$LINE" >> "${TDIR}/invocations.jsonl"

# 集計は JSONL から都度算出（lost-update レースが原理的に起きない）
COUNT="$(count_invocations "$SKILL")"
echo "✓ logged: ${SKILL} #${COUNT} (outcome=${OUTCOME}, rating=${RATING})"

# 進化／卒業トリガーの通知（meta.yaml は読むだけ）
EVO="$(meta_get "$SKILL" evolution_threshold)"; EVO="${EVO:-20}"
GRAD="$(meta_get "$SKILL" graduation_threshold)"; GRAD="${GRAD:-100}"
COOLDOWN="$(meta_get "$SKILL" evolution_cooldown_multiplier)"; COOLDOWN="${COOLDOWN:-1}"
case "$COOLDOWN" in (*[!0-9]*|'') COOLDOWN=1 ;; esac
[ "$COOLDOWN" -ge 1 ] || COOLDOWN=1
EFFECTIVE=$(( EVO * COOLDOWN ))

if [ "$EFFECTIVE" -gt 0 ] && [ "$COUNT" -gt 0 ] && [ $(( COUNT % EFFECTIVE )) -eq 0 ]; then
  echo "🔄 進化サイクル推奨: ${SKILL} が ${COUNT} 回呼び出されました → /skill-ops evolve ${SKILL}"
fi
if [ "$GRAD" -gt 0 ] && [ "$COUNT" -gt 0 ] && [ $(( COUNT % GRAD )) -eq 0 ]; then
  echo "🎓 卒業プローブ推奨: ${SKILL} が ${COUNT} 回到達 → /skill-ops graduate ${SKILL}"
fi

exit 0
