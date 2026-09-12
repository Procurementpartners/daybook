# Daybook configuration — copy to ~/.daybook.conf and edit.

# Where recordings, transcripts and notes are stored.
DBK_ROOT="$HOME/Daybook"

# Input device matched by NAME (indexes shift when USB devices are replugged).
# Run `daybook devices` to list options. Leave empty to use the system default input.
DBK_DEVICE_NAME=""

# Workday window, in YOUR machine's local time. Everything Daybook does is
# local-time based, so a colleague in another timezone just sets their own
# hours — no offsets, no UTC conversion anywhere.
# An end earlier than the start means an overnight window (e.g. 20:00 -> 04:00).
DBK_START_HOUR=8
DBK_START_MINUTE=0
DBK_END_HOUR=17
DBK_END_MINUTE=0

# Days of week to record: 1=Mon .. 7=Sun
DBK_WEEKDAYS="1 2 3 4 5"

# Segment length in seconds. Shorter = more crash-safe, slightly more overhead.
DBK_SEGMENT_SECONDS=300

# Whisper model path and language.
DBK_MODEL="$DBK_ROOT/models/ggml-large-v3-turbo.bin"
DBK_LANG="en"

# Segments quieter than this (dBFS peak) are treated as empty and skipped.
DBK_SILENCE_FLOOR=-45

# Retention.
# >0 = keep a compressed Opus archive for this many days (default: 3).
#      Three days is enough to re-transcribe after improving DBK_PROMPT or
#      to check what was actually said, without keeping voices around long.
#  0  = delete each segment as soon as its transcript is written. Most private,
#      but irreversible: a garbled passage can never be re-transcribed.
DBK_KEEP_AUDIO_DAYS=3
DBK_KEEP_TRANSCRIPT_DAYS=90

# Domain vocabulary to bias transcription (names, acronyms, product terms).
DBK_PROMPT="GPO, vendor, supplier, ROI, SKU, punchout, requisition, Jira, API"

# Weekend recording. Off by default — nothing is scheduled at the weekend.
# To enable it, add the days to BOTH lists, e.g.
#   DBK_WEEKDAYS="1 2 3 4 5 6 7"
#   DBK_WEEKEND_DAYS="6 7"
# Days in DBK_WEEKEND_DAYS use the weekend window below instead of the
# weekday one, so a manual run at the weekend also honours these hours.
DBK_WEEKEND_DAYS=""
DBK_WEEKEND_START_HOUR=9
DBK_WEEKEND_END_HOUR=21
