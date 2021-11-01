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
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      distanceInMeters: 1000 * 10)
        
        startExample()
    }
    
    private func startExample() {
        showDialog(title: "Tap on Carto POIs",
                   message: "This app show how to pick embedded markers on the map, such as subway stations and ATMs.")

        do {
            // Allows to search on already downloaded or cached map data.
            try offlineSearchEngine = OfflineSearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize OfflineSearchEngine. Cause: \(engineInstantiationError)")
        }

        // Setting a tap handler to pick embedded carto POIs from map.
        mapView.gestures.tapDelegate = self
    }
    
    // Conforming to TapDelegate protocol.
    func onTap(origin: Point2D) {
        // You can also use a larger area to include multiple carto POIs.
        let rectangle2D = Rectangle2D(origin: origin,
                                      size: Size2D(width: 1, height: 1))
        mapView.pickMapFeatures(in: rectangle2D, completion: onMapItemsPicked)
    }

    // Completion handler to receive picked map items.
    func onMapItemsPicked(pickedMapFeatures: PickMapFeaturesResult?) {
        guard let pickedMapFeatures = pickedMapFeatures else {
            // Pick operation failed.
            return
        }

        let cartoPOIList = pickedMapFeatures.pois
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
