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

import heresdk
import SwiftUI

class MapFeaturesExample {
    
    private let mapView: MapView
    private let mapScene: MapScene
    private var mapFeatures: [String: String]
    private let mapCenterGeoCoordinates = GeoCoordinates(latitude: 52.51760485151816, longitude: 13.380312380535472)

    init(mapView: MapView, mapFeatures: [String: String]? = nil) {
        self.mapView = mapView
        self.mapScene = mapView.mapScene
        self.mapFeatures = mapFeatures ?? [:]
        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
        mapView.camera.lookAt(point: mapCenterGeoCoordinates,
                              zoom: distanceInMeters)

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
        
        // Textured landmarks are only available with the Navigate License:
        // mapView.mapScene.enableFeatures([MapFeatures.landmarks : MapFeatureModes.landmarksTextured])
    }
    
    func disableFeatures() {
        mapScene.disableFeatures(Array(mapFeatures.keys))
        mapFeatures.removeAll()
    }
    
    func enableBuildingFootprints() {
        mapFeatures[MapFeatures.buildingFootprints] = MapFeatureModes.buildingFootprintsAll
        mapScene.enableFeatures(mapFeatures)
    }

    func enableAmbientOcclusion() {
        mapFeatures[MapFeatures.ambientOcclusion] = MapFeatureModes.ambientOcclusionAll
        mapScene.enableFeatures(mapFeatures)
    }

    func enableContours() {
        mapFeatures[MapFeatures.contours] = MapFeatureModes.contoursAll
        mapScene.enableFeatures(mapFeatures)
    }

    func enableLowSpeedZones() {
        mapFeatures[MapFeatures.lowSpeedZones] = MapFeatureModes.lowSpeedZonesAll
        mapScene.enableFeatures(mapFeatures)
    }

    func enableCongestionZones() {
        mapFeatures[MapFeatures.congestionZones] = MapFeatureModes.congestionZonesAll
        mapScene.enableFeatures(mapFeatures)
    }

    func enableEnvironmentalZones() {
        mapFeatures[MapFeatures.environmentalZones] = MapFeatureModes.environmentalZonesAll
        mapScene.enableFeatures(mapFeatures)
    }

    func enableExtrudedBuildings() {
        mapFeatures[MapFeatures.extrudedBuildings] = MapFeatureModes.extrudedBuildingsAll
        mapScene.enableFeatures(mapFeatures)
    }

    func enableLandmarksTextured() {
        mapFeatures[MapFeatures.landmarks] = MapFeatureModes.landmarksTextured
        mapScene.enableFeatures(mapFeatures)
    }

    func enableLandmarksTextureless() {
        mapFeatures[MapFeatures.landmarks] = MapFeatureModes.landmarksTextureless
        mapScene.enableFeatures(mapFeatures)
    }

    func enableSafetyCameras() {
        mapFeatures[MapFeatures.safetyCameras] = MapFeatureModes.safetyCamerasAll
        mapScene.enableFeatures(mapFeatures)
    }

    func enableShadows() {
        // MapFeatures.shadows is only available for non-satellite-based map schemes.
        mapFeatures[MapFeatures.shadows] = MapFeatureModes.shadowsAll
        
        // Sets the desired shadow quality for all instances of MapView.
        // If no quality is configured, the feature has no effect and shadows are not rendered.
        // Enabling shadows impacts performance and should be used only on sufficiently capable devices.
        MapView.shadowQuality = ShadowQuality.veryHigh
        mapScene.enableFeatures(mapFeatures)
    }

    func enableTerrainHillShade() {
        mapFeatures[MapFeatures.terrain] = MapFeatureModes.terrainHillshade
        mapScene.enableFeatures(mapFeatures)
    }

    func enableTerrain3D() {
        mapFeatures[MapFeatures.terrain] = MapFeatureModes.terrain3d
        mapScene.enableFeatures(mapFeatures)
    }

    func enableTrafficFlowWithFreeFlow() {
        mapFeatures[MapFeatures.trafficFlow] = MapFeatureModes.trafficFlowWithFreeFlow
        mapScene.enableFeatures(mapFeatures)
    }

    func enableTrafficFlowWithoutFreeFlow() {
        mapFeatures[MapFeatures.trafficFlow] = MapFeatureModes.trafficFlowJapanWithoutFreeFlow
        mapScene.enableFeatures(mapFeatures)
    }

    func enableTrafficIncidents() {
        mapFeatures[MapFeatures.trafficIncidents] = MapFeatureModes.trafficIncidentsAll
        mapScene.enableFeatures(mapFeatures)
    }

    func enableVehicleRestrictionsActive() {
        mapFeatures[MapFeatures.vehicleRestrictions] = MapFeatureModes.vehicleRestrictionsActive
        mapScene.enableFeatures(mapFeatures)
    }

    func enableVehicleRestrictionsActiveAndInactive() {
        mapFeatures[MapFeatures.vehicleRestrictions] = MapFeatureModes.vehicleRestrictionsActiveAndInactive
        mapScene.enableFeatures(mapFeatures)
    }

    func enableVehicleRestrictionsActiveAndInactiveDiff() {
        mapFeatures[MapFeatures.vehicleRestrictions] = MapFeatureModes.vehicleRestrictionsActiveAndInactiveDifferentiated
        mapScene.enableFeatures(mapFeatures)
    }

    func enableRoadExitLabels() {
        mapFeatures[MapFeatures.roadExitLabels] = MapFeatureModes.roadExitLabelsAll
        mapScene.enableFeatures(mapFeatures)
    }

    func enableRoadExitLabelsNumbersOnly() {
        mapFeatures[MapFeatures.roadExitLabels] = MapFeatureModes.roadExitLabelsNumbersOnly
        mapScene.enableFeatures(mapFeatures)
    }

    func getEnabledFeatures() -> [String: String] {
        return mapFeatures
    }

    func applyEnabledFeaturesForMapScene(mapFeatures: [String: String]?) {
        if let features = mapFeatures {
            mapScene.enableFeatures(features)
        }
    }
    
    private func showDialog(title: String, message: String) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                // Handle OK button action.
                alert.dismiss(animated: true, completion: nil)
            }))
            
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
}
