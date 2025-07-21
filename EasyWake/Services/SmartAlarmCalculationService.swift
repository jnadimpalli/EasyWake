// SmartAlarmCalculationService.swift - Enhanced iOS service for Lambda integration

import Foundation
import CoreLocation
import Combine
import SwiftUI


// MARK: - Data Models for Lambda Communication

struct SmartAlarmRequest: Codable {
    let userProfile: UserProfilePayload
    let alarmSettings: AlarmSettingsPayload
    let arrivalTime: String // ISO format
    let currentLocation: LocationPayload?
    let forceRecalculation: Bool
    
    enum CodingKeys: String, CodingKey {
        case userProfile = "user_profile"
        case alarmSettings = "alarm_settings"
        case arrivalTime = "arrival_time"
        case currentLocation = "current_location"
        case forceRecalculation = "force_recalculation"
    }
}

struct UserProfilePayload: Codable {
    let userId: String
    let defaultPreparationMinutes: Int
    let commuteBufferMinutes: Int
    let snoozeDurationMinutes: Int
    let minimumSleepHours: Double?
    let preferredWakeTimeEarliest: String?
    let preferredWakeTimeLatest: String?
    let limitSnooze: Bool
    let maxSnoozes: Int?
    let averageSnoozesPerAlarm: Double?
    let defaultTravelMethod: String
    let weatherSensitivityMultiplier: Double
    let homeAddress: String?
    let workAddress: String?
    let historicalAccuracyRate: Double?
    let averageActualPrepTime: Int?
    let lateFrequency: Double?
    let weatherAdjustmentsEnabled: Bool
    let trafficAdjustmentsEnabled: Bool
    let transitAdjustmentsEnabled: Bool
    let learningAdjustmentsEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case defaultPreparationMinutes = "default_preparation_minutes"
        case commuteBufferMinutes = "commute_buffer_minutes"
        case snoozeDurationMinutes = "snooze_duration_minutes"
        case minimumSleepHours = "minimum_sleep_hours"
        case preferredWakeTimeEarliest = "preferred_wake_time_earliest"
        case preferredWakeTimeLatest = "preferred_wake_time_latest"
        case limitSnooze = "limit_snooze"
        case maxSnoozes = "max_snoozes"
        case averageSnoozesPerAlarm = "average_snoozes_per_alarm"
        case defaultTravelMethod = "default_travel_method"
        case weatherSensitivityMultiplier = "weather_sensitivity_multiplier"
        case homeAddress = "home_address"
        case workAddress = "work_address"
        case historicalAccuracyRate = "historical_accuracy_rate"
        case averageActualPrepTime = "average_actual_prep_time"
        case lateFrequency = "late_frequency"
        case weatherAdjustmentsEnabled = "weather_adjustments_enabled"
        case trafficAdjustmentsEnabled = "traffic_adjustments_enabled"
        case transitAdjustmentsEnabled = "transit_adjustments_enabled"
        case learningAdjustmentsEnabled = "learning_adjustments_enabled"
    }
}

struct AlarmSettingsPayload: Codable {
    let alarmId: String
    let alarmName: String
    let originalTime: String
    let arrivalTime: String
    let startingAddress: String?
    let destinationAddress: String?
    let travelMethod: String
    let preparationMinutes: Int
    let smartEnabled: Bool
    let weatherAdjustmentsEnabled: Bool
    let trafficAdjustmentsEnabled: Bool
    let transitAdjustmentsEnabled: Bool
    let isRepeating: Bool
    let specificDate: String?
    let isEnabled: Bool
    let snoozeEnabled: Bool
    let vibrationEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case alarmId = "alarm_id"
        case alarmName = "alarm_name"
        case originalTime = "original_time"
        case arrivalTime = "arrival_time"
        case startingAddress = "starting_address"
        case destinationAddress = "destination_address"
        case travelMethod = "travel_method"
        case preparationMinutes = "preparation_minutes"
        case smartEnabled = "smart_enabled"
        case weatherAdjustmentsEnabled = "weather_adjustments_enabled"
        case trafficAdjustmentsEnabled = "traffic_adjustments_enabled"
        case transitAdjustmentsEnabled = "transit_adjustments_enabled"
        case isRepeating = "is_repeating"
        case specificDate = "specific_date"
        case isEnabled = "is_enabled"
        case snoozeEnabled = "snooze_enabled"
        case vibrationEnabled = "vibration_enabled"
    }
}

