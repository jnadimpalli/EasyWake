// RouteAnalysisService.swift

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Route Relevance Models
struct RouteRelevance {
    let alarm: Alarm
    let relevanceType: RelevanceType
    let distance: CLLocationDistance
    let explanation: String
    
    enum RelevanceType {
        case nearStart(CLLocationDistance)
        case nearDestination(CLLocationDistance)
        case alongRoute(CLLocationDistance)
        case weatherImpact
        
        var priority: Int {
            switch self {
            case .nearStart: return 3
            case .nearDestination: return 4
            case .alongRoute: return 2
            case .weatherImpact: return 1
            }
        }
        
        var icon: String {
            switch self {
            case .nearStart: return "house.fill"
            case .nearDestination: return "mappin.and.ellipse"
            case .alongRoute: return "road.lanes"
            case .weatherImpact: return "cloud.bolt.rain.fill"
            }
        }
    }
}

// MARK: - Analysis State
enum RouteAnalysisState {
    case idle
    case analyzing
    case completed([RouteRelevance])
    case error(String)
    
    var isAnalyzing: Bool {
        if case .analyzing = self { return true }
        return false
    }
}

// MARK: - Route Analysis Service
@MainActor
class RouteAnalysisService: ObservableObject {
    @Published var analysisState: RouteAnalysisState = .idle
    @Published private(set) var relevantAlarms: [RouteRelevance] = []
    @Published private(set) var currentLocationName: String?
    
    public let alarmStore: AlarmStore
    private var analysisTask: Task<Void, Never>?
    
    // Configuration
    private let proximityRadius: CLLocationDistance = 25000 // 25km
    private let routeCorridorWidth: CLLocationDistance = 15000 // 15km
    private let maxConcurrentAnalyses = 3
    
    // Caching
    private var geocodeCache: [String: CLLocationCoordinate2D] = [:]
    private var routeCache: [String: [CLLocationCoordinate2D]] = [:]
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    
    init(alarmStore: AlarmStore) {
        self.alarmStore = alarmStore
    }
    
    deinit {
        analysisTask?.cancel()
    }
    
    func analyzeLocationRelevance(for coordinate: CLLocationCoordinate2D, locationName: String? = nil) {
        // Cancel previous analysis
        analysisTask?.cancel()
        
        analysisState = .analyzing
        currentLocationName = locationName
        
        analysisTask = Task {
            await performRouteAnalysis(for: coordinate)
        }
    }
    
