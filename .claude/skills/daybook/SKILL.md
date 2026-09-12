---
name: daybook
description: Turn the day's recorded audio into meeting notes. Use when the user asks what happened today, wants their meeting notes or action items, asks to catch up on a meeting they missed or half-remember, wants to know what was decided or who owns what, or mentions Daybook, "my recordings", "my transcripts", or the `daybook` command. Also use to start or stop recording, check capture status, or diagnose the recorder.
---

# Daybook

Daybook records the user's workday, transcribes it locally with Whisper, and slices it into per-meeting notes using their calendar. The `daybook` CLI does capture and transcription. You do the parts it cannot: fetching the calendar, fetching Teams transcripts, and telling the user what actually happened.

## Before anything else

Run `daybook status`. It tells you whether recording is live, how many segments exist, and whether the schedule is on. If `daybook` is not found, the tool isn't installed — point at `install.sh` in the repo rather than trying to work around it.

## The daily flow

When the user asks about their day, their meetings, or their notes, do all four steps. Don't stop after step 3 and hand them a transcript — the summary is the point.

### 1. Fetch the calendar

Notes have no meeting structure without this. Check whether `~/Daybook/calendar/<YYYY-MM-DD>.json` already exists; if it does and covers the day, skip ahead.

Otherwise pull the day's events from the user's calendar connector (Outlook or Google) and write that file:

```json
{
  "date": "2026-09-11",
  "times_are": "UTC",
  "events": [
    {"subject": "...", "start": "2026-09-11T14:00:00Z", "end": "2026-09-11T15:00:00Z",
     "organizer": "...", "attendees": ["..."], "location": "..."}
  ]
}
```

**Timezone is the one thing that silently ruins everything.** Outlook returns `{dateTime, timeZone}` pairs. Write the times with a `Z` suffix only if they are genuinely UTC. `make-notes.py` converts to local — so if events land an hour off in the notes, this is why. Sanity-check one known meeting time against what the user remembers before trusting a day's output.

Skip all-day events and anything showing as `free` — they aren't meetings and they swallow the whole day's transcript.

### 2. Fetch Teams transcripts where they exist

A Teams transcript beats the microphone on every axis: real speaker names, unaffected by headphones, and the meeting announced itself. Prefer it whenever available.

Read a calendar event through Graph and use its `meetingTranscriptUrl` field verbatim with a resource read. Save what comes back to:

```
~/Daybook/teams/<YYYY-MM-DD>/<HHMM>-<subject-slug>.txt
```

`HHMM` is the event's **local** start time; the slug is the subject lowercased with non-word characters stripped and spaces turned to hyphens. `make-notes.py` picks these up automatically and folds the mic version underneath.

If this returns `GraphAccessToTranscriptsDisabled`, the tenant has Graph transcript access turned off — see `docs/teams.md`. Say so once and move on with the mic transcript. Don't retry in a loop and don't treat it as a failure of the whole task.

### 3. Build the notes

```bash
daybook today
```

That transcribes any pending segments, rebuilds the notes, and prints the index.

### 4. Summarize — this is the actual value

Read the per-meeting notes in `~/Daybook/notes/<day>/` and give the user, per meeting that has content:

- **What was decided** — concretely, not "the team discussed options"
- **Action items with an owner**, quoting the line that assigns it
- **Open questions** left unresolved
- **Anything that contradicts** a decision recorded earlier in the week, if you have reason to look

Then a short list across the whole day of what needs the user's attention.

## Reading the transcripts honestly

These are machine transcripts of far-field audio. They are not verbatim minutes, and treating them as such will mislead the user.

- **Attribute nothing to a named person** unless the source is a Teams transcript. The mic transcript has no speaker labels. Write "someone raised" or "it was suggested", never "Jim said", when working from mic audio.
- **Quote exactly** when it matters — a decision, a commitment, a number. Paraphrase invents precision that isn't there.
- **Flag low confidence.** Garbled passages, names, and acronyms are where Whisper fails. If a line looks mangled, say so rather than guessing what it meant.
- **Absence is not evidence.** "No audio captured" means the recorder wasn't running or the room was quiet — not that the meeting didn't happen or nothing was said.
- **Expect one-sided calls.** If the user wears headphones, remote participants never reach the mic. A transcript that reads as a monologue is usually this, not a quiet meeting. Say so instead of summarizing half a conversation as if it were the whole.

## Other requests

| The user wants | Do this |
|---|---|
| Start/stop recording | `daybook start [secs]` / `daybook stop` |
| Read the raw transcript | `daybook read [day]` |
| One meeting | `daybook note <name>` |
| Search across days | `grep -ri "<term>" ~/Daybook/transcripts/` |
| Change hours, device, retention | Edit `~/.daybook.conf`, then `daybook schedule on` |
| Different working hours or timezone | All settings are local time on their machine. Set `DBK_START_HOUR`/`DBK_START_MINUTE` and `DBK_END_HOUR`/`DBK_END_MINUTE`, then `daybook schedule on`. An end at or before the start is an overnight window. `daybook doctor` shows the resolved window and timezone. |
| Something is broken | `daybook doctor` first — it checks deps, mic permission, device, disk |
| Free up space | `daybook purge` |

## Privacy

Transcripts are unencrypted plain text containing whatever was said near the user's desk — salaries, health details, personnel matters. Never send transcript content anywhere outside the machine (email, Slack, a ticket, a published page) unless the user explicitly asks for that specific content to go to that specific place. Summarizing into the conversation is fine; exfiltrating is not.

If the user asks you to share meeting content with someone who wasn't in the meeting, say what you're about to send and confirm first.
