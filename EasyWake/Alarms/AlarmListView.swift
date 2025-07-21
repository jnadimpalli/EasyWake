// AlarmListView.swift - Complete Fix

import MapKit
import SwiftUI

// MARK: - Custom Colors (keep your existing colors)
extension Color {
    static let customBlue = Color(red: 0 / 255, green: 187 / 255, blue: 249 / 255)  // #00BBF9

    // Adaptive colors for light/dark mode
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

    // New disabled text color for FR-3
    static let disabledText = Color.gray.opacity(0.6)
}

struct AlarmListView: View {
    // CRITICAL FIX: Use shared AlarmStore from environment
    @EnvironmentObject var store: AlarmStore
    @EnvironmentObject var dataCoordinator: DataCoordinator
    
    @State private var navigateToSettings = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
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
    
    // Add refresh trigger
    @State private var refreshID = UUID()

    // Helper function to sort weekdays in Mon-Sun order
    private func sortedWeekdaysDisplay(_ weekdays: [Weekday]) -> String {
        let weekdayOrder: [Weekday] = [
            .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
        ]

        let sortedWeekdays = weekdayOrder.filter { weekdays.contains($0) }
        return sortedWeekdays.map { $0.rawValue.prefix(3).capitalized }.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content with flexible layout
                VStack(spacing: 0) {
                    // MARK: Top Bar
                    VStack(spacing: 0) {
                        HStack {
                            Text("Alarms")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                            // Only show gear icon when there are alarms
                            if !store.alarms.isEmpty {
                                Button {
                                    navigateToSettings = true
                                } label: {
                                    Image(systemName: "gearshape")
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                        Divider()
                            .padding(.horizontal, 16)
                    }
                    .frame(height: 60)

                    // MARK: Selection Mode Toolbar
                    if isSelectionMode {
                        selectionToolbar()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // MARK: Main Content Area (Flexible)
                    if store.alarms.isEmpty {
                        // Empty State
                        emptyAlarmState()
                    } else {
                        // Normal Alarms List
                        normalAlarmsList()
                    }
                }

                // MARK: Bottom Cards - Positioned at bottom
                VStack {
                    Spacer()

                    VStack(spacing: 0) {
                        Divider()
                            .padding(.horizontal, 16)

                        HStack(spacing: 16) {
                            WeatherCardView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)  // Fixed height for cards
                            TrafficMapView(region: $region)
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)  // Fixed height for cards
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 108)  // 96pt tab bar height + 12pt spacing
                    }
                    .background(Color(.systemBackground))
                }

                // MARK: - Error Toast
                if let error = deletionError {
                    VStack {
                        Spacer()
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
                        .padding(.bottom, 140)  // Position above tab bar with more clearance
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .zIndex(2)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                deletionError = nil
                            }
                        }
                    }
                }
            }

