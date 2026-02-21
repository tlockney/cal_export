import EventKit
import Foundation

// ── Formatters ────────────────────────────────────────────────────────────────

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

// ── Conversion ────────────────────────────────────────────────────────────────

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
