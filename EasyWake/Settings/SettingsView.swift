import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(destination: ProfileView()) {
                    Label("User Profile", systemImage: "person.circle")
                }

                NavigationLink(destination: AlarmSettingView()) {
                    Label("Alarms", systemImage: "alarm")
                }

                NavigationLink(destination: WeatherSettingView()) {
                    Label("Weather", systemImage: "cloud.sun")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}//
//  SettingsView.swift
//  EZ Wake
//
//  Created by Prafulla Bhupathi Raju on 6/26/25.
//

