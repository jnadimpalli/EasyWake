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

                Spacer()

                // MARK: Navigation Buttons
                GeometryReader { geometry in
                    VStack(spacing: 16) {
                        // Get Started Button
                        Button("Get Started") {
                            navigateToRegistration = true
                        }
                        .frame(width: geometry.size.width * 0.6)
                        .padding()
                        .background(Color.blue)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .buttonStyle(PlainButtonStyle())

                        // Login Button
                        Button("Login") {
                            navigateToLogin = true
                        }
                        .frame(width: geometry.size.width * 0.6)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .foregroundColor(.blue)
                        .buttonStyle(PlainButtonStyle())
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

