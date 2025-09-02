/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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
import 'package:here_sdk/core.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart';

// A class that provides simulated location updates along a given route.
// The frequency of the provided updates can be set via LocationSimulatorOptions.
class HEREPositioningSimulator {
  LocationSimulator? _locationSimulator;
  double _speedFactor = 1;

  // Starts route playback. For simplicity, we allow two location listeners.
  void startLocating(LocationListener locationListener1, LocationListener locationListener2, Route route) {
    // Stop any previous simulation.
    if (_locationSimulator != null) {
      _locationSimulator!.stop();
    }

    _locationSimulator = _createLocationSimulator(locationListener1, locationListener2, route);
    _locationSimulator!.start();
  }

  void stopLocating() {
    if (_locationSimulator != null) {
      _locationSimulator!.stop();
      _locationSimulator = null;
    }
  }

  void setSpeedFactor(double speedFactor) {
    _speedFactor = speedFactor;
  }

  // Provides fake GPS signals based on the route geometry.
  LocationSimulator _createLocationSimulator(
    LocationListener locationListener1,
    LocationListener locationListener2,
    Route route,
  ) {
    final locationSimulatorOptions = LocationSimulatorOptions();
    locationSimulatorOptions.speedFactor = _speedFactor;
    locationSimulatorOptions.notificationInterval = Duration(milliseconds: 500);

    late LocationSimulator locationSimulator;
    try {
      locationSimulator = LocationSimulator.withRoute(route, locationSimulatorOptions);
    } catch (e) {
      throw Exception("Initialization of LocationSimulator failed: ${e.toString()}");
    }

    // Set a listener that notifies both provided location listeners.
    locationSimulator.listener = HERE.LocationListener((location) {
      locationListener1.onLocationUpdated(location);
      locationListener2.onLocationUpdated(location);
    });

    return locationSimulator;
  }
}
