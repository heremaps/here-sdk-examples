/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

class ViewController: UIViewController {

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

        // Create positionng example.
        positioningExample = PositioningExample()

        // Check that location authorization is granted .
        ensureLocationAuthorization()
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

    private func ensureLocationAuthorization() {
        // Get current location authorization status.
        let locationAuthorizationStatus = CLLocationManager.authorizationStatus()

        // Check authorization.
        switch locationAuthorizationStatus {
        case .notDetermined:
            // Not determined, request for authorization.
            locationManager.requestAlwaysAuthorization()
            break
        case .denied, .restricted:
            // Denied or restricted, request for user action.
            let alert = UIAlertController(title: "Location services are disabled", message: "Please enable location services in your device settings.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
            break
        case .authorizedAlways, .authorizedWhenInUse:
            // Authorized, ok to continue.
            break
        default:
            fatalError("Unknown location authorization status: \(locationAuthorizationStatus).")
        }

        guard self.positioningExample == nil else {
            return
        }
    }
}
