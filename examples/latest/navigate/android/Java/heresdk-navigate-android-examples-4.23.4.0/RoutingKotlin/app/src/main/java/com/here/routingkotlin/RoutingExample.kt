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

package com.here.routingkotlin

import android.app.AlertDialog
import android.content.Context
import android.util.Log
import android.widget.Toast
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoPolyline
import com.here.sdk.core.Point2D
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.LineCap
import com.here.sdk.mapview.MapCamera
import com.here.sdk.mapview.MapImage
import com.here.sdk.mapview.MapImageFactory
import com.here.sdk.mapview.MapMarker
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapMeasureDependentRenderSize
import com.here.sdk.mapview.MapPolyline
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.RenderSize
import com.here.sdk.routing.CalculateRouteCallback
import com.here.sdk.routing.CarOptions
import com.here.sdk.routing.DynamicSpeedInfo
import com.here.sdk.routing.Maneuver
import com.here.sdk.routing.ManeuverAction
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingEngine
import com.here.sdk.routing.RoutingError
import com.here.sdk.routing.Section
import com.here.sdk.routing.SectionNotice
import com.here.sdk.routing.Toll
import com.here.sdk.routing.TrafficOptimizationMode
import com.here.sdk.routing.Waypoint
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Locale

class RoutingExample(private val context: Context, private val mapView: MapView) {

    private val mapMarkerList = arrayListOf<MapMarker>()
    private val mapPolylines = arrayListOf<MapPolyline>()
    private var routingEngine: RoutingEngine? = null
    private var startGeoCoordinates: GeoCoordinates? = null
    private var destinationGeoCoordinates: GeoCoordinates? = null
    private var trafficDisabled = false
    private val timeUtils = TimeUtils()
    private var waypoints = arrayListOf<Waypoint>()

    init {
        val camera: MapCamera = mapView.camera
        val distanceInMeters = (1000 * 10).toDouble()
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)

