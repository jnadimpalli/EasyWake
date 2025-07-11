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
    
    // MARK: — Favorites storage
    @Published var favorites: [FavoriteLocation] = []

    private let favoritesKey = "favoriteLocations"
    
    // User preferences - shared with WeatherSettingsView
    @AppStorage("temperatureUnit") var useCelsius = false
    @AppStorage("dailySummaryEnabled") private var dailySummaryEnabled = true
    @AppStorage("severeAlertsEnabled") private var severeAlertsEnabled = true
    
    private let weatherService = WeatherService()
    private let locationManager = CLLocationManager()
    private var currentCoordinate: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        loadFavorites()
        setupLocationManager()
    }
    
    struct FavoriteLocation: Codable, Identifiable, Equatable {
        var id: String { "\(lat),\(lon)" }
        let name: String
        let lat: Double
        let lon: Double
    }

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let saved = try? JSONDecoder().decode([FavoriteLocation].self, from: data)
        else { return }
        favorites = saved
    }

    private func saveFavorites() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: favoritesKey)
    }

    func toggleFavorite(name: String, coordinate: CLLocationCoordinate2D) {
        let fav = FavoriteLocation(name: name,
                                   lat: coordinate.latitude,
                                   lon: coordinate.longitude)
        if let idx = favorites.firstIndex(of: fav) {
            favorites.remove(at: idx)
        } else {
            favorites.append(fav)
        }
        saveFavorites()
    }

    // Helper to fetch preview weather for any FavoriteLocation
    func previewWeather(for fav: FavoriteLocation) async -> CurrentWeather? {
        let loc = CLLocation(latitude: fav.lat, longitude: fav.lon)
        do {
            let w = try await weatherService.weather(for: loc)
            return w.currentWeather
        } catch {
            return nil
        }
    }
    
    // Helper to fetch daily weather for high/low temps
    func previewDailyWeather(for fav: FavoriteLocation) async -> DayWeather? {
        let loc = CLLocation(latitude: fav.lat, longitude: fav.lon)
        do {
            let w = try await weatherService.weather(for: loc)
            return w.dailyForecast.first
        } catch {
            return nil
        }
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
        withAnimation(.spring()) {
            let alertId = "\(alert.metadata.date)-\(alert.metadata.expirationDate)"
            dismissedAlerts.insert(alertId)
        }
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
                
                VStack(spacing: 0) {
                    // Pinned header
                    topBar
                        .background(Color.clear)
                        .zIndex(1)
                    
                    Divider().background(Color.white.opacity(0.5))
                    
                    ScrollView {
                        VStack(spacing: 20) {
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
                        .padding(.bottom, 100)
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
                    Task { await viewModel.refreshWeatherData() }
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
            .sheet(isPresented: $viewModel.showLocationPicker) {
                LocationPickerView(viewModel: viewModel)
                    .presentationDetents([.large])
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
        .padding(.top, 8)
        .background(Color.clear)
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
                
                // Feels like temperature
                let feelsLikeTemp = viewModel.useCelsius ?
                    current.apparentTemperature.converted(to: .celsius).value :
                    current.apparentTemperature.converted(to: .fahrenheit).value
                
                Text("Feels like \(Int(feelsLikeTemp))°")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                
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
            let visibleAlerts = viewModel.weatherAlerts.compactMap { alert -> WeatherAlert? in
                let alertId = "\(alert.metadata.date)-\(alert.metadata.expirationDate)"
                return viewModel.dismissedAlerts.contains(alertId) ? nil : alert
            }
            
            let alertsToShow = Array(visibleAlerts.prefix(2))
            let hasMoreAlerts = visibleAlerts.count > 2
            
            ForEach(alertsToShow, id: \.metadata.date) { alert in
                WeatherAlertCard(alert: alert) {
                    viewModel.dismissAlert(alert)
                }
            }
            
            if hasMoreAlerts {
                Button("Show more...") {
                    // Show all alerts - could expand this functionality
                }
                .foregroundColor(.white.opacity(0.8))
                .font(.caption)
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
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(viewModel.dailyForecast, id: \.date) { day in
                    DailyWeatherRow(
                        day: day,
                        useCelsius: viewModel.useCelsius,
                        globalLow: globalLow,
                        globalRange: globalRange
                    )
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
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        withAnimation(.spring()) {
                            offset = 400
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(.spring()) {
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
            
            // Only show precipitation % if > 0
            if hour.precipitationChance > 0 &&
               (hour.symbolName.contains("rain") || hour.symbolName.contains("snow") ||
                hour.symbolName.contains("drizzle") || hour.symbolName.contains("bolt") ||
                hour.symbolName.contains("sleet") || hour.symbolName.contains("hail")) {
                Text("\(Int(hour.precipitationChance * 100))%")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .shadow(radius: 1)
            }
            
            let temp = useCelsius ?
                hour.temperature.converted(to: .celsius).value :
                hour.temperature.converted(to: .fahrenheit).value
            
            Text("\(Int(temp))°")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.white)
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
    let globalLow: Double
    let globalRange: Double
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
            
            VStack(spacing: 4) {
                Image(systemName: day.symbolName)
                    .font(.title2)
                    .foregroundColor(.white)
                    .symbolRenderingMode(.multicolor)
                
                if day.precipitationChance > 0 &&
                   (day.symbolName.contains("rain") || day.symbolName.contains("snow") ||
                    day.symbolName.contains("drizzle") || day.symbolName.contains("bolt") ||
                    day.symbolName.contains("sleet") || day.symbolName.contains("hail")) {
                    Text("\(Int(day.precipitationChance * 100))%")
                        .font(.caption)
                        .foregroundColor(.white)
                        .shadow(radius: 1)
                }
            }
            .frame(width: 40)
            
            Spacer()
            
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
                    let minT = useCelsius
                        ? day.lowTemperature.converted(to: .celsius).value
                        : day.lowTemperature.converted(to: .fahrenheit).value
                    let maxT = useCelsius
                        ? day.highTemperature.converted(to: .celsius).value
                        : day.highTemperature.converted(to: .fahrenheit).value
                    
                    let span = maxT - minT
                    let midT = (minT + maxT) / 2
                    let stops: [Color] = span >= 10
                        ? [colorForTemperature(minT), colorForTemperature(midT), colorForTemperature(maxT)]
                        : [colorForTemperature(minT), colorForTemperature(maxT)]

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: stops,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geo.size.width * CGFloat((maxT - minT) / globalRange),
                                height: 4
                            )
                            .offset(
                                x: geo.size.width * CGFloat((minT - globalLow) / globalRange)
                            )
                    }
                }
                .frame(height: 4)
                
                Text("\(Int(maxTemp))°")
                    .font(.callout)
                    .foregroundColor(.white)
                    .frame(width: 35, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func colorForTemperature(_ temp: Double) -> Color {
        let (minTemp, maxTemp): (Double, Double) = useCelsius
            ? (-10, 40)
            : (0, 95)

        let fraction = min(max((temp - minTemp) / (maxTemp - minTemp), 0), 1)
        let hue = (240 - 210 * fraction) / 360
        return Color(hue: hue, saturation: 1, brightness: 1)
    }
}

// MARK: - Location Picker
struct LocationPickerView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var favoriteWeatherPreviews: [String: CurrentWeather] = [:]
    @State private var favoriteDailyWeather: [String: DayWeather] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    searchSection
                    contentScrollView
                }
            }
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    cancelButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    moreButton
                }
            }
        }
        .task {
            await loadFavoriteWeatherPreviews()
        }
        .onChange(of: viewModel.favorites) { _, _ in
            Task {
                await loadFavoriteWeatherPreviews()
            }
        }
    }
    
    private var searchSection: some View {
        VStack(spacing: 16) {
            searchField
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
    
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16, weight: .medium))
            
            TextField("Search for a city or airport", text: $searchText)
                .foregroundColor(.white)
                .font(.system(size: 16))
                .submitLabel(.search)
                .onSubmit {
                    Task { await performSearch() }
                }
                .accessibilityLabel("Search for locations")
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                searchResultsSection
                favoritesSection
                bottomSpacer
            }
        }
        .simultaneousGesture(
            DragGesture().onChanged { _ in }
        )
    }
    
    private var favoritesSection: some View {
        Group {
            if !viewModel.favorites.isEmpty {
                VStack(spacing: 16) {
                    ForEach(viewModel.favorites) { fav in
                        favoriteCard(for: fav)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, searchResults.isEmpty ? 40 : 32)
            }
        }
    }
    
    private func favoriteCard(for fav: WeatherViewModel.FavoriteLocation) -> some View {
        FavoriteLocationCard(
            favorite: fav,
            weatherPreview: favoriteWeatherPreviews[fav.id],
            dailyWeather: favoriteDailyWeather[fav.id],
            onTap: {
                handleFavoriteTap(fav)
            },
            onToggleFavorite: {
                handleFavoriteToggle(fav)
            }
        )
    }
    
    private var searchResultsSection: some View {
        Group {
            if !searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    searchResultsHeader
                    searchResultsList
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private var searchResultsHeader: some View {
        HStack {
            Text("Search Results")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
    }
    
    private var searchResultsList: some View {
        VStack(spacing: 12) {
            ForEach(searchResults, id: \.self) { item in
                searchResultCard(for: item)
            }
        }
        .padding(.horizontal, 28)
    }
    
    private func searchResultCard(for item: MKMapItem) -> some View {
        SearchResultCard(
            mapItem: item,
            isFavorite: isFavorite(item),
            onTap: {
                handleSearchResultTap(item)
            },
            onToggleFavorite: {
                handleSearchResultToggle(item)
            }
        )
    }
    
    private var bottomSpacer: some View {
        Spacer()
            .frame(height: 120)
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
        .foregroundColor(.blue)
        .font(.system(size: 16, weight: .medium))
    }
    
    private var moreButton: some View {
        Button(action: {
            // Menu functionality placeholder
        }) {
            Image(systemName: "ellipsis")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More options")
    }
    
    // MARK: - Helper Methods
    private func handleFavoriteTap(_ fav: WeatherViewModel.FavoriteLocation) {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: fav.lat, longitude: fav.lon)))
        viewModel.selectLocation(mapItem)
    }
    
    private func handleFavoriteToggle(_ fav: WeatherViewModel.FavoriteLocation) {
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
        viewModel.toggleFavorite(
            name: fav.name,
            coordinate: CLLocationCoordinate2D(latitude: fav.lat, longitude: fav.lon)
        )
    }
    
    private func handleSearchResultTap(_ item: MKMapItem) {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
        
        let name = item.name ?? item.placemark.locality ?? "Unknown"
        if !isFavorite(item) {
            viewModel.toggleFavorite(name: name, coordinate: item.placemark.coordinate)
            Task {
                await loadWeatherForNewFavorite(name: name, coordinate: item.placemark.coordinate)
            }
        }
        
        viewModel.selectLocation(item)
    }
    
    private func handleSearchResultToggle(_ item: MKMapItem) {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
        let name = item.name ?? item.placemark.locality ?? "Unknown"
        viewModel.toggleFavorite(name: name, coordinate: item.placemark.coordinate)
        
        if !isFavorite(item) {
            Task {
                await loadWeatherForNewFavorite(name: name, coordinate: item.placemark.coordinate)
            }
        }
    }

    private func isFavorite(_ mapItem: MKMapItem) -> Bool {
        let coord = mapItem.placemark.coordinate
        return viewModel.favorites.contains { $0.id == "\(coord.latitude),\(coord.longitude)" }
    }

    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = searchText
        req.resultTypes = .address
        if let resp = try? await MKLocalSearch(request: req).start() {
            searchResults = resp.mapItems
        }
        isSearching = false
    }

    private func loadFavoriteWeatherPreviews() async {
        for favorite in viewModel.favorites {
            // Load current weather
            if let weather = await viewModel.previewWeather(for: favorite) {
                await MainActor.run {
                    favoriteWeatherPreviews[favorite.id] = weather
                }
            }
            
            // Load daily weather for high/low temps
            if let dailyWeather = await viewModel.previewDailyWeather(for: favorite) {
                await MainActor.run {
                    favoriteDailyWeather[favorite.id] = dailyWeather
                }
            }
        }
    }
    
    private func loadWeatherForNewFavorite(name: String, coordinate: CLLocationCoordinate2D) async {
        let fav = WeatherViewModel.FavoriteLocation(name: name, lat: coordinate.latitude, lon: coordinate.longitude)
        
        // Load current weather
        if let weather = await viewModel.previewWeather(for: fav) {
            await MainActor.run {
                favoriteWeatherPreviews[fav.id] = weather
            }
        }
        
        // Load daily weather for high/low temps
        if let dailyWeather = await viewModel.previewDailyWeather(for: fav) {
            await MainActor.run {
                favoriteDailyWeather[fav.id] = dailyWeather
            }
        }
    }
}

