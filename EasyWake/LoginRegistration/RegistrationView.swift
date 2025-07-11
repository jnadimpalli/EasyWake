// RegistrationView.swift
import SwiftUI
import CryptoKit   // ← for SHA-256

struct RegistrationView: View {
    // MARK: –– Session
    @EnvironmentObject var session: SessionManager

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    
    @State private var navigateToLogin = false
    @State private var navigateToUserSettings = false
    @State private var navigateToAlarmList = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @AppStorage("savedUsername")     private var savedUsername = ""
    @AppStorage("savedPassword")     private var savedPassword = ""
    @AppStorage("savedFirstName") private var savedFirstName = ""
    @AppStorage("savedLastName")  private var savedLastName  = ""
    
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
                    .foregroundColor(.blue)
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

                    Text("Password").bold()
                    SecureField("Enter Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text("Re-enter Password").bold()
                    SecureField("Re-enter password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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

                // MARK: Continue Button
                HStack {
                    Spacer()
                    Button("Continue") {
                        errorMessage = ""
                        guard validateInputs() else { return }
                        Task {
                            await createUser()
                        }
                    }
                    .frame(width: 300)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!isFormValid)
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }

                // MARK: Social Login
                Text("or")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 12) {
                    // Google button with black border
                    Button(action: { /* Google sign-in */ }) {
                        HStack(spacing: 12) {
                            Image("GoogleIcon")
                                .resizable()
                                .renderingMode(.original)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            Text("Continue with Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: 300)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black, lineWidth: 1)
                        )
                    }

                    // Apple button (unchanged)
                    Button(action: { /* Apple sign-in */ }) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Continue with Apple")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: 300)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    // “Skip for now” button
                    Button("Skip for now") {
                        Task {
                            await MainActor.run {
                                session.currentUser     = ""
                                session.currentPassword = ""
                            }
                        }
                        didCompleteOnboarding = true
                        navigateToAlarmList = true
                    }
                    .frame(maxWidth: 300)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(Color.blue)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        // MARK: Navigation
        .navigationDestination(isPresented: $navigateToLogin) {
            LoginView().environmentObject(session)
        }
        .navigationDestination(isPresented: $navigateToUserSettings) {
            UserSettingsView(origin: .onboarding).environmentObject(session)
        }
        .navigationDestination(isPresented: $navigateToAlarmList) {
            AlarmListView().environmentObject(session)
        }
    }

    // MARK: –– Validation Logic
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
        // 8–30 chars, at least one letter, one digit, one special char
        let pattern = "^(?=.*[A-Za-z])(?=.*\\d)(?=.*[@#$%&!\\-_<>])[A-Za-z\\d@#$%&!\\-_<>]{8,30}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern)
            .evaluate(with: s)
    }

    // MARK: –– Hashing (SHA-256)
    private func hashPassword(_ plain: String) -> String {
        let data = Data(plain.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: –– Networking
    private func createUser() async {
        guard let url = URL(string: lambdaURL) else {
            errorMessage = "Invalid server URL"
            return
        }
        
        let nameOptions = [
                    "Newbie Nick",
                    "Novice Nancy",
                    "Willie Makeit",
                    "Fresh Face Frank",
                    "Rookie Rex",
                    "Just Joined Jessie",
                    "Just Joined Jesse",
                    "Data Dave"
                ]
        let chosen = nameOptions.randomElement()!
        let parts  = chosen.split(separator: " ")
        let first  = parts.dropLast().joined(separator: " ")
        let last   = "\(parts.last!)\(Int.random(in: 1...10_000_000))"

        // Save into AppStorage so ProfileView can pick it up later
        savedFirstName = first
        savedLastName  = last

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "userId":    email,
            "operation": "create",
            "password":  hashPassword(password),
            "firstName": first,
            "lastName":  last
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
                
                // persist raw password securely in Keychain
                let pwdData = Data(password.utf8)
                KeychainHelper.standard.save(pwdData,
                    service: "com.irohtechnologies.EasyWake",
                    account: email)
                
                await MainActor.run {
                    session.currentUser     = email
                    session.currentPassword = password
                }
                
                didCompleteOnboarding = true
                navigateToUserSettings = true
            } else {
                // surface the Lambda’s error message if present
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
        RegistrationView().environmentObject(SessionManager())
    }
}
