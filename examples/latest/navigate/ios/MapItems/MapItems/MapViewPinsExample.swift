/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

class MapViewPinsExample {

    private let distanceInMeters = 1000 * 10.0
    private let mapCenterGeoCoordinates = GeoCoordinates(latitude: 52.51760485151816, longitude: 13.380312380535472)
    
    private let mapView: MapView
    private let mapCamera: MapCamera

    init(mapView: MapView) {
        self.mapView = mapView
        mapCamera = mapView.camera
        mapCamera.lookAt(point: mapCenterGeoCoordinates, distanceInMeters: 7000)

        // Add circle to indicate map center.
        addCircle(mapCenterGeoCoordinates);
    }

    func onDefaultButtonClicked() {
        showMapViewPins()
    }

    func onAnchoredButtonClicked() {
        showAnchoredMapViewPins()
    }

    func onClearButtonClicked() {
        clearMap()
    }

    private func showMapViewPins() {
        // Move map to expected location.
        flyTo(geoCoordinates: mapCenterGeoCoordinates)
        
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        textView.textAlignment = .center
        textView.isEditable = false
        textView.backgroundColor = UIColor(red: 72/255, green: 218/255, blue: 208/255, alpha: 1)
        textView.textColor = .white
        textView.font = .systemFont(ofSize: 17)
        textView.text = "Centered ViewPin"

        _ = mapView.pinView(textView, to: mapCenterGeoCoordinates)
    }

    private func showAnchoredMapViewPins() {
        // Move map to expected location.
        flyTo(geoCoordinates: mapCenterGeoCoordinates)
        
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        textView.textAlignment = .center
        textView.isEditable = false
        textView.backgroundColor = UIColor(red: 0/255, green: 144/255, blue: 138/255, alpha: 1)
        textView.textColor = .white
        textView.font = .systemFont(ofSize: 17)
        textView.text = "Anchored ViewPin"
        textView.layer.anchorPoint = CGPoint(x: 0.5, y: 1)

        _ = mapView.pinView(textView, to: mapCenterGeoCoordinates)
    }

    private func clearMap() {
        for viewPin in mapView.viewPins {
            viewPin.unpin()
        }
    }

    private func addCircle(_ geoCoordinates: GeoCoordinates) {
        guard
            let image = UIImage(named: "circle.png"),
            let imageData = image.pngData() else {
                print("Error: Image not found.")
                return
        }

        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png))
        mapView.mapScene.addMapMarker(mapMarker)
    }
    
    private func flyTo(geoCoordinates: GeoCoordinates) {
        let geoCoordinatesUpdate = GeoCoordinatesUpdate(geoCoordinates)
        let durationInSeconds: TimeInterval = 3
        let animation = MapCameraAnimationFactory.flyTo(target: geoCoordinatesUpdate,
                                                        bowFactor: 1,
                                                        duration: durationInSeconds)
        mapCamera.startAnimation(animation)
    }
}
