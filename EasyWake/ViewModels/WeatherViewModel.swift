//
//  WeatherViewModel.swift

import SwiftUI
import WeatherKit
import CoreLocation
import MapKit

@MainActor
class WeatherViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
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
    
    // Alert Manager
    @Published var alertManager = WeatherAlertManager()
    
    // Favorites storage
    @Published var favorites: [FavoriteLocation] = []
    private let favoritesKey = "favoriteLocations"
    
    // User preferences
    @AppStorage("temperatureUnit") var useCelsius = false
    @AppStorage("dailySummaryEnabled") private var dailySummaryEnabled = true
    @AppStorage("severeAlertsEnabled") private var severeAlertsEnabled = true
    
    // MARK: - Private Properties
    public let weatherService = WeatherService()
    public let locationManager = CLLocationManager()
    public var currentCoordinate: CLLocationCoordinate2D?
    
    // MARK: - Nested Types
    struct FavoriteLocation: Codable, Identifiable, Equatable {
        var id: String { "\(lat),\(lon)" }
        let name: String
        let lat: Double
        let lon: Double
    }

    // MARK: - Initialization
    override init() {
        super.init()
        loadFavorites()
        setupLocationManager()
    }
    
    // MARK: - Location Management
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
        
        // Also refresh alerts
        await alertManager.refreshAlerts()
    }
    
    // MARK: - Weather Data Fetching
    private func fetchWeatherData(for coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil

        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let weather = try await weatherService.weather(for: location)

            // Update published properties
            self.currentWeather = weather.currentWeather
            self.hourlyForecast = filterHourlyForecastFromCurrentHour(weather.hourlyForecast)
            self.dailyForecast = Array(weather.dailyForecast.prefix(7))

            if let alerts = weather.weatherAlerts {
                self.weatherAlerts = Array(alerts)
                await convertAndStoreAlerts(Array(alerts))
            }

            // Reverse-geocode name
            await updateLocationName(for: coordinate)

            isLoading = false

        } catch let urlErr as URLError {
            switch urlErr.code {
            case .timedOut:
                errorMessage = "Weather request timed out. Please check your connection and try again."
            case .notConnectedToInternet, .networkConnectionLost:
                errorMessage = "No internet connection. Please check your network."
            default:
                errorMessage = urlErr.localizedDescription
            }
            showError = true
            isLoading = false

        } catch {
            // any other Swift error
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    // MARK: - Hourly Forecast Filtering (Fixed)
    private func filterHourlyForecastFromCurrentHour(_ hourlyData: Forecast<HourWeather>) -> [HourWeather] {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the current hour (rounded down)
        let currentHourComponents = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        guard let currentHourStart = calendar.date(from: currentHourComponents) else {
            return Array(hourlyData.prefix(24))
        }
        
        // Filter hourly forecast to start from current hour
        let filteredHours = hourlyData.filter { hourWeather in
            return hourWeather.date >= currentHourStart
        }
        
        return Array(filteredHours.prefix(24))
    }
    
    // MARK: - Alert Conversion
    public func convertAndStoreAlerts(_ alerts: [WeatherAlert]) async {
        let convertedAlerts = alerts.compactMap { alert -> WeatherAlertData? in
            let severity: AlertSeverity
            switch alert.severity {
            case .extreme: severity = .emergency
            case .severe: severity = .warning
            case .moderate: severity = .watch
            case .minor: severity = .advisory
            default: severity = .advisory
            }
            
            let alertType: AlertType
            let summary = alert.summary.lowercased()
            if summary.contains("flood") { alertType = .flood }
            else if summary.contains("tornado") { alertType = .tornado }
            else if summary.contains("thunderstorm") || summary.contains("storm") { alertType = .thunderstorm }
            else if summary.contains("winter") || summary.contains("snow") || summary.contains("ice") { alertType = .winter }
            else if summary.contains("heat") { alertType = .heat }
            else if summary.contains("wind") { alertType = .wind }
            else if summary.contains("fire") { alertType = .fire }
            else { alertType = .general }
            
            return WeatherAlertData(
                title: alert.summary,
                description: alert.detailsURL.absoluteString,
                severity: severity,
                alertType: alertType,
                startTime: alert.metadata.date,
                endTime: alert.metadata.expirationDate,
                issuingAuthority: "National Weather Service",
                url: alert.detailsURL.absoluteString,
                affectedAreas: [currentLocation]
            )
        }
        
        DispatchQueue.main.async {
            self.alertManager.activeAlerts = convertedAlerts
        }
    }
    
    // MARK: - Location Services
    public func updateLocationName(for coordinate: CLLocationCoordinate2D) async {
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
    
    // MARK: - Favorites Management
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
        let fav = FavoriteLocation(name: name, lat: coordinate.latitude, lon: coordinate.longitude)
        if let idx = favorites.firstIndex(of: fav) {
            favorites.remove(at: idx)
        } else {
            favorites.append(fav)
        }
        saveFavorites()
    }

    func previewWeather(for fav: FavoriteLocation) async -> CurrentWeather? {
        let loc = CLLocation(latitude: fav.lat, longitude: fav.lon)
        do {
            let w = try await weatherService.weather(for: loc)
            return w.currentWeather
        } catch {
            return nil
        }
    }
    
    func previewDailyWeather(for fav: FavoriteLocation) async -> DayWeather? {
        let loc = CLLocation(latitude: fav.lat, longitude: fav.lon)
        do {
            let w = try await weatherService.weather(for: loc)
            return w.dailyForecast.first
        } catch {
            return nil
        }
    }
    
    // MARK: - Alert Management
    func dismissAlert(_ alert: WeatherAlert) {
        withAnimation(.spring()) {
            let alertId = "\(alert.metadata.date)-\(alert.metadata.expirationDate)"
            dismissedAlerts.insert(alertId)
        }
    }
    
    // MARK: - Location Search
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
