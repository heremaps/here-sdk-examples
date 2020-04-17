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
import UIKit

// A class that conforms the HERE SDK's LocationProvider protocol.
// This class is required by the Navigator to receive location updates from either the device or the LocationSimulator.
class LocationProviderImplementation : LocationProvider,
                                       LocationDelegate,
                                       PlatformPositioningProviderDelegate {

    // Conforms to the LocationProvider protocol.
    // Set by the Navigator instance to listen to location updates.
    var delegate: LocationDelegate?

    var lastKnownLocation: Location?
    private let platformPositioningProvider: PlatformPositioningProvider
    private var locationSimulator: LocationSimulator?
    private var isSimulated: Bool = false

    // A loop to check for timeouts between location events.
    private lazy var timeoutDisplayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self,
                                        selector: #selector(timeoutLoop))
        displayLink.preferredFramesPerSecond = 2
        displayLink.add(to: .current, forMode: .common)
        return displayLink
    }()

    init() {
        platformPositioningProvider = PlatformPositioningProvider()
        platformPositioningProvider.delegate = self
    }

    // Provides location updates based on the given route.
    func enableRoutePlayback(route: Route) {
        if let locationSimulator = locationSimulator {
            locationSimulator.stop()
        }

        locationSimulator = createLocationSimulator(route: route)
        locationSimulator!.start()
        isSimulated = true;
    }

    // Provides location updates based on the device's GPS sensor.
    func enableDevicePositioning() {
        if locationSimulator != nil {
            locationSimulator!.stop()
            locationSimulator = nil
        }

        isSimulated = false;
    }

    // Conforms to the LocationProvider protocol.
    func start() {
        platformPositioningProvider.startLocating()
        timeoutDisplayLink.isPaused = false
    }

    // Conforms to the PlatformPositioningProviderDelegate to receive platform GPS events.
    func onLocationUpdated(location: CLLocation) {
        if !isSimulated {
            handleLocationUpdate(location: convertLocation(nativeLocation: location))
        }
    }

    // Conforms to the LocationProvider protocol.
    func stop() {
        platformPositioningProvider.stopLocating()
        timeoutDisplayLink.isPaused = true
    }

    private func handleLocationUpdate(location: Location) {
        // The GPS location we received from either the platform or the LocationSimulator is forwarded to the Navigator.
        delegate?.onLocationUpdated(location)
        lastKnownLocation = location
    }

    @objc private func timeoutLoop() {
        if isSimulated {
            // LocationSimulator already includes simulated timeout events.
            return
        }

        if let lastKnownLocation = lastKnownLocation {
            let timeIntervalInSeconds = lastKnownLocation.timestamp.timeIntervalSinceNow * -1
            if timeIntervalInSeconds > 3 {
                //If last location is older than 3 seconds we forward a timeout event to Navigator.
                delegate?.onLocationTimeout()
                print("GPS timeout detected: \(timeIntervalInSeconds)")
            }
        }
    }

    // Provides fake GPS signals based on the route geometry.
    // LocationSimulator can also be set directly to the Navigator, but here we want to have the flexibility to
    // switch between real and simulated GPS data.
    private func createLocationSimulator(route: Route) -> LocationSimulator {
        let locationSimulatorOptions = LocationSimulatorOptions(speedFactor: 10,
                                                                notificationIntervalInMilliseconds: 100)
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

    // Conforms to the LocationDelegate, which is required to send notifications from the LocationSimulator.
    func onLocationUpdated(_ location: Location) {
        if isSimulated {
            handleLocationUpdate(location: location)
        }
    }

    // Conforms to the LocationDelegate, which is required to send notifications from the LocationSimulator.
    func onLocationTimeout() {
        if isSimulated {
            delegate?.onLocationTimeout()
        }
    }

    // Converts platform CLLocation to HERE SDK Location.
    private func convertLocation(nativeLocation: CLLocation) -> Location {
        let geoCoordinates = GeoCoordinates(latitude: nativeLocation.coordinate.latitude,
                                            longitude: nativeLocation.coordinate.longitude,
                                            altitude: nativeLocation.altitude)
        var location = Location(coordinates: geoCoordinates,
                                timestamp: nativeLocation.timestamp)
        location.bearingInDegrees = nativeLocation.course
        location.speedInMetersPerSecond = nativeLocation.speed
        location.horizontalAccuracyInMeters = nativeLocation.horizontalAccuracy
        location.verticalAccuracyInMeters = nativeLocation.verticalAccuracy

        return location
    }
}
