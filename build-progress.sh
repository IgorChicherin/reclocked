#!/usr/bin/env bash
# Show progress and an ETA for a running pkgbuild/linux-lts-mbp kernel build.
#
#   ./build-progress.sh              # update every 60 s
#   ./build-progress.sh 30           # update every 30 s
#
# Counts finished modules (*.mod in the build tree) against the module count of the installed stock
# kernel with the same config. Add ~15-25 min after 100% for vmlinux link, BTF, bpftool and packaging.
set -euo pipefail

base=linux-lts
interval=${1:-60}
[[ $interval =~ ^[1-9][0-9]*$ ]] || { echo "usage: build-progress.sh [interval-seconds]" >&2; exit 1; }

here=$(cd "$(dirname "$0")" && pwd)
shopt -s nullglob
trees=("$here/pkgbuild/$base-mbp/src"/linux-*/)
(( ${#trees[@]} == 1 )) || { echo "ERROR: no single build tree in pkgbuild/$base-mbp/src/ — build not started?" >&2; exit 1; }
tree=${trees[0]}

total=0
for d in /usr/lib/modules/*/; do
  if [[ -r $d/pkgbase && $(<"$d/pkgbase") == "$base" ]]; then
    total=$(find "$d" -name '*.ko*' | wc -l)
    break
  fi
done
(( total )) || { echo "ERROR: stock $base not installed, can't tell the module total" >&2; exit 1; }

count() { find "$tree" -name '*.mod' | wc -l; }

n0=$(count); t0=$(date +%s)
echo "$base-mbp: $(basename "$tree"), $total modules expected, sampling every ${interval}s (Ctrl+C to stop)"
while :; do
  n=$(count); dt=$(( $(date +%s) - t0 ))
  pct=$(( n * 100 / total ))
  if (( dt > 0 && n > n0 )); then
    rate=$(( (n - n0) * 60 / dt ))
    left=$(( (total - n) * dt / (n - n0) / 60 ))
    printf '%s  %d/%d (%d%%)  %d mod/min  ~%d min left (+15-25 min link/package)\n' \
      "$(date +%T)" "$n" "$total" "$pct" "$rate" "$left"
  else
    printf '%s  %d/%d (%d%%)  measuring...\n' "$(date +%T)" "$n" "$total" "$pct"
  fi
  pgrep -f 'makepkg' >/dev/null || { echo "makepkg is no longer running — build finished or stopped"; exit 0; }
  (( n >= total )) && { echo "all modules compiled; linking and packaging now"; exit 0; }
  sleep "$interval"
done
