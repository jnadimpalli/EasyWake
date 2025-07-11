// ProfileView.swift

import SwiftUI
import CryptoKit

struct ProfileView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        Group {
            if !session.isLoggedIn {
                LoginView()
                    .environmentObject(session)
            } else {
                NavigationStack {
                    Form {
                        // MARK: - Account Info Section
                        AccountInfoSection(viewModel: viewModel)
                        
                        // MARK: - Subscription Status Section
                        SubscriptionStatusSection(viewModel: viewModel)
                        
                        // MARK: - Addresses Section
                        AddressSectionView(viewModel: viewModel)
                        
                        // MARK: - Alarm & Commute Preferences
                        CommutePreferencesSection(viewModel: viewModel)
                        
                        // MARK: - Notifications & Alerts
                        NotificationSettingsSection(viewModel: viewModel)
                        
                        // MARK: - Sleep & Bedtime Aids
                        SleepSettingsSection(viewModel: viewModel)
                        
                        // MARK: - Integrations (Premium)
                        if viewModel.isPremiumUser {
                            IntegrationsSection(viewModel: viewModel)
                        }
                        
                        // MARK: - App Info & Legal
                        AppInfoSection()
                        
                        // MARK: - Account Actions
                        AccountActionsSection(viewModel: viewModel, session: session)
                    }
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 96)
                    }
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        if viewModel.isEditingName {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Save") {
                                    Task {
                                        await viewModel.updateName()
                                    }
                                }
                                .disabled(!viewModel.nameIsValid || viewModel.isLoading)
                            }
                        }
                    }
                    .alert("Error", isPresented: $viewModel.showError) {
                        Button("OK") { }
                    } message: {
                        Text(viewModel.errorMessage)
                    }
                    .sheet(isPresented: $viewModel.showAddLocationSheet) {
                        AddLocationSheet(viewModel: viewModel)
                    }
                }
                .navigationBarBackButtonHidden(true)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}

// MARK: - Account Info Section
struct AccountInfoSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        Section {
            // Name
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if viewModel.isEditingName {
                        HStack {
                            TextField("First Name", text: $viewModel.firstName)
                                .textFieldStyle(.roundedBorder)
                            TextField("Last Name", text: $viewModel.lastName)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        Text(viewModel.fullName.isEmpty ? "Tap to add name" : viewModel.fullName)
                            .foregroundColor(viewModel.fullName.isEmpty ? .secondary : .primary)
                    }
                }
                
                Spacer()
                
                Button {
                    viewModel.isEditingName.toggle()
                } label: {
                    Image(systemName: viewModel.isEditingName ? "xmark.circle.fill" : "pencil")
                        .foregroundColor(.blue)
                }
            }
            
            // Email (Read-only)
            VStack(alignment: .leading, spacing: 2) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.email)
                    .foregroundColor(.primary)
            }
            
            // Change Password
            NavigationLink("Change Password") {
                ChangePasswordView()
            }
        } header: {
            Label("ACCOUNT", systemImage: "person.circle")
        }
    }
}

