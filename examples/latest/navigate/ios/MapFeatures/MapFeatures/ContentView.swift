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

import heresdk
import SwiftUI

struct ContentView: View {
    
    /// State variable to control the visibility of the menu.
    @State private var showMenu = false
    @State private var mapViewGlobe = MapView()
    @State private var mapViewWebMercator = MapView(options: MapViewOptions(projection: MapProjection.webMercator))
    @State private var mapFeaturesExample: MapFeaturesExample?
    @State private var mapSchemesExample: MapSchemesExample?
    @State private var isWebMercatorProjection: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                
                if isWebMercatorProjection {
                    WrappedMapView(mapView: $mapViewWebMercator)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    WrappedMapView(mapView: $mapViewGlobe)
                        .edgesIgnoringSafeArea(.all)
                }
                
                VStack {
                    HStack {
                        CustomMenuButton(showMenu: $showMenu)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .sheet(isPresented: $showMenu) {
                // Presents the menu view as a sheet when showMenu is true.
                MenuView(menuSections: buildMenuSections())
            }
            .onAppear {
                // ContentView appeared, now we init the examples.
                mapFeaturesExample = MapFeaturesExample(mapView: mapViewGlobe)
                mapSchemesExample = MapSchemesExample(mapView: mapViewGlobe, mapScheme: .normalDay)
            }
        }
    }
    
    /// Builds the sections for the menu. Each section contains items that trigger animations.
    ///
    /// - Returns: An array of `MenuSection` representing the available menu items.
    func buildMenuSections() -> [MenuSection] {
        return [
            buildMapSchemeMenuSection(),
            buildMapFeaturesMenuSection(),
            buildWebMercatorProjectionMenu()
        ]
    }
    
    private func buildMapSchemeMenuSection() -> MenuSection {
        return MenuSection(title: "Map Schemes", items: [
            MenuItem(title: "Lite Night", onSelect: loadSceneLiteNightScheme),
            MenuItem(title: "Hybrid Day", onSelect: loadSceneHybridDayScheme),
            MenuItem(title: "Hybrid Night", onSelect: loadSceneHybridNightScheme),
            MenuItem(title: "Lite Day", onSelect: loadSceneLiteDayScheme),
            MenuItem(title: "Lite Hybrid Day", onSelect: loadSceneLiteHybridDayScheme),
            MenuItem(title: "Lite Hybrid Night", onSelect: loadSceneLiteHybridNightScheme),
            MenuItem(title: "Logistics Day", onSelect: loadSceneLogisticsDayScheme),
            MenuItem(title: "Logistics Hybrid Day", onSelect: loadSceneLogisticsHybridDayScheme),
            MenuItem(title: "Logistics Night", onSelect: loadSceneLogisticsNightScheme),
            MenuItem(title: "Logistics Hybrid Night", onSelect: loadSceneLogisticsHybridNightScheme),
            MenuItem(title: "Normal Day", onSelect: loadSceneNormalDayScheme),
            MenuItem(title: "Normal Night", onSelect: loadSceneNormalNightScheme),
            MenuItem(title: "Road Network Day", onSelect: loadSceneRoadNetworkDayScheme),
            MenuItem(title: "Road Network Night", onSelect: loadSceneRoadNetworkNightScheme),
            MenuItem(title: "Satellite", onSelect: loadSceneSatelliteScheme),
            MenuItem(title: "Topo Day", onSelect: loadSceneTopoDayScheme),
            MenuItem(title: "Topo Night", onSelect: loadSceneTopoNightScheme)
        ])
    }
    
