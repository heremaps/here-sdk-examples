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
package com.here.publictransitkotlin

import android.app.AlertDialog
import android.content.Context
import android.util.Log
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.Point2D
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.LineCap
import com.here.sdk.mapview.MapImageFactory
import com.here.sdk.mapview.MapMarker
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapMeasureDependentRenderSize
import com.here.sdk.mapview.MapPolyline
import com.here.sdk.mapview.MapPolyline.SolidRepresentation
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.RenderSize
import com.here.sdk.routing.Route
import com.here.sdk.routing.Section
import com.here.sdk.routing.TransitRouteOptions
import com.here.sdk.routing.TransitRoutingEngine
import com.here.sdk.routing.TransitWaypoint
import java.util.Locale

class PublicTransportRoutingExample(private val context: Context, private val mapView: MapView) {
    private val mapMarkerList: MutableList<MapMarker> = ArrayList()
    private val mapPolylines: MutableList<MapPolyline> = ArrayList()
    private var transitRoutingEngine: TransitRoutingEngine
    private lateinit var startGeoCoordinates: GeoCoordinates
    private lateinit var destinationGeoCoordinates: GeoCoordinates

    init {
        val camera = mapView.camera
        val distanceInMeters = (1000 * 10).toDouble()
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)

        try {
            transitRoutingEngine = TransitRoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of TransitRoutingEngine failed: " + e.error.name)
        }
    }

    fun addTransitRoute() {
        startGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        destinationGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        val startWaypoint = TransitWaypoint(startGeoCoordinates)
        val destinationWaypoint = TransitWaypoint(destinationGeoCoordinates)

        transitRoutingEngine.calculateRoute(
            startWaypoint,
            destinationWaypoint,
            TransitRouteOptions()
        ) { routingError, routes ->
            if (routingError == null) {
                val route = routes!![0]
                showRouteDetails(route)
                showRouteOnMap(route)
                logRouteViolations(route)
            } else {
                showDialog("Error while calculating a route:", routingError.toString())
            }
        }
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
                        "The violation $violationCode starts at ${toString(violationStartPoint)} and ends at ${toString(violationEndPoint)}."
                    )
                }
            }
        }
    }

    private fun toString(geoCoordinates: GeoCoordinates): String {
        return geoCoordinates.latitude.toString() + ", " + geoCoordinates.longitude
    }

    private fun showRouteDetails(route: Route) {
        val estimatedTravelTimeInSeconds = route.duration.seconds
        val lengthInMeters = route.lengthInMeters

        val routeDetails =
            ("Travel Time: ${formatTime(estimatedTravelTimeInSeconds)}, Length: ${formatLength(lengthInMeters)}.")

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

        return String.format(Locale.getDefault(), "%02d.%02d km", kilometers, remainingMeters)
    }

    private fun showRouteOnMap(route: Route) {
        clearMap()

        // Show route as polyline.
        val routeGeoPolyline = route.geometry
        val widthInPixels = 20.0
        val polylineColor = Color.valueOf(0f, 0.56f, 0.54f, 0.63f)
        var routeMapPolyline: MapPolyline? = null
        try {
            routeMapPolyline = MapPolyline(
                routeGeoPolyline, SolidRepresentation(
                    MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                    polylineColor,
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

        val startPoint =
            route.sections[0].departurePlace.mapMatchedCoordinates
        val destination =
            route.sections[route.sections.size - 1].arrivalPlace.mapMatchedCoordinates

        // Draw a circle to indicate starting point and destination.
        addCircleMapMarker(startPoint, R.drawable.green_dot)
        addCircleMapMarker(destination, R.drawable.green_dot)

        // Log maneuver instructions per route section.
        val sections = route.sections
        for (section in sections) {
            logManeuverInstructions(section)
        }
    }

    private fun logManeuverInstructions(section: Section) {
        Log.d(TAG, "Log maneuver instructions per route section:")
        val maneuverInstructions = section.maneuvers
        for (maneuverInstruction in maneuverInstructions) {
            val maneuverAction = maneuverInstruction.action
            val maneuverLocation = maneuverInstruction.coordinates
            val maneuverInfo = (maneuverInstruction.text
                    + ", Action: " + maneuverAction.name
                    + ", Location: " + maneuverLocation.toString())
            Log.d(TAG, maneuverInfo)
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

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder =
            AlertDialog.Builder(context)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }

    // Dispose the TransitRoutingEngine instance to cancel any pending requests
    // and shut it down for proper resource cleanup.
    fun dispose() {
        transitRoutingEngine.dispose()
    }

    companion object {
        private val TAG: String = PublicTransportRoutingExample::class.java.name
    }
}