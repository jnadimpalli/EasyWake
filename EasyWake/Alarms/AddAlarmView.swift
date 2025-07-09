// AddAlarmView.swift

import SwiftUI
import AVFoundation
import Combine

// MARK: - View Model
class AddAlarmViewModel: ObservableObject {
    @Published var alarm: Alarm
    @Published var errorMessage: String?
    @Published var showDeleteAlert = false
    
    // FR-3: Preparation time picker state
    @Published var preparationHours: Int = 0
    @Published var preparationMinutes: Int = 0
    
    // Consolidated Recurrence State
    @Published var isRepeatDaily: Bool = false
    @Published var selectedWeekdays: Set<Weekday> = []
    @Published var selectedDate: Date = Date()
    
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
    
    init(alarm: Alarm) {
        self.alarm = alarm
        self.isEditMode = alarm.name != ""
        
        // FR-2: Default vibration to ON for new alarms
        if !isEditMode && alarm.vibrationEnabled == false {
            self.alarm.vibrationEnabled = true
        }
        
        // FR-3: Initialize preparation time from preparationInterval
        self.preparationHours = Int(alarm.preparationInterval / 3600)
        self.preparationMinutes = Int((alarm.preparationInterval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        // Initialize recurrence state based on alarm schedule
        initializeRecurrenceState()
    }
    
    private func initializeRecurrenceState() {
        switch alarm.schedule {
        case .repeatingDays(let days):
            isRepeatDaily = true
            selectedWeekdays = Set(days)
            // If no days selected, default to all days
            if selectedWeekdays.isEmpty {
                selectedWeekdays = Set(weekdays)
            }
        case .specificDate(let date):
            isRepeatDaily = false
            selectedDate = date
        case .oneTime:
            // Default to repeat daily for new alarms
            isRepeatDaily = true
            selectedWeekdays = Set(weekdays)
        }
    }
    
    // FR-3: Computed property for preparation time summary
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
    
    // Update preparation interval when hours/minutes change
    func updatePreparationInterval() {
        alarm.preparationInterval = TimeInterval(preparationHours * 3600 + preparationMinutes * 60)
        
        // Also update legacy properties for backward compatibility
        alarm.readyHours = preparationHours
        alarm.readyMinutes = preparationMinutes
    }
    
    var isValid: Bool {
        guard !alarm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // FR-4: Validate recurrence settings
        if isRepeatDaily {
            guard !selectedWeekdays.isEmpty else { return false }
        } else {
            // For specific date, always valid if date is set
        }
        
        if alarm.smartEnabled {
            return !alarm.startingStreet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !alarm.startingCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !alarm.startingZip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   alarm.startingState != "Select" &&
                   !alarm.destinationStreet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !alarm.destinationCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !alarm.destinationZip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   alarm.destinationState != "Select"
        }
        
        return true
    }
    
    func validate() -> Bool {
        errorMessage = nil
        
        if alarm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = NSLocalizedString("Name is required", comment: "Validation error")
            return false
        }
        
        // FR-4: Validate recurrence
        if isRepeatDaily && selectedWeekdays.isEmpty {
            errorMessage = NSLocalizedString("Please select at least one day to repeat", comment: "Validation error")
            return false
        }
        
        if alarm.smartEnabled {
            if alarm.startingStreet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               alarm.startingCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               alarm.startingZip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               alarm.startingState == "Select" {
                errorMessage = NSLocalizedString("Please fill out all starting address fields", comment: "Validation error")
                return false
            }
            
            if alarm.destinationStreet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               alarm.destinationCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               alarm.destinationZip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               alarm.destinationState == "Select" {
                errorMessage = NSLocalizedString("Please fill out all destination address fields", comment: "Validation error")
                return false
            }
        }
        
        return true
    }
    
    // FR-1 & FR-2: Handle repeat daily toggle
    func toggleRepeatDaily() {
        hapticFeedback.impactOccurred()
        
        if isRepeatDaily {
            // Switching to specific date mode
            isRepeatDaily = false
            selectedWeekdays.removeAll()
            selectedDate = Date()
            alarm.schedule = .specificDate(selectedDate)
        } else {
            // Switching to repeat daily mode
            isRepeatDaily = true
            selectedWeekdays = Set(weekdays) // Default to all days
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
        
        // Update alarm schedule
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
}

// MARK: - Main View
struct AddAlarmView: View {
    @StateObject private var viewModel: AddAlarmViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var infoToShow: InfoType?
    
    let onSave: (Alarm) -> Void
    let onCancel: () -> Void
    let onDelete: ((Alarm) -> Void)?
    
    init(
        alarm: Alarm = Alarm(),
        onSave: @escaping (Alarm) -> Void,
        onCancel: @escaping () -> Void,
        onDelete: ((Alarm) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: AddAlarmViewModel(alarm: alarm))
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Name Section
                Section(header: Text("NAME").textCase(.uppercase)) {
                    TextField("Alarm Name", text: $viewModel.alarm.name)
                        .frame(minHeight: 44) // 3.3: Touch target
                        .accessibilityLabel("Alarm name")
                        .accessibilityHint("Enter a name for this alarm")
                }
                
                // Time Section
                Section(header: Text("TIME").textCase(.uppercase)) {
                    DatePicker("",
                              selection: $viewModel.alarm.time,
                              displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.wheel)
                        .frame(maxHeight: 120)
                        .accessibilityLabel("Alarm time")
                        .accessibilityHint("Select the time for this alarm")
                }
                
                // Consolidated Recurrence Section
                recurrenceSection
                
                // Sound & Vibration Section
                Section(header: Text("SOUND").textCase(.uppercase)) {
                    HStack {
                        Text("Tone")
                        Spacer()
                        Picker("", selection: $viewModel.alarm.selectedTone) {
                            ForEach(viewModel.availableTones) { tone in
                                Text(tone.name).tag(tone.filename)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: viewModel.alarm.selectedTone) { _, newValue in
                            viewModel.playTone(newValue)
                        }
                        .accessibilityLabel("Alarm tone")
                        .accessibilityHint("Select a sound for this alarm")
                    }
                    .frame(minHeight: 44) // 3.3: Touch target
                    
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)
                        Slider(value: $viewModel.alarm.volume)
                            .onChange(of: viewModel.alarm.volume) { _, _ in
                                viewModel.playTone(viewModel.alarm.selectedTone)
                            }
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.secondary)
                    }
                    .frame(minHeight: 44) // 3.3: Touch target
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Volume")
                    .accessibilityValue("\(Int(viewModel.alarm.volume * 100)) percent")
                    .accessibilityHint("Adjust the alarm volume")
                    
                    // FR-2: Vibration Toggle
                    Toggle("Vibrate", isOn: $viewModel.alarm.vibrationEnabled)
                        .frame(minHeight: 44) // 3.3: Touch target
                        .accessibilityLabel("Vibration")
                        .accessibilityHint("Enable or disable vibration for this alarm")
                }
                
                // Smart Settings Section
                Section {
                    HStack {
                        Toggle("Enable Smart Alarm", isOn: $viewModel.alarm.smartEnabled)
                            .accessibilityLabel("Smart alarm")
                            .accessibilityHint("Enable automatic adjustments based on traffic and weather")
                        Spacer()
                        InfoButton { infoToShow = .smart }
                    }
                    .frame(minHeight: 44) // 3.3: Touch target
                }
                
                // Smart-only fields
                if viewModel.alarm.smartEnabled {
                    smartAlarmSections
                }
                
                // Inline error display
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
                
                // Delete button for edit mode
                if viewModel.isEditMode, let onDelete = onDelete {
                    Section {
                        Button(action: { viewModel.showDeleteAlert = true }) {
                            HStack {
                                Spacer()
                                Text("Delete Alarm")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                        .frame(minHeight: 44) // 3.3: Touch target
                        .accessibilityLabel("Delete alarm")
                        .accessibilityHint("Remove this alarm permanently")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(viewModel.isEditMode ? "Edit Alarm" : "Add Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: handleCancel)
                        .accessibilityLabel("Cancel")
                        .accessibilityHint("Discard changes and return to alarm list")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: handleSave)
                        .disabled(!viewModel.isValid)
                        .accessibilityLabel("Save")
                        .accessibilityHint(viewModel.isValid ? "Save alarm and return to list" : "Complete required fields to enable save")
                }
            }
            .alert(item: $infoToShow) { info in
                Alert(
                    title: Text(info.title),
                    message: Text(info.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Delete Alarm?", isPresented: $viewModel.showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let onDelete = onDelete {
                        onDelete(viewModel.alarm)
                        dismiss()
                    }
                }
            } message: {
                Text("This alarm will be permanently deleted.")
            }
        }
    }
    
    // MARK: - Consolidated Recurrence Section
    @ViewBuilder
    private var recurrenceSection: some View {
        Section(header: Text("RECURRENCE").textCase(.uppercase)) {
            // FR-1: Repeat Daily Toggle
            Toggle("Repeat Daily", isOn: Binding(
                get: { viewModel.isRepeatDaily },
                set: { _ in viewModel.toggleRepeatDaily() }
            ))
            .frame(minHeight: 44)
            .accessibilityLabel("Repeat Daily")
            .accessibilityHint("Turns on daily repetition; shows weekdays or date picker")
            
            // FR-2: Dynamic Sub-Control
            Group {
                if viewModel.isRepeatDaily {
                    // Weekday Pills
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.weekdays, id: \.self) { weekday in
                                    WeekdayPillView(
                                        weekday: weekday,
                                        isSelected: viewModel.selectedWeekdays.contains(weekday),
                                        action: { viewModel.toggleWeekday(weekday) }
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 2)
                        }
                    }
                    .transition(.opacity.combined(with: .slide))
                } else {
                    // Date Picker
                    HStack {
                      Text("Select Date")
                        .foregroundColor(.primary)
                      Spacer()
                      DatePicker(
                        "",
                        selection: Binding(
                          get: { viewModel.selectedDate },
                          set: { viewModel.updateSelectedDate($0) }
                        ),
                        displayedComponents: .date
                      )
                      .datePickerStyle(.compact)
                      .frame(minHeight: 44)
                      .accessibilityLabel("Select alarm date")
                      .accessibilityHint("Choose the date when the alarm should ring")
                    }
                    .transition(.opacity.combined(with: .slide))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isRepeatDaily)
        }
    }
    
    // MARK: - Smart Alarm Sections
    @ViewBuilder
    private var smartAlarmSections: some View {
        // Arrival Time Section
        Section(header: HStack {
            Text("ARRIVE BY")
                .textCase(.uppercase)
            Spacer()
            InfoButton { infoToShow = .arrival }
        }) {
            DatePicker("",
                      selection: $viewModel.alarm.arrivalTime,
                      displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.wheel)
                .frame(maxHeight: 120)
                .accessibilityLabel("Arrive by")
                .accessibilityHint("Select your desired arrival time")
        }
        
        // FR-3: Preparation Time Section with countdown-style picker
        Section(header:
            VStack(alignment: .leading, spacing: 4) {
                Text("PREPARATION TIME")
                    .textCase(.uppercase)
                Text("How long it takes to get ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Countdown-style wheel picker (like iOS Timers app)
                HStack(spacing: 0) {
                    // Hours Picker
                    Picker("Hours", selection: $viewModel.preparationHours) {
                        ForEach(0...5, id: \.self) { hour in
                            Text("\(hour)")
                                .tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .onChange(of: viewModel.preparationHours) { _, _ in
                        viewModel.updatePreparationInterval()
                    }
                    .accessibilityLabel("Hours")
                    .accessibilityValue("\(viewModel.preparationHours) hours")
                    
                    Text("hours")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .font(.system(.body, design: .default))
                    
                    // Minutes Picker
                    Picker("Minutes", selection: $viewModel.preparationMinutes) {
                        ForEach(0...59, id: \.self) { minute in
                            Text("\(minute)")
                                .tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .onChange(of: viewModel.preparationMinutes) { _, _ in
                        viewModel.updatePreparationInterval()
                    }
                    .accessibilityLabel("Minutes")
                    .accessibilityValue("\(viewModel.preparationMinutes) minutes")
                    
                    Text("min")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .font(.system(.body, design: .default))
                }
                .frame(height: 120)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Select preparation time in hours and minutes")
                .accessibilityHint("Use the wheel pickers to set how long you need to get ready")
                
                // Summary line beneath
                Text(viewModel.preparationTimeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .accessibilityLabel(viewModel.preparationTimeString)
            }
        }
        
        // Automatic Adjustments
        Section(header: Text("AUTOMATIC ADJUSTMENTS").textCase(.uppercase)) {
            Toggle("Weather conditions", isOn: $viewModel.alarm.weatherAdjustment)
                .frame(minHeight: 44)
                .accessibilityHint("Adjust alarm based on weather conditions")
            Toggle("Traffic conditions", isOn: $viewModel.alarm.trafficAdjustment)
                .frame(minHeight: 44)
                .accessibilityHint("Adjust alarm based on traffic conditions")
            Toggle("Transit delays", isOn: $viewModel.alarm.transitAdjustment)
                .frame(minHeight: 44)
                .accessibilityHint("Adjust alarm based on public transit delays")
        }
        
        // Starting Address
        Section(header: HStack {
            Text("STARTING ADDRESS")
                .textCase(.uppercase)
            Spacer()
            InfoButton { infoToShow = .address }
        }) {
            AddressFieldsView(
                street: $viewModel.alarm.startingStreet,
                city: $viewModel.alarm.startingCity,
                state: $viewModel.alarm.startingState,
                zip: $viewModel.alarm.startingZip,
                states: viewModel.states,
                fieldPrefix: "starting"
            )
        }
        
        // Destination Address
        Section(header: HStack {
            Text("DESTINATION ADDRESS")
                .textCase(.uppercase)
            Spacer()
            InfoButton { infoToShow = .address }
        }) {
            AddressFieldsView(
                street: $viewModel.alarm.destinationStreet,
                city: $viewModel.alarm.destinationCity,
                state: $viewModel.alarm.destinationState,
                zip: $viewModel.alarm.destinationZip,
                states: viewModel.states,
                fieldPrefix: "destination"
            )
        }
    }
    
    // MARK: - Actions
    private func handleCancel() {
        onCancel()
        dismiss()
    }
    
    private func handleSave() {
        guard viewModel.validate() else { return }
        
        // Ensure preparation interval is up to date
        viewModel.updatePreparationInterval()
        
        onSave(viewModel.alarm)
        dismiss()
    }
}

// MARK: - Supporting Views
struct WeekdayPillView: View {
    let weekday: Weekday
    let isSelected: Bool
    let action: () -> Void
    
    private var weekdayDisplayName: String {
        switch weekday {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
    
    var body: some View {
        Text(weekdayDisplayName)
            .font(.subheadline)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(minWidth: 44, minHeight: 44) // 3.3: Touch target
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .cornerRadius(8)
            .onTapGesture(perform: action)
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            .accessibilityLabel("\(weekdayDisplayName), \(isSelected ? "selected" : "not selected")")
            .accessibilityHint("Tap to \(isSelected ? "remove" : "add") \(weekdayDisplayName) to repeat schedule")
    }
}

struct AddressFieldsView: View {
    @Binding var street: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zip: String
    let states: [String]
    let fieldPrefix: String
    
    var body: some View {
        TextField("Street Address", text: $street)
            .frame(minHeight: 44) // 3.3: Touch target
            .accessibilityLabel("\(fieldPrefix) street address")
            .textContentType(.streetAddressLine1)
        
        TextField("City", text: $city)
            .frame(minHeight: 44)
            .accessibilityLabel("\(fieldPrefix) city")
            .textContentType(.addressCity)
        
        HStack {
            Picker("State", selection: $state) {
                ForEach(states, id: \.self) { state in
                    Text(state).tag(state)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityLabel("\(fieldPrefix) state")
            
            TextField("ZIP Code", text: $zip)
                .keyboardType(.numberPad)
                .frame(maxWidth: 120, minHeight: 44)
                .accessibilityLabel("\(fieldPrefix) ZIP code")
                .textContentType(.postalCode)
        }
    }
}

struct InfoButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
                .frame(width: 44, height: 44) // 3.3: Touch target
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Information")
        .accessibilityHint("Learn more about this feature")
    }
}

// MARK: - Info Types
private enum InfoType: Identifiable {
    case smart, arrival, address
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .smart:
            return NSLocalizedString("Smart Alarm", comment: "Info title")
        case .arrival:
            return NSLocalizedString("Arrival Time", comment: "Info title")
        case .address:
            return NSLocalizedString("Address Information", comment: "Info title")
        }
    }
    
    var message: String {
        switch self {
        case .smart:
            return NSLocalizedString("Smart Alarm automatically adjusts your wake time based on traffic, weather, and transit conditions to ensure you arrive on time.", comment: "Info message")
        case .arrival:
            return NSLocalizedString("Your desired arrival time at the destination. Smart Alarm will work backwards from this time to calculate when to wake you.", comment: "Info message")
        case .address:
            return NSLocalizedString("Provide complete addresses for accurate travel time calculations. This information is used to check real-time traffic and transit conditions.", comment: "Info message")
        }
    }
}

// MARK: - Alarm Tone Model
struct AlarmTone: Identifiable {
    let id = UUID()
    let name: String
    let filename: String
}

// MARK: - Preview
#Preview {
    AddAlarmView(
        onSave: { _ in },
        onCancel: { }
    )
}

#Preview("Edit Mode") {
    AddAlarmView(
        alarm: Alarm(
            name: "Morning Alarm",
            time: Date(),
            isEnabled: true,
            schedule: .repeatingDays([.monday, .tuesday, .wednesday])
        ),
        onSave: { _ in },
        onCancel: { },
        onDelete: { _ in }
    )
}
