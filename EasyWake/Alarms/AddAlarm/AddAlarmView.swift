// AddAlarmView.swift - Updated with Snooze Section

import SwiftUI

struct AddAlarmView: View {
    @StateObject private var viewModel: AddAlarmViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var infoToShow: InfoType?
    @State private var isSaving = false
    @State private var showingSaveProgress = false
    @EnvironmentObject var dataCoordinator: DataCoordinator
    
    let onSave: (Alarm) -> Void
    let onCancel: () -> Void
    let onDelete: ((Alarm) -> Void)?
    
    init(
        alarm: Alarm = Alarm(),
        onSave: @escaping (Alarm) -> Void,
        onCancel: @escaping () -> Void,
        onDelete: ((Alarm) -> Void)? = nil
    ) {
        let viewModel = AddAlarmViewModel(alarm: alarm)
        viewModel.alarmStore = AlarmStore()
        _viewModel = StateObject(wrappedValue: AddAlarmViewModel(alarm: alarm))
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main form content
                Form {
                    // Name Section
                    Section(header: Text("NAME").textCase(.uppercase)) {
                        TextField("Alarm Name", text: $viewModel.alarm.name)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Alarm name")
                            .accessibilityHint("Enter a name for this alarm")
                            .disabled(isSaving)
                    }
                    
                    // Time Section
                    Section(header: Text("TIME").textCase(.uppercase)) {
                        DatePicker("",
                                  selection: $viewModel.alarm.alarmTime,
                                  displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .frame(maxHeight: 120)
                            .accessibilityLabel("Alarm time")
                            .accessibilityHint("Select the time for this alarm")
                            .disabled(isSaving)
                    }
                    
                    // Recurrence Section
                    RecurrenceSection(viewModel: viewModel)
                        .disabled(isSaving)
                    
                    // Sound & Vibration Section
                    SoundSection(viewModel: viewModel)
                        .disabled(isSaving)
                    
                    // NEW: Snooze Section
                    SnoozeSection(viewModel: viewModel)
                        .disabled(isSaving)
                    
                    // Smart Settings Section
                    SmartSettingsSection(viewModel: viewModel, infoToShow: $infoToShow)
                        .disabled(isSaving)
                    
                    // Smart-only fields
                    if viewModel.alarm.smartEnabled {
                        SmartAlarmSections(viewModel: viewModel, infoToShow: $infoToShow)
                            .disabled(isSaving)
                    }
                    
                    // Inline error display
                    if let error = viewModel.errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
                    }
                    
                    // Alarm limit warning if near limit
                    if !viewModel.isEditMode && viewModel.alarmStore?.alarms.count ?? 0 >= 48 {
                        Section {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("You have \(50 - (viewModel.alarmStore?.alarms.count ?? 0)) alarm slots remaining")
                                    .font(.footnote)
                                    .foregroundColor(.orange)
                            }
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
                            .frame(minHeight: 44)
                            .accessibilityLabel("Delete alarm")
                            .accessibilityHint("Remove this alarm permanently")
                            .disabled(isSaving)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 96) // Account for bottom nav bar
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Color(.systemGroupedBackground))
                .opacity(isSaving ? 0.5 : 1.0)
                .allowsHitTesting(!isSaving)
                
                // Loading overlay
                if isSaving {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text("Saving alarm...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if viewModel.alarm.smartEnabled {
                            Text("Calculating optimal wake time")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.75))
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationTitle(viewModel.isEditMode ? "Edit Alarm" : "Add Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: handleCancel)
                        .disabled(isSaving)
                        .accessibilityLabel("Cancel")
                        .accessibilityHint("Discard changes and return to alarm list")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: handleSave)
                        .disabled(!viewModel.isValid || isSaving)
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
                        handleDelete()
                    }
                }
            } message: {
                Text("This alarm will be permanently deleted.")
            }
            .sheet(isPresented: $viewModel.showAddressSelector) {
                AddressSelectorSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showAddNewAddress) {
                AddNewAddressSheet(viewModel: viewModel)
            }
            .alert("Save to Profile?", isPresented: $viewModel.showSaveToProfilePrompt) {
                Button("Cancel", role: .cancel) {
                    viewModel.pendingAddressToSave = nil
                }
                Button("Save") {
                    viewModel.saveAddressToProfile()
                }
            } message: {
                Text("Would you like to save this address to your profile for future use?")
            }
            .alert("Update Default Travel Method?", isPresented: $viewModel.showTravelMethodUpdate) {
                Button("Keep Current", role: .cancel) { }
                Button("Update Profile") {
                    viewModel.updateTravelMethodInProfile()
                }
            } message: {
                Text("You've consistently chosen \(viewModel.selectedTravelMethod.displayName). Update your profile default?")
            }
        }
        .interactiveDismissDisabled(isSaving)
    }
    
    // MARK: - Actions
    private func handleCancel() {
        onCancel()
        dismiss()
    }
    
    private func handleSave() {
        // Validate
        guard viewModel.validate() else { return }
        guard validateNotPastTime() else {
            showPastTimeError()
            return
        }
        guard validate24HourLimit() else {
            show24HourLimitError()
            return
        }
        
        // Show loading state
        withAnimation(.easeInOut(duration: 0.3)) {
            isSaving = true
        }
        
        // Prepare alarm data
        prepareAlarmData()
        
        // Call onSave callback (which triggers DataCoordinator)
        onSave(viewModel.alarm)
        
        // Dismiss immediately - don't wait for async operations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
    
    private func handleDelete() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isSaving = true
        }
        
        if let onDelete = onDelete {
            onDelete(viewModel.alarm)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
    
    private func prepareAlarmData() {
        let calendar = Calendar.current
        
        // Extract time components from UI pickers
        let alarmTimeComponents = calendar.dateComponents([.hour, .minute], from: viewModel.alarm.alarmTime)
        let arrivalTimeComponents = calendar.dateComponents([.hour, .minute], from: viewModel.effectiveArrivalTime)
        
        // Handle different schedule types
        switch viewModel.alarm.schedule {
        case .oneTime:
            handleOneTimeAlarm(alarmTimeComponents, arrivalTimeComponents)
        case .specificDate(let userSpecifiedDate):
            handleSpecificDateAlarm(userSpecifiedDate, alarmTimeComponents, arrivalTimeComponents)
        case .repeatingDays(let weekdays):
            handleRepeatingAlarm(weekdays, alarmTimeComponents, arrivalTimeComponents)
        }
        
        // Update preparation interval
        viewModel.updatePreparationInterval()
    }
    
    // MARK: - Validation Functions

    private func validateNotPastTime() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch viewModel.alarm.schedule {
        case .oneTime:
            return true
        case .specificDate(let userSpecifiedDate):
            let alarmTimeComponents = calendar.dateComponents([.hour, .minute], from: viewModel.alarm.alarmTime)
            let targetDate = calendar.startOfDay(for: userSpecifiedDate)
            let specificAlarmTime = calendar.date(bySettingHour: alarmTimeComponents.hour ?? 0,
                                                minute: alarmTimeComponents.minute ?? 0,
                                                second: 0,
                                                of: targetDate)!
            return specificAlarmTime > now
        case .repeatingDays(_):
            return true
        }
    }

    private func validate24HourLimit() -> Bool {
        guard viewModel.alarm.smartEnabled else { return true }
        
        let calendar = Calendar.current
        let alarmTimeComponents = calendar.dateComponents([.hour, .minute], from: viewModel.alarm.alarmTime)
        let arrivalTimeComponents = calendar.dateComponents([.hour, .minute], from: viewModel.effectiveArrivalTime)
        
        let alarmMinutes = (alarmTimeComponents.hour ?? 0) * 60 + (alarmTimeComponents.minute ?? 0)
        let arrivalMinutes = (arrivalTimeComponents.hour ?? 0) * 60 + (arrivalTimeComponents.minute ?? 0)
        
        let timeDifference = arrivalMinutes < alarmMinutes ?
            (1440 - alarmMinutes + arrivalMinutes) :
            (arrivalMinutes - alarmMinutes)
        
        return timeDifference <= 1440
    }

    private func showPastTimeError() {
        viewModel.errorMessage = "The alarm time cannot be set for a time that has already passed."
    }

    private func show24HourLimitError() {
        viewModel.errorMessage = "The arrival time cannot be more than 24 hours after the alarm time."
    }

    // MARK: - Schedule Type Handlers

    private func handleOneTimeAlarm(_ alarmComponents: DateComponents, _ arrivalComponents: DateComponents) {
        let calendar = Calendar.current
        let now = Date()
        
        let today = calendar.startOfDay(for: now)
        let todayAlarmTime = calendar.date(bySettingHour: alarmComponents.hour ?? 0,
                                         minute: alarmComponents.minute ?? 0,
                                         second: 0,
                                         of: today)!
        
        let targetDate = todayAlarmTime > now ? today : calendar.date(byAdding: .day, value: 1, to: today)!
        
        viewModel.alarm.alarmTime = calendar.date(bySettingHour: alarmComponents.hour ?? 0,
                                           minute: alarmComponents.minute ?? 0,
                                           second: 0,
                                           of: targetDate)!
        
        if viewModel.alarm.smartEnabled {
            let arrivalDate = calculateArrivalDate(for: targetDate,
                                                 alarmComponents: alarmComponents,
                                                 arrivalComponents: arrivalComponents)
            viewModel.alarm.arrivalTime = calendar.date(bySettingHour: arrivalComponents.hour ?? 0,
                                                       minute: arrivalComponents.minute ?? 0,
                                                       second: 0,
                                                       of: arrivalDate)!
        }
    }

    private func handleSpecificDateAlarm(_ userSpecifiedDate: Date, _ alarmComponents: DateComponents, _ arrivalComponents: DateComponents) {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: userSpecifiedDate)
        
        viewModel.alarm.alarmTime = calendar.date(bySettingHour: alarmComponents.hour ?? 0,
                                           minute: alarmComponents.minute ?? 0,
                                           second: 0,
                                           of: targetDate)!
        
        if viewModel.alarm.smartEnabled {
            let arrivalDate = calculateArrivalDate(for: targetDate,
                                                 alarmComponents: alarmComponents,
                                                 arrivalComponents: arrivalComponents)
            viewModel.alarm.arrivalTime = calendar.date(bySettingHour: arrivalComponents.hour ?? 0,
                                                       minute: arrivalComponents.minute ?? 0,
                                                       second: 0,
                                                       of: arrivalDate)!
        }
    }

    private func handleRepeatingAlarm(_ weekdays: [Weekday], _ alarmComponents: DateComponents, _ arrivalComponents: DateComponents) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let alarmTime = calendar.date(bySettingHour: alarmComponents.hour ?? 0,
                                     minute: alarmComponents.minute ?? 0,
                                     second: 0,
                                     of: today)!
        
        viewModel.alarm.alarmTime = alarmTime
        
        if viewModel.alarm.smartEnabled {
            let arrivalDate = calculateArrivalDate(for: today,
                                                 alarmComponents: alarmComponents,
                                                 arrivalComponents: arrivalComponents)
            let arrivalTime = calendar.date(bySettingHour: arrivalComponents.hour ?? 0,
                                           minute: arrivalComponents.minute ?? 0,
                                           second: 0,
                                           of: arrivalDate)!
            
            viewModel.alarm.arrivalTime = arrivalTime
        }
    }

    private func calculateArrivalDate(for alarmDate: Date, alarmComponents: DateComponents, arrivalComponents: DateComponents) -> Date {
        let calendar = Calendar.current
        
        let alarmMinutes = (alarmComponents.hour ?? 0) * 60 + (alarmComponents.minute ?? 0)
        let arrivalMinutes = (arrivalComponents.hour ?? 0) * 60 + (arrivalComponents.minute ?? 0)
        
        if arrivalMinutes < alarmMinutes {
            return calendar.date(byAdding: .day, value: 1, to: alarmDate)!
        } else {
            return alarmDate
        }
    }
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
            isEnabled: true,
            schedule: .repeatingDays([.monday, .tuesday, .wednesday])
        ),
        onSave: { _ in },
        onCancel: { },
        onDelete: { _ in }
    )
}
