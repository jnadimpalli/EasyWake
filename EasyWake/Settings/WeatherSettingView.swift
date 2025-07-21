// WeatherSettingsView.swift - Fixed Version

import SwiftUI
import CoreLocation

// MARK: - Settings Data Models
struct SavedLocation: Identifiable, Codable {
    var id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let isCurrentLocation: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, isCurrentLocation
    }
    
    init(name: String, coordinate: CLLocationCoordinate2D, isCurrentLocation: Bool = false) {
        self.name = name
        self.coordinate = coordinate
        self.isCurrentLocation = isCurrentLocation
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        isCurrentLocation = try container.decode(Bool.self, forKey: .isCurrentLocation)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(isCurrentLocation, forKey: .isCurrentLocation)
    }
}

// MARK: - Settings View Model
class WeatherSettingsViewModel: ObservableObject {
    @AppStorage("temperatureUnit") var useCelsius = false
    @AppStorage("dailySummaryEnabled") var dailySummaryEnabled = true
    @AppStorage("severeAlertsEnabled") var severeAlertsEnabled = true
    @AppStorage("showBufferTimes") var showBufferTimes = true
    @AppStorage("useWeatherToAdjust") var useWeatherToAdjust = true
    
    @Published var savedLocations: [SavedLocation] = []
    @Published var bufferDelays: [String: Int] = [:]
    
    let weatherTypes = [
        "Light Rain", "Moderate Rain", "Heavy Rain",
        "Light Snow", "Moderate Snow", "Heavy Snow",
        "Fog", "High Wind", "Thunderstorm"
    ]
    
    // Default buffer times (in minutes)
    private let defaultBufferDelays: [String: Int] = [
        "Light Rain": 5,
        "Moderate Rain": 10,
        "Heavy Rain": 15,
        "Light Snow": 20,
        "Moderate Snow": 25,
        "Heavy Snow": 30,
        "Fog": 15,
        "High Wind": 10,
        "Thunderstorm": 20
    ]
    
    init() {
        loadSavedLocations()
        loadBufferDelays()
    }
    
    // MARK: - Location Management
    private func loadSavedLocations() {
        if let data = UserDefaults.standard.data(forKey: "savedWeatherLocations"),
           let locations = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            savedLocations = locations
        } else {
            // Add current location as default
            savedLocations = [
                SavedLocation(
                    name: "Current Location",
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    isCurrentLocation: true
                )
            ]
        }
    }
    
    func saveSavedLocations() {
        if let data = try? JSONEncoder().encode(savedLocations) {
            UserDefaults.standard.set(data, forKey: "savedWeatherLocations")
        }
    }
    
    func addLocation(_ location: SavedLocation) {
        savedLocations.append(location)
        saveSavedLocations()
    }
    
    func removeLocation(_ location: SavedLocation) {
        savedLocations.removeAll { $0.id == location.id }
        saveSavedLocations()
    }
    
    func moveLocation(from source: IndexSet, to destination: Int) {
        savedLocations.move(fromOffsets: source, toOffset: destination)
        saveSavedLocations()
    }
    
    // MARK: - Buffer Delays Management
    private func loadBufferDelays() {
        if let data = UserDefaults.standard.data(forKey: "weatherBufferDelays"),
           let delays = try? JSONDecoder().decode([String: Int].self, from: data) {
            bufferDelays = delays
        } else {
            bufferDelays = defaultBufferDelays
        }
    }
    
    func saveBufferDelays() {
        if let data = try? JSONEncoder().encode(bufferDelays) {
            UserDefaults.standard.set(data, forKey: "weatherBufferDelays")
        }
    }
    
    func updateBufferDelay(for weatherType: String, minutes: Int) {
        bufferDelays[weatherType] = minutes
        saveBufferDelays()
    }
    
    func resetBufferDelays() {
        bufferDelays = defaultBufferDelays
        saveBufferDelays()
    }
}

// MARK: - Settings View
struct WeatherSettingView: View {
    @StateObject private var viewModel = WeatherSettingsViewModel()
    @State private var showAddLocation = false
    @State private var showResetAlert = false
    @Environment(\.dismiss) private var dismiss
    
    // Support for both navigation modes
    let showDoneButton: Bool
    
