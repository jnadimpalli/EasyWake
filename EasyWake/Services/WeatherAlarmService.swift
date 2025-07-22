// WeatherAlarmService.swift - Complete Fix

import Foundation
import SwiftUI
import Combine

// MARK: - Weather Condition Model
struct WeatherCondition {
    let type: WeatherConditionType
    let icon: String
    let description: String
    let severity: Severity
    
    enum WeatherConditionType {
        case heavyRain, snow, thunderstorm, fog, highWinds, ice
    }
    
    enum Severity {
        case moderate, severe, extreme
        
        var color: Color {
            switch self {
            case .moderate: return .orange
            case .severe: return .red
            case .extreme: return .purple
            }
        }
    }
}

@MainActor
class WeatherAlarmService: ObservableObject {
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    
    private let alarmStore: AlarmStore
    private let dataCoordinator: DataCoordinator
    private let smartAlarmService: SmartAlarmCalculationService
    private let profileViewModel: ProfileViewModel
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    // CRITICAL: Add flags to prevent loops
    private var isCalculating = false
    private var isUpdatingFromCalculation = false
    private var lastCalculationTimes: [UUID: Date] = [:]
    private let minimumRecalculationInterval: TimeInterval = 60 // 1 minute
    
    // NEW: Track dismissed adjustments for current session
    @Published private var sessionDismissedAlarmIds: Set<UUID> = []
    
    struct AlarmWithAdjustment: Identifiable {
        let id = UUID()
        let alarm: Alarm
        let adjustment: AlarmAdjustment
        let weatherCondition: WeatherCondition
        let routeSummary: String
        
        var isSignificant: Bool {
            abs(adjustment.adjustmentMinutes) >= 5
        }
    }
    
    // COMPUTED PROPERTY - Single source of truth from alarms
    var activeAdjustments: [AlarmWithAdjustment] {
        alarmStore.alarms.compactMap { alarm in
            // Skip if dismissed in current session
            guard !sessionDismissedAlarmIds.contains(alarm.id) else { return nil }

            guard let adjustment = alarm.currentAdjustment,
                  alarm.smartEnabled && alarm.isEnabled,
                  abs(adjustment.adjustmentMinutes) >= 5 else { return nil }
            
            // Extract weather condition from adjustment reason
            let weatherCondition = WeatherCondition(
                type: .heavyRain,
                icon: "cloud.heavyrain.fill",
                description: extractWeatherDescription(from: adjustment.reason),
                severity: determineSeverity(from: adjustment.adjustmentMinutes)
            )
            
            let routeSummary = createRouteSummary(for: alarm)
            
            return AlarmWithAdjustment(
                alarm: alarm,
                adjustment: adjustment,
                weatherCondition: weatherCondition,
                routeSummary: routeSummary
            )
        }
    }
    
