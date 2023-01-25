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
import android.content.res.AssetManager;
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoOrientationUpdate;
import com.here.sdk.core.Location;
import com.here.sdk.core.Metadata;
import com.here.sdk.core.Point2D;
import com.here.sdk.gestures.TapListener;
import com.here.sdk.mapview.LocationIndicator;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMarker3D;
import com.here.sdk.mapview.MapMarker3DModel;
import com.here.sdk.mapview.MapMarkerCluster;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.MapViewBase;
import com.here.sdk.mapview.PickMapItemsResult;
import com.here.sdk.mapview.RenderSize;
import com.here.time.Duration;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

public class MapItemsExample {

    private final Context context;
    private final MapView mapView;
    private final List<MapMarker> mapMarkerList = new ArrayList<>();
    private final List<MapMarker3D> mapMarker3DList = new ArrayList<>();
    private final List<MapMarkerCluster> mapMarkerClusterList = new ArrayList<>();
    private final List<LocationIndicator> locationIndicatorList = new ArrayList<>();

    public MapItemsExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;

        // Setting a tap handler to pick markers from map.
        setTapGestureHandler();

        Toast.makeText(context, "You can tap 2D markers.", Toast.LENGTH_LONG).show();
    }

    public void showAnchoredMapMarkers() {
        unTiltMap();

        for (int i = 0; i < 10; i++) {
            GeoCoordinates geoCoordinates = createRandomGeoCoordinatesAroundMapCenter();

            // Centered on location. Shown below the POI image to indicate the location.
            // The draw order is determined from what is first added to the map.
            addCircleMapMarker(geoCoordinates);

            // Anchored, pointing to location.
            addPOIMapMarker(geoCoordinates);
        }
    }

    public void showCenteredMapMarkers() {
        unTiltMap();

        GeoCoordinates geoCoordinates = createRandomGeoCoordinatesAroundMapCenter();

        // Centered on location.
        addPhotoMapMarker(geoCoordinates);

        // Centered on location. Shown above the photo marker to indicate the location.
        // The draw order is determined from what is first added to the map.
        addCircleMapMarker(geoCoordinates);
    }

    public void showMapMarkerCluster() {
        MapImage clusterMapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.green_square);

        // Defines a text that indicates how many markers are included in the cluster.
        MapMarkerCluster.CounterStyle counterStyle = new MapMarkerCluster.CounterStyle();
        counterStyle.textColor = new Color(0, 0, 0, 1); // Black
        counterStyle.fontSize = 40;
        counterStyle.maxCountNumber = 9;
        counterStyle.aboveMaxText = "+9";

        MapMarkerCluster mapMarkerCluster = new MapMarkerCluster(
                new MapMarkerCluster.ImageStyle(clusterMapImage), counterStyle);
        mapView.getMapScene().addMapMarkerCluster(mapMarkerCluster);
        mapMarkerClusterList.add(mapMarkerCluster);

        for (int i = 0; i < 10; i++) {
            mapMarkerCluster.addMapMarker(createRandomMapMarkerInViewport("" + i));
        }
    }

    private MapMarker createRandomMapMarkerInViewport(String metaDataText) {
        GeoCoordinates geoCoordinates = createRandomGeoCoordinatesAroundMapCenter();
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.green_square);

        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage);

        Metadata metadata = new Metadata();
        metadata.setString("key_cluster", metaDataText);
        mapMarker.setMetadata(metadata);

        return mapMarker;
    }

    public void showLocationIndicatorPedestrian() {
        unTiltMap();

        GeoCoordinates geoCoordinates = createRandomGeoCoordinatesAroundMapCenter();

        // Centered on location.
        addLocationIndicator(geoCoordinates, LocationIndicator.IndicatorStyle.PEDESTRIAN);
    }

    public void showLocationIndicatorNavigation() {
        unTiltMap();

        GeoCoordinates geoCoordinates = createRandomGeoCoordinatesAroundMapCenter();

        // Centered on location.
        addLocationIndicator(geoCoordinates, LocationIndicator.IndicatorStyle.NAVIGATION);
    }

    public void show2DTexture() {
        // Tilt the map for a better 3D effect.
        tiltMap();

        GeoCoordinates geoCoordinates = createRandomGeoCoordinatesAroundMapCenter();

        // Adds a flat POI marker that rotates and tilts together with the map.
        add2DTexture(geoCoordinates);

        // A centered 2D map marker to indicate the exact location.
        // Note that 3D map markers are always drawn on top of 2D map markers.
        addCircleMapMarker(geoCoordinates);
    }

    public void showMapMarker3D() {
        // Tilt the map for a better 3D effect.
        tiltMap();

        GeoCoordinates geoCoordinates = createRandomGeoCoordinatesAroundMapCenter();

        // Adds a textured 3D model.
        // It's origin is centered on the location.
        addMapMarker3D(geoCoordinates);
    }

    public void showFlatMapMarker() {
        // Tilt the map for a better 3D effect.
        tiltMap();

        GeoCoordinates geoCoordinates = createRandomGeoCoordinatesAroundMapCenter();

        // It's origin is centered on the location.
        addFlatMarker(geoCoordinates);

        // A centered 2D map marker to indicate the exact location.
        addCircleMapMarker(geoCoordinates);
    }

    public void clearMap() {
        mapView.getMapScene().removeMapMarkers(mapMarkerList);
        mapMarkerList.clear();

        for (MapMarker3D mapMarker3D : mapMarker3DList) {
            mapView.getMapScene().removeMapMarker3d(mapMarker3D);
        }
        mapMarker3DList.clear();

        for (LocationIndicator locationIndicator : locationIndicatorList) {
            mapView.removeLifecycleListener(locationIndicator);
        }
        locationIndicatorList.clear();

        for (MapMarkerCluster mapMarkerCluster : mapMarkerClusterList) {
            mapView.getMapScene().removeMapMarkerCluster(mapMarkerCluster);
        }
        mapMarkerClusterList.clear();
    }

    private void addPOIMapMarker(GeoCoordinates geoCoordinates) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.poi);

        // The bottom, middle position should point to the location.
        // By default, the anchor point is set to 0.5, 0.5.
        Anchor2D anchor2D = new Anchor2D(0.5F, 1);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage, anchor2D);

        Metadata metadata = new Metadata();
        metadata.setString("key_poi", "This is a POI.");
        mapMarker.setMetadata(metadata);

        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    private void addPhotoMapMarker(GeoCoordinates geoCoordinates) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.here_car);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage);

        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    private void addCircleMapMarker(GeoCoordinates geoCoordinates) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.circle);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage);

        // Optionally, enable a fade in-out animation.
        mapMarker.setFadeDuration(Duration.ofSeconds(3));

        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkerList.add(mapMarker);
    }

    private void addLocationIndicator(GeoCoordinates geoCoordinates,
                                      LocationIndicator.IndicatorStyle indicatorStyle) {
        LocationIndicator locationIndicator = new LocationIndicator();
        locationIndicator.setLocationIndicatorStyle(indicatorStyle);

        // A LocationIndicator is intended to mark the user's current location,
        // including a bearing direction.
        Location location = new Location(geoCoordinates);
        location.time = new Date();
        location.bearingInDegrees = getRandom(0, 360);

        locationIndicator.updateLocation(location);

        // A LocationIndicator listens to the lifecycle of the map view,
        // therefore, for example, it will get destroyed when the map view gets destroyed.
        mapView.addLifecycleListener(locationIndicator);
        locationIndicatorList.add(locationIndicator);
    }

    // A location indicator can be switched to a gray state, for example, to indicate a weak GPS signal.
    public void toggleActiveStateForLocationIndicator() {
        for (LocationIndicator locationIndicator : locationIndicatorList) {
            boolean isActive = locationIndicator.isActive();
            // Toggle between active / inactive state.
            locationIndicator.setActive(!isActive);
        }
    }

    private void add2DTexture(GeoCoordinates geoCoordinates) {
        // Place the files in the "assets" directory.
        // Full path example: app/src/main/assets/plane.obj
        // Adjust file name and path as appropriate for your project.
        // Note: The bottom of the plane is centered on the origin.
        String geometryFile = "plane.obj";

        // The POI texture is a square, so we can easily wrap it onto the 2 x 2 plane model.
        String textureFile = "poi_texture.png";
        checkIfFileExistsInAssetsFolder(geometryFile);
        checkIfFileExistsInAssetsFolder(textureFile);

        MapMarker3DModel mapMarker3DModel = new MapMarker3DModel(geometryFile, textureFile);
        MapMarker3D mapMarker3D = new MapMarker3D(geoCoordinates, mapMarker3DModel);
        // Scale marker. Note that we used a normalized length of 2 units in 3D space.
        mapMarker3D.setScale(60);

        mapView.getMapScene().addMapMarker3d(mapMarker3D);
        mapMarker3DList.add(mapMarker3D);
    }

    private void addFlatMarker(GeoCoordinates geoCoordinates) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), R.drawable.poi);

        // The default scale factor of the map marker is 1.0. For a scale of 2, the map marker becomes 2x larger.
        // For a scale of 0.5, the map marker shrinks to half of its original size.
        double scaleFactor = 0.5;

        // With DENSITY_INDEPENDENT_PIXELS the map marker will have a constant size on the screen regardless if the map is zoomed in or out.
        MapMarker3D mapMarker3D = new MapMarker3D(geoCoordinates, mapImage, scaleFactor, RenderSize.Unit.DENSITY_INDEPENDENT_PIXELS);

        mapView.getMapScene().addMapMarker3d(mapMarker3D);
        mapMarker3DList.add(mapMarker3D);
    }

    private void addMapMarker3D(GeoCoordinates geoCoordinates) {
        // Place the files in the "assets" directory.
        // Full path example: app/src/main/assets/obstacle.obj
        // Adjust file name and path as appropriate for your project.
        String geometryFile = "obstacle.obj";
        String textureFile = "obstacle_texture.png";
        checkIfFileExistsInAssetsFolder(geometryFile);
        checkIfFileExistsInAssetsFolder(textureFile);

        // Without depth check, 3D models are rendered on top of everything. With depth check enabled,
        // it may be hidden by buildings. In addition:
        // If a 3D object has its center at the origin of its internal coordinate system, 
        // then parts of it may be rendered below the ground surface (altitude < 0).
        // Note that the HERE SDK map surface is flat, following a Mercator or Globe projection. 
        // Therefore, a 3D object becomes visible when the altitude of its location is 0 or higher.
        // By default, without setting a scale factor, 1 unit in 3D coordinate space equals 1 meter.
        double altitude = 18.0;
        GeoCoordinates geoCoordinatesWithAltitude = new GeoCoordinates(geoCoordinates.latitude, geoCoordinates.longitude, altitude);

        MapMarker3DModel mapMarker3DModel = new MapMarker3DModel(geometryFile, textureFile);
        MapMarker3D mapMarker3D = new MapMarker3D(geoCoordinatesWithAltitude, mapMarker3DModel);
        mapMarker3D.setScale(6);
        mapMarker3D.setDepthCheckEnabled(true);

        mapView.getMapScene().addMapMarker3d(mapMarker3D);
        mapMarker3DList.add(mapMarker3D);
    }

    private void checkIfFileExistsInAssetsFolder(String fileName) {
        AssetManager assetManager = context.getAssets();
        try {
            assetManager.open(fileName);
        } catch (IOException e) {
            Log.e("MapItemsExample", "Error: File not found!");
        }
    }

    private GeoCoordinates createRandomGeoCoordinatesAroundMapCenter() {
        GeoCoordinates centerGeoCoordinates = mapView.getCamera().getState().targetCoordinates;
        double lat = centerGeoCoordinates.latitude;
        double lon = centerGeoCoordinates.longitude;
        return new GeoCoordinates(getRandom(lat - 0.02, lat + 0.02),
                getRandom(lon - 0.02, lon + 0.02));
    }

    private double getRandom(double min, double max) {
        return min + Math.random() * (max - min);
    }

    private void setTapGestureHandler() {
        mapView.getGestures().setTapListener(new TapListener() {
            @Override
            public void onTap(@NonNull Point2D touchPoint) {
                pickMapMarker(touchPoint);
            }
        });
    }

    private void pickMapMarker(final Point2D touchPoint) {
        float radiusInPixel = 2;
        mapView.pickMapItems(touchPoint, radiusInPixel, new MapViewBase.PickMapItemsCallback() {
            @Override
            public void onPickMapItems(@Nullable PickMapItemsResult pickMapItemsResult) {
                if (pickMapItemsResult == null) {
                    // An error occurred while performing the pick operation.
                    return;
                }

                // Note that MapMarker items contained in a cluster are not part of pickMapItemsResult.getMarkers().
                handlePickedMapMarkerClusters(pickMapItemsResult);

                // Note that 3D map markers can't be picked yet. Only marker, polygon and polyline map items are pickable.
                List<MapMarker> mapMarkerList = pickMapItemsResult.getMarkers();
                int listSize = mapMarkerList.size();
                if (listSize == 0) {
                    return;
                }
                MapMarker topmostMapMarker = mapMarkerList.get(0);

                Metadata metadata = topmostMapMarker.getMetadata();
                if (metadata != null) {
                    String message = "No message found.";
                    String string = metadata.getString("key_poi");
                    if (string != null) {
                        message = string;
                    }

                    showDialog("Map marker picked", message);
                    return;
                }

                showDialog("Map marker picked:", "Location: " +
                        topmostMapMarker.getCoordinates().latitude + ", " +
                        topmostMapMarker.getCoordinates().longitude);
            }
        });
    }

    private void handlePickedMapMarkerClusters(PickMapItemsResult pickMapItemsResult) {
        List<MapMarkerCluster.Grouping> groupingList = pickMapItemsResult.getClusteredMarkers();
        if (groupingList.size() == 0) {
            return;
        }

        MapMarkerCluster.Grouping topmostGrouping = groupingList.get(0);
        int clusterSize = topmostGrouping.markers.size();
        if (clusterSize == 0) {
            // This cluster does not contain any MapMarker items.
            return;
        }
        if (clusterSize == 1) {
            showDialog("Map marker picked",
                    "This MapMarker belongs to a cluster. Metadata: " + getClusterMetadata(topmostGrouping.markers.get(0)));
        } else {
            String metadata = "";
            for (MapMarker mapMarker: topmostGrouping.markers) {
                metadata += getClusterMetadata(mapMarker);
                metadata += " ";
            }
            showDialog("Map marker cluster picked",
                    "Number of contained markers in this cluster: " + clusterSize + ". " +
                            "Contained Metadata: " + metadata + ". " +
                            "Total number of markers in this MapMarkerCluster: " + topmostGrouping.parent.getMarkers().size());
        }
    }

    private String getClusterMetadata(MapMarker mapMarker) {
        Metadata metadata = mapMarker.getMetadata();
        String message = "No metadata.";
        if (metadata != null) {
            String string = metadata.getString("key_cluster");
            if (string != null) {
                message = string;
            }
        }
        return message;
    }

    private void tiltMap() {
        double bearing = mapView.getCamera().getState().orientationAtTarget.bearing;
        double tilt =  60;
        mapView.getCamera().setOrientationAtTarget(new GeoOrientationUpdate(bearing, tilt));
    }

    private void unTiltMap() {
        double bearing = mapView.getCamera().getState().orientationAtTarget.bearing;
        double tilt =  0;
        mapView.getCamera().setOrientationAtTarget(new GeoOrientationUpdate(bearing, tilt));
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }
}
