import Foundation
import SwiftUI

@MainActor
class SessionManager: ObservableObject {
    @Published var currentUser: String?
    @Published var currentPassword: String?
    @Published var hasSkippedLogin = false
    
    // App storage for persistence
    @AppStorage("hasCompletedInitialFlow") private var hasCompletedInitialFlow = false
    @AppStorage("hasSkippedLogin") private var storedHasSkippedLogin = false
    @AppStorage("savedUsername") private var savedUsername = ""
    
    // expose whether we're "logged in" or have skipped
    var isAuthenticated: Bool {
        return isLoggedIn || hasSkippedLogin
    }
    
    var isLoggedIn: Bool {
        return currentUser != nil && currentPassword != nil && !currentUser!.isEmpty
    }
    
    init() {
        loadStoredSession()
    }
    
    private func loadStoredSession() {
        // Load skipped state first
        hasSkippedLogin = storedHasSkippedLogin
        
        // If user skipped, don't try to load login credentials
        if hasSkippedLogin {
            print("SessionManager: User has skipped login, staying in guest mode")
            return
        }
        
        // Try to load saved login credentials
        guard !savedUsername.isEmpty else {
            print("SessionManager: No saved username found")
            return
        }
        
        // Read password from Keychain
        if let pwdData = KeychainHelper.standard.read(
               service: "com.irohtechnologies.EasyWake",
               account: savedUsername
           ),
           let pwdString = String(data: pwdData, encoding: .utf8)
        {
            // We have both username and password - consider user logged in
            currentUser = savedUsername
            currentPassword = pwdString
            print("SessionManager: Restored login session for user: \(savedUsername)")
        } else {
            // Keychain had no entry - clear the saved username
            savedUsername = ""
            print("SessionManager: No password found in keychain for saved username")
        }
    }
    
    func login(user: String, password: String) async {
        await MainActor.run {
            self.currentUser = user
            self.currentPassword = password
            self.hasSkippedLogin = false
            self.storedHasSkippedLogin = false
            self.hasCompletedInitialFlow = true
        }
        print("SessionManager: User logged in: \(user)")
    }
    
    func skipLogin() {
        currentUser = nil
        currentPassword = nil
        hasSkippedLogin = true
        storedHasSkippedLogin = true
        hasCompletedInitialFlow = true
        
        // Clear any saved credentials
        savedUsername = ""
        print("SessionManager: User skipped login - entered guest mode")
    }
    
    func logout() {
        // Clear everything
        if let user = currentUser {
            KeychainHelper.standard.delete(
                service: "com.irohtechnologies.EasyWake",
                account: user
            )
        }
        
        // Clear AppStorage
        UserDefaults.standard.removeObject(forKey: "savedUsername")
        UserDefaults.standard.removeObject(forKey: "hasCompletedInitialFlow")
        UserDefaults.standard.removeObject(forKey: "hasSkippedLogin")
        
        // Reset local state
        currentUser = nil
        currentPassword = nil
        hasSkippedLogin = false
        storedHasSkippedLogin = false
        hasCompletedInitialFlow = false
        
        print("SessionManager: User logged out - all session data cleared")
    }
    
    func completeRegistration(user: String, password: String) {
        currentUser = user
        currentPassword = password
        hasSkippedLogin = false
        storedHasSkippedLogin = false
        hasCompletedInitialFlow = true
        print("SessionManager: Registration completed for user: \(user)")
    }
}
