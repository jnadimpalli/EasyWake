// Alarm.swift

import Foundation
import SwiftUI
import CoreLocation

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

extension Date {
    /// Convert to UTC ISO8601 string for Lambda
    var utcISO8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: self)
    }
    
    /// Create from ISO8601 string (handles timezone)
    static func fromISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        
        // Try with fractional seconds first
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }
        
        // Try replacing Z with +00:00
        if string.hasSuffix("Z") {
            let modifiedString = string.replacingOccurrences(of: "Z", with: "+00:00")
            return formatter.date(from: modifiedString)
        }
        
        return nil
    }
}

// MARK: - Alarm Model
struct Alarm: Identifiable, Codable, Equatable {
    let id: UUID
    
    // Core fields
    var name: String
    var isEnabled: Bool
    
    // Time storage - always interpreted in current timezone
    var alarmTime: Date
    var arrivalTime: Date
    
    // Schedule
    var schedule: AlarmSchedule
    
    // Smart alarm fields
    var smartEnabled: Bool
    var startingAddress: ValidatedAddress
    var destinationAddress: ValidatedAddress
    var preparationMinutes: Int
    var travelMethod: TravelMethod
    
    // Adjustment toggles
    var weatherAdjustment: Bool
    var trafficAdjustment: Bool
    var transitAdjustment: Bool
    
    // Sound settings
    var soundTone: String
    var volume: Double
    var vibrationEnabled: Bool
    
    // NEW: Individual snooze settings
    var snoozeEnabled: Bool
    var maxSnoozes: Int
    var snoozeMinutes: Int
    
    // Weather adjustment result (stored directly in alarm)
    var currentAdjustment: AlarmAdjustment?
    
    var preparationInterval: TimeInterval {
        get {
            return TimeInterval(preparationMinutes * 60)
        }
        set {
            // convert seconds back into minutes
            preparationMinutes = Int(newValue / 60)
        }
    }
    
