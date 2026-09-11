#!/usr/bin/env python3
"""Convert whisper JSON offsets to wall-clock times using the segment filename."""
import json, re, sys
from datetime import datetime, timedelta

path = sys.argv[1]
m = re.search(r'seg-(\d{8})-(\d{6})', path)
if not m:
    sys.exit(1)
start = datetime.strptime(m.group(1) + m.group(2), "%Y%m%d%H%M%S")

with open(path) as f:
    data = json.load(f)

for seg in data.get("transcription", []):
    off = seg.get("offsets", {}).get("from", 0)      # milliseconds
    text = seg.get("text", "").strip()
    if not text:
        continue
    t = start + timedelta(milliseconds=off)
    print(f"[{t:%H:%M:%S}] {text}")
