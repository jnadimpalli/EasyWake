// Alarm.swift

import Foundation

// Seven weekdays, for the "repeating" case
enum Weekday: String, Codable, CaseIterable, Hashable {
  case sunday, monday, tuesday, wednesday, thursday, friday, saturday
}

// Which of the three firing-modes this alarm uses:
enum AlarmSchedule: Codable, Hashable {

  // Ring immediately when enabled
  case oneTime

  // Ring once at this exact date & time
  case specificDate(Date)

  // Ring at `timeOfDay` on each of these weekdays
  case repeatingDays([Weekday])

  // MARK: — Codable boilerplate

  private enum CodingKeys: String, CodingKey {
    case oneTime, specificDate, repeatingDays
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    if c.contains(.oneTime) {
      self = .oneTime
    } else if let d = try? c.decode(Date.self, forKey: .specificDate) {
      self = .specificDate(d)
    } else {
      let days = try c.decode([Weekday].self, forKey: .repeatingDays)
      self = .repeatingDays(days)
    }
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .oneTime:
      try c.encode(true, forKey: .oneTime)
    case .specificDate(let d):
      try c.encode(d, forKey: .specificDate)
    case .repeatingDays(let days):
      try c.encode(days, forKey: .repeatingDays)
    }
  }
}

struct Alarm: Identifiable, Codable, Equatable {
  var id = UUID()

  // Core alarm fields
  var name: String = ""
  var time: Date = Date()
  var repeatDays: [String] = []
  var isEnabled: Bool = true
  var isAutoPopulated: Bool = false
  var schedule: AlarmSchedule = .oneTime

  // FR-1: Specific date support (nil means "every day")
  var specificDate: Date? = nil

  // For the `.repeatingDays` case, this is ignored;
  // for the `.specificDate` case also
  // ignored (it lives inside the enum).
  // For `.oneTime`, we take "now".
  var timeOfDay: Date = Date()

  // Sound
  var selectedTone: String = "Alarm.caf"
  var volume: Double = 0.5

  // FR-2: Vibration toggle (default to ON for new alarms)
  var vibrationEnabled: Bool = true

  // Smart-alarm toggle
  var smartEnabled: Bool = false

  // Smart-only fields
  var startingStreet: String = ""
  var startingCity: String = ""
  var startingZip: String = ""
  var startingState: String = "Select"

  var destinationStreet: String = ""
  var destinationCity: String = ""
  var destinationZip: String = ""
  var destinationState: String = "Select"

  // FR-3: Replace readyHours/readyMinutes with preparationInterval
  var preparationInterval: TimeInterval = 0

  // Legacy properties for backward compatibility
  var readyHours: Int = 0
  var readyMinutes: Int = 0

  var arrivalTime: Date = Date()

  var weatherAdjustment: Bool = false
  var trafficAdjustment: Bool = false
  var transitAdjustment: Bool = false

  // MARK: – Weekday ordering helper
  private static let weekOrder: [Weekday] = [
    .monday, .tuesday, .wednesday,
    .thursday, .friday, .saturday, .sunday,
  ]

  /// Show Mon→Sun only when using `.repeatingDays`
  var dayString: String {
    // only for repeatingDays – else empty
    guard case .repeatingDays(let days) = schedule else { return "" }

    // sort against our canonical [Mon…Sun]
    let sorted = Alarm.weekOrder.filter { days.contains($0) }
    return
      sorted
      .map { $0.rawValue.prefix(3).capitalized }
      .joined(separator: ", ")
  }

  // A little user-friendly summary of the schedule
  var scheduleDescription: String {
    switch schedule {
    case .oneTime:
      return "Once (now)"
    case .specificDate(let d):
      let df = DateFormatter()
      df.dateStyle = .medium
      df.timeStyle = .short
      return "On \(df.string(from: d))"
    case .repeatingDays(let days):
      return
        days
        .map { $0.rawValue.prefix(3).capitalized }
        .joined(separator: ", ")
    }
  }

  // MARK: - Data Migration and Initialization

  // Custom CodingKeys for handling optional properties
  private enum CodingKeys: String, CodingKey {
    case id, name, time, repeatDays, isEnabled, isAutoPopulated, schedule
    case specificDate, timeOfDay, selectedTone, volume, vibrationEnabled
    case smartEnabled, startingStreet, startingCity, startingZip, startingState
    case destinationStreet, destinationCity, destinationZip, destinationState
    case preparationInterval, readyHours, readyMinutes, arrivalTime
    case weatherAdjustment, trafficAdjustment, transitAdjustment
  }

  // Custom initializer for data migration
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Decode existing properties
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    time = try container.decodeIfPresent(Date.self, forKey: .time) ?? Date()
    repeatDays = try container.decodeIfPresent([String].self, forKey: .repeatDays) ?? []
    isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    isAutoPopulated = try container.decodeIfPresent(Bool.self, forKey: .isAutoPopulated) ?? false
    schedule = try container.decodeIfPresent(AlarmSchedule.self, forKey: .schedule) ?? .oneTime

