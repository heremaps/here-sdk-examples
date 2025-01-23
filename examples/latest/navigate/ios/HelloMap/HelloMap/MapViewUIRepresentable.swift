/*
 * Copyright (C) 2022-2025 HERE Europe B.V.
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

// The MapView provided by the HERE SDK conforms to a UIKit view, so it needs to be wrapped to conform
// to a SwiftUI view using the UIViewRepresentable protocol.
// Make sure that the HERE SDK is initialized beforehand, see HelloMapApp class.
struct MapViewUIRepresentable: UIViewRepresentable {
    
    // Conform to UIViewRepresentable protocol.
    func makeUIView(context: Context) -> MapView {
        // Create an instance of the map view.
        return MapView()
    }
    
    // Conform to UIViewRepresentable protocol.
    func updateUIView(_ mapView: MapView, context: Context) {
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
        
        // Inlined completion handler for onLoadScene().
        func onLoadScene(mapError: MapError?) {
            guard mapError == nil else {
                print("Error: Map scene not loaded, \(String(describing: mapError))")
                return
            }
            
            // Use the camera to specify where to look at the map.
            // For this example, we show Berlin in Germany.
            let camera = mapView.camera
            let distanceInMeters = MapMeasure(kind: .distance, value: 1000)
            camera.lookAt(point: GeoCoordinates(latitude: 52.517543, longitude: 13.408991), zoom: distanceInMeters)
        }
    }
}

// Create a preview representation for the Xcode canvas.
struct MapViewUIRepresentable_Previews: PreviewProvider {
    static var previews: some View {
        MapViewUIRepresentable()
            .edgesIgnoringSafeArea(.all)
    }
}
