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

# Databricks CLI profile (in ~/.databrickscfg) and the all-purpose cluster dbt
# runs on (the cluster id at the end of http_path in ~/.dbt/profiles.yml).
DBT_DATABRICKS_PROFILE="YOUR_DATABRICKS_PROFILE"
DBT_CLUSTER_ID="YOUR_CLUSTER_ID"

# Databricks deletes an all-purpose cluster that has stayed terminated for 30
# days. Start it once it has been terminated this many days, well before that.
DBT_CLUSTER_MAX_TERMINATED_DAYS=15

# Colleagues who sit in the Berlin office. If one of them is on a meeting,
# the meeting gets a real meeting room; otherwise you are alone on the call
# and get a focus room.
BERLIN_COLLEAGUES=(
  email_1
  email_2)

# Daily AB scorecards digest (skill: ab-scorecards-overview): builds the HTML and
# sends it to your own Slack DM. 1 = run it once per day, after room booking.
# The Slack DM is not idempotent like room booking, so it is sent once per day only
# (stamp file logs/ab-scorecards-<date>.done, written after the Slack link comes back).
AB_SCORECARDS=1
AB_MODEL="sonnet"
AB_TIMEOUT=1200

# Unattended run, so no questions. Headless Bash refuses any command that sets a
# shell variable and then uses it ("can't be checked before it runs"), which is
# what the skill's upload step does, hence the literal-URL instruction.
AB_PROMPT='Run the ab-scorecards-overview skill (invoke it with the Skill tool) with its defaults, including step 6: send the HTML to my own Slack DM. This is an unattended run: never ask questions. If a connection (AB, Google Sheets, Slack) is unavailable, stop and say which one. Bash cannot run a command that sets a shell variable, so in step 6 do not use a URL variable: POST with curl and write the upload URL literally, in single quotes, inside the curl command itself. End your answer with the absolute HTML path and the Slack file link, each on its own line.'

# Tools the digest may use. Writes are limited to the reports folder and the
# skill's personal folder; if reports_dir in ~/.config/ab-scorecards-overview/settings.json
# changes, change the first Edit path too.
AB_ALLOWED_TOOLS="Skill,Read,Edit(~/Agentic_OS/reports/**),Edit(~/.config/ab-scorecards-overview/**),Bash(python3:*),Bash(curl:*),Bash(wc:*),Bash(date:*),Bash(mkdir:*),mcp__ab-mcp__ab_test_search,mcp__ab-mcp__ab_test_get,mcp__ab-mcp__ab_scorecard_dashboards,mcp__ab-mcp__ab_scorecard_get,mcp__bolt-pint__read_sheet_values,mcp__claude_ai_Slack__slack_get_file_upload_url,mcp__claude_ai_Slack__slack_complete_file_upload,mcp__claude_ai_Slack__slack_send_message"

# Meetings after this local time are left alone.
END_OF_DAY="19:00:00"

# 1 = report what it would book without writing to the calendar.
# Override for a single run: DRY_RUN=1 ~/morning/morning.sh --rooms-only
DRY_RUN=${DRY_RUN:-0}

# Model used for the calendar step.
CLAUDE_MODEL="sonnet"

# Seconds to allow the calendar step before giving up.
CLAUDE_TIMEOUT=420
