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

# Refuse to start if a recorder is already running. Without this, a manual
# `daybook start` and the scheduled job can both run: two ffmpeg processes
# capture the same room into the same folder, every line is transcribed twice,
# and disk use doubles.
PIDFILE="$DBK_ROOT/logs/record.pid"
if [ -f "$PIDFILE" ]; then
  _old=$(cat "$PIDFILE" 2>/dev/null)
  if [ -n "$_old" ] && kill -0 "$_old" 2>/dev/null; then
    # A live PID is not proof of a healthy recorder. An ffmpeg that ignores its
    # -t and hangs will hold this lock forever, and every later run exits here
    # "cleanly" — which once silently disabled recording for six days. A
    # recording never legitimately outlives a day, so anything older than that
    # is wedged: say so loudly, clear it, and carry on.
    _age=$(( $(date +%s) - $(stat -f %m "$PIDFILE" 2>/dev/null || echo 0) ))
    if [ "$_age" -gt 86400 ]; then
      dbk_log "STALE LOCK: pid $_old has held the recorder for $(( _age / 3600 ))h — killing it"
      kill "$_old" 2>/dev/null
      pkill -P "$_old" -f avfoundation 2>/dev/null
      sleep 2
      kill -9 "$_old" 2>/dev/null
      rm -f "$PIDFILE"
    else
      dbk_log "already recording (pid $_old) — not starting a second recorder"
      exit 0
    fi
  else
    rm -f "$PIDFILE"   # process gone
  fi
fi

if ! PICK=$(dbk_device_pick); then
  dbk_log "FATAL: no input device matches '$DBK_DEVICE_NAME'. Run: daybook devices"
  exit 1
fi
IDX="${PICK%%	*}"; MATCHED="${PICK#*	}"
# Log what was actually opened, never the configured list — a log saying
# "TONOR|MacBook Pro Microphone" hides which microphone is really recording.
dbk_log "input device [$IDX] $MATCHED"
if [ -n "$DBK_DEVICE_NAME" ] && [ "$MATCHED" != "${DBK_DEVICE_NAME%%|*}" ]; then
  dbk_log "NOTE: preferred device '${DBK_DEVICE_NAME%%|*}' not connected — recording on the fallback"
fi

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
