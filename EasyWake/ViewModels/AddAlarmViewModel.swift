// AddAlarmViewModel.swift - Fixed Version

import SwiftUI
import AVFoundation
import Combine

class AddAlarmViewModel: ObservableObject {
    @Published var alarm: Alarm
    @Published var errorMessage: String?
    @Published var showDeleteAlert = false
    
    // Profile integration
    @Published var profileViewModel = ProfileViewModel()
    @Published var showAddressSelector = false
    @Published var showAddNewAddress = false
    @Published var selectedAddressType: AddressType?
    @Published var showSaveToProfilePrompt = false
    @Published var pendingAddressToSave: Address?
    
    // Address management
    @Published var hasUnsavedAddress = false
    @Published var showSwapAddressesAlert = false
    @Published var showAddressSavedMessage = false
    @Published var addressSavedText = ""
    
    // Travel method and defaults
    @Published var selectedTravelMethod: TravelMethod
    @Published var showTravelMethodUpdate = false
    
    // Preparation time picker state
    @Published var preparationHours: Int = 0
    @Published var preparationMinutes: Int = 0
    
    // Consolidated Recurrence State
    @Published var isRepeatDaily: Bool = false
    @Published var selectedWeekdays: Set<Weekday> = []
    @Published var selectedDate: Date = Date()
    
    weak var alarmStore: AlarmStore?
    
    private var player: AVAudioPlayer?
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    let isEditMode: Bool
    let availableTones: [AlarmTone] = [
        .init(name: "Alarm", filename: "Alarm.caf"),
        .init(name: "Chime", filename: "Chime.caf"),
        .init(name: "Pulse", filename: "Pulse.caf"),
    ]
    
