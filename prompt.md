You are booking Berlin office rooms on a user (`YOUR EMAIL`) Google Calendar
. He is physically in the Berlin office today.

Use only these tools: `mcp\_\_bolt-pint\_\_get\_events`, `mcp\_\_bolt-pint\_\_query\_freebusy`,
`mcp\_\_bolt-pint\_\_manage\_event`. Do not use any other tool. Do not ask questions —
work autonomously and finish with the report described at the end.

## Context

* Now: `\_\_NOW\_\_` (timezone `\_\_TZ\_\_`)
* End of working day: `\_\_END\_OF\_DAY\_\_`
* Mode: `\_\_MODE\_\_`
* Rooms, in the order they must be tried:

```json
\_\_ROOMS\_\_
```

* Colleagues who sit in the Berlin office:

```
\_\_BERLIN\_\_
```

## Step 1 — list candidate meetings

Call `get\_events` on `primary` with `time\_min` = now, `time\_max` = end of working day,
`detailed=true`, `max\_results=50`.

Discard an event if **any** of these hold:

1. Its `Location` already contains a Berlin room — anything matching `Berlin-`,
on any floor. He already has somewhere to sit. (A room that declined is dropped
from `Location`, so this correctly re-tries rooms that said no.)
2. YOUR\_NAME's own response is `declined`.
3. It is an all-day event, or its event type is `outOfOffice`, `workingLocation`
or `focusTime`.
4. YOUR\_NAME is the only human attendee **and** there is no meeting link — that is
a personal block, not a meeting.
5. Its title starts with `Room for "` — that is already a room-booking event.
6. A separate event titled `Room for "<that event's title>"` already exists in the
same time slot (check the events you listed). This keeps the script idempotent
across reboots.
7. Its title contains `all hands` or `all-hands`, case-insensitive — those are
large broadcasts he watches from his desk, no room needed.
8. It is shorter than 20 minutes (end minus start `< 20 min`) — those are
reminders, not meetings.

Then resolve conflicts: if two or more surviving events overlap in time and
YOUR\_NAME has `accepted` at least one of them, discard the overlapping ones he has
**not** accepted (`tentative` or `needsAction`) — he will be in the accepted meeting,
so a room for the others would sit empty. If none of the overlapping events is
accepted, keep them all; he has not decided yet and either room may be needed.

Everything left is a candidate.

## Step 2 — pick the room class

For each candidate, look at the human attendees other than YOUR\_NAME (ignore any
address ending in `@resource.calendar.google.com`).

* At least one of them is in the Berlin list above → he needs a **meeting room**.
* Otherwise everyone else is remote, he will be alone on the call → **focus room**.

An attendee who has declined does not count towards the Berlin check.

## Step 3 — find a free room

For each candidate, call `query\_freebusy` with `calendar\_ids` = every room ID of the
chosen class, `time\_min` = event start, `time\_max` = event end. Take the first room
in list order that is free for the whole slot. Batch this efficiently: one
`query\_freebusy` call per candidate event.

If every room of that class is busy, do **not** fall back to the other class —
record the event under "Not booked" with the reason "all <class> rooms busy".

## Step 4 — book it

If Mode is `DRY RUN`: make no `manage\_event` calls at all. Still list what you would
have booked under `BOOKED`, tagged `(dry run)`, and still count it in `booked=`.
Do not invent an extra section for it.

Otherwise, for each candidate with a free room:

**If YOUR\_NAME is the organizer** — call `manage\_event` with `action="update"`,
the event's `event\_id`, `send\_updates="none"`, and `attendees` set to **the complete
existing attendee list plus the new room ID**.

> This is the one dangerous step in this script. `attendees` replaces the whole
> list, so an incomplete list silently uninvites people. Copy every address from
> the event's `Attendees` line, add the room, and pass all of them. Never drop an
> attendee. After the update, re-read the event with `get\_events` using its
> `event\_id` and confirm the attendee count went \*\*up by exactly one\*\* and that
> every original address is still present. If it did not, say so loudly under
> "Failed" — including the full original attendee list so the damage can be undone
> by hand.

For a recurring instance, update the instance (the ID you were given), not the series.

**If YOUR\_NAME is not the organizer** — do not touch their event. Instead call
`manage\_event` with `action="create"`:

* `summary`: `Room for "<original event title>"`
* `start\_time` / `end\_time` / `timezone`: same as the original event
* `attendees`: the room ID only
* `description`: `Room booked automatically for the original event.` plus the
original event's link
* `send\_updates="none"`, `transparency="transparent"`

Also try this fallback if a direct update fails with a permission error.

## Report

Your entire final message must be the report below and nothing else — no preamble,
no commentary, no code fence around it. It goes straight into a log file. Be
specific: every meeting you touched or could not handle must appear.

```
BOOKED
- 09:30–10:00  Debrief  →  14.5 Focus Room  (updated event)
- 14:00–14:30  Pricing sync  →  14.16 Meeting room  (companion event, not organizer)

NOT BOOKED
- 11:00–12:00  John / Alex  —  all focus rooms busy

FAILED
- 16:00–16:30  Bad orders weekly  —  update rejected: forbidden, companion event also failed (403)

SKIPPED
- 13:00–13:30  Lunch  —  no other attendees
- 15:00–16:00  Delivery All Hands  —  all-hands
- 17:00–17:10  Standup reminder  —  shorter than 20 min
- 14:00–14:30  Hiring sync  —  not accepted, conflicts with Pricing sync

SUMMARY: booked=2 not\_booked=1 failed=1 skipped=4
```

Use `HH:MM` local times. If a section is empty write `- none`. The `SUMMARY:` line
must be the last line of your output.

