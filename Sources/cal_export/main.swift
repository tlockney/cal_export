/**
 cal_export — Export calendar events via EventKit to JSON.

 Usage:
   cal_export [--days N] [--from YYYY-MM-DD] [--to YYYY-MM-DD]
              [--calendars "Cal1,Cal2"] [--out FILE]
              [--list-calendars] [--help]

 Permissions:
   macOS will prompt for Calendar access on first run.
   To pre-authorize: tccutil reset Calendar (forces re-prompt)

 Build and run:
   swift build
   swift run cal_export --days 14 --out ~/cal_agenda.json
*/

import EventKit
import Foundation

// ── Output types ─────────────────────────────────────────────────────────────

struct ExportPayload: Codable {
  let generatedAt: String
  let range: DateRange
  let calendars: [String]
  let eventCount: Int
  let events: [EventOutput]
}

struct DateRange: Codable {
  let from: String
  let to: String
}

struct EventOutput: Codable {
  let uid: String
  let title: String
  let calendar: String
  let allDay: Bool
  let start: String
  let end: String
  let location: String?
  let notes: String?
  let url: String?
  let status: String
  let organizer: ParticipantOutput?
  let attendees: [ParticipantOutput]?
  let recurring: Bool
  let recurrenceRule: RecurrenceOutput?
}

struct ParticipantOutput: Codable {
  let name: String?
  let email: String
  let status: String
  let role: String
}

struct RecurrenceOutput: Codable {
  let frequency: String
  let interval: Int
  let endDate: String?
  let occurrenceCount: Int?
}

// ── Argument parsing ──────────────────────────────────────────────────────────

let usageText = """
Usage: cal_export [OPTIONS]

Options:
  --days N              Fetch N days from start date (default: 7)
  --from YYYY-MM-DD     Start date (default: today)
  --to YYYY-MM-DD       End date (overrides --days)
  --calendars CAL,...   Comma-separated calendar names (default: all)
  --out FILE            Write JSON to FILE instead of stdout (supports ~)
  --list-calendars      Print available calendar names and exit
  --help                Show this help and exit
"""

struct Config {
  var dateFrom: Date
  var dateTo: Date
  var calendars: [String]  // empty = all
  var outFile: String?
  var listCalendars: Bool
}

func parseArgs() -> Config {
  let args = Array(CommandLine.arguments.dropFirst())
  let cal = Calendar.current
  let today = cal.startOfDay(for: Date())
  var rawFrom: Date?
  var rawTo: Date?
  var days = 7
  var calendars: [String] = []
  var outFile: String?
  var listCalendars = false

  let fmt = ISO8601DateFormatter()
  fmt.formatOptions = [.withFullDate]

  var i = 0
  while i < args.count {
    switch args[i] {
    case "--help":
      print(usageText)
      exit(0)
    case "--list-calendars":
      listCalendars = true
    case "--days":
      i += 1
      guard i < args.count else {
        fputs("Error: --days requires a value\n", stderr)
        exit(1)
      }
      guard let n = Int(args[i]) else {
        fputs("Error: --days requires an integer, got '\(args[i])'\n", stderr)
        exit(1)
      }
      days = n
    case "--from":
      i += 1
      guard i < args.count else {
        fputs("Error: --from requires a value\n", stderr)
        exit(1)
      }
      guard let d = fmt.date(from: args[i]) else {
        fputs("Error: --from requires YYYY-MM-DD format, got '\(args[i])'\n", stderr)
        exit(1)
      }
      rawFrom = d
    case "--to":
      i += 1
      guard i < args.count else {
        fputs("Error: --to requires a value\n", stderr)
        exit(1)
      }
      guard let d = fmt.date(from: args[i]) else {
        fputs("Error: --to requires YYYY-MM-DD format, got '\(args[i])'\n", stderr)
        exit(1)
      }
      rawTo = d
    case "--calendars":
      i += 1
      guard i < args.count else {
        fputs("Error: --calendars requires a value\n", stderr)
        exit(1)
      }
      calendars = args[i].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    case "--out":
      i += 1
      guard i < args.count else {
        fputs("Error: --out requires a value\n", stderr)
        exit(1)
      }
      outFile = args[i]
    default:
      fputs("Error: unexpected argument '\(args[i])'\n\(usageText)\n", stderr)
      exit(1)
    }
    i += 1
  }

  let dateFrom = rawFrom ?? today
  let dateTo = rawTo ?? cal.date(byAdding: .day, value: days, to: dateFrom)!

  return Config(
    dateFrom: dateFrom,
    dateTo: dateTo,
    calendars: calendars,
    outFile: outFile,
    listCalendars: listCalendars
  )
}

// ── EventKit query ────────────────────────────────────────────────────────────

func requestAccess(store: EKEventStore) async {
  do {
    let granted: Bool
    if #available(macOS 14.0, *) {
      granted = try await store.requestFullAccessToEvents()
    } else {
      granted = try await store.requestAccess(to: .event)
    }
    if !granted {
      fputs("Calendar access denied. Grant access in System Settings → Privacy & Security → Calendars.\n", stderr)
      exit(1)
    }
  } catch {
    fputs("Calendar access error: \(error.localizedDescription)\n", stderr)
    exit(1)
  }
}

