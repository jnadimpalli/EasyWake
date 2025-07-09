import SwiftUI

struct ChangePasswordView: View {
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showError: Bool = false
    @State private var successMessage: String?

    var body: some View {
        Form {
            Section(header: Text("Current Password")) {
                SecureField("Enter current password", text: $currentPassword)
            }

            Section(header: Text("New Password")) {
                SecureField("Enter new password", text: $newPassword)
                SecureField("Confirm new password", text: $confirmPassword)
            }

            if let success = successMessage {
                Section {
                    Text(success)
                        .foregroundColor(.green)
                }
            }

            if showError {
                Section {
                    Text("Passwords do not match or are empty.")
                        .foregroundColor(.red)
                }
            }

            Section {
                Button("Save Password") {
                    if newPassword == confirmPassword && !newPassword.isEmpty {
                        showError = false
                        successMessage = "Password updated successfully."
                        // Perform your password update logic here
                    } else {
                        showError = true
                        successMessage = nil
                    }
                }
            }
        }
        .navigationTitle("Change Password")
    }
}

#Preview {
    ChangePasswordView()
}//
//  ChangePasswordView.swift
//  EZ Wake
//
//  Created by Prafulla Bhupathi Raju on 6/26/25.
//

