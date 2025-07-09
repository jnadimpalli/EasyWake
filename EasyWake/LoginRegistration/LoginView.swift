import SwiftUI

struct LoginView: View {
    @State private var username = UserDefaults.standard.string(forKey: "savedUsername") ?? ""
        @State private var password = UserDefaults.standard.string(forKey: "savedPassword") ?? ""
        @State private var rememberMe = UserDefaults.standard.bool(forKey: "rememberMe")
    
    @State private var errorMessage = ""
    @State private var navigateToSignUp = false
    @State private var navigateToForgotPassword = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @AppStorage("savedUsername")     private var savedUsername = ""
    @AppStorage("savedPassword")     private var savedPassword = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Top Sign Up prompt
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
                
                // Form
                VStack(alignment: .leading, spacing: 12) {
                    Text("Username").bold()
                    TextField("Enter Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 400)

                    Text("Password").bold()
                    SecureField("Enter Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 400)
                    Spacer()
                    
                    HStack {
                        // Remember Me checkbox
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
                            }

                            Text("Remember Me")
                        }

                        Spacer()

                        // Forgot Password
                        Button("Forgot Password?") {
                            navigateToForgotPassword = true
                        }
                        .font(.footnote)
                        .foregroundColor(.blue)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Sign In Button
                Button(action: {
                    if rememberMe {
                        UserDefaults.standard.set(username, forKey: "savedUsername")
                        UserDefaults.standard.set(password, forKey: "savedPassword")
                    }
                    savedUsername = username
                    savedPassword = password
                    didCompleteOnboarding = true
                }) {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.white)
                        .foregroundColor(isFormValid ? .white : .blue)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: isFormValid ? 0 : 2)
                        )
                        .cornerRadius(10)
                }
                .disabled(!isFormValid)
                .frame(maxWidth: 300)
                .buttonStyle(PlainButtonStyle())
                
                // OR
                Text("Or")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                // Social buttons
                // Google Button
                Button(action: {
                    // TODO: Google sign-in
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Sign In with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: 300)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                // Apple Button
                Button(action: {
                    // TODO: Apple sign-in
                }) {
                    HStack {
                        Image(systemName: "applelogo")
                        Text("Sign In with Apple")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: 300)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .navigationDestination(isPresented: $navigateToSignUp) {
                            RegistrationView()
                        }
        .navigationDestination(isPresented: $navigateToForgotPassword) {
                    ForgotPasswordView()
                }
    }
    func NavigationView() {
        LoginView()
            .navigationTitle("")
            .navigationBarHidden(true)
    }

    private func validateInputs() -> Bool {
        if username.isEmpty || password.count < 8 {
            errorMessage = "Please enter a valid username and/or password"
            return false
        }
        errorMessage = ""
        return true
    }
    
    private var isFormValid: Bool {
        return !username.isEmpty && password.count >= 8
    }
}
#Preview {
    NavigationStack {
        LoginView()
    }
}//
//  LoginView.swift
//  EZ Wake
//
//  Created by Prafulla Bhupathi Raju on 6/24/25.
//

