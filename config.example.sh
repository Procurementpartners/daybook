# VoiceNotes configuration — copy to ~/.voicenotes.conf and edit.

# Where recordings, transcripts and notes are stored.
VN_ROOT="$HOME/VoiceNotes"

# Input device matched by NAME (indexes shift when USB devices are replugged).
# Run `vn devices` to list options. Leave empty to use the system default input.
VN_DEVICE_NAME=""

# Workday window, 24h local time.
VN_START_HOUR=8
VN_END_HOUR=17

# Days of week to record: 1=Mon .. 7=Sun
VN_WEEKDAYS="1 2 3 4 5"

# Segment length in seconds. Shorter = more crash-safe, slightly more overhead.
VN_SEGMENT_SECONDS=300

# Whisper model path and language.
VN_MODEL="$VN_ROOT/models/ggml-large-v3-turbo.bin"
VN_LANG="en"

# Segments quieter than this (dBFS peak) are treated as empty and skipped.
VN_SILENCE_FLOOR=-45

# Retention. Audio is compressed to Opus after transcription, then deleted.
VN_KEEP_AUDIO_DAYS=7
VN_KEEP_TRANSCRIPT_DAYS=90

# Domain vocabulary to bias transcription (names, acronyms, product terms).
VN_PROMPT="GPO, vendor, supplier, ROI, SKU, punchout, requisition, Jira, API"

# Weekend recording. Days listed here use the weekend window instead of the
# weekday one. Leave VN_WEEKEND_DAYS empty to disable weekend recording.
VN_WEEKEND_DAYS="6 7"
VN_WEEKEND_START_HOUR=9
VN_WEEKEND_END_HOUR=21
