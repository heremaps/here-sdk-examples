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

package com.here.camerakeyframetracks;

import android.util.Log;

import androidx.annotation.Nullable;

import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapView;
import com.here.sdk.routing.CarOptions;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.Waypoint;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

// A class that creates a route.
public class RouteCalculator {

    private final MapView mapView;
    private final RoutingEngine routingEngine;

    @Nullable
    public static Route testRoute;

    public RouteCalculator(MapView mapView) {
        this.mapView = mapView;

        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }
    }

    public void createRoute() {
        // A fixed test route.
        Waypoint startWaypoint = new Waypoint(new GeoCoordinates(40.7133, -74.0112));
        Waypoint destinationWaypoint = new Waypoint(new GeoCoordinates(40.7203, -74.3122));
        List<Waypoint> waypoints = new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint));
        routingEngine.calculateRoute(waypoints, new CarOptions(), (routingError, routes) -> {
            if (routingError == null) {
                testRoute = routes.get(0);
                showRouteOnMap(testRoute);
            } else {
                Log.e("RouteCalculator", "RoutingError: " + routingError.name());
            }
        });
    }

    private void showRouteOnMap(Route route) {
        // Show route as polyline.
        GeoPolyline routeGeoPolyline = route.getGeometry();
        float widthInPixels = 20;
        MapPolyline routeMapPolyline = new MapPolyline(routeGeoPolyline,
                widthInPixels,
                Color.valueOf(0, 0.56f, 0.54f, 0.63f)); // RGBA
        mapView.getMapScene().addMapPolyline(routeMapPolyline);
    }
}
