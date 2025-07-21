// PremiumIntegration.swift - Fixed Version

import SwiftUI
import Combine

// MARK: - Premium Manager
@MainActor
class PremiumManager: ObservableObject {
    @Published var currentPlan: SubscriptionPlan = .free
    @Published var trialDaysRemaining: Int = 0
    @Published var showUpgradePrompt = false
    @Published var upgradePromptReason: UpgradeReason?
    
    @AppStorage("subscriptionPlan") private var storedPlan = "free"
    @AppStorage("trialStartDate") private var trialStartDate = Date()
    @AppStorage("hasSeenWeatherAlarmPrompt") public var hasSeenWeatherAlarmPrompt = false
    
    enum UpgradeReason {
        case weatherAlarms
        case premiumFeatures
        case trialExpired
        
        var title: String {
            switch self {
            case .weatherAlarms:
                return "Unlock Weather-Smart Alarms"
            case .premiumFeatures:
                return "Upgrade to Premium"
            case .trialExpired:
                return "Continue with Premium"
            }
        }
        
        var message: String {
            switch self {
            case .weatherAlarms:
                return "Get automatic wake-up time adjustments based on weather conditions along your route. Never be late due to unexpected weather again!"
            case .premiumFeatures:
                return "Unlock advanced features including smart alarms, weather integration, and unlimited alarm storage."
            case .trialExpired:
                return "Your trial has ended. Upgrade to continue enjoying premium features."
            }
        }
    }
    
    init() {
        loadSubscriptionState()
    }
    
    private func loadSubscriptionState() {
        currentPlan = SubscriptionPlan(rawValue: storedPlan) ?? .free
        calculateTrialDaysRemaining()
    }
    
    private func calculateTrialDaysRemaining() {
        if currentPlan == .trial {
            let daysSinceStart = Calendar.current.dateComponents([.day], from: trialStartDate, to: Date()).day ?? 0
            trialDaysRemaining = max(0, 7 - daysSinceStart)
            
            if trialDaysRemaining == 0 {
                // Trial expired
                currentPlan = .free
                storedPlan = "free"
            }
        }
    }
    
    var isPremiumUser: Bool {
        switch currentPlan {
        case .plus, .pro:
            return true
        case .trial:
            return trialDaysRemaining > 0
        case .free:
            return false
        }
    }
    
    var hasWeatherAlarmAccess: Bool {
        return isPremiumUser
    }
    
    func requestWeatherAlarmAccess() {
        guard !isPremiumUser else { return }
        
        if !hasSeenWeatherAlarmPrompt && currentPlan == .free {
            // Offer trial for new users
            showTrialOffer()
        } else {
            // Show upgrade prompt
            upgradePromptReason = .weatherAlarms
            showUpgradePrompt = true
        }
    }
    
    private func showTrialOffer() {
        upgradePromptReason = .weatherAlarms
        showUpgradePrompt = true
    }
    
    func startTrial() {
        currentPlan = .trial
        trialStartDate = Date()
        trialDaysRemaining = 7
        storedPlan = "trial"
        hasSeenWeatherAlarmPrompt = true
        showUpgradePrompt = false
    }
    
    func upgradeToPremium(plan: SubscriptionPlan) {
        currentPlan = plan
        storedPlan = plan.rawValue
        showUpgradePrompt = false
        
        // In production, this would integrate with StoreKit
    }
}

// MARK: - Premium Upgrade Prompt View
struct PremiumUpgradePrompt: View {
    @ObservedObject var premiumManager: PremiumManager
    @Environment(\.dismiss) private var dismiss
    
    let reason: PremiumManager.UpgradeReason
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: weatherAlarmIcon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .padding(.top, 40)
                
                // Title and Description
                VStack(spacing: 16) {
                    Text(reason.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(reason.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Feature List
                if reason == .weatherAlarms {
                    weatherAlarmFeatures
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    if premiumManager.currentPlan == .free && !premiumManager.hasSeenWeatherAlarmPrompt {
                        // Trial button for new users
                        Button("Start 7-Day Free Trial") {
                            premiumManager.startTrial()
                        }
                        .buttonStyle(PremiumButtonStyle(isPrimary: true))
                        
                        Button("Upgrade to Premium") {
                            premiumManager.upgradeToPremium(plan: .plus)
                        }
                        .buttonStyle(PremiumButtonStyle(isPrimary: false))
                    } else {
                        // Direct upgrade buttons
                        Button("Upgrade to Premium") {
                            premiumManager.upgradeToPremium(plan: .plus)
                        }
                        .buttonStyle(PremiumButtonStyle(isPrimary: true))
                        
                        Button("Maybe Later") {
                            dismiss()
                        }
                        .buttonStyle(PremiumButtonStyle(isPrimary: false))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var weatherAlarmIcon: String {
        switch reason {
        case .weatherAlarms:
            return "cloud.bolt.rain.fill"
        case .premiumFeatures:
            return "crown.fill"
        case .trialExpired:
            return "clock.fill"
        }
    }
    
    private var weatherAlarmFeatures: some View {
        VStack(spacing: 16) {
            FeatureRow(
                icon: "cloud.rain.fill",
                title: "Weather-Smart Wake Times",
                description: "Automatic adjustments for rain, snow, and severe weather"
            )
            
            FeatureRow(
                icon: "location.fill",
                title: "Route-Based Analysis",
                description: "Real-time weather monitoring along your entire commute"
            )
            
            FeatureRow(
                icon: "bell.badge.fill",
                title: "Smart Notifications",
                description: "Get notified 2 hours before adjusted wake times"
            )
            
            FeatureRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Learning Algorithm",
                description: "Improves accuracy based on your actual travel times"
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Premium Button Style
struct PremiumButtonStyle: ButtonStyle {
    let isPrimary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(isPrimary ? .white : .blue)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Group {
                    if isPrimary {
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPrimary ? Color.clear : Color.blue, lineWidth: 2)
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PremiumWeatherAlertsContainer: View {
    @ObservedObject var alertManager: WeatherAlertManager
    
    var body: some View {
        if !alertManager.activeAlerts.isEmpty {
            VStack {
                Text("Weather Alerts Active")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding()
            }
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Environment Key for Premium Manager - FIXED
struct PremiumManagerKey: EnvironmentKey {
    @MainActor
    static let defaultValue: PremiumManager = {
        return PremiumManager()
    }()
}

extension EnvironmentValues {
    var premiumManager: PremiumManager {
        get { self[PremiumManagerKey.self] }
        set { self[PremiumManagerKey.self] = newValue }
    }
}
