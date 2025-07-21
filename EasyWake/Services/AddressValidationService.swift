// AddressValidationService.swift

import Foundation
import CoreLocation
import MapKit

enum AddressError: LocalizedError {
    case invalidAddress
    case geocodingFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "The address entered could not be found. Please check and try again."
        case .geocodingFailed:
            return "Failed to validate the address. Please try again."
        case .networkError:
            return "Network error. Please check your connection and try again."
        }
    }
}

class AddressValidationService {
    static let shared = AddressValidationService()
    private let geocoder = CLGeocoder()
    
    private init() {}
    
    func validate(
        street: String,
        city: String,
        state: String,
        zip: String,
        label: String? = nil
    ) async throws -> ValidatedAddress {
        // Construct address string
        let addressString = "\(street), \(city), \(state) \(zip)"
        
        do {
            // Geocode the address
            let placemarks = try await geocoder.geocodeAddressString(addressString)
            
            guard let placemark = placemarks.first,
                  let location = placemark.location else {
                throw AddressError.invalidAddress
            }
            
            // Create formatted address
            let formattedAddress = [
                placemark.subThoroughfare,
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.postalCode
            ].compactMap { $0 }.joined(separator: ", ")
            
            return ValidatedAddress(
                label: label,
                street: street,
                city: city,
                state: state,
                zip: zip,
                formattedAddress: formattedAddress.isEmpty ? addressString : formattedAddress,
                coordinates: ValidatedAddress.Coordinates(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            )
        } catch {
            if error is AddressError {
                throw error
            }
            throw AddressError.geocodingFailed
        }
    }
    
    // Validate an existing address (for migration or updates)
    func validateExisting(_ address: ValidatedAddress) async throws -> ValidatedAddress {
        return try await validate(
            street: address.street,
            city: address.city,
            state: address.state,
            zip: address.zip,
            label: address.label
        )
    }
}
