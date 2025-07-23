// RegistrationView.swift - Fixed with Skip Warning
import SwiftUI
import CryptoKit

struct RegistrationView: View {
    @EnvironmentObject var session: SessionManager
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var showSkipWarning = false
    
    @State private var navigateToLogin = false
    @State private var navigateToUserSettings = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @AppStorage("savedUsername") private var savedUsername = ""
    @AppStorage("savedPassword") private var savedPassword = ""
    @AppStorage("savedFirstName") private var savedFirstName = ""
    @AppStorage("savedLastName") private var savedLastName = ""
    
    private let lambdaURL = "https://6qvleq3o26pgdp7jmr4aachf5y0qbkfi.lambda-url.us-east-1.on.aws/"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: Top-right Login
                HStack {
                    Spacer()
                    Text("Already have an account?")
                        .font(.footnote)
                    Button("Login") {
                        navigateToLogin = true
                    }
                    .font(.footnote)
                    .foregroundColor(.customBlue)
                }
                .padding(.top, 8)
                .padding(.trailing, 10)

                // MARK: Title
                Text("Welcome to Easy Wake!")
                    .font(.title).bold()
                Text("Description").font(.subheadline)

                // MARK: Form Fields
                Group {
                    Text("Email").bold()
                    TextField("enter email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password").bold()
                        RevealableSecureField(title: "Enter Password", text: $password)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Re-enter Password").bold()
                        RevealableSecureField(title: "Re-enter Password", text: $confirmPassword)
                    }
                }

                // MARK: Error
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Text("Terms & Conditions")
                    .font(.footnote)
                    .padding(.top, 8)
                
                Spacer().frame(height: 4)

                // MARK: Continue Button
                HStack {
                    Spacer()
                    Button {
                        errorMessage = ""
                        guard validateInputs() else { return }
                        Task {
                            await createUser()
                        }
                    } label: {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 280)
                    }
                    .buttonStyle(PillButtonStyle(fill: isFormValid ? Color.customBlue : Color.gray, border: isFormValid ? Color.customBlue : .gray))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .disabled(!isFormValid)
                    Spacer()
                }

                // MARK: Social Login
                // OR + Social / navigation
                OrDivider()

                // Social buttons
                VStack(spacing: 12) {
                    SocialButton(type: .google,
                                 title: "Continue with Google") {
                        // TODO: Google sign-in
                    }
                    .frame(maxWidth: 320)
                    
                    Spacer().frame(height: 4)

                    SocialButton(type: .apple,
                                 title: "Continue with Apple") {
                        // TODO: Apple sign-in
                    }
                    .frame(maxWidth: 320)
                    
                    Spacer().frame(height: 4)
                    
                    Button {
                        showSkipWarning = true
                    } label: {
                        Text("Skip for now")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.customBlue)
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(PillButtonStyle(fill: .white, border: .customBlue))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToLogin) {
            LoginView()
        }
        .navigationDestination(isPresented: $navigateToUserSettings) {
            UserSettingsView(origin: .onboarding)
        }
        .alert("Continue as Guest?", isPresented: $showSkipWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Continue as Guest") {
                session.skipLogin()
            }
        } message: {
            Text("⚠️ No user profile information will be saved and you will not have access to premium features like weather-adjusted alarms, saved addresses, and cloud sync.")
        }
    }

    // MARK: - Validation Logic
    private func validateInputs() -> Bool {
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return false
        }
        guard isValidPassword(password) else {
            errorMessage = "Password must be 8–30 chars, with a letter, number & special char"
            return false
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return false
        }
        return true
    }

    private var isFormValid: Bool {
        isValidEmail(email)
            && isValidPassword(password)
            && password == confirmPassword
    }

    private func isValidEmail(_ s: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES[c] %@", pattern)
            .evaluate(with: s)
    }

    private func isValidPassword(_ s: String) -> Bool {
        let pattern = "^(?=.*[A-Za-z])(?=.*\\d)(?=.*[@#$%&!\\-_<>])[A-Za-z\\d@#$%&!\\-_<>]{8,30}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern)
            .evaluate(with: s)
    }

    private func hashPassword(_ plain: String) -> String {
        let data = Data(plain.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func createUser() async {
        guard let url = URL(string: lambdaURL) else {
            errorMessage = "Invalid server URL"
            return
        }
        
        let nameOptions = [
            "Newbie Nick", "Novice Nancy", "Willie Makeit", "Fresh Face Frank",
            "Rookie Rex", "Just Joined Jessie", "Just Joined Jesse", "Data Dave"
        ]
        let chosen = nameOptions.randomElement()!
        let parts = chosen.split(separator: " ")
        let first = parts.dropLast().joined(separator: " ")
        let last = "\(parts.last!)\(Int.random(in: 1...10_000_000))"

        savedFirstName = first
        savedLastName = last

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "userId": email,
            "operation": "create",
            "password": hashPassword(password),
            "firstName": first,
            "lastName": last
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            errorMessage = "Failed to build request"
            return
        }

        do {
            let (data, resp) = try await URLSession.shared.data(for: request)
            guard let httpResp = resp as? HTTPURLResponse else {
                errorMessage = "Invalid response from server"
                return
            }

            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

            if httpResp.statusCode == 200 {
                savedUsername = email
                savedPassword = password
                
                let pwdData = Data(password.utf8)
                KeychainHelper.standard.save(pwdData,
                    service: "com.irohtechnologies.EasyWake",
                    account: email)
                
                await session.completeRegistration(user: email, password: password)
                didCompleteOnboarding = true
                navigateToUserSettings = true
            } else {
                if let err = json?["error"] as? String {
                    errorMessage = err
                } else {
                    errorMessage = "Server returned status \(httpResp.statusCode)"
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        RegistrationView()
            .environmentObject(SessionManager())
    }
}
