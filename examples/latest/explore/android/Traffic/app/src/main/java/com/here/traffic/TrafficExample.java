/*
 * Copyright (C) 2019-2020 HERE Europe B.V.
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

package com.here.traffic;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapView;

public class TrafficExample {

    private MapView mapView;

    public TrafficExample(MapView mapView) {
        this.mapView = mapView;
        MapCamera camera = mapView.getCamera();
        double distanceInMeters = 1000 * 10;
        camera.lookAt(new GeoCoordinates(52.520798, 13.409408), distanceInMeters);
    }

    public void enableAll() {
        // Show real-time traffic lines and incidents on the map.
        enableTrafficVisualization();
    }

    public void disableAll() {
        disableTrafficVisualization();
    }

    private void enableTrafficVisualization() {
        mapView.getMapScene().setLayerState(MapScene.Layers.TRAFFIC_FLOW, MapScene.LayerState.VISIBLE);
        mapView.getMapScene().setLayerState(MapScene.Layers.TRAFFIC_INCIDENTS, MapScene.LayerState.VISIBLE);
    }

    private void disableTrafficVisualization() {
        mapView.getMapScene().setLayerState(MapScene.Layers.TRAFFIC_FLOW, MapScene.LayerState.HIDDEN);
        mapView.getMapScene().setLayerState(MapScene.Layers.TRAFFIC_INCIDENTS, MapScene.LayerState.HIDDEN);
    }
}
