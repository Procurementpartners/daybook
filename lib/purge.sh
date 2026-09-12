#!/usr/bin/env bash
# Retention: compress transcribed audio to Opus, delete WAVs, expire old data.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
set -uo pipefail
dbk_dirs

freed=0
# 1. Archive WAVs that already have a transcript
for D in "$DBK_ROOT"/audio/*/; do
  [ -d "$D" ] || continue
  DAY=$(basename "$D")
  for W in "$D"seg-*.wav; do
    [ -e "$W" ] || continue
    BASE=$(basename "$W" .wav)
    [ -e "$DBK_ROOT/transcripts/$DAY/$BASE.txt" ] || continue
    mkdir -p "$DBK_ROOT/archive/$DAY"
    OPUS="$DBK_ROOT/archive/$DAY/$BASE.opus"
    if [ ! -e "$OPUS" ]; then
      sz=$(stat -f%z "$W")
      ffmpeg -hide_banner -loglevel error -i "$W" -c:a libopus -b:a 24k "$OPUS" 2>/dev/null \
        && { rm -f "$W"; freed=$((freed+sz)); }
    else
      rm -f "$W"
    fi
  done
  rmdir "$D" 2>/dev/null
done

# 2. Expire old archives and transcripts
find "$DBK_ROOT/archive" -type f -name '*.opus' -mtime +"$DBK_KEEP_AUDIO_DAYS" -delete 2>/dev/null
find "$DBK_ROOT/transcripts" -type f -name '*.txt' -mtime +"$DBK_KEEP_TRANSCRIPT_DAYS" -delete 2>/dev/null
find "$DBK_ROOT" -type d -empty -delete 2>/dev/null

echo "purge complete — reclaimed $((freed/1024/1024)) MB from WAVs"
echo "audio kept ${DBK_KEEP_AUDIO_DAYS}d, transcripts kept ${DBK_KEEP_TRANSCRIPT_DAYS}d"
