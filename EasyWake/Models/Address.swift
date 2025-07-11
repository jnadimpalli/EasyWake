// Models/Address.swift

import Foundation
import CoreLocation

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
    var customLabel: String?    // for .custom
    var street: String
    var city: String
    var zip: String
    var state: String
    
    var isValid: Bool {
        !street.isEmpty && !city.isEmpty &&
        zip.count == 5 && zip.allSatisfy(\.isNumber) &&
        state != "Select" && !state.isEmpty
    }
    
    var displayAddress: String {
        "\(street), \(city), \(state) \(zip)"
    }
    
    var shortDisplayAddress: String {
        "\(city), \(state)"
    }
}
