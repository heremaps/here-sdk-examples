/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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
import SwiftUI

class CartoPOIPickingExample: TapDelegate {
    
    private let mapView: MapView
    private let searchEngine: SearchEngine
    
    init(_ mapView: MapView) {
        self.mapView = mapView
        
        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)
        
        do {
            // Allows to search online.
            try searchEngine = SearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize SearchEngine. Cause: \(engineInstantiationError)")
        }
        
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
        
        startExample()
    }
    
    private func startExample() {
        showDialog(title: "Tap on Map Content",
                   message: "This app shows how to pick vehicle restrictions and embedded markers on the map, such as subway stations and ATMs.")

        enableVehicleRestrictionsOnMap()

        // Setting a tap handler to pick embedded map content.
        mapView.gestures.tapDelegate = self
    }

    private func enableVehicleRestrictionsOnMap() {
        mapView.mapScene.enableFeatures([MapFeatures.vehicleRestrictions:
                                         MapFeatureModes.vehicleRestrictionsActiveAndInactiveDifferentiated])
    }

    // Conforming to TapDelegate protocol.
    func onTap(origin: Point2D) {
        // You can also use a larger area to include multiple map icons.
        let rectangle2D = Rectangle2D(origin: origin,
                                      size: Size2D(width: 50, height: 50))
        // Creates a list of map content type from which the results will be picked.
        // The content type values can be mapContent, mapItems and customLayerData.
        var contentTypesToPickFrom = Array<MapScene.MapPickFilter.ContentType>();
        
        // mapContent is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
        // mapItems is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
        // Currently we need carto POIs so adding the mapContent filter.
        contentTypesToPickFrom.append(MapScene.MapPickFilter.ContentType.mapContent);
        let filter = MapScene.MapPickFilter(filter: contentTypesToPickFrom)
        mapView.pick(filter:filter,inside: rectangle2D, completion: onMapItemsPicked)
    }

    // Completion handler to receive picked map icons.
    func onMapItemsPicked(mapPickResults: MapPickResult?) {
        guard let mapPickResults = mapPickResults else {
            print("Pick operation failed.")
            return
        }
        guard let pickedMapContent =  mapPickResults.mapContent else {
            print("Pick operation failed.")
            return
        }
        handlePickedCartoPOIs(pickedMapContent.pickedPlaces)
        handlePickedTrafficIncidents(pickedMapContent.trafficIncidents)
        handlePickedVehicleRestrictions(pickedMapContent.vehicleRestrictions)
    }

    private func handlePickedCartoPOIs(_ cartoPOIList: [PickedPlace]) {
        if cartoPOIList.count == 0 {
            // No results found at pick location.
            return
        }

        let topmostCartoPOI = cartoPOIList.first!
        let name = topmostCartoPOI.name
        let lat = topmostCartoPOI.coordinates.latitude
        let lon = topmostCartoPOI.coordinates.longitude
        showDialog(title: "Carto POI picked",
                   message: "Name: \(name). Location: \(lat), \(lon). See log for more place details.")

        // Now you can use the SearchEngine (via PickedPlace)
        // to retrieve the Place object containing more details.
        // Below we use the placeCategoryId.
        fetchCartoPOIDetails(topmostCartoPOI)
    }

    private func fetchCartoPOIDetails(_ pickedPlace: PickedPlace) {
        // Set nil for LanguageCode to get the results in their local language.
        let languageCode: LanguageCode? = nil
        searchEngine.searchByPickedPlace(pickedPlace,
                                         languageCode: languageCode,
                                         completion: onSearchCompleted)
    }

    // Completion handler to receive search results.
    func onSearchCompleted(error: SearchError?, place: Place?) {
        if let searchError = error {
            print("Place ID search: \(searchError)")
            return
        }

        // Below are just a few examples. Much more details can be retrieved, if desired.
        let title = place!.title;
        let addressText = place!.address.addressText;
        print("Title: \(title)");
        print("Address: \(addressText)");
    }

    private func handlePickedTrafficIncidents(_ trafficIndicents: [PickMapContentResult.TrafficIncidentResult]) {
        // See Traffic example app.
    }

    private func handlePickedVehicleRestrictions(_ vehicleRestrictions: [PickMapContentResult.VehicleRestrictionResult]) {
        if vehicleRestrictions.count == 0 {
            return
        }

        let topmostVehicleRestriction = vehicleRestrictions.first!

        let lat = topmostVehicleRestriction.coordinates.latitude
        let lon = topmostVehicleRestriction.coordinates.longitude
        showDialog(title: "Vehicle restriction picked",
                   message: " Location: \(lat), \(lon).")
    }
    
    private func showDialog(title: String, message: String) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {

            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                // Handle OK button action.
                alert.dismiss(animated: true, completion: nil)
            }))

            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
}
