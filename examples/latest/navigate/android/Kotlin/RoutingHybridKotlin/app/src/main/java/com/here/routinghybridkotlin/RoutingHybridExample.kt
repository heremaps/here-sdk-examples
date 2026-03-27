/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
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

package com.here.routinghybridkotlin

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.util.Log
import android.widget.Toast
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.Point2D
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.LineCap
import com.here.sdk.mapview.MapCamera
import com.here.sdk.mapview.MapImageFactory
import com.here.sdk.mapview.MapMarker
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapMeasureDependentRenderSize
import com.here.sdk.mapview.MapPolyline
import com.here.sdk.mapview.MapPolyline.SolidRepresentation
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.RenderSize
import com.here.sdk.navigation.VisualNavigator
import com.here.sdk.routing.CalculateRouteCallback
import com.here.sdk.routing.RoutingOptions
import com.here.sdk.routing.OfflineRoutingEngine
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingEngine
import com.here.sdk.routing.RoutingError
import com.here.sdk.routing.RoutingInterface
import com.here.sdk.routing.Section
import com.here.sdk.routing.Waypoint
import java.util.Locale

class RoutingHybridExample(private val context: Context, private val mapView: MapView) {

    private val mapMarkerList = arrayListOf<MapMarker>()
    private val mapPolylines = arrayListOf<MapPolyline>()
    private var routingEngine: RoutingInterface
    private var onlineRoutingEngine: RoutingEngine
    private var offlineRoutingEngine: OfflineRoutingEngine
    private var startGeoCoordinates: GeoCoordinates? = null
    private var destinationGeoCoordinates: GeoCoordinates? = null

    // Set to true so that routingEngine starts with online routing by default.
    private var isSwitchOnlineButtonClicked = true

    init {
        val camera: MapCamera = mapView.camera
        val distanceInMeters = 5000.0
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)

        try {
            onlineRoutingEngine = RoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of RoutingEngine failed: ${e.error.name}")
        }

        try {
            // Allows to calculate routes on already downloaded or cached map data.
            // For downloading offline maps, please check the OfflineMaps example app.
            // This app uses only cached map data that gets downloaded when the user
            // pans the map. Please note that the OfflineRoutingEngine may not be able
            // to calculate a route, when not all map tiles are loaded. Especially, the
            // vector tiles for lower zoom levels are required to find possible paths.
            offlineRoutingEngine = OfflineRoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of OfflineRoutingEngine failed: ${e.error.name}")
        }

        // It is recommended to download or to prefetch a route corridor beforehand to ensure a smooth user experience during navigation. For simplicity, this is left out for this example.

