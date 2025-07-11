// MainContainerView.swift

import SwiftUI

struct MainContainerView: View {
  enum Tab { case profile, weather, alarms, calendar }
  @State private var selection: Tab = .alarms

  var body: some View {
    ZStack {
      // MARK: Content
      Group {
        switch selection {
          case .profile: ProfileView()
          case .weather: WeatherView()
          case .alarms: AlarmListView()
          case .calendar: CalendarSyncView()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      // MARK: Custom Bottom Bar
      VStack {
          Spacer()
          BottomNavBar(selection: $selection)
      }
    }
    .ignoresSafeArea(edges: .bottom) // so the bar can go fully to the screen edge
  }
}

#Preview {
  MainContainerView()
}
