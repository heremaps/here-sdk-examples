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

import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/navigation.dart';

// A class that provides simulated location updates along a given gpx track.
// The frequency of the provided updates can be set via LocationSimulatorOptions.
// Note: This class was copied from the HERE SDK example app repository:
// https://github.com/heremaps/here-sdk-examples/tree/master/examples/latest/navigate/flutter/navigation_app
class HerePositioningSimulator {
  LocationSimulator? locationSimulator;

  void startLocating(LocationListener locationListener, GPXTrack gpxTrack) {
    if (locationSimulator != null) {
      locationSimulator!.stop();
    }

    locationSimulator = _createLocationSimulator(locationListener, gpxTrack);
    locationSimulator!.start();
  }

  void stopLocating() {
    if (locationSimulator != null) {
      locationSimulator!.stop();
      locationSimulator = null;
    }
  }

  LocationSimulator? _createLocationSimulator(LocationListener locationListener, GPXTrack gpxTrack) {
    Duration notificationIntervalInSeconds = Duration(milliseconds: 5);
    LocationSimulatorOptions locationSimulatorOptions = new LocationSimulatorOptions();
    LocationSimulator? locationSimulator;

    locationSimulatorOptions.notificationInterval = notificationIntervalInSeconds;
    locationSimulatorOptions.speedFactor = 2;

    try {
      locationSimulator = new LocationSimulator.withTrack(gpxTrack, locationSimulatorOptions);
    } on InstantiationErrorCode catch (e) {
      print("Error: " + e.name);
    }

    locationSimulator!.listener = locationListener;
    locationSimulator!.start();

    return locationSimulator;
  }
}