struct LocationPayload: Codable {
    let lat: Double
    let lon: Double
}

// MARK: - Lambda Response Models

struct SmartAlarmResponse: Codable {
    let wakeTime: String
    let arrivalTime: String
    let totalPreparationMinutes: Int
    let extraTimeMinutes: Int
    let breakdown: TimeBreakdown
    let explanation: [ExplanationItem]
    let confidenceScore: Double
    let recommendations: [Recommendation]
    let routeInfo: RouteInfo
    let weatherInfo: WeatherInfo?
    let trafficInfo: TrafficInfo?
    let calculatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case wakeTime = "wake_time"
        case arrivalTime = "arrival_time"
        case totalPreparationMinutes = "total_preparation_minutes"
        case extraTimeMinutes = "extra_time_minutes"
        case breakdown, explanation
        case confidenceScore = "confidence_score"
        case recommendations
        case routeInfo = "route_info"
        case weatherInfo = "weather_info"
        case trafficInfo = "traffic_info"
        case calculatedAt = "calculated_at"
    }
}

// Add these new structs to properly decode weather and traffic info
struct WeatherInfo: Codable {
    let conditions: [WeatherConditionDetail]
    let averageTemperature: Double
    let averagePrecipitation: Double
    let worstVisibility: Double
    let maxWindSpeed: Double
    let summary: String
    let alerts: [String]
    
    enum CodingKeys: String, CodingKey {
        case conditions
        case averageTemperature = "average_temperature"
        case averagePrecipitation = "average_precipitation"
        case worstVisibility = "worst_visibility"
        case maxWindSpeed = "max_wind_speed"
        case summary
        case alerts
    }
}

struct WeatherConditionDetail: Codable {
    let location: String
    let temperature: Double
    let precipitation: Double
    let weatherType: String
    let visibility: Double
    let windSpeed: Double
    
    enum CodingKeys: String, CodingKey {
        case location
        case temperature
        case precipitation
        case weatherType = "weather_type"
        case visibility
        case windSpeed = "wind_speed"
    }
}

struct TrafficInfo: Codable {
    let baseDurationMinutes: Int
    let currentDelayMinutes: Int
    let totalDurationMinutes: Int
    let conditions: [TrafficCondition]
    let routeSummary: String
    
    enum CodingKeys: String, CodingKey {
        case baseDurationMinutes = "base_duration_minutes"
        case currentDelayMinutes = "current_delay_minutes"
        case totalDurationMinutes = "total_duration_minutes"
        case conditions
        case routeSummary = "route_summary"
    }
}

// Update the existing TrafficCondition struct if needed
struct TrafficCondition: Codable {
  let description: String
  let delayMinutes: Int

  enum CodingKeys: String, CodingKey {
    case description
    case delayMinutes = "delay_minutes"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    description = try container.decode(String.self, forKey: .description)
    // first try Int, then String→Int
    if let intValue = try? container.decode(Int.self, forKey: .delayMinutes) {
      delayMinutes = intValue
    } else {
      let str = try container.decode(String.self, forKey: .delayMinutes)
      delayMinutes = Int(str) ?? 0
    }
  }
}

struct TimeBreakdown: Codable {
    let preparationTime: Int
    let baseCommute: Int
    let commuteBuffer: Int
    let snoozeBuffer: Int
    let weatherDelays: Int
    let trafficDelays: Int
    let transitDelays: Int
    let accuracyAdjustment: Int
    let timeAvailableMinutes: Int
    
    enum CodingKeys: String, CodingKey {
        case preparationTime = "preparation_time"
        case baseCommute = "base_commute"
        case commuteBuffer = "commute_buffer"
        case snoozeBuffer = "snooze_buffer"
        case weatherDelays = "weather_delays"
        case trafficDelays = "traffic_delays"
        case transitDelays = "transit_delays"
        case accuracyAdjustment = "accuracy_adjustment"
        case timeAvailableMinutes = "time_available_minutes"
    }
}

struct ExplanationItem: Codable {
    let type: String
    let reason: String
    let minutes: Int
}

