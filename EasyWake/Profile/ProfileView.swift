import SwiftUI

struct ProfileView: View {
    @State private var name: String = "User's Name"
    @State private var email: String = "user@example.com"
    @State private var pushNotificationsEnabled = true
    @State private var softwareVersion = "Version 1.0"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scrollable Form content
                Form {
                    // Name Section
                    Section {
                        HStack {
                            TextField("Name", text: $name)
                            Spacer()
                            Image(systemName: "pencil")
                        }
                    }

                    // Email Section
                    Section {
                        HStack {
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                            Spacer()
                            Image(systemName: "pencil")
                        }
                    }

                    // Change Password
                    Section {
                        NavigationLink("Change Password") {
                            ChangePasswordView()
                        }
                    }

                    // Push Notifications
                    Section {
                        Toggle(isOn: $pushNotificationsEnabled) {
                            Text("Allow push notifications")
                        }
                    }

                    // Software Version
                    Section {
                        HStack {
                            Text("Software Version:")
                            Spacer()
                            Text(softwareVersion)
                                .foregroundColor(.gray)
                        }
                    }

                    // Legal
                    Section {
                        NavigationLink("Software License Agreement") {
                            Text("Software License Agreement Placeholder")
                        }

                        NavigationLink("Terms of Service") {
                            Text("Terms of Service Placeholder")
                        }
                    }
                }
            }
            .navigationTitle("User Profile")
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    ProfileView()
}//
//  ProfileView.swift
//  EZ Wake
//
//  Created by Prafulla Bhupathi Raju on 6/26/25.
//

