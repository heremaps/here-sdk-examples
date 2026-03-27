/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

package com.here.camerakeyframetrackskotlin

import android.util.Log
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.LineCap
import com.here.sdk.mapview.MapMeasureDependentRenderSize
import com.here.sdk.mapview.MapPolyline
import com.here.sdk.mapview.MapPolyline.SolidRepresentation
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.RenderSize
import com.here.sdk.routing.CalculateRouteCallback
import com.here.sdk.routing.RoutingOptions
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingEngine
import com.here.sdk.routing.RoutingError
import com.here.sdk.routing.Waypoint

class RouteCalculator(private val mapView: MapView) {
    private var routingEngine: RoutingEngine

    init {
        try {
            routingEngine = RoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of RoutingEngine failed: ${e.error.name}")
        }
    }

    fun createRoute() {
        // A fixed test route.
        val startWaypoint = Waypoint(GeoCoordinates(40.7133, -74.0112))
        val destinationWaypoint = Waypoint(GeoCoordinates(40.7203, -74.3122))
        val waypoints = listOf(startWaypoint, destinationWaypoint)

        routingEngine.calculateRoute(
            waypoints,
            RoutingOptions(),
            CalculateRouteCallback { routingError: RoutingError?, routes: List<Route>? ->
                if (routingError == null) {
                    routes?.let {
                        showRouteOnMap(routes[0])
                    }
                } else {
                    Log.e("RouteCalculator", "RoutingError: ${routingError.name}")
                }
            })
    }

    private fun showRouteOnMap(route: Route) {
        // Show route as polyline.
        val routeGeoPolyline = route.geometry
        val widthInPixels = 20f
        val polylineColor = Color.valueOf(0f, 0.56f, 0.54f, 0.63f)
        var routeMapPolyline: MapPolyline? = null
        try {
            routeMapPolyline = MapPolyline(
                routeGeoPolyline, SolidRepresentation(
                    MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels.toDouble()),
                    polylineColor,
                    LineCap.ROUND
                )
            )
        } catch (e: MapPolyline.Representation.InstantiationException) {
            Log.e("MapPolyline Representation Exception:", e.error.name)
        } catch (e: MapMeasureDependentRenderSize.InstantiationException) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name)
        }
        val routeMapPolylineNonNull = routeMapPolyline ?: return logError("mapView is null. Cannot load map scene.")
        mapView.mapScene.addMapPolyline(routeMapPolylineNonNull)
    }

    private fun logError(error: String) {
        Log.e(TAG, error)
    }

    companion object {
        var testRoute: Route? = null
        private val TAG = MainActivity::class.java.simpleName
    }
}