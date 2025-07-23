//  AdjustmentBreakdown.swift

import SwiftUI

struct AlarmBreakdownSheet: View {
    let alarm: Alarm
    let adjustment: AlarmAdjustment?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var totalAdjustmentMinutes: Int {
        adjustment?.adjustmentMinutes ?? 0
    }
    
    private var isEarlier: Bool {
        totalAdjustmentMinutes > 0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Summary
                    headerSummarySection
                    
                    // Visual Timeline
                    timelineSection
                    
                    // Breakdown Details
                    if let breakdown = adjustment?.breakdown {
                        breakdownSection(breakdown)
                    }
                    
                    // Confidence Score
                    if let confidence = adjustment?.confidence {
                        confidenceSection(confidence)
                    }
                    
                    // Additional Info
                    additionalInfoSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Wake Time Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Header Summary
    private var headerSummarySection: some View {
        VStack(spacing: 16) {
            // Icon and Title
            VStack(spacing: 12) {
                Image(systemName: isEarlier ? "alarm.fill" : "moon.zzz.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(isEarlier ? .orange : .green)
                    .symbolRenderingMode(.multicolor)
                
                Text(alarm.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }
            
            // Adjustment Summary
            VStack(spacing: 8) {
                Text(adjustmentSummaryText)
                    .font(.headline)
                    .foregroundColor(isEarlier ? .primary : .green)
                
                Text(adjustmentReasonText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Timeline Section
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule Timeline")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                // Original Wake Time
                TimelineRow(
                    time: formatTime(alarm.alarmTime),
                    label: "Original Wake Time",
                    icon: "alarm",
                    iconColor: .gray,
                    isStrikethrough: adjustment != nil
                )
                
                if let adjustedTime = adjustment?.adjustedWakeTime {
                    TimelineConnector()
                    
                    // Adjusted Wake Time
                    TimelineRow(
                        time: formatTime(adjustedTime),
                        label: "Adjusted Wake Time",
                        icon: "alarm.fill",
                        iconColor: isEarlier ? .orange : .green,
                        isHighlighted: true
                    )
                }
                
                if alarm.smartEnabled {
                    TimelineConnector()
                    
                    // Arrival Time
                    TimelineRow(
                        time: formatTime(alarm.arrivalTime),
                        label: "Target Arrival",
                        icon: "location.fill",
                        iconColor: .customBlue
                    )
                }
            }
            .padding(.horizontal, -8) // Compensate for internal padding
        }
    }
    
    // MARK: - Breakdown Section
    private func breakdownSection(_ breakdown: AlarmAdjustment.AdjustmentBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time Breakdown")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Preparation Time
                AdjustmentBreakdownRow(
                    icon: "figure.walk",
                    iconColor: .primary,
                    title: "Preparation Time",
                    minutes: breakdown.preparationTime,
                    description: "Time to get ready"
                )
                
                // Base Commute
                AdjustmentBreakdownRow(
                    icon: "car.fill",
                    iconColor: .primary,
                    title: "Base Commute",
                    minutes: breakdown.baseCommute,
                    description: "Normal travel time"
                )
                
                // Weather Delays
                if breakdown.weatherDelays > 0 {
                    AdjustmentBreakdownRow(
                        icon: "cloud.rain.fill",
                        iconColor: .primary,
                        title: "Weather Delays",
                        minutes: breakdown.weatherDelays,
                        description: "Additional time due to weather",
                        isDelay: true
                    )
                }
                
                // Traffic Delays
                if breakdown.trafficDelays > 0 {
                    AdjustmentBreakdownRow(
                        icon: "car.2.fill",
                        iconColor: .primary,
                        title: "Traffic Delays",
                        minutes: breakdown.trafficDelays,
                        description: "Current traffic conditions",
                        isDelay: true
                    )
                }
                
                // Snooze Buffer
                if breakdown.snoozeBuffer > 0 {
                    AdjustmentBreakdownRow(
                        icon: "zzz",
                        iconColor: .primary,
                        title: "Snooze Buffer",
                        minutes: breakdown.snoozeBuffer,
                        description: "Based on your snooze habits",
                        isBuffer: true
                    )
                }
                
                // Total Time
                Divider()
                    .padding(.vertical, 4)
                
                TotalRow(
                    totalMinutes: breakdown.preparationTime +
                                breakdown.baseCommute +
                                breakdown.weatherDelays +
                                breakdown.trafficDelays +
                                breakdown.snoozeBuffer
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
    
    // MARK: - Confidence Section
    private func confidenceSection(_ confidence: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prediction Confidence")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Confidence Score
                HStack {
                    Image(systemName: confidenceIcon)
                        .font(.title2)
                        .foregroundColor(confidenceColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(confidence * 100))% Confident")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(confidenceDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Confidence Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(confidenceColor)
                            .frame(width: geometry.size.width * confidence, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
    
    // MARK: - Additional Info Section
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Route Info
            if alarm.smartEnabled {
                InfoRow(
                    icon: "map",
                    title: "Route",
                    value: "\(alarm.startingAddress.city) → \(alarm.destinationAddress.city)"
                )
            }
            
            // Travel Method
            InfoRow(
                icon: travelMethodIcon,
                title: "Travel Method",
                value: alarm.travelMethod.displayName
            )
            
            // Last Updated
            if let calculatedAt = adjustment?.calculatedAt {
                InfoRow(
                    icon: "clock.arrow.circlepath",
                    title: "Last Updated",
                    value: RelativeDateTimeFormatter().localizedString(for: calculatedAt, relativeTo: Date())
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Helper Views
    private var adjustmentSummaryText: String {
        if let adjustment = adjustment {
            let minutes = abs(adjustment.adjustmentMinutes)
            if adjustment.adjustmentMinutes > 0 {
                return "Wake up \(minutes) minutes earlier"
            } else {
                return "Sleep in \(minutes) extra minutes!"
            }
        }
        return "No adjustment needed"
    }
    
    private var adjustmentReasonText: String {
        adjustment?.reason ?? "Your alarm is set for the optimal time"
    }
    
    private var confidenceIcon: String {
        guard let confidence = adjustment?.confidence else { return "checkmark.circle" }
        switch confidence {
        case 0.8...1.0: return "checkmark.seal.fill"
        case 0.6..<0.8: return "checkmark.circle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }
    
    private var confidenceColor: Color {
        guard let confidence = adjustment?.confidence else { return .green }
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    private var confidenceDescription: String {
        guard let confidence = adjustment?.confidence else { return "" }
        switch confidence {
        case 0.9...1.0: return "Very reliable prediction"
        case 0.8..<0.9: return "Reliable prediction"
        case 0.7..<0.8: return "Moderate confidence"
        case 0.6..<0.7: return "Lower confidence"
        default: return "Limited data available"
        }
    }
    
    private var travelMethodIcon: String {
        switch alarm.travelMethod {
        case .drive: return "car.fill"
        case .publicTransit: return "tram.fill"
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct TimelineRow: View {
    let time: String
    let label: String
    let icon: String
    let iconColor: Color
    var isStrikethrough: Bool = false
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Time - with flexible width and no wrapping
            Text(time)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(isStrikethrough ? .secondary : .primary)
                .strikethrough(isStrikethrough)
                .frame(minWidth: 90, alignment: .trailing)
                .fixedSize(horizontal: true, vertical: false)
            
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            // Label
            Text(label)
                .font(.subheadline)
                .foregroundColor(isHighlighted ? .primary : .secondary)
                .fontWeight(isHighlighted ? .medium : .regular)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct TimelineConnector: View {
    var body: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(minWidth: 90)
            
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 3, height: 3)
                        .padding(.vertical, 2)
                }
            }
            .frame(width: 36)
            
            Color.clear
        }
        .frame(height: 16)
    }
}

struct AdjustmentBreakdownRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let minutes: Int
    let description: String
    var isDelay: Bool = false
    var isBuffer: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 28)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Time
            HStack(spacing: 4) {
                if isDelay {
                    Text("+")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Text("\(minutes) min")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(isDelay ? .orange : .primary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TotalRow: View {
    let totalMinutes: Int
    
    var body: some View {
        HStack {
            Text("Total Time Required")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text("\(totalMinutes) minutes")
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Breakdown Sheet Item
struct BreakdownSheetItem: Identifiable {
    let id = UUID()
    let alarm: Alarm
    let adjustment: AlarmAdjustment?
}
