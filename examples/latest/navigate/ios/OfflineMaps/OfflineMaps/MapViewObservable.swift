/*
 * Copyright (C) 2022-2024 HERE Europe B.V.
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

import Foundation
import heresdk

class MapViewObservable : ObservableObject {
    @Published var mapView: MapView?  

    init() {
        self.mapView = MapView()
    }
    
    func configureMapView() {
        self.mapView = self.mapView ?? MapView()
        let camera = self.mapView!.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 1000 * 7)
        camera.lookAt(point: GeoCoordinates(latitude: 52.530932, longitude: 13.384915),
                      zoom: distanceInMeters)
        // Load the map scene using a map scheme to render the map with.
        self.mapView!.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)

    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
        }
    }
    
    func resetMapView() {
        self.mapView = nil
    }
}

