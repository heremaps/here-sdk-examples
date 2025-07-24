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
package com.here.mapitemskotlin

import android.util.Log
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCircle
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoCoordinatesUpdate
import com.here.sdk.core.GeoPolygon
import com.here.sdk.core.GeoPolyline
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.LineCap
import com.here.sdk.mapview.MapArrow
import com.here.sdk.mapview.MapCamera
import com.here.sdk.mapview.MapCameraAnimationFactory
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapMeasureDependentRenderSize
import com.here.sdk.mapview.MapMeasureRange
import com.here.sdk.mapview.MapPolygon
import com.here.sdk.mapview.MapPolyline
import com.here.sdk.mapview.MapScene
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.RenderSize
import com.here.time.Duration

class MapObjectsExample(private val mapView: MapView) {

    private val BERLIN_GEO_COORDINATES: GeoCoordinates = GeoCoordinates(52.51760485151816, 13.380312380535472)
    private var mapScene: MapScene? = null
    private var mapCamera: MapCamera? = null
    private var mapPolyline: MapPolyline? = null
    private var mapArrow: MapArrow? = null
    private var mapPolygon: MapPolygon? = null
    private var mapCircle: MapPolygon? = null

    init {
        mapScene = mapView.getMapScene()
        mapCamera = mapView.getCamera()
    }

    fun showMapPolyline() {
        clearMap()
        // Move map to expected location.
        flyTo(BERLIN_GEO_COORDINATES)

        mapPolyline = createPolyline()
        mapScene!!.addMapPolyline(mapPolyline!!)
    }

    fun enableVisibilityRangesForPolyline() {
        val visibilityRanges = ArrayList<MapMeasureRange>()

        // At present, only MapMeasure.Kind.ZOOM_LEVEL is supported for visibility ranges.
        // Other kinds will be ignored.
        visibilityRanges.add(MapMeasureRange(MapMeasure.Kind.ZOOM_LEVEL, 1.0, 10.0))
        visibilityRanges.add(MapMeasureRange(MapMeasure.Kind.ZOOM_LEVEL, 11.0, 22.0))

        // Sets the visibility ranges for this map polyline based on zoom levels.
        // Each range is half-open: [minimumZoomLevel, maximumZoomLevel],
        // meaning the polyline is visible at minimumZoomLevel but not at maximumZoomLevel.
        // The polyline is rendered only when the map zoom level falls within any of the defined ranges.
        mapPolyline?.visibilityRanges = visibilityRanges
    }

    fun showMapArrow() {
        clearMap()
        // Move map to expected location.
        flyTo(BERLIN_GEO_COORDINATES)

        mapArrow = createMapArrow()
        mapScene!!.addMapArrow(mapArrow!!)
    }

    fun showMapPolygon() {
        clearMap()
        // Move map to expected location.
        flyTo(BERLIN_GEO_COORDINATES)

        mapPolygon = createPolygon()
        mapScene!!.addMapPolygon(mapPolygon!!)
    }

    fun showMapCircle() {
        clearMap()
        // Move map to expected location.
        flyTo(BERLIN_GEO_COORDINATES)

        mapCircle = createMapCircle()
        mapScene!!.addMapPolygon(mapCircle!!)
    }

    fun clearMapButtonClicked() {
        clearMap()
    }

    private fun createPolyline(): MapPolyline? {
        val coordinates = ArrayList<GeoCoordinates>()
        coordinates.add(GeoCoordinates(52.53032, 13.37409))
        coordinates.add(GeoCoordinates(52.5309, 13.3946))
        coordinates.add(GeoCoordinates(52.53894, 13.39194))
        coordinates.add(GeoCoordinates(52.54014, 13.37958))

        val geoPolyline: GeoPolyline
        try {
            geoPolyline = GeoPolyline(coordinates)
        } catch (e: InstantiationErrorException) {
            // Thrown when less than two vertices.
            return null
        }

        val widthInPixels = 20f
        val lineColor: Color = Color(0f, 0.56.toFloat(), 0.54.toFloat(), 0.63.toFloat())
        var mapPolyline: MapPolyline? = null
        try {
            mapPolyline = MapPolyline(
                geoPolyline, MapPolyline.SolidRepresentation(
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

        return mapPolyline
    }

    private fun createMapArrow(): MapArrow? {
        val coordinates = ArrayList<GeoCoordinates>()
        coordinates.add(GeoCoordinates(52.53032, 13.37409))
        coordinates.add(GeoCoordinates(52.5309, 13.3946))
        coordinates.add(GeoCoordinates(52.53894, 13.39194))
        coordinates.add(GeoCoordinates(52.54014, 13.37958))

        val geoPolyline: GeoPolyline
        try {
            geoPolyline = GeoPolyline(coordinates)
        } catch (e: InstantiationErrorException) {
            // Thrown when less than two vertices.
            return null
        }

        val widthInPixels = 20f
        val lineColor: Color = Color.valueOf(0f, 0.56f, 0.54f, 0.63f) // RGBA
        val mapArrow = MapArrow(geoPolyline, widthInPixels.toDouble(), lineColor)

        return mapArrow
    }

    private fun createPolygon(): MapPolygon? {
        val coordinates = ArrayList<GeoCoordinates>()
        // Note that a polygon requires a clockwise or counter-clockwise order of the coordinates.
        coordinates.add(GeoCoordinates(52.54014, 13.37958))
        coordinates.add(GeoCoordinates(52.53894, 13.39194))
        coordinates.add(GeoCoordinates(52.5309, 13.3946))
        coordinates.add(GeoCoordinates(52.53032, 13.37409))

        val geoPolygon: GeoPolygon
        try {
            geoPolygon = GeoPolygon(coordinates)
        } catch (e: InstantiationErrorException) {
            // Less than three vertices.
            return null
        }

        val fillColor: Color = Color.valueOf(0f, 0.56f, 0.54f, 0.63f) // RGBA
        val mapPolygon = MapPolygon(geoPolygon, fillColor)

        return mapPolygon
    }

    private fun createMapCircle(): MapPolygon {
        val radiusInMeters = 300f
        val geoCircle = GeoCircle(GeoCoordinates(52.51760485151816, 13.380312380535472), radiusInMeters.toDouble())

        val geoPolygon = GeoPolygon(geoCircle)
        val fillColor: Color = Color.valueOf(0f, 0.56f, 0.54f, 0.63f) // RGBA
        val mapPolygon = MapPolygon(geoPolygon, fillColor)

        return mapPolygon
    }

    private fun clearMap() {
        if (mapPolyline != null) {
            mapScene!!.removeMapPolyline(mapPolyline!!)
        }

        if (mapArrow != null) {
            mapScene!!.removeMapArrow(mapArrow!!)
        }

        if (mapPolygon != null) {
            mapScene!!.removeMapPolygon(mapPolygon!!)
        }

        if (mapCircle != null) {
            mapScene!!.removeMapPolygon(mapCircle!!)
        }
    }

    private fun flyTo(geoCoordinates: GeoCoordinates) {
        val geoCoordinatesUpdate = GeoCoordinatesUpdate(geoCoordinates)
        val distanceInMeters = (1000 * 8).toDouble()
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        val bowFactor = 1.0
        val animation = MapCameraAnimationFactory.flyTo(
            geoCoordinatesUpdate, mapMeasureZoom, bowFactor, Duration.ofSeconds(3)
        )
        mapCamera!!.startAnimation(animation)
    }
}