    init(showDoneButton: Bool = true) {
        self.showDoneButton = showDoneButton
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Temperature Units Section
                Section {
                    Picker("Temperature Units", selection: $viewModel.useCelsius) {
                        Text("Fahrenheit (°F)").tag(false)
                        Text("Celsius (°C)").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                } header: {
                    Label("UNITS", systemImage: "thermometer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Notifications Section
                Section {
                    Toggle(isOn: $viewModel.dailySummaryEnabled) {
                        HStack {
                            Image(systemName: "sunrise.fill")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daily Weather Summary")
                                    .font(.body)
                                Text("Get a morning briefing at 7 AM")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Toggle(isOn: $viewModel.severeAlertsEnabled) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Severe Weather Alerts")
                                    .font(.body)
                                Text("Push notifications for warnings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("NOTIFICATIONS", systemImage: "bell.badge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Smart Alarm Integration Section
                Section {
                    Toggle(isOn: $viewModel.useWeatherToAdjust) {
                        HStack {
                            Image(systemName: "alarm")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weather-Based Adjustments")
                                    .font(.body)
                                Text("Adjust alarm times for weather")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if viewModel.useWeatherToAdjust {
                        DisclosureGroup(
                            isExpanded: $viewModel.showBufferTimes,
                            content: {
                                VStack(spacing: 16) {
                                    ForEach(viewModel.weatherTypes, id: \.self) { weatherType in
                                        BufferTimeRow(
                                            weatherType: weatherType,
                                            minutes: viewModel.bufferDelays[weatherType] ?? 0,
                                            onUpdate: { newValue in
                                                viewModel.updateBufferDelay(for: weatherType, minutes: newValue)
                                            }
                                        )
                                    }
                                    
                                    Button(action: {
                                        showResetAlert = true
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Reset to Defaults")
                                        }
                                        .font(.footnote)
                                        .foregroundColor(.blue)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 8)
                                }
                                .padding(.vertical, 8)
                            },
                            label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.purple)
                                        .frame(width: 30)
                                    
                                    Text("Adjust Buffer Times")
                                        .font(.body)
                                }
                            }
                        )
                    }
                } header: {
                    Label("SMART ALARM INTEGRATION", systemImage: "brain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } footer: {
                    if viewModel.useWeatherToAdjust {
                        Text("Smart alarms will wake you earlier based on weather conditions to ensure you arrive on time.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - About Section
                Section {
                    HStack {
                        Text("Weather Provider")
                        Spacer()
                        Text("Apple Weather")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(Date(), style: .relative)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("ABOUT", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 96)
            }
            .navigationTitle("Weather Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showDoneButton {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Reset Buffer Times", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    viewModel.resetBufferDelays()
                }
            } message: {
                Text("This will reset all buffer times to their default values.")
            }
            .sheet(isPresented: $showAddLocation) {
                Text("Location Picker")
                    .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Supporting Views
struct BufferTimeRow: View {
    let weatherType: String
    let minutes: Int
    let onUpdate: (Int) -> Void
    
    private var weatherIcon: String {
        switch weatherType {
        case "Light Rain": return "cloud.drizzle"
        case "Moderate Rain": return "cloud.rain"
        case "Heavy Rain": return "cloud.heavyrain"
        case "Light Snow": return "snow"
        case "Moderate Snow": return "cloud.snow"
        case "Heavy Snow": return "wind.snow"
        case "Fog": return "cloud.fog"
        case "High Wind": return "wind"
        case "Thunderstorm": return "cloud.bolt.rain"
        default: return "questionmark.circle"
        }
    }
    
    var body: some View {
        HStack {
            Label(weatherType, systemImage: weatherIcon)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Stepper(
                value: Binding(
                    get: { minutes },
                    set: { onUpdate($0) }
                ),
                in: 0...120,
                step: 5
            ) {
                Text("\(minutes) min")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

struct LocationRow: View {
    let location: SavedLocation
    
    var body: some View {
        HStack {
            Image(systemName: location.isCurrentLocation ? "location.fill" : "mappin.circle.fill")
                .foregroundColor(location.isCurrentLocation ? .blue : .secondary)
                .frame(width: 25)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.body)
                
                if !location.isCurrentLocation {
                    Text("\(location.coordinate.latitude), \(location.coordinate.longitude)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if location.isCurrentLocation {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.body)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Smart Alarm Integration Helper
extension WeatherSettingsViewModel {
    func calculateAlarmAdjustment(for weatherConditions: [String]) -> TimeInterval {
        guard useWeatherToAdjust else { return 0 }
        
        var totalAdjustment: TimeInterval = 0
        
        for condition in weatherConditions {
            if let bufferMinutes = bufferDelays[condition] {
                totalAdjustment += TimeInterval(bufferMinutes * 60)
            }
        }
        
        return totalAdjustment
    }
    
    func getAdjustmentDescription(for adjustment: TimeInterval) -> String? {
        guard adjustment > 0 else { return nil }
        
        let minutes = Int(adjustment / 60)
        if minutes < 60 {
            return "Wake \(minutes) min earlier"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "Wake \(hours) hr earlier"
            } else {
                return "Wake \(hours) hr \(remainingMinutes) min earlier"
            }
        }
    }
}

// MARK: - Preview
#Preview {
    WeatherSettingView()
}
