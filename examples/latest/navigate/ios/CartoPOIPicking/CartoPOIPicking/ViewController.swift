/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

class ViewController: UIViewController, TapDelegate {

    @IBOutlet var mapView: MapView!
   
    private var offlineSearchEngine: OfflineSearchEngine?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }

    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)
        
        startExample()
    }
    
    private func startExample() {
        showDialog(title: "Tap on Map Content",
                   message: "This app shows how to pick vehicle restrictions and embedded markers on the map, such as subway stations and ATMs.")

        enableVehicleRestrictionsOnMap()
        
        do {
            // Allows to search on already downloaded or cached map data.
            try offlineSearchEngine = OfflineSearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize OfflineSearchEngine. Cause: \(engineInstantiationError)")
        }

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
        mapView.pickMapContent(inside: rectangle2D, completion: onMapItemsPicked)
    }

    // Completion handler to receive picked map icons.
    func onMapItemsPicked(pickedMapContent: PickMapContentResult?) {
        guard let pickedMapContent = pickedMapContent else {
            print("Pick operation failed.")
            return
        }

        handlePickedCartoPOIs(pickedMapContent.pois)
        handlePickedTrafficIncidents(pickedMapContent.trafficIncidents)
        handlePickedVehicleRestrictions(pickedMapContent.vehicleRestrictions)
    }

    private func handlePickedCartoPOIs(_ cartoPOIList: [PickMapContentResult.PoiResult]) {
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

        fetchCartoPOIDetails(topmostCartoPOI.offlineSearchId);
    }
    
    // The ID is only given for cached or downloaded maps data.
    private func fetchCartoPOIDetails(_ offlineSearchId: String) {
        // Set nil for LanguageCode to get the results in their local language.
        let languageCode: LanguageCode? = nil
        offlineSearchEngine?.search(placeIdQuery: PlaceIdQuery(offlineSearchId),
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
        
        // The text is non-translated and will vary depending on the region.
        // For example, for a height restriction the text might be "5.5m" in Germany and "12'5"" in the US for a
        // restriction of type "HEIGHT". An example for a "WEIGHT" restriction: "15t".
        // The text might be empty, for example, in case of type "GENERAL_TRUCK_RESTRICTION", indicated by a "no-truck" sign.
        let topmostVehicleRestriction = vehicleRestrictions.first!
        var text = topmostVehicleRestriction.text
        if text.isEmpty {
            text = "General vehicle restriction."
        }
        
        let lat = topmostVehicleRestriction.coordinates.latitude
        let lon = topmostVehicleRestriction.coordinates.longitude
        // A textual normed representation of the type.
        let type = topmostVehicleRestriction.restrictionType
        showDialog(title: "Vehicle restriction picked",
                   message: "Text: \(text). Location: \(lat), \(lon). Type: \(type). See log for more place details.")

        // GDF time domains format according to ISO 14825.
        print("VR TimeIntervals: " + topmostVehicleRestriction.timeIntervals);
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
    
    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}
