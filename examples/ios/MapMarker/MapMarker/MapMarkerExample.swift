/*
 * Copyright (C) 2019 HERE Europe B.V.
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

class MapMarkerExample: TapDelegate, PickMapItemsCallback {

    private var viewController: UIViewController!
    private var mapView: MapView!
    private var mapMarkers = [MapMarker]()
    private let mapCenterGeoCoordinates = GeoCoordinates(latitude: 52.520798, longitude: 13.409408)

    func onMapSceneLoaded(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
        let camera = mapView.camera
        camera.setTarget(mapCenterGeoCoordinates)
        camera.setZoomLevel(15)

        // Setting a tap delegate to pick markers from map.
        mapView.gestures.tapDelegate = self

        showDialog(title: "Note", message: "You can tap markers.")
    }

    func onAnchoredButtonClicked() {
        for _ in 1...10 {
            let geoCoordinates = createRandomGeoCoordinatesInViewport()

            // Centered on location. Shown below the POI image to indicate the location.
            addCircleMapMarker(geoCoordinates: geoCoordinates)

            // Anchored, pointing to location.
            addPOIMapMarker(geoCoordinates: geoCoordinates)
        }
    }

    func onCenteredButtonClicked() {
        let geoCoordinates = createRandomGeoCoordinatesInViewport()

        // Centered on location.
        addPhotoMapMarker(geoCoordinates: geoCoordinates)

        // Centered on location. Shown on top of the previous image to indicate the location.
        addCircleMapMarker(geoCoordinates: geoCoordinates)
    }

    func onClearButtonClicked() {
        clearMap()
    }

    private func addPOIMapMarker(geoCoordinates: GeoCoordinates) {
        let mapMarker = MapMarker(at: geoCoordinates)
        // Drag & Drop the image to Assets.xcassets (or simply add the image as file to the project).
        // You can add multiple resolutions to Assets.xcassets that will be used depending on the
        // display size.
        let image = UIImage(named: "poi.png")
        let mapImage = MapImage(image!)

        // The bottom, middle position should point to the location.
        // By default, the anchor point is set to 0.5, 0.5.
        let mapMarkerImageStyle = MapMarkerImageStyle()
        mapMarkerImageStyle.setAnchorPoint(Anchor2D(horizontal: 0.5, vertical: 1))

        let metadata = Metadata()
        metadata.setString(key: "key_poi", value: "This is a POI.")
        mapMarker.metadata = metadata

        mapMarker.addImage(mapImage!, style: mapMarkerImageStyle)
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    @discardableResult
    private func addPhotoMapMarker(geoCoordinates: GeoCoordinates) -> (width: Int32, height: Int32) {
        let mapMarker = MapMarker(at: geoCoordinates)
        let image = UIImage(named: "here_car.png")
        let mapImage = MapImage(image!)
        mapMarker.addImage(mapImage!, style: MapMarkerImageStyle())
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)

        // Return the image size as tuple.
        return (width: mapImage?.width ?? 0, height: mapImage?.height ?? 0)
    }

    private func addCircleMapMarker(geoCoordinates: GeoCoordinates) {
        let mapMarker = MapMarker(at: geoCoordinates)
        let image = UIImage(named: "circle.png")
        let mapImage = MapImage(image!)
        mapMarker.addImage(mapImage!, style: MapMarkerImageStyle())
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    // Conform to the TapDelegate protocol.
    func onTap(origin: Point2D) {
        mapView.pickMapItems(at: origin, radius: 2, callback: self)
    }

    // Conform to the PickMapItemsCallback protocol.
    func onMapItemsPicked(pickedMapItems: PickMapItemsResult?) {
        guard let mapItems = pickedMapItems else {
            return
        }

        guard let topmostMapMarker = mapItems.topmostMarker else {
            return
        }

        if let metadata = topmostMapMarker.metadata {
            var message = "No message found."
            if let string = metadata.getString(key: "key_poi") {
                message = string
            }
            showDialog(title: "Map Marker picked", message: message);
            return
        }

        showDialog(title: "Map marker picked:", message: "Location: \(topmostMapMarker.coordinates)")
    }

    private func createRandomGeoCoordinatesInViewport() -> GeoCoordinates {
        let geoBoundingRect = mapView.camera.boundingRect
        let northEast = geoBoundingRect.northEastCorner
        let southWest = geoBoundingRect.southWestCorner

        let minLat = southWest.latitude
        let maxLat = northEast.latitude
        let lat = getRandom(min: minLat , max: maxLat )

        let minLon = southWest.longitude
        let maxLon = northEast.longitude
        let lon = getRandom(min: minLon , max: maxLon )

        return GeoCoordinates(latitude: lat, longitude: lon)
    }

    private func getRandom(min: Double, max: Double) -> Double {
        return Double.random(in: min ... max)
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }

    private func clearMap() {
        for mapMarker in mapMarkers {
            mapView.mapScene.removeMapMarker(mapMarker)
        }

        mapMarkers.removeAll()
    }
}
