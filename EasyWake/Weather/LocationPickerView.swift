//
//  LocationPickerView.swift

//  LocationPickerView.swift

import SwiftUI
import MapKit
import WeatherKit

struct LocationPickerView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @StateObject private var searchService = LocationSearchService()
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var favoriteWeatherPreviews: [String: WeatherKit.CurrentWeather] = [:]
    @State private var favoriteDailyWeather: [String: WeatherKit.DayWeather] = [:]
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Black background for contrast
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    SearchSection
                    contentScrollView
                }
            }
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                }
                
                // Clear search button when searching
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !searchText.isEmpty {
                        Button("Clear") {
                            clearSearch()
                        }
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                    }
                }
            }
        }
        .task {
            await loadFavoriteWeatherPreviews()
        }
        .onChange(of: viewModel.favorites) { _, _ in
            Task {
                await loadFavoriteWeatherPreviews()
            }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                searchService.clearSearch()
            } else {
                searchService.searchLocations(newValue)
            }
        }
    }
    
    // MARK: -  Search Section
    private var SearchSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search for a city or airport", text: $searchText)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Search for weather locations")
                    .accessibilityHint("Enter a city name to find weather information")
                
                // Loading indicator
                if searchService.searchState.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.gray)
                        .accessibilityLabel("Searching")
                }
                
                // Clear button
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Search status or spell correction banner
            searchStatusBanner
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    // MARK: - Search Status Banner
    @ViewBuilder
    private var searchStatusBanner: some View {
        switch searchService.searchState {
        case .error(let message):
            ErrorBanner(message: message) {
                searchService.searchLocations(searchText)
            }
            
        case .completed(let results) where results.isEmpty && !searchText.isEmpty:
            NoResultsBanner(query: searchText)
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Content Scroll View
    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Search results section
                if case .completed(let results) = searchService.searchState, !results.isEmpty {
                    searchResultsSection(results)
                }
                
                // Favorites section (only show when not searching or no results)
                if searchText.isEmpty {
                    favoritesSection
                }
                else if case .completed(let results) = searchService.searchState, results.isEmpty {
                    favoritesSection
                }
                
                Spacer().frame(height: 120)
            }
        }
    }
    
    // MARK: - Search Results Section
    private func searchResultsSection(_ results: [SearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text(searchService.showSpellingSuggestions ? "Search Results" : "Locations")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                
                Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            
            // Spell correction notice
            if searchService.showSpellingSuggestions {
                SpellCorrectionNotice()
                    .padding(.horizontal, 28)
            }
            
            // Results list
            VStack(spacing: 12) {
                ForEach(results) { result in
                    SearchResultCard(
                        result: result,
                        isFavorite: isFavorite(result.mapItem),
                        onTap: { handleSearchResultTap(result) },
                        onToggleFavorite: { handleSearchResultToggle(result) }
                    )
                }
            }
            .padding(.horizontal, 28)
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Favorites Section
    @ViewBuilder
    private var favoritesSection: some View {
        if !viewModel.favorites.isEmpty {
            VStack(spacing: 16) {
                // Show different header based on search state
                HStack {
                    Text(searchText.isEmpty ? "Favorites" : "Your Saved Locations")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, searchText.isEmpty ? 8 : 24)
                
                ForEach(viewModel.favorites) { fav in
                    FavoriteLocationCard(
                        favorite: fav,
                        weatherPreview: favoriteWeatherPreviews[fav.id],
                        dailyWeather: favoriteDailyWeather[fav.id],
                        onTap: { handleFavoriteTap(fav) },
                        onToggleFavorite: { handleFavoriteToggle(fav) }
                    )
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Helper Methods
    private func clearSearch() {
        searchText = ""
        searchService.clearSearch()
        isSearchFocused = false
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func isFavorite(_ mapItem: MKMapItem) -> Bool {
        let coord = mapItem.placemark.coordinate
        return viewModel.favorites.contains { $0.id == "\(coord.latitude),\(coord.longitude)" }
    }

    private func handleFavoriteTap(_ fav: WeatherViewModel.FavoriteLocation) {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: fav.lat, longitude: fav.lon)))
        viewModel.selectLocation(mapItem)
    }
    
    private func handleFavoriteToggle(_ fav: WeatherViewModel.FavoriteLocation) {
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
        viewModel.toggleFavorite(
            name: fav.name,
            coordinate: CLLocationCoordinate2D(latitude: fav.lat, longitude: fav.lon)
        )
    }
    
    private func handleSearchResultTap(_ result: SearchResult) {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
        
        // Auto-add to favorites if not already there
        let name = result.displayName
        if !isFavorite(result.mapItem) {
            viewModel.toggleFavorite(name: name, coordinate: result.mapItem.placemark.coordinate)
            Task {
                await loadWeatherForNewFavorite(name: name, coordinate: result.mapItem.placemark.coordinate)
            }
        }
        
        viewModel.selectLocation(result.mapItem)
        dismiss()
    }
    
    private func handleSearchResultToggle(_ result: SearchResult) {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
        let name = result.displayName
        viewModel.toggleFavorite(name: name, coordinate: result.mapItem.placemark.coordinate)
        
        if !isFavorite(result.mapItem) {
            Task {
                await loadWeatherForNewFavorite(name: name, coordinate: result.mapItem.placemark.coordinate)
            }
        }
    }

    private func loadFavoriteWeatherPreviews() async {
        for favorite in viewModel.favorites {
            if let weather = await viewModel.previewWeather(for: favorite) {
                await MainActor.run {
                    favoriteWeatherPreviews[favorite.id] = weather
                }
            }
            
            if let dailyWeather = await viewModel.previewDailyWeather(for: favorite) {
                await MainActor.run {
                    favoriteDailyWeather[favorite.id] = dailyWeather
                }
            }
        }
    }
    
    private func loadWeatherForNewFavorite(name: String, coordinate: CLLocationCoordinate2D) async {
        let fav = WeatherViewModel.FavoriteLocation(name: name, lat: coordinate.latitude, lon: coordinate.longitude)
        
        if let weather = await viewModel.previewWeather(for: fav) {
            await MainActor.run {
                favoriteWeatherPreviews[fav.id] = weather
            }
        }
        
        if let dailyWeather = await viewModel.previewDailyWeather(for: fav) {
            await MainActor.run {
                favoriteDailyWeather[fav.id] = dailyWeather
            }
        }
    }
}

// MARK: - Supporting Views

struct SearchResultCard: View {
    let result: SearchResult       // your existing model
    let isFavorite: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    // MARK: – Computed display name
    private var displayName: String {
        let mapItem = result.mapItem
        return mapItem.name
            ?? mapItem.placemark.locality
            ?? result.displayName
    }

    private var locationDescription: String? {
        let p = result.mapItem.placemark
        if let loc = p.locality,
           let area = p.administrativeArea,
           let country = p.country {
            return "\(loc), \(area), \(country)"
        } else if let country = p.country {
            return country
        }
        return nil
    }

    // MARK: – “Suggested” badge
    @ViewBuilder
    private var suggestionBadge: some View {
        if result.isSpellCorrected {
            Text("suggested")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(4)
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(displayName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .lineLimit(1)

                    // Subtitle / location description
                    if let desc = locationDescription {
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            .lineLimit(1)
                    }

                    // Optional suggestion reason (italic)
                    if let reason = result.suggestionReason {
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .italic()
                    }

                    // “Suggested” pill
                    suggestionBadge
                }

                Spacer(minLength: 12)

                // Favorite star
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isFavorite ? .yellow : .gray)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite
                    ? "Remove from favorites"
                    : "Add to favorites")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Select \(displayName)")
        .accessibilityHint("Tap to view weather for this location")
    }
}

struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.body)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Search Error")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button("Retry", action: onRetry)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search error: \(message)")
        .accessibilityHint("Tap retry to search again")
    }
}

struct NoResultsBanner: View {
    let query: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.body)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("No results found")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("Try a different spelling or search term")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No results found for \(query)")
    }
}

struct SpellCorrectionNotice: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(.orange)
                .font(.caption)
            
            Text("Including suggested spellings")
                .font(.caption)
                .foregroundColor(.orange)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.1))
        )
    }
}
