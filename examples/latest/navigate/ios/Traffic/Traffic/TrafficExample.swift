/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

class TrafficExample {

    private var mapView: MapView

    init(mapView: MapView) {
        self.mapView = mapView
        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      distanceInMeters: 1000 * 10)
    }

    func onEnableAllButtonClicked() {
        // Show real-time traffic lines and incidents on the map.
        enableTrafficVisualization()
    }

    func onDisableAllButtonClicked() {
        disableTrafficVisualization()
    }

    private func enableTrafficVisualization() {
        mapView.mapScene.setLayerState(layerName: MapScene.Layers.trafficFlow,
                                       newState: MapScene.LayerState.visible)
        mapView.mapScene.setLayerState(layerName: MapScene.Layers.trafficIncidents,
                                       newState: MapScene.LayerState.visible)
    }

    private func disableTrafficVisualization() {
        mapView.mapScene.setLayerState(layerName: MapScene.Layers.trafficFlow,
                                       newState: MapScene.LayerState.hidden)
        mapView.mapScene.setLayerState(layerName: MapScene.Layers.trafficIncidents,
                                       newState: MapScene.LayerState.hidden)
    }
}