    private func performRouteAnalysis(for searchLocation: CLLocationCoordinate2D) async {
        do {
            let smartAlarms = alarmStore.alarms.filter { $0.smartEnabled && $0.isEnabled }
            
            guard !smartAlarms.isEmpty else {
                await MainActor.run {
                    self.analysisState = .completed([])
                    self.relevantAlarms = []
                }
                return
            }
            
            // Analyze alarms in batches to avoid overwhelming the system
            var allRelevance: [RouteRelevance] = []
            let batches = smartAlarms.chunked(into: maxConcurrentAnalyses)
            
            for batch in batches {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                let batchResults = await withTaskGroup(of: RouteRelevance?.self) { group in
                    for alarm in batch {
                        group.addTask { [weak self] in
                            await self?.analyzeAlarmRelevance(
                                searchLocation: searchLocation,
                                alarm: alarm
                            )
                        }
                    }
                    
                    var results: [RouteRelevance] = []
                    for await result in group {
                        if let relevance = result {
                            results.append(relevance)
                        }
                    }
                    return results
                }
                
                allRelevance.append(contentsOf: batchResults)
            }
            
            // Sort by priority and distance
            let sortedRelevance = allRelevance.sorted { lhs, rhs in
                if lhs.relevanceType.priority != rhs.relevanceType.priority {
                    return lhs.relevanceType.priority > rhs.relevanceType.priority
                }
                return lhs.distance < rhs.distance
            }
            
            await MainActor.run {
                self.analysisState = .completed(sortedRelevance)
                self.relevantAlarms = sortedRelevance
                
                // Provide haptic feedback if relevant alarms found
                if !sortedRelevance.isEmpty {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
            
        } catch {
            await MainActor.run {
                self.analysisState = .error("Analysis failed: \(error.localizedDescription)")
                self.relevantAlarms = []
            }
        }
    }
    
    private func analyzeAlarmRelevance(
        searchLocation: CLLocationCoordinate2D,
        alarm: Alarm
    ) async -> RouteRelevance? {
        
        // Get coordinates for alarm addresses
        guard let startCoordinate = await geocodeAddress(
            street: alarm.startingAddress.street,
            city: alarm.startingAddress.city,
            state: alarm.startingAddress.state,
            zip: alarm.startingAddress.zip
        ),
        let destinationCoordinate = await geocodeAddress(
            street: alarm.destinationAddress.street,
            city: alarm.destinationAddress.city,
            state: alarm.destinationAddress.state,
            zip: alarm.destinationAddress.zip
        ) else {
            return nil
        }
        
        let searchLocationCL = CLLocation(latitude: searchLocation.latitude, longitude: searchLocation.longitude)
        let startLocationCL = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
        let destinationLocationCL = CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude)
        
        let distanceToStart = searchLocationCL.distance(from: startLocationCL)
        let distanceToDestination = searchLocationCL.distance(from: destinationLocationCL)
        
        // Check proximity to start or destination first (faster)
        if distanceToStart <= proximityRadius {
            return RouteRelevance(
                alarm: alarm,
                relevanceType: .nearStart(distanceToStart),
                distance: distanceToStart,
                explanation: "Near your starting location for \(alarm.name)"
            )
        }
        
        if distanceToDestination <= proximityRadius {
            return RouteRelevance(
                alarm: alarm,
                relevanceType: .nearDestination(distanceToDestination),
                distance: distanceToDestination,
                explanation: "Near your destination for \(alarm.name)"
            )
        }
        
        // Check if along the route (more expensive operation)
        if let routeDistance = await checkIfLocationAlongRoute(
            searchLocation: searchLocation,
            start: startCoordinate,
            destination: destinationCoordinate,
            alarm: alarm
        ) {
            return RouteRelevance(
                alarm: alarm,
                relevanceType: .alongRoute(routeDistance),
                distance: routeDistance,
                explanation: "Along your route for \(alarm.name)"
            )
        }
        
        return nil
    }
    
    private func checkIfLocationAlongRoute(
        searchLocation: CLLocationCoordinate2D,
        start: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        alarm: Alarm
    ) async -> CLLocationDistance? {
        
        let routeCacheKey = "\(start.latitude),\(start.longitude)-\(destination.latitude),\(destination.longitude)"
        
        // Check cache first
        var routeCoordinates: [CLLocationCoordinate2D]
        if let cachedRoute = routeCache[routeCacheKey] {
            routeCoordinates = cachedRoute
        } else {
            // Calculate new route
            guard let coordinates = await calculateRoute(from: start, to: destination, for: alarm) else {
                return nil
            }
            routeCoordinates = coordinates
            
            // Cache the route
            routeCache[routeCacheKey] = coordinates
            
            // Clean up old cache entries
            cleanupCacheIfNeeded()
        }
        
        // Find minimum distance to route
        let searchLocationCL = CLLocation(latitude: searchLocation.latitude, longitude: searchLocation.longitude)
        var minDistance = CLLocationDistance.greatestFiniteMagnitude
        
        for routeCoordinate in routeCoordinates {
            let routeLocation = CLLocation(latitude: routeCoordinate.latitude, longitude: routeCoordinate.longitude)
            let distance = searchLocationCL.distance(from: routeLocation)
            minDistance = min(minDistance, distance)
            
            // Early exit if we find a very close point
            if distance <= routeCorridorWidth {
                return distance
            }
        }
        
        return minDistance <= routeCorridorWidth ? minDistance : nil
    }
    
    private func calculateRoute(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        for alarm: Alarm
    ) async -> [CLLocationCoordinate2D]? {
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        
        // Set transport type based on alarm preferences
        switch alarm.smartEnabled {
        case true:
            request.transportType = .automobile // Default for smart alarms
        case false:
            request.transportType = .automobile
        }
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            guard let route = response.routes.first else { return nil }
            
            return extractCoordinatesFromRoute(route)
        } catch {
            print("Route calculation error for alarm \(alarm.name): \(error)")
            return nil
        }
    }
    
    private func extractCoordinatesFromRoute(_ route: MKRoute) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Sample points along the route steps
        let totalSteps = route.steps.count
        let samplingInterval = max(1, totalSteps / 20) // Sample ~20 points max
        
        for i in stride(from: 0, to: totalSteps, by: samplingInterval) {
            let step = route.steps[i]
            let polyline = step.polyline
            
            if polyline.pointCount > 0 {
                let points = polyline.points()
                let coordinate = points[0].coordinate
                coordinates.append(coordinate)
            }
        }
        
        // Always include the final destination
        if let lastStep = route.steps.last, lastStep.polyline.pointCount > 0 {
            let points = lastStep.polyline.points()
            let lastCoordinate = points[lastStep.polyline.pointCount - 1].coordinate
            coordinates.append(lastCoordinate)
        }
        
        return coordinates
    }
    
    private func geocodeAddress(street: String, city: String, state: String, zip: String) async -> CLLocationCoordinate2D? {
        let addressString = "\(street), \(city), \(state) \(zip)".trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check cache first
        if let cached = geocodeCache[addressString] {
            return cached
        }
        
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(addressString)
            guard let coordinate = placemarks.first?.location?.coordinate else {
                return nil
            }
            
            // Cache the result
            geocodeCache[addressString] = coordinate
            cleanupCacheIfNeeded()
            
            return coordinate
        } catch {
            print("Geocoding error for \(addressString): \(error)")
            return nil
        }
    }
    
    private func cleanupCacheIfNeeded() {
        // Simple cache cleanup - in production you'd want timestamp-based expiration
        if geocodeCache.count > 50 {
            let keysToRemove = Array(geocodeCache.keys.prefix(10))
            for key in keysToRemove {
                geocodeCache.removeValue(forKey: key)
            }
        }
        
        if routeCache.count > 20 {
            let keysToRemove = Array(routeCache.keys.prefix(5))
            for key in keysToRemove {
                routeCache.removeValue(forKey: key)
            }
        }
    }
    
    func clearAnalysis() {
        analysisTask?.cancel()
        analysisState = .idle
        relevantAlarms = []
        currentLocationName = nil
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

