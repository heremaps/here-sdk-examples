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

package com.here.custommapstyleskotlin

import android.app.AlertDialog
import android.content.Context
import android.util.Log
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView
import java.io.IOException

class CustomMapStylesExample(private val context: Context, private val mapView: MapView) {

    fun onMapSceneLoaded() {
        val camera = mapView.camera
        val mapMeasureZoom = MapMeasure(
            MapMeasure.Kind.DISTANCE_IN_METERS,
            DEFAULT_DISTANCE_TO_EARTH_IN_METERS.toDouble()
        )
        camera.lookAt(GeoCoordinates(52.530932, 13.384915), mapMeasureZoom)
    }

    fun loadButtonClicked() {
        loadMapStyle()
    }

    private fun loadMapStyle() {
        // Place the style into the "assets" directory.
        // Full path example: app/src/main/assets/mymapstyle.zip .
        // Note: The file can also be a JSON file when using HERE Style Editor < v1.13.0.
        // Adjust file name, type and path as appropriate for your project.
        val fileName = "custom-dark-style-neon-rds.zip"
        val assetManager = context.assets
        try {
            assetManager.open(fileName)
        } catch (e: IOException) {
            Log.e(TAG, "Error: Map style not found!")
            return
        }

        mapView.mapScene.loadScene("" + fileName) { mapError ->
            if (mapError == null) {
                // Scene loaded.
            } else {
                Log.d(TAG, "onLoadScene failed: $mapError")
            }
        }
    }

    fun unloadButtonClicked() {
        mapView.mapScene.loadScene(MapScheme.NORMAL_DAY) { mapError ->
            if (mapError == null) {
                // Scene loaded.
            } else {
                Log.d(TAG, "onLoadScene failed: $mapError")
            }
        }
    }

    companion object {
        private val TAG: String = CustomMapStylesExample::class.java.name
        private val DEFAULT_DISTANCE_TO_EARTH_IN_METERS: Float = (200 * 1000).toFloat()
    }
}