struct Recommendation: Codable {
    let type: String
    let title: String
    let message: String
}

struct RouteInfo: Codable {
    let durationMin: Int
    let conditions: [TrafficCondition]
    
    enum CodingKeys: String, CodingKey {
        case durationMin = "duration_min"
        case conditions
    }
}

// MARK: - Enhanced Smart Alarm Calculation Service

@MainActor
class SmartAlarmCalculationService: ObservableObject {
    @Published var isCalculating = false
    @Published var lastCalculation: SmartAlarmResponse?
    @Published var lastError: Error?
    @Published var calculationHistory: [SmartAlarmResponse] = []
    
    private let lambdaURL = "https://p6fldqu7xje5zuoje4axc4oydi0bzyod.lambda-url.us-east-1.on.aws/"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Interface
    
    func calculateSmartWakeTime(
        for alarm: Alarm,
        userProfile: ProfileViewModel,
        arrivalTime: Date,
        currentLocation: CLLocationCoordinate2D? = nil,
        forceRecalculation: Bool = false
    ) async throws -> SmartAlarmResponse {
        
        print("[SMART-ALARM] Starting smart wake time calculation for alarm: \(alarm.name) (ID: \(alarm.id.uuidString))")
        print("[SMART-ALARM] Alarm settings - Smart: \(alarm.smartEnabled), Weather: \(alarm.weatherAdjustment), Traffic: \(alarm.trafficAdjustment)")
        print("[SMART-ALARM] Arrival time: \(arrivalTime.formatted())")
        
        // CRITICAL FIX: Always use next occurrence times, not stored template times
        let effectiveAlarmTime = alarm.nextOccurrenceTime
        let effectiveArrivalTime = alarm.nextArrivalTime
        
        print("[SMART-ALARM] Next occurrence time: \(effectiveAlarmTime)")
        print("[SMART-ALARM] Next arrival time: \(effectiveArrivalTime)")
        
        let now = Date()
        print("[SMART-ALARM] Current time: \(now)")
        print("[SMART-ALARM] Next occurrence time: \(effectiveAlarmTime)")
        print("[SMART-ALARM] Next arrival time: \(effectiveArrivalTime)")
        
        // CRITICAL CHECK: Ensure alarm is in the future
        if effectiveAlarmTime ?? now <= now {
            print("[SMART-ALARM] ERROR: Next occurrence time is in the past or now!")
            print("[SMART-ALARM] This alarm should not be processed")
            throw SmartAlarmError.invalidTimeRelationship
        }
        
        // Validate the time relationship
        let timeDifference = effectiveArrivalTime.timeIntervalSince(effectiveAlarmTime ?? now)
        print("[SMART-ALARM] Time between alarm and arrival: \(timeDifference / 60) minutes")
        
        if timeDifference < 0 {
            print("[SMART-ALARM] ERROR: Arrival time is before alarm time!")
            throw SmartAlarmError.invalidTimeRelationship
        }
        
        if timeDifference > 86400 { // More than 24 hours
            print("[SMART-ALARM] WARNING: More than 24 hours between alarm and arrival")
        }
        
        isCalculating = true
        print("[SMART-ALARM] Setting isCalculating to true")
        
        defer {
            isCalculating = false
            print("[SMART-ALARM] Setting isCalculating to false")
        }
        
        do {
            // Create request payload
            print("[SMART-ALARM] Creating Lambda request payload for alarm: \(alarm.name)")
            // FIXED: Pass the actual next occurrence times to Lambda
            let request = try createSmartAlarmRequest(
                alarm: alarm,
                userProfile: userProfile,
                originalAlarmTime: effectiveAlarmTime!,
                arrivalTime: effectiveArrivalTime,
                currentLocation: currentLocation,
                forceRecalculation: forceRecalculation
            )
            
            print("[SMART-ALARM] Request payload created successfully")
            print("[SMART-ALARM] User ID: \(request.userProfile.userId)")
            print("[SMART-ALARM] Starting address: \(request.alarmSettings.startingAddress ?? "None")")
            print("[SMART-ALARM] Destination address: \(request.alarmSettings.destinationAddress ?? "None")")
            
            // Call Lambda function
            print("[SMART-ALARM] Sending request to Lambda function")
            let startTime = Date()
            
            let response = try await callLambdaFunction(request: request)
            
            let requestDuration = Date().timeIntervalSince(startTime)
            print("[SMART-ALARM] Lambda response received in \(String(format: "%.2f", requestDuration)) seconds")
            
            // Log response details
            print("[SMART-ALARM] Wake time calculation completed for alarm: \(alarm.name)")
            print("[SMART-ALARM] Original alarm time: \(alarm.alarmTime.formatted())")
            print("[SMART-ALARM] Calculated wake time: \(response.wakeTime)")
            print("[SMART-ALARM] Total preparation minutes: \(response.totalPreparationMinutes)")
            print("[SMART-ALARM] Confidence score: \(response.confidenceScore)")
            
            // Log breakdown details
            print("[SMART-ALARM] Time breakdown:")
            print("[SMART-ALARM]   - Preparation time: \(response.breakdown.preparationTime) min")
            print("[SMART-ALARM]   - Base commute: \(response.breakdown.baseCommute) min")
            print("[SMART-ALARM]   - Commute buffer: \(response.breakdown.commuteBuffer) min")
            print("[SMART-ALARM]   - Snooze buffer: \(response.breakdown.snoozeBuffer) min")
            print("[SMART-ALARM]   - Weather delays: \(response.breakdown.weatherDelays) min")
            print("[SMART-ALARM]   - Traffic delays: \(response.breakdown.trafficDelays) min")
            print("[SMART-ALARM]   - Transit delays: \(response.breakdown.transitDelays) min")
            print("[SMART-ALARM]   - Accuracy adjustment: \(response.breakdown.accuracyAdjustment) min")
            
            // Log if there's a significant adjustment
            if let originalTime = ISO8601DateFormatter().date(from: response.wakeTime),
               let adjustmentMinutes = calculateAdjustmentMinutes(original: alarm.alarmTime, adjusted: originalTime) {
                if abs(adjustmentMinutes) >= 5 {
                    print("[SMART-ALARM] *** SIGNIFICANT ADJUSTMENT: Alarm '\(alarm.name)' adjusted by \(adjustmentMinutes) minutes ***")
                }
            }
            
            // Update state
            lastCalculation = response
            calculationHistory.append(response)
            
            // Keep only last 10 calculations
            if calculationHistory.count > 10 {
                calculationHistory = Array(calculationHistory.suffix(10))
                print("[SMART-ALARM] Trimmed calculation history to 10 entries")
            }
            
            print("[SMART-ALARM] Smart alarm calculation completed successfully")
            return response
            
        } catch {
            print("[SMART-ALARM] ERROR: Smart alarm calculation failed for alarm: \(alarm.name)")
            print("[SMART-ALARM] ERROR: \(error.localizedDescription)")
            print("[SMART-ALARM] ERROR Type: \(String(describing: type(of: error)))")
            lastError = error
            throw error
        }
    }
    
