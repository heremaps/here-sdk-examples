/*
 * Copyright (C) 2023-2024 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
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

/*
 * LocationFilterStrategy protocol defines the structure for filtering locations based on a given criteria.
 * Adopting this protocol allows for easy customization and implementation of different strategies for location
 * filtering algorithms without changing the core functionality of the hiking app.
 */
protocol LocationFilterStrategy {
    func checkIfLocationCanBeUsed(_ location: Location) -> Bool
}

/*
 * The DistanceAccuracyLocationFilter class implements the LocationFilterStrategy protocol and provides a filtering strategy based on accuracy
 * and distance from last accepted location. This class works on two filter mechanisms.
 * AccuracyFilter - Filters the location data based on the accuracy of the GPS  readings, and only includes the readings with a certain level of accuracy.
 * DistanceFilter - Filters the location data based on the locations that are within the specified distance from the last accepted location.
 */
class DistanceAccuracyLocationFilter: LocationFilterStrategy {
    // These two parameters define if incoming location updates are considered to be good enough.
    // In the field, the GPS signal can be very unreliable, so we need to filter out inaccurate signals.
    static let accuracyRadiusThresholdInMeters = 10.0
    static let distanceThresholdInMeters = 15.0
    private var lastAcceptedGeoCoordinates: GeoCoordinates?
    
    func checkIfLocationCanBeUsed(_ location: Location) -> Bool {
        if isAccuracyGoodEnough(location) && isDistanceFarEnough(location) {
            lastAcceptedGeoCoordinates = location.coordinates
            return true
        }
        return false
    }
    
    // Checks if the accuracy of the received GPS signal is good enough.
    private func isAccuracyGoodEnough(_ location: Location) -> Bool {
        guard let horizontalAccuracyInMeters = location.horizontalAccuracyInMeters else {
            return false
        }

        // If the location lies within the radius of accuracyCircleRadiusInMetersThreshold then we accept it.
        if horizontalAccuracyInMeters <= DistanceAccuracyLocationFilter.accuracyRadiusThresholdInMeters {
            return true
        }
        return false
    }
    
    // Checks if last accepted location is farther away than xx meters.
    // If it is, the new location will be accepted.
    // This way we can filter out signals that are caused by a non-moving user.
    private func isDistanceFarEnough(_ location: Location) -> Bool {
        guard let lastAcceptedGeoCoordinates = lastAcceptedGeoCoordinates else {
            // We always accept the first location.
            lastAcceptedGeoCoordinates = location.coordinates
            return true
        }
        
        let distance = location.coordinates.distance(to: lastAcceptedGeoCoordinates)
        if distance >= DistanceAccuracyLocationFilter.distanceThresholdInMeters {
            return true
        }
        return false
    }
}

// The DefaultLocationFilter class implements the LocationFilterStrategy protocol and
// allows every location signal to pass inorder to visualize the raw GPS signals on the map.
class DefaultLocationFilter: LocationFilterStrategy {
    func checkIfLocationCanBeUsed(_ location: Location) -> Bool {
        return true
    }
}
