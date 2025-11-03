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

package com.here.traffic;

import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;

import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoCorridor;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.LineCap;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapMeasureDependentRenderSize;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.RenderSize;
import com.here.sdk.routing.CarOptions;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.Waypoint;
import com.here.sdk.traffic.TrafficEngine;
import com.here.sdk.traffic.TrafficFlow;
import com.here.sdk.traffic.TrafficFlowQueryCallback;
import com.here.sdk.traffic.TrafficFlowQueryOptions;
import com.here.sdk.traffic.TrafficQueryError;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

// This example shows how to request and visualize realtime traffic flow information
// with the TrafficEngine along a route corridor.
// Note that the request time may differ from the refresh cycle for TRAFFIC_FLOWs.
// Note that this does not consider future traffic predictions that are available based on
// the traffic information of the route object based on the ETA and historical traffic patterns.
public class RoutingExample {

    private static final String TAG = RoutingExample.class.getName();

    private final Context context;
    private final MapView mapView;
    private final List<MapPolyline> mapPolylines = new ArrayList<>();
    private final RoutingEngine routingEngine;
    private final TrafficEngine trafficEngine;

    public RoutingExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;

        // Configure the map.
        MapCamera camera = mapView.getCamera();
        double distanceInMeters = 1000 * 10;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters);
        camera.lookAt(new GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }

        try {
            // The traffic engine can be used to request additional information about
            // the current traffic situation anywhere on the road network.
            trafficEngine = new TrafficEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of TrafficEngine failed: " + e.error.name());
        }
    }

    public void addRoute() {
        Waypoint startWaypoint = new Waypoint(createRandomGeoCoordinatesAroundMapCenter());
        Waypoint destinationWaypoint = new Waypoint(createRandomGeoCoordinatesAroundMapCenter());

        List<Waypoint> waypoints =
                new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint));

        routingEngine.calculateRoute(
                waypoints,
                new CarOptions(),
                (routingError, routes) -> {
                    if (routingError == null) {
                        Route route = routes.get(0);
                        showRouteOnMap(route);
                    } else {
                        showDialog("Error while calculating a route:", routingError.toString());
                    }
                });
    }

    private void showRouteOnMap(Route route) {
        // Optionally, clear any previous route.
        clearMap();

        // Show route as polyline.
        GeoPolyline routeGeoPolyline = route.getGeometry();
        float widthInPixels = 20;
        Color polylineColor = new Color(0, (float) 0.56, (float) 0.54, (float) 0.63);
        MapPolyline routeMapPolyline = null;

        try {
            routeMapPolyline = new MapPolyline(routeGeoPolyline, new MapPolyline.SolidRepresentation(
                    new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                    polylineColor,
                    LineCap.ROUND));
        } catch (MapPolyline.Representation.InstantiationException e) {
            Log.e("MapPolyline Representation Exception:", e.error.name());
        } catch (MapMeasureDependentRenderSize.InstantiationException e) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name());
        }

        mapView.getMapScene().addMapPolyline(routeMapPolyline);
        mapPolylines.add(routeMapPolyline);

        if (route.getLengthInMeters() / 1000 > 5000) {
            showDialog("Note", "Skipped showing traffic-on-route for longer routes.");
            return;
        }

        requestRealtimeTrafficOnRoute(route);
    }

    public void clearMap() {
        for (MapPolyline mapPolyline : mapPolylines) {
            mapView.getMapScene().removeMapPolyline(mapPolyline);
        }
        mapPolylines.clear();
    }

    // This code uses the TrafficEngine to request the current state of the traffic situation
    // along the specified route corridor. Note that this information might dynamically change while
    // traveling along a route and it might not relate with the given ETA for the route.
    // Whereas the traffic-flow map feature shows pre-rendered vector tiles to achieve a smooth
    // map performance, the TrafficEngine requests the same information only for a specified area.
    // Depending on the time of the request and other backend factors like rendering the traffic
    // vector tiles, there can be cases, where both results differ.
    // Note that the HERE SDK allows to specify how often to request updates for the traffic-flow
    // map feature. It is recommended to not show traffic-flow and traffic-on-route together as it
    // might lead to redundant information. Instead, consider to show the traffic-flow map feature
    // side-by-side with the route's polyline (not shown in the method below). See Routing app for an
    // example.
    private void requestRealtimeTrafficOnRoute(Route route) {
        // We are interested to see traffic also for side paths.
        int halfWidthInMeters = 500;

        GeoCorridor geoCorridor = new GeoCorridor(route.getGeometry().vertices, halfWidthInMeters);
        TrafficFlowQueryOptions trafficFlowQueryOptions = new TrafficFlowQueryOptions();
        trafficEngine.queryForFlow(geoCorridor, trafficFlowQueryOptions, new TrafficFlowQueryCallback() {
            @Override
            public void onTrafficFlowFetched(@Nullable TrafficQueryError trafficQueryError,
                                             @Nullable List<TrafficFlow> list) {
                if (trafficQueryError == null) {
                    for (TrafficFlow trafficFlow : list) {
                        Double confidence = trafficFlow.getConfidence();
                        if (confidence != null && confidence <= 0.5) {
                            // Exclude speed-limit data and include only real-time and historical
                            // flow information.
                            continue;
                        }

                        // Visualize all polylines unfiltered as we get them from the TrafficEngine.
                        GeoPolyline trafficGeoPolyline = trafficFlow.getLocation().polyline;
                        addTrafficPolylines(trafficFlow.getJamFactor(), trafficGeoPolyline);
                    }
                } else {
                    showDialog("Error while fetching traffic flow:", trafficQueryError.toString());
                }
            }
        });
    }

    private void addTrafficPolylines(double jamFactor, GeoPolyline geoPolyline) {
        Color lineColor = getTrafficColor(jamFactor);
        if (lineColor == null) {
            // We skip rendering low traffic.
            return;
        }
        float widthInPixels = 10;
        MapPolyline trafficSpanMapPolyline = null;
        try {
            trafficSpanMapPolyline = new MapPolyline(geoPolyline, new MapPolyline.SolidRepresentation(
                    new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                    lineColor,
                    LineCap.ROUND));
        }  catch (MapPolyline.Representation.InstantiationException e) {
            Log.e("MapPolyline Representation Exception:", e.error.name());
        } catch (MapMeasureDependentRenderSize.InstantiationException e) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name());
        }

        mapView.getMapScene().addMapPolyline(trafficSpanMapPolyline);
        mapPolylines.add(trafficSpanMapPolyline);
    }

    // Define a traffic color scheme based on the traffic jam factor.
    // 0 <= jamFactor < 4: No or light traffic.
    // 4 <= jamFactor < 8: Moderate or slow traffic.
    // 8 <= jamFactor < 10: Severe traffic.
    // jamFactor = 10: No traffic, ie. the road is blocked.
    // Returns null in case of no or light traffic.
    @Nullable
    private Color getTrafficColor(Double jamFactor) {
        if (jamFactor == null || jamFactor < 4) {
            return null;
        } else if (jamFactor >= 4 && jamFactor < 8) {
            return Color.valueOf(1, 1, 0, 0.63f); // Yellow
        } else if (jamFactor >= 8 && jamFactor < 10) {
            return Color.valueOf(1, 0, 0, 0.63f); // Red
        }
        return Color.valueOf(0, 0, 0, 0.63f); // Black
    }

    private GeoCoordinates createRandomGeoCoordinatesAroundMapCenter() {
        GeoCoordinates centerGeoCoordinates = mapView.viewToGeoCoordinates(
                new Point2D(mapView.getWidth() / 2, mapView.getHeight() / 2));
        if (centerGeoCoordinates == null) {
            // Should never happen for center coordinates.
            throw new RuntimeException("CenterGeoCoordinates are null");
        }
        double lat = centerGeoCoordinates.latitude;
        double lon = centerGeoCoordinates.longitude;
        return new GeoCoordinates(getRandom(lat - 0.02, lat + 0.02),
                getRandom(lon - 0.02, lon + 0.02));
    }

    private double getRandom(double min, double max) {
        return min + Math.random() * (max - min);
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }

    // Dispose the RoutingEngine instance to cancel any pending requests
    // and shut it down for proper resource cleanup.
    public void dispose() {
        routingEngine.dispose();
    }
}
