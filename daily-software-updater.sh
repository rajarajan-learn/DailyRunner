#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="$HOME/Logs/SoftwareUpdater"
mkdir -p "$LOG_DIR"

LOG="$LOG_DIR/daily-software-updater.log"
if [ -f "$LOG" ]; then
  archive="$LOG_DIR/daily-software-updater-$(date -r "$LOG" '+%Y-%m-%d_%H-%M-%S').log"
  if [ -e "$archive" ]; then
    archive="${archive%.log}-$$.log"
  fi
  mv -- "$LOG" "$archive"
fi

# Keep nine completed logs; the non-dated current log makes ten in total.
shopt -s nullglob
logs=("$LOG_DIR"/daily-software-updater-*.log)
if ((${#logs[@]} > 9)); then
  delete_count=$((${#logs[@]} - 9))
  rm -- "${logs[@]:0:delete_count}"
fi
shopt -u nullglob

: >"$LOG"

exec 3>&1                  # fd 3 = terminal, for the summary
exec >>"$LOG" 2>&1         # everything else is logged, not shown
say() { echo "$*" >&3; }

echo "===== $(date '+%F %T') ====="
ver() { "$1" --version 2>/dev/null | head -1 || echo "?"; }
step() { echo; echo "----- $* -----"; }

c0=$(ver claude); u0=$(ver uv); x0=$(ver codex)

step claude
claude update
sbx_out=""
while read -r -u 4 s st; do
  step "sbx $s ($st)"
  b=$(sbx exec "$s" claude --version | head -1 || echo "?")   # exec starts a stopped sandbox
  sbx exec "$s" claude update || true
  a=$(sbx exec "$s" claude --version | head -1 || echo "?")
  [ "$st" != running ] && { sbx stop "$s" || true; }
  [ "$b" != "$a" ] && sbx_out+="sbx     $s: $b -> $a"$'\n' || sbx_out+="sbx     $s: $a (no change)"$'\n'
done 4< <(sbx ls --json | jq -r '.sandboxes[] | select(.agent=="claude") | "\(.name) \(.status)"')
step codex
curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
step uv
uv self update

step apt
sudo apt update
pkgs=$(apt list --upgradable 2>/dev/null | tail -n +2 | cut -d/ -f1 | tr '\n' ' ')
sudo apt upgrade -y
sudo apt autoremove --purge -y
sudo apt autoclean

step snap
snaps=$(sudo snap refresh 2>&1 | awk '/refreshed$/{print $1" "$2}' || true)

c1=$(ver claude); u1=$(ver uv); x1=$(ver codex)

say "--- $(date '+%F %T') ---"
[ "$c0" != "$c1" ] && say "claude  $c0 -> $c1" || say "claude  $c1 (no change)"
[ "$u0" != "$u1" ] && say "uv      $u0 -> $u1" || say "uv      $u1 (no change)"
[ "$x0" != "$x1" ] && say "codex   $x0 -> $x1" || say "codex   $x1 (no change)"
[ -n "$sbx_out" ] && say "${sbx_out%$'\n'}" || true
if [ -n "$snaps" ]; then
  say "snap    $(wc -l <<<"$snaps") refreshed:"
  say "$(sed 's/^/          /' <<<"$snaps")"
else
  say "snap    all up to date"
fi
if [ -n "${pkgs// }" ]; then
  say "apt     $(wc -w <<<"$pkgs") upgraded: $pkgs"
else
  say "apt     nothing to upgrade"
fi
[ -f /var/run/reboot-required ] && say "==> REBOOT REQUIRED" || true
say "full log: $LOG"
