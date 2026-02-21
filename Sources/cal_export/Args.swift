import Foundation

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

func parseArgs(_ args: [String]) -> Config {
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
