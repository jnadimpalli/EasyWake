// ContextAwareWeatherAlarmContainer.swift

import SwiftUI
import CoreLocation

// MARK: - Context-Aware Weather Alarm Container
struct ContextAwareWeatherAlarmContainer: View {
    @ObservedObject var weatherAlarmService: WeatherAlarmService
    @ObservedObject var routeAnalysisService: RouteAnalysisService
    @ObservedObject var weatherViewModel: WeatherViewModel
    
    @State private var showRelevanceDetails = false
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 12) {
            // Location relevance indicator
            // locationRelevanceSection
            
            // Weather alarm cards (only if location is relevant)
            if shouldShowWeatherAlarms {
                weatherAlarmsSection
            }
        }
        .onChange(of: weatherViewModel.currentCoordinate?.latitude) { oldLat, newLat in
            guard let coord = weatherViewModel.currentCoordinate else { return }
            handleLocationChange(coord)
        }
        .onAppear {
            if let coordinate = weatherViewModel.currentCoordinate {
                handleLocationChange(coordinate)
            }
        }
    }
    
    // MARK: - Location Relevance Section
//    @ViewBuilder
//    private var locationRelevanceSection: some View {
//        // Keep the functionality but hide the UI
//        EmptyView()
//            .onReceive(routeAnalysisService.$analysisState) { state in
//                // Handle state changes silently for debugging or internal logic
//                switch state {
//                case .analyzing:
//                    print("Analyzing location relevance...")
//                case .completed(let relevances):
//                    if !relevances.isEmpty {
//                        print("Found \(relevances.count) relevant alarm(s)")
//                        // Provide haptic feedback when relevant alarms are found
//                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
//                        impactFeedback.impactOccurred()
//                    } else {
//                        print("No relevant alarms found for current location")
//                    }
//                case .error(let message):
//                    print("Analysis error: \(message)")
//                default:
//                    break
//                }
//            }
//    }
    
    // MARK: - Weather Alarms Section
    @ViewBuilder
    private var weatherAlarmsSection: some View {
        WeatherAlarmContainer(weatherAlarmService: weatherAlarmService)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: shouldShowWeatherAlarms)
    }
    
    // MARK: - Computed Properties
    private var shouldShowWeatherAlarms: Bool {
        switch routeAnalysisService.analysisState {
        case .completed(let relevances):
            return !relevances.isEmpty &&
            !weatherAlarmService.activeAdjustments.isEmpty
        default:
            return false
        }
    }
    
    // MARK: - Helper Methods
    private func handleLocationChange(_ coordinate: CLLocationCoordinate2D?) {
        guard let coordinate = coordinate else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            routeAnalysisService.analyzeLocationRelevance(
                for: coordinate,
                locationName: weatherViewModel.currentLocation
            )
        }
    }
    
    private func retryAnalysis() {
        guard let coordinate = weatherViewModel.currentCoordinate else { return }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        routeAnalysisService.analyzeLocationRelevance(
            for: coordinate,
            locationName: weatherViewModel.currentLocation
        )
    }
}

// MARK: - Analyzing Location View
struct AnalyzingLocationView: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.magnifyingglass")
                .font(.title2)
                .foregroundColor(.customBlue)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing location relevance...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Checking route connections")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.customBlue.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analyzing location relevance for your alarms")
    }
}

// MARK: - Location Relevance View
struct LocationRelevanceView: View {
    let relevances: [RouteRelevance]
    let locationName: String?
    @Binding var showDetails: Bool
    
    @State private var currentRelevanceIndex = 0
    @State private var animationTimer: Timer?
    
    var body: some View {
        VStack(spacing: 8) {
            // Main relevance card
            if !relevances.isEmpty {
                RelevanceCard(
                    relevance: relevances[currentRelevanceIndex],
                    locationName: locationName,
                    totalCount: relevances.count,
                    currentIndex: currentRelevanceIndex,
                    onTap: { showDetails.toggle() }
                )
            }
            
            // Multiple alarms indicator
            if relevances.count > 1 {
                MultipleAlarmsIndicator(
                    count: relevances.count,
                    currentIndex: currentRelevanceIndex,
                    onTap: { showDetails.toggle() }
                )
            }
        }
        .onAppear {
            startRotationTimer()
        }
        .onDisappear {
            stopRotationTimer()
        }
        .sheet(isPresented: $showDetails) {
            RelevanceDetailsSheet(relevances: relevances, locationName: locationName)
        }
    }
    
    private func startRotationTimer() {
        guard relevances.count > 1 else { return }
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentRelevanceIndex = (currentRelevanceIndex + 1) % relevances.count
            }
        }
    }
    
    private func stopRotationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// MARK: - Relevance Card
