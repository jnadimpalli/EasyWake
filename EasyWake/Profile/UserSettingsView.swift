// UserSettingsView.swift

import SwiftUI

struct UserSettingsView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss
    
    /// Where did we come from?
    enum Origin {
        case onboarding   // from Login/Registration
        case profile      // from ProfileView
    }
    
    let origin: Origin
    
    // MARK: - Navigation triggers
    @State private var goToProfile = false
    @State private var goToAlarmList = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    // MARK: - Home Address (Required for basic functionality)
                    Section {
                        TextField("Street Address", text: $viewModel.homeAddress.street)
                            .autocorrectionDisabled()
                        
                        TextField("City", text: $viewModel.homeAddress.city)
                            .autocorrectionDisabled()
                        
                        HStack {
                            TextField("ZIP Code", text: $viewModel.homeAddress.zip)
                                .keyboardType(.numberPad)
                                .onChange(of: viewModel.homeAddress.zip) { _, newValue in
                                    // Limit to 5 digits
                                    if newValue.count > 5 {
                                        viewModel.homeAddress.zip = String(newValue.prefix(5))
                                    }
                                }
                            
                            Spacer()
                            
                            Picker("State", selection: $viewModel.homeAddress.state) {
                                ForEach(viewModel.states, id: \.self) { state in
                                    Text(state).tag(state)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 100)
                        }
                    } header: {
                        Label("Home Address", systemImage: "house.fill")
                    } footer: {
                        Text("We need your home address to calculate commute times for your alarms.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // MARK: - Basic Preferences
                    Section {
                        Picker("Clock Format", selection: $viewModel.clockFormat24h) {
                            Text("12-hour").tag(false)
                            Text("24-hour").tag(true)
                        }
                        .pickerStyle(.segmented)
                        
                        Picker("Default Travel Method", selection: $viewModel.travelMethod) {
                            ForEach(TravelMethod.allCases, id: \.self) { method in
                                Label(method.displayName, systemImage: method.icon)
                                    .tag(method)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Label("Preferences", systemImage: "gearshape.fill")
                    }
                    
                    // MARK: - Notifications
                    Section {
                        Toggle(isOn: $viewModel.pushNotificationsEnabled) {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.customBlue)
                                    .frame(width: 25)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Push Notifications")
                                        .font(.body)
                                    Text("Get alerts for weather and traffic")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } header: {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 96)
                }
                
                // MARK: - Bottom Button
                VStack(spacing: 0) {
                    // Gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 12)
                    .allowsHitTesting(false)
                    
                    // Button container
                    VStack {
                        Button(action: saveAndContinue) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(origin == .onboarding ? "Get Started" : "Save Changes")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.canSave ? Color.customBlue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .disabled(!viewModel.canSave || viewModel.isLoading)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40) // Account for bottom nav bar
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle(origin == .onboarding ? "Get Started" : "Basic Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if origin == .profile {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .navigationDestination(isPresented: $goToProfile) {
                ProfileView()
            }
            .navigationDestination(isPresented: $goToAlarmList) {
                AlarmListView()
            }
        }
    }
    
    private func saveAndContinue() {
        Task {
            await viewModel.saveBasicSettings()
            
            await MainActor.run {
                switch origin {
                case .onboarding:
                    goToAlarmList = true
                case .profile:
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Onboarding ViewModel
class OnboardingViewModel: ObservableObject {
    @Published var homeAddress = Address(label: .home, street: "", city: "", zip: "", state: "Select")
    @Published var clockFormat24h = false
    @Published var travelMethod = TravelMethod.drive
    @Published var pushNotificationsEnabled = true
    
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    let states = [
        "Select", "AK", "AL", "AR", "AZ", "CA", "CO", "CT", "DC", "DE", "FL", "GA", "HI", "IA",
        "ID", "IL", "IN", "KS", "KY", "LA", "MA", "MD", "ME", "MI", "MN", "MO", "MS",
        "MT", "NC", "ND", "NE", "NH", "NJ", "NM", "NV", "NY", "OH", "OK", "OR", "PA",
        "RI", "SC", "SD", "TN", "TX", "UT", "VA", "VT", "WA", "WI", "WV", "WY"
    ]
    
    var canSave: Bool {
        !homeAddress.street.isEmpty &&
        !homeAddress.city.isEmpty &&
        homeAddress.zip.count == 5 &&
        homeAddress.zip.allSatisfy(\.isNumber) &&
        homeAddress.state != "Select"
    }
    
    @MainActor
    func saveBasicSettings() async {
        guard canSave else {
            errorMessage = "Please fill in all required fields."
            showError = true
            return
        }
        
        isLoading = true
        
        // Save to UserDefaults/AppStorage
        let preferences = UserPreferences(
            clockFormat24h: clockFormat24h,
            travelMethod: travelMethod,
            pushNotificationsEnabled: pushNotificationsEnabled
        )
        
        // Store data that ProfileViewModel will pick up
        if let addressData = try? JSONEncoder().encode([homeAddress]) {
            UserDefaults.standard.set(addressData, forKey: "userAddresses")
        }
        
        if let preferencesData = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(preferencesData, forKey: "userPreferences")
        }
        
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
        
        // Simulate network delay for better UX
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        isLoading = false
    }
}

#Preview {
    UserSettingsView(origin: .onboarding)
}
