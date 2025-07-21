// EasyWakeApp.swift - Fixed Version

import SwiftUI
import UserNotifications
import Combine

@MainActor
class AppEnvironment: ObservableObject {
    @Published var alarmStore = AlarmStore()
    @Published var weatherViewModel = WeatherViewModel()
    @Published var profileViewModel = ProfileViewModel()
    @Published var premiumManager = PremiumManager()
    @Published var dataCoordinator: DataCoordinator!
    @Published var weatherAlarmService: WeatherAlarmService!
    
    private var cancellables = Set<AnyCancellable>()
    
    func setupAlarmDeletionObserver() {
        // Listen for alarm deletions and coordinate cleanup
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AlarmDeleted"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard
                let self = self,
                let alarm = note.object as? Alarm
            else { return }
            
            Task { @MainActor in
                print("[APP-ENV] Handling deletion for alarm: \(alarm.name)")
            }
        }
    }
    
    init() {
        // Initialize DataCoordinator first
        self.dataCoordinator = DataCoordinator(
            alarmStore: alarmStore,
            profileViewModel: profileViewModel
        )
        
        // Then initialize WeatherAlarmService
        self.weatherAlarmService = WeatherAlarmService(
            alarmStore: alarmStore,
            dataCoordinator: dataCoordinator,
            profileViewModel: profileViewModel
        )
        
        self.dataCoordinator.setWeatherAlarmService(weatherAlarmService)
        
        //setupInterComponentCommunication()
        setupAlarmDeletionObserver()
    }
    
//    private func setupInterComponentCommunication() {
//       // Track alarm count to detect deletions
//       var previousAlarmCount = alarmStore.alarms.count
//       
//       alarmStore.$alarms
//           .removeDuplicates() // Better than debounce for this use case
//           .sink { [weak self] alarms in
//               guard let self = self else { return }
//               
//               let currentCount = alarms.count
//               
//               // Skip refresh if alarms were deleted
//               if currentCount < previousAlarmCount {
//                   print("[APP-ENV] Alarms deleted, skipping weather refresh")
//                   previousAlarmCount = currentCount
//                   return
//               }
//               
//               previousAlarmCount = currentCount
//               
//               // Only refresh if we have alarms
//               if !alarms.isEmpty {
//                   Task { @MainActor in
//                       await self.weatherAlarmService.refreshAllAdjustments()
//                   }
//               }
//           }
//           .store(in: &cancellables)
//   }
}

@main
struct EasyWakeApp: App {
    @StateObject private var appEnvironment = AppEnvironment()
    @StateObject private var session = SessionManager()
    
    var body: some Scene {
        WindowGroup {
            AppWithBanner {
                RootView()
                    .environmentObject(session)
                    .environmentObject(appEnvironment.alarmStore)
                    .environmentObject(appEnvironment.weatherViewModel)
                    .environmentObject(appEnvironment.profileViewModel)
                    .environmentObject(appEnvironment.premiumManager)
                    .environmentObject(appEnvironment.weatherAlarmService)
                    .environmentObject(appEnvironment.dataCoordinator)
            }
            .onAppear {
                setupNotifications()
            }
        }
    }
    
    private func setupNotifications() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        
        // Setup notification categories
        setupNotificationCategories()
    }
    
    private func setupNotificationCategories() {
        let viewAlarmAction = UNNotificationAction(
            identifier: "VIEW_ALARM",
            title: "View Alarm",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ADJUSTMENT",
            title: "Dismiss",
            options: []
        )
        
        let weatherAlarmCategory = UNNotificationCategory(
            identifier: "WEATHER_ALARM_ADJUSTMENT",
            actions: [viewAlarmAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([weatherAlarmCategory])
    }
}
