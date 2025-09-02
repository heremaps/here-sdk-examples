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

import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

// A callback to notifiy the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

class MapFeaturesExample {
  final HereMapController _hereMapController;
  final MapScene _mapScene;
  Map<String, String> _mapFeatures;

  MapFeaturesExample(HereMapController hereMapController, Map<String, String>? mapFeatures)
    : _mapScene = hereMapController.mapScene,
      _mapFeatures = mapFeatures ?? {},
      _hereMapController = hereMapController {
    double distanceToEarthInMeters = 8000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(
      GeoCoordinates(52.51760485151816, 13.380312380535472),
      mapMeasureZoom,
    );
  }

  void disableFeatures() {
    _mapScene.disableFeatures(_mapFeatures.keys.toList());
    _mapFeatures.clear();
  }

  void enableBuildingFootprints() {
    _mapFeatures[MapFeatures.buildingFootprints] = MapFeatureModes.buildingFootprintsAll;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableAmbientOcclusion() {
    _mapFeatures[MapFeatures.ambientOcclusion] = MapFeatureModes.ambientOcclusionAll;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableContours() {
    _mapFeatures[MapFeatures.contours] = MapFeatureModes.contoursAll;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableLowSpeedZones() {
    _mapFeatures[MapFeatures.lowSpeedZones] = MapFeatureModes.lowSpeedZonesAll;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableCongestionZones() {
    _mapFeatures[MapFeatures.congestionZones] = MapFeatureModes.congestionZonesAll;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableEnvironmentalZones() {
    _mapFeatures[MapFeatures.environmentalZones] = MapFeatureModes.environmentalZonesAll;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableExtrudedBuildings() {
    _mapFeatures[MapFeatures.extrudedBuildings] = MapFeatureModes.extrudedBuildingsAll;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableLandmarksTextured() {
    _mapFeatures[MapFeatures.landmarks] = MapFeatureModes.landmarksTextured;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableLandmarksTextureless() {
    _mapFeatures[MapFeatures.landmarks] = MapFeatureModes.landmarksTextureless;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableSafetyCameras() {
    _mapFeatures[MapFeatures.safetyCameras] = MapFeatureModes.safetyCamerasAll;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableShadows() {
    // MapFeatures.shadows is only available for non-satellite-based map schemes.
    _mapFeatures[MapFeatures.shadows] = MapFeatureModes.shadowsAll;

    // Sets the desired shadow quality for all instances of MapView.
    // If no quality is configured, the feature has no effect and shadows are not rendered.
    // Enabling shadows impacts performance and should be used only on sufficiently capable devices.
    HereMapController.shadowQuality = ShadowQuality.veryHigh;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableTerrainHillShade() {
    _mapFeatures[MapFeatures.terrain] = MapFeatureModes.terrainHillshade;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableTerrain3D() {
    _mapFeatures[MapFeatures.terrain] = MapFeatureModes.terrain3d;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableTrafficFlowWithFreeFlow() {
    _mapFeatures[MapFeatures.trafficFlow] = MapFeatureModes.trafficFlowWithFreeFlow;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableTrafficFlowWithoutFreeFlow() {
    _mapFeatures[MapFeatures.trafficFlow] = MapFeatureModes.trafficFlowJapanWithoutFreeFlow;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableTrafficIncidents() {
    _mapFeatures[MapFeatures.trafficIncidents] = MapFeatureModes.trafficIncidentsAll;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableVehicleRestrictionsActive() {
    _mapFeatures[MapFeatures.vehicleRestrictions] = MapFeatureModes.vehicleRestrictionsActive;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableVehicleRestrictionsActiveAndInactive() {
    _mapFeatures[MapFeatures.vehicleRestrictions] = MapFeatureModes.vehicleRestrictionsActiveAndInactive;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableVehicleRestrictionsActiveAndInactiveDiff() {
    _mapFeatures[MapFeatures.vehicleRestrictions] = MapFeatureModes.vehicleRestrictionsActiveAndInactiveDifferentiated;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableRoadExitLabels() {
    _mapFeatures[MapFeatures.roadExitLabels] = MapFeatureModes.roadExitLabelsAll;
    _mapScene.enableFeatures(_mapFeatures);
  }

  void enableRoadExitLabelsNumbersOnly() {
    _mapFeatures[MapFeatures.roadExitLabels] = MapFeatureModes.roadExitLabelsNumbersOnly;
    _mapScene.enableFeatures(_mapFeatures);
  }

  Map<String, String> getEnabledFeatures() {
    return Map<String, String>.from(_mapFeatures);
  }

  void applyEnabledFeaturesForMapScene(Map<String, String>? mapFeatures) {
    if (mapFeatures != null) {
      _mapScene.enableFeatures(mapFeatures);
    }
  }
}
