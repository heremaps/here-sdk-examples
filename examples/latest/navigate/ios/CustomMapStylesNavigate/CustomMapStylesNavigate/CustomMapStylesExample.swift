/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

// This example shows how to use the Camera class to rotate and tilt the map programmatically, to set
// a new transform center that influences those operations, and to move to a new location.
// For more features of the Camera class, please consult the API Reference and the Developer's Guide.
class CustomMapStylesExample {

    private let viewController: UIViewController
    private let mapView: MapView

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView

        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      distanceInMeters: 200 * 1000)
    }

    func onLoadButtonClicked() {
        loadCustomMapStyle()
    }

    func onUnloadButtonClicked() {
        mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)
    }
    
    private func loadCustomMapStyle() {
        let bundle = Bundle(for: ViewController.self)
        // Adjust file name and path as appropriate for your project.
        let jsonResourceUrl = bundle.url(forResource: "oslo-ocm-normal-day.scene",
                                         withExtension: "json",
                                         subdirectory: "omv")
        guard let jsonResourceString = jsonResourceUrl?.path else {
            print("Error: Map style not found!")
            return
        }

        print(jsonResourceString)

        // Load the map scene using the JSON resource.
        mapView.mapScene.loadScene(fromFile: jsonResourceString, completion: onLoadScene)
    }

    // Completion handler when loading a map scene.
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
    }
}
