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
import Foundation
import UIKit

public protocol PlatformPositioningProviderDelegate {
    func onLocationUpdated(location: CLLocation)
}

// A simple iOS based positioning implementation.
class PlatformPositioningProvider : NSObject,
                                    CLLocationManagerDelegate {

    var delegate: PlatformPositioningProviderDelegate?
    private let locationManager = CLLocationManager()

    func startLocating() {
         if locationManager.delegate == nil {
             locationManager.delegate = self
             locationManager.desiredAccuracy = kCLLocationAccuracyBest
             locationManager.requestAlwaysAuthorization()
         }
    }

    func stopLocating() {
        locationManager.stopUpdatingLocation()
    }

    // Conforms to the CLLocationManagerDelegate protocol.
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
            case .restricted, .denied, .notDetermined:
                print("Positioning denied by user.")
                break
            case .authorizedWhenInUse, .authorizedAlways:
                print("Positioning authorized by user.")
                locationManager.startUpdatingLocation()
                break
            default:
                break
        }
    }

    // Conforms to the CLLocationManagerDelegate protocol.
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
       if let error = error as? CLError, error.code == .denied {
          print("Positioning denied by user.")
          manager.stopUpdatingLocation()
       }
    }

    // Conforms to the CLLocationManagerDelegate protocol.
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last else {
            print("Warning: No last location found")
            return
        }

        delegate?.onLocationUpdated(location: lastLocation)
    }
}
