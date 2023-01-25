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

import CoreLocation
import heresdk
import UIKit

// Location authorization delegate for requesting location authorization.
public protocol LocationAuthorizationDelegate {
    func requestLocationAuthorization()
}

class ViewController: UIViewController, LocationAuthorizationDelegate, CLLocationManagerDelegate {
    // Core location instance is needed for requesting location authorization.
    private let locationManager = CLLocationManager()

    // Positioning example instance.
    private var positioningExample: PositioningExample!

    // Map view instance.
    private var mapView: MapView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize MapView without a storyboard.
        mapView = MapView(frame: view.bounds)

        // Load the map scene using a map style to render the map with.
        mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)

        // Finally add map view as sub view.
        view.addSubview(mapView)

        // Create positioning example.
        positioningExample = PositioningExample(locationAuthorization: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }

    func onLoadScene(mapError: MapError?) {
        if let error = mapError {
            print("Error: Map scene not loaded, \(error)")
        } else {
            positioningExample.onMapSceneLoaded(mapView: mapView)
        }
    }

    public func requestLocationAuthorization() {
        locationManager.delegate = self
        let alert = UIAlertController(title: "Location access required", message: "This example requires location access to function correctly, please accept location access in following dialog.", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: { action in
            self.locationManager.requestWhenInUseAuthorization()
        })
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        positioningExample.locationAuthorizatioChanged()
    }
}
