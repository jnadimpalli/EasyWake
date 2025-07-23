import SwiftUI
import CryptoKit   // for SHA‐256 hashing

struct ChangePasswordView: View {
    @EnvironmentObject var session: SessionManager

    // MARK: –– Form state
    @State private var currentPassword: String = ""
    @State private var newPassword: String     = ""
    @State private var confirmPassword: String = ""
    
    // MARK: –– Show/hide toggles
    @State private var showCurrent: Bool = false
    @State private var showNew: Bool     = false
    @State private var showConfirm: Bool = false

    // MARK: –– Feedback
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    // MARK: –– Stored credentials
    @AppStorage("savedUsername") private var savedUsername = ""
    @AppStorage("savedPassword") private var savedPassword = ""
    
    // MARK: –– Your Lambda URL
    private let lambdaURL = "https://6qvleq3o26pgdp7jmr4aachf5y0qbkfi.lambda-url.us-east-1.on.aws/"

    var body: some View {
        Form {
            // ── Current Password ────────────────────────
            Section(header: Text("Current Password")) {
                HStack {
                    Group {
                        if showCurrent {
                            TextField("Enter current password", text: $currentPassword)
                        } else {
                            SecureField("Enter current password", text: $currentPassword)
                        }
                    }
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    
                    Button {
                        showCurrent.toggle()
                    } label: {
                        Image(systemName: showCurrent ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
            }

            // ── New Password ────────────────────────────
            Section(header: Text("New Password")) {
                HStack {
                    Group {
                        if showNew {
                            TextField("Enter new password", text: $newPassword)
                        } else {
                            SecureField("Enter new password", text: $newPassword)
                        }
                    }
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    
                    Button {
                        showNew.toggle()
                    } label: {
                        Image(systemName: showNew ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                HStack {
                    Group {
                        if showConfirm {
                            TextField("Confirm new password", text: $confirmPassword)
                        } else {
                            SecureField("Confirm new password", text: $confirmPassword)
                        }
                    }
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    
                    Button {
                        showConfirm.toggle()
                    } label: {
                        Image(systemName: showConfirm ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
            }

            // ── Success Message ─────────────────────────
            if let success = successMessage {
                Section {
                    Text(success)
                        .foregroundColor(.green)
                }
            }

            // ── Error Message ───────────────────────────
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }

            // ── Save Button ─────────────────────────────
            Section {
                Button {
                    guard !newPassword.isEmpty, newPassword == confirmPassword else {
                        errorMessage   = "Passwords do not match or are empty."
                        successMessage = nil
                        return
                    }
                    errorMessage   = nil
                    successMessage = nil
                    Task { await changePassword() }
                } label: {
                    Text("Save Password")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)          // make the label stretch
                }
                .pillButton(fill: .customBlue)               // your capsule style
                .listRowInsets(EdgeInsets(top: 0,            // match text-field width
                                          leading: 16,
                                          bottom: 0,
                                          trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Change Password")
    }

    // MARK: –– SHA-256 hasher (not used here, but kept for consistency)
    private func hashPassword(_ plain: String) -> String {
        let digest = SHA256.hash(data: Data(plain.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: –– Call Lambda to update password
    private func changePassword() async {
        guard let url = URL(string: lambdaURL) else {
            showError("Invalid server URL"); return
        }

        let payload: [String: Any] = [
            "userId":      savedUsername,
            "operation":   "passwordChange",
            "password":    currentPassword,
            "newPassword": newPassword
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            showError("Failed to build request"); return
        }

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let httpResp = resp as? HTTPURLResponse else {
                showError("Invalid response from server"); return
            }
            if httpResp.statusCode == 200 {
                await MainActor.run {
                    // persist the new password
                    savedPassword           = newPassword
                    session.currentPassword = newPassword

                    successMessage = "Password updated successfully."
                    errorMessage   = nil

                    // clear fields
                    currentPassword = ""
                    newPassword     = ""
                    confirmPassword = ""
                }
            } else {
                let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                let err  = json?["error"] as? String
                showError(err ?? "Server returned status \(httpResp.statusCode)")
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ msg: String) {
        Task { @MainActor in
            errorMessage   = msg
            successMessage = nil
        }
    }
}

#Preview {
    ChangePasswordView().environmentObject(SessionManager())
}//
//  ChangePasswordView.swift
//  Easy Wake
//
//  Created by Prafulla Bhupathi Raju on 6/26/25.
//

