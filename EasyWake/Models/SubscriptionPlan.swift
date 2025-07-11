// Models/SubscriptionPlan.swift

enum SubscriptionPlan: String, Codable {
    case free = "free"
    case trial = "trial"
    case plus = "plus"
    case pro = "pro"
    
    var displayName: String {
        switch self {
        case .free: return "Free Tier"
        case .trial: return "Trial"
        case .plus: return "Plus"
        case .pro: return "Pro"
        }
    }
}
