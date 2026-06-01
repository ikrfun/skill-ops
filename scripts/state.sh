#!/usr/bin/env bash
# state.sh — skill-ops のユーザー状態（onboarding 等）を管理する（skill-ops v0.3）
#
# 状態は ~/.claude/skill-ops/state.json に保存する。
# これはユーザー固有の状態（一度 onboarding すれば全マシン共通でよい）なので、
# 同期領域に置いてよい（eval-lock のようにホスト別にする必要はない）。
#
# Usage:
#   state.sh is-onboarded                # true / false を出力
#   state.sh get <key>                   # 任意キーの値
#   state.sh set-onboarded               # onboarded=true, onboarded_at=now
#   state.sh reset                       # onboarded=false（再 onboarding 用）
#   state.sh add-managed <skill>         # managed_skills に追加
#   state.sh list-managed                # managed_skills を1行ずつ
#   state.sh show                        # state.json 全体

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

STATE_DIR="${SKILL_OPS_STATE_DIR:-${HOME}/.claude/skill-ops}"
STATE_FILE="${STATE_DIR}/state.json"

ensure_state() {
  mkdir -p "$STATE_DIR"
  [ -f "$STATE_FILE" ] || printf '%s\n' '{"onboarded": false, "onboarded_at": null, "managed_skills": [], "schema": "0.3.0"}' > "$STATE_FILE"
}

CMD="${1:-}"
case "$CMD" in
  is-onboarded)
    ensure_state
    python3 -c "import json;print('true' if json.load(open('$STATE_FILE')).get('onboarded') else 'false')"
    ;;
  get)
    [ -n "${2:-}" ] || { echo "Usage: state.sh get <key>" >&2; exit 1; }
    ensure_state
    python3 -c "import json;v=json.load(open('$STATE_FILE')).get('$2','');print(v if not isinstance(v,(list,dict)) else json.dumps(v,ensure_ascii=False))"
    ;;
  set-onboarded)
    ensure_state
    python3 - "$STATE_FILE" "$(now_iso)" <<'PY'
import json,sys
p,ts=sys.argv[1],sys.argv[2]
d=json.load(open(p))
d['onboarded']=True; d['onboarded_at']=ts
json.dump(d,open(p,'w'),ensure_ascii=False,indent=2)
print('✓ onboarded = true ('+ts+')')
PY
    ;;
  reset)
    ensure_state
    python3 - "$STATE_FILE" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d['onboarded']=False; d['onboarded_at']=None
json.dump(d,open(p,'w'),ensure_ascii=False,indent=2)
print('✓ onboarded = false (reset — 次回起動で再 onboarding)')
PY
    ;;
  add-managed)
    [ -n "${2:-}" ] || { echo "Usage: state.sh add-managed <skill>" >&2; exit 1; }
    ensure_state
    python3 - "$STATE_FILE" "$2" <<'PY'
import json,sys
p,skill=sys.argv[1],sys.argv[2]
d=json.load(open(p))
ms=set(d.get('managed_skills',[])); ms.add(skill)
d['managed_skills']=sorted(ms)
json.dump(d,open(p,'w'),ensure_ascii=False,indent=2)
print('✓ managed_skills:', ' '.join(d['managed_skills']))
PY
    ;;
  list-managed)
    ensure_state
    python3 -c "import json;[print(s) for s in json.load(open('$STATE_FILE')).get('managed_skills',[])]"
    ;;
  show)
    ensure_state
    cat "$STATE_FILE"
    ;;
  *)
    echo "Usage: state.sh is-onboarded|get <key>|set-onboarded|reset|add-managed <skill>|list-managed|show" >&2
    exit 1 ;;
esac
