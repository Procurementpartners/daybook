# Using Teams transcripts instead of the microphone

Where a Microsoft Teams transcript exists, it beats the local recording on every axis that matters: speaker names, no headphone problem, and the meeting announced itself to participants. Daybook prefers it automatically.

## How the preference works

When building notes for an event, `make-notes.py` looks for:

```
~/Daybook/teams/<YYYY-MM-DD>/<HHMM>-<subject-slug>.txt
```

`HHMM` is the event's **local** start time and the slug is its subject lowercased with non-word characters stripped — the same slug used for the note filename. If that file exists and is non-empty, it becomes the note's transcript and the mic version is folded into a collapsed `<details>` block underneath. If it doesn't exist, the mic transcript is used directly.

The day's index marks which source won, so you can see at a glance which meetings have proper speaker attribution:

```
- `10:00` [Vendor Decision](05-vendor-decision.md) — **Teams transcript**
- `11:00` [Josh - Gaurav 1:1](06-josh-gaurav-11.md) — 42 lines (mic)
```

Nothing else changes. The recorder keeps running regardless — the Teams transcript only affects which text lands in the note.

## Getting the transcripts

### The blocker

Microsoft added a tenant-level control over Graph API access to Teams transcripts, enforced from late July 2026, and **it defaults to off**. With it off, every transcript request returns:

```
403 Forbidden — GraphAccessToTranscriptsDisabled
```

This is independent of your own permissions. An account holding `OnlineMeetingTranscript.Read.All` still gets 403. There is no workaround on the request side.

### What to ask your admin for

> Please enable Microsoft Graph API access to Teams meeting transcripts for the tenant:
> Teams Admin Center → Meetings → Meeting settings → **Transcript API access** → turn **Microsoft Graph access** to On.
>
> Equivalently, in Teams PowerShell 7.9.0 or later:
> `Set-CsTeamsMeetingConfiguration -EnableGraphTranscriptAccess $true`

This is a tenant-wide setting and it governs read access for every app, so it is a legitimate thing for an admin to think about before flipping. It does not itself cause meetings to be transcribed — that stays a per-meeting and per-policy decision.

### Once it's enabled

A calendar event read through Graph carries a `meetingTranscriptUrl` field. Pass it verbatim to a resource read and you get the transcript back with speaker names. In Claude Code with a Microsoft connector, this works:

> For each of today's Teams meetings, fetch the transcript and save it to
> `~/Daybook/teams/<date>/<HHMM>-<slug>.txt` using the Daybook naming convention.

A scheduled morning task can do the same thing unattended.

### Without the tenant setting

Teams still writes transcripts to OneDrive or SharePoint when a meeting is recorded or transcribed, as a `.docx` beside the recording. Those are readable with `Files.Read.All` if they're shared with you — but in practice they live in each organizer's personal OneDrive and are not shared, so this only covers meetings you organised or where someone deliberately filed the transcript somewhere shared.

If that applies to you, save the transcript text into the path above and the preference logic picks it up with no further work.

## Why keep recording at all

Teams transcripts only cover Teams meetings that were actually transcribed. They don't cover in-person conversations, phone calls, the hallway follow-up, or you thinking out loud at your desk — which is most of what the microphone is uniquely good for. Running both means the Teams transcript wins where it exists and the mic covers everything else.
