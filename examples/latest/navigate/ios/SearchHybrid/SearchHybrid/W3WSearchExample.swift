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

/**
 * The W3WSearchExample class demonstrates the use of the W3WSearchEngine
 * to perform operations with what3words terms.
 *
 * With the W3WSearchEngine, you can:
 * - Resolve a what3words term to an address and geographic coordinates.
 * - Find a what3words term for given geographic coordinates.
 *
 * Both approaches are demonstrated in the examples below.
 * The W3WSearchEngine interacts with the https://what3words.com/ backend
 * to perform these operations.
 */
class W3WSearchExample{

    private var w3wSearchEngine : W3WSearchEngine

    init(_ mapView: MapView) {
        
        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      zoom: distanceInMeters)

        do {
            try w3wSearchEngine = W3WSearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize W3WSearchEngine. Cause: \(engineInstantiationError)")
        }

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }

    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
        }
    }
    
    func onW3WSearchButtonClicked() {
        // W3W sample "dizzy.vanilla.singer" used for demonstration purposes. Replace with user input as needed.
        let searchWords = "dizzy.vanilla.singer"

        /* Finds the location of a known What3Words term.
         * This method searches for the geographic location corresponding to a given three-word address
         * (e.g., "dizzy.vanilla.singer"). It uses the What3Words API to resolve the three-word address into
         * a square on the map, retrieving additional details such as the square's coordinates and language.
         */
        w3wSearchEngine.search(words: searchWords) { [weak self] error, W3WSquare in
            guard let self = self else { return }
            if let error = error {
                self.showDialog(title: "W3W Search Error", message: "\(error)")
                return
            } else if let w3wSquare = W3WSquare {
                let message = """
                    3-word address: \(w3wSquare.words)
                    Language: \(w3wSquare.languageCode)
                    Coordinates: \(w3wSquare.coordinates.latitude), \(w3wSquare.coordinates.longitude)
                """
                self.showDialog(title: "What3Words Details", message: message)
            }
        }
    }
    
    func onW3WGeoCodeButtonClicked() {
        let coordinates = GeoCoordinates(latitude: 53.520798, longitude: 13.409408)
        
        // The language code for the desired three-word address.
        // ISO 639-1 code "en" specifies that the three-word address will be in English.
        let w3wLanguageCode = "en";
        
        /* Resolves geographic coordinates to a What3Words address (three-word format).
         * This method uses the What3Words search engine to find a three-word address based
         * on the provided coordinates (latitude and longitude). The result includes
         * additional details such as the square's coordinates and language.
         */
        w3wSearchEngine.search(coordinates: coordinates, language: w3wLanguageCode) { [weak self] error, W3WSquare in
            guard let self = self else { return }

            if let error = error {
                self.showDialog(title: "W3W reverse geocoding failed with error:", message: "\(error)")
                return
            } else if let w3wSquare = W3WSquare {
                let message = """
                    3-word address: \(w3wSquare.words)
                    Language: \(w3wSquare.languageCode)
                    Coordinates: \(w3wSquare.coordinates.latitude), \(w3wSquare.coordinates.longitude)
                """
                self.showDialog(title: "Geocoding Details", message: message)
            } else {
                print("W3W reverse geocoding returned no results.")
                self.showDialog(title: "No Result", message: "W3W reverse geocoding returned no results.")
            }
        }
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let topViewController = keyWindow.rootViewController {
            topViewController.present(alertController, animated: true, completion: nil)
        } else {
            print("Error: Unable to find key window or root view controller.")
        }
    }
}
