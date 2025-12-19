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

package com.here.sdk.units.mapruler

import androidx.annotation.NonNull
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.Point2D
import com.here.sdk.mapview.MapCamera
import com.here.sdk.mapview.MapCameraListener
import com.here.sdk.mapview.MapView

data class MapScaleUiState(
    var scaleText: String = ""
)

// The HERE SDK unit class that defines the logic for the view.
// The logic controls what to show.
// Note: setUp() must be called to initialize the unit with a MapView instance.
class MapScaleUnit {

    internal var uiState by mutableStateOf(MapScaleUiState())
        private set

    private lateinit var mapView: MapView

    enum class DistanceUnitSystem {
        METRIC,      // m / km
        IMPERIAL_US, // ft / mi
        IMPERIAL_UK  // yd / mi
    }

    // The length of the scale bar in pixels is important to calculate the distance it represents.
    private var scaleBarWidthPx: Double = 200.0

    // Current unit system (default: metric).
    private var distanceUnitSystem: DistanceUnitSystem = DistanceUnitSystem.METRIC

    fun setDistanceUnitSystem(system: DistanceUnitSystem) {
        distanceUnitSystem = system
        updateScale()
    }

    fun setScaleBarWidthPx(widthPx: Double) {
        scaleBarWidthPx = widthPx
        updateScale()
    }

    fun setUp(newMapView: MapView) {
        mapView = newMapView
        setupCameraListener()
    }

    private val cameraListener = object : MapCameraListener {
        override fun onMapCameraUpdated(@NonNull state: MapCamera.State) {
            updateScale()
        }
    }

    private fun setupCameraListener() {
        mapView.camera.addListener(cameraListener)
    }

    private fun updateScale() {
        val pxCenter = Point2D(
            mapView.width / 2.0,
            mapView.height / 2.0
        )
        val pxRight = Point2D(
            (mapView.width / 2.0) + scaleBarWidthPx,
            mapView.height / 2.0
        )

        val geoCenter: GeoCoordinates? = mapView.viewToGeoCoordinates(pxCenter)
        val geoRight: GeoCoordinates? = mapView.viewToGeoCoordinates(pxRight)

        if (geoCenter == null || geoRight == null) return

        val meters = geoCenter.distanceTo(geoRight)
        val scaleStr = formatDistance(meters, distanceUnitSystem)

        updateTextOnView(scaleStr)
    }

    private fun updateTextOnView(value: String) {
        uiState = uiState.copy(scaleText = value)
    }

    fun formatDistance(
        meters: Double,
        system: DistanceUnitSystem
    ): String {
        return when (system) {
            DistanceUnitSystem.METRIC -> {
                // < 1000 m => meters, otherwise km.
                if (meters < 1000.0) {
                    String.format("%.0f m", meters)
                } else {
                    val km = meters / 1000.0
                    String.format("%.1f km", km)
                }
            }

            DistanceUnitSystem.IMPERIAL_US -> {
                // < ~0.2 mi => feet, otherwise miles.
                val feet = meters * 3.28084
                val miles = meters / 1609.344
                if (miles < 0.2) {
                    String.format("%.0f ft", feet)
                } else {
                    String.format("%.1f mi", miles)
                }
            }

            DistanceUnitSystem.IMPERIAL_UK -> {
                // < 1 mi => yards, otherwise miles.
                val yards = meters * 1.09361
                val miles = meters / 1609.344
                if (miles < 1.0) {
                    String.format("%.0f yd", yards)
                } else {
                    String.format("%.1f mi", miles)
                }
            }
        }
    }

    fun onDispose() {
        mapView.camera.removeListener(cameraListener)
    }
}
