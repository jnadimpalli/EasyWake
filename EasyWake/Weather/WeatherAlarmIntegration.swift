// WeatherAlarmIntegration.swift

import Foundation
import SwiftUI
import Combine

// MARK: - Weather Alarm Service
class WeatherAlarmService: ObservableObject {
    @Published var upcomingAdjustments: [AlarmAdjustment] = []
    
    private let alarmStore: AlarmStore
    private let weatherSettings = WeatherSettingsViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    struct AlarmAdjustment: Identifiable {
        let id = UUID()
        let alarm: Alarm
        let originalTime: Date
        let adjustedTime: Date
        let adjustmentMinutes: Int
        let weatherConditions: [String]
        let description: String
    }
    
    init(alarmStore: AlarmStore) {
        self.alarmStore = alarmStore
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe alarm changes
        alarmStore.$alarms
            .combineLatest(NotificationCenter.default.publisher(for: .weatherDataUpdated))
            .sink { [weak self] _ in
                self?.calculateAdjustments()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Core Adjustment Logic
    func calculateAdjustments() {
        let next24Hours = Date().addingTimeInterval(24 * 60 * 60)
        
        // Get alarms in next 24 hours that are enabled and smart
        let upcomingAlarms = alarmStore.alarms.filter { alarm in
            alarm.isEnabled &&
            alarm.smartEnabled &&
            isAlarmInTimeRange(alarm, before: next24Hours)
        }
        
        var adjustments: [AlarmAdjustment] = []
        
        for alarm in upcomingAlarms {
            if let adjustment = calculateAdjustmentForAlarm(alarm) {
                adjustments.append(adjustment)
            }
        }
        
        self.upcomingAdjustments = adjustments
    }
    
    private func calculateAdjustmentForAlarm(_ alarm: Alarm) -> AlarmAdjustment? {
        // Get current weather conditions from WeatherViewModel
        let weatherConditions = getCurrentWeatherConditions()
        
        guard !weatherConditions.isEmpty else { return nil }
        
        // Calculate total adjustment based on weather
        var totalMinutes = 0
        var appliedConditions: [String] = []
        
        for condition in weatherConditions {
            if let bufferMinutes = weatherSettings.bufferDelays[condition] {
                totalMinutes += bufferMinutes
                appliedConditions.append(condition)
            }
        }
        
        guard totalMinutes > 0 else { return nil }
        
        // Calculate adjusted wake time
        let originalWakeTime = calculateWakeTime(for: alarm)
        let adjustedWakeTime = originalWakeTime.addingTimeInterval(-TimeInterval(totalMinutes * 60))
        
        // Create readable description
        let description = createAdjustmentDescription(
            minutes: totalMinutes,
            conditions: appliedConditions,
            originalTime: originalWakeTime
        )
        
        return AlarmAdjustment(
            alarm: alarm,
            originalTime: originalWakeTime,
            adjustedTime: adjustedWakeTime,
            adjustmentMinutes: totalMinutes,
            weatherConditions: appliedConditions,
            description: description
        )
    }
    
    // MARK: - Wake Time Calculation
    private func calculateWakeTime(for alarm: Alarm) -> Date {
        var wakeTime: Date
        
        switch alarm.schedule {
        case .oneTime:
            wakeTime = alarm.time
        case .specificDate(let date):
            wakeTime = date
        case .repeatingDays:
            wakeTime = nextOccurrence(of: alarm.time)
        }
        
        // For smart alarms, work backwards from arrival time
        if alarm.smartEnabled {
            // Start with arrival time
            wakeTime = alarm.arrivalTime
            
            // Subtract travel time (would be calculated from Maps API)
            let travelTime = estimateTravelTime(
                from: "\(alarm.startingStreet), \(alarm.startingCity), \(alarm.startingState)",
                to: "\(alarm.destinationStreet), \(alarm.destinationCity), \(alarm.destinationState)"
            )
            wakeTime = wakeTime.addingTimeInterval(-travelTime)
            
            // Subtract preparation time
            wakeTime = wakeTime.addingTimeInterval(-alarm.preparationInterval)
        }
        
        return wakeTime
    }
    
    private func nextOccurrence(of time: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        var nextDate = calendar.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime
        ) ?? Date()
        
        return nextDate
    }
    
    private func estimateTravelTime(from origin: String, to destination: String) -> TimeInterval {
        // This would integrate with Google Maps API
        // For now, return a default 30 minutes
        return 30 * 60
    }
    
    // MARK: - Weather Conditions
    private func getCurrentWeatherConditions() -> [String] {
        // This would get actual conditions from WeatherViewModel
        // For demonstration, return mock conditions based on stored alerts
        
        var conditions: [String] = []
        
        // Check if we have weather data stored
        if let weatherData = UserDefaults.standard.data(forKey: "currentWeatherConditions"),
           let decoded = try? JSONDecoder().decode([String].self, from: weatherData) {
            conditions = decoded
        }
        
        return conditions
    }
    
    // MARK: - Helper Methods
    private func isAlarmInTimeRange(_ alarm: Alarm, before date: Date) -> Bool {
        let wakeTime = calculateWakeTime(for: alarm)
        return wakeTime > Date() && wakeTime < date
    }
    
    private func createAdjustmentDescription(minutes: Int, conditions: [String], originalTime: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        let conditionsText = conditions.joined(separator: ", ")
        
        if minutes < 60 {
            return "Wake \(minutes) min earlier (\(timeFormatter.string(from: originalTime))) due to \(conditionsText)"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "Wake \(hours) hr earlier (\(timeFormatter.string(from: originalTime))) due to \(conditionsText)"
            } else {
                return "Wake \(hours) hr \(remainingMinutes) min earlier (\(timeFormatter.string(from: originalTime))) due to \(conditionsText)"
            }
        }
    }
    
