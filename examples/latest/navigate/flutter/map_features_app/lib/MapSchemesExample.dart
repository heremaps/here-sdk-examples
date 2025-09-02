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

import 'package:here_sdk/mapview.dart';

class MapSchemesExample {
  final MapScene _mapScene;
  MapScheme? _mapScheme;

  MapSchemesExample(HereMapController hereMapController, MapScheme? mapscheme)
    : _mapScene = hereMapController.mapScene,
      _mapScheme = mapscheme;

  void loadSceneForMapScheme(MapScheme mapscheme) {
    _mapScene.loadSceneForMapScheme(mapscheme, (MapError? error) {
      if (error == null) {
        // Map scene loaded successfully
        _mapScheme = mapscheme;
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  MapScheme? getCurrentMapScheme() {
    return _mapScheme;
  }

  void loadCurrentMapScheme() {
    if (_mapScheme != null) {
      loadSceneForMapScheme(_mapScheme!);
    }
  }
}
