// AlarmStore.swift - Complete Fix

import Foundation
import Combine

class AlarmStore: ObservableObject {
    @Published var showingAddModal = false
    
    @Published var alarms: [Alarm] = [] {
        didSet {
            // Save whenever alarms change
            save()
        }
    }
    
    private let storageKey = "alarms_v3"
    
    init() {
        load()
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
    
    // MARK: - CRUD Operations
    func add(_ alarm: Alarm) {
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
        } catch {
            print("[ALARM-STORE] ERROR: Failed to load alarms: \(error)")
            // Clear corrupted data
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}
