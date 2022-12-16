/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

    @IBOutlet private var mapView: MapView!
    private var offlineMapsExample: OfflineMapsExample!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the map scene using a map style to render the map with.
        mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)
    }

    func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Start the example.
        offlineMapsExample = OfflineMapsExample(mapView: mapView)
    }

    @IBAction func onDownloadListClicked(_ sender: Any) {
        offlineMapsExample.onDownloadListClicked()
    }

    @IBAction func onDownloadMapClicked(_ sender: Any) {
        offlineMapsExample.onDownloadMapClicked()
    }

    @IBAction func onCancelMapDownloadClicked(_ sender: Any) {
        offlineMapsExample.onCancelMapDownloadClicked()
    }

    @IBAction func onSearchPlaceClicked(_ sender: Any) {
        offlineMapsExample.onSearchPlaceClicked()
    }

    @IBAction func onSwitchOnlineClicked(_ sender: Any) {
        offlineMapsExample.onSwitchOnlineClicked()
    }

    @IBAction func onSwitchOfflineClicked(_ sender: Any) {
        offlineMapsExample.onSwitchOfflineClicked()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
}

