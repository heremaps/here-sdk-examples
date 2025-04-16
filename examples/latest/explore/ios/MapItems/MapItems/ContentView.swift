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
    @State private var mapView = MapView()
    @State private var mapItemsExample: MapItemsExample?
    @State private var mapObjectsExample: MapObjectsExample?
    @State private var mapViewPinsExample: MapViewPinsExample?
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                
                // The map view should fill the entire screen.
                WrappedMapView(mapView: $mapView)
                    .edgesIgnoringSafeArea(.all)
                
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
                mapItemsExample = MapItemsExample(mapView: mapView)
                mapObjectsExample = MapObjectsExample(mapView: mapView)
                mapViewPinsExample = MapViewPinsExample(mapView: mapView)
            }
        }
    }
    
    /// Builds the sections for the menu. Each section contains items that trigger animations.
    ///
    /// - Returns: An array of `MenuSection` representing the available menu items.
    func buildMenuSections() -> [MenuSection] {
        return [
            buildMapMarkerMenuSection(),
            buildLocationIndicatorMenuSection(),
            buildMapObjectMenuSection(),
            buildMapViewPinsMenuSection(),
            buildClearMenuSection()
        ]
    }
    
    private func buildMapMarkerMenuSection() -> MenuSection {
        return MenuSection(title: "Map Marker", items: [
            MenuItem(title: "Anchored (2D)", onSelect: onAnchoredButtonClicked),
            MenuItem(title: "Centered (2D)", onSelect: onCenteredButtonClicked),
            MenuItem(title: "Marker with text", onSelect: onMarkerWithTextButtonClicked),
            MenuItem(title: "MapMarkerCluster", onSelect: onMapMarkerClusterButtonClicked),
            MenuItem(title: "Flat Marker", onSelect: onFlatMapMarkerButtonClicked),
            MenuItem(title: "2D Texture", onSelect: on2DTextureButtonClicked),
            MenuItem(title: "3D Marker", onSelect: onMapMarker3DClicked)
        ])
    }
    
    private func buildLocationIndicatorMenuSection() -> MenuSection {
        return MenuSection(title: "Location Indicator", items: [
            MenuItem(title: "Pedestrian Style", onSelect: onLocationIndicatorPedestrianButtonClicked),
            MenuItem(title: "Navigation Style", onSelect: onLocationIndicatorNavigationButtonClicked),
            MenuItem(title: "Set Active/Inactive", onSelect: onLocationIndicatorStateClicked)
        ])
    }

    private func buildMapObjectMenuSection() -> MenuSection {
        return MenuSection(title: "Map Object", items: [
            MenuItem(title: "Polyline", onSelect: onMapItemPolylineClicked),
            MenuItem(title: "Polygon", onSelect: onMapItemPolygonClicked),
            MenuItem(title: "Circle", onSelect: onMapItemCircleClicked),
            MenuItem(title: "Arrow", onSelect: onMapItemArrowClicked)
        ])
    }

    private func buildMapViewPinsMenuSection() -> MenuSection {
        return MenuSection(title: "MapView Pins", items: [
            MenuItem(title: "Default", onSelect: onDefaultPinButtonClicked),
            MenuItem(title: "Anchored", onSelect: onAnchoredPinButtonClicked)
        ])
    }

    private func buildClearMenuSection() -> MenuSection {
        return MenuSection(title: "", items: [
            MenuItem(title: "Clear All Map Items", onSelect: onClearButtonClicked)
        ])
    }
    
    private func onAnchoredButtonClicked() {
        mapItemsExample?.onAnchoredButtonClicked()
    }

    private func onCenteredButtonClicked() {
        mapItemsExample?.onCenteredButtonClicked()
    }
    
    private func onMarkerWithTextButtonClicked() {
        mapItemsExample?.onMarkerWithTextButtonClicked()
    }

    private func onMapMarkerClusterButtonClicked() {
        mapItemsExample?.onMapMarkerClusterButtonClicked()
    }

    private func onLocationIndicatorPedestrianButtonClicked() {
        mapItemsExample?.onLocationIndicatorPedestrianButtonClicked()
    }

    private func onLocationIndicatorNavigationButtonClicked() {
        mapItemsExample?.onLocationIndicatorNavigationButtonClicked()
    }

    private func onLocationIndicatorStateClicked() {
        mapItemsExample?.toggleActiveStateForLocationIndicator()
    }

    private func onFlatMapMarkerButtonClicked() {
        mapItemsExample?.onFlatMapMarkerButtonClicked()
    }

    private func on2DTextureButtonClicked() {
        mapItemsExample?.on2DTextureButtonClicked()
    }

    private func onMapMarker3DClicked() {
        mapItemsExample?.onMapMarker3DClicked()
    }

    private func onMapItemPolylineClicked() {
        mapObjectsExample?.onMapPolylineClicked()
    }

    private func onMapItemPolygonClicked() {
        mapObjectsExample?.onMapPolygonClicked()
    }

    private func onMapItemCircleClicked() {
        mapObjectsExample?.onMapCircleClicked()
    }

    private func onMapItemArrowClicked() {
        mapObjectsExample?.onMapArrowClicked()
    }

    private func onDefaultPinButtonClicked() {
        mapViewPinsExample?.onDefaultButtonClicked()
    }

    private func onAnchoredPinButtonClicked() {
        mapViewPinsExample?.onAnchoredButtonClicked()
    }

    private func onClearButtonClicked() {
        mapItemsExample?.onClearButtonClicked()
        mapObjectsExample?.onClearButtonClicked()
        mapViewPinsExample?.onClearButtonClicked()
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
