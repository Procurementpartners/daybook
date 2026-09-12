# Daybook configuration — copy to ~/.daybook.conf and edit.

# Where recordings, transcripts and notes are stored.
DBK_ROOT="$HOME/Daybook"

# Input device matched by NAME (indexes shift when USB devices are replugged).
# Run `daybook devices` to list options. Leave empty to use the system default input.
DBK_DEVICE_NAME=""

# Workday window, 24h local time.
DBK_START_HOUR=8
DBK_END_HOUR=17

# Days of week to record: 1=Mon .. 7=Sun
DBK_WEEKDAYS="1 2 3 4 5"

# Segment length in seconds. Shorter = more crash-safe, slightly more overhead.
DBK_SEGMENT_SECONDS=300

# Whisper model path and language.
DBK_MODEL="$DBK_ROOT/models/ggml-large-v3-turbo.bin"
DBK_LANG="en"

# Segments quieter than this (dBFS peak) are treated as empty and skipped.
DBK_SILENCE_FLOOR=-45

# Retention. Audio is compressed to Opus after transcription, then deleted.
DBK_KEEP_AUDIO_DAYS=7
DBK_KEEP_TRANSCRIPT_DAYS=90

# Domain vocabulary to bias transcription (names, acronyms, product terms).
DBK_PROMPT="GPO, vendor, supplier, ROI, SKU, punchout, requisition, Jira, API"

# Weekend recording. Days listed here use the weekend window instead of the
# weekday one. Leave DBK_WEEKEND_DAYS empty to disable weekend recording.
DBK_WEEKEND_DAYS="6 7"
DBK_WEEKEND_START_HOUR=9
DBK_WEEKEND_END_HOUR=21
