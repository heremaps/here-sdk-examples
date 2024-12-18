/*
 * Copyright (C) 2022-2024 HERE Europe B.V.
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

// A class to visualize the incoming raw location signals on the map during a trip.
class HEREPositioningVisualizer {

    private var mapView: MapView
    private var locationIndicator = LocationIndicator()
    private var mapCircles = [MapPolygon]()
    private var geoCoordinatesList: [GeoCoordinates] = []
    private let accuracyRadiusThresholdInMeters = 10.0

    init(_ mapView: MapView) {
        self.mapView = mapView
        setupMyLocationIndicator()
    }

    func updateLocationIndicator(_ location: Location) {
        locationIndicator.updateLocation(location)
    }

    // Renders the last n location signals and connects them with a polyline.
    // The accuracy of each location is indicated through a colored circle.
    func renderUnfilteredLocationSignals(_ location: Location) {
        print("Received location with accuracy \(String(describing: location.horizontalAccuracyInMeters)).")

        // Black means that no accuracy information is available.
        var fillColor: UIColor = .black
        if let accuracy = location.horizontalAccuracyInMeters {
            if accuracy < accuracyRadiusThresholdInMeters / 2 {
                // Green means that we have very good accuracy.
                fillColor = .green
            } else if accuracy <= accuracyRadiusThresholdInMeters {
                // Orange means that we have acceptable accuracy.
                fillColor = .orange
            } else {
                // Red means, the accuracy is quite bad, ie > 50 m.
                // The location will be ignored for our hiking diary.
                fillColor = .red
            }
        }

        addLocationCircle(center: location.coordinates,
                          radiusInMeters: 1,
                          fillColor: fillColor)
    }

    func clearMap() {
        for circle in mapCircles {
            mapView.mapScene.removeMapPolygon(circle)
        }

        geoCoordinatesList.removeAll()
    }

    private func setupMyLocationIndicator() {
        locationIndicator.isAccuracyVisualized = true
        locationIndicator.locationIndicatorStyle = .pedestrian
        locationIndicator.enable(for: mapView)
    }

    private func addLocationCircle(center: GeoCoordinates, radiusInMeters: Double, fillColor: UIColor) {
        let geoCircle = GeoCircle(center: center, radiusInMeters: radiusInMeters)
        let geoPolygon = GeoPolygon(geoCircle: geoCircle)
        let mapPolygon = MapPolygon(geometry: geoPolygon, color: fillColor)
        mapView.mapScene.addMapPolygon(mapPolygon)
        mapCircles.append(mapPolygon)

        if mapCircles.count > 150 {
            // Drawing too many items on the map view may slow down rendering, so we remove the oldest circle.
            mapView.mapScene.removeMapPolygon(mapCircles.first!)
            mapCircles.removeFirst()
        }
    }
}