    private func buildMapFeaturesMenuSection() -> MenuSection {
        return MenuSection(title: "Map Features", items: [
            MenuItem(title: "Clear Map Features", onSelect: clearMapFeaturesButtonClicked),
            MenuItem(title: "Ambient Occlusion", onSelect: ambientOcclusionButtonClicked),
            MenuItem(title: "Building Footprints", onSelect: buildingFootprintsButtonClicked),
            MenuItem(title: "Congestion Zone", onSelect: congestionZoneButtonClicked),
            MenuItem(title: "Environmental Zones", onSelect: environmentalZonesButtonClicked),
            MenuItem(title: "Extruded Buildings", onSelect: extrudedBuildingsButtonClicked),
            MenuItem(title: "Landmarks Textured", onSelect: landmarksTexturedButtonClicked),
            MenuItem(title: "Landmarks Textureless", onSelect: landmarksTexturelessButtonClicked),
            MenuItem(title: "Safety Cameras", onSelect: safetyCamerasButtonClicked),
            MenuItem(title: "Shadows", onSelect: shadowsButtonClicked),
            MenuItem(title: "Terrain Hillshade", onSelect: terrainHillshadeButtonClicked),
            MenuItem(title: "Terrain 3D", onSelect: terrain3DButtonClicked),
            MenuItem(title: "Contours", onSelect: contoursButtonClicked),
            MenuItem(title: "Low Speed Zones", onSelect: lowSpeedZonesButtonClicked),
            MenuItem(title: "Traffic Flow with Free Flow", onSelect: trafficFlowWithFreeFlowButtonClicked),
            MenuItem(title: "Traffic Flow without Free Flow", onSelect: trafficFlowWithoutFreeFlowButtonClicked),
            MenuItem(title: "Traffic Incidents", onSelect: trafficIncidentsButtonClicked),
            MenuItem(title: "Vehicle Restrictions Active", onSelect: vehicleRestrictionsActiveButtonClicked),
            MenuItem(title: "Vehicle Restrictions Active/Inactive", onSelect: vehicleRestrictionsActiveInactiveButtonClicked),
            MenuItem(title: "Vehicle Restrictions Active/Inactive Diff", onSelect: vehicleRestrictionsActiveInactiveDiffButtonClicked),
            MenuItem(title: "Road Exit Labels", onSelect: roadExitLabelsButtonClicked),
            MenuItem(title: "Road Exit Labels Numbers Only", onSelect: roadExitLabelsNumbersOnlyButtonClicked)

        ])
    }

    private func buildWebMercatorProjectionMenu() -> MenuSection {
        return MenuSection(title: "Web Mercator", items: [
            MenuItem(title: "Web Mercator Projection", onSelect: onWebMercatorClicked),
        ])
    }

    private func onWebMercatorClicked() {
        isWebMercatorProjection.toggle()
        let currentEnabledFeatures = mapFeaturesExample?.getEnabledFeatures()
        mapFeaturesExample = MapFeaturesExample(mapView: isWebMercatorProjection ? mapViewWebMercator: mapViewGlobe, mapFeatures: currentEnabledFeatures)
        mapFeaturesExample?.applyEnabledFeaturesForMapScene(mapFeatures: currentEnabledFeatures)
        let currentMapScheme = mapSchemesExample?.getCurrentMapScheme()
        mapSchemesExample = MapSchemesExample(mapView: isWebMercatorProjection ? mapViewWebMercator: mapViewGlobe, mapScheme: currentMapScheme)
        mapSchemesExample?.loadCurrentMapScheme()
    }

