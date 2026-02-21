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

// ── Runtime config ────────────────────────────────────────────────────────────

struct Config {
  var dateFrom: Date
  var dateTo: Date
  var calendars: [String]  // empty = all
  var outFile: String?
  var listCalendars: Bool
}
