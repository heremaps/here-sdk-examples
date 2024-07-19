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
import UIKit

class CustomMapStylesExample {

    private let viewController: UIViewController
    private let mapView: MapView

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView

        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 200 * 1000)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)
    }

    func onLoadButtonClicked() {
        loadCustomMapStyle()
    }

    func onUnloadButtonClicked() {
        mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)
    }

    // Drag & drop the assets folder including the JSON style onto Xcode's project navigator.
    private func loadCustomMapStyle() {
        let jsonResourceString = getResourceStringFromBundle(name: "custom-dark-style-neon-rds",
                                                             type: "json")
        // Load the map scene using the path to the JSON resource.
        mapView.mapScene.loadScene(fromFile: jsonResourceString, completion: onLoadScene)
    }

    private func getResourceStringFromBundle(name: String, type: String) -> String {
        let bundle = Bundle(for: ViewController.self)
        let resourceUrl = bundle.url(forResource: name,
                                     withExtension: type)
        guard let resourceString = resourceUrl?.path else {
            fatalError("Error: Resource not found!")
        }

        return resourceString
    }
    
    // Completion handler when loading a map scene.
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
    }
}
