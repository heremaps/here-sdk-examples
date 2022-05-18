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

package com.here.traffic;

import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;

import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCircle;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Rectangle2D;
import com.here.sdk.core.Size2D;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.MapViewBase;
import com.here.sdk.mapview.PickMapContentResult;
import com.here.sdk.mapview.VisibilityState;
import com.here.sdk.traffic.TrafficEngine;
import com.here.sdk.traffic.TrafficIncident;
import com.here.sdk.traffic.TrafficIncidentLookupCallback;
import com.here.sdk.traffic.TrafficIncidentLookupOptions;
import com.here.sdk.traffic.TrafficIncidentsQueryCallback;
import com.here.sdk.traffic.TrafficIncidentsQueryOptions;
import com.here.sdk.traffic.TrafficQueryError;

import java.util.ArrayList;
import java.util.List;

public class TrafficExample {

    private static final String TAG = TrafficExample.class.getName();

    private final Context context;
    private final MapView mapView;
    private final TrafficEngine trafficEngine;
    // Visualizes traffic incidents found with the TrafficEngine.
    private final List<MapPolyline> mapPolylines = new ArrayList<>();

    public TrafficExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        MapCamera camera = mapView.getCamera();
        double distanceInMeters = 1000 * 10;
        camera.lookAt(new GeoCoordinates(52.520798, 13.409408), distanceInMeters);

        try {
            trafficEngine = new TrafficEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of TrafficEngine failed: " + e.error.name());
        }

        // Setting a tap handler to pick and search for traffic incidents around the tapped area.
        setTapGestureHandler();