    // Map Schemes
    func loadSceneLiteNightScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.liteNight)
    }

    func loadSceneHybridDayScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.hybridDay)
    }

    func loadSceneHybridNightScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.hybridNight)
    }

    func loadSceneLiteDayScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.liteDay)
    }

    func loadSceneLiteHybridDayScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.liteHybridDay)
    }

    func loadSceneLiteHybridNightScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.liteHybridNight)
    }

    func loadSceneLogisticsDayScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.logisticsDay)
    }

    func loadSceneLogisticsHybridDayScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.logisticsHybridDay)
    }

    func loadSceneLogisticsNightScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.logisticsNight)
    }

    func loadSceneLogisticsHybridNightScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.liteHybridNight)
    }

    func loadSceneNormalDayScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.normalDay)
    }

    func loadSceneNormalNightScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.normalNight)
    }

    func loadSceneRoadNetworkDayScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.roadNetworkDay)
    }

    func loadSceneRoadNetworkNightScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.roadNetworkNight)
    }

    func loadSceneSatelliteScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.satellite)
    }

    func loadSceneTopoDayScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.topoDay)
    }

    func loadSceneTopoNightScheme() {
        mapSchemesExample?.loadSceneForMapScheme(.topoNight)
    }

    // Map Features
    func clearMapFeaturesButtonClicked() {
        mapFeaturesExample?.disableFeatures()
    }

    func buildingFootprintsButtonClicked() {
        mapFeaturesExample?.enableBuildingFootprints()
    }

    func congestionZoneButtonClicked() {
        mapFeaturesExample?.enableCongestionZones()
    }

    func environmentalZonesButtonClicked() {
        mapFeaturesExample?.enableEnvironmentalZones()
    }

    func extrudedBuildingsButtonClicked() {
        mapFeaturesExample?.enableBuildingFootprints()
    }

    func landmarksTexturedButtonClicked() {
        mapFeaturesExample?.enableLandmarksTextured()
    }

    func landmarksTexturelessButtonClicked() {
        mapFeaturesExample?.enableLandmarksTextureless()
    }

    func safetyCamerasButtonClicked() {
        mapFeaturesExample?.enableSafetyCameras()
    }

    func shadowsButtonClicked() {
        mapFeaturesExample?.enableShadows()
    }

    func terrainHillshadeButtonClicked() {
        mapFeaturesExample?.enableTerrainHillShade()
    }

    func terrain3DButtonClicked() {
        mapFeaturesExample?.enableTerrain3D()
    }

    func ambientOcclusionButtonClicked() {
        mapFeaturesExample?.enableAmbientOcclusion()
    }

    func contoursButtonClicked() {
        mapFeaturesExample?.enableContours()
    }

    func lowSpeedZonesButtonClicked() {
        mapFeaturesExample?.enableLowSpeedZones()
    }

    func trafficFlowWithFreeFlowButtonClicked() {
        mapFeaturesExample?.enableTrafficFlowWithFreeFlow()
    }

    func trafficFlowWithoutFreeFlowButtonClicked() {
        mapFeaturesExample?.enableTrafficFlowWithoutFreeFlow()
    }

    func trafficIncidentsButtonClicked() {
        mapFeaturesExample?.enableTrafficIncidents()
    }

    func vehicleRestrictionsActiveButtonClicked() {
        mapFeaturesExample?.enableVehicleRestrictionsActive()
    }

    func vehicleRestrictionsActiveInactiveButtonClicked() {
        mapFeaturesExample?.enableVehicleRestrictionsActiveAndInactive()
    }

    func vehicleRestrictionsActiveInactiveDiffButtonClicked() {
        mapFeaturesExample?.enableVehicleRestrictionsActiveAndInactiveDiff()
    }

    func roadExitLabelsButtonClicked() {
        mapFeaturesExample?.enableRoadExitLabels()
    }

    func roadExitLabelsNumbersOnlyButtonClicked() {
        mapFeaturesExample?.enableRoadExitLabelsNumbersOnly()
    }

}

// The MapView provided by the HERE SDK conforms to a UIKit view, so it needs to be wrapped to conform
// to a SwiftUI view. The map view is created in the ContentView and bound here.
private struct WrappedMapView: UIViewRepresentable {
    @Binding var mapView: MapView
    func makeUIView(context: Context) -> MapView { return mapView }
    func updateUIView(_ mapView: MapView, context: Context) { }
}

/// `CustomMenuButton` is a reusable SwiftUI view that displays a button with a menu icon.
private struct CustomMenuButton: View {
    // Use @Binding to connect to the state from the parent view.
    @Binding var showMenu: Bool
    
    var body: some View {
        Button(action: {
            showMenu.toggle()
        }) {
            Image(systemName: "line.horizontal.3")
                .resizable()
                .frame(width: 25, height: 25)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