    // MARK: - Public Methods
    func getAdjustedWakeTime(for alarm: Alarm) -> Date {
        if let adjustment = upcomingAdjustments.first(where: { $0.alarm.id == alarm.id }) {
            return adjustment.adjustedTime
        }
        return calculateWakeTime(for: alarm)
    }
    
    func getAdjustmentDescription(for alarm: Alarm) -> String? {
        return upcomingAdjustments.first(where: { $0.alarm.id == alarm.id })?.description
    }
    
    func updateWeatherConditions(_ conditions: [String]) {
        // Store current conditions
        if let data = try? JSONEncoder().encode(conditions) {
            UserDefaults.standard.set(data, forKey: "currentWeatherConditions")
        }
        
        // Recalculate adjustments
        calculateAdjustments()
        
        // Post notification for other parts of the app
        NotificationCenter.default.post(name: .weatherDataUpdated, object: nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let weatherDataUpdated = Notification.Name("weatherDataUpdated")
    static let alarmAdjustmentsUpdated = Notification.Name("alarmAdjustmentsUpdated")
}

// MARK: - Weather Condition Mapping
extension WeatherAlarmService {
    // Map OpenWeatherMap conditions to our buffer time categories
    func mapWeatherCondition(from weatherCode: Int, description: String) -> String? {
        switch weatherCode {
        // Thunderstorm
        case 200...299:
            return "Thunderstorm"
            
        // Drizzle and Rain
        case 300...399:
            return "Light Rain"
        case 500...501:
            return "Light Rain"
        case 502...504:
            return "Moderate Rain"
        case 511, 520...531:
            return "Heavy Rain"
            
        // Snow
        case 600...601:
            return "Light Snow"
        case 602...612:
            return "Moderate Snow"
        case 613...622:
            return "Heavy Snow"
            
        // Atmosphere
        case 741:
            return "Fog"
            
        // Additional conditions
        case 771, 781:
            return "High Wind"
            
        default:
            return nil
        }
    }
}

// MARK: - SwiftUI Environment Key
struct WeatherAlarmServiceKey: EnvironmentKey {
    static let defaultValue = WeatherAlarmService(alarmStore: AlarmStore())
}

extension EnvironmentValues {
    var weatherAlarmService: WeatherAlarmService {
        get { self[WeatherAlarmServiceKey.self] }
        set { self[WeatherAlarmServiceKey.self] = newValue }
    }
}

// MARK: - Weather Alert View Component
struct WeatherAlarmAdjustmentView: View {
    let adjustment: WeatherAlarmService.AlarmAdjustment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "alarm")
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(adjustment.alarm.name)
                    .font(.headline)
                
                Text(adjustment.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Label("Original: \(adjustment.originalTime, style: .time)", systemImage: "clock")
                    Spacer()
                    Label("Adjusted: \(adjustment.adjustedTime, style: .time)", systemImage: "clock.badge.exclamationmark")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Integration Helper for AlarmListView
extension AlarmListView {
    func weatherAdjustedTime(for alarm: Alarm) -> String? {
        // This would be injected via environment
        // Return formatted adjusted time if alarm has weather adjustment
        return nil
    }
}
