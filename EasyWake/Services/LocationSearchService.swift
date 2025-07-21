// LocationSearchService.swift

import Foundation
import MapKit
import CoreLocation
import Combine

// MARK: -  Search Result Model
struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let mapItem: MKMapItem
    let relevanceScore: Double
    let isSpellCorrected: Bool
    let originalQuery: String?
    let suggestionReason: String?
    
    var displayName: String {
        mapItem.name ?? mapItem.placemark.locality ?? "Unknown Location"
    }
    
    var subtitle: String {
        var components: [String] = []
        
        if let locality = mapItem.placemark.locality {
            components.append(locality)
        }
        if let state = mapItem.placemark.administrativeArea {
            components.append(state)
        }
        if let country = mapItem.placemark.country {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
    
    var accessibilityLabel: String {
        if isSpellCorrected {
            return "Suggested result: \(displayName), \(subtitle)"
        } else {
            return "\(displayName), \(subtitle)"
        }
    }
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Search State
enum SearchState {
    case idle
    case searching
    case completed([SearchResult])
    case error(String)
    
    var isLoading: Bool {
        if case .searching = self { return true }
        return false
    }
}

// MARK: -  Location Search Service
@MainActor
class LocationSearchService: ObservableObject {
    @Published var searchState: SearchState = .idle
    @Published var showSpellingSuggestions = false
    @Published private(set) var searchResults: [SearchResult] = []
    
    private var searchCancellable: AnyCancellable?
    private let minimumQueryLength = 2
    private let maxResults = 8
    private let debounceDelay: TimeInterval = 0.5
    
    // MARK: - Common Spelling Corrections
    private let commonCityCorrections: [String: String] = [
        "washingon": "washington",
        "philadelfia": "philadelphia",
        "philadelphia": "philadelphia",
        "sandiego": "san diego",
        "sanfransisco": "san francisco",
        "losangeles": "los angeles",
        "newyork": "new york",
        "lasvegas": "las vegas",
        "saltlakecity": "salt lake city",
        "fortworth": "fort worth",
        "elpaso": "el paso",
        "colorado springs": "colorado springs",
        "virginia beach": "virginia beach",
        "atlantacity": "atlantic city",
        "kansascity": "kansas city",
        "oklahomacity": "oklahoma city",
        "jersycity": "jersey city",
        "neworleans": "new orleans"
    ]
    
    func searchLocations(_ query: String) {
        // Cancel previous search
        searchCancellable?.cancel()
        
        guard query.count >= minimumQueryLength else {
            searchState = .idle
            searchResults = []
            showSpellingSuggestions = false
            return
        }
        
        searchCancellable = Future<[SearchResult], Error> { [weak self] promise in
            Task {
                await self?.performSearch(query: query, promise: promise)
            }
        }
        .debounce(for: .seconds(debounceDelay), scheduler: DispatchQueue.main)
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.searchState = .error("Search failed: \(error.localizedDescription)")
                    self?.showSpellingSuggestions = false
                }
            },
            receiveValue: { [weak self] results in
                self?.handleSearchResults(results)
            }
        )
        
        searchState = .searching
    }
    
    private func performSearch(query: String, promise: @escaping (Result<[SearchResult], Error>) -> Void) async {
        do {
            // 1. Perform exact search
            let exactResults = try await performMapSearch(query: query, isSpellCorrected: false)
            
            // 2. If insufficient results, try spell correction
            var allResults = exactResults
            if exactResults.count < 3 {
                let correctedResults = try await performSpellCorrectedSearch(query: query)
                allResults.append(contentsOf: correctedResults)
            }
            
            // 3. Deduplicate, sort, and limit results
            let finalResults = deduplicateAndSort(allResults)
            promise(.success(Array(finalResults.prefix(maxResults))))
            
        } catch {
            promise(.failure(error))
        }
    }
    
    private func performMapSearch(query: String, isSpellCorrected: Bool, originalQuery: String? = nil) async throws -> [SearchResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        return response.mapItems.map { mapItem in
            SearchResult(
                mapItem: mapItem,
                relevanceScore: calculateRelevanceScore(mapItem: mapItem, query: query),
                isSpellCorrected: isSpellCorrected,
                originalQuery: originalQuery,
                suggestionReason: isSpellCorrected ? "Did you mean \"\(query)\"?" : nil
            )
        }
    }
    
    private func performSpellCorrectedSearch(query: String) async throws -> [SearchResult] {
        let suggestions = generateSpellingSuggestions(for: query)
        var correctedResults: [SearchResult] = []
        
        // Limit to top 2 spelling suggestions to avoid overwhelming the user
        for suggestion in suggestions.prefix(2) {
            let suggestionResults = try await performMapSearch(
                query: suggestion,
                isSpellCorrected: true,
                originalQuery: query
            )
            
            // Reduce relevance score for spell-corrected results
            let adjustedResults = suggestionResults.map { result in
                SearchResult(
                    mapItem: result.mapItem,
                    relevanceScore: result.relevanceScore * 0.7,
                    isSpellCorrected: true,
                    originalQuery: query,
                    suggestionReason: "Did you mean \"\(suggestion)\"?"
                )
            }
            correctedResults.append(contentsOf: adjustedResults)
        }
        
        return correctedResults
    }
    
    private func generateSpellingSuggestions(for query: String) -> [String] {
        var suggestions: [String] = []
        let lowercaseQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Check direct corrections
        if let correction = commonCityCorrections[lowercaseQuery] {
            suggestions.append(correction)
        }
        
        // 2. Check for partial matches
        for (typo, correction) in commonCityCorrections {
            if lowercaseQuery.contains(typo) || typo.contains(lowercaseQuery) {
                suggestions.append(correction)
            }
        }
        
        // 3. Add space variations for run-together words
        if !query.contains(" ") && query.count >= 6 {
            // Try splitting at various points
            for splitPoint in 3..<(query.count - 2) {
                let index = query.index(query.startIndex, offsetBy: splitPoint)
                let firstPart = String(query[..<index])
                let secondPart = String(query[index...])
                suggestions.append("\(firstPart) \(secondPart)")
            }
        }
        
        // 4. Remove duplicates and sort by relevance
        return Array(Set(suggestions)).sorted { suggestion1, suggestion2 in
            // Prefer shorter suggestions and exact matches
            if suggestion1.count != suggestion2.count {
                return suggestion1.count < suggestion2.count
            }
            return suggestion1 < suggestion2
        }
    }
    
    private func calculateRelevanceScore(mapItem: MKMapItem, query: String) -> Double {
        var score = 1.0
        let queryLowercased = query.lowercased()
        
        // Exact name match gets highest score
        if let name = mapItem.name?.lowercased() {
            if name == queryLowercased {
                score += 5.0
            } else if name.hasPrefix(queryLowercased) {
                score += 3.0
            } else if name.contains(queryLowercased) {
                score += 2.0
            }
        }
        
        // Locality match
        if let locality = mapItem.placemark.locality?.lowercased() {
            if locality == queryLowercased {
                score += 4.0
            } else if locality.hasPrefix(queryLowercased) {
                score += 2.5
            } else if locality.contains(queryLowercased) {
                score += 1.5
            }
        }
        
        // Administrative area match
        if let adminArea = mapItem.placemark.administrativeArea?.lowercased() {
            if adminArea.contains(queryLowercased) {
                score += 1.0
            }
        }
        
        // Prefer places with more complete address information
        if mapItem.placemark.locality != nil { score += 0.5 }
        if mapItem.placemark.administrativeArea != nil { score += 0.3 }
        if mapItem.placemark.country != nil { score += 0.2 }
        
        return score
    }
    
    private func deduplicateAndSort(_ results: [SearchResult]) -> [SearchResult] {
        var uniqueResults: [SearchResult] = []
        var seenCoordinates: Set<String> = []
        
        let tolerance: Double = 0.001 // ~100m tolerance for coordinate matching
        
        for result in results {
            let coordinate = result.mapItem.placemark.coordinate
            let coordinateKey = "\(Int(coordinate.latitude / tolerance)),\(Int(coordinate.longitude / tolerance))"
            
            if !seenCoordinates.contains(coordinateKey) {
                seenCoordinates.insert(coordinateKey)
                uniqueResults.append(result)
            }
        }
        
        return uniqueResults.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func handleSearchResults(_ results: [SearchResult]) {
        searchResults = results
        searchState = .completed(results)
        showSpellingSuggestions = results.contains { $0.isSpellCorrected }
        
        // Provide haptic feedback for successful search
        if !results.isEmpty {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    func clearSearch() {
        searchCancellable?.cancel()
        searchState = .idle
        searchResults = []
        showSpellingSuggestions = false
    }
}
