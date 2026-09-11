# Supplying calendar data

`vn notes` reads one JSON file per day:

```
~/VoiceNotes/calendar/YYYY-MM-DD.json
```

A shell script can't reach Outlook or Google Calendar on its own, so this file has to be written by something that can. Three options, easiest first.

## Format

```json
{
  "date": "2026-09-11",
  "times_are": "UTC",
  "events": [
    {
      "subject": "Vendor Decision",
      "start": "2026-09-11T14:00:00Z",
      "end":   "2026-09-11T15:00:00Z",
      "organizer": "someone@example.com",
      "attendees": ["a@example.com", "b@example.com"],
      "location": "Microsoft Teams Meeting"
    }
  ]
}
```

Times may be UTC (`Z` suffix) or carry an explicit offset — `make-notes.py` converts to local either way. Getting this wrong is the single most likely cause of notes landing on the wrong meeting, so check one known event before trusting a day's output.

## Option 1 — Claude with a calendar connector

If you use Claude Code with an Outlook or Google connector, ask it to write tomorrow's file. A scheduled task each morning keeps it current with no effort:

> Fetch my calendar events for today and write them to
> `~/VoiceNotes/calendar/YYYY-MM-DD.json` in the VoiceNotes format.

This is how the tool was built and is the least work to maintain.

## Option 2 — Microsoft Graph

For a fully unattended setup, register an app with `Calendars.Read`, then fetch `/me/calendarView` for the day and map the fields. `start`/`end` come back as `{dateTime, timeZone}` pairs — pass the timezone through rather than assuming UTC.

## Option 3 — icalBuddy

For calendars that live in the macOS Calendar app:

```bash
brew install ical-buddy
icalBuddy -npn -nc -b '' -ic "Work" -tf "%H:%M" eventsToday
```

Then reshape into the JSON above. Note this only sees calendars synced into Calendar.app — an Exchange account configured only in Outlook won't appear.

## No calendar at all

`vn notes` still works. Every transcript line lands in `unscheduled.md`, timestamped. You lose the per-meeting split, nothing else.
