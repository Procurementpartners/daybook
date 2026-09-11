#!/usr/bin/env bash
# Retention: compress transcribed audio to Opus, delete WAVs, expire old data.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
set -uo pipefail
vn_dirs

freed=0
# 1. Archive WAVs that already have a transcript
for D in "$VN_ROOT"/audio/*/; do
  [ -d "$D" ] || continue
  DAY=$(basename "$D")
  for W in "$D"seg-*.wav; do
    [ -e "$W" ] || continue
    BASE=$(basename "$W" .wav)
    [ -e "$VN_ROOT/transcripts/$DAY/$BASE.txt" ] || continue
    mkdir -p "$VN_ROOT/archive/$DAY"
    OPUS="$VN_ROOT/archive/$DAY/$BASE.opus"
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
find "$VN_ROOT/archive" -type f -name '*.opus' -mtime +"$VN_KEEP_AUDIO_DAYS" -delete 2>/dev/null
find "$VN_ROOT/transcripts" -type f -name '*.txt' -mtime +"$VN_KEEP_TRANSCRIPT_DAYS" -delete 2>/dev/null
find "$VN_ROOT" -type d -empty -delete 2>/dev/null

echo "purge complete — reclaimed $((freed/1024/1024)) MB from WAVs"
echo "audio kept ${VN_KEEP_AUDIO_DAYS}d, transcripts kept ${VN_KEEP_TRANSCRIPT_DAYS}d"
