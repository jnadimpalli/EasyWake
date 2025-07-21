// RootView.swift - Fixed App Flow

import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionManager
    @State private var showSplash = true
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @AppStorage("hasCompletedInitialFlow") private var hasCompletedInitialFlow = false

    var body: some View {
        Group {
            if showSplash {
                SplashScreenView()
            } else if !hasCompletedInitialFlow {
                // First time opening app - show get started flow
                GetStartedView()
            } else if session.isLoggedIn && !didCompleteOnboarding {
                // Logged in but needs onboarding
                UserSettingsView(origin: .onboarding)
            } else if session.isAuthenticated {
                // Either logged in and onboarded, or skipped login
                MainContainerView()
            } else {
                // Something went wrong, show get started again
                GetStartedView()
            }
        }
        .onAppear {
            // Show splash for 2.5 seconds at app launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(SessionManager())
}