// MARK: - Location Picker Cards
struct FavoriteLocationCard: View {
    let favorite: WeatherViewModel.FavoriteLocation
    let weatherPreview: CurrentWeather?
    let dailyWeather: DayWeather?
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    
    private var timeInfo: (timeString: String, isDaytime: Bool) {
        // Use a proper timezone mapping based on coordinates and city names
        let timeZone: TimeZone
        
        // First check by coordinates (more reliable)
        if favorite.lat >= 25.0 && favorite.lat <= 49.0 && favorite.lon >= -125.0 && favorite.lon <= -66.0 {
            // US Continental boundaries
            if favorite.lon >= -84.0 {
                // Eastern Time Zone
                timeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
            } else if favorite.lon >= -104.0 {
                // Central Time Zone
                timeZone = TimeZone(identifier: "America/Chicago") ?? TimeZone.current
            } else if favorite.lon >= -115.0 {
                // Mountain Time Zone
                timeZone = TimeZone(identifier: "America/Denver") ?? TimeZone.current
            } else {
                // Pacific Time Zone
                timeZone = TimeZone(identifier: "America/Los_Angeles") ?? TimeZone.current
            }
        } else {
            // International locations - check by name
            switch favorite.name.lowercased() {
            case let name where name.contains("london"):
                timeZone = TimeZone(identifier: "Europe/London") ?? TimeZone.current
            case let name where name.contains("paris"):
                timeZone = TimeZone(identifier: "Europe/Paris") ?? TimeZone.current
            case let name where name.contains("tokyo"):
                timeZone = TimeZone(identifier: "Asia/Tokyo") ?? TimeZone.current
            case let name where name.contains("sydney"):
                timeZone = TimeZone(identifier: "Australia/Sydney") ?? TimeZone.current
            case let name where name.contains("hyderabad") || name.contains("mumbai") ||
                               name.contains("delhi") || name.contains("bangalore"):
                timeZone = TimeZone(identifier: "Asia/Kolkata") ?? TimeZone.current
            default:
                // Fallback to longitude-based approximation for unknown international locations
                let timeZoneOffset = Int(round(favorite.lon / 15.0))
                timeZone = TimeZone(secondsFromGMT: timeZoneOffset * 3600) ?? TimeZone.current
            }
        }
        
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        
        let localTime = calendar.dateComponents(in: timeZone, from: now)
        let hour = localTime.hour ?? 12
        let isDaytime = hour >= 6 && hour < 20
        
        return (formatter.string(from: now), isDaytime)
    }
    
