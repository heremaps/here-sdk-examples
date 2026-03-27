/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
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

package com.here.hellomapandroidautokotlin

import android.util.Log
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.core.graphics.drawable.IconCompat
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.Point2D
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapSurface

/**
 * A screen that shows a HERE SDK map view - when connected to a DHU or an in-car head unit.
 *
 *
 * See [HelloMapCarAppService] for the app's entry point to the car host.
 */
class HelloMapScreen(private val carContext: CarContext) : Screen(carContext), SurfaceCallback {
    private val mapSurface: MapSurface

    init {
        Log.d(TAG, "Register surface callback")
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(this)

        // Since the MapSurface implements MapViewBase, it behaves like a MapView, except that it
        // renders on the DHU running Android Auto.
        mapSurface = MapSurface()
    }

    override fun onGetTemplate(): Template {
        val zoomInIcon = CarIcon.Builder(
            IconCompat.createWithResource(carContext, R.drawable.plus)
        ).build()
        val zoomOutIcon = CarIcon.Builder(
            IconCompat.createWithResource(carContext, R.drawable.minus)
        ).build()

        // Add buttons to zoom in/out the map view and to exit the app.
        val actionStripBuilder = ActionStrip.Builder()
        actionStripBuilder.addAction(
            Action.Builder()
                .setIcon(zoomInIcon)
                .setOnClickListener { this.zoomIn() }
                .build())
        actionStripBuilder.addAction(
            Action.Builder()
                .setIcon(zoomOutIcon)
                .setOnClickListener { this.zoomOut() }
                .build())
        actionStripBuilder.addAction(
            Action.Builder()
                .setTitle("Exit")
                .setOnClickListener { this.exit() }
                .build())

        val builder = NavigationTemplate.Builder()
        builder.setActionStrip(actionStripBuilder.build())

        builder.setMapActionStrip(
            ActionStrip.Builder()
                .addAction( // Must be present (even on a car with touch screen) to enable PAN mode. PAN
                    // mode is required to enable reception of gestures.
                    Action.Builder(Action.PAN).build()
                ).build()
        )

        return builder.build()
    }

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        Log.d(TAG, "Received a surface.")

        mapSurface.attachSurface(
            carContext,
            surfaceContainer.surface,
            surfaceContainer.width,
            surfaceContainer.height
        )

        mapSurface.mapScene.loadScene(
            MapScheme.NORMAL_DAY
        ) { mapError ->
            mapError?.let {
                Log.d(TAG, "Loading map failed: mapError: ${mapError.name}")
                return@loadScene
            }
            val distanceInMeters = (1000 * 10).toDouble()
            val mapMeasureZoom =
                MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
            mapSurface.camera.lookAt(GeoCoordinates(52.530932, 13.384915), mapMeasureZoom)
        }
    }

    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) {
        mapSurface.destroySurface()
    }

    private fun zoomIn() {
        val zoomFactor = 2.0
        mapSurface.camera.zoomBy(zoomFactor, centerPoint)
    }

    private fun zoomOut() {
        val zoomFactor = 0.5
        mapSurface.camera.zoomBy(zoomFactor, centerPoint)
    }

    private fun exit() {
        carContext.finishCarApp()
    }

    private val centerPoint: Point2D
        get() {
            val viewport = mapSurface.viewportSize
            return Point2D(viewport.width * 0.5, viewport.height * 0.5)
        }

    /**
     * Will be called on scroll event. Needs car api version 2 to work.
     * See [SurfaceCallback.onScroll] definition for more details.
     */
    override fun onScroll(distanceX: Float, distanceY: Float) {
        mapSurface.gestures.scrollHandler.onScroll(distanceX, distanceY)
    }

    /**
     * Will be called on scale event. Needs car api version 2 to work.
     * See [SurfaceCallback.onScale] definition for more details.
     */
    override fun onScale(focusX: Float, focusY: Float, scaleFactor: Float) {
        mapSurface.gestures.scaleHandler.onScale(focusX, focusY, scaleFactor)
    }

    /**
     * Will be called on scale event. Needs car api version 2 to work.
     * See [SurfaceCallback.onFling] definition for more details.
     */
    override fun onFling(velocityX: Float, velocityY: Float) {
        /**
         *
         * Fling event appears to have inverted axis compared to scroll event on desktop head unit.
         * This should not be the case according to
         * [androidx.car.app.navigation.model.NavigationTemplate]. To compensate inverted axis
         * , factor of -1 was introduced. This might differ depending on which head unit model is
         * used.
         */
        mapSurface.gestures.flingHandler.onFling(-1 * velocityX, -1 * velocityY)
    }

    companion object {
        private val TAG: String = HelloMapScreen::class.java.simpleName
    }
}

