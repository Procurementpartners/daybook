#!/usr/bin/env bash
# Daybook installer. Safe to re-run.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$HOME/.daybook.conf"
BIN="$HOME/.local/bin"

echo "Daybook installer"
echo

# Daybook is macOS-only: it records via ffmpeg's avfoundation input and
# schedules with launchd. Neither exists elsewhere.
if [ "$(uname -s)" != "Darwin" ]; then
  echo "✗ Daybook requires macOS (uses avfoundation and launchd). Detected: $(uname -s)"
  exit 1
fi

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
if [ -z "${DBK_DEVICE_NAME:-}" ]; then
  echo
  echo "Available audio inputs:"
  ffmpeg -f avfoundation -list_devices true -i "" 2>&1 \
    | awk '/audio devices/,0' \
    | sed 's/\[AVFoundation[^]]*\] //' \
    | grep -E '^\[[0-9]+\]' \
    | sed 's/^/  /'
  echo
  echo "  Edit DBK_DEVICE_NAME in $CONF to pick one (blank = system default)."
fi

# 4. CLI on PATH
mkdir -p "$BIN"
ln -sf "$HERE/scripts/daybook" "$BIN/daybook"
echo "✓ daybook linked into $BIN"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "  ! add to your shell profile:  export PATH=\"\$HOME/.local/bin:\$PATH\"";;
esac

# 5. Claude skill — makes `daybook` usable by asking in plain language
SKILLDIR="$HOME/.claude/skills"
mkdir -p "$SKILLDIR"
ln -sfn "$HERE/plugins/daybook/skills/daybook" "$SKILLDIR/daybook"
echo "✓ daybook skill linked into $SKILLDIR"

# 6. Permission rules
# Scheduled/unattended runs do not fail on a missing permission — they stall
# forever waiting for a prompt nobody answers, producing no output and no error.
# These narrow rules let the daybook commands through without prompting.
python3 - "$HOME/.claude/settings.json" <<'PYEOF'
import json, pathlib, sys, os

p = pathlib.Path(sys.argv[1])
p.parent.mkdir(parents=True, exist_ok=True)
try:
    cfg = json.loads(p.read_text())
except Exception:
    cfg = {}

home = os.path.expanduser("~")
root = os.environ.get("DBK_ROOT", os.path.join(home, "Daybook"))
wanted = [
    "Bash(daybook:*)",
    f"Read(//{root.lstrip('/')}/**)",
    f"Write(//{root.lstrip('/')}/calendar/**)",
    f"Write(//{root.lstrip('/')}/summaries/**)",
]

perms = cfg.setdefault("permissions", {})
allow = perms.setdefault("allow", [])
added = [r for r in wanted if r not in allow]
allow.extend(added)

# The data directory sits outside any project, so a scheduled run refuses to
# write there with "Path is outside allowed working directories" — a workspace
# boundary, checked BEFORE the allow rules above, which is why clicking
# "Always allow" never makes it stop asking.
dirs = perms.setdefault("additionalDirectories", [])
dir_entry = root.rstrip("/") + "/"
dir_added = dir_entry not in dirs
if dir_added:
    dirs.append(dir_entry)

if added or dir_added:
    p.write_text(json.dumps(cfg, indent=2) + "\n")
    bits = []
    if added: bits.append(f"{len(added)} permission rule(s)")
    if dir_added: bits.append("the data directory")
    print("\u2713 added " + " and ".join(bits) + f" to {p}")
else:
    print("\u2713 permission rules already present")
PYEOF

# 7. Model
source "$HERE/lib/common.sh"
if [ -f "$DBK_MODEL" ]; then echo "✓ whisper model present"
else echo "→ downloading whisper model (~1.5 GB)…"; "$HERE/scripts/daybook" setup-model; fi

cat <<EOF

Done. Next:

  daybook doctor          check everything is wired up
  daybook start 60        record one minute as a test
  daybook today           transcribe it and build notes
  daybook schedule on     enable the daily job

Before you enable the schedule, read CONSENT.md — this records audio
in your workspace, and that is not only a technical decision.
EOF
