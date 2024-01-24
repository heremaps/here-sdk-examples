/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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

import 'dart:io';

import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

class CustomMapStyleExample {
  HereMapController _hereMapController;

  CustomMapStyleExample(HereMapController this._hereMapController) {
    double distanceToEarthInMeters = 60000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);
  }

  void loadCustomMapStyle() {
    File file = File("assets/custom-dark-style-neon-rds.json");
    String filePath = file.path;
    _hereMapController.mapScene.loadSceneFromConfigurationFile(filePath, (MapError? error) {
      if (error == null) {
        // Scene loaded.
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void loadDefaultMapStyle() {
    _hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) {
      if (error == null) {
        // Scene loaded.
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }
}
