// UpcomingAlarms.swift

import SwiftUI

// MARK: - Upcoming Alarm Data Model
struct UpcomingAlarmInfo: Identifiable, Equatable  {
    let id = UUID()
    let alarm: Alarm
    let scheduledTime: Date
    let adjustedTime: Date?
    let adjustment: AlarmAdjustment?
    
    var isAdjusted: Bool {
        adjustment != nil && abs(adjustment?.adjustmentMinutes ?? 0) >= 2
    }
    
    var timeUntilAlarm: TimeInterval {
        (adjustedTime ?? scheduledTime).timeIntervalSince(Date())
    }
    
    var formattedTimeUntil: String {
        let interval = timeUntilAlarm
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    static func ==(lhs: UpcomingAlarmInfo, rhs: UpcomingAlarmInfo) -> Bool {
        // compare the alarm identity
        return lhs.alarm.id            == rhs.alarm.id
            && lhs.scheduledTime       == rhs.scheduledTime
            && lhs.adjustedTime        == rhs.adjustedTime
            && lhs.adjustment          == rhs.adjustment
    }
}

// MARK: - Single Upcoming Alarm Card
struct UpcomingAlarmCard: View {
    let alarmInfo: UpcomingAlarmInfo
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Time Display
            timeSection
            
            // Bottom Info
            bottomSection
        }
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: shadowColor, radius: 3, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
            onTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // MARK: - Subviews
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Alarm icon
            ZStack {
                Image(systemName: "alarm.waves.left.and.right.fill")
                    .font(.title3)
                    .foregroundColor(.customBlue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alarmInfo.alarm.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("In \(alarmInfo.formattedTimeUntil)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Smart alarm indicator
            if alarmInfo.alarm.smartEnabled {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16))
                    .foregroundColor(.customBlue)
            }
            
            Button(action: {
                onDismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary.opacity(0.6))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var timeSection: some View {
        HStack {
            if alarmInfo.isAdjusted {
                // Show both original and adjusted times
                VStack(alignment: .leading, spacing: 4) {
                    Text("ORIGINAL")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(formatTime(alarmInfo.scheduledTime))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary)
                        .strikethrough(true, color: .secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ADJUSTED")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(alarmInfo.adjustment!.adjustmentMinutes > 0 ? .primary : .green)
                        .textCase(.uppercase)
                    
                    Text(formatTime(alarmInfo.adjustedTime!))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(alarmInfo.adjustment!.adjustmentMinutes > 0 ? .primary : .green)
                }
            } else {
                // Just show the scheduled time
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("WAKE TIME")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(formatTime(alarmInfo.scheduledTime))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var adjustmentSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            
            Text(alarmInfo.adjustment?.reason ?? "Adjusted for optimal arrival")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.orange)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var bottomSection: some View {
        HStack(spacing: 8) {
            // Show schedule type
            HStack(spacing: 4) {
                Image(systemName: scheduleIcon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(scheduleText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Arrival time if smart alarm
            if alarmInfo.alarm.smartEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Arrive by \(formatTime(alarmInfo.alarm.arrivalTime))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 4)
    }
    
    // MARK: - Computed Properties
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.gray.opacity(0.2),
                        lineWidth: 1.5
                    )
            )
    }
    
    private var shadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15)
    }
    
    private var scheduleIcon: String {
        switch alarmInfo.alarm.schedule {
        case .oneTime:
            return "1.circle"
        case .specificDate:
            return "calendar"
        case .repeatingDays:
            return "repeat"
        }
    }
    
    private var scheduleText: String {
        switch alarmInfo.alarm.schedule {
        case .oneTime:
            return "One time"
        case .specificDate(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        case .repeatingDays(let days):
            if days.count == 7 {
                return "Every day"
            } else if days.count == 5 && days.contains(.monday) && days.contains(.friday) && !days.contains(.saturday) && !days.contains(.sunday) {
                return "Weekdays"
            } else if days.count == 2 && days.contains(.saturday) && days.contains(.sunday) {
                return "Weekends"
            } else {
                return "\(days.count) days/week"
            }
        }
    }
    
    private var accessibilityLabel: String {
        var label = "Alarm: \(alarmInfo.alarm.name), scheduled for \(formatTime(alarmInfo.scheduledTime))"
        if alarmInfo.isAdjusted {
            label += ", adjusted to \(formatTime(alarmInfo.adjustedTime!))"
        }
        label += ", in \(alarmInfo.formattedTimeUntil)"
        return label
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Upcoming Alarms Carousel
struct UpcomingAlarmsCarousel: View {
    let upcomingAlarms: [UpcomingAlarmInfo]
    let onCardTap: (UpcomingAlarmInfo) -> Void
    let onCardDismiss: (UpcomingAlarmInfo) -> Void
    
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isUserInteracting = false
    
    private let cardHeight: CGFloat = 160
    private let dotsHeight: CGFloat = 24 // Always reserve space for dots
    
    var body: some View {
        VStack(spacing: 0) {
            if upcomingAlarms.count == 1 {
                // Single card
                UpcomingAlarmCard(
                    alarmInfo: upcomingAlarms[0],
                    onTap: { onCardTap(upcomingAlarms[0]) },
                    onDismiss: { onCardDismiss(upcomingAlarms[0]) }
                )
                .padding(.horizontal, 16)
                .frame(height: cardHeight)
            } else {
                // Multiple cards carousel
                ZStack(alignment: .bottom) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            ForEach(Array(upcomingAlarms.enumerated()), id: \.element.id) { index, alarmInfo in
                                UpcomingAlarmCard(
                                    alarmInfo: alarmInfo,
                                    onTap: { onCardTap(alarmInfo) },
                                    onDismiss: { onCardDismiss(alarmInfo) }
                                )
                                .frame(width: geometry.size.width - 32)
                                .frame(height: cardHeight)
                                .padding(.horizontal, 16)
                            }
                        }
                        .offset(x: -CGFloat(currentIndex) * geometry.size.width + dragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isUserInteracting = true
                                    dragOffset = value.translation.width
                                }
                                .onEnded { value in
                                    withAnimation(.spring()) {
                                        let threshold = geometry.size.width * 0.3
                                        
                                        if value.translation.width > threshold && currentIndex > 0 {
                                            currentIndex -= 1
                                        } else if value.translation.width < -threshold && currentIndex < upcomingAlarms.count - 1 {
                                            currentIndex += 1
                                        }
                                        
                                        dragOffset = 0
                                    }
                                    
                                    isUserInteracting = false
                                }
                        )
                    }
                    .frame(height: cardHeight)
                }
                .frame(height: cardHeight)
                
                // Page indicators - moved below cards
                HStack(spacing: 8) {
                    ForEach(0..<upcomingAlarms.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .scaleEffect(index == currentIndex ? 1.0 : 0.8)
                            .animation(.easeInOut(duration: 0.25), value: currentIndex)
                    }
                }
                .padding(.top, 8)  // Add space between cards and dots
            }
        }
        .onReceive(Timer.publish(every: 6, on: .main, in: .common).autoconnect()) { _ in
            if !isUserInteracting && upcomingAlarms.count > 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex = (currentIndex + 1) % upcomingAlarms.count
                }
            }
        }
        .onAppear {
            currentIndex = 0
        }
        .onChange(of: upcomingAlarms) { _, _ in
            // Adjust current index if needed when alarms are dismissed
            if currentIndex >= upcomingAlarms.count && !upcomingAlarms.isEmpty {
                currentIndex = upcomingAlarms.count - 1
            } else if upcomingAlarms.isEmpty {
                currentIndex = 0
            }
        }
    }
}

