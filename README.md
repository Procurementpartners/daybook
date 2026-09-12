# Daybook

Continuous workday audio capture on macOS, transcribed locally, sliced into per-meeting notes using your Outlook calendar.

**macOS only.** Recording uses ffmpeg's avfoundation input and scheduling uses launchd, neither of which exists on Linux or Windows. Tested on Apple Silicon; Whisper runs on Metal.

Nothing leaves the machine. Whisper runs on-device; there is no API key and no upload.

## What it does

```
08:00  launchd starts a segmented recording
       → 5-minute WAV chunks, each named with its wall-clock start time
every 10 min  silent chunks are skipped, the rest go through Whisper
       → transcript lines stamped [HH:MM:SS] in real clock time
17:00  recording stops
on demand  calendar events slice the day's transcript into one note per meeting
19:30  audio is compressed to Opus and aged out
```

The wall-clock stamps are the whole trick. Because every line carries a real time, matching it to a calendar event is arithmetic rather than guesswork.

## Requirements

- macOS (Apple Silicon recommended — Whisper uses Metal)
- [Homebrew](https://brew.sh)
- ~2 GB disk for the model, plus roughly 1 GB per recorded day before compression
- A microphone, and Microphone permission for whatever runs the recorder

## Install

Daybook lives in an **internal** repo, so you need to be signed in to GitHub first:

```bash
gh auth login
```

Then one line:

```bash
gh repo clone Procurementpartners/daybook ~/.daybook-src && ~/.daybook-src/install.sh
```

Then check it:

```bash
daybook doctor
```

To update later, re-run `~/.daybook-src/bootstrap.sh` — it pulls and reinstalls in place.

> A `curl | bash` install isn't possible while the repo is internal: `raw.githubusercontent.com` returns 404 to unauthenticated requests. If the repo is ever made public, `bootstrap.sh` becomes curl-able as-is.

`install.sh` installs `ffmpeg` and `whisper-cpp` via Homebrew, writes `~/.daybook.conf`, links `daybook` into `~/.local/bin`, and downloads the Whisper model (~1.5 GB).

## Use

```bash
daybook start 60        # record 60 seconds
daybook today           # transcribe + build notes + show the index
daybook status          # what's running, today's counts, disk use
daybook doctor          # dependency / permission / device check
daybook schedule on     # enable the daily 08:00 job
daybook purge           # compress audio, apply retention
```

Notes land in `~/Daybook/notes/YYYY-MM-DD/` as Markdown — one file per meeting plus `00-index.md`.

## Installing the agent org-wide

The repo doubles as a Claude Code plugin marketplace, so the agent can be distributed to the team without anyone copying files.

Individually:

```
/plugin marketplace add Procurementpartners/daybook
/plugin install daybook@procurementpartners-daybook
```

Or list it for the org on a Team/Enterprise plan via **Organization settings → Plugins**, pointing at this repo.

**Set it to "Available" — never "Installed by default" or "Required".**

Organization settings offer all three, but only Available is appropriate here. Daybook records people. Someone should arrive at it by deciding to, not by finding it already in their Claude. "Required" is worse still: it would mean a colleague cannot remove an agent for a recording tool from their own environment.

Available puts it in the catalog for anyone who wants it, which is the whole point of publishing it, without putting it in front of anyone who didn't ask.

**This distributes the agent, not the recorder.** The plugin is instructions — it cannot record audio, run Whisper, or install anything. Each person still runs the local install on their Mac:

```bash
gh repo clone Procurementpartners/daybook ~/.daybook-src && ~/.daybook-src/install.sh
```

If someone has the plugin but not the CLI, the skill tells them exactly that instead of trying to work around it.

## The Claude skill

`install.sh` links a skill into `~/.claude/skills/daybook`, so instead of remembering commands you can ask:

> what happened in my meetings today?
> what did I commit to in the vendor call?
> catch me up on the Jira sync I missed

The skill does the parts the CLI can't. It pulls your calendar into the JSON that `daybook notes` needs, fetches Teams transcripts where the tenant allows it, runs `daybook today`, then reads the notes and tells you what was decided and who owns what.

It also knows how to read these transcripts honestly — it won't attribute a line to a named person when the source is mic audio with no speaker labels, and it flags a one-sided call rather than summarizing half a conversation as the whole thing.

## Configuration

Everything lives in `~/.daybook.conf`:

| Setting | Default | Notes |
|---|---|---|
| `DBK_DEVICE_NAME` | *(system default)* | Matched by name, resolved at each start, so USB reordering can't break it |
| `DBK_START_HOUR` / `DBK_START_MINUTE` | 8 / 0 | |
| `DBK_END_HOUR` / `DBK_END_MINUTE` | 17 / 0 | An end at or before the start means an overnight window |
| `DBK_WEEKDAYS` | `1 2 3 4 5` | 1 = Monday |
| `DBK_SEGMENT_SECONDS` | 300 | Shorter = less lost to a crash |
| `DBK_SILENCE_FLOOR` | -45 | Peak dBFS below which a chunk is skipped |
| `DBK_KEEP_AUDIO_DAYS` | 0 | 0 deletes audio as soon as it's transcribed; >0 keeps an Opus archive that many days |
| `DBK_KEEP_TRANSCRIPT_DAYS` | 90 | |
| `DBK_PROMPT` | — | Domain vocabulary to bias transcription |

## Timezones and working hours

Everything is **local time on the machine that runs it**. There is no shared clock, no UTC offset to set, and no server. A colleague in Bengaluru sets `DBK_START_HOUR=9`, `DBK_END_HOUR=19` and gets 09:00–19:00 IST; the recorder, the schedule, the transcript timestamps and the calendar matcher all agree because they all ask the same machine what time it is.

Three things this supports that a fixed 8–17 assumption doesn't:

- **Half-hour starts** — `DBK_START_MINUTE=30` for a 09:30 day.
- **Late finishes** — an end of 22:00 or later works; the nightly compression job wraps past midnight correctly.
- **Overnight windows** — set an end at or before the start, e.g. 20:00 → 04:00, and the recorder runs through midnight into the next morning.

`daybook doctor` prints the resolved window with the machine's timezone, so a colleague can confirm what their config actually means:

```
✓ window 09:30 – 22:00  IST, UTC+0530
```

The one genuinely shared clock is the **calendar JSON**, whose times are UTC. `make-notes.py` converts to local on read, so this is handled — but it's the place a timezone error would show up, as notes landing on the wrong meeting. Check one known meeting after first setup.

## Calendar

`daybook notes` reads `~/Daybook/calendar/YYYY-MM-DD.json`. Populating it needs access to your calendar, which a shell script doesn't have — see [docs/calendar.md](docs/calendar.md).

Without a calendar file you still get transcripts; they just land in one undifferentiated bucket.

## Teams transcripts take priority

Where a Teams transcript exists, it is used instead of the microphone transcript — it has speaker names and doesn't depend on what your headphones do. Drop it at `~/Daybook/teams/<date>/<HHMM>-<slug>.txt` and the note picks it up, folding the mic version into a collapsed block beneath.

Reaching them through the Graph API needs a tenant setting that Microsoft now defaults to **off**. See [docs/teams.md](docs/teams.md) for the exact thing to ask an admin for.

The recorder keeps running either way — Teams only covers transcribed Teams meetings, not in-person conversations, phone calls, or desk work.

## Known limits

**No speaker labels from the microphone.** Whisper transcribes, it doesn't diarize. A 1:1 is usually readable from context; a six-person call reads as a wall of text. Fixing it needs a diarization model or a source that already carries names, like Teams transcripts.

**The microphone only hears the room.** If you wear headphones, the far end of a call never reaches the mic and you capture half the conversation. Test yours before trusting it:

```bash
daybook start 20   # then talk, and play something through your speakers
daybook today
```

If the played audio isn't in the transcript, you need either your meeting platform's own transcription or a loopback device such as BlackHole.

**Disk.** By default no audio is kept: each segment is deleted the moment its transcript is written, so the working set stays around 50 MB rather than a day's 1 GB. Transcripts are a few hundred KB per day. Set `DBK_KEEP_AUDIO_DAYS` above 0 to keep a compressed archive instead (~10 MB/hour).

**Deleting audio is irreversible.** Once a segment is gone you cannot re-transcribe it with a better model or a corrected vocabulary prompt — a garbled passage stays garbled. If you're still tuning `DBK_PROMPT` or evaluating accuracy, set a few days of retention first and drop to 0 once you're happy. Audio that failed to transcribe is always kept for retry regardless of this setting.

**Accuracy degrades with distance.** Close speech into a decent mic transcribes well. Someone across the room does not.

## Before you deploy this

Read [CONSENT.md](CONSENT.md). This tool records people. That is a legal and cultural question before it is a technical one.

## Layout

```
scripts/daybook                    CLI
scripts/daybook-install-schedule   launchd installer (kept separate and explicit)
lib/record.sh             segmented ffmpeg capture
lib/transcribe.sh         silence gate + Whisper
lib/wallclock.py          whisper offsets → clock time
lib/make-notes.py         calendar slicing
lib/purge.sh              compression + retention
```
