// WeatherAlarmCard.swift - Weather-Alarm Integration Card

import SwiftUI
import WeatherKit

// MARK: - Weather Alarm Adjustment Data Model
struct WeatherAlarmAdjustment: Identifiable, Equatable {
    let id = UUID()
    let alarmId: UUID  // Store ID instead of full alarm
    let originalTime: Date
    let adjustedTime: Date
    let adjustmentMinutes: Int
    let extraTimeMinutes: Int
    let weatherCondition: WeatherCondition
    let routeSummary: String
    let explanation: String
    let isSignificant: Bool // ≥ 5 minutes adjustment
    
    // Add computed property to get current alarm
    public func getCurrentAlarm(from alarmStore: AlarmStore) -> Alarm? {
        return alarmStore.alarms.first { $0.id == alarmId }
    }
    
    var adjustmentText: String {
        if adjustmentMinutes < 0 {
            // Can sleep in!
            let sleepInMinutes = abs(adjustmentMinutes)
            if sleepInMinutes < 60 {
                return "\(sleepInMinutes) min extra sleep!"
            } else {
                let hours = sleepInMinutes / 60
                let minutes = sleepInMinutes % 60
                if minutes == 0 {
                    return "\(hours) hr extra sleep!"
                } else {
                    return "\(hours) hr \(minutes) min extra sleep!"
                }
            }
        } else {
            // Need to wake up earlier
            if adjustmentMinutes < 60 {
                return "\(adjustmentMinutes) min earlier"
            } else {
                let hours = adjustmentMinutes / 60
                let minutes = adjustmentMinutes % 60
                if minutes == 0 {
                    return "\(hours) hr earlier"
                } else {
                    return "\(hours) hr \(minutes) min earlier"
                }
            }
        }
    }
    
    var canSleepIn: Bool {
        return adjustmentMinutes < 0
    }
    
    // MARK: - Equatable conformance
    static func == (lhs: WeatherAlarmAdjustment, rhs: WeatherAlarmAdjustment) -> Bool {
        return lhs.id == rhs.id &&
               lhs.alarmId == rhs.alarmId &&
               lhs.originalTime == rhs.originalTime &&
               lhs.adjustedTime == rhs.adjustedTime &&
               lhs.adjustmentMinutes == rhs.adjustmentMinutes
    }
}

// MARK: - Single Weather Alarm Card
struct WeatherAlarmCard: View {
    let adjustment: WeatherAlarmAdjustment
    @EnvironmentObject var alarmStore: AlarmStore
    let onTap: () -> Void
    let onDismiss: () -> Void
    let onLongPress: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    // Add computed property for current alarm
    private var alarm: Alarm? {
        adjustment.getCurrentAlarm(from: alarmStore)
    }
    
