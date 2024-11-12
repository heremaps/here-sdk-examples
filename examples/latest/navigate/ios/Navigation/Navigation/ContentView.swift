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

struct ContentView: View, TextViewUpdateDelegate {
    
    @State private var mapView = MapView()
    @State private var navigationAppLogic: NavigationAppLogic?
    @State private var message: String = "Initializing..."
    
    var body: some View {
        // Show the views on top of each other.
        ZStack(alignment: .top) {
            
            // The map view should fill the entire screen.
            WrappedMapView(mapView: $mapView)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    CustomButton(title: "Add Route (Simulated Location)") {
                        navigationAppLogic?.addRouteSimulatedLocationButtonClicked()
                    }
                    CustomButton(title: "Add Route (Device Location)") {
                        navigationAppLogic?.addRouteDeviceLocationButtonClicked()
                    }
                }
                HStack {
                    CustomToggleButton(
                        onLabel: "Camera Tracking: Off",
                        offLabel: "Camera Tracking: On",
                        onAction: {
                            navigationAppLogic?.disableCameraTracking()
                        },
                        offAction: {
                            navigationAppLogic?.enableCameraTracking()
                        }
                    )
                    CustomButton(title: "Clear map") {
                        navigationAppLogic?.clearMapButtonClicked()
                    }
                }
                HStack {
                    // A permanent view to show log content such as maneuver information.
                    CustomTextView(message: message)
                }
            }
        }
        .onAppear {
            // ContentView appeared, now we init the example.
            navigationAppLogic = NavigationAppLogic(mapView)
            navigationAppLogic?.textViewUpdateDelegate = self
        }
    }
        
    // Updates the message displayed on CustomTextView.
    func updateTextViewMessage(_ message: String) {
        self.message = message
    }
}

// The MapView provided by the HERE SDK conforms to a UIKit view, so it needs to be wrapped to conform
// to a SwiftUI view. The map view is created in the ContentView and bound here.
private struct WrappedMapView: UIViewRepresentable {
    @Binding var mapView: MapView
    func makeUIView(context: Context) -> MapView { return mapView }
    func updateUIView(_ mapView: MapView, context: Context) { }
}

// Protocol to delegate text message updates to display in ContentView.
protocol TextViewUpdateDelegate {
    func updateTextViewMessage(_ message: String)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
