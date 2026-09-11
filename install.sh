#!/usr/bin/env bash
# VoiceNotes installer. Safe to re-run.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$HOME/.voicenotes.conf"
BIN="$HOME/.local/bin"

echo "VoiceNotes installer"
echo

# 1. Dependencies
if ! command -v brew >/dev/null; then
  echo "✗ Homebrew required: https://brew.sh"; exit 1
fi
for pkg in ffmpeg whisper-cpp; do
  if brew list "$pkg" >/dev/null 2>&1; then echo "✓ $pkg already installed"
  else echo "→ installing $pkg…"; brew install "$pkg" >/dev/null && echo "✓ $pkg"; fi
done

# 2. Config
if [ -f "$CONF" ]; then
  echo "✓ config exists at $CONF (left unchanged)"
else
  cp "$HERE/config.example.sh" "$CONF"
  echo "✓ config written to $CONF"
fi

# 3. Pick an input device if one isn't set
source "$CONF"
if [ -z "${VN_DEVICE_NAME:-}" ]; then
  echo
  echo "Available audio inputs:"
  ffmpeg -f avfoundation -list_devices true -i "" 2>&1 \
    | awk '/audio devices/,0' | grep -E '^\[' | sed 's/\[AVFoundation[^]]*\] /  /'
  echo
  echo "  Edit VN_DEVICE_NAME in $CONF to pick one (blank = system default)."
fi

# 4. CLI on PATH
mkdir -p "$BIN"
ln -sf "$HERE/bin/vn" "$BIN/vn"
echo "✓ vn linked into $BIN"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "  ! add to your shell profile:  export PATH=\"\$HOME/.local/bin:\$PATH\"";;
esac

# 5. Model
source "$HERE/lib/common.sh"
if [ -f "$VN_MODEL" ]; then echo "✓ whisper model present"
else echo "→ downloading whisper model (~1.5 GB)…"; "$HERE/bin/vn" setup-model; fi

cat <<EOF

Done. Next:

  vn doctor          check everything is wired up
  vn start 60        record one minute as a test
  vn today           transcribe it and build notes
  vn schedule on     enable the daily job

Before you enable the schedule, read CONSENT.md — this records audio
in your workspace, and that is not only a technical decision.
EOF