    // FR-1: Decode specific date (new property)
    specificDate = try container.decodeIfPresent(Date.self, forKey: .specificDate)

    timeOfDay = try container.decodeIfPresent(Date.self, forKey: .timeOfDay) ?? Date()
    selectedTone = try container.decodeIfPresent(String.self, forKey: .selectedTone) ?? "Alarm.caf"
    volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 0.5

    // FR-2: Decode vibration setting (new property, default to true)
    vibrationEnabled = try container.decodeIfPresent(Bool.self, forKey: .vibrationEnabled) ?? true

    smartEnabled = try container.decodeIfPresent(Bool.self, forKey: .smartEnabled) ?? false

    // Address fields
    startingStreet = try container.decodeIfPresent(String.self, forKey: .startingStreet) ?? ""
    startingCity = try container.decodeIfPresent(String.self, forKey: .startingCity) ?? ""
    startingZip = try container.decodeIfPresent(String.self, forKey: .startingZip) ?? ""
    startingState = try container.decodeIfPresent(String.self, forKey: .startingState) ?? "Select"

    destinationStreet = try container.decodeIfPresent(String.self, forKey: .destinationStreet) ?? ""
    destinationCity = try container.decodeIfPresent(String.self, forKey: .destinationCity) ?? ""
    destinationZip = try container.decodeIfPresent(String.self, forKey: .destinationZip) ?? ""
    destinationState =
      try container.decodeIfPresent(String.self, forKey: .destinationState) ?? "Select"

    // FR-3: Migration logic for preparation time
    // Try to decode new preparationInterval first
    if let newPreparationInterval = try container.decodeIfPresent(
      TimeInterval.self, forKey: .preparationInterval)
    {
      preparationInterval = newPreparationInterval
      // Extract hours and minutes for backward compatibility
      readyHours = Int(newPreparationInterval / 3600)
      readyMinutes = Int((newPreparationInterval.truncatingRemainder(dividingBy: 3600)) / 60)
    } else {
      // Migrate from legacy readyHours/readyMinutes
      let legacyHours = try container.decodeIfPresent(Int.self, forKey: .readyHours) ?? 0
      let legacyMinutes = try container.decodeIfPresent(Int.self, forKey: .readyMinutes) ?? 0

      readyHours = legacyHours
      readyMinutes = legacyMinutes
      preparationInterval = TimeInterval(legacyHours * 3600 + legacyMinutes * 60)
    }

    arrivalTime = try container.decodeIfPresent(Date.self, forKey: .arrivalTime) ?? Date()
    weatherAdjustment =
      try container.decodeIfPresent(Bool.self, forKey: .weatherAdjustment) ?? false
    trafficAdjustment =
      try container.decodeIfPresent(Bool.self, forKey: .trafficAdjustment) ?? false
    transitAdjustment =
      try container.decodeIfPresent(Bool.self, forKey: .transitAdjustment) ?? false
  }

  // Default initializer
  init(
    id: UUID = UUID(),
    name: String = "",
    time: Date = Date(),
    repeatDays: [String] = [],
    isEnabled: Bool = true,
    isAutoPopulated: Bool = false,
    schedule: AlarmSchedule = .oneTime,
    specificDate: Date? = nil,
    timeOfDay: Date = Date(),
    selectedTone: String = "Alarm.caf",
    volume: Double = 0.5,
    vibrationEnabled: Bool = true,
    smartEnabled: Bool = false,
    startingStreet: String = "",
    startingCity: String = "",
    startingZip: String = "",
    startingState: String = "Select",
    destinationStreet: String = "",
    destinationCity: String = "",
    destinationZip: String = "",
    destinationState: String = "Select",
    preparationInterval: TimeInterval = 0,
    readyHours: Int = 0,
    readyMinutes: Int = 0,
    arrivalTime: Date = Date(),
    weatherAdjustment: Bool = false,
    trafficAdjustment: Bool = false,
    transitAdjustment: Bool = false
  ) {
    self.id = id
    self.name = name
    self.time = time
    self.repeatDays = repeatDays
    self.isEnabled = isEnabled
    self.isAutoPopulated = isAutoPopulated
    self.schedule = schedule
    self.specificDate = specificDate
    self.timeOfDay = timeOfDay
    self.selectedTone = selectedTone
    self.volume = volume
    self.vibrationEnabled = vibrationEnabled
    self.smartEnabled = smartEnabled
    self.startingStreet = startingStreet
    self.startingCity = startingCity
    self.startingZip = startingZip
    self.startingState = startingState
    self.destinationStreet = destinationStreet
    self.destinationCity = destinationCity
    self.destinationZip = destinationZip
    self.destinationState = destinationState
    self.preparationInterval = preparationInterval
    self.readyHours = readyHours
    self.readyMinutes = readyMinutes
    self.arrivalTime = arrivalTime
    self.weatherAdjustment = weatherAdjustment
    self.trafficAdjustment = trafficAdjustment
    self.transitAdjustment = transitAdjustment
  }
}
