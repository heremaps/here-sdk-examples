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
package com.here.navigationquickstartkotlin

import android.app.AlertDialog
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
import com.here.navigationquickstartkotlin.ui.theme.NavigationQuickStartTheme
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.LocationListener
import com.here.sdk.core.engine.AuthenticationMode
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.engine.SDKOptions
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView
import com.here.sdk.navigation.EventText
import com.here.sdk.navigation.EventTextListener
import com.here.sdk.navigation.LocationSimulator
import com.here.sdk.navigation.LocationSimulatorOptions
import com.here.sdk.navigation.VisualNavigator
import com.here.sdk.routing.CarOptions
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingEngine
import com.here.sdk.routing.RoutingError
import com.here.sdk.routing.Waypoint
import java.util.Arrays

class MainActivity : ComponentActivity() {
    private var permissionsRequestor: PermissionsRequestor? = null
    private var mapView: MapView? = null

    private var routingEngine: RoutingEngine? = null
    private var visualNavigator: VisualNavigator? = null
    private var locationSimulator: LocationSimulator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Needs to be called before the activity is started.
        permissionsRequestor = PermissionsRequestor(this)

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        // Before creating a MapView instance please make sure that the HERE SDK is initialized.
        initializeHERESDK()

        enableEdgeToEdge()

        setContent {
            NavigationQuickStartTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize()
                ) { paddingValues ->
                    Box(modifier = Modifier.padding(paddingValues)) {
                        HereMapView(savedInstanceState)
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
        permissionsRequestor?.requestPermissionsFromManifest(
            object : PermissionsRequestor.ResultListener {
                override fun permissionsGranted() {
                    loadMapScene()
                }

                override fun permissionsDenied(deniedPermissions: List<String>) {
                    Log.e(TAG, "Permissions denied by the user.")
                }
            }
        )
    }

    private fun loadMapScene() {
        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapView!!.mapScene.loadScene(MapScheme.NORMAL_DAY) { mapError ->
            if (mapError == null) {
                val distanceInMeters = (1000 * 10).toDouble()
                val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
                mapView!!.camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)
                startGuidanceExample()
            } else {
                Log.d(TAG, "Loading map failed: mapError: " + mapError.name)
            }
        }
    }

    private fun startGuidanceExample() {
        showDialog(
            "Navigation Quick Start",
            "This app routes to the HERE office in Berlin. See logs for guidance information."
        )

        // We start by calculating a car route.
        calculateRoute()
    }

    private fun calculateRoute() {
        try {
            routingEngine = RoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of RoutingEngine failed: " + e.error.name)
        }

        val startWaypoint = Waypoint(GeoCoordinates(52.520798, 13.409408))
        val destinationWaypoint = Waypoint(GeoCoordinates(52.530905, 13.385007))

        routingEngine!!.calculateRoute(
            ArrayList(Arrays.asList(startWaypoint, destinationWaypoint)),
            CarOptions()
        ) { routingError: RoutingError?, routes: List<Route?>? ->
            if (routingError == null) {
                val route = routes!![0]
                startGuidance(route)
            } else {
                Log.e("Route calculation error", routingError.toString())
            }
        }
    }

    private fun startGuidance(route: Route?) {
        try {
            // Without a route set, this starts tracking mode.
            visualNavigator = VisualNavigator()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of VisualNavigator failed: " + e.error.name)
        }

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator!!.startRendering(mapView!!)

        // Hook in one of the many listeners. Here we set up a listener to get instructions on the maneuvers to take while driving.
        // For more details, please check the "Navigation" example app and the Developer's Guide.
        visualNavigator!!.eventTextListener = EventTextListener { eventText: EventText -> Log.d("Maneuver text", eventText.text) }

        // Set a route to follow. This leaves tracking mode.
        visualNavigator!!.route = route

        // VisualNavigator acts as LocationListener to receive location updates directly from a location provider.
        // Any progress along the route is a result of getting a new location fed into the VisualNavigator.
        setupLocationSource(visualNavigator!!, route)
    }

    private fun setupLocationSource(locationListener: LocationListener, route: Route?) {
        try {
            // Provides fake GPS signals based on the route geometry.
            locationSimulator = LocationSimulator(route!!, LocationSimulatorOptions())
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of LocationSimulator failed: " + e.error.name)
        }

        locationSimulator!!.listener = locationListener
        locationSimulator!!.start()
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
    }
}