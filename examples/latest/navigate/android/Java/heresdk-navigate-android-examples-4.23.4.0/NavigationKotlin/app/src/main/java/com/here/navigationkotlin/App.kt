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

import android.content.Context
import android.util.Log
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.Location
import com.here.sdk.core.Point2D
import com.here.sdk.gestures.GestureState
import com.here.sdk.gestures.LongPressListener
import com.here.sdk.mapview.LineCap
import com.here.sdk.mapview.MapImageFactory
import com.here.sdk.mapview.MapMarker
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapMeasureDependentRenderSize
import com.here.sdk.mapview.MapPolyline
import com.here.sdk.mapview.MapPolyline.SolidRepresentation
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.RenderSize
import com.here.sdk.routing.CalculateRouteCallback
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingError
import com.here.sdk.routing.Waypoint


// An app that allows to calculate a route and start navigation, using either platform positioning or
// simulated locations.
class App(
    private val context: Context,
    private val mapView: MapView,
    private val messageView: MessageViewUpdater,
) {
    private val mapMarkerList: MutableList<MapMarker> = ArrayList()
    private val mapPolylines: MutableList<MapPolyline?> = ArrayList()
    private var startWaypoint: Waypoint? = null
    private var destinationWaypoint: Waypoint? = null
    private var setLongpressDestination = false
    private val routeCalculator: RouteCalculator
    private val navigationExample: NavigationExample
    private var isCameraTrackingEnabled = true
    private val timeUtils: TimeUtils

    init {
        val mapMeasureZoom =
            MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, DEFAULT_DISTANCE_IN_METERS.toDouble())
        mapView.camera.lookAt(DEFAULT_MAP_CENTER, mapMeasureZoom)

        routeCalculator = RouteCalculator()

        navigationExample = NavigationExample(context, mapView, messageView)
        navigationExample.startLocationProvider()

        timeUtils = TimeUtils()

        setLongPressGestureHandler()

        messageView.updateText("Long press to set start/destination or use random ones.")
    }

    // Calculate a route and start navigation using a location simulator.
    // Start is map center and destination location is set random within viewport,
    // unless a destination is set via long press.
    fun addRouteSimulatedLocation() {
        calculateRoute(true)
    }

    // Calculate a route and start navigation using locations from device.
    // Start is current location and destination is set random within viewport,
    // unless a destination is set via long press.
    fun addRouteDeviceLocation() {
        calculateRoute(false)
    }

    fun clearMapButtonPressed() {
        clearMap()
    }

    fun toggleTrackingButtonOnClicked() {
        // By default, this is enabled.
        navigationExample.startCameraTracking()
        isCameraTrackingEnabled = true
    }

    fun toggleTrackingButtonOffClicked() {
        navigationExample.stopCameraTracking()
        isCameraTrackingEnabled = false
    }

    private fun calculateRoute(isSimulated: Boolean) {
        clearMap()

        if (!determineRouteWaypoints(isSimulated)) {
            return
        }

        // Calculates a car route.
        startWaypoint?.let { startWaypoint ->
            destinationWaypoint?.let { destinationWaypoint ->
                routeCalculator.calculateRoute(
                    startWaypoint,
                    destinationWaypoint,
                    CalculateRouteCallback { routingError: RoutingError?, routes: List<Route>? ->
                        if (routingError == null) {
                            val route: Route = routes!![0]
                            showRouteOnMap(route)
                            showRouteDetails(route, isSimulated)
                        } else {
                            showDialog("Error while calculating a route:", routingError.toString())
                        }
                    }
                )
            }
        }
    }

    private fun determineRouteWaypoints(isSimulated: Boolean): Boolean {
        if (!isSimulated && navigationExample.getLastKnownLocation() == null) {
            showDialog("Error", "No GPS location found.")
            return false
        }

        // When using real GPS locations, we always start from the current location of user.
        if (!isSimulated) {
            val location: Location? = navigationExample.getLastKnownLocation()
            location?.let {
                startWaypoint = Waypoint(it.coordinates)
                // If a driver is moving, the bearing value can help to improve the route calculation.
                startWaypoint!!.headingInDegrees = it.bearingInDegrees
                mapView.camera.lookAt(it.coordinates)
            }
        }

        if (startWaypoint == null) {
            startWaypoint = Waypoint(createRandomGeoCoordinatesAroundMapCenter())
        }

        if (destinationWaypoint == null) {
            destinationWaypoint = Waypoint(createRandomGeoCoordinatesAroundMapCenter())
        }

        return true
    }

    private fun showRouteDetails(route: Route, isSimulated: Boolean) {
        val estimatedTravelTimeInSeconds = route.duration.seconds
        val lengthInMeters = route.lengthInMeters

        val routeDetails =
            (("Travel Time: " + timeUtils.formatTime(estimatedTravelTimeInSeconds)
                    ) + ", Length: " + timeUtils.formatLength(lengthInMeters))

        showStartNavigationDialog("Route Details", routeDetails, route, isSimulated)
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

        mapView.mapScene.addMapPolyline(routeMapPolyline!!)
        mapPolylines.add(routeMapPolyline)
    }

    private fun clearMap() {
        clearWaypointMapMarker()
        clearRoute()
        navigationExample.stopNavigation(isCameraTrackingEnabled)
    }

    private fun clearWaypointMapMarker() {
        for (mapMarker in mapMarkerList) {
            mapView.mapScene.removeMapMarker(mapMarker)
        }
        mapMarkerList.clear()
    }

    private fun clearRoute() {
        for (mapPolyline in mapPolylines) {
            mapView.mapScene.removeMapPolyline(mapPolyline!!)
        }
        mapPolylines.clear()
    }

    private fun setLongPressGestureHandler() {
        mapView.gestures.longPressListener =
            LongPressListener { gestureState: GestureState, touchPoint: Point2D? ->
                val geoCoordinates = mapView.viewToGeoCoordinates(
                    touchPoint!!
                )
                if (geoCoordinates == null) {
                    return@LongPressListener
                }
                if (gestureState == GestureState.BEGIN) {
                    if (setLongpressDestination) {
                        destinationWaypoint = Waypoint(geoCoordinates)
                        addCircleMapMarker(geoCoordinates, R.drawable.green_dot)
                        messageView.updateText("New long press destination set.")
                    } else {
                        startWaypoint = Waypoint(geoCoordinates)
                        addCircleMapMarker(geoCoordinates, R.drawable.green_dot)
                        messageView.updateText("New long press starting point set.")
                    }
                    setLongpressDestination = !setLongpressDestination
                }
            }
    }

    private fun createRandomGeoCoordinatesAroundMapCenter(): GeoCoordinates {
        val centerGeoCoordinates = mapViewCenter
        val lat = centerGeoCoordinates.latitude
        val lon = centerGeoCoordinates.longitude
        return GeoCoordinates(
            getRandom(lat - 0.02, lat + 0.02),
            getRandom(lon - 0.02, lon + 0.02)
        )
    }

    private fun getRandom(min: Double, max: Double): Double {
        return min + Math.random() * (max - min)
    }

    private val mapViewCenter: GeoCoordinates
        get() = mapView.camera.state.targetCoordinates

    private fun addCircleMapMarker(geoCoordinates: GeoCoordinates, resourceId: Int) {
        val mapImage = MapImageFactory.fromResource(context.resources, resourceId)
        val mapMarker = MapMarker(geoCoordinates, mapImage)

        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkerList.add(mapMarker)
    }

    private fun showDialog(title: String, text: String) {
        DialogManager.show(title, text, buttonText = "Ok") {}
    }

    private fun showStartNavigationDialog(
        title: String,
        message: String,
        route: Route,
        isSimulated: Boolean
    ) {
        val buttonText =
            if (isSimulated) "Start navigation (simulated)" else "Start navigation (device location)"
        DialogManager.show(
            title,
            message,
            buttonText)
            { navigationExample.startNavigation(route, isSimulated, isCameraTrackingEnabled) }
    }

    fun detach() {
        // Disables TBT guidance (if running) and enters tracking mode.
        navigationExample.stopNavigation(isCameraTrackingEnabled)
        // Disables positioning.
        navigationExample.stopLocating()
        // Disables rendering.
        navigationExample.stopRendering()
    }

    companion object {
        val DEFAULT_MAP_CENTER: GeoCoordinates = GeoCoordinates(52.520798, 13.409408)
        const val DEFAULT_DISTANCE_IN_METERS: Int = 1000 * 2
    }
}