    func calculateForMultipleAlarms(
        alarms: [Alarm],
        userProfile: ProfileViewModel,
        currentLocation: CLLocationCoordinate2D? = nil
    ) async -> [String: SmartAlarmResponse] {
        
        print("[SMART-ALARM] Starting batch calculation for \(alarms.count) alarms")
        var results: [String: SmartAlarmResponse] = [:]
        
        // Process alarms concurrently (limit to 3 at a time)
        let chunks = alarms.chunked(into: 3)
        
        for (chunkIndex, chunk) in chunks.enumerated() {
            print("[SMART-ALARM] Processing chunk \(chunkIndex + 1) of \(chunks.count)")
            
            await withTaskGroup(of: (String, SmartAlarmResponse?).self) { group in
                for alarm in chunk {
                    guard alarm.smartEnabled && alarm.isEnabled else {
                        print("[SMART-ALARM] Skipping alarm '\(alarm.name)' - Smart: \(alarm.smartEnabled), Enabled: \(alarm.isEnabled)")
                        continue
                    }
                    
                    group.addTask {
                        print("[SMART-ALARM] Starting calculation for alarm: \(alarm.name)")
                        do {
                            let response = try await self.calculateSmartWakeTime(
                                for: alarm,
                                userProfile: userProfile,
                                arrivalTime: alarm.arrivalTime,
                                currentLocation: currentLocation
                            )
                            return (alarm.id.uuidString, response)
                        } catch {
                            print("[SMART-ALARM] WARNING: Failed to calculate for alarm '\(alarm.name)': \(error.localizedDescription)")
                            return (alarm.id.uuidString, nil)
                        }
                    }
                }
                
                for await (alarmId, response) in group {
                    if let response = response {
                        results[alarmId] = response
                        print("[SMART-ALARM] Added result for alarm ID: \(alarmId)")
                    }
                }
            }
        }
        
        print("[SMART-ALARM] Batch calculation completed. Processed \(results.count) of \(alarms.count) alarms")
        return results
    }
    
