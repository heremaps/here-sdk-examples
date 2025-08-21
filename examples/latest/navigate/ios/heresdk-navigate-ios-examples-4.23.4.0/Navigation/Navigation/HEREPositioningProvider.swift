/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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
import SwiftUI

// A reference implementation using HERE Positioning to get notified on location updates
// from various location sources available from a device and HERE services.
class HEREPositioningProvider : NSObject,
                                // Needed to check device capabilities.
                                CLLocationManagerDelegate,
                                // Optionally needed to listen for status changes.
                                LocationStatusDelegate {

    // We need to check if the device is authorized to use location capabilities like GPS sensors.
    // Results are handled in the CLLocationManagerDelegate below.
    private let locationManager = CLLocationManager()
    private let locationEngine: LocationEngine
    private var locationUpdateDelegate: LocationDelegate?
    private var accuracy = LocationAccuracy.bestAvailable
    private var isLocating = false

    override init() {
        do {
            try locationEngine = LocationEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize LocationEngine. Cause: \(engineInstantiationError)")
        }

        super.init()
        authorizeNativeLocationServices()
    }

    func getLastKnownLocation() -> Location? {
        return locationEngine.lastKnownLocation
    }

    private func authorizeNativeLocationServices() {
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
    }

    // Make sure to add the required location permissions in the "Info.plist" file.
    // Xcode contains already "Info.plist values" in the "Build Settings" tab.
    // You can add new ones in a separate file (these will be combined with the existing values):
    // 1. In Xcode, click on your project in the Project Navigator.
    // 2. Under Targets, select the "Info" tab.
    // 3. Expand "URL Types (1)" and click on the "+" button.
    // 4. A new Info.plist file will appear in the project. You can edit now the values.

    // Conforms to the CLLocationManagerDelegate protocol.
    // Handles the result of the native authorization request.
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
            case .restricted, .denied, .notDetermined:
                print("Native location services denied or disabled by user in device settings.")
                showDialog(title: "Error", message: "Location service and permissions are needed for this app.")
                break
            case .authorizedWhenInUse, .authorizedAlways:
                if let locationUpdateDelegate = locationUpdateDelegate, isLocating {
                    startLocating(locationDelegate: locationUpdateDelegate, accuracy: accuracy)
                }
                print("Native location services authorized by user.")
                break
            default:
                fatalError("Unknown location authorization status.")
        }
    }

    // Does nothing when engine is already running.
    func startLocating(locationDelegate: LocationDelegate, accuracy: LocationAccuracy) {
        if locationEngine.isStarted {
            return
        }

        isLocating = true
        locationUpdateDelegate = locationDelegate
        self.accuracy = accuracy

        // Set delegates to get location updates.
        locationEngine.addLocationDelegate(locationDelegate: locationUpdateDelegate!)
        locationEngine.addLocationStatusDelegate(locationStatusDelegate: self)

        // Without native permissins granted by user, the LocationEngine cannot be started.
        if locationEngine.start(locationAccuracy: .bestAvailable) == .missingPermissions {
            authorizeNativeLocationServices()
        }
    }

    // Does nothing when engine is already stopped.
    func stopLocating() {
        if !locationEngine.isStarted {
            return
        }

        // Remove delegates and stop location engine.
        locationEngine.removeLocationDelegate(locationDelegate: locationUpdateDelegate!)
        locationEngine.removeLocationStatusDelegate(locationStatusDelegate: self)
        locationEngine.stop()
        isLocating = false
    }

    // Conforms to the LocationStatusDelegate protocol.
    func onStatusChanged(locationEngineStatus: LocationEngineStatus) {
        print("Location engine status changed: \(locationEngineStatus)")
    }

    // Conforms to the LocationStatusDelegate protocol.
    func onFeaturesNotAvailable(features: [LocationFeature]) {
        for feature in features {
            print("Location feature not available: '%s'", String(describing: feature))
        }
    }
    
    private func showDialog(title: String, message: String) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                // Handle OK button action.
                alert.dismiss(animated: true, completion: nil)
            }))
            
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
}
