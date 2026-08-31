#!/bin/zsh
# Morning setup: VS Code + Slack + Tunnelblick + MCP auth, then book Berlin rooms if in office.
# Runs at login via ~/Library/LaunchAgents/eu.bolt.morning.plist.
#
# Every laptop start runs the whole thing. Re-running is safe: `open -a` on an
# already-running app is a no-op, and the booking step skips meetings that already
# have a Berlin room or an existing `Room for "..."` event.
#
#   morning.sh                   full run
#   morning.sh --rooms-only      skip app launching, just do the calendar step
#   morning.sh --learn-network   add this network's SSID + gateway MAC to config.sh

emulate -L zsh
setopt pipe_fail

HERE=${0:A:h}
source "$HERE/config.sh"

LOG_DIR="$HERE/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/$(date +%Y-%m-%d).log"

ROOMS_ONLY=0 LEARN_NETWORK=0
for arg in "$@"; do
  case $arg in
    --rooms-only)                 ROOMS_ONLY=1 ;;
    --learn-network|--learn-ssid) LEARN_NETWORK=1 ;;
    *) print -u2 "unknown argument: $arg"; exit 2 ;;
  esac
done

log()  { print -r -- "$(date '+%H:%M:%S')  $*" | tee -a "$LOG" }
fail() { log "ERROR: $*"; PROBLEMS+=("$*") }

notify() {
  local title=$1 body=$2
  osascript >/dev/null 2>&1 <<OSA
display notification "${body//\"/\\\"}" with title "${title//\"/\\\"}"
OSA
}

# Current Wi-Fi SSID, or empty if it cannot be determined. Needs Location
# Services permission on macOS 14+; networksetup is a fallback that stopped
# working on macOS 26.
current_ssid() {
  local s
  s=$(ipconfig getsummary en0 2>/dev/null | awk -F' SSID : ' '/ SSID : /{print $2; exit}')
  [[ -z $s ]] && s=$(networksetup -getairportnetwork en0 2>/dev/null \
                     | sed -n 's/^Current Wi-Fi Network: //p')
  print -r -- "${s## }"
}