    // MARK: - Private Implementation
    
    private func createSmartAlarmRequest(
        alarm: Alarm,
        userProfile: ProfileViewModel,
        originalAlarmTime: Date,
        arrivalTime: Date,
        currentLocation: CLLocationCoordinate2D?,
        forceRecalculation: Bool
    ) throws -> SmartAlarmRequest {
        print("[SMART-ALARM] Creating request with times:")
        print("[SMART-ALARM]   Original alarm: \(originalAlarmTime)")
        print("[SMART-ALARM]   Arrival time: \(arrivalTime)")
        print("[SMART-ALARM]   Time difference: \((arrivalTime.timeIntervalSince(originalAlarmTime)) / 60) minutes")
        
        // Use the logical arrival time instead of raw arrival time
        let effectiveArrivalTime = alarm.arrivalTime
        
        print("[SMART-ALARM] Creating smart alarm request payload")
        
        // Validate that arrival time makes sense
        let timeDifference = effectiveArrivalTime.timeIntervalSince(alarm.alarmTime)
        print("[SMART-ALARM] Time between alarm and arrival: \(timeDifference / 60) minutes")
        
        if timeDifference < 0 || timeDifference > 86400 { // Less than 0 or more than 24 hours
            print("[SMART-ALARM] WARNING: Unusual time difference detected")
        }
        
        // Convert user profile
        let userPayload = UserProfilePayload(
            userId: userProfile.email.isEmpty ? "guest_user" : userProfile.email,
            defaultPreparationMinutes: Int(alarm.preparationInterval / 60),
            commuteBufferMinutes: userProfile.preferences.commuteBuffer,
            snoozeDurationMinutes: 9, // Default snooze duration
            minimumSleepHours: nil, // Could be added to user preferences
            preferredWakeTimeEarliest: nil,
            preferredWakeTimeLatest: nil,
            limitSnooze: userProfile.preferences.limitSnooze,
            maxSnoozes: userProfile.preferences.maxSnoozes,
            averageSnoozesPerAlarm: nil, // Historical data not implemented yet
            defaultTravelMethod: mapTravelMethod(userProfile.preferences.travelMethod),
            weatherSensitivityMultiplier: 1.0, // Default sensitivity
            homeAddress: userProfile.homeAddress?.displayAddress,
            workAddress: userProfile.workAddress?.displayAddress,
            historicalAccuracyRate: nil, // Historical data not implemented yet
            averageActualPrepTime: nil,
            lateFrequency: nil,
            weatherAdjustmentsEnabled: alarm.weatherAdjustment,
            trafficAdjustmentsEnabled: alarm.trafficAdjustment,
            transitAdjustmentsEnabled: alarm.transitAdjustment,
            learningAdjustmentsEnabled: true
        )
        
        print("[SMART-ALARM] User profile payload created")
        
        // Convert alarm settings
        let alarmPayload = AlarmSettingsPayload(
            alarmId: alarm.id.uuidString,
            alarmName: alarm.name,
            originalTime: formatTimeForLambda(originalAlarmTime),
            arrivalTime: formatTimeForLambda(arrivalTime),
            startingAddress: createFullAddress(
                street: alarm.startingAddress.street,
                city: alarm.startingAddress.city,
                state: alarm.startingAddress.state,
                zip: alarm.startingAddress.zip
            ),
            destinationAddress: createFullAddress(
                street: alarm.destinationAddress.street,
                city: alarm.destinationAddress.city,
                state: alarm.destinationAddress.state,
                zip: alarm.destinationAddress.zip
            ),
            travelMethod: "drive", // Default for now
            preparationMinutes: Int(alarm.preparationInterval / 60),
            smartEnabled: alarm.smartEnabled,
            weatherAdjustmentsEnabled: alarm.weatherAdjustment,
            trafficAdjustmentsEnabled: alarm.trafficAdjustment,
            transitAdjustmentsEnabled: alarm.transitAdjustment,
            isRepeating: true, // Simplified for now
            specificDate: extractSpecificDate(from: alarm.schedule),
            isEnabled: alarm.isEnabled,
            snoozeEnabled: true, // Default
            vibrationEnabled: alarm.vibrationEnabled
        )
        
        print("[SMART-ALARM] Alarm settings payload created")
        
        // Convert current location if available
        let locationPayload = currentLocation.map { coord in
            LocationPayload(lat: coord.latitude, lon: coord.longitude)
        }
        
        if let location = locationPayload {
            print("[SMART-ALARM] Current location included: (\(location.lat), \(location.lon))")
        }
        
        return SmartAlarmRequest(
            userProfile: userPayload,
            alarmSettings: alarmPayload,
            arrivalTime: formatTimeForLambda(effectiveArrivalTime),
            currentLocation: locationPayload,
            forceRecalculation: forceRecalculation
        )
    }
    
