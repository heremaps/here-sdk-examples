/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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
import 'package:here_sdk/location.dart';

// A reference implementation using HERE Positioning to get notified on location updates
// from various location sources available from a device and HERE services.
//
// Note: Make sure to set the required permissions:
// Android: navigation_app/android/app/src/main/AndroidManifest.xml
// iOS: navigation_app/ios/Runner/Info.plist
//
// This app uses the permission_handler plugin to handle the permissions for iOS and Android.
//
// Important: When using HERE Positioning in your app on Android devices,
// it is required to request and to show the user's consent decision.
// In addition, users must be able to change their consent decision at any time.
// In main.dart you can see an example how the consent handling can be implemented.
//
// Note that this app does not show how to get background location updates. If you want to enable
// background location updates, please refer to the "Get Locations" section in the Developer's Guide.
class HEREPositioningProvider implements LocationStatusListener {
  late LocationEngine _locationEngine;
  late LocationListener updateListener;

  HEREPositioningProvider() {
    try {
      _locationEngine = LocationEngine();
    } on InstantiationException {
      throw ("Initialization of LocationEngine failed.");
    }
  }

  Location? getLastKnownLocation() {
    return _locationEngine.lastKnownLocation;
  }

  // Does nothing when engine is already started.
  void startLocating(LocationListener updateListener, LocationAccuracy accuracy) {
    if (_locationEngine.isStarted) {
      return;
    }

    this.updateListener = updateListener;

    // Set listeners to get location updates.
    _locationEngine.addLocationListener(updateListener);
    _locationEngine.addLocationStatusListener(this);

    _locationEngine.startWithLocationAccuracy(accuracy);
  }

// Does nothing when engine is already stopped.
  void stop() {
    if (!_locationEngine.isStarted) {
      return;
    }

    // Remove listeners and stop location engine.
    _locationEngine.removeLocationStatusListener(this);
    _locationEngine.removeLocationListener(updateListener);
    _locationEngine.stop();
  }

  @override
  void onStatusChanged(LocationEngineStatus locationEngineStatus) {
    print("Location engine status: " + locationEngineStatus.toString());
  }

  @override
  onFeaturesNotAvailable(List<LocationFeature> features) {
    for (var feature in features) {
      print("Feature not available: " + feature.toString());
    }
  }

  @override
  void release() {
    stop();
  }
}