// MARK: - Subscription Status Section
struct SubscriptionStatusSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.subscriptionStatusText)
                        .font(.headline)
                    
                    if viewModel.subscriptionPlan == .trial && viewModel.trialDaysRemaining > 0 {
                        Text("Upgrade to keep premium features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if viewModel.subscriptionPlan == .free {
                        Text("Upgrade for unlimited alarms and premium features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if viewModel.subscriptionPlan != .pro {
                    Button("Upgrade") {
                        // TODO: Show upgrade flow
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            // Referral (if applicable)
            if viewModel.subscriptionPlan != .free {
                NavigationLink("Invite Friends - Get 1 Week Free") {
                    ReferralView()
                }
            }
        } header: {
            Label("SUBSCRIPTION", systemImage: "crown")
        }
    }
}

// MARK: - Address Section
struct AddressSectionView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        Section {
            // Home Address
            AddressRow(
                address: viewModel.homeAddress ?? Address(label: .home, street: "", city: "", zip: "", state: "Select"),
                onUpdate: viewModel.updateAddress
            )
            
            // Work Address
            AddressRow(
                address: viewModel.workAddress ?? Address(label: .work, street: "", city: "", zip: "", state: "Select"),
                onUpdate: viewModel.updateAddress
            )
            
            // Add Custom Location
            Button {
                viewModel.showAddLocationSheet = true
            } label: {
                Label("Add Location", systemImage: "plus.circle.fill")
                    .foregroundColor(.blue)
            }
        } header: {
            Label("ADDRESSES", systemImage: "location")
        }
        
        // Custom Locations
        if !viewModel.customAddresses.isEmpty {
            Section {
                ForEach(viewModel.customAddresses) { address in
                    CustomLocationRow(address: address) {
                        viewModel.deleteAddress(address)
                    }
                }
                .onMove { source, destination in
                    viewModel.moveAddresses(from: source, to: destination)
                }
            } header: {
                Label("SAVED LOCATIONS", systemImage: "mappin.and.ellipse")
            }
        }
    }
}

// MARK: - Address Row
struct AddressRow: View {
    let address: Address
    let onUpdate: (Address) -> Void
    @State private var isEditing = false
    @State private var editingAddress: Address
    
    init(address: Address, onUpdate: @escaping (Address) -> Void) {
        self.address = address
        self.onUpdate = onUpdate
        self._editingAddress = State(initialValue: address)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(address.label.displayName, systemImage: address.label == .home ? "house.fill" : "building.2.fill")
                    .foregroundColor(address.label == .home ? .blue : .orange)
                
                Spacer()
                
                Button {
                    editingAddress = address
                    isEditing.toggle()
                } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
            }
            
            if isEditing {
                VStack(spacing: 12) {
                    TextField("Street Address", text: $editingAddress.street)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        TextField("City", text: $editingAddress.city)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("ZIP", text: $editingAddress.zip)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 80)
                    }
                    
                    Picker("State", selection: $editingAddress.state) {
                        ForEach(states, id: \.self) { state in
                            Text(state).tag(state)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Button("Cancel") {
                            editingAddress = address
                            isEditing = false
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("Save") {
                            onUpdate(editingAddress)
                            isEditing = false
                        }
                        .disabled(!editingAddress.isValid)
                        .foregroundColor(.blue)
                    }
                    .font(.subheadline)
                }
            } else {
                if address.isValid {
                    Text(address.displayAddress)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Tap to add \(address.label.displayName.lowercased()) address")
                      .font(.subheadline)
                      .foregroundStyle(.tertiary)    // accepts ShapeStyle
                      .italic()
                }
            }
        }
    }
    
    private let states = [
        "Select", "AK", "AL", "AR", "AZ", "CA", "CO", "CT", "DC", "DE", "FL", "GA", "HI", "IA",
        "ID", "IL", "IN", "KS", "KY", "LA", "MA", "MD", "ME", "MI", "MN", "MO", "MS",
        "MT", "NC", "ND", "NE", "NH", "NJ", "NM", "NV", "NY", "OH", "OK", "OR", "PA",
        "RI", "SC", "SD", "TN", "TX", "UT", "VA", "VT", "WA", "WI", "WV", "WY"
    ]
}

