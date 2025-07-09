import SwiftUI
import MapKit
import CoreLocation

struct TrafficMapView: UIViewRepresentable {
  @Binding var region: MKCoordinateRegion

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: Context) -> MKMapView {
    let map = MKMapView(frame: .zero)
    map.showsUserLocation = true
    map.showsTraffic     = true
    map.delegate         = context.coordinator

    // kick off CoreLocation
    let lm = context.coordinator.locationManager
    lm.requestWhenInUseAuthorization()
    lm.startUpdatingLocation()

    return map
  }

  func updateUIView(_ map: MKMapView, context: Context) {
    // whenever our @Binding region changes, recenter the map
    map.setRegion(region, animated: true)
  }

  class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
    var parent: TrafficMapView
    let locationManager = CLLocationManager()

    init(_ parent: TrafficMapView) {
      self.parent = parent
      super.init()
      locationManager.delegate = self
      locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
      guard let loc = locations.last else { return }
      let newRegion = MKCoordinateRegion(
        center: loc.coordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
      )

      // push it back into our binding so updateUIView fires
      DispatchQueue.main.async {
        self.parent.region = newRegion
      }
    }
  }
}
