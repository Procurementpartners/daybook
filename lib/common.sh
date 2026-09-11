# Shared helpers. Sourced by every VoiceNotes script.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

VN_CONF="${VN_CONF:-$HOME/.voicenotes.conf}"
[ -f "$VN_CONF" ] && source "$VN_CONF"

: "${VN_ROOT:=$HOME/VoiceNotes}"
: "${VN_DEVICE_NAME:=}"
: "${VN_START_HOUR:=8}"
: "${VN_END_HOUR:=17}"
: "${VN_SEGMENT_SECONDS:=300}"
: "${VN_MODEL:=$VN_ROOT/models/ggml-large-v3-turbo.bin}"
: "${VN_LANG:=en}"
: "${VN_SILENCE_FLOOR:=-45}"
: "${VN_KEEP_AUDIO_DAYS:=7}"
: "${VN_KEEP_TRANSCRIPT_DAYS:=90}"
: "${VN_PROMPT:=}"

vn_dirs(){ mkdir -p "$VN_ROOT"/{audio,transcripts,notes,calendar,logs,models,archive}; }

vn_log(){ echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Resolve the avfoundation audio device index by name, at call time.
vn_device_index(){
  local list idx
  list=$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | awk '/audio devices/,0')
  if [ -z "$VN_DEVICE_NAME" ]; then echo 0; return 0; fi
  idx=$(echo "$list" | grep -i "$VN_DEVICE_NAME" | sed -E 's/.*\[([0-9]+)\].*/\1/' | head -1)
  [ -n "$idx" ] && echo "$idx" || return 1
}

vn_peak_db(){  # $1=wav -> peak dBFS
  ffmpeg -hide_banner -i "$1" -af volumedetect -f null - 2>&1 \
    | awk -F': ' '/max_volume/{gsub(/ dB/,"",$2); print $2}'
}
