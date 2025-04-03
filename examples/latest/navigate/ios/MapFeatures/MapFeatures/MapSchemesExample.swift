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

class MapSchemesExample {

    private let mapScene: MapScene
    private var mapScheme: MapScheme?

    init(mapView: MapView, mapScheme: MapScheme?) {
        // Configure the map.
        mapScene = mapView.mapScene
        self.mapScheme = mapScheme;
    }
    
    func loadSceneForMapScheme(_ mapScheme: MapScheme) {
        mapScene.loadScene(mapScheme: mapScheme, completion: onLoadScene(mapError:))
        self.mapScheme = mapScheme
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
    }

    func getCurrentMapScheme() -> MapScheme? {
        return mapScheme
    }

    func loadCurrentMapScheme() {
        if let currentScheme = mapScheme {
            loadSceneForMapScheme(currentScheme)
        }
    }
}
