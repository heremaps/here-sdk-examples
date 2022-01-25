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

    private var mapView: MapView!
    private var gesturesExample: GesturesExample!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize MapView without a storyboard.
        mapView = MapView(frame: view.bounds)
        view.addSubview(mapView)

        // Load the map scene using a map style to render the map with.
        mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)
    }

    func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
          print("Error: Map scene not loaded, \(String(describing: mapError))")
          return
        }

        // Start the example.
        gesturesExample = GesturesExample(viewController: self, mapView: mapView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
}
