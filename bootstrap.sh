#!/usr/bin/env bash
# Daybook one-line installer.
#
#   curl -fsSL <raw-url>/bootstrap.sh | bash
#
# Downloads Daybook, then runs install.sh. Safe to re-run: an existing
# checkout is updated in place rather than re-cloned.
set -uo pipefail

REPO="${DAYBOOK_REPO:-https://github.com/Procurementpartners/daybook.git}"
DEST="${DAYBOOK_DEST:-$HOME/.daybook-src}"

echo "Daybook"
echo

if [ "$(uname -s)" != "Darwin" ]; then
  echo "✗ Daybook requires macOS (it records via avfoundation and schedules with launchd)."
  echo "  Detected: $(uname -s)"
  exit 1
fi

if ! command -v git >/dev/null; then
  echo "✗ git not found. Install the Xcode command line tools first:"
  echo "    xcode-select --install"
  exit 1
fi

if [ -d "$DEST/.git" ]; then
  echo "→ updating existing install at $DEST"
  git -C "$DEST" pull --ff-only --quiet \
    || echo "! could not fast-forward; leaving your checkout alone"
else
  echo "→ downloading to $DEST"
  if ! git clone --quiet --depth 1 "$REPO" "$DEST"; then
    echo "✗ clone failed. Check your network, or clone manually:"
    echo "    git clone $REPO $DEST"
    exit 1
  fi
fi

echo
exec "$DEST/install.sh"