# 0:9:f:9:1:3 -> 00:09:0f:09:01:03, so config entries compare reliably.
norm_mac() {
  local out="" o
  for o in ${(s.:.)1}; do
    (( ${#o} == 1 )) && o="0$o"
    out+="${out:+:}$o"
  done
  print -r -- ${out:l}
}

# MAC address of the default gateway. No special permission needed.
gateway_mac() {
  local gw mac
  gw=$(route -n get default 2>/dev/null | awk '/gateway/{print $2}')
  [[ -z $gw ]] && return
  mac=$(arp -n "$gw" 2>/dev/null | awk '{print $4}')
  [[ $mac == *:* ]] || return
  norm_mac "$mac"
}

if (( LEARN_NETWORK )); then
  ssid=$(current_ssid)
  mac=$(gateway_mac)

  if [[ -n $ssid ]]; then
    if (( ${OFFICE_SSIDS[(Ie)$ssid]} )); then
      print "SSID \"$ssid\" is already in OFFICE_SSIDS."
    else
      print "Adding SSID \"$ssid\" to OFFICE_SSIDS."
      /usr/bin/sed -i '' "s|^OFFICE_SSIDS=(|OFFICE_SSIDS=(\\
  \"$ssid\"|" "$HERE/config.sh"
    fi
  else
    print "Could not read the Wi-Fi network — check Location Services permission in"
    print "System Settings > Privacy & Security. The gateway MAC below covers for it."
  fi

  if [[ -n $mac ]]; then
    if (( ${OFFICE_GATEWAY_MACS[(Ie)$mac]} )); then
      print "Gateway MAC $mac is already in OFFICE_GATEWAY_MACS."
    else
      print "Adding gateway MAC $mac to OFFICE_GATEWAY_MACS."
      /usr/bin/sed -i '' "s|^OFFICE_GATEWAY_MACS=(|OFFICE_GATEWAY_MACS=(\\
  \"$mac\"|" "$HERE/config.sh"
    fi
  else
    print "Could not read the default gateway MAC — are you connected to a network?"
  fi

  [[ -z $ssid && -z $mac ]] && exit 1
  exit 0
fi

PROBLEMS=()
log "=== morning run start ==="

# ---------------------------------------------------------------- apps

if (( ! ROOMS_ONLY )); then
  if [[ -d $DS_FOLDER ]]; then
    open -a "Visual Studio Code" "$DS_FOLDER" && log "VS Code opened on $DS_FOLDER" \
      || fail "could not open VS Code on $DS_FOLDER"
  else
    fail "DS_FOLDER does not exist: $DS_FOLDER"
  fi

  open -a Slack && log "Slack launched" || fail "could not launch Slack"

  open -a Tunnelblick && log "Tunnelblick launched" || fail "could not launch Tunnelblick"
  for i in {1..15}; do pgrep -qx Tunnelblick && break; sleep 1; done

  if pgrep -qx Tunnelblick; then
    osascript -e 'tell application "Tunnelblick" to connect all' >/dev/null 2>&1 \
      && log "Tunnelblick: connect all sent" || fail "Tunnelblick connect failed"
    # Tunnelblick may put up an admin or credentials prompt; give it time,
    # then report whatever state it settled in.
    state=""
    for i in {1..30}; do
      state=$(osascript -e 'tell application "Tunnelblick" to get state of configuration 1' 2>/dev/null)
      [[ $state == CONNECTED ]] && break
      sleep 2
    done
    if [[ $state == CONNECTED ]]; then
      log "VPN connected"
    else
      fail "VPN not connected (state: ${state:-unknown}) — it may be waiting for your password"
    fi
  else
    fail "Tunnelblick did not start"
  fi
fi

# ---------------------------------------------------------------- network

log "waiting for internet"
online=0
for i in {1..30}; do
  if curl -sf --max-time 3 -o /dev/null https://www.google.com/generate_204; then
    online=1; break
  fi
  sleep 2
done
if (( ! online )); then
  fail "no internet after 60s — skipping MCP auth and room booking"
  notify "Morning setup" "No internet. Rooms not booked. See today's log."
  exit 1
fi
log "online"

# ---------------------------------------------------------------- MCP auth
# The HTTP MCP servers use OAuth, so a stale token needs a browser click. We can
# detect staleness and open the login flow, but you have to approve it.

cd "$HOME" || exit 1
mcp_status=$(claude mcp list 2>&1)

for srv in $MCP_SERVERS; do
  if print -r -- "$mcp_status" | grep -E "^${srv}:" | grep -q "Connected"; then
    log "MCP $srv: connected"
    continue
  fi

  fail "MCP $srv needs re-authentication — opening login in Terminal"
  osascript >/dev/null 2>&1 <<OSA
tell application "Terminal"
  activate
  do script "claude mcp login $srv"
end tell
OSA
  for i in {1..30}; do
    sleep 4
    if claude mcp list 2>&1 | grep -E "^${srv}:" | grep -q "Connected"; then
      log "MCP $srv: re-authenticated"
      PROBLEMS=(${PROBLEMS:#*$srv*})
      break
    fi
  done
done

# ---------------------------------------------------------------- office check

ssid=$(current_ssid)
mac=$(gateway_mac)
in_office=0

if [[ -n $ssid ]] && (( ${OFFICE_SSIDS[(Ie)$ssid]} )); then
  log "in the office (Wi-Fi: $ssid)"
  in_office=1
elif [[ -n $mac ]] && (( ${OFFICE_GATEWAY_MACS[(Ie)$mac]} )); then
  log "in the office (gateway $mac)"
  in_office=1
elif [[ -z $ssid && -z $mac ]]; then
  fail "could not identify the network — cannot tell if you are in the office, skipping room booking"
elif [[ -z $ssid ]] && (( ${#OFFICE_GATEWAY_MACS} == 0 )); then
  fail "SSID unreadable and no office gateway MAC known — run 'morning.sh --learn-network' from the office; skipping room booking"
else
  log "not in the office (Wi-Fi: ${ssid:-unknown}, gateway: ${mac:-unknown}) — skipping room booking"
fi

# ---------------------------------------------------------------- rooms

if (( in_office )); then
  # Explicit format: `date -j -f ... -Iseconds` silently ignores -Iseconds and
  # prints the human-readable form, which is not valid RFC3339 for the API.
  now=$(date '+%Y-%m-%dT%H:%M:%S%z')
  eod=$(date -j -f '%H:%M:%S' "$END_OF_DAY" '+%Y-%m-%dT%H:%M:%S%z')
  tz=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')
  if (( DRY_RUN )); then mode="DRY RUN"; else mode="LIVE"; fi

  prompt=$(< "$HERE/prompt.md")
  prompt=${prompt//__NOW__/$now}
  prompt=${prompt//__END_OF_DAY__/$eod}
  prompt=${prompt//__TZ__/$tz}
  prompt=${prompt//__MODE__/$mode}
  prompt=${prompt//__ROOMS__/$(< "$HERE/rooms.json")}
  prompt=${prompt//__BERLIN__/${(F)BERLIN_COLLEAGUES}}

  log "booking rooms ($mode, until $eod)"
  report=$(perl -e 'alarm shift; exec @ARGV' "$CLAUDE_TIMEOUT" \
    claude -p "$prompt" \
      --model "$CLAUDE_MODEL" \
      --allowedTools "mcp__bolt-pint__get_events,mcp__bolt-pint__query_freebusy,mcp__bolt-pint__manage_event" \
      --disallowedTools "Bash,Edit,Write,WebFetch,WebSearch" \
      --max-turns 60 2>&1)
  rc=$?

  print -r -- "$report" >> "$LOG"

  if (( rc != 0 )); then
    fail "room booking did not finish (exit $rc, ${CLAUDE_TIMEOUT}s limit) — see today's log"
  else
    summary=$(print -r -- "$report" | grep -E '^SUMMARY:' | tail -1)
    log "${summary:-no SUMMARY line in report}"
    bad=$(print -r -- "$report" | awk '
      /^(NOT BOOKED|FAILED)$/ {on=1; next}
      /^[A-Z ]+$/            {on=0}
      on && /^- / && !/^- none/ {print}')
    [[ -n $bad ]] && PROBLEMS+=("rooms not booked:"$'\n'"$bad")
    notify "Morning setup" "${summary:-Room booking finished}"
  fi
fi

# ---------------------------------------------------------------- wrap up

if (( ${#PROBLEMS} )); then
  log "--- ${#PROBLEMS} problem(s) ---"
  for p in $PROBLEMS; do log "  * $p"; done
  notify "Morning setup: ${#PROBLEMS} problem(s)" "Opening today's log."
  open -a "Visual Studio Code" "$LOG"
else
  log "all good"
fi

log "=== morning run end ==="
