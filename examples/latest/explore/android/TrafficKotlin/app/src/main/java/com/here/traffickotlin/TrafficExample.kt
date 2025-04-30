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
import com.here.sdk.core.GeoCircle
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoPolyline
import com.here.sdk.core.Point2D
import com.here.sdk.core.Rectangle2D
import com.here.sdk.core.Size2D
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.gestures.TapListener
import com.here.sdk.mapview.LineCap
import com.here.sdk.mapview.MapCamera
import com.here.sdk.mapview.MapContentSettings
import com.here.sdk.mapview.MapContentSettings.TrafficRefreshPeriodException
import com.here.sdk.mapview.MapFeatureModes
import com.here.sdk.mapview.MapFeatures
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapMeasureDependentRenderSize
import com.here.sdk.mapview.MapPolyline
import com.here.sdk.mapview.MapPolyline.SolidRepresentation
import com.here.sdk.mapview.MapScene.MapPickFilter
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.MapViewBase.MapPickCallback
import com.here.sdk.mapview.RenderSize
import com.here.sdk.traffic.TrafficEngine
import com.here.sdk.traffic.TrafficIncident
import com.here.sdk.traffic.TrafficIncidentLookupOptions
import com.here.sdk.traffic.TrafficIncidentsQueryOptions
import com.here.time.Duration

class TrafficExample(private val context: Context, private val mapView: MapView) {

    private val mapPolylines = arrayListOf<MapPolyline>()
    private var trafficEngine: TrafficEngine? = null

    init {
        val camera: MapCamera = mapView.camera
        val distanceInMeters = (1000 * 10).toDouble()
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)

        try {
            // The traffic engine can be used to request additional information about
            // the current traffic situation anywhere on the road network.
            trafficEngine = TrafficEngine()
        } catch (e: InstantiationErrorException) {
            throw java.lang.RuntimeException("Initialization of TrafficEngine failed: " + e.error.name)
        }

        // Setting a tap handler to pick and search for traffic incidents around the tapped area.
        setTapGestureHandler();

