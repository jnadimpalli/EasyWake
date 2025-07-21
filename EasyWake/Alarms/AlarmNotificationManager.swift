// AlarmNotificationManager.swift

import Foundation
import UserNotifications

class AlarmNotificationManager {
    
    init() {
        setupNotificationCategories()
    }
    
    private func setupNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze",
            options: []
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )
        
        let alarmCategory = UNNotificationCategory(
            identifier: "ALARM",
            actions: [snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([alarmCategory])
    }
    
    func scheduleAdjustedAlarm(_ alarm: Alarm, adjustment: AlarmAdjustment) async {
        guard alarm.isEnabled else {
            print("[NOTIFICATION-MANAGER] Alarm is disabled, not scheduling: \(alarm.name)")
            return
        }
        
        // Use the adjusted wake time from the adjustment
        let wakeTime = adjustment.adjustedWakeTime
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = alarm.name
        content.body = "Wake up \(abs(adjustment.adjustmentMinutes)) min \(adjustment.adjustmentMinutes > 0 ? "earlier" : "later") due to conditions"
        content.subtitle = adjustment.reason
        
        // Set sound
        if alarm.soundTone == "None" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(alarm.soundTone))
        }
        
        content.categoryIdentifier = "ALARM"
        content.threadIdentifier = alarm.id.uuidString
        
        // Create trigger based on adjusted time
        let timeInterval = wakeTime.timeIntervalSinceNow
        guard timeInterval > 0 else {
            print("[NOTIFICATION-MANAGER] Adjusted wake time is in the past, not scheduling")
            return
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[NOTIFICATION-MANAGER] Scheduled adjusted notification for alarm: \(alarm.name)")
        } catch {
            print("[NOTIFICATION-MANAGER] ERROR: Failed to schedule notification: \(error)")
        }
    }
    
    func scheduleAlarm(_ alarm: Alarm) async {
        guard alarm.isEnabled else {
            print("[NOTIFICATION-MANAGER] Alarm is disabled, not scheduling: \(alarm.name)")
            return
        }
        
        // Check if we already have a notification scheduled with the same wake time
        let existingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let alarmIdentifiers = [alarm.id.uuidString] + Weekday.allCases.map { "\(alarm.id.uuidString)-\($0.rawValue)" }
        
        let hasExistingNotification = existingRequests.contains { request in
            alarmIdentifiers.contains(request.identifier)
        }
        
        if hasExistingNotification {
            print("[NOTIFICATION-MANAGER] Notification already scheduled for alarm: \(alarm.name)")
            return
        }
        
        // Determine wake time
        let wakeTime: Date
        if alarm.smartEnabled, let adjustment = alarm.currentAdjustment {
            wakeTime = adjustment.adjustedWakeTime
            print("[NOTIFICATION-MANAGER] Using adjusted wake time for smart alarm")
        } else if let nextOccurrence = alarm.nextOccurrenceTime {
            wakeTime = nextOccurrence
        } else {
            print("[NOTIFICATION-MANAGER] No valid wake time for alarm: \(alarm.name)")
            return
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = alarm.name
        
        if alarm.smartEnabled, let adjustment = alarm.currentAdjustment {
            content.body = "Wake up \(abs(adjustment.adjustmentMinutes)) min \(adjustment.adjustmentMinutes > 0 ? "earlier" : "later") due to conditions"
            content.subtitle = adjustment.reason
        } else {
            content.body = "Time to wake up!"
        }
        
        // Set sound
        if alarm.soundTone == "None" {
            content.sound = nil
        } else {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(alarm.soundTone))
        }
        
        content.categoryIdentifier = "ALARM"
        content.threadIdentifier = alarm.id.uuidString
        
        // Create trigger based on schedule
        let trigger: UNNotificationTrigger
        
        switch alarm.schedule {
        case .oneTime, .specificDate:
            // One-time trigger
            let timeInterval = wakeTime.timeIntervalSinceNow
            guard timeInterval > 0 else {
                print("[NOTIFICATION-MANAGER] Wake time is in the past, not scheduling")
                return
            }
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            
        case .repeatingDays(let days):
            // Repeating trigger
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: wakeTime)
            
            // For repeating alarms, we need to schedule multiple notifications (one per day)
            for day in days {
                var dateComponents = DateComponents()
                dateComponents.hour = components.hour
                dateComponents.minute = components.minute
                dateComponents.weekday = weekdayNumber(for: day)
                
                let dayTrigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: true
                )
                
                let request = UNNotificationRequest(
                    identifier: "\(alarm.id.uuidString)-\(day.rawValue)",
                    content: content,
                    trigger: dayTrigger
                )
                
                do {
                    try await UNUserNotificationCenter.current().add(request)
                    print("[NOTIFICATION-MANAGER] Scheduled repeating notification for \(day.rawValue)")
                } catch {
                    print("[NOTIFICATION-MANAGER] ERROR: Failed to schedule notification: \(error)")
                }
            }
            return
        }
        
        // Schedule one-time notification
        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[NOTIFICATION-MANAGER] Scheduled notification for alarm: \(alarm.name)")
        } catch {
            print("[NOTIFICATION-MANAGER] ERROR: Failed to schedule notification: \(error)")
        }
    }
    
    func cancelAlarm(with id: UUID) async {
        // Remove base notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [id.uuidString]
        )
        
        // Remove any day-specific notifications for repeating alarms
        let dayIdentifiers = Weekday.allCases.map { "\(id.uuidString)-\($0.rawValue)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: dayIdentifiers
        )
        
        print("[NOTIFICATION-MANAGER] Cancelled notifications for alarm: \(id)")
    }
    
    private func weekdayNumber(for day: Weekday) -> Int {
        switch day {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}
