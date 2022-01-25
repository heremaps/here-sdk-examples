/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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
import UIKit

class TrafficExample {

    private var viewController: UIViewController
    private var mapView: MapViewLite

    init(viewController: UIViewController, mapView: MapViewLite) {
        self.mapView = mapView
        self.viewController = viewController
        let camera = mapView.camera
        camera.setTarget(GeoCoordinates(latitude: 52.530932, longitude: 13.384915))
        camera.setZoomLevel(14)
    }

    func onEnableAllButtonClicked() {
        // Show real-time traffic lines and incidents on the map.
        enableTrafficVisualization()
    }

    func onDisableAllButtonClicked() {
        disableTrafficVisualization()
    }

    private func enableTrafficVisualization() {
        do {
            try mapView.mapScene.setLayerState(layer: MapLayerLite.trafficFlow, newState: LayerStateLite.enabled)
            try mapView.mapScene.setLayerState(layer: MapLayerLite.trafficIncidents, newState: LayerStateLite.enabled)
        } catch let mapSceneError {
            print("Failed to enable traffic visualization. Cause: \(mapSceneError)")
        }
    }

    private func disableTrafficVisualization() {
        do {
            try mapView.mapScene.setLayerState(layer: MapLayerLite.trafficFlow, newState: LayerStateLite.disabled)
            try mapView.mapScene.setLayerState(layer: MapLayerLite.trafficIncidents, newState: LayerStateLite.disabled)
        } catch let mapSceneError {
            print("Failed to disable traffic visualization. Cause: \(mapSceneError)")
        }
    }
}
