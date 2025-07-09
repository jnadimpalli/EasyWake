// WeatherView.swift

import SwiftUI
import WeatherKit
import CoreLocation
import MapKit

// MARK: - View Model
@MainActor
class WeatherViewModel: NSObject, ObservableObject {
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [HourWeather] = []
    @Published var dailyForecast: [DayWeather] = []
    @Published var weatherAlerts: [WeatherAlert] = []
    
    @Published var currentLocation: String = "Loading..."
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showLocationPicker = false
    @Published var dismissedAlerts: Set<String> = []
    
    // User preferences
    @AppStorage("temperatureUnit") var useCelsius = false
    @AppStorage("dailySummaryEnabled") private var dailySummaryEnabled = true
    @AppStorage("severeAlertsEnabled") private var severeAlertsEnabled = true
    
    private let weatherService = WeatherService()
    private let locationManager = CLLocationManager()
    private var currentCoordinate: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
    }
    
    func refreshWeatherData() async {
        if let coordinate = currentCoordinate {
            await fetchWeatherData(for: coordinate)
        } else {
            locationManager.requestLocation()
        }
    }
    
    private func fetchWeatherData(for coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch weather data from WeatherKit
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            // Get weather data with proper WeatherKit query
            let weather = try await weatherService.weather(for: location)
            
            // Update current weather
            self.currentWeather = weather.currentWeather
            
            // Update hourly forecast (next 24 hours)
            self.hourlyForecast = Array(weather.hourlyForecast.prefix(24))
            
            // Update daily forecast (next 7 days)
            self.dailyForecast = Array(weather.dailyForecast.prefix(7))
            
            // Update alerts if available
            if let alerts = weather.weatherAlerts {
                self.weatherAlerts = Array(alerts)
            }
            
            // Update location name
            await updateLocationName(for: coordinate)
            
            isLoading = false
        } catch {
            self.errorMessage = "Unable to fetch weather data: \(error.localizedDescription)"
            self.showError = true
            self.isLoading = false
        }
    }
    
    private func updateLocationName(for coordinate: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                self.currentLocation = placemark.locality ?? placemark.name ?? "Unknown Location"
            }
        } catch {
            self.currentLocation = "Location"
        }
    }
    
    func dismissAlert(_ alert: WeatherAlert) {
        let alertId = "\(alert.metadata.date)-\(alert.metadata.expirationDate)"
        dismissedAlerts.insert(alertId)
    }
    
    func searchLocation(_ query: String) async -> [MKMapItem] {
        guard !query.isEmpty else { return [] }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            return response.mapItems
        } catch {
            print("Location search error: \(error)")
            return []
        }
    }
    
    func selectLocation(_ mapItem: MKMapItem) {
        currentCoordinate = mapItem.placemark.coordinate
        currentLocation = mapItem.placemark.locality ?? mapItem.name ?? "Unknown"
        showLocationPicker = false
        
        Task {
            await fetchWeatherData(for: mapItem.placemark.coordinate)
        }
    }
}

// MARK: - Location Manager Delegate
extension WeatherViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        currentCoordinate = location.coordinate
        
        Task {
            await fetchWeatherData(for: location.coordinate)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        showLocationPicker = true
        errorMessage = "Unable to get location. Please select a city."
        showError = true
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            showLocationPicker = true
        default:
            break
        }
    }
}

// MARK: - Main View
struct WeatherView: View {
    @StateObject private var viewModel = WeatherViewModel()
    @State private var navigateToSettings = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Top Bar
                        topBar
                        