    let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    let states = ["Select", "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
                  "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
                  "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
                  "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
                  "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]
    
    enum AddressType {
        case starting, destination
    }
    
    var effectiveArrivalTime: Date {
        get {
            return alarm.arrivalTime
        }
        set {
            let calendar = Calendar.current
            let alarmComponents = calendar.dateComponents([.hour, .minute], from: alarm.alarmTime)
            let arrivalComponents = calendar.dateComponents([.hour, .minute], from: newValue)
            
            let alarmMinutes = (alarmComponents.hour ?? 0) * 60 + (alarmComponents.minute ?? 0)
            let arrivalMinutes = (arrivalComponents.hour ?? 0) * 60 + (arrivalComponents.minute ?? 0)
            
            // CRITICAL: For cross-day arrivals, always use next calendar day
            // NOT the next day in repeating schedule
            if arrivalMinutes < alarmMinutes {
                // Arrival is next calendar day
                let alarmDate = calendar.startOfDay(for: alarm.alarmTime)
                let nextDay = calendar.date(byAdding: .day, value: 1, to: alarmDate)!
                alarm.arrivalTime = calendar.date(bySettingHour: arrivalComponents.hour ?? 0,
                                                minute: arrivalComponents.minute ?? 0,
                                                second: 0,
                                                of: nextDay) ?? newValue
                
                print("[ADD-ALARM] Cross-day arrival detected")
                print("[ADD-ALARM] Alarm time: \(alarmMinutes / 60):\(alarmMinutes % 60)")
                print("[ADD-ALARM] Arrival time: \(arrivalMinutes / 60):\(arrivalMinutes % 60)")
                print("[ADD-ALARM] Arrival date set to: \(nextDay)")
            } else {
                // Same day arrival
                let alarmDate = calendar.startOfDay(for: alarm.alarmTime)
                alarm.arrivalTime = calendar.date(bySettingHour: arrivalComponents.hour ?? 0,
                                                minute: arrivalComponents.minute ?? 0,
                                                second: 0,
                                                of: alarmDate) ?? newValue
                
                print("[ADD-ALARM] Same-day arrival")
                print("[ADD-ALARM] Arrival date set to: \(alarmDate)")
            }
        }
    }
    
    init(alarm: Alarm) {
        // UPDATED: Check if this is a new alarm or editing existing
        if alarm.name.isEmpty {
            // New alarm - set default to specific date (today)
            var newAlarm = alarm
            newAlarm.schedule = .specificDate(Date())
            self.alarm = newAlarm
            self.isEditMode = false
            self.isRepeatDaily = false
            self.selectedDate = Date()
        } else {
            // Existing alarm - keep current schedule
            self.alarm = alarm
            self.isEditMode = true
        }
        
        self.selectedTravelMethod = ProfileViewModel().preferences.travelMethod
        
        // Load profile data
        profileViewModel.loadData()
        
        // Apply smart defaults from profile
        applyProfileDefaults()
        
        // Default vibration to ON for new alarms
        if !isEditMode && alarm.vibrationEnabled == false {
            self.alarm.vibrationEnabled = true
        }
        
        // Initialize preparation time from preparationInterval or profile defaults
        initializePreparationTime()
        
        // Initialize recurrence state based on alarm schedule
        initializeRecurrenceState()
    }
    
    var arrivalTimeCaption: String? {
        guard alarm.smartEnabled else { return nil }
        
        let calendar = Calendar.current
        let alarmTimeComponents = calendar.dateComponents([.hour, .minute], from: alarm.alarmTime)
        let arrivalTimeComponents = calendar.dateComponents([.hour, .minute], from: effectiveArrivalTime)
        
        let alarmMinutes = (alarmTimeComponents.hour ?? 0) * 60 + (alarmTimeComponents.minute ?? 0)
        let arrivalMinutes = (arrivalTimeComponents.hour ?? 0) * 60 + (arrivalTimeComponents.minute ?? 0)
        
        if arrivalMinutes < alarmMinutes {
            // Cross-day scenario
            let arrivalDate = calendar.startOfDay(for: effectiveArrivalTime)
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            let arrivalWeekday = weekdayFormatter.string(from: arrivalDate)
            
            return "Your arrival time (\(formatTime(effectiveArrivalTime))) is earlier than your wake time, so you'll arrive on \(arrivalWeekday) morning."
        }
        
        return nil
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - FIXED: Preparation Time Initialization
    private func initializePreparationTime() {
        if alarm.preparationInterval > 0 {
            // Use existing preparation interval
            self.preparationHours = Int(alarm.preparationInterval / 3600)
            self.preparationMinutes = Int((alarm.preparationInterval.truncatingRemainder(dividingBy: 3600)) / 60)
        } else {
            // Use profile default commute buffer as preparation time
            loadProfileDefault()
        }
        updatePreparationInterval()
    }
    
    // MARK: - FIXED: Load Profile Default Function
    func loadProfileDefault() {
        let totalMinutes = profileViewModel.preferences.commuteBuffer
        self.preparationHours = totalMinutes / 60
        self.preparationMinutes = totalMinutes % 60
        updatePreparationInterval()
    }
    
    // MARK: - Profile Integration Methods
    
    private func applyProfileDefaults() {
        // Pre-populate with home address as starting point only if fields are empty
        if alarm.startingAddress.street.isEmpty, let homeAddress = profileViewModel.homeAddress, homeAddress.isValid {
            alarm.startingAddress.street = homeAddress.street
            alarm.startingAddress.city = homeAddress.city
            alarm.startingAddress.state = homeAddress.state
            alarm.startingAddress.zip = homeAddress.zip
        }
        
        // Suggest work address during business hours only if fields are empty
        if alarm.destinationAddress.street.isEmpty, let workAddress = profileViewModel.workAddress, workAddress.isValid {
            alarm.destinationAddress.street = workAddress.street
            alarm.destinationAddress.city = workAddress.city
            alarm.destinationAddress.state = workAddress.state
            alarm.destinationAddress.zip = workAddress.zip
        }
        
        // Use default travel method from profile
        selectedTravelMethod = profileViewModel.preferences.travelMethod
    }
    
    // MARK: - FIXED: Address Selection
    func selectSavedAddress(_ address: Address, for type: AddressType) {
        hapticFeedback.impactOccurred()
        
        switch type {
        case .starting:
            alarm.startingAddress.street = address.street
            alarm.startingAddress.city = address.city
            alarm.startingAddress.state = address.state
            alarm.startingAddress.zip = address.zip
        case .destination:
            alarm.destinationAddress.street = address.street
            alarm.destinationAddress.city = address.city
            alarm.destinationAddress.state = address.state
            alarm.destinationAddress.zip = address.zip
        }
        
        showAddressSelector = false
        // Force UI update
        objectWillChange.send()
    }
    
    // MARK: - FIXED: Swap Addresses
    func swapAddresses() {
        hapticFeedback.impactOccurred()
        
        let tempStreet = alarm.startingAddress.street
        let tempCity = alarm.startingAddress.city
        let tempState = alarm.startingAddress.state
        let tempZip = alarm.startingAddress.zip
        
        alarm.startingAddress.street = alarm.destinationAddress.street
        alarm.startingAddress.city = alarm.destinationAddress.city
        alarm.startingAddress.state = alarm.destinationAddress.state
        alarm.startingAddress.zip = alarm.destinationAddress.zip
        
        alarm.destinationAddress.street = tempStreet
        alarm.destinationAddress.city = tempCity
        alarm.destinationAddress.state = tempState
        alarm.destinationAddress.zip = tempZip
        
        // Force UI update
        objectWillChange.send()
    }
    
    // MARK: - FIXED: Save Address to Profile
    func promptToSaveAddress(_ address: Address) {
        pendingAddressToSave = address
        showSaveToProfilePrompt = true
    }
    
    func saveAddressToProfile() {
        guard let address = pendingAddressToSave else { return }
        
        // Create a copy of the address to avoid reference issues
        var addressToSave = address
        
        // Don't clear the form - just save to profile
        profileViewModel.addCustomLocation(addressToSave)
        pendingAddressToSave = nil
        hasUnsavedAddress = false
        
        // Keep the address in the form
        // No need to clear anything
    }
    
    func updateTravelMethodInProfile() {
        if selectedTravelMethod != profileViewModel.preferences.travelMethod {
            profileViewModel.preferences.travelMethod = selectedTravelMethod
            profileViewModel.updatePreferences()
            showTravelMethodUpdate = false
        }
    }
    
    // MARK: - Computed Properties
    
    var currentStartingAddress: Address? {
        guard !alarm.startingAddress.street.isEmpty else { return nil }
        return Address(
            label: .custom,
            customLabel: "Current Starting Address",
            street: alarm.startingAddress.street,
            city: alarm.startingAddress.city,
            zip: alarm.startingAddress.city,
            state: alarm.startingAddress.state
        )
    }
    
    var currentDestinationAddress: Address? {
        guard !alarm.destinationAddress.street.isEmpty else { return nil }
        return Address(
            label: .custom,
            customLabel: "Current Destination",
            street: alarm.destinationAddress.street,
            city: alarm.destinationAddress.city,
            zip: alarm.destinationAddress.city,
            state: alarm.destinationAddress.state
        )
    }
    
    var isPremiumUser: Bool {
        true // Temporarily allow all users to access smart features
    }
    
    var canSwapAddresses: Bool {
        let hasStarting = !alarm.startingAddress.street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                         !alarm.startingAddress.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDestination = !alarm.destinationAddress.street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                         !alarm.destinationAddress.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasStarting && hasDestination
    }
    
    var preparationTimeString: String {
        if preparationHours == 0 && preparationMinutes == 0 {
            return NSLocalizedString("No preparation time", comment: "Preparation time display")
        } else if preparationHours == 0 {
            let format = NSLocalizedString("Prep time: %d min", comment: "Preparation time display")
            return String(format: format, preparationMinutes)
        } else if preparationMinutes == 0 {
            let format = NSLocalizedString("Prep time: %d h", comment: "Preparation time display")
            return String(format: format, preparationHours)
        } else {
            let format = NSLocalizedString("Prep time: %d h %d min", comment: "Preparation time display")
            return String(format: format, preparationHours, preparationMinutes)
        }
    }
    
    // MARK: - SIMPLIFIED: Basic Validation Logic
    var isValid: Bool {
        // Only check for alarm name - that's it!
        return !alarm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Core Functionality Methods
    
    private func initializeRecurrenceState() {
        switch alarm.schedule {
        case .repeatingDays(let days):
            isRepeatDaily = true
            selectedWeekdays = Set(days)
            // Start with no days selected for new alarms
            if selectedWeekdays.isEmpty && !isEditMode {
                selectedWeekdays = []
            }
        case .specificDate(let date):
            isRepeatDaily = false
            selectedDate = date
        case .oneTime:
            isRepeatDaily = true
            selectedWeekdays = [] // Start with no days selected
        }
    }
    
    func updatePreparationInterval() {
        alarm.preparationInterval = TimeInterval(preparationHours * 3600 + preparationMinutes * 60)
    }
    
    func validate() -> Bool {
        errorMessage = nil
        
        // Basic validation - always required
        if alarm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = NSLocalizedString("Name is required", comment: "Validation error")
            return false
        }
        
        // Recurrence validation - only if repeat daily is enabled
        if isRepeatDaily && selectedWeekdays.isEmpty {
            errorMessage = NSLocalizedString("Please select at least one day to repeat", comment: "Validation error")
            return false
        }
        
        // Smart alarm validation - only if smart alarm is enabled
        if alarm.smartEnabled {
            // Validate starting address
            if alarm.startingAddress.street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                alarm.startingAddress.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                alarm.startingAddress.zip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                alarm.startingAddress.state == "Select" {
                errorMessage = NSLocalizedString("Smart alarms require complete starting address", comment: "Validation error")
                return false
            }
            
            // Validate starting ZIP code
            if alarm.startingAddress.zip.count != 5 || !alarm.startingAddress.zip.allSatisfy(\.isNumber) {
                errorMessage = NSLocalizedString("Please enter a valid 5-digit ZIP code for starting address", comment: "Validation error")
                return false
            }
            
            // Validate destination address
            if alarm.destinationAddress.street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                alarm.destinationAddress.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                alarm.destinationAddress.zip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                alarm.destinationAddress.state == "Select" {
                errorMessage = NSLocalizedString("Smart alarms require complete destination address", comment: "Validation error")
                return false
            }
            
            // Validate destination ZIP code
            if alarm.destinationAddress.zip.count != 5 || !alarm.destinationAddress.zip.allSatisfy(\.isNumber) {
                errorMessage = NSLocalizedString("Please enter a valid 5-digit ZIP code for destination address", comment: "Validation error")
                return false
            }
        }
        
        return true
    }
    
    func toggleRepeatDaily() {
        hapticFeedback.impactOccurred()
        
        if isRepeatDaily {
            isRepeatDaily = false
            selectedWeekdays.removeAll()
            selectedDate = Date()
            alarm.schedule = .specificDate(selectedDate)
        } else {
            isRepeatDaily = true
            selectedWeekdays = [] // Start with no days selected
            alarm.schedule = .repeatingDays(Array(selectedWeekdays))
        }
    }
    
    func toggleWeekday(_ weekday: Weekday) {
        hapticFeedback.impactOccurred()
        
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
        
        alarm.schedule = .repeatingDays(Array(selectedWeekdays))
    }
    
    func updateSelectedDate(_ date: Date) {
        selectedDate = date
        alarm.schedule = .specificDate(date)
    }
    
    func playTone(_ filename: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = Float(alarm.volume)
        player?.play()
    }
    
    // ENHANCED: Clear alarm data
    func clearAlarmData() {
        print("[ADD-ALARM-VM] Clearing alarm data")
        
        // Clear all state
        errorMessage = nil
        showDeleteAlert = false
        showAddressSelector = false
        showAddNewAddress = false
        selectedAddressType = nil
        showSaveToProfilePrompt = false
        pendingAddressToSave = nil
        hasUnsavedAddress = false
        showAddressSavedMessage = false
        addressSavedText = ""
        showTravelMethodUpdate = false
        
        // Stop any audio
        player?.stop()
        player = nil
        
        print("[ADD-ALARM-VM] Alarm data cleared")
    }
}
