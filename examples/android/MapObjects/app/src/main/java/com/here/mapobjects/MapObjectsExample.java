/*
 * Copyright (C) 2019 HERE Europe B.V.
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

import com.here.sdk.core.GeoCircle;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolygon;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.Camera;
import com.here.sdk.mapview.MapCircle;
import com.here.sdk.mapview.MapCircleStyle;
import com.here.sdk.mapview.MapPolygon;
import com.here.sdk.mapview.MapPolygonStyle;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapPolylineStyle;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.PixelFormat;

import java.util.ArrayList;

public class MapObjectsExample {

    private MapScene mapScene;
    private MapPolyline mapPolyline;
    private MapPolygon mapPolygon;
    private MapCircle mapCircle;

    public void onMapSceneLoaded(MapView mapView) {
        Camera mapViewCamera = mapView.getCamera();
        mapViewCamera.setTarget(new GeoCoordinates(52.530932, 13.384915));
        mapViewCamera.setZoomLevel(14);

        mapScene = mapView.getMapScene();
    }

    public void showMapPolyline() {
        clearMap();
        mapPolyline = createPolyline();
        mapScene.addMapPolyline(mapPolyline);
    }

    public void showMapPolygon() {
        clearMap();
        mapPolygon = createPolygon();
        mapScene.addMapPolygon(mapPolygon);
    }

    public void showMapCircle() {
        clearMap();
        mapCircle = createMapCircle();
        mapScene.addMapCircle(mapCircle);
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

        MapPolylineStyle mapPolylineStyle = new MapPolylineStyle();
        mapPolylineStyle.setWidth(20);
        mapPolylineStyle.setColor(0x00908AA0, PixelFormat.RGBA_8888);
        MapPolyline mapPolyline = new MapPolyline(geoPolyline, mapPolylineStyle);

        return mapPolyline;
    }

    private MapPolygon createPolygon() {
        ArrayList<GeoCoordinates> coordinates = new ArrayList<>();
        coordinates.add(new GeoCoordinates(52.53032, 13.37409));
        coordinates.add(new GeoCoordinates(52.5309, 13.3946));
        coordinates.add(new GeoCoordinates(52.53894, 13.39194));
        coordinates.add(new GeoCoordinates(52.54014, 13.37958));

        GeoPolygon geoPolygon;
        try {
            geoPolygon = new GeoPolygon(coordinates);
        } catch (InstantiationErrorException e) {
            // Less than three vertices.
            return null;
        }

        MapPolygonStyle mapPolygonStyle = new MapPolygonStyle();
        mapPolygonStyle.setFillColor(0x00908AA0, PixelFormat.RGBA_8888);
        MapPolygon mapPolygon = new MapPolygon(geoPolygon, mapPolygonStyle);

        return mapPolygon;
    }

    private MapCircle createMapCircle() {
        float radiusInMeters = 300;
        GeoCircle geoCircle = new GeoCircle(new GeoCoordinates(52.530932, 13.384915), radiusInMeters);
        MapCircleStyle mapCircleStyle = new MapCircleStyle();
        mapCircleStyle.setFillColor(0x00908AA0, PixelFormat.RGBA_8888);
        MapCircle mapCircle = new MapCircle(geoCircle, mapCircleStyle);

        return mapCircle;
    }

    private void clearMap() {
        if (mapPolyline != null) {
            mapScene.removeMapPolyline(mapPolyline);
        }

        if (mapPolygon != null) {
            mapScene.removeMapPolygon(mapPolygon);
        }

        if (mapCircle != null) {
            mapScene.removeMapCircle(mapCircle);
        }
    }
}