    // NEW: Computed property for snooze buffer in seconds
    var totalSnoozeBuffer: TimeInterval {
        guard snoozeEnabled else { return 0 }
        return TimeInterval(maxSnoozes * snoozeMinutes * 60)
    }
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        name: String = "",
        isEnabled: Bool = true,
        alarmTime: Date = Date(),
        arrivalTime: Date = Date(),
        schedule: AlarmSchedule = .oneTime,
        smartEnabled: Bool = false,
        startingAddress: ValidatedAddress = ValidatedAddress(),
        destinationAddress: ValidatedAddress = ValidatedAddress(),
        preparationMinutes: Int = 0,
        travelMethod: TravelMethod = .drive,
        weatherAdjustment: Bool = false,
        trafficAdjustment: Bool = false,
        transitAdjustment: Bool = false,
        soundTone: String = "Alarm.caf",
        volume: Double = 0.5,
        vibrationEnabled: Bool = true,
        snoozeEnabled: Bool = false,
        maxSnoozes: Int = 2,
        snoozeMinutes: Int = 9,
        currentAdjustment: AlarmAdjustment? = nil
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.alarmTime = alarmTime
        self.arrivalTime = arrivalTime
        self.schedule = schedule
        self.smartEnabled = smartEnabled
        self.startingAddress = startingAddress
        self.destinationAddress = destinationAddress
        self.preparationMinutes = preparationMinutes
        self.travelMethod = travelMethod
        self.weatherAdjustment = weatherAdjustment
        self.trafficAdjustment = trafficAdjustment
        self.transitAdjustment = transitAdjustment
        self.soundTone = soundTone
        self.volume = volume
        self.vibrationEnabled = vibrationEnabled
        self.snoozeEnabled = snoozeEnabled
        self.maxSnoozes = maxSnoozes
        self.snoozeMinutes = snoozeMinutes
        self.currentAdjustment = currentAdjustment
    }
    
    // MARK: - Computed Properties
    var isRepeating: Bool {
        switch schedule {
        case .repeatingDays: return true
        default: return false
        }
    }
    
    private func convertToLocalTime(_ date: Date) -> Date {
        // If the date doesn't have timezone info, treat it as local
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return calendar.date(from: components) ?? date
    }
    
    var nextOccurrenceTime: Date? {
        let calendar = Calendar.current
        let now = Date()
        
        switch schedule {
        case .oneTime:
            return alarmTime > now ? convertToLocalTime(alarmTime) : nil
            
        case .specificDate(let date):
            let components = calendar.dateComponents([.hour, .minute], from: alarmTime)
            guard let occurrence = calendar.date(
                bySettingHour: components.hour ?? 0,
                minute: components.minute ?? 0,
                second: 0,
                of: date
            ) else { return nil }
            
            return occurrence > now ? occurrence : nil
            
        case .repeatingDays(let days):
            return findNextRepeatingOccurrence(days: days, from: now)
        }
    }
    
    /// Convert stored time to local timezone for display
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter.string(from: alarmTime)
    }
    
    /// Convert stored arrival time to local timezone for display
    var displayArrivalTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter.string(from: arrivalTime)
    }
    
    /// Get wake time adjusted for current timezone
    var effectiveWakeTime: Date {
        if smartEnabled, let adjustment = currentAdjustment {
            return convertToLocalTime(adjustment.adjustedWakeTime)
        }
        return nextOccurrenceTime ?? alarmTime
    }
    
    var nextArrivalTime: Date {
        guard let nextOccurrence = nextOccurrenceTime else {
            return arrivalTime
        }
        
        let calendar = Calendar.current
        let alarmComponents = calendar.dateComponents([.hour, .minute], from: alarmTime)
        let arrivalComponents = calendar.dateComponents([.hour, .minute], from: arrivalTime)
        
        // Calculate if arrival is next day
        let alarmMinutes = (alarmComponents.hour ?? 0) * 60 + (alarmComponents.minute ?? 0)
        let arrivalMinutes = (arrivalComponents.hour ?? 0) * 60 + (arrivalComponents.minute ?? 0)
        
        let baseDate = calendar.startOfDay(for: nextOccurrence)
        
        if arrivalMinutes < alarmMinutes {
            // Arrival is next day
            let nextDay = calendar.date(byAdding: .day, value: 1, to: baseDate)!
            return calendar.date(
                bySettingHour: arrivalComponents.hour ?? 0,
                minute: arrivalComponents.minute ?? 0,
                second: 0,
                of: nextDay
            ) ?? arrivalTime
        } else {
            // Same day arrival
            return calendar.date(
                bySettingHour: arrivalComponents.hour ?? 0,
                minute: arrivalComponents.minute ?? 0,
                second: 0,
                of: baseDate
            ) ?? arrivalTime
        }
    }
    
    var effectiveAlarmTime: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: alarmTime)
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: components.hour ?? 0,
                           minute: components.minute ?? 0,
                           second: 0,
                           of: today) ?? alarmTime
    }
    
    
    // MARK: - Private Methods
    private func findNextRepeatingOccurrence(days: [Weekday], from date: Date) -> Date? {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: alarmTime)
        
        // Convert Weekday enum to Calendar weekday integers
        let targetWeekdays = Set(days.map { weekday in
            switch weekday {
            case .sunday: return 1
            case .monday: return 2
            case .tuesday: return 3
            case .wednesday: return 4
            case .thursday: return 5
            case .friday: return 6
            case .saturday: return 7
            }
        })
        
        // Check next 7 days
        for dayOffset in 0..<7 {
            guard let candidateDate = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let weekday = calendar.component(.weekday, from: candidateDate)
            
            if targetWeekdays.contains(weekday) {
                guard let alarmDateTime = calendar.date(
                    bySettingHour: timeComponents.hour ?? 0,
                    minute: timeComponents.minute ?? 0,
                    second: 0,
                    of: candidateDate
                ) else { continue }
                
                // For today, check if time has passed
                if dayOffset == 0 && alarmDateTime <= date {
                    continue
                }
                
                return alarmDateTime
            }
        }
        
        return nil
    }
}

// MARK: - ValidatedAddress
struct ValidatedAddress: Codable, Equatable {
    var label: String?
    var street: String
    var city: String
    var state: String
    var zip: String
    var formattedAddress: String
    var coordinates: Coordinates
    
    struct Coordinates: Codable, Equatable {
        let latitude: Double
        let longitude: Double
    }
    
    init(
        label: String? = nil,
        street: String = "",
        city: String = "",
        state: String = "Select",
        zip: String = "",
        formattedAddress: String = "",
        coordinates: Coordinates = Coordinates(latitude: 0, longitude: 0)
    ) {
        self.label = label
        self.street = street
        self.city = city
        self.state = state
        self.zip = zip
        self.formattedAddress = formattedAddress
        self.coordinates = coordinates
    }
    
    var isValid: Bool {
        return !street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               state != "Select" && !state.isEmpty &&
               zip.count == 5
    }
}

// MARK: - AlarmAdjustment
struct AlarmAdjustment: Codable, Equatable {
    let adjustedWakeTime: Date
    let adjustmentMinutes: Int
    let reason: String
    let calculatedAt: Date
    let confidence: Double
    let breakdown: AdjustmentBreakdown?
    
    struct AdjustmentBreakdown: Codable, Equatable {
        let preparationTime: Int
        let baseCommute: Int
        let weatherDelays: Int
        let trafficDelays: Int
        let snoozeBuffer: Int
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let alarmCreated = Notification.Name("alarmCreated")
    static let alarmUpdated = Notification.Name("alarmUpdated")
    static let alarmDeleted = Notification.Name("alarmDeleted")
}
