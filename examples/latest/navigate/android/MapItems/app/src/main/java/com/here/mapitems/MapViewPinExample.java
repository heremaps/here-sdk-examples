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

package com.here.mapitems;

import android.content.Context;
import android.graphics.Color;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.GeoCircle;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolygon;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapPolygon;
import com.here.sdk.mapview.MapView;

import java.util.ArrayList;
import java.util.List;

public class MapViewPinExample {

    private static final double DISTANCE_IN_METERS = 1000 * 10;
    private static final GeoCoordinates MAP_CENTER_GEO_COORDINATES = new GeoCoordinates(52.51760485151816, 13.380312380535472);

    private Context context;
    private final MapView mapView;
    private final MapCamera mapCamera;

    public MapViewPinExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        mapCamera = mapView.getCamera();
        double distanceToEarthInMeters = 7000;
        mapCamera.lookAt(MAP_CENTER_GEO_COORDINATES, distanceToEarthInMeters);

        // Add circle to indicate map center.
        addCirclePolygon(MAP_CENTER_GEO_COORDINATES);
    }

    public void showMapViewPin() {
        // Move map to expected location.
        mapCamera.flyTo(MAP_CENTER_GEO_COORDINATES, DISTANCE_IN_METERS, new MapCamera.FlyToOptions());

        TextView textView = new TextView(context);
        textView.setTextColor(Color.parseColor("#FFFFFF"));
        textView.setText("Centered ViewPin");

        LinearLayout linearLayout = new LinearLayout(context);
        linearLayout.setBackgroundResource(R.color.colorAccent);
        linearLayout.setPadding(10, 10, 10, 10);
        linearLayout.addView(textView);

        mapView.pinView(linearLayout, MAP_CENTER_GEO_COORDINATES);
    }

    public void showAnchoredMapViewPin() {
        // Move map to expected location.
        mapCamera.flyTo(MAP_CENTER_GEO_COORDINATES, DISTANCE_IN_METERS, new MapCamera.FlyToOptions());

        TextView textView = new TextView(context);
        textView.setTextColor(Color.parseColor("#FFFFFF"));
        textView.setText("Anchored MapViewPin");

        LinearLayout linearLayout = new LinearLayout(context);
        linearLayout.setBackgroundResource(R.color.colorPrimary);
        linearLayout.setPadding(10, 10, 10, 10);
        linearLayout.addView(textView);

        MapView.ViewPin viewPin = mapView.pinView(linearLayout, MAP_CENTER_GEO_COORDINATES);
        viewPin.setAnchorPoint(new Anchor2D(0.5F, 1));
    }

    public void clearMap() {
        List<MapView.ViewPin> mapViewPins = mapView.getViewPins();
        for (MapView.ViewPin viewPin : new ArrayList<>(mapViewPins)) {
            viewPin.unpin();
        }
    }

    private void addCirclePolygon(GeoCoordinates geoCoordinates) {
        // Move map to expected location.
        mapCamera.flyTo(MAP_CENTER_GEO_COORDINATES, DISTANCE_IN_METERS, new MapCamera.FlyToOptions());

        float radiusInMeters = 50;
        GeoCircle geoCircle = new GeoCircle(geoCoordinates, radiusInMeters);

        GeoPolygon geoPolygon = new GeoPolygon(geoCircle);
          com.here.sdk.core.Color fillColor =
                com.here.sdk.core.Color.valueOf(0, 0.56f, 0.54f, 0.63f); // RGBA
        MapPolygon mapPolygon = new MapPolygon(geoPolygon, fillColor);

        mapView.getMapScene().addMapPolygon(mapPolygon);
    }
}
