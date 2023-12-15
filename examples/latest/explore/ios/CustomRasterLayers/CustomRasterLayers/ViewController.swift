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

final class ViewController: UIViewController {

    @IBOutlet private var mapView: MapView!
    private var customRasterLayersExample: CustomRasterLayersExample!
    private var isMapSceneLoaded = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the map scene using a map style to render the map with.
        mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let message = "For this example app, an outdoor layer from thunderforest.com is used. Without setting a valid API key, these raster tiles will show a watermark (terms of usage: https://www.thunderforest.com/terms/).\n Attribution for the outdoor layer: \n Maps © www.thunderforest.com, \n Data © www.osm.org/copyright."
        showDialog(title: "Note", message: message)
    }

    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Start the example.
        customRasterLayersExample = CustomRasterLayersExample(mapView: mapView)
        isMapSceneLoaded = true
    }

    @IBAction func onEnableButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            customRasterLayersExample.onEnableButtonClicked()
        }
    }

    @IBAction func onDisableButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            customRasterLayersExample.onDisableButtonClicked()
        }
    }
    
    func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))

        present(alertController, animated: true, completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
}
