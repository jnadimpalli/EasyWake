// GetStartedView.swift

import SwiftUI

// 👇 This is required before using Feature inside GetStartedView
struct Feature: Identifiable {
    let id = UUID()
    let imageName: String
    let description: String
}

struct GetStartedView: View {
    // State to control navigation
    @State private var navigateToRegistration = false
    @State private var navigateToLogin = false

    let features = [
        Feature(imageName: "feature1", description: "Get up on time with weather and traffic alerts."),
        Feature(imageName: "feature2", description: "Smart navigation to your destination."),
        Feature(imageName: "feature3", description: "Plan your day effortlessly.")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // MARK: Feature Carousel
                TabView {
                    ForEach(features) { feature in
                        VStack {
                            Spacer()
                            Image(feature.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 500) // Increase this to make the image larger
                                .frame(maxWidth: .infinity)
                            Spacer()
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .frame(height: 400)

                Spacer().frame(height: 32)

                // MARK: Navigation Buttons
                GeometryReader { geometry in
                    VStack(spacing: 16) {
                        // Get Started Button
                        Button {
                            navigateToRegistration = true
                        } label: {
                            Text("Get Started")
                                .fontWeight(.semibold)
                                .frame(width: geometry.size.width * 0.6)
                        }
                        .buttonStyle(PillButtonStyle(fill: .customBlue))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

                        // Login Button
                        Button {
                            navigateToLogin = true
                        } label: {
                            Text("Login")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.customBlue)
                                .frame(width: geometry.size.width * 0.6)
                        }
                        .buttonStyle(PillButtonStyle(fill: .white, border: .customBlue))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    .frame(width: geometry.size.width)
                }
                .frame(height: 150)
                .padding(.bottom, 15)
            }
            .padding(.top, 60)
            .navigationDestination(isPresented: $navigateToRegistration) {
                RegistrationView()
            }
            .navigationDestination(isPresented: $navigateToLogin) {
                LoginView()
            }
        }
    }
}

#Preview {
    GetStartedView()
}

