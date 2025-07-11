import Foundation
import SwiftUI

@MainActor
class SessionManager: ObservableObject {
    @Published var currentUser: String?
    @Published var currentPassword: String?
    
    // expose whether we’re “logged in”
    var isLoggedIn: Bool { currentUser != nil && currentPassword != nil }
    
    init() {
        // 1️⃣ read username from UserDefaults/AppStorage
        let defaults = UserDefaults.standard
        guard let savedUser = defaults.string(forKey: "savedUsername") else {
            // no saved user → not logged in
            return
        }
        
        // 2️⃣ read password data from Keychain
        if let pwdData = KeychainHelper.standard.read(
               service: "com.yourcompany.EZWake",
               account: savedUser
           ),
           let pwdString = String(data: pwdData, encoding: .utf8)
        {
            // we got both → consider ourselves logged in
            currentUser = savedUser
            currentPassword = pwdString
            
            // 3️⃣ optionally kick off an auto-login or session-validation call
            //    Task { await self.login() }
        } else {
            // Keychain had no entry → treat as not logged in
        }
    }
    
    func login(user: String, password: String) async {
        // your existing network‐call logic, e.g. POST to /login
        // on success:
        await MainActor.run {
            self.currentUser = user
            self.currentPassword = password
        }
    }
    
    func logout() {
        // clear everything
        if let user = currentUser {
            KeychainHelper.standard.delete(
                service: "com.yourcompany.EZWake",
                account: user
            )
        }
        UserDefaults.standard.removeObject(forKey: "savedUsername")
        currentUser = nil
        currentPassword = nil
    }
}