    var body: some View {
        if let alarm = alarm {
            Button(action: onTap) {
                VStack(spacing: 0) {
                    // Header with weather icon and condition
                    headerSection(alarm: alarm)
                    
                    // Time Adjustment Section
                    timeAdjustmentSection
                    
                    // Route Summary
                    routeSummarySection
                }
            }
            .buttonStyle(PlainButtonStyle())
            .background(cardBackground)
            .cornerRadius(12)
            .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(minimumDuration: 0.5) {
                onLongPress()
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
            .onTapGesture {
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.selectionChanged()
                onTap()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(alarm: alarm))
            .accessibilityHint("Tap to view alarm details, or swipe up to dismiss")
        } else {
            // Handle case where alarm was deleted
            EmptyView()
        }
    }
    
    // MARK: - Subviews (broken down to fix complex expression)
    private func headerSection(alarm: Alarm) -> some View {
        VStack(spacing: 0) {
            // Top row with dismiss button
            HStack {
                Spacer()
                
                // Dismiss Button - moved to top right
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Main header content
            HStack(spacing: 12) {
                // Weather Icon
                ZStack {
                    Circle()
                        .fill(adjustment.weatherCondition.severity.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: adjustment.weatherCondition.icon)
                        .font(.title3)
                        .foregroundColor(adjustment.weatherCondition.severity.color)
                        .symbolRenderingMode(.multicolor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    // Alarm Name
                    Text(alarm.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Weather Condition
                    Text(adjustment.weatherCondition.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
    
    private var timeAdjustmentSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original Time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    // Use the alarm's display time
                    if let alarm = alarm {
                        Text(alarm.displayTime)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                            .strikethrough(!adjustment.canSleepIn, color: .secondary)
                    } else {
                        Text(adjustment.originalTime, style: .time)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                            .strikethrough(!adjustment.canSleepIn, color: .secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(adjustment.canSleepIn ? "Sleep Until" : "Wake Up At")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(adjustment.canSleepIn ? .green : .secondary)
                        .textCase(.uppercase)
                    
                    // Format the adjusted time in local timezone
                    Text(formatLocalTime(adjustment.adjustedTime))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(adjustment.canSleepIn ? .green : .secondary)
                }
            }
            
            // Show sleep-in bonus or wake-early warning
            if adjustment.canSleepIn {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    
                    Text("Good news! You can sleep in \(adjustment.adjustmentText)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.green)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if adjustment.adjustmentMinutes > 0 {
                Text("\(adjustment.adjustmentText) • \(adjustment.explanation)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var routeSummarySection: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(adjustment.routeSummary)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        adjustment.canSleepIn
                            ? Color.green.opacity(0.4)
                            : adjustment.weatherCondition.severity.color.opacity(0.3),
                        lineWidth: 1.5
                    )
            )
    }
    
    private var shadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15)
    }
    
    // MARK: - Simplified accessibility label
    private func accessibilityLabel(alarm: Alarm) -> String {
        let alarmName = alarm.name
        let weatherDesc = adjustment.weatherCondition.description
        let adjustmentDesc = adjustment.adjustmentText
        
        return "Weather alarm adjustment for \(alarmName). \(weatherDesc) expected. \(adjustmentDesc)."
    }
    
    private func formatLocalTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

// MARK: - Weather Alarm Carousel Container
struct WeatherAlarmCarousel: View {
    let adjustments: [WeatherAlarmAdjustment]
    let onCardTap: (WeatherAlarmAdjustment) -> Void
    let onCardDismiss: (WeatherAlarmAdjustment) -> Void
    let onCardLongPress: (WeatherAlarmAdjustment) -> Void
    @EnvironmentObject var alarmStore: AlarmStore
    
    @State private var currentIndex = 0
    @State private var autoAdvanceTimer: Timer?
    @State private var pauseAutoAdvance = false
    @State private var isUserInteracting = false
    
    private let maxDisplayedAlarms = 5
    
    var body: some View {
        VStack(spacing: 0) {
            if adjustments.count == 1 {
                // Single card
                WeatherAlarmCard(
                    adjustment: adjustments[0],
                    onTap: { onCardTap(adjustments[0]) },
                    onDismiss: { onCardDismiss(adjustments[0]) },
                    onLongPress: { onCardLongPress(adjustments[0]) }
                )
                .environmentObject(alarmStore)
                .frame(minHeight: 120)
            } else {
                // Multiple cards carousel
                VStack(spacing: 8) {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(displayedAdjustments.enumerated()), id: \.element.id) { index, adjustment in
                            WeatherAlarmCard(
                                adjustment: adjustment,
                                onTap: { onCardTap(adjustment) },
                                onDismiss: { onCardDismiss(adjustment) },
                                onLongPress: { onCardLongPress(adjustment) }
                            )
                            .environmentObject(alarmStore)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 120)
                    .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                        if !pauseAutoAdvance && !isUserInteracting && displayedAdjustments.count > 1 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentIndex = (currentIndex + 1) % displayedAdjustments.count
                            }
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { _ in
                                isUserInteracting = true
                                pauseAutoAdvance = true
                            }
                            .onEnded { _ in
                                isUserInteracting = false
                                // Resume auto-advance after 10 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                    pauseAutoAdvance = false
                                }
                            }
                    )
                    
                    // Page Indicators
                    if displayedAdjustments.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(0..<displayedAdjustments.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(index == currentIndex ? 1.0 : 0.8)
                                    .animation(.easeInOut(duration: 0.25), value: currentIndex)
                            }
                            
                            if hiddenAlarmsCount > 0 {
                                Text("and \(hiddenAlarmsCount) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            // Reset to first item when adjustments change
            currentIndex = 0
        }
        .onChange(of: adjustments) { _, _ in
            currentIndex = 0
        }
    }
    
    private var displayedAdjustments: [WeatherAlarmAdjustment] {
        Array(adjustments.prefix(maxDisplayedAlarms))
    }
    
    private var hiddenAlarmsCount: Int {
        max(0, adjustments.count - maxDisplayedAlarms)
    }
}

// MARK: - Weather Alarm Container (Main Integration Point)
struct WeatherAlarmContainer: View {
    @ObservedObject var weatherAlarmService: WeatherAlarmService
    @State private var showingAlarmDetail: Alarm?
    @State private var showingContextMenu: WeatherAlarmAdjustment?
    @EnvironmentObject var alarmStore: AlarmStore
    
    @State private var hasAdjustments = false
    
    var body: some View {
        Group {
            if !weatherAlarmService.activeAdjustments.isEmpty {
                VStack(spacing: 12) {
                    // Section Header
                    HStack {
                        Label("Weather Impact", systemImage: "cloud.bolt.rain.fill")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        if weatherAlarmService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Weather Alarm Cards
                    WeatherAlarmCarousel(
                        adjustments: weatherAlarmService.activeAdjustments.map { alarmWithAdjustment in
                            // Convert AlarmWithAdjustment to WeatherAlarmAdjustment
                            WeatherAlarmAdjustment(
                                alarmId: alarmWithAdjustment.alarm.id,
                                originalTime: alarmWithAdjustment.alarm.nextOccurrenceTime ?? alarmWithAdjustment.alarm.alarmTime,
                                adjustedTime: alarmWithAdjustment.adjustment.adjustedWakeTime,
                                adjustmentMinutes: alarmWithAdjustment.adjustment.adjustmentMinutes,
                                extraTimeMinutes: 0, // This field doesn't exist in the new structure
                                weatherCondition: alarmWithAdjustment.weatherCondition,
                                routeSummary: alarmWithAdjustment.routeSummary,
                                explanation: alarmWithAdjustment.adjustment.reason,
                                isSignificant: alarmWithAdjustment.isSignificant
                            )
                        },
                        onCardTap: { adjustment in
                            // Get the alarm directly from activeAdjustments
                            if let alarmWithAdjustment = weatherAlarmService.activeAdjustments.first(where: { $0.alarm.id == adjustment.alarmId }) {
                                showingAlarmDetail = alarmWithAdjustment.alarm
                            }
                        },
                        onCardDismiss: { adjustment in
                            weatherAlarmService.dismissAdjustment(for: adjustment.alarmId)
                        },
                        onCardLongPress: { adjustment in
                            showingContextMenu = adjustment
                        }
                    )
                    .environmentObject(alarmStore)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasAdjustments)
            }
        }
        .onAppear {
            hasAdjustments = !weatherAlarmService.activeAdjustments.isEmpty
        }
        .onChange(of: weatherAlarmService.activeAdjustments.count) { _, newCount in
            hasAdjustments = newCount > 0
        }
        .fullScreenCover(item: $showingAlarmDetail) { alarm in
            AddAlarmView(
                alarm: alarm,
                onSave: { updatedAlarm in
                    // Handle alarm updates
                    showingAlarmDetail = nil
                },
                onCancel: {
                    showingAlarmDetail = nil
                },
                onDelete: { deletedAlarm in
                    // Handle alarm deletion
                    showingAlarmDetail = nil
                }
            )
        }
        .actionSheet(item: $showingContextMenu) { adjustment in
            // Get the current alarm from the store
            guard let alarm = adjustment.getCurrentAlarm(from: alarmStore) else {
                return ActionSheet(
                    title: Text("Alarm Not Found"),
                    message: Text("This alarm has been deleted"),
                    buttons: [.cancel()]
                )
            }
            
            return ActionSheet(
                title: Text("Weather Alarm Options"),
                message: Text(alarm.name),
                buttons: [
                    .default(Text("View Alarm Details")) {
                        showingAlarmDetail = alarm
                    },
                    .default(Text("Dismiss for Today")) {
                        weatherAlarmService.dismissAdjustmentForToday(adjustment.alarmId)
                    },
                    .default(Text("Turn Off Weather Adjustments")) {
                        Task {await weatherAlarmService.disableWeatherAdjustments(for: alarm)}
                    },
                    .default(Text("View Route")) {
                        weatherAlarmService.showRoute(for: alarm)
                    },
                    .cancel()
                ]
            )
        }
    }
}
