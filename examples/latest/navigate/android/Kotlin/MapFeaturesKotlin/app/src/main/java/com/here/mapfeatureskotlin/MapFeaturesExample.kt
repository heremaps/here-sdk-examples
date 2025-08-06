/*
 * Copyright (C) 2025 HERE Europe B.V.
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
package com.here.mapfeatureskotlin

import com.here.sdk.mapview.MapFeatureModes
import com.here.sdk.mapview.MapFeatures
import com.here.sdk.mapview.MapScene
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.ShadowQuality

class MapFeaturesExample(private val mapScene: MapScene) {

    private val mapFeatures: MutableMap<String, String> = mutableMapOf()

    fun disableFeatures() {
        mapScene.disableFeatures(ArrayList(mapFeatures.keys))
        mapFeatures.clear()
    }

    fun enableBuildingFootprints() {
        mapFeatures[MapFeatures.BUILDING_FOOTPRINTS] = MapFeatureModes.BUILDING_FOOTPRINTS_ALL
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableAmbientOcclusion() {
        mapFeatures[MapFeatures.AMBIENT_OCCLUSION] = MapFeatureModes.AMBIENT_OCCLUSION_ALL
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableContours() {
        mapFeatures[MapFeatures.CONTOURS] = MapFeatureModes.CONTOURS_ALL
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableLowSpeedZones() {
        mapFeatures[MapFeatures.LOW_SPEED_ZONES] = MapFeatureModes.LOW_SPEED_ZONES_ALL
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableCongestionZones() {
        mapFeatures[MapFeatures.CONGESTION_ZONES] = MapFeatureModes.CONGESTION_ZONES_ALL
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableEnvironmentalZones() {
        mapFeatures[MapFeatures.ENVIRONMENTAL_ZONES] = MapFeatureModes.ENVIRONMENTAL_ZONES_ALL
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableExtrudedBuildings() {
        mapFeatures[MapFeatures.EXTRUDED_BUILDINGS] = MapFeatureModes.EXTRUDED_BUILDINGS_ALL
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableLandmarksTextured() {
        mapFeatures[MapFeatures.LANDMARKS] = MapFeatureModes.LANDMARKS_TEXTURED
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableLandmarksTextureless() {
        mapFeatures[MapFeatures.LANDMARKS] = MapFeatureModes.LANDMARKS_TEXTURELESS
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableSafetyCameras() {
        mapFeatures[MapFeatures.SAFETY_CAMERAS] = MapFeatureModes.SAFETY_CAMERAS_ALL
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableShadows() {
        // MapFeatures.SHADOWS is only available for non-satellite-based map schemes.
        mapFeatures[MapFeatures.SHADOWS] = MapFeatureModes.SHADOWS_ALL

        // Sets the desired shadow quality for all instances of MapView.
        // If no quality is configured, the feature has no effect and shadows are not rendered.
        // Enabling shadows impacts performance and should be used only on sufficiently capable devices.
        MapView.setShadowQuality(ShadowQuality.VERY_HIGH)
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableTerrainHillShade() {
        mapFeatures[MapFeatures.TERRAIN] = MapFeatureModes.TERRAIN_HILLSHADE
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableTerrain3D() {
        mapFeatures[MapFeatures.TERRAIN] = MapFeatureModes.TERRAIN_3D
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableTrafficFlowWithFreeFlow() {
        mapFeatures[MapFeatures.TRAFFIC_FLOW] = MapFeatureModes.TRAFFIC_FLOW_WITH_FREE_FLOW
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableTrafficFlowWithoutFreeFlow() {
        mapFeatures[MapFeatures.TRAFFIC_FLOW] = MapFeatureModes.TRAFFIC_FLOW_WITHOUT_FREE_FLOW
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableTrafficIncidents() {
        mapFeatures[MapFeatures.TRAFFIC_INCIDENTS] = MapFeatureModes.TRAFFIC_INCIDENTS_ALL
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableVehicleRestrictionsActive() {
        mapFeatures[MapFeatures.VEHICLE_RESTRICTIONS] = MapFeatureModes.VEHICLE_RESTRICTIONS_ACTIVE
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableVehicleRestrictionsActiveAndInactive() {
        mapFeatures[MapFeatures.VEHICLE_RESTRICTIONS] = MapFeatureModes.VEHICLE_RESTRICTIONS_ACTIVE_AND_INACTIVE
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableVehicleRestrictionsActiveAndInactiveDiff() {
        mapFeatures[MapFeatures.VEHICLE_RESTRICTIONS] = MapFeatureModes.VEHICLE_RESTRICTIONS_ACTIVE_AND_INACTIVE_DIFFERENTIATED
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableRoadExitLabels() {
        mapFeatures[MapFeatures.ROAD_EXIT_LABELS] = MapFeatureModes.ROAD_EXIT_LABELS_ALL
        mapScene.enableFeatures(mapFeatures)
    }

    fun enableRoadExitLabelsNumbersOnly() {
        mapFeatures[MapFeatures.ROAD_EXIT_LABELS] = MapFeatureModes.ROAD_EXIT_LABELS_NUMBERS_ONLY
        mapScene.enableFeatures(mapFeatures)
    }

    fun getEnabledFeatures(): Map<String, String> {
        return HashMap(mapFeatures)
    }

    fun applyEnabledFeaturesForMapScene(targetMapScene: MapScene) {
        targetMapScene.enableFeatures(mapFeatures)
    }

    fun enableFeature(featureKey: String, featureMode: String) {
        val featureMap = mapOf(featureKey to featureMode)
        mapScene.enableFeatures(featureMap)
    }
}
