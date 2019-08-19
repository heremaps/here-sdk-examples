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

package com.here.mapmarker;

import android.content.Context;
import android.support.annotation.Nullable;
import android.support.v7.app.AlertDialog;
import android.widget.Toast;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.GeoBoundingRect;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Metadata;
import com.here.sdk.core.Point2D;
import com.here.sdk.mapview.Camera;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMarkerImageStyle;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.PickMapItemsCallback;
import com.here.sdk.mapview.PickMapItemsResult;
import com.here.sdk.mapview.gestures.TapListener;

import java.util.ArrayList;
import java.util.List;

public class MapMarkerExample {

    private Context context;
    private MapView mapView;
    private final List<MapMarker> mapMarkerList = new ArrayList<>();

    public void onMapSceneLoaded(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        Camera camera = mapView.getCamera();
        camera.setTarget(new GeoCoordinates(52.520798, 13.409408));
        camera.setZoomLevel(15);

        // Setting a tap handler to pick markers from map
        setTapGestureHandler();

        Toast.makeText(context,"You can tap markers.", Toast.LENGTH_LONG).show();
    }

    public void showAnchoredMapMarkers() {
        for (int i = 0; i < 10; i++) {
            GeoCoordinates geoCoordinates = createRandomLatLonInViewport();

            // Centered on location. Shown below the POI image to indicate the location.
            addCircleMapMarker(geoCoordinates);

            // Anchored, pointing to location.
            addPOIMapMarker(geoCoordinates);
        }
    }

    public void showCenteredMapMarkers() {
        GeoCoordinates geoCoordinates = createRandomLatLonInViewport();

        // Centered on location.
        addPhotoMapMarker(geoCoordinates);

        // Centered on location. Shown on top of the previous image to indicate the location.
        addCircleMapMarker(geoCoordinates);
    }

    public void clearMap() {
        for (MapMarker mapMarker : mapMarkerList) {
            mapView.getMapScene().removeMapMarker(mapMarker);
        }
        mapMarkerList.clear();
    }

    private GeoCoordinates createRandomLatLonInViewport() {
        GeoBoundingRect geoBoundingRect = mapView.getCamera().getBoundingRect();
        GeoCoordinates northEast = geoBoundingRect.northEastCorner;
        GeoCoordinates southWest = geoBoundingRect.southWestCorner;

        double minLat = southWest.latitude;
        double maxLat = northEast.latitude;
        double lat = getRandom(minLat, maxLat);

        double minLon = southWest.longitude;
        double maxLon = northEast.longitude;
        double lon = getRandom(minLon, maxLon);

        return new GeoCoordinates(lat, lon);
    }

    private double getRandom(double min, double max) {
        return min + Math.random() * (max - min);
    }

    private void setTapGestureHandler() {
        mapView.getGestures().setTapListener(new TapListener() {
            @Override
            public void onTap(Point2D origin) {
                pickMapMarker(origin);
            }
        });
    }

    private void pickMapMarker(final Point2D origin) {
        float radiusInPixel = 2;
        mapView.pickMapItems(origin, radiusInPixel, new PickMapItemsCallback() {
            @Override
            public void onMapItemsPicked(@Nullable PickMapItemsResult pickMapItemsResult) {
                if (pickMapItemsResult == null) {
                    return;
                }

                MapMarker topmostMapMarker = pickMapItemsResult.getTopmostMarker();
                if (topmostMapMarker == null) {
                    return;
                }

                Metadata metadata = topmostMapMarker.getMetadata();
                if (metadata != null) {
                    String message = "No message found.";
                    String string = metadata.getString("key_poi");
                    if (string != null) {
                        message = string;
                    }
                    showDialog("Map Marker picked", message);
                    return;
                }

                showDialog("Map marker picked:", "Location: " +
                        topmostMapMarker.getCoordinates().latitude + ", " +
                        topmostMapMarker.getCoordinates().longitude);
            }
        });
    }

    private void addPOIMapMarker(GeoCoordinates geoCoordinates) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.poi);

        MapMarker mapMarker = new MapMarker(geoCoordinates);

        // The bottom, middle position should point to the location.
        // By default, the anchor point is set to 0.5, 0.5.
        MapMarkerImageStyle mapMarkerImageStyle = new MapMarkerImageStyle();
        mapMarkerImageStyle.setAnchorPoint(new Anchor2D(0.5F, 1));

        mapMarker.addImage(mapImage, mapMarkerImageStyle);

        Metadata metadata = new Metadata();
        metadata.setString("key_poi", "This is a POI.");
        mapMarker.setMetadata(metadata);

        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    private void addPhotoMapMarker(GeoCoordinates geoCoordinates) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.here_car);

        MapMarker mapMarker = new MapMarker(geoCoordinates);
        mapMarker.addImage(mapImage, new MapMarkerImageStyle());

        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    private void addCircleMapMarker(GeoCoordinates geoCoordinates) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.circle);

        MapMarker mapMarker = new MapMarker(geoCoordinates);
        mapMarker.addImage(mapImage, new MapMarkerImageStyle());

        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }
}
