// AlarmStore.swift - Complete Fix

import Foundation
import Combine
import UIKit

class AlarmStore: ObservableObject {
    @Published var showingAddModal = false
    
    @Published var alarms: [Alarm] = [] {
        didSet {
            // Enforce 50 alarm limit
            if alarms.count > 50 {
                print("[ALARM-STORE] WARNING: Exceeding 50 alarm limit. Current count: \(alarms.count)")
            }
            save()
        }
    }
    
    private let storageKey = "alarms_v3"
    private var lifecycleTimer: Timer?
    private let maxAlarmCount = 50
    
    init() {
        load()
        startLifecycleManagement()
        setupNotificationObservers()
    }
    
    deinit {
        lifecycleTimer?.invalidate()
    }
    
    var sortedAlarms: [Alarm] {
        alarms.sorted { alarm1, alarm2 in
            let calendar = Calendar.current
            let time1 = calendar.dateComponents([.hour, .minute], from: alarm1.alarmTime)
            let time2 = calendar.dateComponents([.hour, .minute], from: alarm2.alarmTime)

            let minutes1 = (time1.hour ?? 0) * 60 + (time1.minute ?? 0)
            let minutes2 = (time2.hour ?? 0) * 60 + (time2.minute ?? 0)

            return minutes1 < minutes2
        }
    }
    
    var canAddMoreAlarms: Bool {
        alarms.count < maxAlarmCount
    }
    
    // MARK: - Lifecycle Management
    
    private func startLifecycleManagement() {
        // Check every minute for expired alarms
        lifecycleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkAndUpdateExpiredAlarms()
        }
        
        // Initial check
        checkAndUpdateExpiredAlarms()
    }
    
    private func setupNotificationObservers() {
        // Listen for app becoming active to check expired alarms
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appBecameActive() {
        checkAndUpdateExpiredAlarms()
    }
    
    private func checkAndUpdateExpiredAlarms() {
        let now = Date()
        var hasChanges = false
        
        // Process alarms in a single pass
        var updatedAlarms = alarms
        var alarmsToRemove: [UUID] = []
        
        for (index, alarm) in updatedAlarms.enumerated() {
            switch alarm.schedule {
            case .oneTime:
                // Remove one-time alarms 5 minutes after they should have fired
                if let nextOccurrence = alarm.nextOccurrenceTime {
                    let fiveMinutesAfter = nextOccurrence.addingTimeInterval(5 * 60)
                    if now > fiveMinutesAfter {
                        alarmsToRemove.append(alarm.id)
                        hasChanges = true
                        print("[ALARM-STORE] Marking one-time alarm for removal: \(alarm.name)")
                    }
                } else if alarm.alarmTime.addingTimeInterval(5 * 60) < now {
                    // Fallback check using alarmTime
                    alarmsToRemove.append(alarm.id)
                    hasChanges = true
                    print("[ALARM-STORE] Marking expired one-time alarm for removal: \(alarm.name)")
                }
                
            case .specificDate(let date):
                // Disable specific date alarms that have passed
                if alarm.isEnabled {
                    let alarmDateTime = combineDateTime(date: date, time: alarm.alarmTime)
                    if now > alarmDateTime {
                        updatedAlarms[index].isEnabled = false
                        hasChanges = true
                        print("[ALARM-STORE] Disabling expired specific date alarm: \(alarm.name)")
                    }
                }
                
            case .repeatingDays:
                // Repeating alarms don't expire
                break
            }
        }
        
        // Remove one-time alarms
        if !alarmsToRemove.isEmpty {
            updatedAlarms.removeAll { alarmsToRemove.contains($0.id) }
            
            // Post notifications for removed alarms
            for alarmId in alarmsToRemove {
                NotificationCenter.default.post(
                    name: .alarmDeleted,
                    object: nil,
                    userInfo: ["alarmId": alarmId.uuidString]
                )
            }
        }
        
        // Update if changes were made
        if hasChanges {
            DispatchQueue.main.async {
                self.alarms = updatedAlarms
                self.objectWillChange.send()
            }
        }
    }
    
    private func combineDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second
        
        return calendar.date(from: combined) ?? date
    }
    
    // MARK: - CRUD Operations
    func add(_ alarm: Alarm) {
        guard canAddMoreAlarms else {
            print("[ALARM-STORE] ERROR: Cannot add alarm. Maximum of \(maxAlarmCount) alarms reached.")
            NotificationCenter.default.post(
                name: .alarmLimitReached,
                object: nil
            )
            return
        }
        
        DispatchQueue.main.async {
            self.alarms.append(alarm)
            print("[ALARM-STORE] Added alarm: \(alarm.name) (ID: \(alarm.id))")
            
            // Force UI update
            self.objectWillChange.send()
        }
    }
    
    func update(_ alarm: Alarm, fromCreation: Bool = false) {
        // Find index safely
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else {
            print("[ALARM-STORE] ERROR: Could not find alarm to update: \(alarm.id)")
            return
        }
        
        // Check bounds before updating
        guard alarms.indices.contains(index) else {
            print("[ALARM-STORE] ERROR: Index out of bounds")
            return
        }
        
        // Update on main thread
        DispatchQueue.main.async {
            // Double-check the alarm still exists
            guard self.alarms.indices.contains(index),
                  index < self.alarms.count,
                  self.alarms[index].id == alarm.id else {
                print("[ALARM-STORE] ERROR: Alarm no longer exists at index during update")
                return
            }
            
            self.alarms[index] = alarm
            print("[ALARM-STORE] Updated alarm: \(alarm.name) (ID: \(alarm.id))")
            
            // Post notification with flags
            let skipWeatherRefresh = alarm.currentAdjustment != nil
            NotificationCenter.default.post(
                name: .alarmUpdated,
                object: alarm,
                userInfo: [
                    "skipWeatherRefresh": skipWeatherRefresh,
                    "alarmId": alarm.id.uuidString,
                    "fromCreation": fromCreation
                ]
            )
        }
    }
    
    func delete(_ alarm: Alarm) {
        // Cancel any pending operations first
        NotificationCenter.default.post(
            name: Notification.Name("CancelOperationsForAlarm"),
            object: nil,
            userInfo: ["alarmId": alarm.id]
        )
        
        // Remove immediately on main thread
        DispatchQueue.main.async {
            self.alarms.removeAll { $0.id == alarm.id }
            print("[ALARM-STORE] Deleted alarm: \(alarm.name) (ID: \(alarm.id))")
            
            // Force UI update
            self.objectWillChange.send()
            
            // Post deletion notification
            NotificationCenter.default.post(
                name: .alarmDeleted,
                object: alarm,
                userInfo: ["alarmId": alarm.id.uuidString]
            )
        }
    }
    
    func deleteAll() {
        alarms.removeAll()
        print("[ALARM-STORE] Deleted all alarms")
    }
    
    // MARK: - Persistence
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(alarms)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("[ALARM-STORE] Saved \(alarms.count) alarms")
        } catch {
            print("[ALARM-STORE] ERROR: Failed to save alarms: \(error)")
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("[ALARM-STORE] No saved alarms found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            alarms = try decoder.decode([Alarm].self, from: data)
            print("[ALARM-STORE] Loaded \(alarms.count) alarms")
            
            // Check for expired alarms immediately after loading
            checkAndUpdateExpiredAlarms()
        } catch {
            print("[ALARM-STORE] ERROR: Failed to load alarms: \(error)")
            // Clear corrupted data
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}

// MARK: - New Notification Names
extension Notification.Name {
    static let alarmLimitReached = Notification.Name("alarmLimitReached")
}
