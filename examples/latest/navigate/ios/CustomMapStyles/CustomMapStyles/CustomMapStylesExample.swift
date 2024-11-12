/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
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

class CustomMapStylesExample {

    private let mapView: MapView

    init(_ mapView: MapView) {
        self.mapView = mapView

        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 200 * 1000)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)
        
        // Load the initial map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
        }
    }
    
    func onLoadButtonClicked() {
        loadCustomMapStyle()
    }

    func onUnloadButtonClicked() {
        mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)
    }

    // Drag & drop the assets folder including the JSON style onto Xcode's project navigator.
    private func loadCustomMapStyle() {
        let jsonResourceString = getResourceStringFromBundle(filename: "custom-dark-style-neon-rds",
                                                             type: "json")
        // Load the map scene using the path to the JSON resource.
        mapView.mapScene.loadScene(fromFile: jsonResourceString, completion: onLoadScene)
    }

    private func getResourceStringFromBundle(filename: String, type: String) -> String {
        let bundle = Bundle.main
        guard let resourceUrl = bundle.url(forResource: filename, withExtension: type) else {
            fatalError("Error: Resource not found!")
        }

        return resourceUrl.path
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
