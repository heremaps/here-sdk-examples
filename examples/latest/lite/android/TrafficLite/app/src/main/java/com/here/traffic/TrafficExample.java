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

package com.here.traffic;

import android.content.Context;
import android.widget.Toast;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.mapviewlite.Camera;
import com.here.sdk.mapviewlite.LayerState;
import com.here.sdk.mapviewlite.MapLayer;
import com.here.sdk.mapviewlite.MapScene;
import com.here.sdk.mapviewlite.MapViewLite;

public class TrafficExample {

    private Context context;
    private MapViewLite mapView;
    private Camera camera;

    public TrafficExample(Context context, MapViewLite mapView) {
        this.context = context;
        this.mapView = mapView;
        camera = mapView.getCamera();
        camera.setTarget(new GeoCoordinates(52.530932, 13.384915));
        camera.setZoomLevel(14);
    }

    public void enableAll() {
        // Show real-time traffic lines and incidents on the map.
        enableTrafficVisualization();
    }

    public void disableAll() {
        disableTrafficVisualization();
    }

    private void enableTrafficVisualization() {
        try {
            mapView.getMapScene().setLayerState(MapLayer.TRAFFIC_FLOW, LayerState.ENABLED);
            mapView.getMapScene().setLayerState(MapLayer.TRAFFIC_INCIDENTS, LayerState.ENABLED);
        } catch (MapScene.MapSceneException e) {
            Toast.makeText(context, "Exception when enabling traffic visualization.", Toast.LENGTH_LONG).show();
        }
    }

    private void disableTrafficVisualization() {
        try {
            mapView.getMapScene().setLayerState(MapLayer.TRAFFIC_FLOW, LayerState.DISABLED);
            mapView.getMapScene().setLayerState(MapLayer.TRAFFIC_INCIDENTS, LayerState.DISABLED);
        } catch (MapScene.MapSceneException e) {
            Toast.makeText(context, "Exception when disabling traffic visualization.", Toast.LENGTH_LONG).show();
        }
    }
}
