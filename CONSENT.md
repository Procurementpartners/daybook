# Before you run this

This tool records audio in a workplace for nine hours a day. That is a legal and cultural question before it is a technical one, and the code cannot answer it for you.

## Recording law is not uniform

In the United States, wiretap and eavesdropping statutes split roughly two ways:

- **One-party consent** — you may record a conversation you are part of.
- **All-party consent** — every participant must consent. California, Florida, Illinois, Maryland, Massachusetts, Montana, Nevada, New Hampshire, Pennsylvania and Washington are commonly cited here, and the details differ in each.

A call spanning two states can be governed by the stricter one. Federal law sets a floor, not a ceiling. If you record colleagues, customers or candidates without consent, the exposure is not hypothetical — several of these statutes carry criminal penalties and a private right of action.

This is a description of the landscape, not legal advice. For anything beyond your own voice, ask someone qualified.

## Your employer's rules come first

Most organisations have policy on recording meetings, handling customer data, and where that data may be stored. A tool that quietly writes a transcript of every meeting to an unencrypted folder on a laptop will often conflict with those rules even where the law permits it. Ask before deploying, not after.

## What this tool actually captures

- **Everything the microphone hears**, for the whole configured window — including the parts of your day that are not meetings, and conversations of people near you who never opted in.
- **Only your side of remote calls**, if you wear headphones. Whether that helps or hurts depends on which risk you care about.
- **Nothing off-device.** Whisper runs locally. No audio or transcript is uploaded anywhere by this tool.
- **Audio is kept 3 days by default**, compressed, then deleted; transcripts persist longer. A recording identifies a speaker in a way a transcript does not, so if you don't need to re-transcribe, set `DBK_KEEP_AUDIO_DAYS=0` and no voices are kept at all.

## What it does not do

- It does not announce itself. Unlike Teams or Zoom recording, participants get no indicator.
- It does not encrypt anything beyond your disk's own encryption. Enable FileVault.
- It does not redact. Salaries, health details, anything said near your desk lands in plain text.

## If you distribute the plugin

The Claude agent can be listed in your organization's plugin catalog. Set it to **Available** only — never "Installed by default" or "Required".

The agent records nothing by itself, so this is not a safety control in the strict sense. It is a question of what you put in front of people. A recording tool that arrives unrequested in someone's environment reframes it as sanctioned and expected, which is exactly the assumption that gets consent skipped. Let people find it.

## Practical guidance

If you deploy this beyond your own machine:

1. **Tell people.** A standing note in your meeting invitations costs nothing and resolves most of this.
2. **Prefer the platform's own transcription for meetings.** Teams and Zoom announce themselves and attribute speakers by name. This tool is better aimed at the parts of your day no meeting platform covers.
3. **Keep retention short.** Audio defaults to 3 days and transcripts to 90. Raising either needs a reason you'd be comfortable stating out loud; lowering audio to 0 is always defensible.
4. **Turn it off for sensitive conversations.** `daybook stop` exists for this. HR matters, personnel discussions, anything under legal privilege.
5. **Enable FileVault**, and don't sync `~/Daybook` to a cloud drive without thinking it through.

## The honest summary

For recording yourself — notes, thinking out loud, your own half of a call — this is straightforward and useful.

For recording other people, the technology is the easy part. Get agreement first.
