#!/usr/bin/env bash
# lib.sh — skill-ops 共通ライブラリ
#
# 設計方針（v0.2 / レビュー反映）:
#   - Mac(BSD) / Linux(GNU) 両対応。`sed -i` は一切使わない。
#   - 「ログが単一の真実」: invocation_count 等のカウンタは meta.yaml に書き戻さず、
#     JSONL の行数から都度集計する（並行 read-modify-write レースを構造的に排除）。
#   - 評価ロックは同期されないマシンローカル（$TMPDIR）にスキル名スコープで置く。
#   - meta.yaml は読み取り専用（grep のみ。書き戻しによる lost-update を起こさない）。
#
# 3スクリプト(log_invocation/log_feedback/skill_stats)から source される。

# 管理対象スキルのルート（テスト時は SKILL_OPS_SKILLS_DIR で上書き可能）
SKILLS_DIR="${SKILL_OPS_SKILLS_DIR:-${HOME}/.claude/skills}"

# 評価ロック置き場: 同期領域(~/.claude)を避け、マシンローカルの一時領域に置く。
# これにより「Mac で評価中の lock が Linux に同期して実利用を誤判定」する事故を防ぐ。
EVAL_LOCK_DIR="${SKILL_OPS_EVAL_DIR:-${TMPDIR:-/tmp}/skill-ops-eval}"

# --- 時刻ヘルパ（Mac/Linux 共通の date のみ使用） ---
now_iso()   { date +%Y-%m-%dT%H:%M:%S%z; }
now_epoch() { date +%s; }

# ファイルの mtime epoch（BSD: stat -f / GNU: stat -c をフォールバック）
epoch_of() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }

# --- JSON 文字列エスケープ（sed 不使用・bash パラメータ展開のみ） ---
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"      # backslash を先に
  s="${s//\"/\\\"}"      # double quote
  s="${s//$'\n'/ }"      # newline -> space
  s="${s//$'\t'/ }"      # tab -> space
  printf '%s' "$s"
}

# --- パス解決 ---
skill_dir()      { printf '%s/%s' "$SKILLS_DIR" "$1"; }
telemetry_dir()  { printf '%s/%s/telemetry' "$SKILLS_DIR" "$1"; }
meta_file()      { printf '%s/%s/meta.yaml' "$SKILLS_DIR" "$1"; }

ensure_telemetry() {
  local d; d="$(telemetry_dir "$1")"
  [ -d "$d" ] || mkdir -p "$d"
}

# --- meta.yaml 読み取り（書き込まない。grep + 通常 sed は両OSで安全） ---
meta_get() {
  local m; m="$(meta_file "$1")"
  [ -f "$m" ] || { printf ''; return; }
  grep "^$2:" "$m" 2>/dev/null | head -1 | sed "s/^$2:[[:space:]]*//" | tr -d '"'
}

# --- テレメトリ集計（JSONL の行数 = 真実。grep -c の exit1 は || で吸収） ---
count_lines() { local f="$1"; [ -f "$f" ] && wc -l < "$f" | tr -d ' ' || echo 0; }

# grep -c はマッチ0でも "0" を出力しつつ exit 1 を返すため、|| echo 0 だと
# 二重出力になる。コマンド置換でキャプチャして1つだけ返す。
count_invocations() {
  local f n; f="$(telemetry_dir "$1")/invocations.jsonl"
  [ -f "$f" ] || { echo 0; return; }
  n="$(grep -c '"ts"' "$f" 2>/dev/null)"; echo "${n:-0}"
}
count_outcome() {
  local f n; f="$(telemetry_dir "$1")/invocations.jsonl"
  [ -f "$f" ] || { echo 0; return; }
  n="$(grep -c "\"outcome\":\"$2\"" "$f" 2>/dev/null)"; echo "${n:-0}"
}
count_eval_runs() {
  local f n; f="$(telemetry_dir "$1")/eval-runs.jsonl"
  [ -f "$f" ] || { echo 0; return; }
  n="$(grep -c '"ts"' "$f" 2>/dev/null)"; echo "${n:-0}"
}

# --- 評価モード判定（スキル名スコープ・同期外 lock・lock 内 epoch で鮮度判定） ---
# 真: 評価中（実利用としてカウントしない） / 偽: 通常の実利用
is_eval_mode() {
  local lock="${EVAL_LOCK_DIR}/$1.lock"
  [ -f "$lock" ] || return 1
  # lock 内に書いた epoch を読む（mtime は同期で汚染されうるため使わない）
  local started now age
  started="$(grep -o '"epoch":[0-9]*' "$lock" 2>/dev/null | head -1 | cut -d: -f2)"
  [ -n "$started" ] || return 1
  now="$(now_epoch)"
  age=$(( now - started ))
  # 24h を超える lock はクラッシュ残留とみなし無効（最終保険。通常は trap で解放される）
  [ "$age" -ge 0 ] && [ "$age" -lt 86400 ]
}

# 評価ロックの作成/解放（judge/evolve から使う。PID と epoch を記録）
eval_lock_acquire() {
  mkdir -p "$EVAL_LOCK_DIR"
  printf '{"skill":"%s","epoch":%s,"iso":"%s","pid":%s,"host":"%s"}\n' \
    "$1" "$(now_epoch)" "$(now_iso)" "$$" "$(hostname -s 2>/dev/null || echo unknown)" \
    > "${EVAL_LOCK_DIR}/$1.lock"
}
eval_lock_release() { rm -f "${EVAL_LOCK_DIR}/$1.lock"; }
