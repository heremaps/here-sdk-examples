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

import heresdk
import UIKit

// This class allows to switch between simulated location events (requires a route) and real location updates using
// the advanced capabilities of the HERE positioning features.
class LocationProviderImplementation : // Used to receive events from HERE Positioning.
                                       LocationUpdateDelegate,
                                       // Used to receive events from LocationSimulator.
                                       LocationDelegate {

    // Set by anyone who wants to listen to location updates from either HERE Positioning or LocationSimulator.
    var delegate: LocationDelegate?

    var lastKnownLocation: Location?
    private let herePositioningProvider: HEREPositioningProvider
    private var locationSimulator: LocationSimulator?
    private var isSimulated: Bool = false

    init() {
        herePositioningProvider = HEREPositioningProvider()
    }

    // Provides location updates based on the given route.
    func enableRoutePlayback(route: Route) {
        if let locationSimulator = locationSimulator {
            locationSimulator.stop()
        }

        locationSimulator = createLocationSimulator(route: route)
        locationSimulator!.start()
        isSimulated = true
    }

    // Provides location updates based on the device's GPS sensor.
    func enableDevicePositioning() {
        if locationSimulator != nil {
            locationSimulator!.stop()
            locationSimulator = nil
        }

        isSimulated = false;
    }

    func start() {
        herePositioningProvider.startLocating(locationUpdateDelegate: self)
    }

    func stop() {
        herePositioningProvider.stopLocating()
    }

    // Conforms to the LocationUpdateDelegate protocol to receive location events from the device.
    func onLocationUpdated(location: Location) {
        if !isSimulated {
            handleLocationUpdate(location: location)
        }
    }

    private func handleLocationUpdate(location: Location) {
        // The GPS location we received from either the platform or the LocationSimulator is forwarded to the LocationDelegate.
        delegate?.onLocationUpdated(location)
        lastKnownLocation = location
    }

    // Provides fake GPS signals based on the route geometry.
    private func createLocationSimulator(route: Route) -> LocationSimulator {
        let locationSimulatorOptions = LocationSimulatorOptions(speedFactor: 2,
                                                                notificationIntervalInMilliseconds: 500)
        let locationSimulator: LocationSimulator

        do {
            try locationSimulator = LocationSimulator(route: route,
                                                      options: locationSimulatorOptions)
        } catch let instantiationError {
            fatalError("Failed to initialize LocationSimulator. Cause: \(instantiationError)")
        }

        locationSimulator.delegate = self
        locationSimulator.start()

        return locationSimulator
    }

    // Conforms to the LocationDelegate protocol, which is required to send notifications from the LocationSimulator.
    func onLocationUpdated(_ location: Location) {
        if isSimulated {
            handleLocationUpdate(location: location)
        }
    }

    // Conforms to the LocationDelegate protocol.
    func onLocationTimeout() {
        // Note: This method is deprecated and will be removed from the LocationDelegate protocol with release HERE SDK v4.7.0.
    }
}
