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
package com.here.navigationwarnerskotlin

import android.app.AlertDialog
import android.content.Context
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.here.navigationwarnerskotlin.ui.theme.NavigationWarnersTheme
import com.here.sdk.core.Anchor2D
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.Point2D
import com.here.sdk.core.engine.*
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.gestures.GestureState
import com.here.sdk.gestures.LongPressListener
import com.here.sdk.mapview.MapImageFactory
import com.here.sdk.mapview.MapMarker
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView
import com.here.sdk.units.core.utils.EnvironmentLogger
import com.here.sdk.units.core.utils.PermissionsRequestor

class MainActivity : ComponentActivity() {

    private val environmentLogger = EnvironmentLogger()
    private lateinit var permissionsRequestor: PermissionsRequestor
    private var mapView: MapView? = null

    private var navigationWarnersExample: NavigationWarnersExample? = null
    private var changeDestination: Boolean = false
    private var startGeoCoordinates: GeoCoordinates? = null
    private var destinationGeoCoordinates: GeoCoordinates? = null
    private var startMapMarker: MapMarker? = null
    private var destinationMapMarker: MapMarker? = null
    private var guidanceButtonLabel by mutableStateOf(START_GUIDANCE_BUTTON_LABEL)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Needs to be called before the activity is started.

        // Log application and device details.
        // It expects a string parameter that describes the application source language.
        environmentLogger.logEnvironment("Kotlin")
        permissionsRequestor = PermissionsRequestor(this)

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        // Before creating a MapView instance please make sure that the HERE SDK is initialized.
        initializeHERESDK()

        enableEdgeToEdge()

        setContent {
            NavigationWarnersTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize()
                ) { paddingValues ->
                    Box(modifier = Modifier.padding(paddingValues)) {
                        HereMapView(savedInstanceState)
                        StartGuidanceButton()
                    }
                }
            }
        }

        showDialog(
            "Navigation Warners",
            "This app routes to the HERE office in Berlin and logs various TBT events."
        )

        showDialog(
            "Note", "Do a long press to change start and destination coordinates. " +
                    "Map icons are pickable."
        )

        startGeoCoordinates = GeoCoordinates(52.520798, 13.409408)
        destinationGeoCoordinates = GeoCoordinates(52.530905, 13.385007)
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

    private fun setLongPressGestureHandler() {
        mapView!!.gestures.longPressListener =
            LongPressListener { gestureState: GestureState, touchPoint: Point2D? ->
                val geoCoordinates = mapView!!.viewToGeoCoordinates(
                    touchPoint!!
                )
                if (geoCoordinates == null) {
                    showDialog("Note", "Invalid GeoCoordinates.")
                    return@LongPressListener
                }
                if (gestureState == GestureState.BEGIN) {
                    // Set new route start or destination geographic coordinates based on long press location.
                    if (changeDestination) {
                        destinationGeoCoordinates = geoCoordinates
                        destinationMapMarker!!.coordinates = geoCoordinates
                    } else {
                        startGeoCoordinates = geoCoordinates
                        startMapMarker!!.coordinates = geoCoordinates
                    }
                    // Toggle the marker that should be updated on next long press.
                    changeDestination = !changeDestination
                }
            }
    }

    private fun addMapMarker(geoCoordinates: GeoCoordinates, resourceId: Int): MapMarker {
        val mapImage = MapImageFactory.fromResource(this.resources, resourceId)
        val anchor2D = Anchor2D(0.5, 1.0)
        val mapMarker = MapMarker(geoCoordinates, mapImage, anchor2D)
        mapView!!.mapScene.addMapMarker(mapMarker)
        return mapMarker
    }

    @Composable
    fun StartGuidanceButton() {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.Bottom,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            CustomButton(
                onClick = {
                    onStartGuidanceClicked()
                },
                text = guidanceButtonLabel
            )
        }
    }

    @Composable
    fun CustomButton(onClick: () -> Unit, text: String) {
        Button(
            onClick = onClick,
            colors = ButtonDefaults.buttonColors(
                containerColor = Color(0xFF005CB9)
            )
        ) {
            Text(text)
        }
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
            throw RuntimeException("Initialization of HERE SDK failed: " + e.error.name)
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

    private fun loadMapScene() {
        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapView!!.mapScene.loadScene(MapScheme.NORMAL_DAY) { mapError ->
            if (mapError == null) {
                val distanceInMeters = (1000 * 10).toDouble()
                val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
                mapView!!.camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)

                startMapMarker = addMapMarker(startGeoCoordinates!!, com.here.sdk.units.core.R.drawable.poi_start)
                destinationMapMarker = addMapMarker(destinationGeoCoordinates!!, com.here.sdk.units.core.R.drawable.poi_destination)
                navigationWarnersExample = NavigationWarnersExample(this, mapView!!)
                setLongPressGestureHandler()
            } else {
                Log.d(TAG, "Loading map failed: mapError: " + mapError.name)
            }
        }
    }

    private fun onStartGuidanceClicked() {
        val warnersExample = navigationWarnersExample ?: return
        if (warnersExample.isGuidanceRunning()) {
            warnersExample.stopGuidance()
            warnersExample.animateToRoutePreview(startGeoCoordinates!!, destinationGeoCoordinates!!)
            guidanceButtonLabel = START_GUIDANCE_BUTTON_LABEL
        } else {
            warnersExample.startGuidance(startGeoCoordinates!!, destinationGeoCoordinates!!)
            guidanceButtonLabel = STOP_GUIDANCE_BUTTON_LABEL
        }
    }

    override fun onPause() {
        mapView?.onPause()
        super.onPause()
    }

    override fun onResume() {
        mapView?.onResume()
        super.onResume()
    }

    override fun onDestroy() {
        navigationWarnersExample?.stopGuidance()
        mapView?.onDestroy()
        super.onDestroy()
        if (isFinishing) {
            disposeHERESDK()
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        mapView!!.onSaveInstanceState(outState)
        super.onSaveInstanceState(outState)
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

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder = AlertDialog.Builder(this)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }

    companion object {
        private val TAG: String = MainActivity::class.java.simpleName
        private const val START_GUIDANCE_BUTTON_LABEL = "Start Guidance"
        private const val STOP_GUIDANCE_BUTTON_LABEL = "Stop Guidance"
    }
}