// MARK: - Upcoming Alarms Container
struct UpcomingAlarmsContainer: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @State private var showingAlarmDetail: Alarm?
    @State private var showingBreakdownSheet: BreakdownSheetItem?
    @State private var selectedTimeFrame: TimeFrame = .twentyFourHours
    @AppStorage("upcomingAlarmsTimeFrame") private var savedTimeFrame: String = "24h"
    
    // Track dismissed alarms for current session
    @State private var sessionDismissedAlarmIds: Set<UUID> = []
    
    enum TimeFrame: String, CaseIterable {
        case threeHours = "3h"
        case sixHours = "6h"
        case twelveHours = "12h"
        case twentyFourHours = "24h"
        
        var hours: Double {
            switch self {
            case .threeHours: return 3
            case .sixHours: return 6
            case .twelveHours: return 12
            case .twentyFourHours: return 24
            }
        }
        
        var displayText: String {
            switch self {
            case .threeHours: return "3 hours"
            case .sixHours: return "6 hours"
            case .twelveHours: return "12 hours"
            case .twentyFourHours: return "24 hours"
            }
        }
    }
    
    // MARK: - Computed Properties
    private var upcomingAlarms: [UpcomingAlarmInfo] {
        let now = Date()
        let timeFrameEnd = now.addingTimeInterval(selectedTimeFrame.hours * 60 * 60)
        
        return alarmStore.alarms.compactMap { alarm in
            // Skip if dismissed in current session
            guard !sessionDismissedAlarmIds.contains(alarm.id) else { return nil }
            
            guard alarm.isEnabled,
                  let nextOccurrence = alarm.nextOccurrenceTime,
                  nextOccurrence > now && nextOccurrence <= timeFrameEnd else {
                return nil
            }
            
            let adjustedTime = alarm.currentAdjustment?.adjustedWakeTime
            
            return UpcomingAlarmInfo(
                alarm: alarm,
                scheduledTime: nextOccurrence,
                adjustedTime: adjustedTime,
                adjustment: alarm.currentAdjustment
            )
        }
        .sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    private var shouldShowSection: Bool {
        !upcomingAlarms.isEmpty || selectedTimeFrame != .twentyFourHours
    }
    
    var body: some View {
        Group {
            if shouldShowSection {
                mainContent
            }
        }
        .sheet(item: $showingBreakdownSheet) { item in
            AlarmBreakdownSheet(alarm: item.alarm, adjustment: item.adjustment)
        }
        .fullScreenCover(item: $showingAlarmDetail) { alarm in
            addAlarmView(for: alarm)
        }
    }
    
    // MARK: - Subviews
    private var mainContent: some View {
        VStack(spacing: 16) {
            sectionHeader
            alarmContent
        }
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            loadSavedTimeFrame()
        }
    }
    
    private var sectionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Upcoming Alarms")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                timeFrameMenu
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var timeFrameMenu: some View {
        Menu {
            ForEach(TimeFrame.allCases.reversed(), id: \.self) { timeFrame in
                Button {
                    handleTimeFrameChange(timeFrame)
                } label: {
                    timeFrameMenuLabel(for: timeFrame)
                }
            }
        } label: {
            currentTimeFrameLabel
        }
    }
    
    @ViewBuilder
    private func timeFrameMenuLabel(for timeFrame: TimeFrame) -> some View {
        if selectedTimeFrame == timeFrame {
            Label("Next \(timeFrame.displayText)", systemImage: "checkmark")
        } else {
            Text("Next \(timeFrame.displayText)")
        }
    }
    
    private var currentTimeFrameLabel: some View {
        HStack(spacing: 4) {
            Text("Next \(selectedTimeFrame.displayText)")
                .font(.caption)
                .foregroundColor(.secondary)
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var alarmContent: some View {
        if upcomingAlarms.isEmpty {
            EmptyUpcomingAlarmsView(timeFrame: selectedTimeFrame)
                .padding(.horizontal, 16)
        } else {
            UpcomingAlarmsCarousel(
                upcomingAlarms: upcomingAlarms,
                onCardTap: handleCardTap,
                onCardDismiss: handleCardDismiss
            )
        }
    }
    
    // MARK: - Helper Methods
    private func addAlarmView(for alarm: Alarm) -> some View {
        AddAlarmView(
            alarm: alarm,
            onSave: { _ in
                showingAlarmDetail = nil
            },
            onCancel: {
                showingAlarmDetail = nil
            },
            onDelete: { _ in
                showingAlarmDetail = nil
            }
        )
    }
    
    // MARK: - Action Handlers
    private func handleTimeFrameChange(_ timeFrame: TimeFrame) {
        selectedTimeFrame = timeFrame
        savedTimeFrame = timeFrame.rawValue
        // Reset dismissed alarms when changing time frame
        sessionDismissedAlarmIds.removeAll()
    }
    
    private func handleCardTap(_ alarmInfo: UpcomingAlarmInfo) {
        if alarmInfo.isAdjusted {
            showingBreakdownSheet = BreakdownSheetItem(
                alarm: alarmInfo.alarm,
                adjustment: alarmInfo.adjustment
            )
        } else {
            showingAlarmDetail = alarmInfo.alarm
        }
    }
    
    private func handleCardDismiss(_ alarmInfo: UpcomingAlarmInfo) {
        dismissUpcomingAlarm(alarmInfo.alarm.id)
    }
    
    private func dismissUpcomingAlarm(_ alarmId: UUID) {
        withAnimation(.easeOut(duration: 0.3)) {
            sessionDismissedAlarmIds.insert(alarmId)
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func loadSavedTimeFrame() {
        if let saved = TimeFrame(rawValue: savedTimeFrame) {
            selectedTimeFrame = saved
        }
    }
}

// Empty state when no alarms in selected time frame
struct EmptyUpcomingAlarmsView: View {
    let timeFrame: UpcomingAlarmsContainer.TimeFrame
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("No alarms in the next \(timeFrame.displayText)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Try selecting a longer time frame")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}
