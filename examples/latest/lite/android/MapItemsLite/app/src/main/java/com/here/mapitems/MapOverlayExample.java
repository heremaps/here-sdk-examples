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

package com.here.mapitems;

import android.content.Context;
import android.graphics.Color;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.GeoCircle;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.mapviewlite.Camera;
import com.here.sdk.mapviewlite.MapCircle;
import com.here.sdk.mapviewlite.MapCircleStyle;
import com.here.sdk.mapviewlite.MapImage;
import com.here.sdk.mapviewlite.MapImageFactory;
import com.here.sdk.mapviewlite.MapMarker;
import com.here.sdk.mapviewlite.MapMarkerImageStyle;
import com.here.sdk.mapviewlite.MapOverlay;
import com.here.sdk.mapviewlite.MapViewLite;
import com.here.sdk.mapviewlite.PixelFormat;

import java.util.ArrayList;
import java.util.List;

public class MapOverlayExample {

    private static final GeoCoordinates MAP_CENTER_GEO_COORDINATES = new GeoCoordinates(52.51760485151816, 13.380312380535472);

    private final Context context;
    private final MapViewLite mapView;
    private final Camera mapCamera;

    public MapOverlayExample(Context context, MapViewLite mapView) {
        this.context = context;
        this.mapView = mapView;
        mapCamera = mapView.getCamera();

        // A circle to indicate the center location where the view pins are added upon in this example.
        addCircleMapMarker(MAP_CENTER_GEO_COORDINATES);
    }

    public void showMapOverlay() {
        // Move map to expected location.
        mapCamera.setTarget(MAP_CENTER_GEO_COORDINATES);
        mapCamera.setZoomLevel(13.0);

        TextView textView = new TextView(context);
        textView.setTextColor(Color.parseColor("#FFFFFF"));
        textView.setText("Centered MapOverlay");

        LinearLayout linearLayout = new LinearLayout(context);
        linearLayout.setBackgroundResource(R.color.colorAccent);
        linearLayout.setPadding(10, 10, 10, 10);
        linearLayout.addView(textView);

        MapOverlay<LinearLayout> mapOverlay = new MapOverlay<>(linearLayout, MAP_CENTER_GEO_COORDINATES);
        mapView.addMapOverlay(mapOverlay);
    }

    public void showAnchoredMapOverlay() {
        // Move map to expected location.
        mapCamera.setTarget(MAP_CENTER_GEO_COORDINATES);
        mapCamera.setZoomLevel(13.0);

        TextView textView = new TextView(context);
        textView.setTextColor(Color.parseColor("#FFFFFF"));
        textView.setText("Anchored MapOverlay");

        LinearLayout linearLayout = new LinearLayout(context);
        linearLayout.setBackgroundResource(R.color.colorPrimary);
        linearLayout.setPadding(10, 10, 10, 10);
        linearLayout.addView(textView);

        MapOverlay<LinearLayout> mapOverlay = new MapOverlay<>(linearLayout, MAP_CENTER_GEO_COORDINATES);
        mapOverlay.setAnchorPoint(new Anchor2D(0.5F, 1));
        mapView.addMapOverlay(mapOverlay);
    }

    public void clearMap() {
        List<MapOverlay> mapOverlays = mapView.getMapOverlays();
        for (MapOverlay mapOverlay : new ArrayList<>(mapOverlays)) {
            mapView.removeMapOverlay(mapOverlay);
        }
    }

    private void addCircleMapMarker(GeoCoordinates geoCoordinates) {
        // Move map to expected location.
        mapCamera.setTarget(MAP_CENTER_GEO_COORDINATES);
        mapCamera.setZoomLevel(13.0);

        float radiusInMeters = 30;
        GeoCircle geoCircle = new GeoCircle(geoCoordinates, radiusInMeters);
        MapCircleStyle mapCircleStyle = new MapCircleStyle();
        mapCircleStyle.setFillColor(0xAA908AA0, PixelFormat.RGBA_8888);
        MapCircle mapCircle = new MapCircle(geoCircle, mapCircleStyle);
        mapView.getMapScene().addMapCircle(mapCircle);
    }
}
