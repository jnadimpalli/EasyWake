//
//  EasyWakeApp.swift
//  EasyWake
//
//  Created by Jitesh Nadimpalli on 7/9/25.
//

import SwiftUI

@MainActor
class AppEnvironment: ObservableObject {
    @Published var alarmStore = AlarmStore()
    @Published var weatherViewModel = WeatherViewModel()
    
    init() {
        // Any app-wide initialization can go here
    }
}

// Update your App file:
@main
struct EasyWakeApp: App {
    @StateObject private var appEnvironment = AppEnvironment()
    @StateObject private var session = SessionManager()
    
    var body: some Scene {
        WindowGroup {
            AppWithBanner {
                Group {
                  if session.isLoggedIn {
                    // main flow (tabs + bottom bar)
                    RootView()
                      .environmentObject(session)
                  } else {
                    // onboarding flow (no bottom bar)
                    NavigationStack {
                      RegistrationView()
                        .environmentObject(session)
                    }
                  }
                }
              }
              .environmentObject(appEnvironment.alarmStore)
              .environmentObject(appEnvironment.weatherViewModel)
        }
    }
}
