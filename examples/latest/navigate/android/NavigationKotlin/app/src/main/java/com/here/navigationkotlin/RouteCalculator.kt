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

package com.here.navigationkotlin

import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.routing.CalculateRouteCallback
import com.here.sdk.routing.CarOptions
import com.here.sdk.routing.RoutingEngine
import com.here.sdk.routing.Waypoint

// A class that creates car Routes with the HERE SDK.
class RouteCalculator {
    private var routingEngine: RoutingEngine? = null

    init {
        try {
            routingEngine = RoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of RoutingEngine failed: " + e.error.name)
        }
    }

    fun calculateRoute(
        startWaypoint: Waypoint,
        destinationWaypoint: Waypoint,
        calculateRouteCallback: CalculateRouteCallback?
    ) {
        val waypoints: List<Waypoint> = listOf(startWaypoint, destinationWaypoint)

        // A route handle is required for the DynamicRoutingEngine to get updates on traffic-optimized routes.
        val routingOptions = CarOptions()
        routingOptions.routeOptions.enableRouteHandle = true

        routingEngine!!.calculateRoute(
            waypoints,
            routingOptions,
            calculateRouteCallback!!
        )
    }
}