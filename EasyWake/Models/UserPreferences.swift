// Models/UserPreferences.swift
import Foundation

struct UserPreferences: Codable {
    var clockFormat24h: Bool = false
    var travelMethod: TravelMethod = .drive
    var commuteBuffer: Int = 10 // minutes
    
    // Notifications
    var pushNotificationsEnabled: Bool = true
    var weatherAlertsEnabled: Bool = true
    var trafficAlertsEnabled: Bool = false // Premium
    var calendarRemindersEnabled: Bool = false // Premium
    
    // Sleep & Bedtime
    var bedtimeReminderEnabled: Bool = false
    var bedtimeReminderTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    var sleepCycleRecommendationsEnabled: Bool = false
    
    // Integrations
    var calendarSyncEnabled: Bool = false // Premium
    var siriShortcutsEnabled: Bool = false // Premium
    var smartHomeEnabled: Bool = false // Post-MVP
}
