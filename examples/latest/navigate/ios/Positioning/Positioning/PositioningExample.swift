/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

import heresdk
import UIKit

class PositioningExample: LocationDelegate, LocationStatusDelegate, LocationAuthorizationChangeDelegate {

    private static let defaultGeoCoordinates = GeoCoordinates(latitude: 52.520798, longitude: 13.409408)
    private static let defaultCameraDistance = 1000.0

    private var locationAuthorization: LocationAuthorizationDelegate
    private var locationEngine: LocationEngine
    private var mapView: MapView!
    private var mapCamera: MapCamera!
    private var locationIndicator: LocationIndicator!

    init(locationAuthorization: LocationAuthorizationDelegate) {
        self.locationAuthorization = locationAuthorization
        // Create instance of location engine.
        do {
            try locationEngine = LocationEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize LocationEngine. Cause: \(engineInstantiationError)")
        }
    }

    func onMapSceneLoaded(mapView: MapView) {
        self.mapView = mapView
        mapCamera = mapView.camera
        if let lastLocation = locationEngine.lastKnownLocation {
            addMyLocationToMap(myLocation: lastLocation)
        } else {
            let defaultLocation = Location(coordinates: PositioningExample.defaultGeoCoordinates,
                                           timestamp: Date())
            addMyLocationToMap(myLocation: defaultLocation)
        }
        locationAuthorization.authorizationChangeDelegate = self
        startLocating()
    }

    deinit {
        stopLocating()
    }

    func locationAuthorizatioChanged(granted: Bool) {
        if granted {
            startLocating()
        }
    }

    private func startLocating() {
        // Set delegates and start location engine.
        locationEngine.addLocationStatusDelegate(locationStatusDelegate: self)
        locationEngine.addLocationDelegate(locationDelegate: self)
        if locationEngine.start(locationAccuracy: .bestAvailable) == .missingPermissions {
            locationAuthorization.requestLocationAuthorization()
        }
    }

    public func stopLocating() {
        // Remove delegates and stop location engine.
        locationEngine.removeLocationDelegate(locationDelegate: self)
        locationEngine.removeLocationStatusDelegate(locationStatusDelegate: self)
        locationEngine.stop()
    }

    func onLocationUpdated(_ location: heresdk.Location) {
        updateMyLocationOnMap(myLocation: location)
        print("Location updated: \(location.coordinates)")
        print("Horizontal accuracy (m): \(String(describing: location.horizontalAccuracyInMeters))")
        print("Altitude (m): \(String(describing: location.verticalAccuracyInMeters))")
    }

    func onStatusChanged(locationEngineStatus: LocationEngineStatus) {
        print("Location engine status: \(locationEngineStatus)")
    }

    func onFeaturesNotAvailable(features: [LocationFeature]) {
        for feature in features {
            print("Location feature not available: '%s'", String(describing: feature))
        }
    }

    private func addMyLocationToMap(myLocation: Location) {
        // Setup location indicator.
        locationIndicator = LocationIndicator()
        locationIndicator.locationIndicatorStyle = .pedestrian;
        locationIndicator.updateLocation(myLocation)
        mapView.addLifecycleDelegate(locationIndicator)
        // Point camera to current location.
        mapCamera.lookAt(point: myLocation.coordinates,
                         distanceInMeters: PositioningExample.defaultCameraDistance)
    }

    private func updateMyLocationOnMap(myLocation: Location) {
        // Update location indicator.
        locationIndicator.updateLocation(myLocation)
        // Point camera to current location.
        mapCamera.lookAt(point: myLocation.coordinates)
    }
}
