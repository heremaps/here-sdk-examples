/*
 * Copyright (C) 2024 HERE Europe B.V.
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
    @State private var cameraKeyframeTracksExample: CameraKeyframeTracksExample?
    @State private var routeAnimationExample: RouteAnimationExample?
    
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
                cameraKeyframeTracksExample = CameraKeyframeTracksExample(mapView)
                routeAnimationExample = RouteAnimationExample(mapView)
            }
        }
    }
    
    /// Builds the sections for the menu. Each section contains items that trigger animations.
    ///
    /// - Returns: An array of `MenuSection` representing the available menu items.
    private func buildMenuSections() -> [MenuSection] {
        return [
            MenuSection(title: "Animate to Route", items: [
                MenuItem(title: "Start Animation", onSelect: onStartAnimationToRouteButtonClicked),
                MenuItem(title: "Stop Animation", onSelect: onStopAnimationToRouteButtonClicked)
            ]),
            MenuSection(title: "Trip to NYC", items: [
                MenuItem(title: "Start trip to NYC", onSelect: onStartTripToNYCButtonClicked),
                MenuItem(title: "Stop trip to NYC", onSelect: onStopTripToNYCButtonClicked)
            ])
        ]
    }
    
    /// Represents a menu item in the menu view.
    struct MenuItem {
        let title: String
        let onSelect: () -> Void
    }
    
    /// Represents a section in the menu view, which contains a list of menu items.
    struct MenuSection {
        let title: String
        let items: [MenuItem]
    }
    
    /// View for displaying the menu. Each menu section and item triggers its respective action.
    struct MenuView: View {
        var menuSections: [MenuSection]
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            NavigationView {
                List {
                    ForEach(menuSections, id: \.title) { section in
                        Section(header: Text(section.title)) {
                            ForEach(section.items, id: \.title) { item in
                                Button(action: {
                                    item.onSelect()
                                    dismiss()
                                }) {
                                    Text(item.title)
                                }
                            }
                        }
                    }
                }
                .navigationBarTitle("Menu")
            }
        }
    }
    
    private func onStartAnimationToRouteButtonClicked() {
        routeAnimationExample?.animateToRoute()
    }
    
    private func onStopAnimationToRouteButtonClicked() {
        routeAnimationExample?.stopRouteAnimation()
    }

    private func onStartTripToNYCButtonClicked() {
        cameraKeyframeTracksExample?.startTripToNYC()
    }
    
    private func onStopTripToNYCButtonClicked() {
        cameraKeyframeTracksExample?.stopTripToNYCAnimation()
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
    
    /// `WrappedMapView` is a wrapper around the HERE SDK `MapView` to make it compatible with SwiftUI.
    /// It uses `UIViewRepresentable` to bridge UIKit with SwiftUI
    private struct WrappedMapView: UIViewRepresentable {
        @Binding var mapView: MapView
        func makeUIView(context: Context) -> MapView { return mapView }
        func updateUIView(_ mapView: MapView, context: Context) { }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

