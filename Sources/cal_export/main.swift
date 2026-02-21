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

let config = parseArgs(Array(CommandLine.arguments.dropFirst()))
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
