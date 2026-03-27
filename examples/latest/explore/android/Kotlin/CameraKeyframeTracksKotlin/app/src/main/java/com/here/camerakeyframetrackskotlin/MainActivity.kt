/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

package com.here.camerakeyframetrackskotlin

import android.content.Context
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.here.camerakeyframetrackskotlin.ui.theme.CameraKeyframeTracksTheme
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.engine.*
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView
import com.here.sdk.units.core.utils.EnvironmentLogger
import com.here.sdk.units.core.utils.PermissionsRequestor

class MainActivity: ComponentActivity() {

    private val environmentLogger = EnvironmentLogger()
    private lateinit var permissionsRequestor: PermissionsRequestor
    private var mapView: MapView? = null
    private lateinit var cameraKeyframeTracksExample: CameraKeyframeTracksExample
    private lateinit var routeAnimationExample: RouteAnimationExample

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Needs to be called before the activity is started.
        permissionsRequestor = PermissionsRequestor(this)

        // Log application and device details.
        // It expects a string parameter that describes the application source language.
        environmentLogger.logEnvironment("Kotlin")

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK()

        enableEdgeToEdge()

        setContent {
            CameraKeyframeTracksTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize()
                ) { paddingValues ->
                    Box(modifier = Modifier.padding(paddingValues)) {
                        HereMapView(savedInstanceState)
                        CustomDropDownMenu()
                    }
                }
            }
        }
    }

    // Wrap the MapView into a Composable in order to use it with Jetpack Compose.
    @Composable
    private fun HereMapView(savedInstanceState: Bundle?) {
        AndroidView(factory = { context ->
            MapView(context).apply {
                mapView = this
                mapView?.onCreate(savedInstanceState)

                // Note that for this app handling of permissions is optional as no sensitive permissions
                // are required.
                // Only after permissions have been granted (if any), we load the map view and start the app.
                handleAndroidPermissions()
            }
        })
    }

    private fun loadMapScene() {
        val mapViewNonNull = mapView ?: return logError("mapView is null. Cannot load map scene.")

        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapViewNonNull.mapScene.loadScene(MapScheme.NORMAL_DAY) { mapError ->
            if (mapError == null) {
                val distanceInMeters = (1000 * 10).toDouble()
                val mapMeasureZoom =
                    MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
                mapViewNonNull.camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)

                cameraKeyframeTracksExample = CameraKeyframeTracksExample(mapViewNonNull)
                routeAnimationExample = RouteAnimationExample(mapViewNonNull)
            } else {
                Log.d(TAG, "Loading map failed: mapError: ${mapError.name}")
            }
        }
    }

    @Composable
    fun CustomDropDownMenu() {
        DropdownMenu(
            onAnimateToRouteClick = { item ->
                when (item) {
                    "Start Route Animation" -> routeAnimationExample.animateToRoute()
                    "Stop Route Animation" -> routeAnimationExample.stopRouteAnimation()
                }
            },
            onTripToNycClick = { item ->
                when (item) {
                    "Start NYC Animation" -> cameraKeyframeTracksExample.startTripToNYC()
                    "Stop NYC Animation" -> cameraKeyframeTracksExample.stopTripToNYCAnimation()
                }

            }
        )
    }

    private fun initializeHERESDK() {
        // Set your credentials for the HERE SDK.
        val accessKeyID = "YOUR_ACCESS_KEY_ID"
        val accessKeySecret = "YOUR_ACCESS_KEY_SECRET"
        val authenticationMode = AuthenticationMode.withKeySecret(accessKeyID, accessKeySecret)
        val options = SDKOptions(authenticationMode)
        try {
            val context: Context = this
            SDKNativeEngine.makeSharedInstance(context, options)
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of HERE SDK failed: ${e.error.name}")
        }
    }

    // Convenience method to check all permissions that have been added to the AndroidManifest.
    private fun handleAndroidPermissions() {
        permissionsRequestor.request(object :
            PermissionsRequestor.ResultListener {
            override fun permissionsGranted() {
                loadMapScene()
            }

            override fun permissionsDenied() {
                Log.e(TAG, "Permissions denied by user.")
            }
        })
    }

    override fun onDestroy() {
        disposeHERESDK()
        super.onDestroy()
    }

    private fun disposeHERESDK() {
        // Free HERE SDK resources before the application shuts down.
        // Usually, this should be called only on application termination.
        // Afterwards, the HERE SDK is no longer usable unless it is initialized again.
        val sdkNativeEngine = SDKNativeEngine.getSharedInstance()
        if (sdkNativeEngine != null) {
            sdkNativeEngine.dispose()
            // For safety reasons, we explicitly set the shared instance to null to avoid situations,
            // where a disposed instance is accidentally reused.
            SDKNativeEngine.setSharedInstance(null)
        }
    }

    private fun logError(error: String) {
        Log.e(TAG, error)
    }

    companion object {
        private val TAG: String = MainActivity::class.java.simpleName
    }
}