        showDialog("Note",
                "Tap on the map to pick a traffic incident.");
    }

    public void enableAll() {
        // Show real-time traffic lines and incidents on the map.
        enableTrafficVisualization();
    }

    public void disableAll() {
        disableTrafficVisualization();
    }

    private void enableTrafficVisualization() {
        // Once these layers are added to the map, they will be automatically updated while panning the map.
        mapView.getMapScene().setLayerVisibility(MapScene.Layers.TRAFFIC_FLOW, VisibilityState.VISIBLE);
        // MapScene.Layers.TRAFFIC_INCIDENTS renders traffic icons and lines to indicate the location of incidents. Note that these are not directly pickable yet.
        mapView.getMapScene().setLayerVisibility(MapScene.Layers.TRAFFIC_INCIDENTS, VisibilityState.VISIBLE);
    }

    private void disableTrafficVisualization() {
        mapView.getMapScene().setLayerVisibility(MapScene.Layers.TRAFFIC_FLOW, VisibilityState.HIDDEN);
        mapView.getMapScene().setLayerVisibility(MapScene.Layers.TRAFFIC_INCIDENTS, VisibilityState.HIDDEN);

        // This clears only the custom visualization for incidents found with the TrafficEngine.
        clearTrafficIncidentsMapPolylines();
    }

    private void setTapGestureHandler() {
        mapView.getGestures().setTapListener(touchPoint -> {
            GeoCoordinates touchGeoCoords = mapView.viewToGeoCoordinates(touchPoint);
            // Can be null when the map was tilted and the sky was tapped.
            if (touchGeoCoords != null) {
                // Pick incidents that are shown in MapScene.Layers.TRAFFIC_INCIDENTS.
                pickTrafficIncident(touchPoint);

                // Query for incidents independent of MapScene.Layers.TRAFFIC_INCIDENTS.
                queryForIncidents(touchGeoCoords);
            }
        });
    }

    // Traffic incidents can only be picked, when MapScene.Layers.TRAFFIC_INCIDENTS is visible.
    private void pickTrafficIncident(Point2D touchPointInPixels) {
        // Center the rectangle on the touch location.
        Point2D originInPixels = new Point2D(touchPointInPixels.x - 50/2, touchPointInPixels.y - 50/2);
        Size2D sizeInPixels = new Size2D(50, 50);
        Rectangle2D rectangle = new Rectangle2D(originInPixels, sizeInPixels);

        mapView.pickMapContent(rectangle, new MapViewBase.PickMapContentCallback() {
            @Override
            public void onPickMapContent(@Nullable PickMapContentResult pickMapContentResult) {
                if (pickMapContentResult == null) {
                    // An error occurred while performing the pick operation.
                    return;
                }

                List<PickMapContentResult.TrafficIncidentResult> trafficIncidents =
                        pickMapContentResult.getTrafficIncidents();
                if (trafficIncidents.size() == 0) {
                    Log.d(TAG, "No traffic incident found at picked location");
                } else {
                    Log.d(TAG, "Picked at least one incident.");
                    PickMapContentResult.TrafficIncidentResult firstIncident = trafficIncidents.get(0);
                    showDialog("Traffic incident picked:", "Type: " +
                            firstIncident.getType().name());

                    // Find more details by looking up the ID via TrafficEngine.
                    findIncidentByID(firstIncident.getOriginalId());
                }

                // Optionally, look for more map content like embedded POIs.
            }
        });
    }

    private void findIncidentByID(long originalId) {
        TrafficIncidentLookupOptions trafficIncidentsQueryOptions = new TrafficIncidentLookupOptions();
        // Optionally, specify a language:
        // the language of the country where the incident occurs is used.
        // trafficIncidentsQueryOptions.languageCode = LanguageCode.EN_US;
        trafficEngine.lookupIncident(String.valueOf(originalId), trafficIncidentsQueryOptions, new TrafficIncidentLookupCallback() {
            @Override
            public void onTrafficIncidentFetched(@Nullable TrafficQueryError trafficQueryError, @Nullable TrafficIncident trafficIncident) {
                if (trafficQueryError == null) {
                    Log.d(TAG, "Fetched TrafficIncident from lookup request." +
                            " Description: " + trafficIncident.getDescription().text);
                    addTrafficIncidentsMapPolyline(trafficIncident.getLocation().polyline);
                } else {
                    showDialog("TrafficLookupError:", trafficQueryError.toString());
                }
            }
        });
    }

    private void addTrafficIncidentsMapPolyline(GeoPolyline geoPolyline) {
        // Show traffic incident as polyline.
        float widthInPixels = 20;
        MapPolyline routeMapPolyline = new MapPolyline(geoPolyline,
                widthInPixels,
                Color.valueOf(0, 0, 0, 0.5f)); // RGBA

        mapView.getMapScene().addMapPolyline(routeMapPolyline);
        mapPolylines.add(routeMapPolyline);
    }

    private void queryForIncidents(GeoCoordinates centerCoords) {
        int radiusInMeters = 1000;
        GeoCircle geoCircle = new GeoCircle(centerCoords, radiusInMeters);
        TrafficIncidentsQueryOptions trafficIncidentsQueryOptions = new TrafficIncidentsQueryOptions();
        // Optionally, specify a language:
        // the language of the country where the incident occurs is used.
        // trafficIncidentsQueryOptions.languageCode = LanguageCode.EN_US;
        trafficEngine.queryForIncidents(geoCircle, trafficIncidentsQueryOptions, new TrafficIncidentsQueryCallback() {
            @Override
            public void onTrafficIncidentsFetched(@Nullable TrafficQueryError trafficQueryError,
                                                  @Nullable List<TrafficIncident> trafficIncidentsList) {
                if (trafficQueryError == null) {
                    // If error is null, it is guaranteed that the list will not be null.
                    String trafficMessage = "Found " + trafficIncidentsList.size() + " result(s).";
                    TrafficIncident nearestIncident =
                            getNearestTrafficIncident(centerCoords, trafficIncidentsList);
                    if (nearestIncident != null) {
                        trafficMessage += " Nearest incident: " + nearestIncident.getDescription().text;
                    }
                    Log.d(TAG, "Nearby traffic incidents: " + trafficMessage);
                    for (TrafficIncident trafficIncident : trafficIncidentsList) {
                        Log.d(TAG, "" + trafficIncident.getDescription().text);
                    }
                } else {
                    Log.d(TAG, "TrafficQueryError: " + trafficQueryError.toString());
                }
            }
        });
    }

    @Nullable
    private TrafficIncident getNearestTrafficIncident(GeoCoordinates currentGeoCoords,
                                                      List<TrafficIncident> trafficIncidentsList) {
        if (trafficIncidentsList.size() == 0) {
            return null;
        }

        // By default, traffic incidents results are not sorted by distance.
        double nearestDistance = Double.MAX_VALUE;
        TrafficIncident nearestTrafficIncident = null;
        for (TrafficIncident trafficIncident : trafficIncidentsList) {
            // In case lengthInMeters == 0 then the polyline consistes of two equal coordinates.
            // It is guaranteed that each incident has a valid polyline.
            for (GeoCoordinates geoCoords : trafficIncident.getLocation().polyline.vertices) {
                double currentDistance = currentGeoCoords.distanceTo(geoCoords);
                if (currentDistance < nearestDistance) {
                    nearestDistance = currentDistance;
                    nearestTrafficIncident = trafficIncident;
                }
            }
        }

        return nearestTrafficIncident;
    }

    private void clearTrafficIncidentsMapPolylines() {
        for (MapPolyline mapPolyline : mapPolylines) {
            mapView.getMapScene().removeMapPolyline(mapPolyline);
        }
        mapPolylines.clear();
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }
}
