/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:here_sdk/navigation.dart';

// Owns and switches the camera behaviors used by the visual lane guidance example.
// AutomotiveCameraBehavior is configured from JSON so tuning can be changed outside code.
// TransitionCameraBehavior enables automatic switching between HD and SD camera behavior during guidance.
// Note: Both TransitionCameraBehavior and AutomotiveCameraBehavior are beta features,
// and related APIs are subject to change.
class CameraBehaviors {
  static const String _automotiveConfigAsset = 'assets/AutomotiveCameraConfig.json';

  final VisualNavigator visualNavigator;
  late final TransitionCameraBehavior transitionCameraBehavior;
  late final AutomotiveCameraBehavior automotiveCameraBehavior;
  CameraBehavior? activeCameraBehavior;

  CameraBehaviors(this.visualNavigator);

  Future<void> initialize() async {
    transitionCameraBehavior = TransitionCameraBehavior.withRecommendedConfiguration();
    final configJson = await _loadAutomotiveCameraConfig();
    print('AutomotiveCameraConfig.json loaded (${configJson.length} chars).');
    print(configJson);
    automotiveCameraBehavior = AutomotiveCameraBehavior.fromJson(configJson);
    automotiveCameraBehavior.activeCameraType = AutomotiveCameraBehaviorActiveCameraType.tracking;
    activeCameraBehavior = automotiveCameraBehavior;
    visualNavigator.cameraBehavior = activeCameraBehavior;
  }

  // Activates TransitionCameraBehavior for automatic switching between lane-level
  // visualization and the standard navigation view.
  // Note: TransitionCameraBehavior is a beta feature and related APIs are subject to change.
  void useTransitionCameraBehavior() {
    activeCameraBehavior = transitionCameraBehavior;
    visualNavigator.cameraBehavior = activeCameraBehavior;
  }

  // Activates AutomotiveCameraBehavior with tracking mode from the loaded JSON configuration.
  // Note: AutomotiveCameraBehavior is a beta feature and related APIs are subject to change.
  void useAutomotiveCameraBehavior() {
    automotiveCameraBehavior.activeCameraType = AutomotiveCameraBehaviorActiveCameraType.tracking;
    activeCameraBehavior = automotiveCameraBehavior;
    visualNavigator.cameraBehavior = activeCameraBehavior;
  }

  bool isAutomotiveCameraSelected() {
    return activeCameraBehavior == automotiveCameraBehavior;
  }

  // Returns the currently selected camera behavior label for UI status.
  String getCameraBehaviorStatus() {
    if (activeCameraBehavior == automotiveCameraBehavior) {
      return 'AutomotiveCameraBehavior';
    }
    return 'TransitionCameraBehavior';
  }

  Future<String> _loadAutomotiveCameraConfig() async {
    final raw = await rootBundle.loadString(_automotiveConfigAsset);
    // Validate JSON early so failures are explicit and easier to debug.
    jsonDecode(raw);
    return raw;
  }
}
