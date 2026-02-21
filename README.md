# cal_export

Exports macOS calendar events to JSON using EventKit directly. Intended to run periodically via launchd, producing a JSON file that other processes (scripts, Flint, automation workflows) can read and query.

## Background

### Why EventKit, not icalBuddy

[icalBuddy](https://hasseg.org/icalBuddy/) is a common tool for this use case but uses the deprecated CalendarStore framework and outputs plain text requiring parsing. EventKit is Apple's current calendar framework — the same one the Calendar app uses. It provides:

- Direct access to all calendar sources: iCloud, Google (CalDAV), Exchange, local
- Typed data with no text parsing
- Full event properties: attendees with RSVP status, organizer, recurrence rules, event status, timezone-aware timestamps
- Forward compatibility with macOS updates

### Calendar access (TCC)

macOS controls calendar access via the Transparency, Consent, and Control (TCC) system. The permission is granted **per executable path** — the compiled binary and the Swift interpreter are treated as separate executables. For launchd use, always compile to a binary and grant access to that binary specifically.

The permission persists across runs as long as the binary is not moved or replaced. If you recompile and the binary changes, you may need to re-grant access via System Settings → Privacy & Security → Calendars.

---

## Files

| File | Purpose |
|---|---|
| `Sources/cal_export/main.swift` | Main source. Queries EventKit and outputs JSON to stdout or a file. |
| `Package.swift` | Swift Package Manager manifest. |
| `Makefile` | Build, install, and run shortcuts. |
| `local.cal_export.plist` | launchd agent definition. Runs the compiled binary on a schedule. |

---

## Output Schema

```json
{
  "generated_at": "2025-02-21T14:00:00Z",
  "range": {
    "from": "2025-02-21",
    "to": "2025-03-07"
  },
  "calendars": ["Family", "Personal", "Work"],
  "event_count": 12,
  "events": [
    {
      "uid": "x-apple-id://...",
      "title": "Team Standup",
      "calendar": "Work",
      "all_day": false,
      "start": "2025-02-21T09:00:00-08:00",
      "end": "2025-02-21T09:30:00-08:00",
      "location": "Zoom",
      "status": "confirmed",
      "organizer": {
        "name": "Jane Smith",
        "email": "jane@example.com",
        "status": "accepted",
        "role": "chair"
      },
      "attendees": [
        {
          "name": "Thomas Lockney",
          "email": "thomas@example.com",
          "status": "accepted",
          "role": "required"
        }
      ],
      "recurring": true,
      "recurrence_rule": {
        "frequency": "weekly",
        "interval": 1
      }
    }
  ]
}
```

**Notes on fields:**

- `start`/`end`: ISO 8601 with timezone offset for timed events; `YYYY-MM-DD` for all-day events
- `status`: `confirmed` | `tentative` | `cancelled` | `none`
- `attendee.status`: `accepted` | `declined` | `pending` | `tentative` | `delegated` | `completed` | `in_process` | `unknown`
- `attendee.role`: `required` | `optional` | `chair` | `non_participant` | `unknown`
- `calendars`: lists the calendar names included in the export (all available calendars when no `--calendars` filter is specified)
- Null fields are omitted from output (e.g. an event with no location will not have a `location` key)

---

## Setup

### 1. Build

```bash
swift build
# or
make build
```

### 2. Install

```bash
make install
```

This builds a release binary and copies it to `~/.local/bin/cal_export`. To install elsewhere:

```bash
make install PREFIX=/usr/local
```

### 3. Grant Calendar access

Run once manually to trigger the TCC permission prompt:

```bash
~/.local/bin/cal_export --days 1
```

Approve in the dialog. Verify it's listed under System Settings → Privacy & Security → Calendars.

### 4. Verify output

```bash
~/.local/bin/cal_export --days 7 | jq .
```

To list all available calendar names:

```bash
~/.local/bin/cal_export --list-calendars
```

### 5. Install launchd agent

Edit `local.cal_export.plist` first — replace `YOURUSER` with your username in the paths. Then:

```bash
cp local.cal_export.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/local.cal_export.plist
```

To run immediately without waiting for the interval:

```bash
launchctl start local.cal_export
```

To check status:

```bash
launchctl list | grep cal_export
```

Logs go to `/tmp/cal_export.log` (stdout) and `/tmp/cal_export.err` (stderr).

---

## CLI Reference

```
cal_export [--days N] [--from YYYY-MM-DD] [--to YYYY-MM-DD]
           [--calendars "Cal1,Cal2,..."] [--out FILE]
           [--list-calendars] [--help]

--days N            Fetch N days from start date (default: 7)
--from YYYY-MM-DD   Start date (default: today)
--to YYYY-MM-DD     End date (overrides --days)
--calendars CAL,..  Comma-separated list of calendar names to include.
                    Omit to include all calendars.
--out FILE          Write JSON to FILE instead of stdout. Supports ~.
--list-calendars    Print available calendar names and exit.
--help              Show usage and exit.
```

---

## launchd Schedule

The plist is configured for every 30 minutes (`StartInterval: 1800`). To change to specific times, replace `StartInterval` with `StartCalendarInterval`. Example for 6am, noon, and 6pm:

```xml
<key>StartCalendarInterval</key>
<array>
    <dict><key>Hour</key><integer>6</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>12</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
</array>
```

After any plist change:

```bash
launchctl unload ~/Library/LaunchAgents/local.cal_export.plist
launchctl load ~/Library/LaunchAgents/local.cal_export.plist
```

---

## Filtering Calendars

Pass `--calendars` at runtime to restrict output to specific calendars:

```bash
cal_export --calendars "Work,Personal,Family" --days 7
```

For launchd, add `--calendars` to `ProgramArguments` in the plist:

```xml
<key>ProgramArguments</key>
<array>
    <string>/Users/YOURUSER/.local/bin/cal_export</string>
    <string>--days</string>
    <string>14</string>
    <string>--calendars</string>
    <string>Work,Personal,Family</string>
    <string>--out</string>
    <string>/Users/YOURUSER/.local/var/cal_agenda.json</string>
</array>
```

Note: launchd does not expand `~` or `$HOME` — use full absolute paths in the plist.

If a `--calendars` argument names a calendar that doesn't exist, the program will exit with an error and print available calendar names to stderr — useful for debugging name mismatches (e.g. "Google Calendar" vs the actual calendar title).

---

## Extending

The JSON output is intentionally flat and complete. Likely next steps:

- **Filtering/querying**: pipe through `jq`, or load into SQLite via a separate script for more complex queries
- **Flint integration**: consume `cal_agenda.json` as context for scheduling, reminders, or daily briefings
- **Task export**: EventKit also supports reminders (`EKReminder`) via the same store — a parallel `rem_export.swift` would follow the same pattern, using `store.predicateForReminders(in:)` instead
- **Recurring event expansion**: the current output includes one entry per occurrence as EventKit expands recurrences within the query range; the `recurrence_rule` field on each is informational
