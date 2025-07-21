// Models/Address.swift

import Foundation
import SwiftUI

struct Address: Identifiable, Codable {
    enum Label: String, Codable, CaseIterable {
        case home = "home"
        case work = "work"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .home: return "Home"
            case .work: return "Work"
            case .custom: return "Custom"
            }
        }
    }
    
    var id = UUID()
    var label: Label
    var customLabel: String?
    var street: String
    var city: String
    var zip: String
    var state: String
    
    // Icon support for custom locations
    var iconName: String?
    var iconColorHex: String? // Store color as hex string for Codable
    
    // Computed property for icon color
    var iconColor: Color? {
        get {
            guard let hex = iconColorHex else { return nil }
            return Color(hex: hex)
        }
        set {
            iconColorHex = newValue?.toHex()
        }
    }
    
    var isValid: Bool {
      let s = street.trimmingCharacters(in: .whitespacesAndNewlines)
      let c = city.trimmingCharacters(in: .whitespacesAndNewlines)
      let z = zip.trimmingCharacters(in: .whitespacesAndNewlines)
      return !s.isEmpty && !c.isEmpty
          && z.count == 5 && z.allSatisfy(\.isNumber)
          && state != "Select"
    }
    
    var displayAddress: String {
        "\(street), \(city), \(state) \(zip)"
    }
    
    var shortDisplayAddress: String {
        "\(city), \(state)"
    }
    
    // Custom initializer
    init(label: Label, customLabel: String? = nil, street: String, city: String, zip: String, state: String, iconName: String? = nil, iconColor: Color? = nil) {
        self.label = label
        self.customLabel = customLabel
        self.street = street
        self.city = city
        self.zip = zip
        self.state = state
        self.iconName = iconName
        self.iconColor = iconColor
    }
    
    // Codable implementation
    enum CodingKeys: String, CodingKey {
        case id, label, customLabel, street, city, zip, state, iconName, iconColorHex
    }
}

// Color extension for hex conversion
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = Float(components.count > 3 ? components[3] : 1.0)
        
        if a != 1.0 {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(a * 255), lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
