#!/usr/bin/env bash
# Segmented recorder. Usage: record.sh [duration_seconds]
# With no argument, records until VN_END_HOUR then exits.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
set -uo pipefail
vn_dirs

DAY=$(date +%Y-%m-%d)
OUTDIR="$VN_ROOT/audio/$DAY"
LOG="$VN_ROOT/logs/record-$DAY.log"
mkdir -p "$OUTDIR"
exec >>"$LOG" 2>&1

if ! IDX=$(vn_device_index); then
  vn_log "FATAL: no input device matching '$VN_DEVICE_NAME'. Run: vn devices"
  exit 1
fi
vn_log "input device [$IDX] ${VN_DEVICE_NAME:-<system default>}"

if [ "${1:-}" != "" ]; then
  DUR="$1"; vn_log "manual run: ${DUR}s"
else
  END=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DAY $(printf '%02d' "$VN_END_HOUR"):00:00" +%s 2>/dev/null)
  DUR=$(( END - $(date +%s) ))
  if [ "$DUR" -le 0 ]; then vn_log "past ${VN_END_HOUR}:00, nothing to do"; exit 0; fi
  vn_log "recording ${DUR}s until ${VN_END_HOUR}:00"
fi

echo $$ > "$VN_ROOT/logs/record.pid"
trap 'rm -f "$VN_ROOT/logs/record.pid"' EXIT

ffmpeg -hide_banner -loglevel warning \
  -f avfoundation -i ":$IDX" -t "$DUR" -ac 1 -ar 16000 \
  -f segment -segment_time "$VN_SEGMENT_SECONDS" -strftime 1 -reset_timestamps 1 \
  "$OUTDIR/seg-%Y%m%d-%H%M%S.wav"

vn_log "done: $(ls "$OUTDIR"/seg-*.wav 2>/dev/null | wc -l | tr -d ' ') segments"
