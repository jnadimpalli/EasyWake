// WeatherAlarmCard.swift - Fixed Version

import SwiftUI
import WeatherKit

// MARK: - Weather Alarm Adjustment Data Model
struct WeatherAlarmAdjustment: Identifiable, Equatable {
    let id = UUID()
    let alarmId: UUID
    let originalTime: Date
    let adjustedTime: Date
    let adjustmentMinutes: Int
    let extraTimeMinutes: Int
    let weatherCondition: WeatherCondition
    let routeSummary: String
    let explanation: String
    let isSignificant: Bool
    
    public func getCurrentAlarm(from alarmStore: AlarmStore) -> Alarm? {
        return alarmStore.alarms.first { $0.id == alarmId }
    }
    
    var adjustmentText: String {
        if adjustmentMinutes < 0 {
            let sleepInMinutes = abs(adjustmentMinutes)
            if sleepInMinutes < 60 {
                return "\(sleepInMinutes) min extra"
            } else {
                let hours = sleepInMinutes / 60
                let minutes = sleepInMinutes % 60
                if minutes == 0 {
                    return "\(hours) hr extra"
                } else {
                    return "\(hours) hr \(minutes) min"
                }
            }
        } else {
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
    
    private var alarm: Alarm? {
        adjustment.getCurrentAlarm(from: alarmStore)
    }
    
    var body: some View {
        if let alarm = alarm {
            VStack(spacing: 0) {
                // Header with weather icon and condition
                headerSection(alarm: alarm)
                
                // Time Adjustment Section
                timeAdjustmentSection
                
                // Route Summary
                routeSummarySection
            }
            .background(cardBackground)
            .cornerRadius(12)
            .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.selectionChanged()
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                onLongPress()
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(alarm: alarm))
            .accessibilityHint("Tap to view alarm details, or swipe up to dismiss")
        }
    }
    
    // MARK: - Subviews
    private func headerSection(alarm: Alarm) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Weather Icon with background
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
                Text(alarm.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(adjustment.weatherCondition.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Dismiss Button - aligned with alarm name
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .offset(y: -2) // Fine-tune vertical alignment with text
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var timeAdjustmentSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ORIGINAL TIME")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(alarm!.displayTime)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                        .strikethrough(adjustment.adjustmentMinutes != 0, color: .secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(adjustment.canSleepIn ? "SLEEP UNTIL" : "WAKE UP AT")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(adjustment.canSleepIn ? .green : .orange)
                        .textCase(.uppercase)
                    
                    Text(formatLocalTime(adjustment.adjustedTime))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(adjustment.canSleepIn ? .green : .orange)
                }
            }
            
            // Sleep-in bonus or wake-early warning - FIXED HEIGHT
            Group {
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
                    .cornerRadius(8)
                } else {
                    // Wake early section with same height as sleep-in banner
                    HStack(spacing: 8) {
                        Text("\(adjustment.adjustmentText) • \(adjustment.explanation)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8) // Slightly more padding to match banner height
                    .background(Color.clear) // Invisible background to maintain consistent spacing
                }
            }
            .frame(height: 32) // Fixed height for both states
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

// MARK: - Weather Alarm Carousel Container (With Proper Width)
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
    @State private var dragOffset: CGFloat = 0
    
    private let maxDisplayedAlarms = 5
    private let cardHeight: CGFloat = 160 // Fixed height for all cards
    
    var body: some View {
        VStack(spacing: 0) {
            if adjustments.count == 1 {
                // Single card with reduced width
                WeatherAlarmCard(
                    adjustment: adjustments[0],
                    onTap: { onCardTap(adjustments[0]) },
                    onDismiss: { onCardDismiss(adjustments[0]) },
                    onLongPress: { onCardLongPress(adjustments[0]) }
                )
                .environmentObject(alarmStore)
                .padding(.horizontal, 16)
                .frame(height: cardHeight) // Fixed height
            } else {
                // Multiple cards carousel
                ZStack(alignment: .bottom) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            ForEach(Array(displayedAdjustments.enumerated()), id: \.element.id) { index, adjustment in
                                WeatherAlarmCard(
                                    adjustment: adjustment,
                                    onTap: {
                                        // Only trigger tap if not dragging
                                        if abs(dragOffset) < 10 {
                                            onCardTap(adjustment)
                                        }
                                    },
                                    onDismiss: { onCardDismiss(adjustment) },
                                    onLongPress: { onCardLongPress(adjustment) }
                                )
                                .environmentObject(alarmStore)
                                .frame(width: geometry.size.width - 32) // REDUCED WIDTH with margins
                                .frame(height: cardHeight) // Fixed height
                                .padding(.horizontal, 16)
                            }
                        }
                        .offset(x: -CGFloat(currentIndex) * geometry.size.width + dragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isUserInteracting = true
                                    pauseAutoAdvance = true
                                    dragOffset = value.translation.width
                                }
                                .onEnded { value in
                                    withAnimation(.spring()) {
                                        let threshold = geometry.size.width * 0.3
                                        
                                        if value.translation.width > threshold && currentIndex > 0 {
                                            currentIndex -= 1
                                        } else if value.translation.width < -threshold && currentIndex < displayedAdjustments.count - 1 {
                                            currentIndex += 1
                                        }
                                        
                                        dragOffset = 0
                                    }
                                    
                                    isUserInteracting = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                        pauseAutoAdvance = false
                                    }
                                }
                        )
                    }
                    .frame(height: cardHeight)
                    
                    // Page Indicators - Positioned at bottom of ZStack
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
                    .padding(.bottom, -20) // Position below the card
                }
                .frame(height: cardHeight + 30) // Total height including space for dots
            }
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            if !pauseAutoAdvance && !isUserInteracting && displayedAdjustments.count > 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex = (currentIndex + 1) % displayedAdjustments.count
                }
            }
        }
        .onAppear {
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
                            WeatherAlarmAdjustment(
                                alarmId: alarmWithAdjustment.alarm.id,
                                originalTime: alarmWithAdjustment.alarm.nextOccurrenceTime ?? alarmWithAdjustment.alarm.alarmTime,
                                adjustedTime: alarmWithAdjustment.adjustment.adjustedWakeTime,
                                adjustmentMinutes: alarmWithAdjustment.adjustment.adjustmentMinutes,
                                extraTimeMinutes: 0,
                                weatherCondition: alarmWithAdjustment.weatherCondition,
                                routeSummary: alarmWithAdjustment.routeSummary,
                                explanation: alarmWithAdjustment.adjustment.reason,
                                isSignificant: alarmWithAdjustment.isSignificant
                            )
                        },
                        onCardTap: { adjustment in
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
                .padding(.bottom, 24) // INCREASED bottom padding for better spacing
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
                    showingAlarmDetail = nil
                },
                onCancel: {
                    showingAlarmDetail = nil
                },
                onDelete: { deletedAlarm in
                    showingAlarmDetail = nil
                }
            )
        }
        .actionSheet(item: $showingContextMenu) { adjustment in
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
