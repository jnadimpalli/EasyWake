import SwiftUI

struct UserProfileView: View {
    @State private var name: String = "User's Name"
    @State private var email: String = "User's Email"
    @State private var pushNotificationsEnabled: Bool = true
    @State private var softwareVersion: String = "Version 1.0"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Text("User Profile")
                        .font(.title)
                        .bold()
                        .padding(.top, 16)

                    Divider()

                    // Name
                    HStack {
                        Text("Name:")
                            .bold()
                        TextField("User's Name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Image(systemName: "pencil")
                            .foregroundColor(.gray)
                    }

                    // Email
                    HStack {
                        Text("Email:")
                            .bold()
                        TextField("User's Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    // Change Password
                    NavigationLink(destination: ChangePasswordView()) {
                        Text("Change Password")
                            .underline()
                            .fontWeight(.medium)
                    }

                    Divider()

                    // Push Notifications
                    HStack {
                        Text("Allow push notifications")
                            .bold()
                        Spacer()
                        Toggle("", isOn: $pushNotificationsEnabled)
                            .labelsHidden()
                    }

                    Divider()

                    // Software Version
                    HStack {
                        Text("Software Version:")
                            .bold()
                        Spacer()
                        Text(softwareVersion)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }

                    Spacer(minLength: 40)

                    // Footer Links
                    VStack(spacing: 8) {
                        Button("Software License Agreement") {
                            // Handle link
                        }
                        .underline()

                        Button("Terms of Service") {
                            // Handle link
                        }
                        .underline()
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    UserProfileView()
}
//
//  UserProfileView.swift
//  EZ Wake
//
//  Created by Prafulla Bhupathi Raju on 6/26/25.
//