        try {
            // The engine can be dynamically switched between online and offline modes based on connectivity using the isDeviceOnline() and setRoutingEngine() function.
            // Note: For demonstration purposes, isDeviceOnline() uses a simple UI toggle (isSwitchOnlineButtonClicked) instead of actual network connectivity detection.
            // In production, implement proper connectivity checks using ConnectivityManager or similar network monitoring solutions.
            // Here we are setting the default routing engine to online routing.
            routingEngine = onlineRoutingEngine
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("RoutingEngine initialization failed.${e.message}")
        }
    }

    // Calculates a route with two waypoints (start / destination).
    fun addRoute() {
        setRoutingEngine()

        val startingPoint = createRandomGeoCoordinatesAroundMapCenter()
        val destinationPoint = createRandomGeoCoordinatesAroundMapCenter()

        // Store the generated coordinates in global variables for use in other functions.
        startGeoCoordinates = startingPoint
        destinationGeoCoordinates = destinationPoint

        val startWaypoint = Waypoint(startingPoint)
        val destinationWaypoint = Waypoint(destinationPoint)

        val waypoints = arrayListOf(startWaypoint, destinationWaypoint)

        routingEngine.calculateRoute(
            waypoints,
            RoutingOptions(),
            object : CalculateRouteCallback {
                override fun onRouteCalculated(routingError: RoutingError?, routeList: List<Route>?) {
                    routingError?.let {
                        showDialog("Error while calculating a route:", routingError.toString())
                        return
                    }

                    // If routingError is null, routes is guaranteed to be not null.
                    routeList?.let {
                        if (routeList.isEmpty()) {
                            showDialog("Error while calculating a route:", "No route found.")
                            return
                        }
                        val route = routeList[0]
                        showRouteDetails(route)
                        showRouteOnMap(route)
                        logRouteViolations(route)
                    }
                }
            })
    }

    // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
    // An implementation may decide to reject a route if one or more violations are detected.
    private fun logRouteViolations(route: Route) {
        for (section in route.sections) {
            for (span in section.spans) {
                val spanGeometryVertices = span.geometry.vertices
                // This route violation spreads across the whole span geometry.
                val violationStartPoint = spanGeometryVertices[0]
                val violationEndPoint = spanGeometryVertices[spanGeometryVertices.size - 1]
                for (index in span.noticeIndexes) {
                    val spanSectionNotice = section.sectionNotices[index]
                    // The violation code such as "VIOLATED_VEHICLE_RESTRICTION".
                    val violationCode = spanSectionNotice.code.toString()
                    Log.d(
                        TAG,
                        "The violation $violationCode starts at $violationStartPoint and ends at $violationEndPoint."
                    )
                }
            }
        }
    }

    private fun showRouteDetails(route: Route) {
        val estimatedTravelTimeInSeconds = route.duration.seconds
        val lengthInMeters = route.lengthInMeters

        val routeDetails =
            "Travel Time: ${formatTime(estimatedTravelTimeInSeconds)}, Length: ${formatLength(lengthInMeters)}"

        showDialog("Route Details", routeDetails)
    }

    private fun formatTime(sec: Long): String {
        val hours = (sec / 3600).toInt()
        val minutes = ((sec % 3600) / 60).toInt()

        return String.format(Locale.getDefault(), "%02d:%02d", hours, minutes)
    }

    private fun formatLength(meters: Int): String {
        val kilometers = meters / 1000
        val remainingMeters = meters % 1000

        return String.format(Locale.getDefault(), "%d.%03d km", kilometers, remainingMeters)
    }

    private fun showRouteOnMap(route: Route) {
        clearMap()

        // Show route as polyline.
        val routeGeoPolyline = route.geometry
        val polylineColor = Color.valueOf(0.051f, 0.380f, 0.871f, 1.0f)
        val outlineColor = Color.valueOf(0.043f, 0.325f, 0.749f, 1.0f)
        var routeMapPolyline: MapPolyline? = null
        try {
            // Below, we're creating an instance of MapMeasureDependentRenderSize. This instance will use the scaled width values to render the route polyline.
            // We can also apply the same values to MapArrow.setMeasureDependentTailWidth().
            // The parameters for the constructor are: the kind of MapMeasure (in this case, ZOOM_LEVEL), the unit of measurement for the render size (PIXELS), and the scaled width values.
            val mapMeasureDependentLineWidth = MapMeasureDependentRenderSize(
                MapMeasure.Kind.ZOOM_LEVEL,
                RenderSize.Unit.PIXELS,
                getDefaultLineWidthValues()
            )

            // We can also use MapMeasureDependentRenderSize to specify the outline width of the polyline.
            val outlineWidthInPixel = 1.23 * mapView.pixelScale
            val mapMeasureDependentOutlineWidth =
                MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, outlineWidthInPixel)
            routeMapPolyline = MapPolyline(
                routeGeoPolyline, SolidRepresentation(
                    mapMeasureDependentLineWidth,
                    polylineColor,
                    mapMeasureDependentOutlineWidth,
                    outlineColor,
                    LineCap.ROUND
                )
            )
        } catch (e: MapPolyline.Representation.InstantiationException) {
            Log.e("MapPolyline Representation Exception:", e.error.name)
        } catch (e: MapMeasureDependentRenderSize.InstantiationException) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name)
        }

        routeMapPolyline?.let {
            mapView.mapScene.addMapPolyline(routeMapPolyline)
            mapPolylines.add(routeMapPolyline)
        }

        val startPoint = route.sections[0].departurePlace.mapMatchedCoordinates
        val destination = route.sections[route.sections.size - 1].arrivalPlace.mapMatchedCoordinates

        // Draw a circle to indicate starting point and destination.
        addCircleMapMarker(startPoint, R.drawable.green_dot)
        addCircleMapMarker(destination, R.drawable.green_dot)

        // Log maneuver instructions per route section.
        val sections = route.sections
        for (section in sections) {
            logManeuverInstructions(section)
        }
    }

    // Retrieves the default widths of a route polyline and maneuver arrows from VisualNavigator,
    // scaling them based on the screen's pixel density.
    // Note that the VisualNavigator stores the width values per zoom level MapMeasure.Kind.
    private fun getDefaultLineWidthValues(): MutableMap<Double, Double> {
        val widthsPerZoomLevel = HashMap<Double, Double>()
        for (defaultValues in VisualNavigator.defaultRouteManeuverArrowMeasureDependentWidths().entries) {
            val key = defaultValues.key.value
            val value = defaultValues.value * mapView.pixelScale
            widthsPerZoomLevel.put(key, value)
        }
        return widthsPerZoomLevel
    }

    private fun logManeuverInstructions(section: Section) {
        Log.d(TAG, "Log maneuver instructions per route section:")
        val maneuverInstructions = section.maneuvers
        for (maneuverInstruction in maneuverInstructions) {
            val maneuverAction = maneuverInstruction.action
            val maneuverLocation = maneuverInstruction.coordinates
            val maneuverInfo = "${maneuverInstruction.text}, Action: ${maneuverAction.name}, Location: $maneuverLocation"
            Log.d(TAG, maneuverInfo)
        }
    }

    // Calculates a route with additional waypoints.
    fun addWaypoints() {
        setRoutingEngine()

        val startingPoint = startGeoCoordinates ?: return showDialog("Error", "Please add a route first.")
        val destinationPoint = destinationGeoCoordinates ?: return showDialog("Error", "Please add a route first.")
        val waypoint1 = Waypoint(createRandomGeoCoordinatesAroundMapCenter())
        val waypoint2 = Waypoint(createRandomGeoCoordinatesAroundMapCenter())
        val waypoints = mutableListOf(Waypoint(startingPoint), waypoint1, waypoint2, Waypoint(destinationPoint))

        routingEngine.calculateRoute(waypoints, RoutingOptions()) { routingError, routes ->
            if (routingError != null) {
                showDialog("Error while calculating a route:", routingError.toString())
                return@calculateRoute
            }

            val route = routes?.firstOrNull()
                ?: return@calculateRoute showDialog("Error while calculating a route:", "No route found.")

            showRouteDetails(route)
            showRouteOnMap(route)
            logRouteViolations(route)

            // Indicate the waypoint locations.
            addCircleMapMarker(waypoint1.coordinates, R.drawable.red_dot)
            addCircleMapMarker(waypoint2.coordinates, R.drawable.red_dot)
        }
    }

    fun clearMap() {
        clearWaypointMapMarker()
        clearRoute()
    }

    private fun clearWaypointMapMarker() {
        for (mapMarker in mapMarkerList) {
            mapView.mapScene.removeMapMarker(mapMarker)
        }
        mapMarkerList.clear()
    }

    private fun clearRoute() {
        for (mapPolyline in mapPolylines) {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylines.clear()
    }

    private fun createRandomGeoCoordinatesAroundMapCenter(): GeoCoordinates {
        val centerGeoCoordinates = mapView.viewToGeoCoordinates(
            Point2D((mapView.width / 2).toDouble(), (mapView.height / 2).toDouble())
        )
        if (centerGeoCoordinates == null) {
            // Should never happen for center coordinates.
            throw RuntimeException("CenterGeoCoordinates are null")
        }
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

    private fun addCircleMapMarker(geoCoordinates: GeoCoordinates, resourceId: Int) {
        val mapImage = MapImageFactory.fromResource(context.resources, resourceId)
        val mapMarker = MapMarker(geoCoordinates, mapImage)
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkerList.add(mapMarker)
    }

    // Sets the OfflineRoutingEngine as main engine when the device is not connected, otherwise this will set the
    // RoutingEngine that requires connectivity.
    private fun setRoutingEngine() {
        routingEngine = if (isDeviceOnline()) {
            onlineRoutingEngine
        } else {
            offlineRoutingEngine
        }
    }

    fun onSwitchOnlineButtonClicked() {
        isSwitchOnlineButtonClicked = true
        Toast.makeText(context, "The app will now use the RoutingEngine.", Toast.LENGTH_LONG).show()
    }

    fun onSwitchOfflineButtonClicked() {
        isSwitchOnlineButtonClicked = false
        Toast.makeText(context, "The app will now use the OfflineRoutingEngine.", Toast.LENGTH_LONG)
            .show()
    }

    private fun isDeviceOnline(): Boolean {
        // In production apps, implement proper network connectivity detection here.
        // See Android's ConnectivityManager guide: https://developer.android.com/training/monitoring-device-state/connectivity-monitoring
        // For this example app, connectivity is simulated using UI toggle buttons for easy testing.
        return isSwitchOnlineButtonClicked
    }

    private fun showDialog(title: String, message: String) {
        if(context is Activity) {
            val builder: AlertDialog.Builder = AlertDialog.Builder(context)
            builder.setTitle(title)
            builder.setMessage(message)
            builder.show()
        }
    }

    private fun logError(error: String) {
        Log.e(TAG, error)
    }

    // Dispose the RoutingEngine and OfflineRoutingEngine instance to cancel 
    // any pending requests and shut it down for proper resource cleanup.
    fun dispose() {
        onlineRoutingEngine.dispose()
        offlineRoutingEngine.dispose()
    }

    companion object {
        private val TAG: String = RoutingHybridExample::class.java.name
    }
}