struct RelevanceCard: View {
    let relevance: RouteRelevance
    let locationName: String?
    let totalCount: Int
    let currentIndex: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Alarm \(relevance.alarm.name) is relevant to this location. \(relevance.explanation)")
        .accessibilityHint("Tap for more details")
    }

    // MARK: - Broken out content
    private var cardContent: some View {
        HStack(spacing: 12) {
            iconView
            contentView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(iconColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.2))
                .frame(width: 40, height: 40)

            Image(systemName: relevance.relevanceType.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(iconColor)
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerView
            explanationView
            footerView
        }
    }

    private var headerView: some View {
        HStack {
            Text(relevance.alarm.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            if totalCount > 1 {
                Text("\(currentIndex + 1)/\(totalCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }

    private var explanationView: some View {
        Text(relevance.explanation)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .lineLimit(2)
    }

    private var footerView: some View {
        HStack(spacing: 8) {
            Label(distanceText, systemImage: "location.fill")
                .font(.caption)
                .foregroundColor(.secondary)

            if locationName != nil {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Helpers
    private var iconColor: Color {
        switch relevance.relevanceType {
        case .nearStart:        return .customBlue
        case .nearDestination:  return .green
        case .alongRoute:       return .orange
        case .weatherImpact:    return .purple
        }
    }

    private var distanceText: String {
        let d = relevance.distance
        if d < 1_000 {
            return "\(Int(d))m away"
        } else {
            return String(format: "%.1fkm away", d / 1_000)
        }
    }
}

// MARK: - Multiple Alarms Indicator
struct MultipleAlarmsIndicator: View {
    let count: Int
    let currentIndex: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                ForEach(0..<min(count, 5), id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
                
                if count > 5 {
                    Text("+\(count - 5)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text("View all")
                    .font(.caption)
                    .foregroundColor(.customBlue)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .accessibilityLabel("View all \(count) relevant alarms")
    }
}

// MARK: - Location Analysis Error View
struct LocationAnalysisErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Analysis Error")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Couldn't analyze route relevance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button("Retry", action: onRetry)
                .font(.caption)
                .foregroundColor(.customBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.customBlue.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Route analysis error. \(message)")
        .accessibilityHint("Tap retry to analyze again")
    }
}

// MARK: - Relevance Details Sheet
struct RelevanceDetailsSheet: View {
    let relevances: [RouteRelevance]
    let locationName: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        if let locationName = locationName {
                            Text("Weather Impact for \(locationName)")
                                .font(.title2)
                                .fontWeight(.bold)
                        } else {
                            Text("Route Relevance Analysis")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Text("\(relevances.count) alarm\(relevances.count == 1 ? "" : "s") affected by weather at this location")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Relevance list
                    ForEach(relevances, id: \.alarm.id) { relevance in
                        DetailedRelevanceRow(relevance: relevance)
                    }
                }
                .padding(.bottom, 100)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Detailed Relevance Row
struct DetailedRelevanceRow: View {
    let relevance: RouteRelevance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: relevance.relevanceType.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(relevance.alarm.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(relevanceTypeDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(
                    icon: "location.fill",
                    title: "Distance",
                    value: distanceText,
                    color: .customBlue
                )
                
                DetailRow(
                    icon: "clock.fill",
                    title: "Alarm Time",
                    value: relevance.alarm.alarmTime.formatted(date: .omitted, time: .shortened),
                    color: .green
                )
                
                if relevance.alarm.smartEnabled {
                    DetailRow(
                        icon: "brain.head.profile",
                        title: "Smart Features",
                        value: "Weather & traffic adjustments enabled",
                        color: .purple
                    )
                }
                
                DetailRow(
                    icon: "map.fill",
                    title: "Route",
                    value: routeDescription,
                    color: .orange
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(iconColor.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    private var iconColor: Color {
        switch relevance.relevanceType {
        case .nearStart: return .customBlue
        case .nearDestination: return .green
        case .alongRoute: return .orange
        case .weatherImpact: return .purple
        }
    }
    
    private var relevanceTypeDescription: String {
        switch relevance.relevanceType {
        case .nearStart:
            return "Near your starting location"
        case .nearDestination:
            return "Near your destination"
        case .alongRoute:
            return "Along your travel route"
        case .weatherImpact:
            return "Weather will impact this commute"
        }
    }
    
    private var distanceText: String {
        let distance = relevance.distance
        if distance < 1000 {
            return "\(Int(distance)) meters"
        } else {
            return String(format: "%.1f kilometers", distance / 1000)
        }
    }
    
    private var routeDescription: String {
        let alarm = relevance.alarm
        let start = "\(alarm.startingAddress.city), \(alarm.startingAddress.state)"
        let destination = "\(alarm.destinationAddress.city), \(alarm.destinationAddress.state)"
        return "\(start) → \(destination)"
    }
}

// MARK: - Detail Row Component
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}
