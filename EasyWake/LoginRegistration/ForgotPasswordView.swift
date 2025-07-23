//
//  ForgotPasswordView.swift
//  Easy Wake
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
            
            Spacer().frame(height: 4)
            
            Button {
                // Simulate sending email
                showAlert = true
            } label: {
                Text("Reset Password")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)   // optional: full-width pill
            }
            .buttonStyle(PillButtonStyle(fill: .customBlue))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Password Reset Sent"),
                message: Text("Hi! Just a test from Easy Wake :)"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    ForgotPasswordView()
}
