/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

class TrafficExample {
  HereMapController _hereMapController;

  TrafficExample(HereMapController hereMapController) {
    _hereMapController = hereMapController;

    double distanceToEarthInMeters = 10000;
    _hereMapController.camera.lookAtPointWithDistance(
        GeoCoordinates(52.520798, 13.409408), distanceToEarthInMeters);
  }

  void enableAll() {
    // Show real-time traffic lines and incidents on the map.
    _enableTrafficVisualization();
  }

  void disableAll() {
    _disableTrafficVisualization();
  }

  void _enableTrafficVisualization() {
    _hereMapController.mapScene
        .setLayerState(MapSceneLayers.trafficFlow, MapSceneLayerState.visible);
    _hereMapController.mapScene.setLayerState(
        MapSceneLayers.trafficIncidents, MapSceneLayerState.visible);
  }

  void _disableTrafficVisualization() {
    _hereMapController.mapScene
        .setLayerState(MapSceneLayers.trafficFlow, MapSceneLayerState.hidden);
    _hereMapController.mapScene.setLayerState(
        MapSceneLayers.trafficIncidents, MapSceneLayerState.hidden);
  }
}