// MARK: - Custom Location Row
struct CustomLocationRow: View {
    let address: Address
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(address.customLabel ?? "Custom Location")
                    .font(.body)
                Text(address.shortDisplayAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Commute Preferences Section
struct CommutePreferencesSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        Section {
            // Clock Format
            Picker("Clock Format", selection: $viewModel.preferences.clockFormat24h) {
                Text("12-hour").tag(false)
                Text("24-hour").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.preferences.clockFormat24h) { _, _ in
                viewModel.updatePreferences()
            }
            
            // Travel Method
            Picker("Default Travel Method", selection: $viewModel.preferences.travelMethod) {
                ForEach(TravelMethod.allCases, id: \.self) { method in
                    Label(method.displayName, systemImage: method.icon)
                        .tag(method)
                }
            }
            .onChange(of: viewModel.preferences.travelMethod) { _, _ in
                viewModel.updatePreferences()
            }
            
            // Commute Buffer
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Commute Buffer")
                    Spacer()
                    Text("\(viewModel.preferences.commuteBuffer) min")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                
                Slider(
                    value: Binding(
                        get: { Double(viewModel.preferences.commuteBuffer) },
                        set: { viewModel.preferences.commuteBuffer = Int($0) }
                    ),
                    in: 0...60,
                    step: 5
                ) {
                    Text("Buffer Time")
                } minimumValueLabel: {
                    Text("0")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("60")
                        .font(.caption)
                }
                .onChange(of: viewModel.preferences.commuteBuffer) { _, _ in
                    viewModel.updatePreferences()
                }
            }
            
            // Smart Snooze
            Toggle("Limit Snooze", isOn: $viewModel.preferences.limitSnooze)
                .onChange(of: viewModel.preferences.limitSnooze) { _, _ in
                    viewModel.updatePreferences()
                }
            
            if viewModel.preferences.limitSnooze {
                Stepper(
                    "Max \(viewModel.preferences.maxSnoozes) snoozes",
                    value: $viewModel.preferences.maxSnoozes,
                    in: 1...10
                )
                .onChange(of: viewModel.preferences.maxSnoozes) { _, _ in
                    viewModel.updatePreferences()
                }
            }
        } header: {
            Label("ALARM & COMMUTE", systemImage: "alarm")
        } footer: {
            Text("Add extra time to your commute and control snooze behavior.")
        }
    }
}

// MARK: - Notification Settings Section
struct NotificationSettingsSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        Section {
            Toggle(isOn: $viewModel.preferences.pushNotificationsEnabled) {
                Label("Push Notifications", systemImage: "bell.fill")
            }
            .onChange(of: viewModel.preferences.pushNotificationsEnabled) { _, _ in
                viewModel.updatePreferences()
            }
            
