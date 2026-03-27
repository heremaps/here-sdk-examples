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
import com.here.sdk.animation.Easing
import com.here.sdk.animation.EasingFunction
import com.here.sdk.core.GeoOrientationUpdate
import com.here.sdk.core.Point2D
import com.here.sdk.core.Rectangle2D
import com.here.sdk.core.Size2D
import com.here.sdk.mapview.MapCameraAnimationFactory
import com.here.sdk.mapview.MapCameraUpdateFactory
import com.here.sdk.mapview.MapView
import com.here.sdk.routing.Route
import com.here.time.Duration

class RouteAnimationExample(private val mapView: MapView) {
    // Creates a fixed route for testing purposes.
    private val routeCalculator: RouteCalculator = RouteCalculator(mapView)

    init {
        routeCalculator.createRoute()
    }

    fun stopRouteAnimation() {
        mapView.camera.cancelAnimations()
    }

    fun animateToRoute() {
        var testRoute: Route? = RouteCalculator.testRoute

        val testRouteNonNull = testRoute ?: return logError("TestRoute is null. Cannot start route animation.")
        animateToRoute(testRouteNonNull)
    }

    private fun animateToRoute(route: Route) {
        // The animation should result in an untilted and unrotated map.
        val bearing = 0.0
        val tilt = 0.0
        // We want to show the route fitting in the map view with an additional padding of 50 pixels
        val origin = Point2D(50.0, 50.0)
        val sizeInPixels =
            Size2D((mapView.width - 100).toDouble(), (mapView.height - 100).toDouble())
        val mapViewport = Rectangle2D(origin, sizeInPixels)

        // Animate to the route within a duration of 3 seconds.
        val update = MapCameraUpdateFactory.lookAt(
            route.boundingBox,
            GeoOrientationUpdate(bearing, tilt),
            mapViewport
        )
        val animation =
            MapCameraAnimationFactory.createAnimation(
                update,
                Duration.ofMillis(3000),
                Easing(EasingFunction.IN_CUBIC)
            )
        mapView.camera.startAnimation(animation)
    }

    private fun logError(error: String) {
        Log.e(TAG, error)
    }

    companion object {
        private val TAG: String = MainActivity::class.java.simpleName
    }
}