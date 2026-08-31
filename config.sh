# Settings for morning.sh — edit these, not the script.

# Folder to open in VS Code.
DS_FOLDER="$HOME/source/data-science"

# Wi-Fi networks that mean "I am in the Berlin office". Anything else (home,
# tethering, a cafe) counts as out of office and no rooms get booked.
OFFICE_SSIDS=(
  "NAME OF WLAN HERE"
)

# Second office signal: the MAC address of the default gateway. Reading the SSID
# needs Location Services permission, which a process launchd starts at login is
# often denied; reading the gateway MAC never is. Either signal matching counts
# as "in the office".
#
# Run `~/morning/morning.sh --learn-network` from the office to fill this in.
OFFICE_GATEWAY_MACS=(
  "HERE MAC OF WLAN"
)

# MCP servers to health-check (and re-authenticate) before touching the calendar.
MCP_SERVERS=(bolt-pint atlassian)

# Colleagues who sit in the Berlin office. If one of them is on a meeting,
# the meeting gets a real meeting room; otherwise you are alone on the call
# and get a focus room.
BERLIN_COLLEAGUES=(
  email_1
  email_2)

# Meetings after this local time are left alone.
END_OF_DAY="19:00:00"

# 1 = report what it would book without writing to the calendar.
# Override for a single run: DRY_RUN=1 ~/morning/morning.sh --rooms-only
DRY_RUN=${DRY_RUN:-0}

# Model used for the calendar step.
CLAUDE_MODEL="sonnet"

# Seconds to allow the calendar step before giving up.
CLAUDE_TIMEOUT=420
