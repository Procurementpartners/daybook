#!/usr/bin/env bash
# Transcribes completed segments. Idempotent — safe to run on a timer.
# Silent segments are skipped so wall-clock timing stays exact.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
set -uo pipefail
dbk_dirs

DAY="${1:-$(date +%Y-%m-%d)}"
AUDIO="$DBK_ROOT/audio/$DAY"
OUT="$DBK_ROOT/transcripts/$DAY"
mkdir -p "$OUT"
[ -d "$AUDIO" ] || { echo "no audio for $DAY"; exit 0; }

if [ ! -f "$DBK_MODEL" ]; then
  echo "FATAL: whisper model missing at $DBK_MODEL — run: daybook setup-model" >&2; exit 1
fi

PROMPT_ARG=()
[ -n "$DBK_PROMPT" ] && PROMPT_ARG=(--prompt "$DBK_PROMPT")

for W in "$AUDIO"/seg-*.wav; do
  [ -e "$W" ] || continue
  BASE=$(basename "$W" .wav)
  DONE="$OUT/$BASE.txt"
  [ -e "$DONE" ] && continue

  # Never touch the segment ffmpeg is still writing
  if [ -f "$DBK_ROOT/logs/record.pid" ] && [ -n "$(find "$W" -mmin -1 2>/dev/null)" ]; then
    continue
  fi

  PEAK=$(dbk_peak_db "$W"); PEAK=${PEAK:--99}
  if awk -v v="$PEAK" -v f="$DBK_SILENCE_FLOOR" 'BEGIN{exit !(v<f)}'; then
    echo "[silent] $BASE (${PEAK}dB)"
    : > "$DONE"
    [ "$DBK_KEEP_AUDIO_DAYS" = "0" ] && rm -f "$W"
    continue
  fi

  echo "[speech] $BASE (${PEAK}dB)"
  whisper-cli -m "$DBK_MODEL" -f "$W" -oj -of "$OUT/$BASE" \
              -l "$DBK_LANG" -t 8 "${PROMPT_ARG[@]}" >/dev/null 2>&1

  if [ -f "$OUT/$BASE.json" ]; then
    python3 "$(dirname "${BASH_SOURCE[0]}")/wallclock.py" "$OUT/$BASE.json" > "$DONE"
    rm -f "$OUT/$BASE.json"
    # Audio is the sensitive artefact. With retention 0, drop it as soon as
    # the transcript exists — never wait for the nightly purge.
    if [ "$DBK_KEEP_AUDIO_DAYS" = "0" ] && [ -s "$DONE" ]; then
      rm -f "$W"
    fi
  else
    # Keep the audio when transcription failed, so it can be retried.
    echo "(transcription failed — audio kept for retry)" > "$DONE"
  fi
done
