/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

// A class that provides simulated location updates along a given route.
// The frequency of the provided updates can be set via LocationSimulatorOptions.
class HEREPositioningSimulator {
  HERE.LocationSimulator? _locationSimulator;

  // Provides location updates based on the given route (route playback).
  void startLocating(HERE.Route route, HERE.LocationListener locationListener) {
    _locationSimulator?.stop();

    _locationSimulator = _createLocationSimulator(route, locationListener);
    _locationSimulator!.start();
  }

  void stop() {
    _locationSimulator?.stop();
  }

  // Provides fake GPS signals based on the route geometry.
  HERE.LocationSimulator _createLocationSimulator(HERE.Route route, HERE.LocationListener locationListener) {
    HERE.LocationSimulatorOptions locationSimulatorOptions = HERE.LocationSimulatorOptions.withDefaults();
    locationSimulatorOptions.speedFactor = 2;
    locationSimulatorOptions.notificationIntervalInMilliseconds = 500;

    HERE.LocationSimulator locationSimulator;

    try {
      locationSimulator = HERE.LocationSimulator.withRoute(route, locationSimulatorOptions);
    } on InstantiationException {
      throw Exception("Initialization of LocationSimulator failed.");
    }

    locationSimulator.listener = locationListener;

    return locationSimulator;
  }
}
