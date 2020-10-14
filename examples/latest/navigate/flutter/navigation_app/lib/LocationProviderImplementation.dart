/*
 * Copyright (C) 2019-2020 HERE Europe B.V.
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

import 'package:here_sdk/core.dart' as HERE;
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/navigation.dart' as HERE;
import 'package:here_sdk/routing.dart' as HERE;

// This class provides simulated location events (requires a route).
// Alternatively, check the positioning_app to see how to get real location events from a device.
class LocationProviderImplementation {
  // Set by anyone who wants to listen to location updates from LocationSimulator.
  HERE.LocationListener locationListener;

  HERE.LocationSimulator _locationSimulator;

  // Provides location updates based on the given route.
  void enableRoutePlayback(HERE.Route route) {
    _locationSimulator?.stop();

    _locationSimulator = _createLocationSimulator(route);
    _locationSimulator.start();
  }

  void stop() {
    _locationSimulator?.stop();
  }

  // Provides fake GPS signals based on the route geometry.
  HERE.LocationSimulator _createLocationSimulator(HERE.Route route) {
    final double speedFactor = 3;
    final notificationIntervalInMilliseconds = 500;
    HERE.LocationSimulatorOptions locationSimulatorOptions = HERE.LocationSimulatorOptions(
      speedFactor,
      notificationIntervalInMilliseconds,
    );

    HERE.LocationSimulator locationSimulator;

    try {
      locationSimulator = HERE.LocationSimulator.withRoute(route, locationSimulatorOptions);
    } on InstantiationException {
      throw Exception("Initialization of LocationSimulator failed.");
    }

    locationSimulator.listener = HERE.LocationListener.fromLambdas(lambda_onLocationUpdated: (HERE.Location location) {
      locationListener?.onLocationUpdated(location);
    }, lambda_onLocationTimeout: () {
      // Note: This method is deprecated and will be removed
      // from the LocationListener interface with release HERE SDK v4.7.0.
    });

    return locationSimulator;
  }
}