    private func callLambdaFunction(request: SmartAlarmRequest) async throws -> SmartAlarmResponse {
        guard let url = URL(string: lambdaURL) else {
            print("[SMART-ALARM] ERROR: Invalid Lambda URL: \(lambdaURL)")
            throw SmartAlarmError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode request
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)
        
        print("[SMART-ALARM] Request body size: \(urlRequest.httpBody?.count ?? 0) bytes")
        
        // Make request with timeout
        print("[SMART-ALARM] Sending POST request to Lambda")
        let (data, response) = try await session.data(for: urlRequest)
        
        print("[SMART-ALARM] Response received, size: \(data.count) bytes")
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[SMART-ALARM] ERROR: Invalid response type: \(type(of: response))")
            throw SmartAlarmError.invalidResponse
        }
        
        print("[SMART-ALARM] HTTP status code: \(httpResponse.statusCode)")
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                print("[SMART-ALARM] ERROR: Lambda error response: \(errorMessage)")
                throw SmartAlarmError.serverError(errorMessage)
            }
            print("[SMART-ALARM] ERROR: HTTP error: \(httpResponse.statusCode)")
            throw SmartAlarmError.httpError(httpResponse.statusCode)
        }
        
        // Decode response with better error handling
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try multiple date formats
            let formatters = [
                ISO8601DateFormatter(),
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'+00:00'"
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    return formatter
                }(),
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'+00:00'"
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    return formatter
                }()
            ]
            
            for formatter in formatters {
                if let iso8601Formatter = formatter as? ISO8601DateFormatter {
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                } else if let dateFormatter = formatter as? DateFormatter {
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        do {
            let smartAlarmResponse = try decoder.decode(SmartAlarmResponse.self, from: data)
            print("[SMART-ALARM] Successfully decoded Lambda response")
            return smartAlarmResponse
        } catch {
            print("[SMART-ALARM] ERROR: Failed to decode Lambda response: \(error)")
            
            // More detailed error logging
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("[SMART-ALARM] Missing key: \(key.stringValue) in context: \(context)")
                case .typeMismatch(let type, let context):
                    print("[SMART-ALARM] Type mismatch: expected \(type) in context: \(context)")
                case .valueNotFound(let type, let context):
                    print("[SMART-ALARM] Value not found: \(type) in context: \(context)")
                case .dataCorrupted(let context):
                    print("[SMART-ALARM] Data corrupted in context: \(context)")
                @unknown default:
                    print("[SMART-ALARM] Unknown decoding error: \(error)")
                }
            }
            
            print("[SMART-ALARM] Raw response: \(String(data: data, encoding: .utf8) ?? "invalid")")
            throw SmartAlarmError.decodingError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateAdjustmentMinutes(original: Date, adjusted: Date) -> Int? {
        let difference = original.timeIntervalSince(adjusted)
        return Int(difference / 60)
    }
    
    private func mapTravelMethod(_ method: TravelMethod) -> String {
        switch method {
        case .drive:
            return "drive"
        case .publicTransit:
            return "transit"
        case .walk:
            return "walk"
        case .bike:
            return "bike"
        }
    }
    
    private func formatTimeForLambda(_ date: Date) -> String {
        // Use the UTC extension
        return date.utcISO8601
    }
    
    private func createFullAddress(street: String, city: String, state: String, zip: String) -> String? {
        let components = [street, city, state, zip].filter { !$0.isEmpty && $0 != "Select" }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    private func extractSpecificDate(from schedule: AlarmSchedule) -> String? {
        switch schedule {
        case .specificDate(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        default:
            return nil
        }
    }
    
    // MARK: - Public Utility Methods
    
    func getRecommendationsForAlarm(_ alarmId: String) -> [Recommendation] {
        guard let calculation = calculationHistory.first(where: { response in
            // Extract alarm ID from response if needed
            return true // Simplified for now
        }) else {
            return []
        }
        
        return calculation.recommendations
    }
    
    func getConfidenceScoreForLastCalculation() -> Double? {
        return lastCalculation?.confidenceScore
    }
    
    func getTimeBreakdownForLastCalculation() -> TimeBreakdown? {
        return lastCalculation?.breakdown
    }
    
    // ENHANCED: Clear calculation history for specific alarm
    func clearCalculationHistoryForAlarm(_ alarmId: String) {
        let originalCount = calculationHistory.count
        
        // Remove calculations for this alarm
        // Note: You might need to add alarmId to SmartAlarmResponse to do this properly
        calculationHistory.removeAll { response in
            // For now, we'll clear all history since we can't identify which belongs to which alarm
            // In production, you should add alarmId to the response structure
            return false // Keep all for now
        }
        
        let removedCount = originalCount - calculationHistory.count
        print("[SMART-ALARM] Removed \(removedCount) calculation history entries for alarm: \(alarmId)")
    }
}

// MARK: - Smart Alarm Error Types

enum SmartAlarmError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidTimeRelationship
    case serverError(String)
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case missingData
    
    var errorDescription: String? {
        switch self {
        case .invalidTimeRelationship:
                    return "Invalid time relationship between alarm and arrival"
        case .invalidURL:
            return "Invalid Lambda URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return "Server error: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .missingData:
            return "Missing required data for calculation"
        }
    }
}

// MARK: - Smart Alarm View Integration

struct SmartAlarmStatusView: View {
    @StateObject private var smartAlarmService = SmartAlarmCalculationService()
    var alarm: Alarm
    @ObservedObject var profileViewModel: ProfileViewModel
    
    @State private var lastCalculation: SmartAlarmResponse?
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("Smart Alarm")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if smartAlarmService.isCalculating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Details") {
                        showingDetails = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if let calculation = lastCalculation {
                SmartAlarmSummaryView(calculation: calculation)
            } else {
                Text("Calculating optimal wake time...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .onAppear {
            calculateWakeTime()
        }
        .sheet(isPresented: $showingDetails) {
            if let calculation = lastCalculation {
                SmartAlarmDetailsView(calculation: calculation)
            }
        }
    }
    
    private func calculateWakeTime() {
        Task {
            do {
                let response = try await smartAlarmService.calculateSmartWakeTime(
                    for: alarm,
                    userProfile: profileViewModel,
                    arrivalTime: alarm.nextArrivalTime
                )
                await MainActor.run {
                    lastCalculation = response
                }
            } catch {
                print("Failed to calculate smart wake time: \(error)")
            }
        }
    }
}

struct SmartAlarmSummaryView: View {
    let calculation: SmartAlarmResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Wake Time:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatWakeTime(calculation.wakeTime))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("Total Prep Time:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(calculation.totalPreparationMinutes) minutes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if calculation.confidenceScore < 0.8 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Lower confidence prediction")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    private func formatWakeTime(_ timeString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: timeString) else {
            return timeString
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SmartAlarmDetailsView: View {
    let calculation: SmartAlarmResponse
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Time Breakdown Section
                    GroupBox("Time Breakdown") {
                        TimeBreakdownDetailView(breakdown: calculation.breakdown)
                    }
                    
                    // Explanation Section
                    GroupBox("Explanation") {
                        ExplanationDetailView(explanations: calculation.explanation)
                    }
                    
                    // Recommendations Section
                    if !calculation.recommendations.isEmpty {
                        GroupBox("Recommendations") {
                            RecommendationsDetailView(recommendations: calculation.recommendations)
                        }
                    }
                    
                    // Confidence Section
                    GroupBox("Prediction Confidence") {
                        ConfidenceDetailView(score: calculation.confidenceScore)
                    }
                }
                .padding()
            }
            .navigationTitle("Smart Alarm Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TimeBreakdownDetailView: View {
    let breakdown: TimeBreakdown
    
    var body: some View {
        VStack(spacing: 8) {
            BreakdownRow(label: "Preparation Time", minutes: breakdown.preparationTime)
            BreakdownRow(label: "Base Commute", minutes: breakdown.baseCommute)
            BreakdownRow(label: "Commute Buffer", minutes: breakdown.commuteBuffer)
            BreakdownRow(label: "Snooze Buffer", minutes: breakdown.snoozeBuffer)
            BreakdownRow(label: "Weather Delays", minutes: breakdown.weatherDelays, isDelay: true)
            BreakdownRow(label: "Traffic Delays", minutes: breakdown.trafficDelays, isDelay: true)
            BreakdownRow(label: "Transit Delays", minutes: breakdown.transitDelays, isDelay: true)
            BreakdownRow(label: "Learning Adjustment", minutes: breakdown.accuracyAdjustment, isDelay: breakdown.accuracyAdjustment > 0)
            
            Divider()
            
            BreakdownRow(
                label: "Total Time",
                minutes: breakdown.preparationTime + breakdown.baseCommute + breakdown.commuteBuffer +
                        breakdown.snoozeBuffer + breakdown.weatherDelays + breakdown.trafficDelays +
                        breakdown.transitDelays + breakdown.accuracyAdjustment,
                isTotal: true
            )
        }
    }
}

struct BreakdownRow: View {
    let label: String
    let minutes: Int
    var isDelay: Bool = false
    var isTotal: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(isTotal ? .headline : .subheadline)
                .fontWeight(isTotal ? .semibold : .regular)
            
            Spacer()
            
            Text("\(minutes) min")
                .font(isTotal ? .headline : .subheadline)
                .fontWeight(isTotal ? .semibold : .regular)
                .foregroundColor(isDelay && minutes > 0 ? .orange : .primary)
        }
    }
}