        try {
            routingEngine = RoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of RoutingEngine failed: " + e.error.name)
        }
    }

    fun addRoute() {
        startGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        destinationGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        val startWaypoint = Waypoint(startGeoCoordinates!!)
        val destinationWaypoint = Waypoint(destinationGeoCoordinates!!)

        waypoints = arrayListOf(startWaypoint, destinationWaypoint)
        calculateRoute(waypoints)
    }

    private fun calculateRoute(waypoints: List<Waypoint>) {
        routingEngine?.calculateRoute(
            waypoints,
            carOptions,
            object : CalculateRouteCallback {
                override fun onRouteCalculated(routingError: RoutingError?, routes: List<Route>?) {
                    if (routingError == null) {
                        val route: Route = routes!![0]
                        showRouteDetails(route)
                        showRouteOnMap(route)
                        logRouteRailwayCrossingDetails(route)
                        logRouteSectionDetails(route)
                        logRouteViolations(route)
                        logTollDetails(route)
                        showWaypointsOnMap(waypoints)
                    } else {
                        showDialog("Error while calculating a route:", routingError.toString())
                    }
                }
            })
    }

    // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
    // An implementation may decide to reject a route if one or more violations are detected.
    private fun logRouteViolations(route: Route) {
        for (section in route.sections) {
            for (span in section.spans) {
                val spanGeometryVertices: List<GeoCoordinates> = span.geometry.vertices
                // This route violation spreads across the whole span geometry.
                val violationStartPoint: GeoCoordinates = spanGeometryVertices[0]
                val violationEndPoint: GeoCoordinates =
                    spanGeometryVertices[spanGeometryVertices.size - 1]
                for (index in span.noticeIndexes) {
                    val spanSectionNotice: SectionNotice = section.sectionNotices[index]
                    // The violation code such as "VIOLATED_VEHICLE_RESTRICTION".
                    val violationCode: String = spanSectionNotice.code.toString()
                    Log.d(TAG, "The violation " + violationCode + " starts at "
                       + toString(violationStartPoint) + " and ends at " + toString(violationEndPoint) + " .")
                }
            }
        }
    }

    fun toggleTrafficOptimization() {
        trafficDisabled = !trafficDisabled
        if (waypoints.isNotEmpty()) {
            calculateRoute(waypoints)
        }
        Toast.makeText(
            context,
            "Traffic optimization is " + (if (trafficDisabled) "Disabled" else "Enabled"),
            Toast.LENGTH_LONG
        ).show()
    }

    private fun toString(geoCoordinates: GeoCoordinates): String {
        return geoCoordinates.latitude.toString() + ", " + geoCoordinates.longitude
    }

    private fun logRouteSectionDetails(route: Route) {
        val dateFormat: DateFormat = SimpleDateFormat("HH:mm", Locale.getDefault())

        for (i in route.sections.indices) {
            val section: Section = route.sections.get(i)

            Log.d(TAG, "Route Section : " + (i + 1))
            Log.d(TAG, "Route Section Departure Time : "
                        + dateFormat.format(section.departureLocationTime!!.localTime)
            )
            Log.d(TAG, "Route Section Arrival Time : "
                        + dateFormat.format(section.arrivalLocationTime!!.localTime)
            )
            Log.d(TAG, "Route Section length : " + section.lengthInMeters + " m")
            Log.d(TAG, "Route Section duration : " + section.duration.seconds + " s")
        }
    }

    private fun logRouteRailwayCrossingDetails(route: Route) {
        for (routeRailwayCrossing in route.railwayCrossings) {
            // Coordinates of the route offset
            val routeOffsetCoordinates: GeoCoordinates = routeRailwayCrossing.coordinates
            // Index of the corresponding route section. The start of the section indicates the start of the offset.
            val routeOffsetSectionIndex: Int = routeRailwayCrossing.routeOffset.sectionIndex
            // Offset from the start of the specified section to the specified location along the route.
            val routeOffsetInMeters: Double = routeRailwayCrossing.routeOffset.offsetInMeters

            Log.d(TAG, "A railway crossing of type " + routeRailwayCrossing.type.name +
                "is situated " +
                routeOffsetInMeters + " m away from start of section: " +
                routeOffsetSectionIndex)
        }
    }

    private fun logTollDetails(route: Route) {
        for (section in route.sections) {
            // The spans that make up the polyline along which tolls are required or
            // where toll booths are located.
            val tolls: List<Toll> = section.tolls
            if (tolls.isNotEmpty()) {
                Log.d(TAG, "Attention: This route may require tolls to be paid.")
            }
            for (toll in tolls) {
                Log.d(TAG, "Toll information valid for this list of spans:")
                Log.d(TAG, "Toll systems: " + toll.tollSystems)
                Log.d(TAG, "Toll country code (ISO-3166-1 alpha-3): " + toll.countryCode)
                Log.d(TAG, "Toll fare information: ")
                for (tollFare in toll.fares) {
                    // A list of possible toll fares which may depend on time of day, payment method and
                    // vehicle characteristics. For further details please consult the local
                    // authorities.
                    Log.d(TAG, "Toll price: " + tollFare.price + " " + tollFare.currency)
                    for (paymentMethod in tollFare.paymentMethods) {
                        Log.d(TAG, "Accepted payment methods for this price: " + paymentMethod.name)
                    }
                }
            }
        }
    }

    private fun showRouteDetails(route: Route) {
        // estimatedTravelTimeInSeconds includes traffic delay.
        val estimatedTravelTimeInSeconds: Long = route.duration.seconds
        val estimatedTrafficDelayInSeconds: Long = route.trafficDelay.seconds
        val lengthInMeters: Int = route.lengthInMeters

        // Timezones can vary depending on the device's geographic location.
        // For instance, when calculating a route, the device's current timezone may differ from that of the destination.
        // Consider a scenario where a user calculates a route from Berlin to London — each city operates in a different timezone.
        // To address this, you can display the Estimated Time of Arrival (ETA) in multiple timezones: the device's current timezone (Berlin), the destination's timezone (London), and UTC (Coordinated Universal Time), which serves as a global reference.
        val routeDetails = """
            Travel Duration: ${timeUtils.formatTime(estimatedTravelTimeInSeconds)}
            Traffic Delay: ${timeUtils.formatTime(estimatedTrafficDelayInSeconds)}
            Route Length (m): ${timeUtils.formatLength(lengthInMeters)}
            ETA in Device Timezone: ${timeUtils.getETAinDeviceTimeZone(route)}
            ETA in Destination Timezone: ${timeUtils.getETAinDestinationTimeZone(route)}
            ETA in UTC: ${timeUtils.getEstimatedTimeOfArrivalInUTC(route)}
        """.trimIndent()

        showDialog("Route Details", routeDetails)
    }

    private fun showRouteOnMap(route: Route) {
        // Optionally, clear any previous route.
        clearMap()

        // Show route as polyline.
        val routeGeoPolyline: GeoPolyline = route.geometry
        val widthInPixels = 20f
        val polylineColor = Color(0f, 0.56.toFloat(), 0.54.toFloat(), 0.63.toFloat())
        var routeMapPolyline: MapPolyline? = null

        try {
            routeMapPolyline = MapPolyline(
                routeGeoPolyline, MapPolyline.SolidRepresentation(
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

        if (routeMapPolyline != null) {
            mapView.mapScene.addMapPolyline(routeMapPolyline)
            mapPolylines.add(routeMapPolyline)
        }

        // Optionally, render traffic on route.
        showTrafficOnRoute(route)

        // Log maneuver instructions per route section.
        val sections: List<Section> = route.sections
        for (section in sections) {
            logManeuverInstructions(section)
        }
    }

    private fun showWaypointsOnMap(waypoints: List<Waypoint>) {
        val n = waypoints.size
        for (i in 0 until n) {
            val currentGeoCoordinates: GeoCoordinates = waypoints[i].coordinates
            if (i == 0 || i == n - 1) {
                // Draw a green circle to indicate starting point and destination.
                addCircleMapMarker(currentGeoCoordinates, R.drawable.green_dot)
            } else {
                // Draw a red circle to indicate intermediate waypoints, if any.
                addCircleMapMarker(currentGeoCoordinates, R.drawable.red_dot)
            }
        }
    }

    private fun logManeuverInstructions(section: Section) {
        Log.d(TAG, "Log maneuver instructions per route section:")
        val maneuverInstructions: List<Maneuver> = section.maneuvers
        for (maneuverInstruction in maneuverInstructions) {
            val maneuverAction: ManeuverAction = maneuverInstruction.action
            val maneuverLocation: GeoCoordinates = maneuverInstruction.coordinates
            val maneuverInfo: String = (maneuverInstruction.text
                    + ", Action: " + maneuverAction.name
                    + ", Location: " + maneuverLocation.toString())
            Log.d(TAG, maneuverInfo)
        }
    }

    fun addWaypoints() {
        if (startGeoCoordinates == null || destinationGeoCoordinates == null) {
            showDialog("Error", "Please add a route first.")
            return
        }

        val waypoint1 = Waypoint(createRandomGeoCoordinatesAroundMapCenter())
        val waypoint2 = Waypoint(createRandomGeoCoordinatesAroundMapCenter())
        waypoints = arrayListOf(Waypoint(startGeoCoordinates!!), waypoint1, waypoint2, Waypoint(destinationGeoCoordinates!!))
        calculateRoute(waypoints)
    }

    private val carOptions: CarOptions
        get() {
            val carOptions = CarOptions()
            carOptions.routeOptions.enableTolls = true

            // Enable usage of HOV and HOT lanes.
            // Note: These lanes will only be used if they are available in the selected country.
            carOptions.allowOptions.allowHov = true;
            carOptions.allowOptions.allowHot = true;

            // When occupantsNumber is greater than 1, it enables the vehicle to use HOV/HOT lanes.
            carOptions.occupantsNumber = 4

            // Disabled - Traffic optimization is completely disabled, including long-term road closures. It helps in producing stable routes.
            // Time dependent - Traffic optimization is enabled, the shape of the route will be adjusted according to the traffic situation which depends on departure time and arrival time.
            carOptions.routeOptions.trafficOptimizationMode =
                if (trafficDisabled) TrafficOptimizationMode.DISABLED else TrafficOptimizationMode.TIME_DEPENDENT
            return carOptions
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

    // This renders the traffic jam factor on top of the route as multiple MapPolylines per span.
    private fun showTrafficOnRoute(route: Route) {
        if (route.lengthInMeters / 1000 > 5000) {
            Log.d(TAG, "Skip showing traffic-on-route for longer routes.")
            return
        }

        for (section in route.sections) {
            for (span in section.spans) {
                val dynamicSpeed: DynamicSpeedInfo? = span.dynamicSpeedInfo
                val lineColor = getTrafficColor(dynamicSpeed?.calculateJamFactor())
                    ?: // We skip rendering low traffic.
                    continue
                val widthInPixels = 10f
                var trafficSpanMapPolyline: MapPolyline? = null
                try {
                    trafficSpanMapPolyline = MapPolyline(
                        span.geometry, MapPolyline.SolidRepresentation(
                            MapMeasureDependentRenderSize(
                                RenderSize.Unit.PIXELS,
                                widthInPixels.toDouble()
                            ),
                            lineColor,
                            LineCap.ROUND
                        )
                    )
                } catch (e: MapPolyline.Representation.InstantiationException) {
                    Log.e("MapPolyline Representation Exception:", e.error.name)
                } catch (e: MapMeasureDependentRenderSize.InstantiationException) {
                    Log.e("MapMeasureDependentRenderSize Exception:", e.error.name)
                }

                if (trafficSpanMapPolyline != null) {
                    mapView.mapScene.addMapPolyline(trafficSpanMapPolyline)
                    mapPolylines.add(trafficSpanMapPolyline)
                }
            }
        }
    }

    // Define a traffic color scheme based on the route's jam factor.
    // 0 <= jamFactor < 4: No or light traffic.
    // 4 <= jamFactor < 8: Moderate or slow traffic.
    // 8 <= jamFactor < 10: Severe traffic.
    // jamFactor = 10: No traffic, ie. the road is blocked.
    // Returns null in case of no or light traffic.
    private fun getTrafficColor(jamFactor: Double?): Color? {
        if (jamFactor == null || jamFactor < 4) {
            return null
        } else if (jamFactor >= 4 && jamFactor < 8) {
            return Color.valueOf(1f, 1f, 0f, 0.63f) // Yellow
        } else if (jamFactor >= 8 && jamFactor < 10) {
            return Color.valueOf(1f, 0f, 0f, 0.63f) // Red
        }
        return Color.valueOf(0f, 0f, 0f, 0.63f) // Black
    }

    private fun createRandomGeoCoordinatesAroundMapCenter(): GeoCoordinates {
        val centerGeoCoordinates: GeoCoordinates? = mapView.viewToGeoCoordinates(
            Point2D((mapView.width / 2).toDouble(), (mapView.height / 2).toDouble())
        )
        if (centerGeoCoordinates == null) {
            // Should never happen for center coordinates.
            throw RuntimeException("CenterGeoCoordinates are null")
        }
        val lat: Double = centerGeoCoordinates.latitude
        val lon: Double = centerGeoCoordinates.longitude
        return GeoCoordinates(
            getRandom(lat - 0.02, lat + 0.02),
            getRandom(lon - 0.02, lon + 0.02)
        )
    }

    private fun getRandom(min: Double, max: Double): Double {
        return min + Math.random() * (max - min)
    }

    private fun addCircleMapMarker(geoCoordinates: GeoCoordinates, resourceId: Int) {
        val mapImage: MapImage = MapImageFactory.fromResource(context.resources, resourceId)
        val mapMarker = MapMarker(geoCoordinates, mapImage)
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkerList.add(mapMarker)
    }

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder = AlertDialog.Builder(context)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }

    companion object {
        private val TAG: String = RoutingExample::class.java.name
    }
}
