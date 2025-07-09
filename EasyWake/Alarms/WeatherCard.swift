// WeatherCardView.swift

import SwiftUI

struct WeatherCardView: View {
    @StateObject private var viewModel = WeatherCardViewModel()
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.locationName)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: viewModel.weatherIcon)
                        .font(.title3)
                        .foregroundColor(.primary)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("\(viewModel.temperature)°")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .task {
            await viewModel.loadWeatherData()
        }
    }
}

// Simple ViewModel for WeatherCard
class WeatherCardViewModel: ObservableObject {
    @Published var temperature: Int = 0
    @Published var weatherIcon: String = "cloud.fill"
    @Published var locationName: String = "Loading..."
    
    @AppStorage("temperatureUnit") private var useCelsius = false
    
    func loadWeatherData() async {
        // This would fetch actual weather data
        // For now, using mock data
        await MainActor.run {
            self.locationName = "Vienna, VA"
            self.temperature = useCelsius ? 33 : 92
            self.weatherIcon = "cloud.sun.fill"
        }
    }
}

#Preview {
    WeatherCardView()
        .padding()
}
