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

// Location authorization changes are reported using this protocol.
public protocol LocationAuthorizationChangeDelegate {
    func locationAuthorizatioChanged(granted: Bool)
}

// Location authorization delegate for requesting location authorization.
public protocol LocationAuthorizationDelegate {
    var authorizationChangeDelegate: LocationAuthorizationChangeDelegate? { get set }
    func requestLocationAuthorization()
}

class ViewController: UIViewController, LocationAuthorizationDelegate, CLLocationManagerDelegate {

    // Core location instance is needed for requesting location authorization.
    private let locationManager = CLLocationManager()

    // Positioning example instance.
    private var positioningExample: PositioningExample!

    // Map view instance.
    private var mapView: MapView!

    // Location authorization change delegate reference.
    var authorizationChangeDelegate: LocationAuthorizationChangeDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize MapView without a storyboard.
        mapView = MapView(frame: view.bounds)

        // Load the map scene using a map style to render the map with.
        mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)

        // Finally add map view as sub view.
        view.addSubview(mapView)

        // Listen for location authorization status changes
        locationManager.delegate = self

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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if let delegate = authorizationChangeDelegate {
            let allowed = [
                CLAuthorizationStatus.authorizedAlways,
                CLAuthorizationStatus.authorizedWhenInUse
            ].contains(CLLocationManager.authorizationStatus())
            delegate.locationAuthorizatioChanged(granted: allowed)
        }
    }

    public func requestLocationAuthorization() {
        // Get current location authorization status.
        let locationAuthorizationStatus = CLLocationManager.authorizationStatus()

        // Check authorization.
        switch locationAuthorizationStatus {
        case .restricted:
            // Access to location services restricted in the system settings.
            let alert = UIAlertController(title: "Location Services are restricted", message: "Please remove Location Services restriction in your device Settings", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
            return

        case .denied:
            // Location access denied for the application.
            let alert = UIAlertController(title: "Location access is denied", message: "Please allow location access for the application in your device Settings", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
            return

        case .authorizedWhenInUse, .authorizedAlways:
            // Authorization ok.
            break

        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            break

        default:
            break
        }
    }
}
