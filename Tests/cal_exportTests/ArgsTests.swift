import Testing
import Foundation
@testable import cal_export

@Suite("Argument parsing")
struct ArgsTests {

  // Shared date formatter matching parseArgs internals.
  private let fmt: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withFullDate]
    return f
  }()

  private func date(_ s: String) -> Date { fmt.date(from: s)! }

  @Test("defaults: today + 7 days, no filters")
  func defaults() {
    let config = parseArgs([])
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let expected = cal.date(byAdding: .day, value: 7, to: today)!
    #expect(config.dateFrom == today)
    #expect(config.dateTo == expected)
    #expect(config.calendars.isEmpty)
    #expect(config.outFile == nil)
    #expect(config.listCalendars == false)
  }

  @Test("--days overrides window size")
  func days() {
    let config = parseArgs(["--days", "14"])
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let expected = cal.date(byAdding: .day, value: 14, to: today)!
    #expect(config.dateTo == expected)
  }

  @Test("--from sets start date")
  func fromDate() {
    let config = parseArgs(["--from", "2025-03-01"])
    #expect(config.dateFrom == date("2025-03-01"))
  }

  @Test("--from and --days compose: end = from + days")
  func fromAndDays() {
    let config = parseArgs(["--from", "2025-03-01", "--days", "14"])
    let cal = Calendar.current
    let expectedEnd = cal.date(byAdding: .day, value: 14, to: date("2025-03-01"))!
    #expect(config.dateFrom == date("2025-03-01"))
    #expect(config.dateTo == expectedEnd)
  }

  @Test("--to overrides --days for end date")
  func toDate() {
    let config = parseArgs(["--to", "2025-04-01"])
    #expect(config.dateTo == date("2025-04-01"))
  }

  @Test("--from and --to set both bounds directly")
  func fromAndTo() {
    let config = parseArgs(["--from", "2025-03-01", "--to", "2025-03-15"])
    #expect(config.dateFrom == date("2025-03-01"))
    #expect(config.dateTo == date("2025-03-15"))
  }

  @Test("--calendars parses comma-separated names")
  func calendars() {
    let config = parseArgs(["--calendars", "Work,Personal,Family"])
    #expect(config.calendars == ["Work", "Personal", "Family"])
  }

  @Test("--calendars trims whitespace around names")
  func calendarsWhitespace() {
    let config = parseArgs(["--calendars", "Work, Personal , Family"])
    #expect(config.calendars == ["Work", "Personal", "Family"])
  }

  @Test("--out sets output path")
  func outFile() {
    let config = parseArgs(["--out", "/tmp/events.json"])
    #expect(config.outFile == "/tmp/events.json")
  }

  @Test("--list-calendars sets flag")
  func listCalendars() {
    let config = parseArgs(["--list-calendars"])
    #expect(config.listCalendars == true)
  }

  @Test("--list-calendars can be combined with other flags")
  func listCalendarsCombined() {
    let config = parseArgs(["--list-calendars", "--days", "30"])
    #expect(config.listCalendars == true)
  }
}