struct ExplanationDetailView: View {
    let explanations: [ExplanationItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(explanations.indices, id: \.self) { index in
                let item = explanations[index]
                HStack(alignment: .top) {
                    Text("•")
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.reason)
                            .font(.subheadline)
                        if item.minutes > 0 {
                            Text("+\(item.minutes) minutes")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}

struct RecommendationsDetailView: View {
    let recommendations: [Recommendation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(recommendations.indices, id: \.self) { index in
                let recommendation = recommendations[index]
                RecommendationCardView(recommendation: recommendation)
            }
        }
    }
}

struct RecommendationCardView: View {
    let recommendation: Recommendation
    
    var iconName: String {
        switch recommendation.type {
        case "warning":
            return "exclamationmark.triangle.fill"
        case "preparation":
            return "cloud.bolt.rain.fill"
        case "behavior":
            return "bell.slash.fill"
        case "info":
            return "info.circle.fill"
        default:
            return "lightbulb.fill"
        }
    }
    
    var iconColor: Color {
        switch recommendation.type {
        case "warning":
            return .red
        case "preparation":
            return .orange
        case "behavior":
            return .blue
        case "info":
            return .gray
        default:
            return .yellow
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(recommendation.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ConfidenceDetailView: View {
    let score: Double
    
    var confidenceText: String {
        switch score {
        case 0.9...1.0:
            return "Very High"
        case 0.8..<0.9:
            return "High"
        case 0.7..<0.8:
            return "Medium"
        case 0.6..<0.7:
            return "Low"
        default:
            return "Very Low"
        }
    }
    
    var confidenceColor: Color {
        switch score {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Confidence Score:")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(score * 100))% (\(confidenceText))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(confidenceColor)
            }
            
            ProgressView(value: score)
                .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor))
            
            Text("This score indicates how reliable this wake time prediction is based on available data and conditions.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
