// AlarmListView.swift

import SwiftUI

// MARK: - Custom Colors
extension Color {
    static let customBlue = Color(red: 18 / 255, green: 176 / 255, blue: 228 / 255)  // #00BBF9

    static let alarmCardBackground = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.secondarySystemGroupedBackground
                : UIColor.secondarySystemGroupedBackground
        })

    static let alarmCardBorder = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.separator
                : UIColor.separator
        })

    static let smartAlarmBackground = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0 / 255, green: 187 / 255, blue: 249 / 255, alpha: 0.15)
                : UIColor(red: 0 / 255, green: 187 / 255, blue: 249 / 255, alpha: 0.08)
        })

    static let smartAlarmBorder = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0 / 255, green: 187 / 255, blue: 249 / 255, alpha: 0.4)
                : UIColor(red: 0 / 255, green: 187 / 255, blue: 249 / 255, alpha: 0.3)
        })

    static let selectionBackground = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0 / 255, green: 187 / 255, blue: 249 / 255, alpha: 0.2)
                : UIColor(red: 0 / 255, green: 187 / 255, blue: 249 / 255, alpha: 0.12)
        })

    static let selectionBorder = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0 / 255, green: 187 / 255, blue: 249 / 255, alpha: 0.6)
                : UIColor(red: 0 / 255, green: 187 / 255, blue: 249 / 255, alpha: 0.5)
        })

    static let disabledText = Color.gray.opacity(0.6)
}

struct AlarmListView: View {
    @EnvironmentObject var store: AlarmStore
    @EnvironmentObject var dataCoordinator: DataCoordinator
    
    @State private var navigateToSettings = false
    @State private var alarmToEdit: Alarm? = nil

    // MARK: - Swipe to Delete State
    @State private var swipeOffsets: [UUID: CGFloat] = [:]
    @State private var isDeleting: Set<UUID> = []
    @State private var deletionError: String?
    @Environment(\.layoutDirection) private var layoutDirection

    // MARK: - Multi-Select State
    @State private var isSelectionMode: Bool = false
    @State private var selectedAlarms: Set<UUID> = []
    @State private var showingBatchDeleteAlert: Bool = false
    
    private let topBarHeight: CGFloat = 60
    private let alarmRowSpacing: CGFloat = 16
    private let sectionPadding: CGFloat = 16
    private let bottomNavBarHeight: CGFloat = 56

    // Helper function to sort weekdays in Mon-Sun order
    private func sortedWeekdaysDisplay(_ weekdays: [Weekday]) -> String {
        let weekdayOrder: [Weekday] = [
            .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
        ]

        let sortedWeekdays = weekdayOrder.filter { weekdays.contains($0) }
        return sortedWeekdays.map { $0.rawValue.prefix(3).capitalized }.joined(separator: ", ")
    }
    
