/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

// CoreLocation is needed for CLLocationManagerDelegate.
import CoreLocation
import heresdk
import SwiftUI

class PositioningExample: NSObject, CLLocationManagerDelegate, LocationDelegate, LocationStatusDelegate {

    private static let defaultGeoCoordinates = GeoCoordinates(latitude: 52.520798, longitude: 13.409408)
    private static let defaultCameraDistance = 1000.0

    private var mapView: MapView
    private var locationEngine: LocationEngine
    private var locationIndicator: LocationIndicator!

    // This core location instance is needed for requesting location authorization from iOS.
    private let clLocationManager = CLLocationManager()

    init(_ mapView: MapView) {
        self.mapView = mapView

        // Create instance of location engine.
        do {
            try locationEngine = LocationEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize LocationEngine. Cause: \(engineInstantiationError)")
        }

        super.init()

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }

    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        addMyInitialLocation()
        startLocating()
    }

    // A last known location may be already available after initialization of the location engine.
    private func addMyInitialLocation() {
        if let lastLocation = locationEngine.lastKnownLocation {
            addMyLocationToMap(myLocation: lastLocation)
        } else {
            // Fallback: It seems, this app never received a location signal so far.
            // Maybe this is the 1st time the app starts?
            var defaultLocation = Location(coordinates: PositioningExample.defaultGeoCoordinates)
            defaultLocation.time = Date()
            addMyLocationToMap(myLocation: defaultLocation)
        }
    }

    private func startLocating() {
        // Enable background updates.
        _ = locationEngine.setBackgroundLocationAllowed(allowed: true)
        _ = locationEngine.setBackgroundLocationIndicatorVisible(visible: true)

        // Set delegates and start location engine.
        locationEngine.addLocationStatusDelegate(locationStatusDelegate: self)
        locationEngine.addLocationDelegate(locationDelegate: self)

        // Make sure to add the required location permissions in the "Info.plist" file.
        // Xcode contains already "Info.plist values" in the "Build Settings" tab.
        // You can add new ones in a separate file (these will be combined with the existing values):
        // 1. In Xcode, click on your project in the Project Navigator.
        // 2. Under Targets, select the "Info" tab.
        // 3. Expand "URL Types (1)" and click on the "+" button.
        // 4. A new Info.plist file will appear in the project. You can edit now the values.

        // Start the location engine and check if permissions are missing.
        if locationEngine.start(locationAccuracy: .bestAvailable) == .missingPermissions {
            // Location permissions need to be requested from iOS. The user needs to accept
            // to be able to receive location signals.
            requestLocationAuthorization()
        }
    }

    public func requestLocationAuthorization() {
        clLocationManager.delegate = self

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {

            let alert = UIAlertController(
                title: "Location access required",
                message: "This example requires location access to function correctly, please accept location access in following dialog.",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                // Handle OK button action.
                self.clLocationManager.requestWhenInUseAuthorization()
                alert.dismiss(animated: true, completion: nil)
            }))

            rootViewController.present(alert, animated: true, completion: nil)
        }
    }

    // Optional protocol invoked by CLLocationManagerDelegate when user permissions have been changed.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Start location engine again and check if permissions have been granted.
        startLocating()
    }

    deinit {
        // Called when the ContentView holding an instance of this class will be deallocated.
        stopLocating()
    }

    public func stopLocating() {
        // Remove delegates and stop location engine.
        locationEngine.removeLocationDelegate(locationDelegate: self)
        locationEngine.removeLocationStatusDelegate(locationStatusDelegate: self)
        locationEngine.stop()
    }

    // Conform to LocationDelegate protocol.
    // Called by the LocationEngine when a new location signal is available.
    func onLocationUpdated(_ location: heresdk.Location) {
        updateMyLocationOnMap(myLocation: location)
        print("Location updated: \(location.coordinates)")
        print("Horizontal accuracy (m): \(String(describing: location.horizontalAccuracyInMeters))")
        print("Altitude (m): \(String(describing: location.verticalAccuracyInMeters))")
    }

    private func updateMyLocationOnMap(myLocation: Location) {
        // Update location indicator.
        locationIndicator.updateLocation(myLocation)
        // Point camera to current location.
        mapView.camera.lookAt(point: myLocation.coordinates)
    }

    // Conform to LocationStatusDelegate protocol.
    func onStatusChanged(locationEngineStatus: LocationEngineStatus) {
        print("Location engine status: \(locationEngineStatus)")
    }

    // Conform to LocationStatusDelegate protocol.
    func onFeaturesNotAvailable(features: [LocationFeature]) {
        for feature in features {
            print("Location feature not available: '%s'", String(describing: feature))
        }
    }

    private func addMyLocationToMap(myLocation: Location) {
        // Setup location indicator.
        locationIndicator = LocationIndicator()

        // Enable a halo to indicate the horizontal accuracy.
        locationIndicator.isAccuracyVisualized = true
        locationIndicator.locationIndicatorStyle = .pedestrian;
        locationIndicator.updateLocation(myLocation)
        locationIndicator.enable(for: mapView)

        // Point camera to current location.
        let distanceInMeters = MapMeasure(kind: .distance, value: PositioningExample.defaultCameraDistance)
        mapView.camera.lookAt(point: myLocation.coordinates,
                              zoom: distanceInMeters)
    }
}