        showDialog("Note", "Tap on the map to pick a traffic incident.");
    }

    fun enableAll() {
        // Show real-time traffic lines and incidents on the map.
        enableTrafficVisualization()
    }

    fun disableAll() {
        disableTrafficVisualization()
    }

    private fun enableTrafficVisualization() {
        // Try to refresh the TRAFFIC_FLOW vector tiles 5 minutes.
        // If MapFeatures.TRAFFIC_FLOW is disabled, no requests are made.
        //
        // Note: This code initiates periodic calls to the HERE Traffic backend. Depending on your contract,
        // each call may be charged separately. It is the application's responsibility to decide how
        // often this code should be executed.
        try {
            MapContentSettings.setTrafficRefreshPeriod(Duration.ofMinutes(5))
        } catch (e: TrafficRefreshPeriodException) {
            throw RuntimeException("TrafficRefreshPeriodException: " + e.error.name)
        }

        val mapFeatures: MutableMap<String, String> = HashMap()
        // Once these traffic layers are added to the map, they will be automatically updated while panning the map.
        mapFeatures[MapFeatures.TRAFFIC_FLOW] = MapFeatureModes.TRAFFIC_FLOW_WITH_FREE_FLOW
        // MapFeatures.TRAFFIC_INCIDENTS renders traffic icons and lines to indicate the location of incidents.
        mapFeatures[MapFeatures.TRAFFIC_INCIDENTS] = MapFeatureModes.DEFAULT
        mapView.mapScene.enableFeatures(mapFeatures)
    }

    private fun disableTrafficVisualization() {
        val mapFeatures: MutableList<String> = ArrayList()
        mapFeatures.add(MapFeatures.TRAFFIC_FLOW)
        mapFeatures.add(MapFeatures.TRAFFIC_INCIDENTS)
        mapView.mapScene.disableFeatures(mapFeatures)

        // This clears only the custom visualization for incidents found with the TrafficEngine.
        clearTrafficIncidentsMapPolylines()
    }

    private fun setTapGestureHandler() {
        mapView.gestures.tapListener =
            TapListener { touchPoint: Point2D? ->
                val touchGeoCoords = mapView.viewToGeoCoordinates(
                    touchPoint!!
                )
                // Can be null when the map was tilted and the sky was tapped.
                if (touchGeoCoords != null) {
                    // Pick incidents that are shown in MapScene.Layers.TRAFFIC_INCIDENTS.
                    pickTrafficIncident(touchPoint)

                    // Query for incidents independent of MapScene.Layers.TRAFFIC_INCIDENTS.
                    queryForIncidents(touchGeoCoords)
                }
            }
    }

    // Traffic incidents can only be picked, when MapScene.Layers.TRAFFIC_INCIDENTS is visible.
    private fun pickTrafficIncident(touchPointInPixels: Point2D) {
        val originInPixels = Point2D(touchPointInPixels.x, touchPointInPixels.y)
        val sizeInPixels = Size2D(1.0, 1.0)
        val rectangle = Rectangle2D(originInPixels, sizeInPixels)

        // Creates a list of map content type from which the results will be picked.
        // The content type values can be MAP_CONTENT, MAP_ITEMS and CUSTOM_LAYER_DATA.
        val contentTypesToPickFrom = ArrayList<MapPickFilter.ContentType>()

        // MAP_CONTENT is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
        // MAP_ITEMS is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
        // Currently we need traffic incidents so adding the MAP_CONTENT filter.
        contentTypesToPickFrom.add(MapPickFilter.ContentType.MAP_CONTENT)
        val filter = MapPickFilter(contentTypesToPickFrom)

        // If you do not want to specify any filter you can pass filter as NULL and all of the pickable contents will be picked.
        mapView.pick(filter, rectangle, MapPickCallback { mapPickResult ->
            if (mapPickResult == null) {
                // An error occurred while performing the pick operation.
                return@MapPickCallback
            }
            val trafficIncidents =
                mapPickResult.mapContent!!.trafficIncidents
            if (trafficIncidents.isEmpty()) {
                Log.d(TAG, "No traffic incident found at picked location")
            } else {
                Log.d(TAG, "Picked at least one incident.")
                val firstIncident = trafficIncidents[0]
                showDialog(
                    "Traffic incident picked:", "Type: " +
                            firstIncident.type.name
                )

                // Find more details by looking up the ID via TrafficEngine.
                findIncidentByID(firstIncident.originalId)
            }
            // Optionally, look for more map content like embedded POIs.
        })
    }

    private fun findIncidentByID(originalId: String) {
        val trafficIncidentsQueryOptions = TrafficIncidentLookupOptions()
        // Optionally, specify a language:
        // the language of the country where the incident occurs is used.
        // trafficIncidentsQueryOptions.languageCode = LanguageCode.EN_US;
        trafficEngine!!.lookupIncident(
            originalId, trafficIncidentsQueryOptions
        ) { trafficQueryError, trafficIncident ->
            if (trafficQueryError == null) {
                Log.d(
                    TAG, "Fetched TrafficIncident from lookup request." +
                            " Description: " + trafficIncident!!.description.text
                )
                addTrafficIncidentsMapPolyline(trafficIncident!!.location.polyline)
            } else {
                showDialog("TrafficLookupError:", trafficQueryError.toString())
            }
        }
    }

    private fun addTrafficIncidentsMapPolyline(geoPolyline: GeoPolyline) {
        // Show traffic incident as polyline.
        val widthInPixels = 20f
        val polylineColor: Color = Color.valueOf(0f, 0f, 0f, 0.5f);
        var routeMapPolyline: MapPolyline? = null
        try {
            routeMapPolyline = MapPolyline(
                geoPolyline, SolidRepresentation(
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
        mapPolylines.add(routeMapPolyline!!)
    }

    private fun queryForIncidents(centerCoords: GeoCoordinates) {
        val radiusInMeters = 1000
        val geoCircle = GeoCircle(centerCoords, radiusInMeters.toDouble())
        val trafficIncidentsQueryOptions = TrafficIncidentsQueryOptions()
        // Optionally, specify a language:
        // the language of the country where the incident occurs is used.
        // trafficIncidentsQueryOptions.languageCode = LanguageCode.EN_US;
        trafficEngine!!.queryForIncidents(
            geoCircle, trafficIncidentsQueryOptions
        ) { trafficQueryError, trafficIncidentsList ->
            if (trafficQueryError == null) {
                // If error is null, it is guaranteed that the list will not be null.
                var trafficMessage = "Found " + trafficIncidentsList!!.size + " result(s)."
                val nearestIncident =
                    getNearestTrafficIncident(centerCoords, trafficIncidentsList)
                if (nearestIncident != null) {
                    trafficMessage += " Nearest incident: " + nearestIncident.description.text
                }
                Log.d(TAG, "Nearby traffic incidents: $trafficMessage")
                for (trafficIncident in trafficIncidentsList) {
                    Log.d(TAG, "" + trafficIncident.description.text)
                }
            } else {
                Log.d(TAG, "TrafficQueryError: $trafficQueryError")
            }
        }
    }

    private fun getNearestTrafficIncident(
        currentGeoCoords: GeoCoordinates,
        trafficIncidentsList: List<TrafficIncident>?
    ): TrafficIncident? {
        if (trafficIncidentsList!!.size == 0) {
            return null
        }

        // By default, traffic incidents results are not sorted by distance.
        var nearestDistance = Double.MAX_VALUE
        var nearestTrafficIncident: TrafficIncident? = null
        for (trafficIncident in trafficIncidentsList) {
            // In case lengthInMeters == 0 then the polyline consistes of two equal coordinates.
            // It is guaranteed that each incident has a valid polyline.
            for (geoCoords in trafficIncident.location.polyline.vertices) {
                val currentDistance = currentGeoCoords.distanceTo(geoCoords)
                if (currentDistance < nearestDistance) {
                    nearestDistance = currentDistance
                    nearestTrafficIncident = trafficIncident
                }
            }
        }

        return nearestTrafficIncident
    }

    private fun clearTrafficIncidentsMapPolylines() {
        for (mapPolyline in mapPolylines) {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylines.clear()
    }

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder = AlertDialog.Builder(context)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }

    companion object {
        private val TAG: String = TrafficExample::class.java.name
    }
}
