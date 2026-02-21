import EventKit
import Foundation

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
