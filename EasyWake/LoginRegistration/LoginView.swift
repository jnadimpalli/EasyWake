import SwiftUI
import CryptoKit
import UIKit

struct LoginView: View {
    @EnvironmentObject var session: SessionManager
    @State private var username = UserDefaults.standard.string(forKey: "savedUsername") ?? ""
    @State private var password = UserDefaults.standard.string(forKey: "savedPassword") ?? ""
    @State private var rememberMe = UserDefaults.standard.bool(forKey: "rememberMe")
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    @State private var navigateToSignUp = false
    @State private var navigateToForgotPwd = false
    
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @AppStorage("savedUsername") private var savedUsername = ""
    @AppStorage("savedPassword") private var savedPassword = ""
    @AppStorage("savedFirstName") private var savedFirstName = ""
    @AppStorage("savedLastName") private var savedLastName = ""
    
    private let lambdaURL = "https://6qvleq3o26pgdp7jmr4aachf5y0qbkfi.lambda-url.us-east-1.on.aws/"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top "Sign Up" prompt
                HStack {
                    Spacer()
                    Text("Don't have an account?")
                        .font(.footnote)
                    Button("Sign Up") {
                        navigateToSignUp = true
                    }
                    .font(.footnote)
                    .foregroundColor(.customBlue)
                }
                .padding(.top, 8)
                .padding(.trailing, 10)
                
                // Title
                Text("Welcome to Easy Wake!")
                    .font(.title)
                    .bold()
                
                // Username Field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Username").bold()
                    TextField("Enter Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 400)
                }
                
                // Password Field with eye toggle
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password").bold()
                    RevealableSecureField(title: "Enter Password", text: $password)
                }

                // Remember Me & Forgot
                HStack {
                    Button(action: {
                        rememberMe.toggle()
                        UserDefaults.standard.set(rememberMe, forKey: "rememberMe")
                        if rememberMe {
                            UserDefaults.standard.set(username, forKey: "savedUsername")
                            UserDefaults.standard.set(password, forKey: "savedPassword")
                        } else {
                            UserDefaults.standard.removeObject(forKey: "savedUsername")
                            UserDefaults.standard.removeObject(forKey: "savedPassword")
                        }
                    }) {
                        Image(systemName: rememberMe ? "checkmark.square" : "square")
                            .foregroundColor(.customBlue)
                        Text("Remember Me")
                    }

                    Spacer()

                    Button("Forgot Password?") {
                        navigateToForgotPwd = true
                    }
                    .font(.footnote)
                    .foregroundColor(.customBlue)
                }
                .frame(maxWidth: 400)

                // Sign In Button
                Spacer().frame(height: 12)
                Button {
                    errorMessage = ""
                    guard validateInputs() else { return }
                    Task { await loginUser() }
                } label: {
                    Text("Sign In")
                        .fontWeight(.semibold)
                        .foregroundStyle(isFormValid ? .white : .customBlue)
                        .frame(width: 280)
                }
                .buttonStyle(PillButtonStyle(fill: isFormValid ? Color.customBlue : Color.white, border: isFormValid ? .white : .customBlue))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .disabled(!isFormValid || isLoading)
                
                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                // OR + Social / navigation
                OrDivider()

                // Social buttons
                VStack(spacing: 12) {
                    SocialButton(type: .google,
                                 title: "Continue with Google") {
                        // TODO: Google sign-in
                    }
                    .disabled(isLoading)
                    .frame(maxWidth: 320)
                    
                    Spacer().frame(height: 4)

                    SocialButton(type: .apple,
                                 title: "Continue with Apple") {
                        // TODO: Apple sign-in
                    }
                    .disabled(isLoading)
                    .frame(maxWidth: 320)
                }
                
                // Loading Overlay
                if isLoading {
                  VStack {
                    ProgressView()
                      .progressViewStyle(.circular)
                      .scaleEffect(1.5)      // make it “large”
                      .frame(width: 50, height: 50)
                      .background(.ultraThinMaterial)
                      .cornerRadius(10)
                  }
                  .transition(.opacity)
                }
            }
            .padding()
        }
        // Routing
        .navigationDestination(isPresented: $navigateToSignUp) {
            RegistrationView()
        }
        .navigationDestination(isPresented: $navigateToForgotPwd) {
            ForgotPasswordView()
        }
    }
    
    // MARK: - Validation
    private func validateInputs() -> Bool {
        guard !username.isEmpty, password.count >= 8 else {
            errorMessage = "Please enter a valid username and/or password"
            return false
        }
        return true
    }
    
    private var isFormValid: Bool {
        !username.isEmpty && password.count >= 8
    }
    
    // MARK: - SHA-256 Hashing
    private func hashPassword(_ plain: String) -> String {
        let data = Data(plain.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Network Login
    private func loginUser() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: lambdaURL) else {
            errorMessage = "Invalid server URL"
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "userId": username,
            "operation": "login",
            "password": hashPassword(password)
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
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
                // Extract firstName/lastName from response
                if let fn = json?["firstName"] as? String {
                    savedFirstName = fn
                }
                if let ln = json?["lastName"] as? String {
                    savedLastName = ln
                }
                
                // Persist username / password
                savedUsername = username
                savedPassword = password
                UserDefaults.standard.set(rememberMe, forKey: "rememberMe")
                if rememberMe {
                    UserDefaults.standard.set(username, forKey: "savedUsername")
                    UserDefaults.standard.set(password, forKey: "savedPassword")
                }
                let pwdData = Data(password.utf8)
                KeychainHelper.standard.save(pwdData,
                    service: "com.irohtechnologies.EasyWake",
                    account: username)

                // Mark onboarding complete and login with session
                didCompleteOnboarding = true
                await session.login(user: username, password: password)
                
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
    NavigationStack
    {
        LoginView().environmentObject(SessionManager())
    }
}