            // MARK: Navigation & Modals
            .fullScreenCover(item: $alarmToEdit) { alarm in
                AddAlarmView(
                    alarm: alarm,
                    onSave: { updatedAlarm in
                        Task {
                            await dataCoordinator.updateAlarm(updatedAlarm)
                            refreshID = UUID() // Force refresh
                        }
                        alarmToEdit = nil
                    },
                    onCancel: {
                        alarmToEdit = nil
                    },
                    onDelete: { alarmToDelete in
                        Task {
                            await dataCoordinator.deleteAlarm(alarmToDelete)
                            refreshID = UUID() // Force refresh
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
                            refreshID = UUID() // Force refresh
                        }
                        store.showingAddModal = false
                    },
                    onCancel: {
                        store.showingAddModal = false
                    }
                )
            }
            .navigationDestination(isPresented: $navigateToSettings) {
                SettingsView()
            }
            .alert(
                "Delete \(selectedAlarms.count) alarm\(selectedAlarms.count == 1 ? "" : "s")?",
                isPresented: $showingBatchDeleteAlert
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    batchDeleteSelectedAlarms()
                }
            } message: {
                Text("This cannot be undone.")
            }
            .onAppear {
                // Exit selection mode when view appears (handles app backgrounding)
                if isSelectionMode {
                    exitSelectionMode()
                }
            }
            // Add explicit refresh trigger when alarms array changes
            .onChange(of: store.alarms) { _, _ in
                // Clear any stale UI state when alarms change
                cleanupStaleUIState()
            }
            .navigationBarBackButtonHidden(true)
        }
        .id(refreshID) // Force view refresh when ID changes
        .onReceive(NotificationCenter.default.publisher(for: .alarmCreated)) { notification in
            // Don't trigger UI updates that might cause modal to reopen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                refreshID = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .alarmUpdated)) { notification in
            // Only refresh if we're not coming from a creation
            if notification.userInfo?["fromCreation"] as? Bool != true {
                refreshID = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .alarmDeleted)) { _ in
            // Force view update and cleanup
            cleanupStaleUIState()
            refreshID = UUID()
        }
    }

    // MARK: - Cleanup Stale UI State
    private func cleanupStaleUIState() {
        let currentAlarmIds = Set(store.alarms.map { $0.id })

        // Remove swipe offsets for deleted alarms
        swipeOffsets = swipeOffsets.filter { currentAlarmIds.contains($0.key) }

        // Remove deletion states for non-existent alarms
        isDeleting = isDeleting.intersection(currentAlarmIds)

        // Remove selections for deleted alarms
        selectedAlarms = selectedAlarms.intersection(currentAlarmIds)

        // Exit selection mode if no alarms are selected
        if isSelectionMode && selectedAlarms.isEmpty && !store.alarms.isEmpty {
            exitSelectionMode()
        }
    }
    
    private func deleteAlarm(_ alarm: Alarm) {
        // Clean up UI state immediately
        withAnimation(.easeOut(duration: 0.2)) {
            swipeOffsets[alarm.id] = 0
            isDeleting.insert(alarm.id)
        }
        
        Task {
            await dataCoordinator.deleteAlarm(alarm)
            
            // Force UI update after deletion
            await MainActor.run {
                // Clean up all UI state for this alarm
                swipeOffsets.removeValue(forKey: alarm.id)
                isDeleting.remove(alarm.id)
                selectedAlarms.remove(alarm.id)
                
                // Force refresh
                refreshID = UUID()
            }
        }
    }

    // REFACTOR: Remove comprehensive cleanup call
    private func batchDeleteSelectedAlarms() {
        let alarmsToDelete = store.alarms.filter { selectedAlarms.contains($0.id) }
        Task {
            for alarm in alarmsToDelete {
                await dataCoordinator.deleteAlarm(alarm)
            }
            exitSelectionMode()
        }
    }

    // MARK: – Add Button Component
    @ViewBuilder
    private func addButton() -> some View {
        Button {
            store.showingAddModal = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.customBlue)
                .background(
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 56, height: 56)
                )
        }
        .frame(width: 56, height: 56)
        .padding(.vertical, 16)
    }

    // MARK: - Empty Alarm State (updated to use flexible space)
    @ViewBuilder
    private func emptyAlarmState() -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Calculate available height minus bottom cards and tab bar
                    let cardAreaHeight: CGFloat = 120 + 16 + 108 + 1  // card + top padding + bottom padding + divider
                    let minTopSpacing: CGFloat = 24

                    Spacer()
                        .frame(height: minTopSpacing)

                    // Illustration
                    Image("emptyAlarmSet")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxHeight: min(
                                geometry.size.height * 0.4,
                                geometry.size.height - cardAreaHeight - 200  // Leave room for text and spacing
                            )
                        )
                        .accessibilityHidden(true)

                    Spacer()
                        .frame(height: 12)

                    // "No alarms yet" text
                    Text("No alarms yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .accessibilityLabel("No alarms yet")

                    Spacer()
                        .frame(height: 16)

                    // Add button
                    Button {
                        store.showingAddModal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.customBlue)
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Add alarm")
                    .accessibilityHint("Create your first alarm")

                    // Push content up but leave room for bottom cards
                    Spacer(minLength: cardAreaHeight + 40)
                }
                .frame(minHeight: geometry.size.height)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Normal Alarms List (updated to use flexible layout)
    @ViewBuilder
    private func normalAlarmsList() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Use ForEach with the store's alarms directly
                    ForEach(store.sortedAlarms) { alarm in
                        alarmRow(alarm)
                            .id(alarm.id)
                    }

                    // Add button
                    addButton()
                        .id("addButton")

                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 120 + 108 + 32)
            }
        }
    }

    // MARK: – Alarm Row with Multi-Select Support and Toggle Switch
    @ViewBuilder
    private func alarmRow(_ alarm: Alarm) -> some View {
        let swipeOffset = swipeOffsets[alarm.id] ?? 0
        let deleteButtonWidth: CGFloat = 88
        let isRTL = layoutDirection == .rightToLeft
        let swipeThreshold = deleteButtonWidth * 0.6
        let isSelected = selectedAlarms.contains(alarm.id)

        ZStack(alignment: isRTL ? .leading : .trailing) {
            // Delete button background (only in normal mode)
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

            // Main alarm content
            HStack(spacing: 12) {
                // Selection checkbox (only in selection mode)
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

                // Text content
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(alarm.name)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundColor(alarm.isEnabled ? .primary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)

                        if alarm.smartEnabled {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(alarm.isEnabled ? .customBlue : .disabledText)
                                .font(.body)
                                .opacity(alarm.isEnabled ? 1.0 : 0.8)
                        }
                    }

                    // Use the display properties instead of raw time
                    switch alarm.schedule {
                    case .specificDate(let date):
                        Text(alarm.displayTime)  // Use displayTime instead of alarm.time
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(alarm.isEnabled ? .primary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)
                        Text(date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(alarm.isEnabled ? .secondary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)
                    case .repeatingDays(let weekdays):
                        Text(alarm.displayTime)  // Use displayTime
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(alarm.isEnabled ? .primary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)
                        Text(sortedWeekdaysDisplay(weekdays))
                            .font(.footnote)
                            .foregroundColor(alarm.isEnabled ? .secondary : .disabledText)
                            .opacity(alarm.isEnabled ? 1.0 : 0.8)
                    case .oneTime:
                        Text(alarm.displayTime)  // Use displayTime
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

                // Toggle switch instead of bell icon (FR-1 & FR-2)
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
                    .frame(width: 44, height: 28)  // FR-6: Appropriate sizing (≈44×28pt)
                    .disabled(isDeleting.contains(alarm.id))
                    .accessibilityLabel("Alarm \(alarm.name)")  // FR-5: Accessibility
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
            .offset(x: isSelectionMode ? 0 : swipeOffset)  // Disable swipe in selection mode
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
                print("Long press detected on alarm: \(alarm.name)")  // Debug print
                if !isSelectionMode {
                    enterSelectionMode(with: alarm.id)
                }
            }
            .simultaneousGesture(
                // Only add swipe gesture in normal mode
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

                            let isHorizontalSwipe = angle < (25 * .pi / 180)  // Stricter angle
                            let horizontalDistance = abs(translation.width)

                            if isHorizontalSwipe && horizontalDistance > 30 {
                                let maxSwipe = deleteButtonWidth

                                let normalizedTranslation: CGFloat
                                if isRTL {
                                    normalizedTranslation = max(0, min(maxSwipe, translation.width))
                                } else {
                                    normalizedTranslation = min(
                                        0, max(-maxSwipe, translation.width))
                                }

                                swipeOffsets[alarm.id] = normalizedTranslation
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
                                    shouldShowDelete =
                                        translation.width > swipeThreshold || velocity.width > 1000
                                } else {
                                    shouldShowDelete =
                                        translation.width < -swipeThreshold
                                        || velocity.width < -1000
                                }

                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if shouldShowDelete {
                                        swipeOffsets[alarm.id] =
                                            isRTL ? deleteButtonWidth : -deleteButtonWidth
                                    } else {
                                        swipeOffsets[alarm.id] = 0
                                    }
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
        // Haptic feedback for entering selection mode
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

            // Clear any active swipe states
            for alarmId in swipeOffsets.keys {
                swipeOffsets[alarmId] = 0
            }
        }
    }

    private func toggleAlarmSelection(_ alarmId: UUID) {
        // Haptic feedback for selection toggle
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
            // Delete button
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

            // Cancel button
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
