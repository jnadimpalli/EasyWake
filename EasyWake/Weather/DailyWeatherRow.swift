//
//  DailyWeatherRow.swift

import SwiftUI
import WeatherKit

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
        HStack(spacing: 16) {
            // Day label
            Text(dayString)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 40, alignment: .leading)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            
            // Weather icon and precipitation
            VStack(spacing: 4) {
                Image(systemName: day.symbolName)
                    .font(.title3)
                    .foregroundColor(.white)
                    .symbolRenderingMode(.multicolor)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                
                if day.precipitationChance > 0 &&
                   (day.symbolName.contains("rain") || day.symbolName.contains("snow") ||
                    day.symbolName.contains("drizzle") || day.symbolName.contains("bolt") ||
                    day.symbolName.contains("sleet") || day.symbolName.contains("hail")) {
                    Text("\(Int(day.precipitationChance * 100))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                }
            }
            .frame(width: 50)
            
            Spacer()
            
            // Temperature range
            let minTemp = useCelsius ?
                day.lowTemperature.converted(to: .celsius).value :
                day.lowTemperature.converted(to: .fahrenheit).value
            
            let maxTemp = useCelsius ?
                day.highTemperature.converted(to: .celsius).value :
                day.highTemperature.converted(to: .fahrenheit).value
            
            HStack(spacing: 12) {
                // Low temperature
                Text("\(Int(minTemp))°")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    .frame(width: 35, alignment: .trailing)
                
                // Temperature range bar
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
                        // Background track
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: 4)
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)

                        // Temperature gradient
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
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    }
                }
                .frame(height: 4)
                
                // High temperature
                Text("\(Int(maxTemp))°")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    .frame(width: 35, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
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
