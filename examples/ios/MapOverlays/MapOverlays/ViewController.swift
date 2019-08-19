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

class ViewController: UIViewController {

    @IBOutlet var mapView: MapView!
    private let mapOverlaysExample = MapOverlaysExample()
    private var isMapSceneLoaded = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the map scene using a map style to render the map with.
        mapView.mapScene.loadScene(mapStyle: .normalDay) { (sceneError) in
            if let error = sceneError {
                print("Error: Map scene not loaded, \(error)")
            } else {
                // Start the example.
                self.mapOverlaysExample.onMapSceneLoaded(mapView: self.mapView)
                self.isMapSceneLoaded = true;
            }
        }
    }

    @IBAction func onDefaultButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            mapOverlaysExample.onDefaultButtonClicked()
        }
    }

    @IBAction func onAnchoredButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            mapOverlaysExample.onAnchoredButtonClicked()
        }
    }

    @IBAction func onClearButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            mapOverlaysExample.onClearButtonClicked()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
}
