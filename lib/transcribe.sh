#!/usr/bin/env bash
# Transcribes completed segments. Idempotent — safe to run on a timer.
# Silent segments are skipped so wall-clock timing stays exact.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
set -uo pipefail
vn_dirs

DAY="${1:-$(date +%Y-%m-%d)}"
AUDIO="$VN_ROOT/audio/$DAY"
OUT="$VN_ROOT/transcripts/$DAY"
mkdir -p "$OUT"
[ -d "$AUDIO" ] || { echo "no audio for $DAY"; exit 0; }

if [ ! -f "$VN_MODEL" ]; then
  echo "FATAL: whisper model missing at $VN_MODEL — run: vn setup-model" >&2; exit 1
fi

PROMPT_ARG=()
[ -n "$VN_PROMPT" ] && PROMPT_ARG=(--prompt "$VN_PROMPT")

for W in "$AUDIO"/seg-*.wav; do
  [ -e "$W" ] || continue
  BASE=$(basename "$W" .wav)
  DONE="$OUT/$BASE.txt"
  [ -e "$DONE" ] && continue

  # Never touch the segment ffmpeg is still writing
  if [ -f "$VN_ROOT/logs/record.pid" ] && [ -n "$(find "$W" -mmin -1 2>/dev/null)" ]; then
    continue
  fi

  PEAK=$(vn_peak_db "$W"); PEAK=${PEAK:--99}
  if awk -v v="$PEAK" -v f="$VN_SILENCE_FLOOR" 'BEGIN{exit !(v<f)}'; then
    echo "[silent] $BASE (${PEAK}dB)"
    : > "$DONE"; continue
  fi

  echo "[speech] $BASE (${PEAK}dB)"
  whisper-cli -m "$VN_MODEL" -f "$W" -oj -of "$OUT/$BASE" \
              -l "$VN_LANG" -t 8 "${PROMPT_ARG[@]}" >/dev/null 2>&1

  if [ -f "$OUT/$BASE.json" ]; then
    python3 "$(dirname "${BASH_SOURCE[0]}")/wallclock.py" "$OUT/$BASE.json" > "$DONE"
    rm -f "$OUT/$BASE.json"
  else
    echo "(transcription failed)" > "$DONE"
  fi
done
