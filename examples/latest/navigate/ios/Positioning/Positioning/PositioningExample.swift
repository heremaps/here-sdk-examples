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

class PositioningExample: LocationDelegate, LocationStatusDelegate {

    private static let defaultGeoCoordinates = GeoCoordinates(latitude: 52.520798, longitude: 13.409408)
    private static let defaultCameraDistance = 1000.0
    private static let defaultAccuracyColor = UIColor(red: 0.25, green: 0.75, blue: 1, alpha: 0.25)
    private static let defaultCenterColor = UIColor(red: 1.0, green: 0.125, blue: 0.125, alpha: 1)

    private var locationEngine: LocationEngine
    private var mapView: MapView!
    private var mapCamera: MapCamera!
    private var locationAccuracyCircle: MapPolygon!
    private var locationCenterCircle: MapMarker!

    init() {
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
            addMyLocationToMap(geoCoordinates: lastLocation.coordinates,
                               accuracyInMeters: lastLocation.horizontalAccuracyInMeters ?? 0.0)
        } else {
            addMyLocationToMap(geoCoordinates: PositioningExample.defaultGeoCoordinates,
                               accuracyInMeters: 0.0)
        }

        startLocating()
    }

    deinit {
        stopLocating()
    }

    private func startLocating() {
        // Set delegates and start location engine.
        locationEngine.addLocationStatusDelegate(locationStatusDelegate: self)
        locationEngine.addLocationDelegate(locationDelegate: self)
        _ = locationEngine.start(locationAccuracy: .bestAvailable)
    }

    public func stopLocating() {
        // Remove delegates and stop location engine.
        locationEngine.removeLocationDelegate(locationDelegate: self)
        locationEngine.removeLocationStatusDelegate(locationStatusDelegate: self)
        locationEngine.stop()
    }

    func onLocationUpdated(_ location: heresdk.Location) {
        updateMyLocationOnMap(geoCoordinates: location.coordinates,
                              accuracyInMeters: location.horizontalAccuracyInMeters ?? 1.0)

        print("Location updated: \(location.coordinates)")
        print("Horizontal accuracy (m): \(String(describing: location.horizontalAccuracyInMeters))")
        print("Altitude (m): \(String(describing: location.verticalAccuracyInMeters))")
    }

    func onLocationTimeout() {
        // Will be removed in 4.7.0. The time-out functionality is now part of the SDK implementation.
    }

    func onStatusChanged(locationEngineStatus: LocationEngineStatus) {
        print("Location engine status: \(locationEngineStatus)")
    }

    func onFeaturesNotAvailable(features: [LocationFeature]) {
        for feature in features {
            print("Location feature not available: '%s'", String(describing: feature))
        }
    }

    private func addMyLocationToMap(geoCoordinates: GeoCoordinates, accuracyInMeters: Double) {
        // Transparent halo around the current location with radius of horizontal accuracy.
        let accuracyCircle = GeoCircle(center: geoCoordinates, radiusInMeters: accuracyInMeters)
        let accuracyPolygon = GeoPolygon(geoCircle: accuracyCircle)
        locationAccuracyCircle = MapPolygon(geometry: accuracyPolygon,
                                            color: PositioningExample.defaultAccuracyColor)
        mapView.mapScene.addMapPolygon(locationAccuracyCircle)
        // Solid red circle on top of the current location.
        guard
            let image = UIImage(named: "red_dot"),
            let imageData = image.pngData() else {
            return
        }
        locationCenterCircle = MapMarker(at: geoCoordinates,
                                         image: MapImage(pixelData: imageData,
                                                         imageFormat: ImageFormat.png))
        mapView.mapScene.addMapMarker(locationCenterCircle)
        // Point camera to current location.
        mapCamera.lookAt(point: geoCoordinates,
                         distanceInMeters: PositioningExample.defaultCameraDistance)
    }

    private func updateMyLocationOnMap(geoCoordinates: GeoCoordinates, accuracyInMeters: Double) {
        // Update location accuracy circle.
        let accuracyCircle = GeoCircle(center: geoCoordinates, radiusInMeters: accuracyInMeters)
        locationAccuracyCircle.geometry = GeoPolygon(geoCircle: accuracyCircle)
        // Update location center.
        locationCenterCircle.coordinates = geoCoordinates
        // Point camera to current location.
        mapCamera.lookAt(point: geoCoordinates)
    }
}
