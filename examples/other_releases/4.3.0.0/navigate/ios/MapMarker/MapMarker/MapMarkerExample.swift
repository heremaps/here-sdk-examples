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

class MapMarkerExample: TapDelegate {

    private var viewController: UIViewController
    private var mapView: MapView
    private var mapMarkers = [MapMarker]()
    private let mapCenterGeoCoordinates = GeoCoordinates(latitude: 52.520798, longitude: 13.409408)

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
        let camera = mapView.camera
        camera.lookAt(point: mapCenterGeoCoordinates,
                      distanceInMeters: 1000 * 10)

        // Setting a tap delegate to pick markers from map.
        mapView.gestures.tapDelegate = self

        showDialog(title: "Note", message: "You can tap markers.")
    }

    func onAnchoredButtonClicked() {
        for _ in 1...10 {
            let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

            // Centered on location. Shown below the POI image to indicate the location.
            addCircleMapMarker(geoCoordinates: geoCoordinates)

            // Anchored, pointing to location.
            addPOIMapMarker(geoCoordinates: geoCoordinates)
        }
    }

    func onCenteredButtonClicked() {
        let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Centered on location.
        addPhotoMapMarker(geoCoordinates: geoCoordinates)
    }

    func onClearButtonClicked() {
        clearMap()
    }

    private func addPOIMapMarker(geoCoordinates: GeoCoordinates) {
        // Drag & Drop the image to Assets.xcassets (or simply add the image as file to the project).
        // You can add multiple resolutions to Assets.xcassets that will be used depending on the
        // display size.
        guard
            let image = UIImage(named: "poi.png"),
            let imageData = image.pngData() else {
                print("Error: Image not found.")
                return
        }

        // The bottom, middle position should point to the location.
        // By default, the anchor point is set to 0.5, 0.5.
        let anchorPoint = Anchor2D(horizontal: 0.5, vertical: 1)
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png),
                                  anchor: anchorPoint)

        let metadata = Metadata()
        metadata.setString(key: "key_poi", value: "This is a POI.")
        mapMarker.metadata = metadata

        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    private func addPhotoMapMarker(geoCoordinates: GeoCoordinates) {
        guard
            let image = UIImage(named: "here_car.png"),
            let imageData = image.pngData() else {
                print("Error: Image not found.")
                return
        }

        let mapImage = MapImage(pixelData: imageData,
                                imageFormat: ImageFormat.png)
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: mapImage)

        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    private func addCircleMapMarker(geoCoordinates: GeoCoordinates) {
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
        mapMarkers.append(mapMarker)
    }

    // Conform to the TapDelegate protocol.
    func onTap(origin: Point2D) {
        mapView.pickMapItems(at: origin, radius: 2, completion: onMapItemsPicked)
    }

    // Completion handler to receive picked map items.
    func onMapItemsPicked(pickedMapItems: PickMapItemsResult?) {
        guard let topmostMapMarker = pickedMapItems?.markers.first else {
            return
        }

        if let message = topmostMapMarker.metadata?.getString(key: "key_poi") {
            showDialog(title: "Map Marker picked", message: message);
            return
        }

        showDialog(title: "Map marker picked:", message: "Location: \(topmostMapMarker.coordinates)")
    }

    private func createRandomGeoCoordinatesAroundMapCenter() -> GeoCoordinates {
        let scaleFactor = UIScreen.main.scale
        let mapViewWidthInPixels = Double(mapView.bounds.width * scaleFactor)
        let mapViewHeightInPixels = Double(mapView.bounds.height * scaleFactor)
        let centerPoint2D = Point2D(x: mapViewWidthInPixels / 2,
                                    y: mapViewHeightInPixels / 2)

        let centerGeoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: centerPoint2D)
        let lat = centerGeoCoordinates!.latitude
        let lon = centerGeoCoordinates!.longitude
        return GeoCoordinates(latitude: getRandom(min: lat - 0.02,
                                                  max: lat + 0.02),
                              longitude: getRandom(min: lon - 0.02,
                                                   max: lon + 0.02))
    }

    private func getRandom(min: Double, max: Double) -> Double {
        return Double.random(in: min ... max)
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }

    private func clearMap() {
        for mapMarker in mapMarkers {
            mapView.mapScene.removeMapMarker(mapMarker)
        }

        mapMarkers.removeAll()
    }
}
