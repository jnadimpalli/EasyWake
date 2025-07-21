//
//  HourlyWeatherCard.swift

import SwiftUI
import WeatherKit

struct HourlyWeatherCard: View {
    let hour: HourWeather
    let useCelsius: Bool
    
    private var timeString: String {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if this hour is the current hour
        if calendar.isDate(hour.date, equalTo: now, toGranularity: .hour) {
            return "Now"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: hour.date).lowercased()
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Time label with improved readability
            Text(timeString)
                .font(.caption)
                .fontWeight(timeString == "Now" ? .semibold : .medium)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            
            // Weather icon
            Image(systemName: hour.symbolName)
                .font(.title2)
                .foregroundColor(.white)
                .symbolRenderingMode(.multicolor)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            
            // Precipitation chance (only if > 0)
            if hour.precipitationChance > 0 &&
               (hour.symbolName.contains("rain") || hour.symbolName.contains("snow") ||
                hour.symbolName.contains("drizzle") || hour.symbolName.contains("bolt") ||
                hour.symbolName.contains("sleet") || hour.symbolName.contains("hail")) {
                Text("\(Int(hour.precipitationChance * 100))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
            
            // Temperature
            let temp = useCelsius ?
                hour.temperature.converted(to: .celsius).value :
                hour.temperature.converted(to: .fahrenheit).value
            
            Text("\(Int(temp))°")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
        }
        .frame(width: 60)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .opacity(timeString == "Now" ? 0.4 : 0.25)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(timeString == "Now" ? 0.6 : 0.3), lineWidth: 1)
        )
    }
}
