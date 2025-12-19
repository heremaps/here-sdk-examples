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

package com.here.sdk.units.compass

import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.here.sdk.animation.AnimationState
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoCoordinatesUpdate
import com.here.sdk.core.GeoOrientationUpdate
import com.here.sdk.mapview.MapCameraAnimation
import com.here.sdk.mapview.MapCameraAnimationFactory
import com.here.sdk.mapview.MapCameraListener
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapView
import com.here.time.Duration

data class CompassUiState(
    // Current rotation of the compass in degrees (clockwise).
    var rotationDegrees: Float = 0f
)

// The HERE SDK unit class that defines the logic for the view.
// The logic controls what to show.
class CompassUnit {

    internal var uiState by mutableStateOf(CompassUiState())
        private set

    private lateinit var mapView: MapView

    fun setUp(newMapView: MapView) {
        mapView = newMapView
        // When the rotation of the map changes, rotate the compass button accordingly.
        listenToRotationChanges(mapView)
    }

    /**
     * Animate the map back to North-Up (bearing = 0, tilt = 0) while
     * preserving current target and distance.
     */
    fun resetNorthUpWithAnimation() {
        val camera = mapView.camera
        val state = camera.state

        val currentLocation: GeoCoordinates = state.targetCoordinates
        val geoCoordinatesUpdate = GeoCoordinatesUpdate(currentLocation)

        val bearingInDegrees = 0.0
        val tiltInDegrees = 0.0
        val orientationUpdate = GeoOrientationUpdate(bearingInDegrees, tiltInDegrees)

        val currentDistanceInMeters = state.distanceToTargetInMeters
        val mapMeasureZoom = MapMeasure(
            MapMeasure.Kind.DISTANCE_IN_METERS,
            currentDistanceInMeters
        )

        val bowFactor = 1.0
        val animation: MapCameraAnimation = MapCameraAnimationFactory.flyTo(
            geoCoordinatesUpdate,
            orientationUpdate,
            mapMeasureZoom,
            bowFactor,
            Duration.ofSeconds(3)
        )

        camera.startAnimation(animation) { animationState ->
            if (animationState == AnimationState.COMPLETED ||
                animationState == AnimationState.CANCELLED
            ) {
                Log.d(TAG, "Reset North-Up animation finished with state: $animationState")
            }
        }
    }

    private val cameraListener = MapCameraListener { state ->
        // We rotate the compass in the opposite direction of the map.
        val bearingInDegrees = -state.orientationAtTarget.bearing
        rotateButton(bearingInDegrees)
    }

    private fun listenToRotationChanges(mapView: MapView) {
        mapView.camera.addListener(cameraListener)
    }

    // Rotate the button clockwise in degrees to indicate the current bearing.
    private fun rotateButton(bearingInDegrees: Double) {
        uiState = uiState.copy(rotationDegrees = bearingInDegrees.toFloat())
    }

    fun onDispose() {
        mapView.camera.removeListener(cameraListener)
    }

    companion object {
        private val TAG: String = CompassUnit::class.java.simpleName
    }
}
