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

class UnitTestingExample {
    
    private let mapView: MapView
  
    init(_ mapView: MapView) {
        self.mapView = mapView
        
        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      zoom: distanceInMeters)
        
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
        }
    }
}

