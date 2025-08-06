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

package com.here.camerakotlin

import android.app.AlertDialog
import android.content.Context
import android.util.Log
import android.widget.ImageView
import android.widget.Toast
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCircle
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoCoordinatesUpdate
import com.here.sdk.core.GeoOrientationUpdate
import com.here.sdk.core.GeoPolygon
import com.here.sdk.core.Point2D
import com.here.sdk.gestures.TapListener
import com.here.sdk.mapview.MapCamera
import com.here.sdk.mapview.MapCameraAnimationFactory
import com.here.sdk.mapview.MapCameraListener
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapPolygon
import com.here.sdk.mapview.MapView
import com.here.time.Duration

/**
 * This example shows how to use the Camera class to rotate and tilt the map programmatically, to set
 * a new transform center that influences those operations, and to move to a new location.
 * For more features of the Camera class, please consult the API Reference and the Developer's Guide.
 */
class CameraExample(private val context: Context, private val mapView: MapView) {

    var cameraTargetView: ImageView? = null
    private var poiMapCircle: MapPolygon? = null
    val camera: MapCamera = mapView.camera

    init {
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, CameraExample.DEFAULT_DISTANCE_TO_EARTH_IN_METERS.toDouble())
        camera.lookAt(GeoCoordinates(52.750731, 13.007375), mapMeasureZoom)

        // The POI MapCircle (green) indicates the next location to move to.
        updatePoiCircle(getRandomGeoCoordinates())

        addCameraObserver()
        setTapGestureHandler(mapView)

        showDialog("Note", "Tap the map to set a new transform center.")
    }

    fun rotateButtonClicked() {
        rotateMap(10)
    }

    fun tiltButtonClicked() {
        tiltMap(5)
    }

    fun moveToXYButtonClicked() {
        val geoCoordinates: GeoCoordinates = getRandomGeoCoordinates()
        updatePoiCircle(geoCoordinates)
        flyTo(geoCoordinates)
    }

    private fun flyTo(geoCoordinates: GeoCoordinates) {
        val geoCoordinatesUpdate = GeoCoordinatesUpdate(geoCoordinates)
        val bowFactor = 1.0
        val animation = MapCameraAnimationFactory.flyTo(geoCoordinatesUpdate, bowFactor, Duration.ofSeconds(3))
        camera.startAnimation(animation)
    }

    // Rotate the map by x degrees. Tip: Try to see what happens for negative values.
    private fun rotateMap(bearingStepInDegrees: Int) {
        val currentBearing: Double = camera.getState().orientationAtTarget.bearing
        val newBearing = currentBearing + bearingStepInDegrees

        //By default, bearing will be clamped to the range (0, 360].
        val orientationUpdate = GeoOrientationUpdate(newBearing, null)
        camera.setOrientationAtTarget(orientationUpdate)
    }

    // Tilt the map by x degrees.
    private fun tiltMap(tiltStepInDegrees: Int) {
        val currentTilt: Double = camera.getState().orientationAtTarget.tilt
        val newTilt = currentTilt + tiltStepInDegrees

        //By default, tilt will be clamped to the range [0, 70].
        val orientationUpdate = GeoOrientationUpdate(null, newTilt)
        camera.setOrientationAtTarget(orientationUpdate)
    }

    private fun setTapGestureHandler(mapView: MapView) {
        mapView.gestures.tapListener =
            TapListener { mapViewTouchPointInPixels: Point2D -> this.setTransformCenter(mapViewTouchPointInPixels) }
    }

    // The new transform center will be used for all programmatical map transformations
    // and determines where the target is located in the view.
    // By default, the target point is located at the center of the view.
    // Note: Gestures are not affected, for example, the pinch-rotate gesture and
    // the two-finger-pan (=> tilt) will work like before.
    private fun setTransformCenter(mapViewTouchPointInPixels: Point2D) {
        // Note that this moves the current camera's target at the locatiion where you tapped the screen.
        // Effectively, you move the map by changing the camera's target.
        camera.setPrincipalPoint(mapViewTouchPointInPixels)

        // Reposition circle view on screen to indicate the new target.
        cameraTargetView!!.x = mapViewTouchPointInPixels.x.toFloat() - cameraTargetView!!.width / 2
        cameraTargetView!!.y = mapViewTouchPointInPixels.y.toFloat() - cameraTargetView!!.height / 2

        Toast.makeText(
            context, "New transform center: " +
                    mapViewTouchPointInPixels.x + ", " +
                    mapViewTouchPointInPixels.y, Toast.LENGTH_SHORT
        ).show()
    }

    private fun updatePoiCircle(geoCoordinates: GeoCoordinates) {
        if (poiMapCircle != null) {
            mapView.mapScene.removeMapPolygon(poiMapCircle!!)
        }
        poiMapCircle = createMapCircle(geoCoordinates)
        mapView.mapScene.addMapPolygon(poiMapCircle!!)
    }

    private fun createMapCircle(geoCoordinates: GeoCoordinates): MapPolygon {
        val radiusInMeters = 300f
        val geoCircle = GeoCircle(geoCoordinates, radiusInMeters.toDouble())

        val geoPolygon = GeoPolygon(geoCircle)
        val fillColor = Color.valueOf(0f, 1f, 0f, 1f) // RGBA
        val mapPolygon = MapPolygon(geoPolygon, fillColor)

        return mapPolygon
    }

    private fun getRandomGeoCoordinates(): GeoCoordinates {
        val currentTarget = camera.state.targetCoordinates
        val amount = 0.05
        val latitude = getRandom(currentTarget.latitude - amount, currentTarget.latitude + amount)
        val longitude = getRandom(currentTarget.longitude - amount, currentTarget.longitude + amount)
        return GeoCoordinates(latitude, longitude)
    }
    private fun getRandom(min: Double, max: Double): Double {
        return min + Math.random() * (max - min)
    }

    private val cameraListener = MapCameraListener { state ->
        val camTarget = state.targetCoordinates
        Log.d(
            "CameraListener", "New camera target: " +
                    camTarget.latitude + ", " + camTarget.longitude
        )
    }

    private fun addCameraObserver() {
        mapView.camera.addListener(cameraListener)
    }

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder = AlertDialog.Builder(context)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }

    companion object {
        private val TAG: String = CameraExample::class.java.name
        private const val DEFAULT_DISTANCE_TO_EARTH_IN_METERS = 8000f
    }
}
