/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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
    private var visualNavigator: VisualNavigator?

    var spatialNavigationExample: SpatialNavigationExample?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
        // Init SpatialNavigationExample class.
        spatialNavigationExample = SpatialNavigationExample()
        spatialNavigationExample?.setMapView(mapView: mapView)
        // Start Navigation
        spatialNavigationExample?.calculateRoute()
    }
    
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
        
        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)
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
