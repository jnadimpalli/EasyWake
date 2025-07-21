// AddAlarmFormSections.swift - Fixed Version

import SwiftUI

// MARK: - Preparation Time Section (FIXED)
struct PreparationTimeSection: View {
    @ObservedObject var viewModel: AddAlarmViewModel
    
    var body: some View {
        Section(header:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("PREPARATION TIME")
                        .textCase(.uppercase)
                    Spacer()
                    // FIXED: Always show the button and make it work
                    Button("Use Profile Default") {
                        viewModel.loadProfileDefault()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                Text("How long it takes to get ready")
                    .font(.caption)
                    .textCase(.none)
                    .foregroundColor(.secondary)
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 0) {
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
                    
                    Text("hours")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    
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
                    
                    Text("min")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                }
                .frame(height: 120)
                
                Text(viewModel.preparationTimeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Enhanced Address Section (FIXED)
struct EnhancedAddressSection: View {
    @ObservedObject var viewModel: AddAlarmViewModel
    let type: AddAlarmViewModel.AddressType
    @Binding var infoToShow: InfoType?
    
    private var title: String {
        type == .starting ? "STARTING ADDRESS" : "DESTINATION ADDRESS"
    }
    
    private var currentAddress: Address? {
        type == .starting ? viewModel.currentStartingAddress : viewModel.currentDestinationAddress
    }
    
    // FIXED: Check if address fields are filled
    private var hasAddressData: Bool {
        switch type {
        case .starting:
            return !viewModel.alarm.startingAddress.street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !viewModel.alarm.startingAddress.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .destination:
            return !viewModel.alarm.destinationAddress.street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !viewModel.alarm.destinationAddress.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var body: some View {
        Section(header: HStack {
            Text(title)
                .textCase(.uppercase)
            Spacer()
            InfoButton { infoToShow = .address }
        }) {
            // Quick select saved addresses
            if !viewModel.profileViewModel.addresses.isEmpty {
                Button {
                    viewModel.selectedAddressType = type
                    viewModel.showAddressSelector = true
                } label: {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.blue)
                        Text("Select Saved Address")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)
                .frame(minHeight: 44)
            }
            
            // ALWAYS show manual entry form - let user edit the fields directly
            VStack(alignment: .leading, spacing: 12) {
                // Manual address entry
                EnhancedAddressFieldsView(
                    street: type == .starting ? $viewModel.alarm.startingAddress.street : $viewModel.alarm.destinationAddress.street,
                    city: type == .starting ? $viewModel.alarm.startingAddress.city : $viewModel.alarm.destinationAddress.city,
                    state: type == .starting ? $viewModel.alarm.startingAddress.state : $viewModel.alarm.destinationAddress.state,
                    zip: type == .starting ? $viewModel.alarm.startingAddress.zip : $viewModel.alarm.destinationAddress.zip,
                    states: viewModel.states,
                    fieldPrefix: type == .starting ? "starting" : "destination",
                    onAddressComplete: { address in
                        viewModel.promptToSaveAddress(address)
                    }
                )
                
                // Show confirmation message if address was saved
                if viewModel.showAddressSavedMessage && hasAddressData {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(viewModel.addressSavedText)
                            .font(.caption)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.showAddressSavedMessage)
                }
            }
        }
}
}

// MARK: - Enhanced Address Fields View (FIXED)
struct EnhancedAddressFieldsView: View {
    @Binding var street: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zip: String
    let states: [String]
    let fieldPrefix: String
    let onAddressComplete: (Address) -> Void
    
    @State private var isValidating = false
    @State private var isValid = false
    
    var currentAddress: Address {
        Address(
            label: .custom,
            customLabel: "\(fieldPrefix.capitalized) Address",
            street: street,
            city: city,
            zip: zip,
            state: state
        )
    }
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Street Address", text: $street)
                .frame(minHeight: 44)
                .accessibilityLabel("\(fieldPrefix) street address")
                .textContentType(.streetAddressLine1)
                .onChange(of: street) { _, _ in validateAddress() }
            
            TextField("City", text: $city)
                .frame(minHeight: 44)
                .accessibilityLabel("\(fieldPrefix) city")
                .textContentType(.addressCity)
                .onChange(of: city) { _, _ in validateAddress() }
            
            HStack {
                Picker("State", selection: $state) {
                    ForEach(states, id: \.self) { state in
                        Text(state).tag(state)
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
                .accessibilityLabel("\(fieldPrefix) state")
                .onChange(of: state) { _, _ in validateAddress() }
                
                TextField("ZIP Code", text: $zip)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 120, minHeight: 44)
                    .accessibilityLabel("\(fieldPrefix) ZIP code")
                    .textContentType(.postalCode)
                    .onChange(of: zip) { _, newValue in
                        // Limit to 5 digits
                        if newValue.count > 5 {
                            zip = String(newValue.prefix(5))
                        }
                        validateAddress()
                    }
            }
            
            // Validation status and save option
            if isValid {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Valid address")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Button("Save to Profile") {
                        onAddressComplete(currentAddress)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.top, 4)
            } else if isValidating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Validating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func validateAddress() {
        guard currentAddress.isValid else {
            isValid = false
            return
        }
        
        isValidating = true
        
        // Simulate address validation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isValidating = false
            isValid = true
        }
    }
}

// MARK: - Other sections remain the same...
// (Include all other sections from the original file without changes)

// MARK: - Recurrence Section
struct RecurrenceSection: View {
    @ObservedObject var viewModel: AddAlarmViewModel
    
    var body: some View {
        Section(header: Text("RECURRENCE").textCase(.uppercase)) {
            Toggle("Repeat Daily", isOn: Binding(
                get: { viewModel.isRepeatDaily },
                set: { _ in viewModel.toggleRepeatDaily() }
            ))
            .frame(minHeight: 44)
            .accessibilityLabel("Repeat Daily")
            .accessibilityHint("Turns on daily repetition; shows weekdays or date picker")
            
            Group {
                if viewModel.isRepeatDaily {
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
                            in: Date()..., // Prevent past dates
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
}

// MARK: - Sound Section
struct SoundSection: View {
    @ObservedObject var viewModel: AddAlarmViewModel
    
    var body: some View {
        Section(header: Text("SOUND").textCase(.uppercase)) {
            HStack {
                Text("Tone")
                Spacer()
                Picker("", selection: $viewModel.alarm.soundTone) {
                    ForEach(viewModel.availableTones) { tone in
                        Text(tone.name).tag(tone.filename)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.alarm.soundTone) { _, newValue in
                    viewModel.playTone(newValue)
                }
                .accessibilityLabel("Alarm tone")
                .accessibilityHint("Select a sound for this alarm")
            }
            .frame(minHeight: 44)
            
            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.secondary)
                Slider(value: $viewModel.alarm.volume)
                    .onChange(of: viewModel.alarm.volume) { _, _ in
                        viewModel.playTone(viewModel.alarm.soundTone)
                    }
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.secondary)
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Volume")
            .accessibilityValue("\(Int(viewModel.alarm.volume * 100)) percent")
            .accessibilityHint("Adjust the alarm volume")
            
            Toggle("Vibrate", isOn: $viewModel.alarm.vibrationEnabled)
                .frame(minHeight: 44)
                .accessibilityLabel("Vibration")
                .accessibilityHint("Enable or disable vibration for this alarm")
        }
    }
}

// MARK: - Smart Settings Section
struct SmartSettingsSection: View {
    @ObservedObject var viewModel: AddAlarmViewModel
    @Binding var infoToShow: InfoType?
    
    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Smart Alarm")
                    Text("Automatically adjust wake time based on conditions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.alarm.smartEnabled)
                    .labelsHidden()
                
                InfoButton { infoToShow = .smart }
            }
            .frame(minHeight: 44)
        }
    }
}

// MARK: - Smart Alarm Sections
struct SmartAlarmSections: View {
    @ObservedObject var viewModel: AddAlarmViewModel
    @Binding var infoToShow: InfoType?
    
    var body: some View {
        // Arrival Time Section
        Section(header: HStack {
            Text("ARRIVE BY")
                .textCase(.uppercase)
            Spacer()
            InfoButton { infoToShow = .arrival }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                    DatePicker("",
                               selection: Binding(
                                   get: { viewModel.effectiveArrivalTime },
                                   set: { viewModel.effectiveArrivalTime = $0 }
                               ),
                               displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .frame(maxHeight: 120)
                    .accessibilityLabel("Arrive by")
                    .accessibilityHint("Select your desired arrival time")
                    
                    // Dynamic caption that appears when arrival time is before alarm time
                    if let caption = viewModel.arrivalTimeCaption {
                        Text(caption)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                            .animation(.easeInOut(duration: 0.3), value: caption)
                    }
                }
        }
        
        // Preparation Time Section
        PreparationTimeSection(viewModel: viewModel)
        
        // Travel Method Section
        TravelMethodSection(viewModel: viewModel)
        
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
        
        // Enhanced Starting Address Section
        EnhancedAddressSection(viewModel: viewModel, type: .starting, infoToShow: $infoToShow)
        
        // Enhanced Destination Address Section
        EnhancedAddressSection(viewModel: viewModel, type: .destination, infoToShow: $infoToShow)
        
        // Address Swap Section
        if viewModel.canSwapAddresses {
            Section {
                Button {
                    viewModel.swapAddresses()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.blue)
                        Text("Swap Starting and Destination")
                        Spacer()
                    }
                }
                .frame(minHeight: 44)
                .accessibilityLabel("Swap addresses")
                .accessibilityHint("Exchange starting and destination addresses")
            }
        }
    }
}

// MARK: - Travel Method Section
struct TravelMethodSection: View {
    @ObservedObject var viewModel: AddAlarmViewModel
    
    var body: some View {
        Section(header: Text("TRAVEL METHOD").textCase(.uppercase)) {
            Picker("Travel Method", selection: $viewModel.selectedTravelMethod) {
                ForEach(TravelMethod.allCases, id: \.self) { method in
                    Label(method.displayName, systemImage: method.icon)
                        .tag(method)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .onChange(of: viewModel.selectedTravelMethod) { _, newValue in
                // Check if user consistently chooses different method
                if newValue != viewModel.profileViewModel.preferences.travelMethod {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        viewModel.showTravelMethodUpdate = true
                    }
                }
            }
        }
    }
}
