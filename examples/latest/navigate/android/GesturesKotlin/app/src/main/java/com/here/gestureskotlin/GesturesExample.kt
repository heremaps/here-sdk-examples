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
package com.here.gestureskotlin

import android.content.Context
import android.util.Log
import android.widget.Toast
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.gestures.DoubleTapListener
import com.here.sdk.gestures.GestureState
import com.here.sdk.gestures.GestureType
import com.here.sdk.gestures.LongPressListener
import com.here.sdk.gestures.TapListener
import com.here.sdk.gestures.TwoFingerTapListener
import com.here.sdk.mapview.MapCamera
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapView

class GesturesExample(private val context: Context, private val mapView: MapView) {

    private var gestureMapAnimator: GestureMapAnimator? = null

    init {
        val camera: MapCamera = mapView.camera
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, GesturesExample.DEFAULT_DISTANCE_TO_EARTH_IN_METERS.toDouble())
        camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)

        gestureMapAnimator = GestureMapAnimator(mapView.camera)

        setTapGestureHandler(mapView)
        setDoubleTapGestureHandler(mapView)
        setTwoFingerTapGestureHandler(mapView)
        setLongPressGestureHandler(mapView)


        // Disable the default map gesture behavior for DoubleTap (zooms in) and TwoFingerTap (zooms out)
        // as we want to enable custom map animations when such gestures are detected.
        mapView.gestures.disableDefaultAction(GestureType.DOUBLE_TAP)
        mapView.gestures.disableDefaultAction(GestureType.TWO_FINGER_TAP)

        Toast.makeText(
            context, "Shows Tap and LongPress gesture handling. " +
                    "See log for details. DoubleTap / TwoFingerTap map action (zoom in/out) is disabled " +
                    "and replaced with a custom animation.", Toast.LENGTH_LONG
        ).show()
    }

    private fun setTapGestureHandler(mapView: MapView) {
        mapView.gestures.tapListener = TapListener { touchPoint ->
            val geoCoordinates = mapView.viewToGeoCoordinates(touchPoint)
            Log.d(TAG, "Tap at: $geoCoordinates")
        }
    }

    private fun setDoubleTapGestureHandler(mapView: MapView) {
        mapView.gestures.doubleTapListener = DoubleTapListener { touchPoint ->
            val geoCoordinates = mapView.viewToGeoCoordinates(touchPoint)
            Log.d(TAG, "Default zooming in is disabled. DoubleTap at: $geoCoordinates")

            // Start our custom zoom in animation.
            gestureMapAnimator?.zoomIn(touchPoint)
        }
    }

    private fun setTwoFingerTapGestureHandler(mapView: MapView) {
        mapView.gestures.twoFingerTapListener = TwoFingerTapListener { touchCenterPoint ->
            val geoCoordinates = mapView.viewToGeoCoordinates(touchCenterPoint)
            Log.d(TAG, "Default zooming in is disabled. TwoFingerTap at: $geoCoordinates")

            // Start our custom zoom out animation.
            gestureMapAnimator?.zoomOut(touchCenterPoint)
        }
    }

    private fun setLongPressGestureHandler(mapView: MapView) {
        mapView.gestures.longPressListener = LongPressListener { gestureState, touchPoint ->
            val geoCoordinates = mapView.viewToGeoCoordinates(touchPoint)
            if (gestureState == GestureState.BEGIN) {
                Log.d(TAG, "LongPress detected at: $geoCoordinates")
            }

            if (gestureState == GestureState.UPDATE) {
                Log.d(TAG, "LongPress update at: $geoCoordinates")
            }

            if (gestureState == GestureState.END) {
                Log.d(TAG, "LongPress finger lifted at: $geoCoordinates")
            }
            if (gestureState == GestureState.CANCEL) {
                Log.d(TAG, "Map view lost focus. Maybe a modal dialog is shown or the app is sent to background.")
            }
        }
    }

    // This is just an example how to clean up.
    @Suppress("unused")
    private fun removeGestureHandler(mapView: MapView) {
        // Stop listening.
        mapView.gestures.tapListener = null
        mapView.gestures.doubleTapListener = null
        mapView.gestures.twoFingerTapListener = null
        mapView.gestures.longPressListener = null

        // Bring back the default map gesture behavior for DoubleTap (zooms in)
        // and TwoFingerTap (zooms out). These actions were disabled above.
        mapView.gestures.enableDefaultAction(GestureType.DOUBLE_TAP)
        mapView.gestures.enableDefaultAction(GestureType.TWO_FINGER_TAP)
    }

    companion object {
        private val TAG: String = GesturesExample::class.java.name
        private const val DEFAULT_DISTANCE_TO_EARTH_IN_METERS = 1000 * 10
    }
}