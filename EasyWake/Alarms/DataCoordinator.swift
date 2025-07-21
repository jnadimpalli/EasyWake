// DataCoordinator.swift

import Foundation
import SwiftUI

@MainActor
class DataCoordinator: ObservableObject {
    private let alarmStore: AlarmStore
    private let smartAlarmService: SmartAlarmCalculationService
    private let notificationManager: AlarmNotificationManager
    private let profileViewModel: ProfileViewModel
    private weak var weatherAlarmService: WeatherAlarmService?
    private var isUpdatingAdjustment = false
    
    // Track which alarms are currently being processed
    private var alarmsBeingProcessed = Set<UUID>()
    private var deletingAlarms = Set<UUID>()
    
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    
    init(
        alarmStore: AlarmStore,
        profileViewModel: ProfileViewModel
    ) {
        self.alarmStore = alarmStore
        self.profileViewModel = profileViewModel
        self.smartAlarmService = SmartAlarmCalculationService()
        self.notificationManager = AlarmNotificationManager()
        
        // Listen for cancellation requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cancelOperations),
            name: Notification.Name("CancelOperationsForAlarm"),
            object: nil
        )
    }
    
    @objc private func cancelOperations(_ notification: Notification) {
        if let alarmId = notification.userInfo?["alarmId"] as? UUID {
            // Cancel any active task for this alarm
            activeTasks[alarmId]?.cancel()
            activeTasks.removeValue(forKey: alarmId)
            alarmsBeingProcessed.remove(alarmId)
        }
    }
    
    func setWeatherAlarmService(_ service: WeatherAlarmService) {
        self.weatherAlarmService = service
    }
    
    private func scheduleNotifications(for alarm: Alarm) async {
        // Cancel old notifications first
        await notificationManager.cancelAlarm(with: alarm.id)
        
        // Schedule new ones based on current state
        if alarm.isEnabled {
            if alarm.smartEnabled, let adjustment = alarm.currentAdjustment {
                // Schedule adjusted notification
                await notificationManager.scheduleAdjustedAlarm(alarm, adjustment: adjustment)
            } else {
                // Schedule regular notification
                await notificationManager.scheduleAlarm(alarm)
            }
        }
    }
    
    // MARK: - CREATE
    func createAlarm(_ alarm: Alarm) async {
        print("[DATA-COORDINATOR] Creating alarm: \(alarm.name)")
        
        // 1. Validate alarm data
        guard validateAlarm(alarm) else {
            print("[DATA-COORDINATOR] ERROR: Invalid alarm data")
            return
        }
        
        // 2. Add to store (source of truth)
        alarmStore.add(alarm)
        
        // 3. Calculate initial adjustment if smart alarm
        if alarm.smartEnabled && alarm.isEnabled {
            await calculateAndStoreAdjustment(for: alarm)
        }
        
        // 4. Schedule notifications
        await notificationManager.scheduleAlarm(alarm)
        
        // 5. Post notification for any listeners
        NotificationCenter.default.post(
            name: .alarmCreated,
            object: nil,
            userInfo: ["alarm": alarm]
        )
        
        print("[DATA-COORDINATOR] Successfully created alarm: \(alarm.name)")
    }
    
    // MARK: - UPDATE
    func updateAlarm(_ alarm: Alarm, skipAdjustmentCalculation: Bool = false) async {
        // Check if alarm still exists
        guard alarmStore.alarms.contains(where: { $0.id == alarm.id }) else {
            print("[DATA-COORDINATOR] Alarm no longer exists, skipping update")
            return
        }
        
        print("[DATA-COORDINATOR] Updating alarm: \(alarm.name) (skip adjustment: \(skipAdjustmentCalculation))")
                
        // 1. Validate alarm data
        guard validateAlarm(alarm) else {
            print("[DATA-COORDINATOR] ERROR: Invalid alarm data")
            return
        }
        
        // 2. Cancel old notifications
        await notificationManager.cancelAlarm(with: alarm.id)
        
        // 3. Update in store (source of truth)
        alarmStore.update(alarm)
        
        // 4. Only calculate adjustment if:
        //    - Not explicitly skipped
        //    - Not already being processed
        //    - Smart alarm is enabled
        if !skipAdjustmentCalculation &&
           !alarmsBeingProcessed.contains(alarm.id) &&
           alarm.smartEnabled &&
           alarm.isEnabled {
            
            alarmsBeingProcessed.insert(alarm.id)
            
            // Store the task so we can cancel it if needed
            let task = Task {
                await calculateAndStoreAdjustment(for: alarm)
                alarmsBeingProcessed.remove(alarm.id)
                activeTasks.removeValue(forKey: alarm.id)
            }
            activeTasks[alarm.id] = task
        }
    }
    
    // MARK: - DELETE
    func deleteAlarm(_ alarm: Alarm) async {
        print("[DATA-COORDINATOR] Deleting alarm: \(alarm.name) (ID: \(alarm.id))")
        
        // 1. Mark alarm as being deleted to prevent any new operations
        deletingAlarms.insert(alarm.id)
        
        // 2. Cancel any active operations for this alarm
        activeTasks[alarm.id]?.cancel()
        activeTasks.removeValue(forKey: alarm.id)
        alarmsBeingProcessed.remove(alarm.id)
        
        // 3. Cancel notifications
        await notificationManager.cancelAlarm(with: alarm.id)
        
        // 4. Clear any weather adjustments
        if let weatherAlarmService = weatherAlarmService {
            await weatherAlarmService.clearAdjustmentsForAlarm(alarm.id)
        }
        
        // 5. Remove from store
        alarmStore.delete(alarm)
        
        // 6. Clean up deletion tracking after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.deletingAlarms.remove(alarm.id)
        }
        
        print("[DATA-COORDINATOR] Successfully deleted alarm: \(alarm.name)")
    }
    
    // MARK: - Batch Operations
    func deleteAllAlarms() async {
        print("[DATA-COORDINATOR] Deleting all alarms")
        
        let allAlarms = alarmStore.alarms
        for alarm in allAlarms {
            await deleteAlarm(alarm)
        }
    }
    
    func recalculateAllAdjustments() async {
        print("[DATA-COORDINATOR] Recalculating all smart alarm adjustments")
        
        let smartAlarms = alarmStore.alarms.filter { $0.smartEnabled && $0.isEnabled }
        
        for alarm in smartAlarms {
            await calculateAndStoreAdjustment(for: alarm)
        }
        
        print("[DATA-COORDINATOR] Completed recalculation for \(smartAlarms.count) alarms")
    }
    
    // MARK: - Private Methods
    private func validateAlarm(_ alarm: Alarm) -> Bool {
        // Basic validation
        guard !alarm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[DATA-COORDINATOR] ERROR: Alarm name is empty")
            return false
        }
        
        // Smart alarm validation
        if alarm.smartEnabled {
            guard alarm.startingAddress.isValid else {
                print("[DATA-COORDINATOR] ERROR: Invalid starting address")
                print("[DATA-COORDINATOR] ERROR: \(alarm.startingAddress.street), \(alarm.startingAddress.city), \(alarm.startingAddress.state), \(alarm.startingAddress.zip)")
                return false
            }
            
            guard alarm.destinationAddress.isValid else {
                print("[DATA-COORDINATOR] ERROR: Invalid destination address")
                print("[DATA-COORDINATOR] ERROR: \(alarm.destinationAddress.street), \(alarm.destinationAddress.city), \(alarm.destinationAddress.state), \(alarm.destinationAddress.zip)")
                return false
            }
        }
        
        return true
    }
    
    private func calculateAndStoreAdjustment(for alarm: Alarm) async {
        print("[DATA-COORDINATOR] Calculating adjustment for alarm: \(alarm.name)")
        
        do {
            let response = try await smartAlarmService.calculateSmartWakeTime(
                for: alarm,
                userProfile: profileViewModel,
                arrivalTime: alarm.arrivalTime,
                currentLocation: nil,
                forceRecalculation: true
            )
            
            // Parse response and create adjustment
            guard let adjustment = createAdjustment(from: response, for: alarm) else {
                print("[DATA-COORDINATOR] No adjustment needed")
                return
            }
            
            // Update alarm with adjustment - SKIP RECALCULATION
            var updatedAlarm = alarm
            updatedAlarm.currentAdjustment = adjustment
            
            // Update with skip flag to prevent loop
            await updateAlarm(updatedAlarm, skipAdjustmentCalculation: true)
            
            print("[DATA-COORDINATOR] Successfully stored adjustment: \(adjustment.adjustmentMinutes) minutes")
            
        } catch {
            print("[DATA-COORDINATOR] ERROR: Failed to calculate adjustment: \(error)")
        }
    }
    
    // Move adjustment creation logic here
    private func createAdjustment(from response: SmartAlarmResponse, for alarm: Alarm) -> AlarmAdjustment? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let adjustedTime = formatter.date(from: response.wakeTime) ??
                                ISO8601DateFormatter().date(from: response.wakeTime) else {
            print("[DATA-COORDINATOR] ERROR: Failed to parse wake time")
            return nil
        }
        
        let adjustmentMinutes = Int((alarm.alarmTime.timeIntervalSince(adjustedTime)) / 60)
        
        // Skip very small adjustments
        guard abs(adjustmentMinutes) >= 2 else {
            print("[DATA-COORDINATOR] Adjustment too small: \(adjustmentMinutes) minutes")
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
            adjustedWakeTime: adjustedTime,
            adjustmentMinutes: adjustmentMinutes,
            reason: response.explanation.first?.reason ?? "Conditions require adjustment",
            calculatedAt: Date(),
            confidence: response.confidenceScore,
            breakdown: breakdown
        )
    }
}
