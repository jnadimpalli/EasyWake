// WeatherAlertModels.swift

import Foundation
import SwiftUI

// MARK: - Weather Alert Models
struct WeatherAlertData: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let severity: AlertSeverity
    let alertType: AlertType
    let startTime: Date
    let endTime: Date
    let issuingAuthority: String
    let url: String?
    let affectedAreas: [String]
    
    var isActive: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }
    
    var isExpired: Bool {
        Date() > endTime.addingTimeInterval(3600) // 1 hour grace period
    }
    
    var timeRemaining: String {
        let now = Date()
        if now < startTime {
            return "Starts \(RelativeDateTimeFormatter().localizedString(for: startTime, relativeTo: now))"
        } else if now < endTime {
            return "Until \(RelativeDateTimeFormatter().localizedString(for: endTime, relativeTo: now))"
        } else {
            return "Expired"
        }
    }
    
    var effectiveTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        let calendar = Calendar.current
        if calendar.isDate(startTime, inSameDayAs: endTime) {
            return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
        } else {
            formatter.dateStyle = .short
            return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
        }
    }
}

enum AlertSeverity: String, Codable, CaseIterable {
    case advisory = "advisory"
    case watch = "watch"
    case warning = "warning"
    case emergency = "emergency"
    
    var displayName: String {
        switch self {
        case .advisory: return "ADVISORY"
        case .watch: return "WATCH"
        case .warning: return "WARNING"
        case .emergency: return "EMERGENCY"
        }
    }
    
    var priority: Int {
        switch self {
        case .emergency: return 4
        case .warning: return 3
        case .watch: return 2
        case .advisory: return 1
        }
    }
    
    var borderColor: Color {
        switch self {
        case .advisory: return .primary
        case .watch: return .primary
        case .warning: return .primary
        case .emergency: return .primary
        }
    }
    
    var icon: String {
        switch self {
        case .advisory: return "info.circle.fill"
        case .watch: return "eye.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .emergency: return "exclamationmark.octagon.fill"
        }
    }
}

enum AlertType: String, Codable {
    case flood = "flood"
    case tornado = "tornado"
    case thunderstorm = "thunderstorm"
    case winter = "winter"
    case heat = "heat"
    case wind = "wind"
    case fire = "fire"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .flood: return "Flood"
        case .tornado: return "Tornado"
        case .thunderstorm: return "Thunderstorm"
        case .winter: return "Winter Weather"
        case .heat: return "Heat"
        case .wind: return "Wind"
        case .fire: return "Fire Weather"
        case .general: return "Weather"
        }
    }
    
    var icon: String {
        switch self {
        case .flood: return "drop.fill"
        case .tornado: return "tornado"
        case .thunderstorm: return "cloud.bolt.fill"
        case .winter: return "snow"
        case .heat: return "thermometer.sun.fill"
        case .wind: return "wind"
        case .fire: return "flame.fill"
        case .general: return "cloud.fill"
        }
    }
}

// MARK: - Weather Alert Manager
@MainActor
class WeatherAlertManager: ObservableObject {
    @Published var activeAlerts: [WeatherAlertData] = []
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    
    private let maxVisibleAlerts = 3
    private var alertUpdateTimer: Timer?
    
    init() {
        startPeriodicUpdates()
        // Load mock data for development
        loadMockAlerts()
    }
    
    deinit {
        alertUpdateTimer?.invalidate()
    }
    
    var sortedAlerts: [WeatherAlertData] {
        activeAlerts
            .filter { !$0.isExpired }
            .sorted { first, second in
                if first.severity.priority != second.severity.priority {
                    return first.severity.priority > second.severity.priority
                }
                return first.startTime < second.startTime
            }
    }
    
    var visibleAlerts: [WeatherAlertData] {
        Array(sortedAlerts.prefix(maxVisibleAlerts))
    }
    
    var additionalAlertsCount: Int {
        max(0, sortedAlerts.count - maxVisibleAlerts)
    }
    
    func refreshAlerts() async {
        isLoading = true
        
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // In real implementation, fetch from weather API
            await fetchAlertsFromAPI()
            
            lastUpdated = Date()
        } catch {
            print("Failed to refresh alerts: \(error)")
        }
        
        isLoading = false
    }
    
    func dismissAlert(_ alert: WeatherAlertData) {
        withAnimation(.easeInOut(duration: 0.3)) {
            activeAlerts.removeAll { $0.id == alert.id }
        }
    }
    
    private func startPeriodicUpdates() {
        alertUpdateTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { _ in
            Task {
                await self.refreshAlerts()
            }
        }
    }
    
    private func fetchAlertsFromAPI() async {
        // TODO: Implement actual weather alert API integration
        // For now, update mock data
        DispatchQueue.main.async {
            self.loadMockAlerts()
        }
    }
    
    private func loadMockAlerts() {
        let now = Date()
        let calendar = Calendar.current
        
        activeAlerts = [
            WeatherAlertData(
                title: "Flood Watch",
                description: "Flooding caused by excessive rainfall is possible. Low-lying and poor drainage areas are the most likely to experience flooding.",
                severity: .watch,
                alertType: .flood,
                startTime: now,
                endTime: calendar.date(byAdding: .hour, value: 6, to: now) ?? now,
                issuingAuthority: "National Weather Service",
                url: "https://weatherkit.apple.com/alertDetails/flood-watch",
                affectedAreas: ["McLean", "Great Falls", "Vienna"]
            ),
            WeatherAlertData(
                title: "Severe Thunderstorm Warning",
                description: "Damaging winds and large hail are possible with this storm. Seek shelter immediately if threatening weather approaches.",
                severity: .warning,
                alertType: .thunderstorm,
                startTime: calendar.date(byAdding: .hour, value: 2, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 4, to: now) ?? now,
                issuingAuthority: "National Weather Service",
                url: nil,
                affectedAreas: ["McLean", "Fairfax County"]
            )
        ]
    }
}
