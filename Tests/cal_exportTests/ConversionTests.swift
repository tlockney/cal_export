import Testing
import EventKit
@testable import cal_export

@Suite("Status and role conversions")
struct ConversionTests {

  @Test("convertStatus maps all EKEventStatus values")
  func eventStatus() {
    #expect(convertStatus(.none) == "none")
    #expect(convertStatus(.confirmed) == "confirmed")
    #expect(convertStatus(.tentative) == "tentative")
    #expect(convertStatus(.canceled) == "cancelled")
  }

  @Test("convertParticipantStatus maps all EKParticipantStatus values")
  func participantStatus() {
    #expect(convertParticipantStatus(.unknown) == "unknown")
    #expect(convertParticipantStatus(.pending) == "pending")
    #expect(convertParticipantStatus(.accepted) == "accepted")
    #expect(convertParticipantStatus(.declined) == "declined")
    #expect(convertParticipantStatus(.tentative) == "tentative")
    #expect(convertParticipantStatus(.delegated) == "delegated")
    #expect(convertParticipantStatus(.completed) == "completed")
    #expect(convertParticipantStatus(.inProcess) == "in_process")
  }

  @Test("convertParticipantRole maps all EKParticipantRole values")
  func participantRole() {
    #expect(convertParticipantRole(.unknown) == "unknown")
    #expect(convertParticipantRole(.required) == "required")
    #expect(convertParticipantRole(.optional) == "optional")
    #expect(convertParticipantRole(.chair) == "chair")
    #expect(convertParticipantRole(.nonParticipant) == "non_participant")
  }

  @Test("convertFrequency maps all EKRecurrenceFrequency values")
  func recurrenceFrequency() {
    #expect(convertFrequency(.daily) == "daily")
    #expect(convertFrequency(.weekly) == "weekly")
    #expect(convertFrequency(.monthly) == "monthly")
    #expect(convertFrequency(.yearly) == "yearly")
  }
}
