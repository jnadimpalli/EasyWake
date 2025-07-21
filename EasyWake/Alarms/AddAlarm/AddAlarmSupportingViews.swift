// AddAlarmSupportingViews.swift

import SwiftUI

// MARK: - Weekday Pill View
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
            .frame(minWidth: 44, minHeight: 44)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .cornerRadius(8)
            .onTapGesture(perform: action)
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            .accessibilityLabel("\(weekdayDisplayName), \(isSelected ? "selected" : "not selected")")
            .accessibilityHint("Tap to \(isSelected ? "remove" : "add") \(weekdayDisplayName) to repeat schedule")
    }
}

// MARK: - Info Button
struct InfoButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Information")
        .accessibilityHint("Learn more about this feature")
    }
}

// MARK: - Info Types
enum InfoType: Identifiable {
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
