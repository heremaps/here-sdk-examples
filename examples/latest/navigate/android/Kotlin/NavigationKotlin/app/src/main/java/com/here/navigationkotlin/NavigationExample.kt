/*
 * Copyright (C) 2025 HERE Europe B.V.
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

import android.content.Context
import android.util.Log
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.Location
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.location.LocationAccuracy
import com.here.sdk.mapview.MapView
import com.here.sdk.navigation.DynamicCameraBehavior
import com.here.sdk.navigation.SpeedBasedCameraBehavior
import com.here.sdk.navigation.VisualNavigator
import com.here.sdk.prefetcher.RoutePrefetcher
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingError
import com.here.sdk.trafficawarenavigation.DynamicRoutingEngine
import com.here.sdk.trafficawarenavigation.DynamicRoutingEngine.StartException
import com.here.sdk.trafficawarenavigation.DynamicRoutingEngineOptions
import com.here.sdk.trafficawarenavigation.DynamicRoutingListener
import com.here.time.Duration

// Shows how to start and stop turn-by-turn navigation on a car route.
// By default, tracking mode is enabled. When navigation is stopped, tracking mode is enabled again.
// The preferred device language determines the language for voice notifications used for TTS.
// (Make sure to set language + region in device settings.)
class NavigationExample(
    context: Context?,
    mapView: MapView?,
    private val messageView: MessageViewUpdater
) {
    private var visualNavigator: VisualNavigator
    private val herePositioningProvider: HEREPositioningProvider
    private val herePositioningSimulator: HEREPositioningSimulator
    private var dynamicRoutingEngine: DynamicRoutingEngine? = null
    private val routePrefetcher: RoutePrefetcher
    private val navigationHandler: NavigationHandler

    init {
        // A class to receive real location events.
        herePositioningProvider = HEREPositioningProvider()
        // A class to receive simulated location events.
        herePositioningSimulator = HEREPositioningSimulator()
        // The RoutePrefetcher downloads map data in advance into the map cache.
        // This is not mandatory, but can help to improve the guidance experience.
        routePrefetcher = RoutePrefetcher(SDKNativeEngine.getSharedInstance()!!)

        try {
            // Without a route set, this starts tracking mode.
            visualNavigator = VisualNavigator()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of VisualNavigator failed: " + e.error.name)
        }

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator.startRendering(mapView!!)

        createDynamicRoutingEngine()

        // A class to handle various kinds of guidance events.
        navigationHandler = NavigationHandler(context, messageView)
        dynamicRoutingEngine?.let { navigationHandler.setupListeners(visualNavigator, it) }

        messageView.updateText("Initialization completed.")
    }

    fun startLocationProvider() {
        // Set navigator as listener to receive locations from HERE Positioning
        // and choose a suitable accuracy for the tbt navigation use case.
        herePositioningProvider.startLocating(visualNavigator, LocationAccuracy.NAVIGATION)
    }

    private fun prefetchMapData(currentGeoCoordinates: GeoCoordinates) {
        // Prefetches map data around the provided location with a radius of 2 km into the map cache.
        // For the best experience, prefetchAroundLocationWithRadius() should be called as early as possible.
        val radiusInMeters = 2000.0
        routePrefetcher.prefetchAroundLocationWithRadius(currentGeoCoordinates, radiusInMeters)
        // Prefetches map data within a corridor along the route that is currently set to the provided Navigator instance.
        // This happens continuously in discrete intervals.
        // If no route is set, no data will be prefetched.
        routePrefetcher.prefetchAroundRouteOnIntervals(visualNavigator)
    }

    // Use this engine to periodically search for better routes during guidance, ie. when the traffic
    // situation changes.
    //
    // Note: This code initiates periodic calls to the HERE Routing backend. Depending on your contract,
    // each call may be charged separately. It is the application's responsibility to decide how
    // often this code should be executed.
    private fun createDynamicRoutingEngine() {
        val dynamicRoutingOptions = DynamicRoutingEngineOptions()
        // Both, minTimeDifference and minTimeDifferencePercentage, will be checked:
        // When the poll interval is reached, the smaller difference will win.
        dynamicRoutingOptions.minTimeDifference = Duration.ofSeconds(1)
        dynamicRoutingOptions.minTimeDifferencePercentage = 0.1
        // Below, we use 10 minutes. A common range is between 5 and 15 minutes.
        dynamicRoutingOptions.pollInterval = Duration.ofMinutes(10)

        try {
            // With the dynamic routing engine you can poll the HERE backend services to search for routes with less traffic.
            // This can happen during guidance - or you can periodically update a route that is shown in a route planner.
            //
            // Make sure to call dynamicRoutingEngine.updateCurrentLocation(...) to trigger execution. If this is not called,
            // no events will be delivered even if the next poll interval has been reached.
            dynamicRoutingEngine = DynamicRoutingEngine(dynamicRoutingOptions)
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of DynamicRoutingEngine failed: " + e.error.name)
        }
    }

    fun startNavigation(route: Route, isSimulated: Boolean, isCameraTrackingEnabled: Boolean) {
        val startGeoCoordinates = route.geometry.vertices[0]
        prefetchMapData(startGeoCoordinates)

        // Switches to navigation mode when no route was set before, otherwise navigation mode is kept.
        visualNavigator.route = route

        // Enable auto-zoom during guidance.
        visualNavigator.cameraBehavior = DynamicCameraBehavior()

        if (isSimulated) {
            enableRoutePlayback(route)
            messageView.updateText("Starting simulated navgation.")
        } else {
            enableDevicePositioning()
            messageView.updateText("Starting navgation.")
        }

        startDynamicSearchForBetterRoutes(route)

        // Synchronize with the toggle button state.
        updateCameraTracking(isCameraTrackingEnabled)
    }

    private fun startDynamicSearchForBetterRoutes(route: Route) {
        try {
            // Note that the engine will be internally stopped, if it was started before.
            // Therefore, it is not necessary to stop the engine before starting it again.
            dynamicRoutingEngine!!.start(route, object : DynamicRoutingListener {
                // Notifies on traffic-optimized routes that are considered better than the current route.
                override fun onBetterRouteFound(
                    newRoute: Route,
                    etaDifferenceInSeconds: Int,
                    distanceDifferenceInMeters: Int
                ) {
                    Log.d(TAG, "DynamicRoutingEngine: Calculated a new route.")
                    Log.d(
                        TAG,
                        "DynamicRoutingEngine: etaDifferenceInSeconds: $etaDifferenceInSeconds."
                    )
                    Log.d(
                        TAG,
                        "DynamicRoutingEngine: distanceDifferenceInMeters: $distanceDifferenceInMeters."
                    )

                    val logMessage =
                        "Calculated a new route. etaDifferenceInSeconds: " + etaDifferenceInSeconds +
                                " distanceDifferenceInMeters: " + distanceDifferenceInMeters
                    messageView.updateText("DynamicRoutingEngine update: $logMessage")

                    // An implementation needs to decide when to switch to the new route based
                    // on above criteria.
                }

                override fun onRoutingError(routingError: RoutingError) {
                    Log.d(
                        TAG,
                        "Error while dynamically searching for a better route: " + routingError.name
                    )
                }
            })
        } catch (e: StartException) {
            throw RuntimeException("Start of DynamicRoutingEngine failed. Is the RouteHandle missing?")
        }
    }

    fun stopNavigation(isCameraTrackingEnabled: Boolean) {
        // Switches to tracking mode when a route was set before, otherwise tracking mode is kept.
        // Note that tracking mode means that the visual navigator will continue to run, but without
        // turn-by-turn instructions - this can be done with or without camera tracking.
        // Without a route the navigator will only notify on the current map-matched location
        // including info such as speed and current street name.
        visualNavigator.route = null
        // SpeedBasedCameraBehavior is recommended for tracking mode.
        visualNavigator.cameraBehavior = SpeedBasedCameraBehavior()
        enableDevicePositioning()
        messageView.updateText("Tracking device's location.")

        dynamicRoutingEngine!!.stop()
        routePrefetcher.stopPrefetchAroundRoute()
        // Synchronize with the toggle button state.
        updateCameraTracking(isCameraTrackingEnabled)
    }

    private fun updateCameraTracking(isCameraTrackingEnabled: Boolean) {
        if (isCameraTrackingEnabled) {
            startCameraTracking()
        } else {
            stopCameraTracking()
        }
    }

    // Provides simulated location updates based on the given route.
    private fun enableRoutePlayback(route: Route?) {
        herePositioningProvider.stopLocating()
        herePositioningSimulator.startLocating(visualNavigator, route!!)
    }

    // Provides location updates based on the device's GPS sensor.
    private fun enableDevicePositioning() {
        herePositioningSimulator.stopLocating()
        herePositioningProvider.startLocating(visualNavigator, LocationAccuracy.NAVIGATION)
    }

    fun startCameraTracking() {
        visualNavigator.cameraBehavior = DynamicCameraBehavior()
    }

    fun stopCameraTracking() {
        visualNavigator.cameraBehavior = null
    }

    fun getLastKnownLocation(): Location? {
        return herePositioningProvider.getLastKnownLocation()
    }

    fun stopLocating() {
        herePositioningProvider.stopLocating()
    }

    fun stopRendering() {
        // It is recommended to stop rendering before leaving an activity.
        // This also removes the current location marker.
        visualNavigator.stopRendering()
    }

    companion object {
        private val TAG: String = NavigationExample::class.java.name
    }
}
