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

final class ViewController: UIViewController {

    @IBOutlet private var mapView: MapViewLite!
    private var mapObjectsExample: MapObjectsExample!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the map scene using a map style to render the map with.
        mapView.mapScene.loadScene(mapStyle: .normalDay, callback: onLoadScene)
    }

    func onLoadScene(errorCode: MapSceneLite.ErrorCode?) {
        guard errorCode == nil else {
            print("Error: Map scene not loaded, \(String(describing: errorCode))")
            return
        }

        // Configure the map.
        mapView.camera.setTarget(GeoCoordinates(latitude: 52.518043, longitude: 13.405991))
        mapView.camera.setZoomLevel(13)

        // Start the example.
        mapObjectsExample = MapObjectsExample(mapView: mapView)
    }

    @IBAction func onMapPolylineClicked(_ sender: Any) {
        mapObjectsExample.onMapPolylineClicked()
    }

    @IBAction func onMapPolygonClicked(_ sender: Any) {
        mapObjectsExample.onMapPolygonClicked()
    }

    @IBAction func onMapCircleClicked(_ sender: Any) {
        mapObjectsExample.onMapCircleClicked()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
}
