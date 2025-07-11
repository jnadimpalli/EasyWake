import SwiftUI
import CryptoKit   // for SHA-256
import UIKit

/// A thin SwiftUI wrapper around UIActivityIndicatorView
struct ActivityIndicator: UIViewRepresentable {
    let style: UIActivityIndicatorView.Style
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let spinner = UIActivityIndicatorView(style: style)
        spinner.startAnimating()
        return spinner
    }
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) { }
}

struct LoginView: View {
    // MARK: –– Form state
    @EnvironmentObject var session: SessionManager
    @State private var username            = UserDefaults.standard.string(forKey: "savedUsername") ?? ""
    @State private var password            = UserDefaults.standard.string(forKey: "savedPassword") ?? ""
    @State private var rememberMe          = UserDefaults.standard.bool(forKey: "rememberMe")
    @State private var showPassword        = false
    @State private var errorMessage        = ""
    
    // MARK: –– Navigation
    @State private var navigateToSignUp    = false
    @State private var navigateToForgotPwd = false
    @State private var navigateToAlarmList = false
    
    // MARK: –– Loading state
    @State private var isLoading = false
    
    // MARK: –– Persisted flags
    @AppStorage("didCompleteOnboarding")   private var didCompleteOnboarding = false
    @AppStorage("savedUsername")           private var savedUsername         = ""
    @AppStorage("savedPassword")           private var savedPassword         = ""
    @AppStorage("savedFirstName")          private var savedFirstName        = ""
    @AppStorage("savedLastName")           private var savedLastName         = ""
    
    // MARK: –– Same endpoint as Registration
    private let lambdaURL = "https://6qvleq3o26pgdp7jmr4aachf5y0qbkfi.lambda-url.us-east-1.on.aws/"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top “Sign Up” prompt
                HStack {
                    Spacer()
                    Text("Don't have an account?")
                        .font(.footnote)
                    Button("Sign Up") {
                        navigateToSignUp = true
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                }
                .padding(.top, 8)
                .padding(.trailing, 10)
                
                // Title
                Text("Welcome to EZ Wake!")
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
                    HStack {
                        Group {
                            if showPassword {
                                TextField("Enter Password", text: $password)
                            } else {
                                SecureField("Enter Password", text: $password)
                            }
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 360)
                        
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }
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
                            .foregroundColor(.blue)
                        Text("Remember Me")
                    }

                    Spacer()

                    Button("Forgot Password?") {
                        navigateToForgotPwd = true
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: 400)

                // Sign In Button
                Button(action: {
                    errorMessage = ""
                    guard validateInputs() else { return }
                    Task { await loginUser() }
                }) {
                    Text("Sign In")
                        .frame(width: 300)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.white)
                        .foregroundColor(isFormValid ? .white : .blue)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: isFormValid ? 0 : 2)
                        )
                        .cornerRadius(10)
                }
                .disabled(!isFormValid || isLoading)
                .frame(width: 300)
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 10)
                
                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                // OR + Social / navigation
                Text("Or")
                    .font(.subheadline)
                Button("Sign In with Google") { /*…*/ }
                    .frame(width: 300).padding().background(Color.red).foregroundColor(.white).cornerRadius(10)
                    .disabled(isLoading)
                Button("Sign In with Apple") { /*…*/ }
                    .frame(width: 300).padding().background(Color.black).foregroundColor(.white).cornerRadius(10)
                    .disabled(isLoading)
                
                // ── Loading Overlay ─────────────────────────
                if isLoading {
                    VStack {
                        ActivityIndicator(style: .large)
                            .frame(width: 50, height: 50)
                            .background(Color(.systemBackground).opacity(0.8))
                            .cornerRadius(10)
                    }
                    .transition(.opacity)
                }
            }
            .padding()
        }
        // Routing
        .navigationDestination(isPresented: $navigateToAlarmList) {
            AlarmListView().environmentObject(session)
        }
        .navigationDestination(isPresented: $navigateToSignUp) {
            RegistrationView().environmentObject(session)
        }
        .navigationDestination(isPresented: $navigateToForgotPwd) {
            ForgotPasswordView().environmentObject(session)
        }
    }
    
    // MARK: –– Validation
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
    
    // MARK: –– SHA-256 Hashing (identical to RegistrationView)
    private func hashPassword(_ plain: String) -> String {
        let data   = Data(plain.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: –– Network Login
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
            "userId":    username,
            "operation": "login",
            "password":  hashPassword(password)
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
                // 1) Extract firstName/lastName from response
                if let fn = json?["firstName"] as? String {
                    savedFirstName = fn
                }
                if let ln = json?["lastName"] as? String {
                    savedLastName = ln
                }
                // 2) Persist username / password
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

                // 3) Mark onboarding complete
                didCompleteOnboarding = true

                // 4) Flip the session into “logged in”
                await MainActor.run {
                    session.currentUser     = username
                    session.currentPassword = password
                }
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
