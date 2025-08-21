#!/usr/bin/env bash
set -Eeuo pipefail

SRC="/profiles"
DST="/opt/server/user/profiles"

# prevent overlapping runs (cron) if one takes longer than the interval
exec 9>/tmp/sync-profiles.lock
flock -n 9 || exit 0

updated=0

# NOTE: use process substitution to keep the loop in the current shell
while IFS= read -r -d '' f; do
  echo "Checking ${f}"
  timestamp="$(date +%Y%m%dT%H%M)"
  base="$(basename "$f")"
  dst="${DST}/${base}"

  if [ -f "$dst" ]; then
    backup_prof="${dst}-${timestamp}.bak"
    echo "backup ${base} to ${backup_prof}"
    mv -f "$dst" "$backup_prof"
  fi

  tmp="${dst}.tmp.$$"
  echo "copy ${f} to ${tmp}, then move ${tmp} to ${dst}"
  cp -f "$f" "$tmp" && mv -f "$tmp" "$dst"

  rm -f "$f"
  updated=1
done < <(find "$SRC" -type f -name "*.json" -print0)

if (( updated )); then
  echo "Profiles updated; requesting server restart..."
  pids="$(pgrep -f 'SPT\.Server\.exe' || true)"
  if [ -n "$pids" ]; then
    echo "Send SIGTERM to ${pids}"
    kill -TERM $pids || true
  else
    echo "SPT.Server.exe not found (already down?)"
  fi
else
  echo "No updates"
fi
