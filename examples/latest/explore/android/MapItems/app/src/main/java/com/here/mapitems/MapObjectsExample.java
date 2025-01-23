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

package com.here.mapitems;

import android.util.Log;

import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCircle;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoCoordinatesUpdate;
import com.here.sdk.core.GeoPolygon;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.LineCap;
import com.here.sdk.mapview.MapArrow;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapMeasureDependentRenderSize;
import com.here.sdk.mapview.MapPolygon;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.RenderSize;
import com.here.time.Duration;

import java.util.ArrayList;

public class MapObjectsExample {

    private static final  GeoCoordinates BERLIN_GEO_COORDINATES = new GeoCoordinates(52.51760485151816, 13.380312380535472);

    private final MapScene mapScene;
    private final MapCamera mapCamera;
    private MapPolyline mapPolyline;
    private MapArrow mapArrow;
    private MapPolygon mapPolygon;
    private MapPolygon mapCircle;

    public MapObjectsExample(MapView mapView) {
        mapScene = mapView.getMapScene();
        mapCamera = mapView.getCamera();
    }

    public void showMapPolyline() {
        clearMap();
        // Move map to expected location.
        flyTo(BERLIN_GEO_COORDINATES);

        mapPolyline = createPolyline();
        mapScene.addMapPolyline(mapPolyline);
    }

    public void showMapArrow() {
        clearMap();
        // Move map to expected location.
        flyTo(BERLIN_GEO_COORDINATES);

        mapArrow = createMapArrow();
        mapScene.addMapArrow(mapArrow);
    }

    public void showMapPolygon() {
        clearMap();
        // Move map to expected location.
        flyTo(BERLIN_GEO_COORDINATES);

        mapPolygon = createPolygon();
        mapScene.addMapPolygon(mapPolygon);
    }

    public void showMapCircle() {
        clearMap();
        // Move map to expected location.
        flyTo(BERLIN_GEO_COORDINATES);

        mapCircle = createMapCircle();
        mapScene.addMapPolygon(mapCircle);
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
            // Thrown when less than two vertices.
            return null;
        }

        float widthInPixels = 20;
        Color lineColor = new Color(0, (float) 0.56, (float) 0.54, (float) 0.63);
        MapPolyline mapPolyline = null;
        try {
            mapPolyline = new MapPolyline(geoPolyline, new MapPolyline.SolidRepresentation(
                    new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                    lineColor,
                    LineCap.ROUND));
        } catch (MapPolyline.Representation.InstantiationException e) {
            Log.e("MapPolyline Representation Exception:", e.error.name());
        } catch (MapMeasureDependentRenderSize.InstantiationException e) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name());
        }

        return mapPolyline;
    }

    private MapArrow createMapArrow() {
        ArrayList<GeoCoordinates> coordinates = new ArrayList<>();
        coordinates.add(new GeoCoordinates(52.53032, 13.37409));
        coordinates.add(new GeoCoordinates(52.5309, 13.3946));
        coordinates.add(new GeoCoordinates(52.53894, 13.39194));
        coordinates.add(new GeoCoordinates(52.54014, 13.37958));

        GeoPolyline geoPolyline;
        try {
            geoPolyline = new GeoPolyline(coordinates);
        } catch (InstantiationErrorException e) {
            // Thrown when less than two vertices.
            return null;
        }

        float widthInPixels = 20;
        Color lineColor = Color.valueOf(0, 0.56f, 0.54f, 0.63f); // RGBA
        MapArrow mapArrow = new MapArrow(geoPolyline, widthInPixels, lineColor);

        return mapArrow;
    }

    private MapPolygon createPolygon() {
        ArrayList<GeoCoordinates> coordinates = new ArrayList<>();
        // Note that a polygon requires a clockwise or counter-clockwise order of the coordinates.
        coordinates.add(new GeoCoordinates(52.54014, 13.37958));
        coordinates.add(new GeoCoordinates(52.53894, 13.39194));
        coordinates.add(new GeoCoordinates(52.5309, 13.3946));
        coordinates.add(new GeoCoordinates(52.53032, 13.37409));

        GeoPolygon geoPolygon;
        try {
            geoPolygon = new GeoPolygon(coordinates);
        } catch (InstantiationErrorException e) {
            // Less than three vertices.
            return null;
        }

        Color fillColor = Color.valueOf(0, 0.56f, 0.54f, 0.63f); // RGBA
        MapPolygon mapPolygon = new MapPolygon(geoPolygon, fillColor);

        return mapPolygon;
    }

    private MapPolygon createMapCircle() {
        float radiusInMeters = 300;
        GeoCircle geoCircle = new GeoCircle(new GeoCoordinates(52.51760485151816, 13.380312380535472), radiusInMeters);

        GeoPolygon geoPolygon = new GeoPolygon(geoCircle);
        Color fillColor = Color.valueOf(0, 0.56f, 0.54f, 0.63f); // RGBA
        MapPolygon mapPolygon = new MapPolygon(geoPolygon, fillColor);

        return mapPolygon;
    }

    private void clearMap() {
        if (mapPolyline != null) {
            mapScene.removeMapPolyline(mapPolyline);
        }

        if (mapArrow != null) {
            mapScene.removeMapArrow(mapArrow);
        }

        if (mapPolygon != null) {
            mapScene.removeMapPolygon(mapPolygon);
        }

        if (mapCircle != null) {
            mapScene.removeMapPolygon(mapCircle);
        }
    }

    private void flyTo(GeoCoordinates geoCoordinates) {
        GeoCoordinatesUpdate geoCoordinatesUpdate = new GeoCoordinatesUpdate(geoCoordinates);
        double distanceInMeters = 1000 * 8;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
        double bowFactor = 1;
        MapCameraAnimation animation = MapCameraAnimationFactory.flyTo(
                geoCoordinatesUpdate, mapMeasureZoom, bowFactor, Duration.ofSeconds(3));
        mapCamera.startAnimation(animation);
    }
}
