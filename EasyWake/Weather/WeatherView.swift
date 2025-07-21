// WeatherView.swift - Updated with Both Features

import SwiftUI
import WeatherKit

struct WeatherView: View {
    @StateObject private var viewModel = WeatherViewModel()
    @StateObject private var routeAnalysisService: RouteAnalysisService
    @EnvironmentObject var weatherAlarmService: WeatherAlarmService
    @EnvironmentObject var alarmStore: AlarmStore
    @State private var navigateToSettings = false
    @Environment(\.colorScheme) private var colorScheme
    
    // Initialize with alarm store dependency
    init() {
        // We'll need to get this from environment, but for now create a placeholder
        let alarmStore = AlarmStore()
        self._routeAnalysisService = StateObject(wrappedValue: RouteAnalysisService(alarmStore: alarmStore))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic background gradient
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar
                    topBar
                        .background(Color.clear)
                        .zIndex(1)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            if viewModel.isLoading {
                                loadingView
                            } else {
                                // Current Weather
                                if viewModel.currentWeather != nil {
                                    currentWeatherView
                                }
                                
                                // Context-Aware Weather Alarm Container (Feature 2)
                                ContextAwareWeatherAlarmContainer(
                                    weatherAlarmService: weatherAlarmService,
                                    routeAnalysisService: routeAnalysisService,
                                    weatherViewModel: viewModel
                                )
                                
                                // Weather Alerts
                                WeatherAlertsContainer(alertManager: viewModel.alertManager)
                                    .transition(.scale.combined(with: .opacity))
                                
                                // Hourly Forecast
                                if !viewModel.hourlyForecast.isEmpty {
                                    hourlyForecastView
                                }
                                
                                // Daily Forecast
                                if !viewModel.dailyForecast.isEmpty {
                                    dailyForecastView
                                }
                            }
                        }
                        .padding(.bottom, 120) // Extra space for tab bar
                    }
                }
                .refreshable {
                    await viewModel.refreshWeatherData()
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToSettings) {
                WeatherSettingView()
            }
            .alert("Weather Error", isPresented: $viewModel.showError) {
                Button("Retry") {
                    Task {
                        await viewModel.refreshWeatherData()
                    }
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
            .sheet(isPresented: $viewModel.showLocationPicker) {
                // Enhanced Location Picker (Feature 1)
                LocationPickerView(viewModel: viewModel)
                    .presentationDetents([.large])
            }
        }
        .task {
            await viewModel.refreshWeatherData()
        }
        .onAppear {
            // Update route analysis service with the actual alarm store
            updateRouteAnalysisService()
            
            // Trigger Lambda calculation when weather view appears
//            Task {
//                print("[WEATHER-VIEW] View appeared, triggering Lambda calculation")
//                await weatherAlarmService.calculateWeatherAdjustmentsWithLambda()
//            }
        }
    }
    
    private func updateRouteAnalysisService() {
        // This is a workaround - ideally we'd inject this properly
        if routeAnalysisService.alarmStore !== alarmStore {
            routeAnalysisService.clearAnalysis()
        }
    }
    
    // MARK: - Dynamic Background
    private var backgroundGradient: LinearGradient {
        if let currentWeather = viewModel.currentWeather {
            return createWeatherBackground(weather: currentWeather)
        }
        
        return LinearGradient(
            colors: defaultBackgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func createWeatherBackground(weather: CurrentWeather) -> LinearGradient {
        let isNight = !isDaytime()
        let condition = weather.condition
        
        var colors: [Color] = []
        
        if isNight {
            switch condition {
            case .clear:
                colors = [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.0, green: 0.0, blue: 0.1)]
            case .partlyCloudy:
                colors = [Color(red: 0.08, green: 0.08, blue: 0.18), Color(red: 0.03, green: 0.03, blue: 0.12)]
            case .cloudy, .mostlyCloudy:
                colors = [Color(red: 0.12, green: 0.12, blue: 0.22), Color(red: 0.06, green: 0.06, blue: 0.16)]
            case .rain, .drizzle:
                colors = [Color(red: 0.08, green: 0.12, blue: 0.20), Color(red: 0.05, green: 0.08, blue: 0.15)]
            default:
                colors = [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.0, green: 0.0, blue: 0.1)]
            }
        } else {
            switch condition {
            case .clear:
                colors = [Color(red: 0.2, green: 0.4, blue: 0.7), Color(red: 0.3, green: 0.5, blue: 0.8)]
            case .partlyCloudy:
                colors = [Color(red: 0.3, green: 0.4, blue: 0.6), Color(red: 0.4, green: 0.5, blue: 0.7)]
            case .cloudy, .mostlyCloudy:
                colors = [Color(red: 0.35, green: 0.35, blue: 0.45), Color(red: 0.25, green: 0.25, blue: 0.35)]
            case .rain, .drizzle:
                colors = [Color(red: 0.2, green: 0.3, blue: 0.4), Color(red: 0.15, green: 0.25, blue: 0.35)]
            case .snow:
                colors = [Color(red: 0.4, green: 0.45, blue: 0.55), Color(red: 0.3, green: 0.35, blue: 0.45)]
            case .heavyRain, .strongStorms:
                colors = [Color(red: 0.15, green: 0.2, blue: 0.3), Color(red: 0.1, green: 0.15, blue: 0.25)]
            default:
                colors = [Color(red: 0.2, green: 0.4, blue: 0.7), Color(red: 0.3, green: 0.5, blue: 0.8)]
            }
        }
        
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private func isDaytime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 6 && hour < 20
    }
    
    private var defaultBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.05, green: 0.1, blue: 0.2), Color(red: 0.02, green: 0.05, blue: 0.1)]
        } else {
            return [Color(red: 0.2, green: 0.4, blue: 0.7), Color(red: 0.3, green: 0.5, blue: 0.8)]
        }
    }
    
    // MARK: - View Components
    private var topBar: some View {
        HStack {
            Text("Weather")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            Button {
                navigateToSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading weather...")
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var currentWeatherView: some View {
        VStack(spacing: 12) {
            // Location with enhanced search
            Button {
                viewModel.showLocationPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.callout)
                    Text(viewModel.currentLocation)
                        .font(.title2)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.white)
            }
            .accessibilityLabel("Current location: \(viewModel.currentLocation)")
            .accessibilityHint("Tap to search for a different location")
            
            if let current = viewModel.currentWeather {
                // Temperature
                let temp = viewModel.useCelsius ?
                    current.temperature.converted(to: .celsius).value :
                    current.temperature.converted(to: .fahrenheit).value
                
                Text("\(Int(temp))°")
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundColor(.white)
                
                // Feels like temperature
                let feelsLikeTemp = viewModel.useCelsius ?
                    current.apparentTemperature.converted(to: .celsius).value :
                    current.apparentTemperature.converted(to: .fahrenheit).value
                
                Text("Feels like \(Int(feelsLikeTemp))°")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                
                // Weather icon and condition
                VStack(spacing: 8) {
                    Image(systemName: current.symbolName)
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.multicolor)
                    
                    Text(current.condition.description)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.95))
                }
            }
        }
        .padding(.vertical, 20)
    }
    
    private var hourlyForecastView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hourly Forecast")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.hourlyForecast, id: \.date) { hour in
                        HourlyWeatherCard(hour: hour, useCelsius: viewModel.useCelsius)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var globalLow: Double {
        let lows = viewModel.dailyForecast.map {
            viewModel.useCelsius
            ? $0.lowTemperature.converted(to: .celsius).value
            : $0.lowTemperature.converted(to: .fahrenheit).value
        }
        return lows.min() ?? 0
    }

    private var globalHigh: Double {
        let highs = viewModel.dailyForecast.map {
            viewModel.useCelsius
            ? $0.highTemperature.converted(to: .celsius).value
            : $0.highTemperature.converted(to: .fahrenheit).value
        }
        return highs.max() ?? 1
    }

    private var globalRange: Double {
        max(globalHigh - globalLow, 1)
    }
    
    private var dailyForecastView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("7-Day Forecast")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            VStack(spacing: 8) {
                ForEach(viewModel.dailyForecast, id: \.date) { day in
                    DailyWeatherRow(
                        day: day,
                        useCelsius: viewModel.useCelsius,
                        globalLow: globalLow,
                        globalRange: globalRange
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Enhanced WeatherView with Proper Dependencies
struct EnhancedWeatherView: View {
    @EnvironmentObject var weatherAlarmService: WeatherAlarmService
    @EnvironmentObject var alarmStore: AlarmStore
    
    var body: some View {
        WeatherViewWithDependencies(
            weatherAlarmService: weatherAlarmService,
            alarmStore: alarmStore
        )
    }
}

// MARK: - Weather View with Proper Dependency Injection
struct WeatherViewWithDependencies: View {
    @StateObject private var viewModel = WeatherViewModel()
    @StateObject private var routeAnalysisService: RouteAnalysisService
    @ObservedObject var weatherAlarmService: WeatherAlarmService
    @State private var navigateToSettings = false
    @Environment(\.colorScheme) private var colorScheme
    
    init(weatherAlarmService: WeatherAlarmService, alarmStore: AlarmStore) {
        self.weatherAlarmService = weatherAlarmService
        self._routeAnalysisService = StateObject(wrappedValue: RouteAnalysisService(alarmStore: alarmStore))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic background gradient
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar
                    topBar
                        .background(Color.clear)
                        .zIndex(1)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            if viewModel.isLoading {
                                loadingView
                            } else {
                                // Current Weather
                                if viewModel.currentWeather != nil {
                                    currentWeatherView
                                }
                                
                                // Context-Aware Weather Alarm Container (Feature 2)
                                ContextAwareWeatherAlarmContainer(
                                    weatherAlarmService: weatherAlarmService,
                                    routeAnalysisService: routeAnalysisService,
                                    weatherViewModel: viewModel
                                )
                                
                                // Weather Alerts
                                WeatherAlertsContainer(alertManager: viewModel.alertManager)
                                    .transition(.scale.combined(with: .opacity))
                                
                                // Hourly Forecast
                                if !viewModel.hourlyForecast.isEmpty {
                                    hourlyForecastView
                                }
                                
                                // Daily Forecast
                                if !viewModel.dailyForecast.isEmpty {
                                    dailyForecastView
                                }
                            }
                        }
                        .padding(.bottom, 120) // Extra space for tab bar
                    }
                }
                .refreshable {
                    await viewModel.refreshWeatherData()
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToSettings) {
                WeatherSettingView()
            }
            .alert("Weather Error", isPresented: $viewModel.showError) {
                Button("Retry") {
                    Task {
                        await viewModel.refreshWeatherData()
                    }
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
            .sheet(isPresented: $viewModel.showLocationPicker) {
                // Enhanced Location Picker (Feature 1)
                LocationPickerView(viewModel: viewModel)
                    .presentationDetents([.large])
            }
        }
        .task {
            await viewModel.refreshWeatherData()
        }
    }
    
    // MARK: - Copy all the other view components from above
    // (backgroundGradient, topBar, loadingView, etc. - same implementation)
    
    private var backgroundGradient: LinearGradient {
        if let currentWeather = viewModel.currentWeather {
            return createWeatherBackground(weather: currentWeather)
        }
        
        return LinearGradient(
            colors: defaultBackgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func createWeatherBackground(weather: CurrentWeather) -> LinearGradient {
        let isNight = !isDaytime()
        let condition = weather.condition
        
        var colors: [Color] = []
        
        if isNight {
            switch condition {
            case .clear:
                colors = [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.0, green: 0.0, blue: 0.1)]
            case .partlyCloudy:
                colors = [Color(red: 0.08, green: 0.08, blue: 0.18), Color(red: 0.03, green: 0.03, blue: 0.12)]
            case .cloudy, .mostlyCloudy:
                colors = [Color(red: 0.12, green: 0.12, blue: 0.22), Color(red: 0.06, green: 0.06, blue: 0.16)]
            case .rain, .drizzle:
                colors = [Color(red: 0.08, green: 0.12, blue: 0.20), Color(red: 0.05, green: 0.08, blue: 0.15)]
            default:
                colors = [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.0, green: 0.0, blue: 0.1)]
            }
        } else {
            switch condition {
            case .clear:
                colors = [Color(red: 0.2, green: 0.4, blue: 0.7), Color(red: 0.3, green: 0.5, blue: 0.8)]
            case .partlyCloudy:
                colors = [Color(red: 0.3, green: 0.4, blue: 0.6), Color(red: 0.4, green: 0.5, blue: 0.7)]
            case .cloudy, .mostlyCloudy:
                colors = [Color(red: 0.35, green: 0.35, blue: 0.45), Color(red: 0.25, green: 0.25, blue: 0.35)]
            case .rain, .drizzle:
                colors = [Color(red: 0.2, green: 0.3, blue: 0.4), Color(red: 0.15, green: 0.25, blue: 0.35)]
            case .snow:
                colors = [Color(red: 0.4, green: 0.45, blue: 0.55), Color(red: 0.3, green: 0.35, blue: 0.45)]
            case .heavyRain, .strongStorms:
                colors = [Color(red: 0.15, green: 0.2, blue: 0.3), Color(red: 0.1, green: 0.15, blue: 0.25)]
            default:
                colors = [Color(red: 0.2, green: 0.4, blue: 0.7), Color(red: 0.3, green: 0.5, blue: 0.8)]
            }
        }
        
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private func isDaytime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 6 && hour < 20
    }
    
    private var defaultBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.05, green: 0.1, blue: 0.2), Color(red: 0.02, green: 0.05, blue: 0.1)]
        } else {
            return [Color(red: 0.2, green: 0.4, blue: 0.7), Color(red: 0.3, green: 0.5, blue: 0.8)]
        }
    }
    
    private var topBar: some View {
        HStack {
            Text("Weather")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            Button {
                navigateToSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading weather...")
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var currentWeatherView: some View {
        VStack(spacing: 12) {
            // Location with enhanced search
            Button {
                viewModel.showLocationPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.callout)
                    Text(viewModel.currentLocation)
                        .font(.title2)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.white)
            }
            .accessibilityLabel("Current location: \(viewModel.currentLocation)")
            .accessibilityHint("Tap to search for a different location")
            
            if let current = viewModel.currentWeather {
                // Temperature
                let temp = viewModel.useCelsius ?
                    current.temperature.converted(to: .celsius).value :
                    current.temperature.converted(to: .fahrenheit).value
                
                Text("\(Int(temp))°")
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundColor(.white)
                
                // Feels like temperature
                let feelsLikeTemp = viewModel.useCelsius ?
                    current.apparentTemperature.converted(to: .celsius).value :
                    current.apparentTemperature.converted(to: .fahrenheit).value
                
                Text("Feels like \(Int(feelsLikeTemp))°")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                
                // Weather icon and condition
                VStack(spacing: 8) {
                    Image(systemName: current.symbolName)
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.multicolor)
                    
                    Text(current.condition.description)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.95))
                }
            }
        }
        .padding(.vertical, 20)
    }
    
    private var hourlyForecastView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hourly Forecast")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.hourlyForecast, id: \.date) { hour in
                        HourlyWeatherCard(hour: hour, useCelsius: viewModel.useCelsius)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var globalLow: Double {
        let lows = viewModel.dailyForecast.map {
            viewModel.useCelsius
            ? $0.lowTemperature.converted(to: .celsius).value
            : $0.lowTemperature.converted(to: .fahrenheit).value
        }
        return lows.min() ?? 0
    }

    private var globalHigh: Double {
        let highs = viewModel.dailyForecast.map {
            viewModel.useCelsius
            ? $0.highTemperature.converted(to: .celsius).value
            : $0.highTemperature.converted(to: .fahrenheit).value
        }
        return highs.max() ?? 1
    }

    private var globalRange: Double {
        max(globalHigh - globalLow, 1)
    }
    
    private var dailyForecastView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("7-Day Forecast")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            VStack(spacing: 8) {
                ForEach(viewModel.dailyForecast, id: \.date) { day in
                    DailyWeatherRow(
                        day: day,
                        useCelsius: viewModel.useCelsius,
                        globalLow: globalLow,
                        globalRange: globalRange
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Preview
#Preview {
    WeatherView()
}