    // MARK: - Check if there are upcoming alarms
    private var hasUpcomingAlarms: Bool {
        let now = Date()
        let next24Hours = now.addingTimeInterval(24 * 60 * 60)
        
        return store.alarms.contains { alarm in
            guard alarm.isEnabled,
                  let nextOccurrence = alarm.nextOccurrenceTime else { return false }
            return nextOccurrence > now && nextOccurrence <= next24Hours
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Top Bar (Fixed)
                VStack(spacing: 0) {
                    HStack {
                        Text("Alarms")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Button {
                            store.showingAddModal = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.customBlue)
                        }
                        .frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Divider()
                        .padding(.horizontal, 16)
                }
                .frame(height: topBarHeight)
                .background(Color(.systemBackground))

                // Selection Mode Toolbar
                if isSelectionMode {
                    selectionToolbar()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // MARK: - Main Content Area
                if hasUpcomingAlarms {
                    // Split Layout: Scrollable alarms on top, fixed upcoming alarms at bottom
                    VStack(spacing: 0) {
                        // Alarm List (Scrollable)
                        ScrollView {
                            VStack(spacing: 0) {
                                if store.alarms.isEmpty {
                                    emptyAlarmStateContent()
                                        .padding(.top, 40)
                                } else {
                                    VStack(spacing: alarmRowSpacing) {
                                        ForEach(store.sortedAlarms) { alarm in
                                            alarmRow(alarm)
                                                .id(alarm.id)
                                        }
                                    }
                                    .padding(.horizontal, sectionPadding)
                                    .padding(.top, sectionPadding)
                                    .padding(.bottom, sectionPadding)
                                }
                            }
                        }
                        .background(Color(.systemGroupedBackground))
                        
                        // Upcoming Alarms Section (Fixed at bottom)
                        VStack(spacing: 0) {
                            Divider()
                                .padding(.horizontal, 16)
                            
                            UpcomingAlarmsContainer()
                                .environmentObject(store)
                                .padding(.top, 12)
                                .padding(.bottom, 12)
                        }
                        .background(Color(.systemBackground))
                    }
                } else {
                    // Full height scrollable list when no upcoming alarms
                    ScrollView {
                        VStack(spacing: 0) {
                            if store.alarms.isEmpty {
                                emptyAlarmStateContent()
                                    .padding(.top, 40)
                            } else {
                                VStack(spacing: alarmRowSpacing) {
                                    ForEach(store.sortedAlarms) { alarm in
                                        alarmRow(alarm)
                                            .id(alarm.id)
                                    }
                                }
                                .padding(.horizontal, sectionPadding)
                                .padding(.top, sectionPadding)
                                .padding(.bottom, sectionPadding)
                            }
                        }
                        .padding(.bottom, bottomNavBarHeight)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            // Reserve space for tab bar
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: bottomNavBarHeight)
            }
            
            // MARK: - Error Toast (Overlay)
            .overlay(alignment: .bottom) {
                if let error = deletionError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                        Text(error)
                            .foregroundColor(.white)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 140)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { deletionError = nil }
                        }
                    }
                }
            }

            // MARK: — Navigation & Modals
            .fullScreenCover(item: $alarmToEdit) { alarm in
                AddAlarmView(
                    alarm: alarm,
                    onSave: { updated in
                        Task {
                            await dataCoordinator.updateAlarm(updated)
                        }
                        alarmToEdit = nil
                    },
                    onCancel: { alarmToEdit = nil },
                    onDelete: { toDelete in
                        Task {
                            await dataCoordinator.deleteAlarm(toDelete)
                        }
                        alarmToEdit = nil
                    }
                )
            }
            .fullScreenCover(isPresented: $store.showingAddModal) {
                AddAlarmView(
                    onSave: { newAlarm in
                        Task {
                            await dataCoordinator.createAlarm(newAlarm)
                        }
                        store.showingAddModal = false
                    },
                    onCancel: { store.showingAddModal = false }
                )
            }
            .navigationDestination(isPresented: $navigateToSettings) { SettingsView() }
            .alert(
                "Delete \(selectedAlarms.count) alarm\(selectedAlarms.count == 1 ? "" : "s")?",
                isPresented: $showingBatchDeleteAlert
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { batchDeleteSelectedAlarms() }
            } message: {
                Text("This cannot be undone.")
            }
            .onAppear {
                if isSelectionMode {
                    exitSelectionMode()
                }
            }
            .onChange(of: store.alarms) { _, _ in
                cleanupStaleUIState()
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    // MARK: - Empty Alarm State Content
    @ViewBuilder
    private func emptyAlarmStateContent() -> some View {
        VStack(spacing: 0) {
            Image("emptyAlarmSet")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .accessibilityHidden(true)

            Spacer()
                .frame(height: 12)

            Text("No alarms yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .accessibilityLabel("No alarms yet")

            Spacer()
                .frame(height: 16)

            Text("Tap + to create your first alarm")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Cleanup Stale UI State
    private func cleanupStaleUIState() {
        let currentAlarmIds = Set(store.alarms.map { $0.id })
        swipeOffsets = swipeOffsets.filter { currentAlarmIds.contains($0.key) }
        isDeleting = isDeleting.intersection(currentAlarmIds)
        selectedAlarms = selectedAlarms.intersection(currentAlarmIds)
        if isSelectionMode && selectedAlarms.isEmpty && !store.alarms.isEmpty {
            exitSelectionMode()
        }
    }
    
    private func deleteAlarm(_ alarm: Alarm) {
        withAnimation(.easeOut(duration: 0.2)) {
            swipeOffsets[alarm.id] = 0
            isDeleting.insert(alarm.id)
        }
        
        Task {
            await dataCoordinator.deleteAlarm(alarm)
            
            await MainActor.run {
                swipeOffsets.removeValue(forKey: alarm.id)
                isDeleting.remove(alarm.id)
                selectedAlarms.remove(alarm.id)
            }
        }
    }

    private func batchDeleteSelectedAlarms() {
        let alarmsToDelete = store.alarms.filter { selectedAlarms.contains($0.id) }
        Task {
            for alarm in alarmsToDelete {
                await dataCoordinator.deleteAlarm(alarm)
            }
            exitSelectionMode()
        }
    }

    // MARK: – Alarm Row (unchanged)
    @ViewBuilder
    private func alarmRow(_ alarm: Alarm) -> some View {
        let swipeOffset = swipeOffsets[alarm.id] ?? 0
        let deleteButtonWidth: CGFloat = 88
        let isRTL = layoutDirection == .rightToLeft
        let swipeThreshold = deleteButtonWidth * 0.6
        let isSelected = selectedAlarms.contains(alarm.id)

        ZStack(alignment: isRTL ? .leading : .trailing) {
            if !isSelectionMode && abs(swipeOffset) > 10 {
                Button(action: {
                    deleteAlarm(alarm)
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                            .font(.title2)
                        Spacer()
                    }
                    .frame(width: deleteButtonWidth)
                    .frame(minHeight: 88)
                    .background(Color.red)
                }
                .accessibilityLabel("Delete alarm: \(alarm.name)")
                .accessibilityHint("Removes this alarm permanently")
            }

            HStack(spacing: 12) {
                if isSelectionMode {
                    Button(action: {
                        toggleAlarmSelection(alarm.id)
                    }) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .customBlue : .secondary)
                            .font(.title2)
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(isSelected ? "Selected" : "Not selected")
                    .accessibilityHint("Tap to toggle selection")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(alarm.name)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundColor(alarm.isEnabled ? .primary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)

                        if alarm.smartEnabled {
                            Image(systemName: "brain")
                                .foregroundColor(alarm.isEnabled ? .customBlue : .disabledText)
                                .font(.body)
                                .opacity(alarm.isEnabled ? 1.0 : 0.8)
                        }
                        
                        if alarm.snoozeEnabled {
                            Image(systemName: "zzz")
                                .foregroundColor(alarm.isEnabled ? .purple : .disabledText)
                                .font(.body)
                                .opacity(alarm.isEnabled ? 1.0 : 0.8)
                        }
                    }

                    switch alarm.schedule {
                    case .specificDate(let date):
                        Text(alarm.displayTime)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(alarm.isEnabled ? .primary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)
                        Text(date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(alarm.isEnabled ? .secondary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)
                    case .repeatingDays(let weekdays):
                        Text(alarm.displayTime)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(alarm.isEnabled ? .primary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)
                        Text(sortedWeekdaysDisplay(weekdays))
                            .font(.footnote)
                            .foregroundColor(alarm.isEnabled ? .secondary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)
                    case .oneTime:
                        Text(alarm.displayTime)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(alarm.isEnabled ? .primary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)
                        Text("One time")
                            .font(.footnote)
                            .foregroundColor(alarm.isEnabled ? .secondary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)
                    }
                }

                Spacer()

                if !isSelectionMode {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { alarm.isEnabled },
                            set: { newValue in
                                var updatedAlarm = alarm
                                updatedAlarm.isEnabled = newValue
                                Task {
                                    await dataCoordinator.updateAlarm(updatedAlarm)
                                }
                            }
                        )
                    )
                    .labelsHidden()
                    .frame(width: 44, height: 28)
                    .disabled(isDeleting.contains(alarm.id))
                    .accessibilityLabel("Alarm \(alarm.name)")
                    .accessibilityHint("Double-tap to turn alarm on or off")
                    .accessibilityValue(alarm.isEnabled ? "on" : "off")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(minHeight: 88)
            .background(
                Group {
                    if isSelected && isSelectionMode {
                        Color.selectionBackground
                    } else {
                        Color.alarmCardBackground
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected && isSelectionMode
                            ? Color.selectionBorder
                            : Color.gray.opacity(0.25),
                        lineWidth: isSelected && isSelectionMode ? 2.0 : 1.5
                    )
            )
            .cornerRadius(12)
            .offset(x: isSelectionMode ? 0 : swipeOffset)
            .opacity(isDeleting.contains(alarm.id) ? 0.5 : 1.0)
            .scaleEffect(isDeleting.contains(alarm.id) ? 0.95 : 1.0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(alarm.name), \(isSelected ? "Selected" : "Not selected")")
            .onTapGesture {
                if isSelectionMode {
                    toggleAlarmSelection(alarm.id)
                } else if abs(swipeOffsets[alarm.id] ?? 0) > 10 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        swipeOffsets[alarm.id] = 0
                    }
                } else {
                    alarmToEdit = alarm
                }
            }
            .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 50) {
                print("Long press detected on alarm: \(alarm.name)")
                if !isSelectionMode {
                    enterSelectionMode(with: alarm.id)
                }
            }
            .simultaneousGesture(
                !isSelectionMode
                    ? DragGesture(minimumDistance: 30, coordinateSpace: .local)
                        .onChanged { value in
                            if isDeleting.contains(alarm.id) { return }

                            let translation = value.translation
                            let startLocation = value.startLocation
                            let currentLocation = value.location

                            let deltaX = currentLocation.x - startLocation.x
                            let deltaY = currentLocation.y - startLocation.y
                            let angle = atan2(abs(deltaY), abs(deltaX))

                            let isHorizontalSwipe = angle < (25 * .pi / 180)
                            let horizontalDistance = abs(translation.width)

                            if isHorizontalSwipe && horizontalDistance > 30 {
                                let maxSwipe = deleteButtonWidth

                                let normalizedTranslation: CGFloat
                                if isRTL {
                                    normalizedTranslation = max(0, min(maxSwipe, translation.width))
                                } else {
                                    normalizedTranslation = min(0, max(-maxSwipe, translation.width))
                                }
                                
                                withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.95, blendDuration: 0)) {
                                    if abs(normalizedTranslation) > deleteButtonWidth * 0.8 {
                                        let excess = abs(normalizedTranslation) - (deleteButtonWidth * 0.8)
                                        let dampened = deleteButtonWidth * 0.8 + (excess * 0.3)
                                        swipeOffsets[alarm.id] = normalizedTranslation < 0 ? -dampened : dampened
                                    } else {
                                        swipeOffsets[alarm.id] = normalizedTranslation
                                    }
                                }
                            }
                        }
                        .onEnded { value in
                            if isDeleting.contains(alarm.id) { return }
                            
                            let translation = value.translation
                            let velocity = value.velocity
                            let startLocation = value.startLocation
                            let currentLocation = value.location
                            
                            let deltaX = currentLocation.x - startLocation.x
                            let deltaY = currentLocation.y - startLocation.y
                            let angle = atan2(abs(deltaY), abs(deltaX))
                            
                            let isHorizontalSwipe = angle < (25 * .pi / 180)
                            let horizontalDistance = abs(translation.width)
                            
                            if isHorizontalSwipe && horizontalDistance > 30 {
                                let shouldShowDelete: Bool
                                if isRTL {
                                    shouldShowDelete = translation.width > swipeThreshold || velocity.width > 500
                                } else {
                                    shouldShowDelete = translation.width < -swipeThreshold || velocity.width < -500
                                }
                                
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                    if shouldShowDelete {
                                        swipeOffsets[alarm.id] = isRTL ? deleteButtonWidth : -deleteButtonWidth
                                    } else {
                                        swipeOffsets[alarm.id] = 0
                                    }
                                }
                            } else {
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                    swipeOffsets[alarm.id] = 0
                                }
                            }
                        } : nil
            )
        }
        .clipped()
    }

    // MARK: - Selection Mode Functions
    private func enterSelectionMode(with alarmId: UUID) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        withAnimation(.easeInOut(duration: 0.3)) {
            isSelectionMode = true
            selectedAlarms.insert(alarmId)
        }
    }

    private func exitSelectionMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isSelectionMode = false
            selectedAlarms.removeAll()

            for alarmId in swipeOffsets.keys {
                swipeOffsets[alarmId] = 0
            }
        }
    }

    private func toggleAlarmSelection(_ alarmId: UUID) {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()

        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedAlarms.contains(alarmId) {
                selectedAlarms.remove(alarmId)
            } else {
                selectedAlarms.insert(alarmId)
            }
        }
    }

    // MARK: - Selection Toolbar
    @ViewBuilder
    private func selectionToolbar() -> some View {
        HStack {
            Button(action: {
                showingBatchDeleteAlert = true
            }) {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(selectedAlarms.isEmpty ? .gray : .red)
            }
            .disabled(selectedAlarms.isEmpty)
            .frame(width: 44, height: 44)
            .accessibilityLabel("Delete selected alarms")
            .accessibilityHint("Deletes all currently selected alarms")

            Spacer()

            Button(action: {
                exitSelectionMode()
            }) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.customBlue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.customBlue.opacity(0.1))
                    )
            }
            .frame(height: 44)
            .accessibilityLabel("Cancel selection")
            .accessibilityHint("Exits selection mode without deleting")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 0))
    }
}

#Preview {
    AlarmListView()
        .environmentObject(AlarmStore())
        .environmentObject(DataCoordinator(alarmStore: AlarmStore(), profileViewModel: ProfileViewModel()))
}
