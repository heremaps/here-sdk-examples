/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

package com.here.mapitems;

import com.here.sdk.core.GeoCircle;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolygon;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapviewlite.Camera;
import com.here.sdk.mapviewlite.MapCircle;
import com.here.sdk.mapviewlite.MapCircleStyle;
import com.here.sdk.mapviewlite.MapPolygon;
import com.here.sdk.mapviewlite.MapPolygonStyle;
import com.here.sdk.mapviewlite.MapPolyline;
import com.here.sdk.mapviewlite.MapPolylineStyle;
import com.here.sdk.mapviewlite.MapScene;
import com.here.sdk.mapviewlite.MapViewLite;
import com.here.sdk.mapviewlite.PixelFormat;

import java.util.ArrayList;

public class MapObjectsExample {

    private static final GeoCoordinates BERLIN_GEO_COORDINATES = new GeoCoordinates(52.51760485151816, 13.380312380535472);
    
    private final MapScene mapScene;
    private final Camera mapCamera;
    private MapPolyline mapPolyline;
    private MapPolygon mapPolygon;
    private MapCircle mapCircle;

    public MapObjectsExample(MapViewLite mapView) {
        mapScene = mapView.getMapScene();
        mapCamera = mapView.getCamera();
    }

    public void showMapPolyline() {
        clearMap();
        // Move map to expected location.
        mapCamera.setTarget(BERLIN_GEO_COORDINATES);
        mapCamera.setZoomLevel(13.0);

        mapPolyline = createPolyline();
        mapScene.addMapPolyline(mapPolyline);
    }

    public void showMapPolygon() {
        clearMap();
        // Move map to expected location.
        mapCamera.setTarget(BERLIN_GEO_COORDINATES);
        mapCamera.setZoomLevel(13.0);

        mapPolygon = createPolygon();
        mapScene.addMapPolygon(mapPolygon);
    }

    public void showMapCircle() {
        clearMap();
        // Move map to expected location.
        mapCamera.setTarget(BERLIN_GEO_COORDINATES);
        mapCamera.setZoomLevel(13.0);

        mapCircle = createMapCircle();
        mapScene.addMapCircle(mapCircle);
    }

    public void clearMap() {
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
        mapPolylineStyle.setWidthInPixels(20);
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
        GeoCircle geoCircle = new GeoCircle(new GeoCoordinates(52.51760485151816, 13.380312380535472), radiusInMeters);
        MapCircleStyle mapCircleStyle = new MapCircleStyle();
        mapCircleStyle.setFillColor(0x00908AA0, PixelFormat.RGBA_8888);
        MapCircle mapCircle = new MapCircle(geoCircle, mapCircleStyle);

        return mapCircle;
    }
}
