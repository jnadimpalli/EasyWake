// ViewModels/ProfileViewModel.swift

import SwiftUI
import CryptoKit
import Combine

class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var addresses: [Address] = []
    @Published var preferences = UserPreferences()
    @Published var subscriptionPlan: SubscriptionPlan = .free
    @Published var trialDaysRemaining: Int = 0
    
    // MARK: - UI State
    @Published var isEditingName = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var showAddLocationSheet = false
    
    // MARK: - Form Validation
    @Published var nameIsValid = true
    @Published var zipIsValid = true
    
    // MARK: - Dependencies
    private let lambdaURL = "https://6qvleq3o26pgdp7jmr4aachf5y0qbkfi.lambda-url.us-east-1.on.aws/"
    
    // MARK: - AppStorage
    @AppStorage("savedUsername") private var savedUsername = ""
    @AppStorage("savedPassword") private var savedPassword = ""
    @AppStorage("savedFirstName") private var savedFirstName = ""
    @AppStorage("savedLastName") private var savedLastName = ""
    @AppStorage("userAddresses") private var storedAddresses = Data()
    @AppStorage("userPreferences") private var storedPreferences = Data()
    @AppStorage("subscriptionPlan") private var storedSubscriptionPlan = "free"
    @AppStorage("trialStartDate") private var trialStartDate = Date()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadData()
        setupValidation()
    }
    
    // MARK: - Computed Properties
    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    var homeAddress: Address? {
        addresses.first { $0.label == .home }
    }
    
    var workAddress: Address? {
        addresses.first { $0.label == .work }
    }
    
    var customAddresses: [Address] {
        addresses.filter { $0.label == .custom }
    }
    
    var subscriptionStatusText: String {
        switch subscriptionPlan {
        case .free:
            return "Free Tier"
        case .trial:
            return "Trial (\(trialDaysRemaining) days left)"
        case .plus:
            return "Plus Plan"
        case .pro:
            return "Pro Plan"
        }
    }
    
    var isPremiumUser: Bool {
        subscriptionPlan == .plus || subscriptionPlan == .pro ||
        (subscriptionPlan == .trial && trialDaysRemaining > 0)
    }
    
    // MARK: - Data Loading
    public func loadData() {
        // Load basic info
        firstName = savedFirstName
        lastName = savedLastName
        email = savedUsername
        
        // Load addresses
        if let decoded = try? JSONDecoder().decode([Address].self, from: storedAddresses) {
            addresses = decoded
        } else {
            // Initialize with empty home and work addresses
            addresses = [
                Address(label: .home, street: "", city: "", zip: "", state: "Select"),
                Address(label: .work, street: "", city: "", zip: "", state: "Select")
            ]
        }
        
        // Load preferences
        if let decoded = try? JSONDecoder().decode(UserPreferences.self, from: storedPreferences) {
            preferences = decoded
        }
        
        // Load subscription info
        subscriptionPlan = SubscriptionPlan(rawValue: storedSubscriptionPlan) ?? .free
        calculateTrialDaysRemaining()
    }
    
    private func calculateTrialDaysRemaining() {
        if subscriptionPlan == .trial {
            let daysSinceStart = Calendar.current.dateComponents([.day], from: trialStartDate, to: Date()).day ?? 0
            trialDaysRemaining = max(0, 7 - daysSinceStart)
        }
    }
    
    // MARK: - Validation Setup
    private func setupValidation() {
        // Name validation
        $firstName.combineLatest($lastName)
            .map { first, last in
                let combined = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
                return !combined.isEmpty && combined.count <= 50
            }
            .assign(to: &$nameIsValid)
    }
    
    // MARK: - Data Persistence
    private func saveData() {
        // Save addresses
        if let encoded = try? JSONEncoder().encode(addresses) {
            storedAddresses = encoded
        }
        
        // Save preferences
        if let encoded = try? JSONEncoder().encode(preferences) {
            storedPreferences = encoded
        }
        
        // Save subscription
        storedSubscriptionPlan = subscriptionPlan.rawValue
    }
    
    // MARK: - Name Management
    func updateName() async {
        guard nameIsValid else {
            showErrorMessage("Please enter a valid name.")
            return
        }
        
        isLoading = true
        
        guard let url = URL(string: lambdaURL) else {
            showErrorMessage("Invalid server URL")
            isLoading = false
            return
        }
        
        let hashedPW = hashPassword(savedPassword)
        let payload: [String: Any] = [
            "userId": savedUsername,
            "operation": "update",
            "password": hashedPW,
            "firstName": firstName,
            "lastName": lastName
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode == 200 {
                await MainActor.run {
                    savedFirstName = firstName
                    savedLastName = lastName
                    isEditingName = false
                    isLoading = false
                }
            } else {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let error = json?["error"] as? String ?? "Update failed"
                throw NSError(domain: "ProfileError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: error])
            }
        } catch {
            await MainActor.run {
                showErrorMessage(error.localizedDescription)
                isLoading = false
            }
        }
    }
    
    // MARK: - Address Management
    func updateAddress(_ address: Address) {
        if let index = addresses.firstIndex(where: { $0.id == address.id }) {
            addresses[index] = address
        } else {
            addresses.append(address)
        }
        saveData()
    }
    
    func addCustomLocation(_ address: Address) {
        var customAddress = address
        customAddress.label = .custom
        addresses.append(customAddress)
        saveData()
    }
    
    func deleteAddress(_ address: Address) {
        addresses.removeAll { $0.id == address.id }
        saveData()
    }
    
    func moveAddresses(from source: IndexSet, to destination: Int) {
        let customAddressesStartIndex = addresses.firstIndex { $0.label == .custom } ?? addresses.count
        let adjustedSource = IndexSet(source.map { $0 + customAddressesStartIndex })
        let adjustedDestination = destination + customAddressesStartIndex
        
        addresses.move(fromOffsets: adjustedSource, toOffset: adjustedDestination)
        saveData()
    }
    
    // MARK: - Preferences Management
    func updatePreferences() {
        saveData()
    }
    
    // MARK: - Authentication
    private func hashPassword(_ plain: String) -> String {
        let digest = SHA256.hash(data: Data(plain.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    func logout() {
        // Clear stored data
        savedUsername = ""
        savedPassword = ""
        savedFirstName = ""
        savedLastName = ""
        storedAddresses = Data()
        storedPreferences = Data()
        storedSubscriptionPlan = "free"
        
        // Clear keychain
        KeychainHelper.standard.delete(
            service: "com.irohtechnologies.EasyWake",
            account: email
        )
        
        // Reset local state
        firstName = ""
        lastName = ""
        email = ""
        addresses = []
        preferences = UserPreferences()
        subscriptionPlan = .free
        trialDaysRemaining = 0
    }
    
    // MARK: - Error Handling
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}
