/*
 * Copyright (C) 2023 HERE Europe B.V.
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

import 'package:here_sdk/core.dart';

import 'LocationFilterAbstract.dart';

/*
 * The DistanceAccuracyLocationFilter class implements the LocationFilterAbstract and provides a filtering strategy based on accuracy
 * and distance from last accepted location. This class works on two filter mechanisms.
 * AccuracyFilter - Filters the location data based on the accuracy of the GPS readings, and only includes the readings with a certain level of accuracy.
 * DistanceFilter - Filters the location data based on the locations that are within the specified distance from the last accepted location.
 */
class DistanceAccuracyLocationFilter implements LocationFilterAbstract {
  // These two parameters define if incoming location updates are considered to be good enough.
  // In the field, the GPS signal can be very unreliable, so we need to filter out inaccurate signals.

  static const double accuracyRadiusThresholdInMeters = 10.0;
  static const double distanceThresholdInMeters = 15.0;
  GeoCoordinates? lastAcceptedGeoCoordinates;

  @override
  bool checkIfLocationCanBeUsed(Location location) {
    if (_isAccuracyGoodEnough(location) && _isDistanceFarEnough(location)) {
      lastAcceptedGeoCoordinates = location.coordinates;
      return true;
    }
    return false;
  }

  // Checks if the accuracy of the received GPS signal is good enough.
  bool _isAccuracyGoodEnough(Location location) {
    final horizontalAccuracyInMeters = location.horizontalAccuracyInMeters;
    if (horizontalAccuracyInMeters == null) {
      return false;
    }

    // If the location lies within the radius of accuracyRadiusThresholdInMeters then we accept it.
    if (horizontalAccuracyInMeters <= accuracyRadiusThresholdInMeters) {
      return true;
    }
    return false;
  }

  // Checks if the last accepted location is farther away than xx meters.
  // If it is, the new location will be accepted.
  // This way we can filter out signals that are caused by a non-moving user.
  bool _isDistanceFarEnough(Location location) {
    if (lastAcceptedGeoCoordinates == null) {
      // We always accept the first location.
      lastAcceptedGeoCoordinates = location.coordinates;
      return true;
    }

    final distance = location.coordinates.distanceTo(lastAcceptedGeoCoordinates!);
    if (distance >= distanceThresholdInMeters) {
      return true;
    }
    return false;
  }
}
