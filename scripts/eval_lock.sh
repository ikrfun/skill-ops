#!/usr/bin/env bash
# eval_lock.sh — 評価モードのロックを操作する（skill-ops v0.2）
#
# judge / evolve が「対象スキルを評価実行する区間」を囲むために使う。
# ロック中は log_invocation.sh / log_feedback.sh が eval-runs.jsonl /
# eval-feedback.jsonl へ分離記録し、実利用カウント（invocations.jsonl）を汚さない。
#
# ロックは同期されないマシンローカル（$TMPDIR）にスキル名スコープで作られる。
#
# Usage:
#   eval_lock.sh acquire <skill>
#   eval_lock.sh release <skill>
#   eval_lock.sh status  <skill>

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

CMD="${1:-}"
SKILL="${2:-}"
[ -n "$CMD" ] && [ -n "$SKILL" ] || { echo "Usage: eval_lock.sh acquire|release|status <skill>" >&2; exit 1; }

case "$CMD" in
  acquire)
    eval_lock_acquire "$SKILL"
    echo "✓ eval lock acquired: ${SKILL}（この間の実行は eval-runs に分離されます）"
    ;;
  release)
    eval_lock_release "$SKILL"
    echo "✓ eval lock released: ${SKILL}（通常の実利用カウントに戻ります）"
    ;;
  status)
    if is_eval_mode "$SKILL"; then echo "evaluating"; else echo "normal"; fi
    ;;
  *)
    echo "Usage: eval_lock.sh acquire|release|status <skill>" >&2; exit 1 ;;
esac
