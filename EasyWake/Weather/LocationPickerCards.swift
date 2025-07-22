//
//  LocationPickerCards.swift

import SwiftUI
import WeatherKit
import CoreLocation
import MapKit

struct FavoriteLocationCard: View {
    let favorite: WeatherViewModel.FavoriteLocation
    let weatherPreview: WeatherKit.CurrentWeather?
    let dailyWeather: WeatherKit.DayWeather?
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    
    private var timeInfo: (timeString: String, isDaytime: Bool) {
        let timeZone = getTimeZone(for: favorite)
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
    
    private func getTimeZone(for location: WeatherViewModel.FavoriteLocation) -> TimeZone {
        // US Continental boundaries
        if location.lat >= 25.0 && location.lat <= 49.0 && location.lon >= -125.0 && location.lon <= -66.0 {
            if location.lon >= -84.0 {
                return TimeZone(identifier: "America/New_York") ?? TimeZone.current
            } else if location.lon >= -104.0 {
                return TimeZone(identifier: "America/Chicago") ?? TimeZone.current
            } else if location.lon >= -115.0 {
                return TimeZone(identifier: "America/Denver") ?? TimeZone.current
            } else {
                return TimeZone(identifier: "America/Los_Angeles") ?? TimeZone.current
            }
        }
        
        // International locations
        let name = location.name.lowercased()
        if name.contains("london") {
            return TimeZone(identifier: "Europe/London") ?? TimeZone.current
        } else if name.contains("paris") {
            return TimeZone(identifier: "Europe/Paris") ?? TimeZone.current
        } else if name.contains("tokyo") {
            return TimeZone(identifier: "Asia/Tokyo") ?? TimeZone.current
        } else if name.contains("sydney") {
            return TimeZone(identifier: "Australia/Sydney") ?? TimeZone.current
        } else if name.contains("mumbai") || name.contains("delhi") || name.contains("bangalore") {
            return TimeZone(identifier: "Asia/Kolkata") ?? TimeZone.current
        }
        
        // Fallback to longitude-based approximation
        let timeZoneOffset = Int(round(location.lon / 15.0))
        return TimeZone(secondsFromGMT: timeZoneOffset * 3600) ?? TimeZone.current
    }
    
    private var backgroundGradient: LinearGradient {
        if let weather = weatherPreview {
            if timeInfo.isDaytime {
                // Daytime gradients
                if weather.symbolName.contains("sun") {
                    return LinearGradient(
                        colors: [Color.customBlue.opacity(0.9), Color.cyan.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else if weather.symbolName.contains("cloud") {
                    return LinearGradient(
                        colors: [Color.gray.opacity(0.8), Color.customBlue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else if weather.symbolName.contains("rain") {
                    return LinearGradient(
                        colors: [Color.gray.opacity(0.9), Color.customBlue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                // Nighttime gradients
                return LinearGradient(
                    colors: [Color.indigo.opacity(0.95), Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        
        return LinearGradient(
            colors: [Color.customBlue.opacity(0.8), Color.cyan.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            if timeInfo.isDaytime {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.white.opacity(0.08))
                    .offset(x: 60, y: -10)
            }
            
            VStack(spacing: 0) {
                // Top row
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(favorite.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        
                        HStack(spacing: 6) {
                            Text(timeInfo.timeString)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.95))
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            
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
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: onToggleFavorite) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.yellow)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Remove from favorites")
                }
                
                Spacer()
                
                // Bottom row
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let weather = weatherPreview {
                            Text(weather.condition.description)
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.95))
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            
                            if let daily = dailyWeather {
                                let highTemp = Int(daily.highTemperature.converted(to: .fahrenheit).value)
                                let lowTemp = Int(daily.lowTemperature.converted(to: .fahrenheit).value)
                                Text("H:\(highTemp)° L:\(lowTemp)°")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        if let weather = weatherPreview {
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .symbolRenderingMode(.multicolor)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            
                            let temp = Int(weather.temperature.converted(to: .fahrenheit).value)
                            Text("\(temp)°")
                                .font(.system(size: 52, weight: .ultraLight))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        .onTapGesture(perform: onTap)
        .accessibilityLabel("\(favorite.name) weather")
        .accessibilityHint("Tap to view detailed weather for this location")
    }
}
