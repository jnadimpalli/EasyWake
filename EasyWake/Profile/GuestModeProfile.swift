// GuestModeProfileContent - Fixed Navigation
import SwiftUI
import CryptoKit

struct GuestModeProfileContent: View {
    @EnvironmentObject var session: SessionManager
    @State private var showLoginSheet = false
    @State private var showRegisterSheet = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "person.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            // Title
            Text("Profile Locked")
                .font(.title)
                .fontWeight(.bold)
            
            // Description
            Text("You are currently using EZ Wake as a guest. Login or create an account to access your profile, save addresses, sync settings, and unlock premium features.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            // Buttons
            VStack(spacing: 16) {
                Button(action: {
                    print("🔵 Login button tapped")
                    showLoginSheet = true
                }) {
                    Text("Login to Existing Account")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                
                Button(action: {
                    print("🟢 Register button tapped")
                    showRegisterSheet = true
                }) {
                    Text("Create New Account")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 96)
        }
        // FIXED: Use fullScreenCover instead of navigationDestination
        .fullScreenCover(isPresented: $showLoginSheet) {
            NavigationStack {
                LoginViewFromProfile()
                    .environmentObject(session)
            }
        }
        .fullScreenCover(isPresented: $showRegisterSheet) {
            NavigationStack {
                RegistrationViewFromProfile()
                    .environmentObject(session)
            }
        }
        .onAppear {
            print("🎯 GuestModeProfileContent appeared")
            print("🎯 Session isLoggedIn: \(session.isLoggedIn)")
            print("🎯 Session hasSkippedLogin: \(session.hasSkippedLogin)")
        }
    }
}

// MARK: - Login View From Profile (Modified for proper dismissal)
struct LoginViewFromProfile: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) private var dismiss
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
                
                // Loading Overlay
                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                            .frame(width: 50, height: 50)
                            .background(Color(.systemBackground).opacity(0.8))
                            .cornerRadius(10)
                    }
                    .transition(.opacity)
                }
            }
            .padding()
        }
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $navigateToSignUp) {
            NavigationStack {
                RegistrationViewFromProfile()
                    .environmentObject(session)
            }
        }
        .fullScreenCover(isPresented: $navigateToForgotPwd) {
            NavigationStack {
                ForgotPasswordView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                navigateToForgotPwd = false
                            }
                        }
                    }
            }
        }
        // CRITICAL: Watch for login success and dismiss
        .onChange(of: session.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                print("🎉 Login successful, dismissing sheet")
                dismiss()
            }
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
                print("🎉 Login complete, session updated")
                
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

// MARK: - Registration View From Profile (Modified for proper dismissal)
struct RegistrationViewFromProfile: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var showSkipWarning = false
    @State private var isLoading = false
    
    @State private var navigateToLogin = false
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
                    .foregroundColor(.blue)
                }
                .padding(.top, 8)
                .padding(.trailing, 10)

                // MARK: Title
                Text("Welcome to Easy Wake!")
                    .font(.title).bold()
                Text("Create your account to unlock all features").font(.subheadline)

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

                Text("By continuing, you agree to our Terms & Conditions")
                    .font(.footnote)
                    .padding(.top, 8)

                // MARK: Continue Button
                HStack {
                    Spacer()
                    Button("Create Account") {
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
                    .disabled(!isFormValid || isLoading)
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
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Loading Overlay
                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                            .frame(width: 50, height: 50)
                            .background(Color(.systemBackground).opacity(0.8))
                            .cornerRadius(10)
                    }
                    .transition(.opacity)
                }
            }
            .padding()
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $navigateToLogin) {
            NavigationStack {
                LoginViewFromProfile()
                    .environmentObject(session)
            }
        }
        // CRITICAL: Watch for login success and dismiss
        .onChange(of: session.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                print("🎉 Registration successful, dismissing sheet")
                dismiss()
            }
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
        isLoading = true
        defer { isLoading = false }
        
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
                
                didCompleteOnboarding = true
                await session.completeRegistration(user: email, password: password)
                print("🎉 Registration complete, session updated")
                
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
