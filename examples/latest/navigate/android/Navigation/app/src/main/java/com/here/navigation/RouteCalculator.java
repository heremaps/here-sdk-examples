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

package com.here.navigation;

import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.routing.CalculateRouteCallback;
import com.here.sdk.routing.CalculateTrafficOnRouteCallback;
import com.here.sdk.routing.CarOptions;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.Waypoint;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

// A class that creates car Routes with the HERE SDK.
public class RouteCalculator {

    private final RoutingEngine routingEngine;

    public RouteCalculator() {
        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }
    }

    public void calculateRoute(Waypoint startWaypoint,
                               Waypoint destinationWaypoint,
                               CalculateRouteCallback calculateRouteCallback) {
        List<Waypoint> waypoints =
                new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint));

        // A route handle is required for the DynamicRoutingEngine to get updates on traffic-optimized routes.
        CarOptions routingOptions = new CarOptions();
        routingOptions.routeOptions.enableRouteHandle = true;

        routingEngine.calculateRoute(
                waypoints,
                routingOptions,
                calculateRouteCallback);
    }
}
