//
//  ForgotPasswordView.swift
//  EZ Wake
//
//  Created by Prafulla Bhupathi Raju on 6/25/25.
//

import SwiftUI
import MessageUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Forgot Password")
                .font(.title)
                .bold()

            VStack(alignment: .leading, spacing: 12) {
                Text("Email").bold()
                TextField("Enter your email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 400)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Send Reset Link") {
                // Simulate sending email
                showAlert = true
            }
            .frame(maxWidth: 300)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)

            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Password Reset Sent"),
                message: Text("Hi! Just a test from EZ Wake :)"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    ForgotPasswordView()
}
