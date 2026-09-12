#!/usr/bin/env python3
"""
Slice a day's timestamped transcript into per-meeting notes using Outlook events.

Reads : ~/Daybook/transcripts/<day>/*.txt   lines like "[HH:MM:SS] text"
        ~/Daybook/calendar/<day>.json       events with UTC start/end
Writes: ~/Daybook/notes/<day>/NN-<slug>.md  plus 00-index.md and unscheduled.md
"""
import json, re, sys, os
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(os.environ.get("DBK_ROOT", str(Path.home() / "Daybook")))
day = sys.argv[1] if len(sys.argv) > 1 else datetime.now().strftime("%Y-%m-%d")

tdir = ROOT / "transcripts" / day
cfile = ROOT / "calendar" / f"{day}.json"
odir = ROOT / "notes" / day
odir.mkdir(parents=True, exist_ok=True)

# ---- load transcript lines, tagged with a real datetime -------------------
line_re = re.compile(r'^\[(\d{2}):(\d{2}):(\d{2})\]\s*(.*)$')
lines = []
for f in sorted(tdir.glob("*.txt")) if tdir.exists() else []:
    for raw in f.read_text(errors="replace").splitlines():
        m = line_re.match(raw.strip())
        if not m:
            continue
        h, mi, s, text = m.groups()
        if not text.strip() or text.strip() == "-":
            continue
        ts = datetime.strptime(f"{day} {h}:{mi}:{s}", "%Y-%m-%d %H:%M:%S").astimezone()
        lines.append((ts, text.strip()))
lines.sort(key=lambda x: x[0])

# ---- load events, convert UTC -> local ------------------------------------
events = []
if cfile.exists():
    data = json.loads(cfile.read_text())
    for e in data.get("events", []):
        st = datetime.fromisoformat(e["start"].replace("Z", "+00:00")).astimezone()
        en = datetime.fromisoformat(e["end"].replace("Z", "+00:00")).astimezone()
        events.append({**e, "start_local": st, "end_local": en})
    events.sort(key=lambda e: e["start_local"])

def slug(s):
    s = re.sub(r'[^\w\s-]', '', s).strip().lower()
    return re.sub(r'[\s_-]+', '-', s)[:50] or "untitled"

claimed = set()
index = [f"# Daily notes — {day}\n"]

for i, ev in enumerate(events, 1):
    hits = [(t, x) for (t, x) in lines if ev["start_local"] <= t <= ev["end_local"]]
    for t, x in hits:
        claimed.add((t, x))

    dur = int((ev["end_local"] - ev["start_local"]).total_seconds() // 60)
    name = f"{i:02d}-{slug(ev['subject'])}.md"
    body = [
        f"# {ev['subject']}",
        "",
        f"- **When:** {ev['start_local']:%H:%M}–{ev['end_local']:%H:%M} ({dur} min)",
        f"- **Organizer:** {ev.get('organizer') or '—'}",
        f"- **Location:** {ev.get('location') or '—'}",
    ]
    att = ev.get("attendees") or []
    if att:
        body.append(f"- **Attendees:** {', '.join(a.split('@')[0] for a in att)}")
    # Prefer a Teams transcript when one exists — it carries speaker names,
    # which the local recording cannot. Fall back to the mic transcript.
    teams_file = ROOT / "teams" / day / f"{ev['start_local']:%H%M}-{slug(ev['subject'])}.txt"
    if teams_file.exists() and teams_file.stat().st_size > 0:
        body += ["", "## Transcript", "",
                 "_Source: Microsoft Teams — speaker-attributed._", ""]
        body += teams_file.read_text(errors="replace").rstrip().splitlines()
        if hits:
            body += ["", f"<details><summary>Local mic recording ({len(hits)} lines)</summary>", ""]
            body += [f"`{t:%H:%M:%S}`  {x}" for t, x in hits]
            body += ["", "</details>"]
        source = "teams"
    else:
        body += ["", "## Transcript", "",
                 "_Source: local microphone — no speaker labels._", ""]
        if hits:
            body += [f"`{t:%H:%M:%S}`  {x}" for t, x in hits]
        else:
            body.append("_No audio captured during this window._")
        source = "mic" if hits else "none"
    body.append("")
    (odir / name).write_text("\n".join(body))

    mark = {"teams": "**Teams transcript**",
            "mic":   f"{len(hits)} lines (mic)",
            "none":  "no audio"}[source]
    index.append(f"- `{ev['start_local']:%H:%M}` [{ev['subject']}]({name}) — {mark}")

# ---- anything outside a meeting ------------------------------------------
leftover = [(t, x) for (t, x) in lines if (t, x) not in claimed]
if leftover:
    body = ["# Unscheduled / desk audio", ""]
    body += [f"`{t:%H:%M:%S}`  {x}" for t, x in leftover]
    (odir / "unscheduled.md").write_text("\n".join(body) + "\n")
    index.append(f"- [Unscheduled / desk audio](unscheduled.md) — {len(leftover)} lines")

index.append(f"\n_{len(lines)} transcript lines across {len(events)} calendar events._")
(odir / "00-index.md").write_text("\n".join(index) + "\n")
print(f"wrote {len(events)+1} notes to {odir}")
print(f"  matched: {len(claimed)} lines   unscheduled: {len(leftover)}")