                        if viewModel.isLoading {
                            loadingView
                        } else {
                            // Current Weather
                            if viewModel.currentWeather != nil {
                                currentWeatherView
                            }
                            
                            // Weather Alerts
                            if !viewModel.weatherAlerts.isEmpty {
                                alertsView
                            }
                            
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
                    .padding(.bottom, 100) // Space for tab bar
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
                    Task { await viewModel.refreshWeatherData() }
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
            .sheet(isPresented: $viewModel.showLocationPicker) {
                LocationPickerView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.refreshWeatherData()
        }
    }
    
    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.1, green: 0.2, blue: 0.3), Color(red: 0.05, green: 0.1, blue: 0.15)]
        } else {
            return [Color(red: 0.4, green: 0.6, blue: 0.9), Color(red: 0.6, green: 0.8, blue: 1.0)]
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
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading weather...")
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var currentWeatherView: some View {
        VStack(spacing: 8) {
            // Location with search
            Button {
                viewModel.showLocationPicker = true
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption)
                    Text(viewModel.currentLocation)
                        .font(.title3)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.9))
            }
            
            if let current = viewModel.currentWeather {
                // Temperature
                let temp = viewModel.useCelsius ?
                    current.temperature.converted(to: .celsius).value :
                    current.temperature.converted(to: .fahrenheit).value
                
                Text("\(Int(temp))°")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundColor(.white)
                
                // Weather icon and condition
                VStack(spacing: 4) {
                    Image(systemName: current.symbolName)
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.multicolor)
                    
                    Text(current.condition.description)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding(.vertical, 30)
    }
    
    private var alertsView: some View {
            VStack(spacing: 12) {
                ForEach(viewModel.weatherAlerts, id: \.metadata.date) { alert in
                    let alertId = "\(alert.metadata.date)-\(alert.metadata.expirationDate)"
                    if !viewModel.dismissedAlerts.contains(alertId) {
                        WeatherAlertCard(alert: alert) {
                            viewModel.dismissAlert(alert)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    
    private var hourlyForecastView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hourly Forecast")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.hourlyForecast, id: \.date) { hour in
                        HourlyWeatherCard(hour: hour, useCelsius: viewModel.useCelsius)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var dailyForecastView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("7-Day Forecast")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(viewModel.dailyForecast, id: \.date) { day in
                    DailyWeatherRow(day: day, useCelsius: viewModel.useCelsius)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Supporting Views
struct WeatherAlertCard: View {
    let alert: WeatherAlert
    let onDismiss: () -> Void
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Label(alert.summary, systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(alert.detailsURL.absoluteString)
                  .font(.caption)
                  .foregroundColor(.white.opacity(0.8))
                  .lineLimit(2)
                
                // Alert severity
                Text("Severity: \(alert.severity.description)")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .italic()
            }
            .padding()
            
            Spacer()
        }
        .background(backgroundColorForSeverity(alert.severity))
        .cornerRadius(12)
        .offset(x: offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        offset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 100 {
                        withAnimation {
                            offset = 400
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    } else {
                        withAnimation {
                            offset = 0
                        }
                    }
                }
        )
    }
    
    private func backgroundColorForSeverity(_ severity: WeatherSeverity) -> Color {
        switch severity {
        case .extreme:
            return Color.red
        case .severe:
            return Color.orange
        case .moderate:
            return Color.yellow.opacity(0.8)
        case .minor:
            return Color.blue.opacity(0.8)
        default:
            return Color.gray.opacity(0.8)
        }
    }
}

struct HourlyWeatherCard: View {
    let hour: HourWeather
    let useCelsius: Bool
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: hour.date)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(timeString)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            Image(systemName: hour.symbolName)
                .font(.title2)
                .foregroundColor(.white)
                .symbolRenderingMode(.multicolor)
            
            let temp = useCelsius ?
                hour.temperature.converted(to: .celsius).value :
                hour.temperature.converted(to: .fahrenheit).value
            
            Text("\(Int(temp))°")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            if hour.precipitationChance > 0 {
                Text("\(Int(hour.precipitationChance * 100))%")
                    .font(.caption2)
                    .foregroundColor(.cyan)
            }
        }
        .frame(width: 60)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(30)
    }
}

struct DailyWeatherRow: View {
    let day: DayWeather
    let useCelsius: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: day.date)
    }
    
    var body: some View {
        HStack {
            Text(dayString)
                .frame(width: 50, alignment: .leading)
                .foregroundColor(.white)
            
            Image(systemName: day.symbolName)
                .font(.title2)
                .foregroundColor(.white)
                .symbolRenderingMode(.multicolor)
                .frame(width: 40)
            
            Spacer()
            
            // Temperature range with bar
            let minTemp = useCelsius ?
                day.lowTemperature.converted(to: .celsius).value :
                day.lowTemperature.converted(to: .fahrenheit).value
            
            let maxTemp = useCelsius ?
                day.highTemperature.converted(to: .celsius).value :
                day.highTemperature.converted(to: .fahrenheit).value
            
            HStack(spacing: 8) {
                Text("\(Int(minTemp))°")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 35, alignment: .trailing)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(temperatureGradient)
                            .frame(width: tempBarWidth(
                                min: minTemp,
                                max: maxTemp,
                                in: geo.size.width
                            ), height: 4)
                    }
                }
                .frame(width: 80, height: 4)
                
                Text("\(Int(maxTemp))°")
                    .font(.callout)
                    .foregroundColor(.white)
                    .frame(width: 35, alignment: .leading)
            }
            
            if day.precipitationChance > 0 {
                Text("\(Int(day.precipitationChance * 100))%")
                    .font(.caption)
                    .foregroundColor(.cyan)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var temperatureGradient: LinearGradient {
        LinearGradient(
            colors: [Color.blue, Color.cyan, Color.yellow, Color.orange],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func tempBarWidth(min: Double, max: Double, in totalWidth: CGFloat) -> CGFloat {
        let range = max - min
        let maxRange: Double = 30 // Assume max daily range
        return totalWidth * CGFloat(range / maxRange)
    }
}

// MARK: - Location Picker
struct LocationPickerView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search for a city", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task {
                                await performSearch()
                            }
                        }
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Results list
                List(searchResults, id: \.self) { item in
                    Button {
                        viewModel.selectLocation(item)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name ?? "Unknown")
                                .font(.headline)
                            
                            if let locality = item.placemark.locality,
                               let adminArea = item.placemark.administrativeArea {
                                Text("\(locality), \(adminArea)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        searchResults = await viewModel.searchLocation(searchText)
        isSearching = false
    }
}

// MARK: - Preview
#Preview {
    WeatherView()
}