            Toggle(isOn: $viewModel.preferences.weatherAlertsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weather Alerts")
                    Text(viewModel.isPremiumUser ? "Custom thresholds" : "Severe weather only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!viewModel.preferences.pushNotificationsEnabled)
            .onChange(of: viewModel.preferences.weatherAlertsEnabled) { _, _ in
                viewModel.updatePreferences()
            }
            
            if viewModel.isPremiumUser {
                Toggle(isOn: $viewModel.preferences.trafficAlertsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Traffic Alerts")
                            Image(systemName: "crown.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        Text("Get notified of delays on your route")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(!viewModel.preferences.pushNotificationsEnabled)
                .onChange(of: viewModel.preferences.trafficAlertsEnabled) { _, _ in
                    viewModel.updatePreferences()
                }
                
                Toggle(isOn: $viewModel.preferences.calendarRemindersEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Calendar Reminders")
                            Image(systemName: "crown.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        Text("Auto-create alarms from calendar events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(!viewModel.preferences.pushNotificationsEnabled)
                .onChange(of: viewModel.preferences.calendarRemindersEnabled) { _, _ in
                    viewModel.updatePreferences()
                }
            }
        } header: {
            Label("NOTIFICATIONS", systemImage: "bell.badge")
        }
    }
}

// MARK: - Sleep Settings Section
struct SleepSettingsSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        Section {
            Toggle(isOn: $viewModel.preferences.bedtimeReminderEnabled) {
                Text("Bedtime Reminder")
            }
            .onChange(of: viewModel.preferences.bedtimeReminderEnabled) { _, _ in
                viewModel.updatePreferences()
            }
            
            if viewModel.preferences.bedtimeReminderEnabled {
                DatePicker(
                    "Remind me at",
                    selection: $viewModel.preferences.bedtimeReminderTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: viewModel.preferences.bedtimeReminderTime) { _, _ in
                    viewModel.updatePreferences()
                }
            }
            
            Toggle(isOn: $viewModel.preferences.sleepCycleRecommendationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sleep-Cycle Recommendations")
                    Text("Get optimal bedtime suggestions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: viewModel.preferences.sleepCycleRecommendationsEnabled) { _, _ in
                viewModel.updatePreferences()
            }
        } header: {
            Label("SLEEP & BEDTIME", systemImage: "moon.fill")
        }
    }
}

// MARK: - Integrations Section (Premium)
struct IntegrationsSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        Section {
            Button {
                // TODO: Calendar OAuth flow
            } label: {
                HStack {
                    Label("Connect Calendar", systemImage: "calendar.badge.plus")
                    Spacer()
                    if viewModel.preferences.calendarSyncEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .foregroundColor(.primary)
            
            Toggle(isOn: $viewModel.preferences.siriShortcutsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Siri Shortcuts")
                        Image(systemName: "crown.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    Text("\"Hey Siri, set my work alarm\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: viewModel.preferences.siriShortcutsEnabled) { _, _ in
                viewModel.updatePreferences()
            }
        } header: {
            Label("INTEGRATIONS", systemImage: "link")
        }
    }
}

// MARK: - App Info Section
struct AppInfoSection: View {
    var body: some View {
        Section {
            HStack {
                Text("App Version")
                Spacer()
                Text("1.0.0 (Build 42)")
                    .foregroundColor(.secondary)
            }
            
            NavigationLink("Software License Agreement") {
                LegalDocumentView(type: .license)
            }
            
            NavigationLink("Terms of Service") {
                LegalDocumentView(type: .terms)
            }
            
            NavigationLink("Privacy Policy") {
                LegalDocumentView(type: .privacy)
            }
        } header: {
            Label("ABOUT", systemImage: "info.circle")
        }
    }
}

// MARK: - Account Actions Section
struct AccountActionsSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    @ObservedObject var session: SessionManager
    
    var body: some View {
        Section {
            Button("Log Out", role: .destructive) {
                viewModel.logout()
                session.currentUser = nil
                session.currentPassword = nil
            }
        }
    }
}

// MARK: - Add Location Sheet
struct AddLocationSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var customLabel = ""
    @State private var newAddress = Address(label: .custom, street: "", city: "", zip: "", state: "Select")
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Location Name (e.g., Gym, Office)", text: $customLabel)
                    TextField("Street Address", text: $newAddress.street)
                    TextField("City", text: $newAddress.city)
                    
                    HStack {
                        TextField("ZIP Code", text: $newAddress.zip)
                            .keyboardType(.numberPad)
                        
                        Picker("State", selection: $newAddress.state) {
                            ForEach(states, id: \.self) { state in
                                Text(state).tag(state)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Location Details")
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var addressToSave = newAddress
                        addressToSave.customLabel = customLabel
                        viewModel.addCustomLocation(addressToSave)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private var canSave: Bool {
        !customLabel.isEmpty &&
        customLabel.count <= 20 &&
        newAddress.isValid
    }
    
    private let states = [
        "Select", "AK", "AL", "AR", "AZ", "CA", "CO", "CT", "DC", "DE", "FL", "GA", "HI", "IA",
        "ID", "IL", "IN", "KS", "KY", "LA", "MA", "MD", "ME", "MI", "MN", "MO", "MS",
        "MT", "NC", "ND", "NE", "NH", "NJ", "NM", "NV", "NY", "OH", "OK", "OR", "PA",
        "RI", "SC", "SD", "TN", "TX", "UT", "VA", "VT", "WA", "WI", "WV", "WY"
    ]
}

// MARK: - Supporting Views (Stubs)
struct ReferralView: View {
    var body: some View {
        Text("Referral Program")
            .navigationTitle("Invite Friends")
    }
}

struct LegalDocumentView: View {
    enum DocumentType {
        case license, terms, privacy
        
        var title: String {
            switch self {
            case .license: return "License Agreement"
            case .terms: return "Terms of Service"
            case .privacy: return "Privacy Policy"
            }
        }
    }
    
    let type: DocumentType
    
    var body: some View {
        ScrollView {
            Text("Legal document content would go here...")
                .padding()
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .environmentObject(SessionManager())
}
