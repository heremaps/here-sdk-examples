/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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

package com.here.mapfeatures;

import com.here.sdk.mapview.MapFeatureModes;
import com.here.sdk.mapview.MapFeatures;
import com.here.sdk.mapview.MapScene;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

public class MapFeaturesExample {

    private final MapScene mapScene;
    private Map<String,String> mapFeatures = new HashMap<>();

    public MapFeaturesExample(MapScene mapScene) {
        this.mapScene = mapScene;
    }

    public void disableFeatures() {
        mapScene.disableFeatures(new ArrayList<>(mapFeatures.keySet()));
    }


    public void enableBuildingFootprints() {
        mapFeatures.put(MapFeatures.BUILDING_FOOTPRINTS, MapFeatureModes.BUILDING_FOOTPRINTS_ALL);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableAmbientOcclusion() {
        mapFeatures.put(MapFeatures.AMBIENT_OCCLUSION, MapFeatureModes.AMBIENT_OCCLUSION_ALL);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableContours() {
        mapFeatures.put(MapFeatures.CONTOURS, MapFeatureModes.CONTOURS_ALL);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableLowSpeedZones() {
        mapFeatures.put(MapFeatures.LOW_SPEED_ZONES, MapFeatureModes.LOW_SPEED_ZONES_ALL);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableCongestionZones() {
        mapFeatures.put(MapFeatures.CONGESTION_ZONES, MapFeatureModes.CONGESTION_ZONES_ALL);
        mapScene.enableFeatures( mapFeatures);
    }

    public void enableEnvironmentalZones() {
        mapFeatures.put(MapFeatures.ENVIRONMENTAL_ZONES, MapFeatureModes.ENVIRONMENTAL_ZONES_ALL);
        mapScene.enableFeatures( mapFeatures);
    }

    public void enableExtrudedBuildings() {
        mapFeatures.put(MapFeatures.EXTRUDED_BUILDINGS, MapFeatureModes.EXTRUDED_BUILDINGS_ALL);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableLandmarksTextured() {
        mapFeatures.put(MapFeatures.LANDMARKS, MapFeatureModes.LANDMARKS_TEXTURED);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableLandmarksTextureless() {
        mapFeatures.put(MapFeatures.LANDMARKS, MapFeatureModes.LANDMARKS_TEXTURELESS);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableSafetyCameras() {
        mapFeatures.put(MapFeatures.SAFETY_CAMERAS, MapFeatureModes.SAFETY_CAMERAS_ALL);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableShadows() {
        mapFeatures.put(MapFeatures.SHADOWS, MapFeatureModes.SHADOWS_ALL);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableTerrainHillShade() {
        mapFeatures.put(MapFeatures.TERRAIN, MapFeatureModes.TERRAIN_HILLSHADE);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableTerrain3D() {
        mapFeatures.put(MapFeatures.TERRAIN, MapFeatureModes.TERRAIN_3D);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableTrafficFlowWithFreeFlow() {
        mapFeatures.put(MapFeatures.TRAFFIC_FLOW, MapFeatureModes.TRAFFIC_FLOW_WITH_FREE_FLOW);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableTrafficFlowWithoutFreeFlow() {
        mapFeatures.put(MapFeatures.TRAFFIC_FLOW, MapFeatureModes.TRAFFIC_FLOW_WITHOUT_FREE_FLOW);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableTrafficIncidents() {
        mapFeatures.put(MapFeatures.TRAFFIC_INCIDENTS, MapFeatureModes.TRAFFIC_INCIDENTS_ALL);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableVehicleRestrictionsActive() {
        mapFeatures.put(MapFeatures.VEHICLE_RESTRICTIONS, MapFeatureModes.VEHICLE_RESTRICTIONS_ACTIVE);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableVehicleRestrictionsActiveAndInactive() {
        mapFeatures.put(MapFeatures.VEHICLE_RESTRICTIONS, MapFeatureModes.VEHICLE_RESTRICTIONS_ACTIVE_AND_INACTIVE);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableVehicleRestrictionsActiveAndInactiveDiff() {
        mapFeatures.put(MapFeatures.VEHICLE_RESTRICTIONS, MapFeatureModes.VEHICLE_RESTRICTIONS_ACTIVE_AND_INACTIVE_DIFFERENTIATED);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableRoadExitLabels() {
        mapFeatures.put(MapFeatures.ROAD_EXIT_LABELS, MapFeatureModes.ROAD_EXIT_LABELS_ALL);
        mapScene.enableFeatures(mapFeatures);
    }

    public void enableRoadExitLabelsNumbersOnly() {
        mapFeatures.put(MapFeatures.ROAD_EXIT_LABELS, MapFeatureModes.ROAD_EXIT_LABELS_NUMBERS_ONLY);
        mapScene.enableFeatures(mapFeatures);
    }

    public Map<String, String> getEnabledFeatures() {
        return new HashMap<>(mapFeatures);
    }

    public void applyEnabledFeaturesForMapScene(MapScene targetMapScene) {
        targetMapScene.enableFeatures(mapFeatures);
    }

    public void enableFeature(String featureKey, String featureMode) {
        Map<String, String> featureMap = new HashMap<>();
        featureMap.put(featureKey, featureMode);
        mapScene.enableFeatures(featureMap);
    }
}
