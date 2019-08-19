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

package com.here.sdk.mapoverlays;

import android.content.Context;
import android.graphics.Color;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.mapview.Camera;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMarkerImageStyle;
import com.here.sdk.mapview.MapOverlay;
import com.here.sdk.mapview.MapView;

import java.util.ArrayList;
import java.util.List;

public class MapOverlayExample {

    private Context context;
    private MapView mapView;
    private GeoCoordinates mapCenterGeoCoordinates = new GeoCoordinates(52.520798, 13.409408);

    public void onMapSceneLoaded(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        Camera camera = mapView.getCamera();
        camera.setZoomLevel(15);

        camera.setTarget(mapCenterGeoCoordinates);
        addCircleMapMarker(mapCenterGeoCoordinates);
    }

    public void showMapOverlay() {
        TextView textView = new TextView(context);
        textView.setTextColor(Color.parseColor("#FFFFFF"));
        textView.setText("Centered MapOverlay");

        LinearLayout linearLayout = new LinearLayout(context);
        linearLayout.setBackgroundResource(R.color.colorAccent);
        linearLayout.setPadding(10, 10, 10, 10);
        linearLayout.addView(textView);

        MapOverlay<LinearLayout> mapOverlay = new MapOverlay<>(linearLayout, mapCenterGeoCoordinates);
        mapView.addMapOverlay(mapOverlay);
    }

    public void showAnchoredMapOverlay() {
        TextView textView = new TextView(context);
        textView.setTextColor(Color.parseColor("#FFFFFF"));
        textView.setText("Anchored MapOverlay");

        LinearLayout linearLayout = new LinearLayout(context);
        linearLayout.setBackgroundResource(R.color.colorPrimary);
        linearLayout.setPadding(10, 10, 10, 10);
        linearLayout.addView(textView);

        MapOverlay<LinearLayout> mapOverlay = new MapOverlay<>(linearLayout, mapCenterGeoCoordinates);
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
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.red_dot);
        MapMarker mapMarker = new MapMarker(geoCoordinates);
        mapMarker.addImage(mapImage, new MapMarkerImageStyle());
        mapView.getMapScene().addMapMarker(mapMarker);
    }
}
