#!/usr/bin/env bash
# Segmented recorder. Usage: record.sh [duration_seconds]
# With no argument, records until DBK_END_HOUR then exits.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
set -uo pipefail
dbk_dirs

DAY=$(date +%Y-%m-%d)
OUTDIR="$DBK_ROOT/audio/$DAY"
LOG="$DBK_ROOT/logs/record-$DAY.log"
mkdir -p "$OUTDIR"
exec >>"$LOG" 2>&1

if ! IDX=$(dbk_device_index); then
  dbk_log "FATAL: no input device matching '$DBK_DEVICE_NAME'. Run: daybook devices"
  exit 1
fi
dbk_log "input device [$IDX] ${DBK_DEVICE_NAME:-<system default>}"

if [ "${1:-}" != "" ]; then
  DUR="$1"; dbk_log "manual run: ${DUR}s"
else
  END=$(date -j -f "%Y-%m-%d %H:%M:%S" \
        "$DAY $(printf '%02d:%02d' "$DBK_END_HOUR" "$DBK_END_MINUTE"):00" +%s 2>/dev/null)
  # An end at or before the start means the window crosses midnight.
  if [ $(( DBK_END_HOUR * 60 + DBK_END_MINUTE )) -le $(( DBK_START_HOUR * 60 + DBK_START_MINUTE )) ]; then
    END=$(( END + 86400 ))
    dbk_log "overnight window, ending tomorrow"
  fi
  DUR=$(( END - $(date +%s) ))
  if [ "$DUR" -le 0 ]; then
    dbk_log "past $(printf '%02d:%02d' "$DBK_END_HOUR" "$DBK_END_MINUTE"), nothing to do"; exit 0
  fi
  dbk_log "recording ${DUR}s until $(printf '%02d:%02d' "$DBK_END_HOUR" "$DBK_END_MINUTE")"
fi

echo $$ > "$DBK_ROOT/logs/record.pid"
trap 'rm -f "$DBK_ROOT/logs/record.pid"' EXIT

ffmpeg -hide_banner -loglevel warning \
  -f avfoundation -i ":$IDX" -t "$DUR" -ac 1 -ar 16000 \
  -f segment -segment_time "$DBK_SEGMENT_SECONDS" -strftime 1 -reset_timestamps 1 \
  "$OUTDIR/seg-%Y%m%d-%H%M%S.wav"

dbk_log "done: $(ls "$OUTDIR"/seg-*.wav 2>/dev/null | wc -l | tr -d ' ') segments"
