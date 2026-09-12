# Shared helpers. Sourced by every Daybook script.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DBK_CONF="${DBK_CONF:-$HOME/.daybook.conf}"
[ -f "$DBK_CONF" ] && source "$DBK_CONF"

: "${DBK_ROOT:=$HOME/Daybook}"
: "${DBK_DEVICE_NAME:=}"
: "${DBK_START_HOUR:=8}"
: "${DBK_END_HOUR:=17}"
: "${DBK_SEGMENT_SECONDS:=300}"
: "${DBK_MODEL:=$DBK_ROOT/models/ggml-large-v3-turbo.bin}"
: "${DBK_LANG:=en}"
: "${DBK_SILENCE_FLOOR:=-45}"
: "${DBK_KEEP_AUDIO_DAYS:=7}"
: "${DBK_KEEP_TRANSCRIPT_DAYS:=90}"
: "${DBK_PROMPT:=}"
: "${DBK_WEEKEND_DAYS:=}"
: "${DBK_WEEKEND_START_HOUR:=$DBK_START_HOUR}"
: "${DBK_WEEKEND_END_HOUR:=$DBK_END_HOUR}"

# On a weekend day, swap in the weekend window. Done here so every script
# (record, schedule installer, status) agrees without duplicating the logic.
if [ -n "$DBK_WEEKEND_DAYS" ]; then
  _today_dow=$(date +%u)                 # 1=Mon .. 7=Sun
  case " $DBK_WEEKEND_DAYS " in
    *" $_today_dow "*)
      DBK_START_HOUR="$DBK_WEEKEND_START_HOUR"
      DBK_END_HOUR="$DBK_WEEKEND_END_HOUR"
      ;;
  esac
fi

dbk_dirs(){ mkdir -p "$DBK_ROOT"/{audio,transcripts,notes,calendar,logs,models,archive}; }

dbk_log(){ echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Resolve the avfoundation audio device index by name, at call time.
dbk_device_index(){
  local list idx
  list=$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | awk '/audio devices/,0')
  if [ -z "$DBK_DEVICE_NAME" ]; then echo 0; return 0; fi
  idx=$(echo "$list" | grep -i "$DBK_DEVICE_NAME" | sed -E 's/.*\[([0-9]+)\].*/\1/' | head -1)
  [ -n "$idx" ] && echo "$idx" || return 1
}

dbk_peak_db(){  # $1=wav -> peak dBFS
  ffmpeg -hide_banner -i "$1" -af volumedetect -f null - 2>&1 \
    | awk -F': ' '/max_volume/{gsub(/ dB/,"",$2); print $2}'
}
