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
package com.here.traffickotlin

import android.app.AlertDialog
import android.content.Context
import android.util.Log
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoCorridor
import com.here.sdk.core.GeoPolyline
import com.here.sdk.core.Point2D
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.LineCap
import com.here.sdk.mapview.MapCamera
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapMeasureDependentRenderSize
import com.here.sdk.mapview.MapPolyline
import com.here.sdk.mapview.MapPolyline.SolidRepresentation
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.RenderSize
import com.here.sdk.routing.CalculateRouteCallback
import com.here.sdk.routing.CarOptions
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingEngine
import com.here.sdk.routing.RoutingError
import com.here.sdk.routing.Waypoint
import com.here.sdk.traffic.TrafficEngine
import com.here.sdk.traffic.TrafficFlowQueryOptions


// This example shows how to request and visualize realtime traffic flow information
// with the TrafficEngine along a route corridor.
// Note that the request time may differ from the refresh cycle for TRAFFIC_FLOWs.
// Note that this does not consider future traffic predictions that are available based on
// the traffic information of the route object based on the ETA and historical traffic patterns.
class RoutingExample(private val context: Context, private val mapView: MapView) {
    private val mapPolylines = arrayListOf<MapPolyline>()
    private var routingEngine: RoutingEngine
    private var trafficEngine: TrafficEngine
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

        try {
            // The traffic engine can be used to request additional information about
            // the current traffic situation anywhere on the road network.
            trafficEngine = TrafficEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of TrafficEngine failed: " + e.error.name)
        }
    }

    fun addRoute() {
        val startGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        val destinationGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        val startWaypoint = Waypoint(startGeoCoordinates!!)
        val destinationWaypoint = Waypoint(destinationGeoCoordinates!!)

        waypoints = arrayListOf(startWaypoint, destinationWaypoint)
        calculateRoute(waypoints)
    }

    private fun calculateRoute(waypoints: List<Waypoint>) {
        routingEngine.calculateRoute(
            waypoints,
            CarOptions(),
            object : CalculateRouteCallback {
                override fun onRouteCalculated(routingError: RoutingError?, routes: List<Route>?) {
                    if (routingError == null) {
                        val route: Route = routes!![0]
                        showRouteOnMap(route)
                    } else {
                        showDialog("Error while calculating a route:", routingError.toString())
                    }
                }
            })
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

        if (routeMapPolyline != null) {
            mapView.getMapScene().addMapPolyline(routeMapPolyline)
            mapPolylines.add(routeMapPolyline)
        }

        if (route.getLengthInMeters() / 1000 > 5000) {
            showDialog("Note", "Skipped showing traffic-on-route for longer routes.");
            return;
        }

        requestRealtimeTrafficOnRoute(route)
    }

    // This code uses the TrafficEngine to request the current state of the traffic situation
    // along the specified route corridor. Note that this information might dynamically change while
    // traveling along a route and it might not relate with the given ETA for the route.
    // Whereas the traffic-flow map feature shows pre-rendered vector tiles to achieve a smooth
    // map performance, the TrafficEngine requests the same information only for a specified area.
    // Depending on the time of the request and other backend factors like rendering the traffic
    // vector tiles, there can be cases, where both results differ.
    // Note that the HERE SDK allows to specify how often to request updates for the traffic-flow
    // map feature. It is recommended to not show traffic-flow and traffic-on-route together as it
    // might lead to redundant information. Instead, consider to show the traffic-flow map feature
    // side-by-side with the route's polyline (not shown in the method below). See Routing app for an
    // example.
    private fun requestRealtimeTrafficOnRoute(route: Route) {
        // We are interested to see traffic also for side paths.
        val halfWidthInMeters = 500

        val geoCorridor = GeoCorridor(route.geometry.vertices, halfWidthInMeters)
        val trafficFlowQueryOptions = TrafficFlowQueryOptions()
        trafficEngine.queryForFlow(
            geoCorridor, trafficFlowQueryOptions
        ) { trafficQueryError, list ->
            if (trafficQueryError == null) {
                for (trafficFlow in list!!) {
                    val confidence = trafficFlow.confidence
                    if (confidence != null && confidence <= 0.5) {
                        // Exclude speed-limit data and include only real-time and historical
                        // flow information.
                        continue
                    }

                    // Visualize all polylines unfiltered as we get them from the TrafficEngine.
                    val trafficGeoPolyline = trafficFlow.location.polyline
                    addTrafficPolylines(trafficFlow.jamFactor, trafficGeoPolyline)
                }
            } else {
                showDialog("Error while fetching traffic flow:", trafficQueryError.toString())
            }
        }
    }

    private fun addTrafficPolylines(jamFactor: Double, geoPolyline: GeoPolyline) {
        val lineColor: Color = getTrafficColor(jamFactor)
            ?: // We skip rendering low traffic.
            return
        val widthInPixels = 10f
        var trafficSpanMapPolyline: MapPolyline? = null
        try {
            trafficSpanMapPolyline = MapPolyline(
                geoPolyline, SolidRepresentation(
                    MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels.toDouble()),
                    lineColor,
                    LineCap.ROUND
                )
            )
        } catch (e: MapPolyline.Representation.InstantiationException) {
            Log.e("MapPolyline Representation Exception:", e.error.name)
        } catch (e: MapMeasureDependentRenderSize.InstantiationException) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name)
        }

        mapView.mapScene.addMapPolyline(trafficSpanMapPolyline!!)
        mapPolylines.add(trafficSpanMapPolyline!!)
    }

    // Define a traffic color scheme based on the traffic jam factor.
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
        val centerGeoCoordinates = mapView.viewToGeoCoordinates(
            Point2D((mapView.width / 2).toDouble(), (mapView.height / 2).toDouble())
        )
        if (centerGeoCoordinates == null) {
            // Should never happen for center coordinates.
            throw java.lang.RuntimeException("CenterGeoCoordinates are null")
        }
        val lat = centerGeoCoordinates.latitude
        val lon = centerGeoCoordinates.longitude
        return GeoCoordinates(
            getRandom(lat - 0.02, lat + 0.02),
            getRandom(lon - 0.02, lon + 0.02)
        )
    }

   fun clearMap() {
        for (mapPolyline in mapPolylines) {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylines.clear()
    }

    private fun getRandom(min: Double, max: Double): Double {
        return min + Math.random() * (max - min)
    }

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder = AlertDialog.Builder(context)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }

    // Dispose the RoutingEngine instance to cancel any pending requests
    // and shut it down for proper resource cleanup.
    fun dispose() {
        routingEngine.dispose()
    }

    companion object {
        private val TAG: String = RoutingExample::class.java.name
    }
}
