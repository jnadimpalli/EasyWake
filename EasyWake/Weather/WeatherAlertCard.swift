// WeatherAlertCard.swift

import SwiftUI

struct WeatherAlertCard: View {
    let alert: WeatherAlertData
    let onDismiss: () -> Void
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Alert Icon
                Image(systemName: alert.severity.icon)
                    .font(.title3)
                    .foregroundColor(alert.severity.borderColor)
                    .frame(width: 20, height: 20)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title and Severity in one line
                    HStack {
                        Text(alert.severity.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(alert.severity.borderColor)
                            .textCase(.uppercase)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(alert.timeRemaining)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Alert Title
                    Text(alert.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Simplified Description
                    Text(simplifiedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(cardBackground)
        .overlay(borderOverlay)
        .cornerRadius(12)
        .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if alert.severity != .emergency {
                Button("Dismiss", role: .destructive) {
                    onDismiss()
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap for more details")
    }
    
    // MARK: - Computed Properties
    private var simplifiedDescription: String {
        // Simplify the description to key information only
        let description = alert.description
        let maxLength = 80
        
        if description.count <= maxLength {
            return description
        }
        
        // Find the first sentence or up to maxLength characters
        if let sentenceEnd = description.firstIndex(of: ".") {
            let firstSentence = String(description[..<sentenceEnd])
            if firstSentence.count <= maxLength {
                return firstSentence + "."
            }
        }
        
        return String(description.prefix(maxLength)) + "..."
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.regularMaterial)
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(alert.severity.borderColor, lineWidth: 1.5)
            .opacity(0.6)
    }
    
    private var backgroundMaterial: Color {
        // Match the opacity of WeatherAlarmCard (.regularMaterial)
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.secondarySystemGroupedBackground
            default:
                return UIColor.secondarySystemGroupedBackground
            }
        })
    }
    
    private var shadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15)
    }
    
    private var accessibilityLabel: String {
        "\(alert.severity.displayName) alert: \(alert.title). \(alert.timeRemaining)."
    }
}

struct WeatherAlertsContainer: View {
    @ObservedObject var alertManager: WeatherAlertManager
    @State private var currentIndex = 0
    
    var body: some View {
        if !alertManager.visibleAlerts.isEmpty {
            VStack(spacing: 8) {
                if alertManager.visibleAlerts.count == 1 {
                    // Single alert - more compact
                    WeatherAlertCard(
                        alert: alertManager.visibleAlerts[0],
                        onDismiss: {
                            alertManager.dismissAlert(alertManager.visibleAlerts[0])
                        },
                        onTap: {
                            // Handle tap - could show detail view
                        }
                    )
                    .frame(height: 80) // Fixed compact height
                } else {
                    // Multiple alerts carousel - also more compact
                    VStack(spacing: 6) {
                        TabView(selection: $currentIndex) {
                            ForEach(Array(alertManager.visibleAlerts.enumerated()), id: \.element.id) { index, alert in
                                WeatherAlertCard(
                                    alert: alert,
                                    onDismiss: {
                                        alertManager.dismissAlert(alert)
                                        // Adjust current index if needed
                                        if currentIndex >= alertManager.visibleAlerts.count - 1 {
                                            currentIndex = max(0, alertManager.visibleAlerts.count - 2)
                                        }
                                    },
                                    onTap: {
                                        // Handle tap
                                    }
                                )
                                .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 80) // Fixed compact height
                        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                            if alertManager.visibleAlerts.count > 1 {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    currentIndex = (currentIndex + 1) % alertManager.visibleAlerts.count
                                }
                            }
                        }
                        
                        // Compact page indicators
                        HStack(spacing: 6) {
                            ForEach(0..<alertManager.visibleAlerts.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(index == currentIndex ? 1.0 : 0.8)
                                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
                            }
                            
                            if alertManager.additionalAlertsCount > 0 {
                                Text("+\(alertManager.additionalAlertsCount)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.leading, 4)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Alert Detail View (for tap action)
struct WeatherAlertDetailView: View {
    let alert: WeatherAlertData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: alert.severity.icon)
                                .font(.title)
                                .foregroundColor(alert.severity.borderColor)
                            
                            VStack(alignment: .leading) {
                                Text(alert.severity.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(alert.severity.borderColor)
                                    .textCase(.uppercase)
                                
                                Text(alert.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                        }
                        
                        Text(alert.timeRemaining)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Full Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        Text(alert.description)
                            .font(.body)
                    }
                    
                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.headline)
                        
                        DetailRow(icon: "clock.fill", title: "Effective Time", value: alert.effectiveTimeRange, color: .blue)
                        DetailRow(icon: "person.fill", title: "Issued By", value: alert.issuingAuthority, color: .secondary)
                        
                        if !alert.affectedAreas.isEmpty {
                            DetailRow(icon: "location.fill", title: "Affected Areas", value: alert.affectedAreas.joined(separator: ", "), color: .secondary)
                        }
                    }
                    
                    if let url = alert.url, let urlObj = URL(string: url) {
                        Link("View Official Alert", destination: urlObj)
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding()
            }
            .navigationTitle("Weather Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Custom Button Style
struct AlertCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("Single Alert") {
    let manager = WeatherAlertManager()
    return WeatherAlertsContainer(alertManager: manager)
        .background(Color.blue.gradient)
}

#Preview("Dark Mode") {
    let manager = WeatherAlertManager()
    return WeatherAlertsContainer(alertManager: manager)
        .background(Color.blue.gradient)
        .preferredColorScheme(.dark)
}
