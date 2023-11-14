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

import android.content.Context;
import android.graphics.Color;
import android.util.Log;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoCoordinatesUpdate;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapView;
import com.here.time.Duration;

import java.util.ArrayList;
import java.util.List;

public class MapViewPinExample {
    private static final String TAG = MapViewPinExample.class.getSimpleName();
    private static final GeoCoordinates MAP_CENTER_GEO_COORDINATES = new GeoCoordinates(52.51760485151816, 13.380312380535472);

    private final Context context;
    private final MapView mapView;
    private final MapCamera mapCamera;

    public MapViewPinExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        mapCamera = mapView.getCamera();
        double distanceToEarthInMeters = 7000;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceToEarthInMeters);
        mapCamera.lookAt(MAP_CENTER_GEO_COORDINATES, mapMeasureZoom);

        // Add circle to indicate map center.
        addCircle(MAP_CENTER_GEO_COORDINATES);
    }

    public void showMapViewPin() {
        // Move map to expected location.
        flyTo(MAP_CENTER_GEO_COORDINATES);

        TextView textView = new TextView(context);
        textView.setTextColor(Color.parseColor("#FFFFFF"));
        textView.setText("Centered ViewPin");

        LinearLayout linearLayout = new LinearLayout(context);
        linearLayout.setBackgroundResource(R.color.colorAccent);
        linearLayout.setPadding(10, 10, 10, 10);
        linearLayout.addView(textView);
        linearLayout.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Log.i(TAG, "Tapped on MapViewPin");
            }
        });

        mapView.pinView(linearLayout, MAP_CENTER_GEO_COORDINATES);
    }

    public void showAnchoredMapViewPin() {
        // Move map to expected location.
        flyTo(MAP_CENTER_GEO_COORDINATES);

        TextView textView = new TextView(context);
        textView.setTextColor(Color.parseColor("#FFFFFF"));
        textView.setText("Anchored MapViewPin");

        LinearLayout linearLayout = new LinearLayout(context);
        linearLayout.setBackgroundResource(R.color.colorPrimary);
        linearLayout.setPadding(10, 10, 10, 10);
        linearLayout.addView(textView);
        linearLayout.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Log.i(TAG, "Tapped on Anchored MapViewPin");
            }
        });

        MapView.ViewPin viewPin = mapView.pinView(linearLayout, MAP_CENTER_GEO_COORDINATES);
        viewPin.setAnchorPoint(new Anchor2D(0.5F, 1));
    }

    public void clearMap() {
        List<MapView.ViewPin> mapViewPins = mapView.getViewPins();
        for (MapView.ViewPin viewPin : new ArrayList<>(mapViewPins)) {
            viewPin.unpin();
        }
    }

    private void addCircle(GeoCoordinates geoCoordinates) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.circle);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage);
        mapView.getMapScene().addMapMarker(mapMarker);
    }

    private void flyTo(GeoCoordinates geoCoordinates) {
        GeoCoordinatesUpdate geoCoordinatesUpdate = new GeoCoordinatesUpdate(geoCoordinates);
        double bowFactor = 1;
        MapCameraAnimation animation =
                MapCameraAnimationFactory.flyTo(geoCoordinatesUpdate, bowFactor, Duration.ofSeconds(3));
        mapCamera.startAnimation(animation);
    }
}
