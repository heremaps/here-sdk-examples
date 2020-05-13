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

package com.here.mapobjects;

import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapView;

import java.util.ArrayList;

public class MapObjectsExample {

    private MapScene mapScene;
    private MapPolyline mapPolyline;

    public MapObjectsExample(MapView mapView) {
        MapCamera camera = mapView.getCamera();
        double distanceInMeters = 1000 * 5;
        camera.lookAt(new GeoCoordinates(52.530932, 13.384915), distanceInMeters);

        mapScene = mapView.getMapScene();
    }

    public void showMapPolyline() {
        clearMap();
        mapPolyline = createPolyline();
        mapScene.addMapPolyline(mapPolyline);
    }

    public void clearMapButtonClicked() {
        clearMap();
    }

    private MapPolyline createPolyline() {
        ArrayList<GeoCoordinates> coordinates = new ArrayList<>();
        coordinates.add(new GeoCoordinates(52.53032, 13.37409));
        coordinates.add(new GeoCoordinates(52.5309, 13.3946));
        coordinates.add(new GeoCoordinates(52.53894, 13.39194));
        coordinates.add(new GeoCoordinates(52.54014, 13.37958));

        GeoPolyline geoPolyline;
        try {
            geoPolyline = new GeoPolyline(coordinates);
        } catch (InstantiationErrorException e) {
            // Less than two vertices.
            return null;
        }

        float widthInPixels = 20;
        Color lineColor = new Color((short) 0x00, (short) 0x90, (short) 0x8A, (short) 0xA0);
        MapPolyline mapPolyline = new MapPolyline(geoPolyline, widthInPixels, lineColor);

        return mapPolyline;
    }

    private void clearMap() {
        if (mapPolyline != null) {
            mapScene.removeMapPolyline(mapPolyline);
        }
    }
}