    init(alarmStore: AlarmStore,
         dataCoordinator: DataCoordinator,
         profileViewModel: ProfileViewModel) {
        self.alarmStore = alarmStore
        self.dataCoordinator = dataCoordinator
        self.profileViewModel = profileViewModel
        self.smartAlarmService = SmartAlarmCalculationService()
        
        setupObservers()
        
        // Initial calculation
        Task {
            await refreshAllAdjustments()
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
        
    private func setupObservers() {
        // Listen for alarm deletions
        NotificationCenter.default.publisher(for: .alarmDeleted)
            .sink { [weak self] notification in
                // Clear calculation time for deleted alarm
                if let alarmId = notification.userInfo?["alarmId"] as? String,
                   let uuid = UUID(uuidString: alarmId) {
                    self?.lastCalculationTimes.removeValue(forKey: uuid)
                }
                print("[WEATHER-ALARM-SERVICE] Alarm deleted, skipping refresh")
            }
            .store(in: &cancellables)
        
        // Listen for alarm updates with smart debouncing
        NotificationCenter.default.publisher(for: .alarmUpdated)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                // Skip if we're the source of the update
                if self.isUpdatingFromCalculation {
                    print("[WEATHER-ALARM-SERVICE] Skipping refresh - update came from weather calculation")
                    return
                }
                
                // Check if this is from a deletion
                if let alarmId = notification.userInfo?["alarmId"] as? String,
                   self.alarmStore.alarms.first(where: { $0.id.uuidString == alarmId }) == nil {
                    print("[WEATHER-ALARM-SERVICE] Update for deleted alarm, skipping refresh")
                    return
                }
                
                // Check if we should skip weather refresh
                if let skipRefresh = notification.userInfo?["skipWeatherRefresh"] as? Bool, skipRefresh {
                    print("[WEATHER-ALARM-SERVICE] Skipping refresh due to skipWeatherRefresh flag")
                    return
                }
                
                // Debounce: Only refresh if enough time has passed
                Task { @MainActor in
                    await self.refreshAllAdjustmentsIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    func refreshAllAdjustments() async {
        await calculateWeatherAdjustmentsWithLambda()
    }
    
    private func refreshAllAdjustmentsIfNeeded() async {
        // Check if any alarm needs recalculation
        let now = Date()
        let needsRefresh = alarmStore.alarms.contains { alarm in
            guard alarm.smartEnabled && alarm.isEnabled else { return false }
            
            if let lastCalc = lastCalculationTimes[alarm.id] {
                return now.timeIntervalSince(lastCalc) >= minimumRecalculationInterval
            }
            return true
        }
        
        if needsRefresh {
            await calculateWeatherAdjustmentsWithLambda()
        } else {
            print("[WEATHER-ALARM-SERVICE] Skipping refresh - calculations are recent")
        }
    }
    
    public func clearAdjustmentsForAlarm(_ alarmId: UUID) async {
        // Clear adjustment from the alarm itself
        if let alarm = alarmStore.alarms.first(where: { $0.id == alarmId }) {
            var updatedAlarm = alarm
            updatedAlarm.currentAdjustment = nil
            
            // Set flag to prevent loop
            isUpdatingFromCalculation = true
            await dataCoordinator.updateAlarm(updatedAlarm, skipAdjustmentCalculation: true)
            isUpdatingFromCalculation = false
        }
        
        // Clear last calculation time
        lastCalculationTimes.removeValue(forKey: alarmId)
    }
    
    // MARK: - Public Methods
    
    func dismissAdjustment(for alarmId: UUID) {
        // Add to session dismissed set
        sessionDismissedAlarmIds.insert(alarmId)
        
        // Don't clear the adjustment from the alarm itself
        // This allows it to be shown again after app restart
        objectWillChange.send()
    }
    
    func dismissAdjustmentForToday(_ alarmId: UUID) {
        // For now, just dismiss it for the session
        // In future, could track dismissed dates
        dismissAdjustment(for: alarmId)
    }
    
    // NEW: Reset dismissed alarms (call on app restart if needed)
    func resetDismissedAlarms() {
        sessionDismissedAlarmIds.removeAll()
        objectWillChange.send()
    }
    
    func disableWeatherAdjustments(for alarm: Alarm) async {
        var updatedAlarm = alarm
        updatedAlarm.weatherAdjustment = false
        updatedAlarm.currentAdjustment = nil
        
        isUpdatingFromCalculation = true
        await dataCoordinator.updateAlarm(updatedAlarm, skipAdjustmentCalculation: true)
        isUpdatingFromCalculation = false
    }
    
    public func showRoute(for alarm: Alarm) {
        guard alarm.startingAddress.isValid && alarm.destinationAddress.isValid else { return }
        
        let start = alarm.startingAddress.coordinates
        let dest = alarm.destinationAddress.coordinates
        
        let urlString = "maps://maps.apple.com/?saddr=\(start.latitude),\(start.longitude)&daddr=\(dest.latitude),\(dest.longitude)&dirflg=d"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Lambda Integration
    public func calculateWeatherAdjustmentsWithLambda() async {
        // Prevent concurrent calculations
        guard !isCalculating else {
            print("[WEATHER-ALARM-SERVICE] Calculation already in progress, skipping")
            return
        }
        
        isCalculating = true
        defer { isCalculating = false }
        
        print("[WEATHER-ALARM-SERVICE] Starting weather adjustments calculation with Lambda")
        
        isLoading = true
        defer {
            isLoading = false
            lastUpdateTime = Date()
        }
        
        let now = Date()
        let next24Hours = now.addingTimeInterval(24 * 60 * 60)
        
        // Get eligible alarms
        let eligibleAlarms = alarmStore.alarms.filter { alarm in
            guard alarm.isEnabled && alarm.smartEnabled else { return false }
            guard alarm.startingAddress.isValid && alarm.destinationAddress.isValid else { return false }
            guard let nextOccurrence = alarm.nextOccurrenceTime else { return false }
            guard nextOccurrence > now && nextOccurrence <= next24Hours else { return false }
            
            // Check if we recently calculated for this alarm
            if let lastCalc = lastCalculationTimes[alarm.id],
               now.timeIntervalSince(lastCalc) < minimumRecalculationInterval {
                print("[WEATHER-ALARM-SERVICE] Skipping \(alarm.name) - calculated \(Int(now.timeIntervalSince(lastCalc)))s ago")
                return false
            }
            
            return true
        }
        
        print("[WEATHER-ALARM-SERVICE] Found \(eligibleAlarms.count) eligible alarms")
        
        // Process each eligible alarm
        for alarm in eligibleAlarms {
            await processAlarmAdjustment(alarm)
            // Record calculation time
            lastCalculationTimes[alarm.id] = Date()
        }
    }
    
    public func processAlarmAdjustment(_ alarm: Alarm) async {
        // Check if alarm still exists before processing
        guard alarmStore.alarms.contains(where: { $0.id == alarm.id }) else {
            print("[WEATHER-ALARM-SERVICE] Alarm no longer exists, skipping processing")
            return
        }
        
        print("[WEATHER-ALARM-SERVICE] Processing alarm: \(alarm.name)")
        
        do {
            // Check for cancellation
            try Task.checkCancellation()
            
            let response = try await smartAlarmService.calculateSmartWakeTime(
                for: alarm,
                userProfile: profileViewModel,
                arrivalTime: alarm.arrivalTime,
                currentLocation: nil,
                forceRecalculation: true
            )
            
            // Check again after async call
            guard alarmStore.alarms.contains(where: { $0.id == alarm.id }) else {
                print("[WEATHER-ALARM-SERVICE] Alarm was deleted during calculation")
                return
            }
            
            if let adjustment = createAdjustmentFromResponse(response, for: alarm) {
                // Get fresh copy of alarm from store
                guard let currentAlarm = alarmStore.alarms.first(where: { $0.id == alarm.id }) else {
                    print("[WEATHER-ALARM-SERVICE] Alarm no longer exists in store")
                    return
                }
                
                var updatedAlarm = currentAlarm
                updatedAlarm.currentAdjustment = adjustment
                
                // Set flag to prevent loop
                isUpdatingFromCalculation = true
                await dataCoordinator.updateAlarm(updatedAlarm, skipAdjustmentCalculation: true)
                isUpdatingFromCalculation = false
                
                print("[WEATHER-ALARM-SERVICE] Created adjustment: \(adjustment.adjustmentMinutes) minutes")
            }
        } catch {
            if error is CancellationError {
                print("[WEATHER-ALARM-SERVICE] Calculation cancelled for alarm: \(alarm.name)")
            } else {
                print("[WEATHER-ALARM-SERVICE] ERROR: Failed to calculate for '\(alarm.name)': \(error)")
            }
        }
    }
    
    private func createAdjustmentFromResponse(_ response: SmartAlarmResponse, for alarm: Alarm) -> AlarmAdjustment? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let adjustedWakeTime = formatter.date(from: response.wakeTime) ??
                                    ISO8601DateFormatter().date(from: response.wakeTime) else {
            print("[WEATHER-ALARM-SERVICE] Failed to parse wake time: \(response.wakeTime)")
            return nil
        }
        
        let originalTime = alarm.nextOccurrenceTime ?? alarm.alarmTime
        let adjustmentMinutes = Int((originalTime.timeIntervalSince(adjustedWakeTime)) / 60)
        
        guard abs(adjustmentMinutes) >= 2 else {
            print("[WEATHER-ALARM-SERVICE] Adjustment too small: \(adjustmentMinutes) minutes")
            return nil
        }
        
        let breakdown = AlarmAdjustment.AdjustmentBreakdown(
            preparationTime: response.breakdown.preparationTime,
            baseCommute: response.breakdown.baseCommute,
            weatherDelays: response.breakdown.weatherDelays,
            trafficDelays: response.breakdown.trafficDelays,
            snoozeBuffer: response.breakdown.snoozeBuffer
        )
        
        return AlarmAdjustment(
            adjustedWakeTime: adjustedWakeTime,
            adjustmentMinutes: adjustmentMinutes,
            reason: createExplanation(from: response.explanation, breakdown: response.breakdown),
            calculatedAt: Date(),
            confidence: response.confidenceScore,
            breakdown: breakdown
        )
    }
    
    // MARK: - Helper Methods
    
    private func extractWeatherDescription(from reason: String) -> String {
        // Extract weather condition from reason text
        if reason.lowercased().contains("rain") { return "Heavy rain expected" }
        if reason.lowercased().contains("snow") { return "Snow conditions" }
        if reason.lowercased().contains("fog") { return "Low visibility fog" }
        if reason.lowercased().contains("wind") { return "High winds" }
        if reason.lowercased().contains("storm") { return "Storm conditions" }
        return "Weather conditions"
    }
    
    private func determineSeverity(from adjustmentMinutes: Int) -> WeatherCondition.Severity {
        let absMinutes = abs(adjustmentMinutes)
        if absMinutes >= 20 { return .extreme }
        if absMinutes >= 10 { return .severe }
        return .moderate
    }
    
    public func extractWeatherCondition(from explanations: [ExplanationItem]) -> WeatherCondition {
        let weatherExplanations = explanations.filter { $0.type == "weather" }
        
        if !weatherExplanations.isEmpty {
            let totalDelay = weatherExplanations.reduce(0) { $0 + $1.minutes }
            let description = weatherExplanations.first?.reason ?? "Weather conditions affecting commute"
            
            let severity: WeatherCondition.Severity =
                totalDelay >= 15 ? .extreme :
                totalDelay >= 8 ? .severe :
                .moderate
            
            let type: WeatherCondition.WeatherConditionType
            let icon: String
            
            if description.lowercased().contains("rain") {
                type = .heavyRain
                icon = "cloud.heavyrain.fill"
            } else if description.lowercased().contains("snow") {
                type = .snow
                icon = "cloud.snow.fill"
            } else if description.lowercased().contains("fog") {
                type = .fog
                icon = "cloud.fog.fill"
            } else if description.lowercased().contains("storm") {
                type = .thunderstorm
                icon = "cloud.bolt.rain.fill"
            } else if description.lowercased().contains("wind") {
                type = .highWinds
                icon = "wind"
            } else if description.lowercased().contains("ice") {
                type = .ice
                icon = "thermometer.snowflake"
            } else {
                type = .heavyRain
                icon = "cloud.fill"
            }
            
            return WeatherCondition(
                type: type,
                icon: icon,
                description: description,
                severity: severity
            )
        }
        
        return WeatherCondition(
            type: .heavyRain,
            icon: "cloud.fill",
            description: "Conditions may affect commute",
            severity: .moderate
        )
    }
    
    public func createRouteSummary(for alarm: Alarm) -> String {
        let start = alarm.startingAddress.city.isEmpty ?
            alarm.startingAddress.label ?? "Start" :
            alarm.startingAddress.city
            
        let dest = alarm.destinationAddress.city.isEmpty ?
            alarm.destinationAddress.label ?? "Destination" :
            alarm.destinationAddress.city
            
        return "\(start) → \(dest)"
    }
    
    public func createExplanation(from items: [ExplanationItem], breakdown: TimeBreakdown) -> String {
        var components: [String] = []
        
        let weatherItems = items.filter { $0.type == "weather" }
        let trafficItems = items.filter { $0.type == "traffic" }
        
        if !weatherItems.isEmpty {
            let totalWeather = weatherItems.reduce(0) { $0 + $1.minutes }
            components.append("Weather: +\(totalWeather)min")
        }
        
        if !trafficItems.isEmpty {
            let totalTraffic = trafficItems.reduce(0) { $0 + $1.minutes }
            components.append("Traffic: +\(totalTraffic)min")
        }
        
        if breakdown.snoozeBuffer > 0 {
            components.append("Snooze buffer: \(breakdown.snoozeBuffer)min")
        }
        
        return components.isEmpty ? "Adjusted for optimal arrival" : components.joined(separator: ", ")
    }
}