func fetchEvents(store: EKEventStore, config: Config) -> [EKEvent] {
  var targetCalendars: [EKCalendar]? = nil

  if !config.calendars.isEmpty {
    let all = store.calendars(for: .event)
    let matched = all.filter { config.calendars.contains($0.title) }
    if matched.isEmpty {
      fputs("Warning: no calendars matched \(config.calendars). Available:\n", stderr)
      all.forEach { fputs("  \($0.title)\n", stderr) }
      exit(1)
    }
    targetCalendars = matched
  }

  let predicate = store.predicateForEvents(
    withStart: config.dateFrom,
    end: config.dateTo,
    calendars: targetCalendars
  )

  return store.events(matching: predicate)
    .sorted { $0.startDate < $1.startDate }
}

// ── Conversion ───────────────────────────────────────────────────────────────

nonisolated(unsafe) let isoFmt: ISO8601DateFormatter = {
  let f = ISO8601DateFormatter()
  f.formatOptions = [.withInternetDateTime]
  return f
}()

let dateFmt: DateFormatter = {
  let f = DateFormatter()
  f.dateFormat = "yyyy-MM-dd"
  f.locale = Locale(identifier: "en_US_POSIX")
  return f
}()

func convertEvent(_ event: EKEvent) -> EventOutput {
  let start = event.isAllDay
    ? dateFmt.string(from: event.startDate)
    : isoFmt.string(from: event.startDate)
  let end = event.isAllDay
    ? dateFmt.string(from: event.endDate)
    : isoFmt.string(from: event.endDate)

  let recurring: Bool
  let recurrenceRule: RecurrenceOutput?
  if let rules = event.recurrenceRules, let first = rules.first {
    recurring = true
    recurrenceRule = convertRecurrence(first)
  } else {
    recurring = false
    recurrenceRule = nil
  }

  return EventOutput(
    uid: event.calendarItemExternalIdentifier,
    title: event.title,
    calendar: event.calendar.title,
    allDay: event.isAllDay,
    start: start,
    end: end,
    location: event.location,
    notes: event.notes,
    url: event.url?.absoluteString,
    status: convertStatus(event.status),
    organizer: event.organizer.map { convertParticipant($0) },
    attendees: event.attendees?.map { convertParticipant($0) },
    recurring: recurring,
    recurrenceRule: recurrenceRule
  )
}

func convertStatus(_ status: EKEventStatus) -> String {
  switch status {
  case .none:      return "none"
  case .confirmed: return "confirmed"
  case .tentative: return "tentative"
  case .canceled:  return "cancelled"
  @unknown default: return "unknown"
  }
}

func convertParticipant(_ p: EKParticipant) -> ParticipantOutput {
  ParticipantOutput(
    name: p.name,
    email: p.url.absoluteString.replacingOccurrences(of: "mailto:", with: ""),
    status: convertParticipantStatus(p.participantStatus),
    role: convertParticipantRole(p.participantRole)
  )
}

func convertParticipantStatus(_ s: EKParticipantStatus) -> String {
  switch s {
  case .unknown:   return "unknown"
  case .pending:   return "pending"
  case .accepted:  return "accepted"
  case .declined:  return "declined"
  case .tentative: return "tentative"
  case .delegated: return "delegated"
  case .completed: return "completed"
  case .inProcess: return "in_process"
  @unknown default: return "unknown"
  }
}

func convertParticipantRole(_ r: EKParticipantRole) -> String {
  switch r {
  case .unknown:        return "unknown"
  case .required:       return "required"
  case .optional:       return "optional"
  case .chair:          return "chair"
  case .nonParticipant: return "non_participant"
  @unknown default:     return "unknown"
  }
}

func convertRecurrence(_ rule: EKRecurrenceRule) -> RecurrenceOutput {
  var endDate: String?
  var occurrenceCount: Int?

  if let end = rule.recurrenceEnd {
    if let d = end.endDate {
      endDate = isoFmt.string(from: d)
    } else {
      occurrenceCount = end.occurrenceCount
    }
  }

  return RecurrenceOutput(
    frequency: convertFrequency(rule.frequency),
    interval: rule.interval,
    endDate: endDate,
    occurrenceCount: occurrenceCount
  )
}

func convertFrequency(_ f: EKRecurrenceFrequency) -> String {
  switch f {
  case .daily:   return "daily"
  case .weekly:  return "weekly"
  case .monthly: return "monthly"
  case .yearly:  return "yearly"
  @unknown default: return "unknown"
  }
}

// ── Main ──────────────────────────────────────────────────────────────────────

let config = parseArgs()
let store = EKEventStore()

await requestAccess(store: store)

if config.listCalendars {
  let names = store.calendars(for: .event).map { $0.title }.sorted()
  for name in names {
    print(name)
  }
  exit(0)
}

let events = fetchEvents(store: store, config: config)

let calendarNames = config.calendars.isEmpty
  ? store.calendars(for: .event).map { $0.title }.sorted()
  : config.calendars

let payload = ExportPayload(
  generatedAt: isoFmt.string(from: Date()),
  range: DateRange(
    from: dateFmt.string(from: config.dateFrom),
    to: dateFmt.string(from: config.dateTo)
  ),
  calendars: calendarNames,
  eventCount: events.count,
  events: events.map { convertEvent($0) }
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
encoder.keyEncodingStrategy = .convertToSnakeCase

let json = try encoder.encode(payload)

if let outFile = config.outFile {
  let url = URL(fileURLWithPath: (outFile as NSString).expandingTildeInPath)
  try json.write(to: url)
  fputs("Wrote \(events.count) events to \(outFile)\n", stderr)
} else {
  FileHandle.standardOutput.write(json)
  print()
}
