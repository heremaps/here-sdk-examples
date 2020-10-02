/*
 * Copyright (C) 2019-2020 HERE Europe B.V.
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

class PositioningExample: LocationUpdateDelegate, LocationStatusDelegate {

    private static let defaultGeoCoordinates = GeoCoordinates(latitude: 52.520798, longitude: 13.409408)
    private static let defaultCameraDistance = 1000.0
    private static let defaultAccuracyColor = Color(red: 64, green: 190, blue: 255, alpha: 64)
    private static let defaultCenterColor = Color(red: 255, green: 32, blue: 32, alpha: 255)

    private var locationEngine: LocationEngine
    private var mapView: MapView!
    private var mapCamera: MapCamera!
    private var locationAccuracyCircle: MapPolygon!
    private var locationCenterCircle: MapPolygon!

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
        let status = startLocating()
        print("Start locating status: \(status)")
    }

    deinit {
        stopLocating()
    }

    private func startLocating() -> LocationEngineStatus {
        // Set delegates and start location engine.
        locationEngine.addLocationStatusDelegate(locationStatusDelegate: self)
        locationEngine.addLocationUpdateDelegate(locationUpdateDelegate: self)
        return locationEngine.start(locationAccuracy: .bestAvailable)
    }

    public func stopLocating() {
        // Remove delegates and stop location engine.
        locationEngine.removeLocationUpdateDelegate(locationUpdateDelegate: self)
        locationEngine.removeLocationStatusDelegate(locationStatusDelegate: self)
        locationEngine.stop()
    }

    func onLocationUpdated(location: Location) {
        updateMyLocationOnMap(geoCoordinates: location.coordinates,
                              accuracyInMeters: location.horizontalAccuracyInMeters ?? 1.0)

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

    private func addMyLocationToMap(geoCoordinates: GeoCoordinates, accuracyInMeters: Double) {
        // Transparent halo around the current location with radius of horizontal accuracy.
        let accuracyCircle = GeoCircle(center: geoCoordinates, radiusInMeters: accuracyInMeters)
        let accuracyPolygon = GeoPolygon(geoCircle: accuracyCircle)
        locationAccuracyCircle = MapPolygon(geometry: accuracyPolygon,
                                            color: PositioningExample.defaultAccuracyColor)
        mapView.mapScene.addMapPolygon(locationAccuracyCircle)
        // Solid circle on top of the current location.
        let centerCircle = GeoCircle(center: geoCoordinates, radiusInMeters: 1.0)
        let centerPolygon = GeoPolygon(geoCircle: centerCircle)
        locationCenterCircle = MapPolygon(geometry: centerPolygon,
                                          color: PositioningExample.defaultCenterColor)
        mapView.mapScene.addMapPolygon(locationCenterCircle)
        // Point camera to current location.
        mapCamera.lookAt(point: geoCoordinates,
                         distanceInMeters: PositioningExample.defaultCameraDistance)
    }

    private func updateMyLocationOnMap(geoCoordinates: GeoCoordinates, accuracyInMeters: Double) {
        // Update location accuracy circle.
        let accuracyCircle = GeoCircle(center: geoCoordinates, radiusInMeters: accuracyInMeters)
        locationAccuracyCircle.updateGeometry(GeoPolygon(geoCircle: accuracyCircle))
        // Update location center.
        let centerCircle = GeoCircle(center: geoCoordinates, radiusInMeters: 1.0)
        locationCenterCircle.updateGeometry(GeoPolygon(geoCircle: centerCircle))
        // Point camera to current location.
        mapCamera.lookAt(point: geoCoordinates)
    }

}
