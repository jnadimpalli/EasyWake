// Models/TravelMethod.swift

enum TravelMethod: String, Codable, CaseIterable {
    case drive = "drive"
    case publicTransit = "public_transit"
    case walk = "walk"
    case bike = "bike"
    
    var displayName: String {
        switch self {
        case .drive: return "Drive"
        case .publicTransit: return "Public Transit"
        case .walk: return "Walk"
        case .bike: return "Bike"
        }
    }
    
    var icon: String {
        switch self {
        case .drive: return "car.fill"
        case .publicTransit: return "bus.fill"
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        }
    }
}