    private var backgroundGradient: LinearGradient {
        if let weather = weatherPreview {
            // Create gradient based on weather conditions and time of day
            if timeInfo.isDaytime {
                // Daytime gradients
                if weather.symbolName.contains("sun") {
                    return LinearGradient(
                        colors: [Color.blue.opacity(0.9), Color.cyan.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else if weather.symbolName.contains("cloud") {
                    return LinearGradient(
                        colors: [Color.gray.opacity(0.8), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else if weather.symbolName.contains("rain") {
                    return LinearGradient(
                        colors: [Color.gray.opacity(0.9), Color.blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                // Nighttime gradients - darker with better contrast
                return LinearGradient(
                    colors: [Color.indigo.opacity(0.95), Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        
        // Default gradient
        return LinearGradient(
            colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            // Subtle cloud overlay for visual depth
            if timeInfo.isDaytime {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.white.opacity(0.08))
                    .offset(x: 60, y: -10)
            }
            
            VStack(spacing: 0) {
                // Top row with star button
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        // Location name
                        Text(favorite.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        
                        // Time and day/night indicator
                        HStack(spacing: 6) {
                            Text(timeInfo.timeString)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.95))
                            
                            Text("•")
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack(spacing: 4) {
                                Image(systemName: timeInfo.isDaytime ? "sun.max.fill" : "moon.fill")
                                    .font(.caption)
                                    .foregroundColor(timeInfo.isDaytime ? .yellow : .white)
                                
                                Text(timeInfo.isDaytime ? "Day" : "Night")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Star toggle button with better accessibility
                    Button(action: onToggleFavorite) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.yellow)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Remove from favorites")
                }
                
                Spacer()
                
                // Bottom row with weather info
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Weather condition
                        if let weather = weatherPreview {
                            Text(weather.condition.description)
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.95))
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            
                            // H:L temperatures with actual data
                            if let daily = dailyWeather {
                                let highTemp = Int(daily.highTemperature.converted(to: .fahrenheit).value)
                                let lowTemp = Int(daily.lowTemperature.converted(to: .fahrenheit).value)
                                Text("H:\(highTemp)° L:\(lowTemp)°")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        // Weather icon
                        if let weather = weatherPreview {
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .symbolRenderingMode(.multicolor)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                        
                        // Current temperature
                        if let weather = weatherPreview {
                            let temp = Int(weather.temperature.converted(to: .fahrenheit).value)
                            Text("\(temp)°")
                                .font(.system(size: 52, weight: .ultraLight))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .onTapGesture {
            onTap()
        }
        .accessibilityLabel("\(favorite.name) weather")
        .accessibilityHint("Tap to view detailed weather for this location")
    }
}

struct SearchResultCard: View {
    let mapItem: MKMapItem
    let isFavorite: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    // Primary location name with better typography
                    Text(mapItem.name ?? mapItem.placemark.locality ?? "Unknown Location")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // Secondary location info with proper hierarchy
                    if let locality = mapItem.placemark.locality,
                       let administrativeArea = mapItem.placemark.administrativeArea,
                       let country = mapItem.placemark.country {
                        Text("\(locality), \(administrativeArea), \(country)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    } else if let country = mapItem.placemark.country {
                        Text(country)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 12)
                
                // Star toggle with proper touch target
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isFavorite ? .yellow : .gray)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Select \(mapItem.name ?? "location")")
        .accessibilityHint("Tap to view weather for this location")
    }
}

// MARK: - Preview
#Preview {
    WeatherView()
}
