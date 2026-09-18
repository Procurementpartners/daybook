# Automating the daily summary

Daybook records and transcribes on its own. Turning that into a summary that arrives without you asking needs one more piece: a scheduled Claude task, because the calendar fetch and the summarising both need a model and a connector, which a shell script has neither of.

## Two tasks, not one

**Calendar fetch, 18:00.** Pulls the day's final calendar and rebuilds the notes.
Deliberately at the end of the day: meetings get added, moved and cancelled as the
day goes on, so a calendar pulled in the morning is wrong by the evening. It
overwrites any earlier file rather than skipping.

**Summary, 18:30.** Transcribes anything outstanding, writes a summary for every
meeting that has content, rebuilds the viewer, and sends the day-level roll-up.

Splitting them matters: the summary task depends on the notes being correct, and
the notes depend on a calendar that reflects what actually happened.

## Where summaries go

The summary task writes one file per meeting to:

```
~/Daybook/summaries/<date>/<same filename as the note>.md
```

That pairing is how `daybook web` renders a summary above its meeting's transcript.
They live outside `notes/` because `daybook notes` rewrites those files on every
build — anything written into a note would be destroyed on the next run.

`daybook web` itself does **not** summarise. It is a static generator: it renders
summaries that already exist. Writing them needs a model, so it happens in the
18:30 task or whenever you ask Claude.

## Setting it up

Ask Claude, in a session where your connectors are available:

> Create a scheduled task that runs weekdays at 17:30. It should run `daybook transcribe`, fetch my calendar into `~/Daybook/calendar/<date>.json`, run `daybook notes`, read the notes, and DM me the summary and my todos on Slack.

Each run starts with no memory of the conversation that created it, so the task prompt has to be self-contained. Worth putting in it:

- **Summary only, never raw transcript.** Sending a summary somewhere is a deliberate, bounded act. Pasting a day's transcript into a chat app is not — it contains everything the microphone heard, including things that have nothing to do with work.
- **No speaker attribution from mic audio.** There are no speaker labels. "Someone raised", not "Jim said".
- **Ignore repeated identical lines.** That is Whisper hallucinating on silence, not something anyone said.
- **A meeting with few lines was genuinely quiet.** Report that honestly rather than padding it.
- **Verify one known meeting time** before trusting the calendar conversion. A timezone error silently files notes under the wrong meeting.

## The failure you will actually hit

**A scheduled run that needs a permission does not fail. It stalls forever.**

No error, no output, no notification — the run sits at "running" waiting for a prompt that nobody is at the keyboard to answer. The first time this happens you will conclude the scheduler is broken. It isn't; the run started on time and stopped six seconds later.

`install.sh` adds narrow rules to `~/.claude/settings.json` to cover the Daybook commands themselves:

```json
"permissions": {
  "allow": [
    "Bash(daybook:*)",
    "Read(//<home>/Daybook/**)",
    "Write(//<home>/Daybook/calendar/**)"
  ]
}
```

That is deliberately not a blanket allow. Connectors — Outlook, Slack — are **not** pre-authorised, because a global rule letting any session send messages on your behalf is a much larger grant than this feature justifies.

So after creating the task, **click "Run now" once and stay watching.** Approve the connector prompts as they appear. Those approvals are stored on the task and reused by every later run. One minute of attention buys you unattended operation from then on.

## Other things worth knowing

**Tasks only run while the app is open.** If the machine is closed at the scheduled time, the run happens at next launch — so an evening summary may arrive the following morning.

**The schedule has jitter.** A task set for 17:30 may fire at 17:38. The cron expression is exact; the scheduler adds a random offset. Don't conclude it failed because nothing happened at 17:30:00.

**Test at a time you are present for.** Create a one-off run a few minutes out, watch it, then let the recurring one take over. Testing a 17:30 task by waiting until 17:30 tomorrow wastes a day per iteration and you learn nothing if it stalls silently.
