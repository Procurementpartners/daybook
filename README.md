# VoiceNotes

Continuous workday audio capture on macOS, transcribed locally, sliced into per-meeting notes using your Outlook calendar.

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

## Install

```bash
git clone <your-remote> voicenotes && cd voicenotes
./install.sh
vn doctor
```

`install.sh` installs `ffmpeg` and `whisper-cpp` via Homebrew, writes `~/.voicenotes.conf`, links `vn` into `~/.local/bin`, and downloads the Whisper model (~1.5 GB).

## Use

```bash
vn start 60        # record 60 seconds
vn today           # transcribe + build notes + show the index
vn status          # what's running, today's counts, disk use
vn doctor          # dependency / permission / device check
vn schedule on     # enable the daily 08:00 job
vn purge           # compress audio, apply retention
```

Notes land in `~/VoiceNotes/notes/YYYY-MM-DD/` as Markdown — one file per meeting plus `00-index.md`.

## The Claude skill

`install.sh` links a skill into `~/.claude/skills/voicenotes`, so instead of remembering commands you can ask:

> what happened in my meetings today?
> what did I commit to in the vendor call?
> catch me up on the Jira sync I missed

The skill does the parts the CLI can't. It pulls your calendar into the JSON that `vn notes` needs, fetches Teams transcripts where the tenant allows it, runs `vn today`, then reads the notes and tells you what was decided and who owns what.

It also knows how to read these transcripts honestly — it won't attribute a line to a named person when the source is mic audio with no speaker labels, and it flags a one-sided call rather than summarizing half a conversation as the whole thing.

## Configuration

Everything lives in `~/.voicenotes.conf`:

| Setting | Default | Notes |
|---|---|---|
| `VN_DEVICE_NAME` | *(system default)* | Matched by name, resolved at each start, so USB reordering can't break it |
| `VN_START_HOUR` / `VN_END_HOUR` | 8 / 17 | |
| `VN_WEEKDAYS` | `1 2 3 4 5` | 1 = Monday |
| `VN_SEGMENT_SECONDS` | 300 | Shorter = less lost to a crash |
| `VN_SILENCE_FLOOR` | -45 | Peak dBFS below which a chunk is skipped |
| `VN_KEEP_AUDIO_DAYS` | 7 | Opus archives expire after this |
| `VN_KEEP_TRANSCRIPT_DAYS` | 90 | |
| `VN_PROMPT` | — | Domain vocabulary to bias transcription |

## Calendar

`vn notes` reads `~/VoiceNotes/calendar/YYYY-MM-DD.json`. Populating it needs access to your calendar, which a shell script doesn't have — see [docs/calendar.md](docs/calendar.md).

Without a calendar file you still get transcripts; they just land in one undifferentiated bucket.

## Teams transcripts take priority

Where a Teams transcript exists, it is used instead of the microphone transcript — it has speaker names and doesn't depend on what your headphones do. Drop it at `~/VoiceNotes/teams/<date>/<HHMM>-<slug>.txt` and the note picks it up, folding the mic version into a collapsed block beneath.

Reaching them through the Graph API needs a tenant setting that Microsoft now defaults to **off**. See [docs/teams.md](docs/teams.md) for the exact thing to ask an admin for.

The recorder keeps running either way — Teams only covers transcribed Teams meetings, not in-person conversations, phone calls, or desk work.

## Known limits

**No speaker labels from the microphone.** Whisper transcribes, it doesn't diarize. A 1:1 is usually readable from context; a six-person call reads as a wall of text. Fixing it needs a diarization model or a source that already carries names, like Teams transcripts.

**The microphone only hears the room.** If you wear headphones, the far end of a call never reaches the mic and you capture half the conversation. Test yours before trusting it:

```bash
vn start 20   # then talk, and play something through your speakers
vn today
```

If the played audio isn't in the transcript, you need either your meeting platform's own transcription or a loopback device such as BlackHole.

**Disk.** Roughly 1 GB per recorded day before compression. `vn purge` runs nightly once scheduled; Opus archives are about 10 MB/hour.

**Accuracy degrades with distance.** Close speech into a decent mic transcribes well. Someone across the room does not.

## Before you deploy this

Read [CONSENT.md](CONSENT.md). This tool records people. That is a legal and cultural question before it is a technical one.

## Layout

```
bin/vn                    CLI
bin/vn-install-schedule   launchd installer (kept separate and explicit)
lib/record.sh             segmented ffmpeg capture
lib/transcribe.sh         silence gate + Whisper
lib/wallclock.py          whisper offsets → clock time
lib/make-notes.py         calendar slicing
lib/purge.sh              compression + retention
```
