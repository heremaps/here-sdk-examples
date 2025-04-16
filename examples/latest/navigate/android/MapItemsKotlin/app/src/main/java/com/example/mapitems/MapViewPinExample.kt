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
package com.example.mapitems

import android.content.Context;
import android.graphics.Color;
import android.util.Log;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoCoordinatesUpdate;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapView;
import com.here.time.Duration;

import java.util.ArrayList;

class MapViewPinExample(private val context: Context, private val mapView: MapView) {

    private val MAP_CENTER_GEO_COORDINATES: GeoCoordinates = GeoCoordinates(52.51760485151816, 13.380312380535472)
    private var mapCamera: MapCamera? = null

    init {
        mapCamera = mapView.camera
        val distanceToEarthInMeters = 7000.0
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceToEarthInMeters)
        mapCamera!!.lookAt(MAP_CENTER_GEO_COORDINATES, mapMeasureZoom)

        // Add circle to indicate map center.
        addCircle(MAP_CENTER_GEO_COORDINATES)

    }

    fun showMapViewPin() {
        // Move map to expected location.
        flyTo(MAP_CENTER_GEO_COORDINATES)

        val textView = TextView(context)
        textView.setTextColor(Color.parseColor("#FFFFFF"))
        textView.text = "Centered ViewPin"

        val linearLayout = LinearLayout(context)
        linearLayout.setBackgroundResource(R.color.colorAccent)
        linearLayout.setPadding(10, 10, 10, 10)
        linearLayout.addView(textView)
        linearLayout.setOnClickListener { Log.i(TAG, "Tapped on MapViewPin") }

        mapView.pinView(linearLayout, MAP_CENTER_GEO_COORDINATES)
    }

    fun showAnchoredMapViewPin() {
        // Move map to expected location.
        flyTo(MAP_CENTER_GEO_COORDINATES)

        val textView = TextView(context)
        textView.setTextColor(Color.parseColor("#FFFFFF"))
        textView.text = "Anchored MapViewPin"

        val linearLayout = LinearLayout(context)
        linearLayout.setBackgroundResource(R.color.colorPrimary)
        linearLayout.setPadding(10, 10, 10, 10)
        linearLayout.addView(textView)
        linearLayout.setOnClickListener { Log.i(TAG, "Tapped on Anchored MapViewPin") }

        val viewPin = mapView.pinView(linearLayout, MAP_CENTER_GEO_COORDINATES)
        viewPin!!.anchorPoint = Anchor2D(0.5, 1.0)
    }

    fun clearMap() {
        val mapViewPins = mapView.viewPins
        for (viewPin in ArrayList(mapViewPins)) {
            viewPin.unpin()
        }
    }

    private fun addCircle(geoCoordinates: GeoCoordinates) {
        val mapImage = MapImageFactory.fromResource(context.resources, R.drawable.circle)
        val mapMarker = MapMarker(geoCoordinates, mapImage)
        mapView.mapScene.addMapMarker(mapMarker)
    }

    private fun flyTo(geoCoordinates: GeoCoordinates) {
        val geoCoordinatesUpdate = GeoCoordinatesUpdate(geoCoordinates)
        val bowFactor = 1.0
        val animation =
            MapCameraAnimationFactory.flyTo(geoCoordinatesUpdate, bowFactor, Duration.ofSeconds(3))
        mapCamera!!.startAnimation(animation)
    }

    companion object {
        private val TAG: String = MapViewPinExample::class.java.name
    }
}