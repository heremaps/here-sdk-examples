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

import CoreLocation
import heresdk

// A reference implementation using HERE positioning.
// It is not necessary to use this class directly, as the location features can be controlled
// from the LocationProviderImplementation which uses this class to get location updates from
// the device.
class HEREPositioningProvider : NSObject,
                                // Needed to check device capabilities.
                                CLLocationManagerDelegate,
                                // Optionally needed by HERE SDK to listen for status changes.
                                LocationStatusDelegate,
                                // Needed by HERE SDK positioning to listen for location updates.
                                LocationUpdateDelegate {

    private var locationEngine: LocationEngine
    private var locationUpdateDelegate: LocationUpdateDelegate?

    override init() {
        do {
            try locationEngine = LocationEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize LocationEngine. Cause: \(engineInstantiationError)")
        }

        if let lastLocation = locationEngine.lastKnownLocation {
            print("Last known location: \(lastLocation.coordinates)")
        } else {
            print("No last known location found.")
        }

        super.init()
        authorizeNativeLocationServices()
    }

    private func authorizeNativeLocationServices() {
        // We need to check if the device is authorized to use location capabilities like GPS sensors.
        // Results are handled in the CLLocationManagerDelegate below.
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
    }

    // Conforms to the CLLocationManagerDelegate protocol.
    // Handles the result of the native authorization request.
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
            case .restricted, .denied, .notDetermined:
                print("Native location services denied or disabled by user in device settings.")
                break
            case .authorizedWhenInUse, .authorizedAlways:
                print("Native location services authorized by user.")
                break
            default:
                fatalError("Unknown location authorization status.")
        }
    }

    func startLocating(locationUpdateDelegate: LocationUpdateDelegate) {
        if locationEngine.isStarted {
            return
        }

        self.locationUpdateDelegate = locationUpdateDelegate

        // Set delegates to get location updates.
        locationEngine.addLocationUpdateDelegate(locationUpdateDelegate: locationUpdateDelegate)
        locationEngine.addLocationUpdateDelegate(locationUpdateDelegate: self)
        locationEngine.addLocationStatusDelegate(locationStatusDelegate: self)

        // Choose the best accuracy for the tbt navigation use case.
        _ = locationEngine.start(locationAccuracy: .navigation)
    }

    // Use this optionally to hook in additional delegates.
    func addLocationUpdateDelegate(locationUpdateDelegate: LocationUpdateDelegate) {
        locationEngine.addLocationUpdateDelegate(locationUpdateDelegate: locationUpdateDelegate)
    }

    func removeLocationUpdateDelegate(locationUpdateDelegate: LocationUpdateDelegate) {
        locationEngine.removeLocationUpdateDelegate(locationUpdateDelegate: locationUpdateDelegate)
    }

    func stopLocating() {
        if !locationEngine.isStarted {
            return
        }

        // Remove delegates and stop location engine.
        locationEngine.removeLocationUpdateDelegate(locationUpdateDelegate: locationUpdateDelegate!)
        locationEngine.removeLocationUpdateDelegate(locationUpdateDelegate: self)
        locationEngine.removeLocationStatusDelegate(locationStatusDelegate: self)
        locationEngine.stop()
    }

    // Conforms to the LocationUpdateDelegate protocol.
    func onLocationUpdated(location: Location) {
        print("Location updated: \(location.coordinates)")
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
}
