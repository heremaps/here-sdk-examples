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
package com.here.mapitemskotlin

import android.os.Bundle
import android.util.Log
import android.widget.Toast
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
import com.here.mapitemskotlin.ui.theme.MapItemsTheme
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.engine.AuthenticationMode
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.engine.SDKOptions
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView

class MainActivity : ComponentActivity() {

    private var permissionsRequestor: PermissionsRequestor? = null
    private var mapView: MapView? = null
    private var mapItemsExample: MapItemsExample? = null
    private var mapObjectsExample: MapObjectsExample? = null
    private var mapViewPinExample: MapViewPinExample? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Needs to be called before the activity is started.
        permissionsRequestor = PermissionsRequestor(this)

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        // Before creating a MapView instance please make sure that the HERE SDK is initialized.
        initializeHERESDK()

        enableEdgeToEdge()

        setContent {
            MapItemsTheme {
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

    private fun initializeHERESDK() {
        // Set your credentials for the HERE SDK.
        val accessKeyID = "YOUR_ACCESS_KEY_ID"
        val accessKeySecret = "YOUR_ACCESS_KEY_SECRET"
        val authenticationMode = AuthenticationMode.withKeySecret(accessKeyID, accessKeySecret)
        val options = SDKOptions(authenticationMode)
        try {
            val context = this
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
        val mapViewNonNull = mapView ?: run {
            Log.e(TAG, "mapView is null. Cannot load map scene.")
            return
        }

        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapViewNonNull.mapScene.loadScene(MapScheme.NORMAL_DAY) { mapError ->
            if (mapError == null) {
                mapObjectsExample = MapObjectsExample(mapViewNonNull)
                mapItemsExample = MapItemsExample(this@MainActivity, mapViewNonNull)
                mapViewPinExample = MapViewPinExample(this@MainActivity, mapViewNonNull)

                val distanceInMeters = (1000 * 20).toDouble()
                val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
                mapViewNonNull.camera.lookAt(GeoCoordinates(52.51760485151816, 13.380312380535472), mapMeasureZoom)
            } else {
                Log.d(TAG, "Loading of map failed: mapError: ${mapError.name}")
            }
        }
    }

    @Composable
    fun CustomDropDownMenu() {
        DropdownMenu(
            onMapObjectClick = { item ->
                when (item) {
                    "Polyline" -> mapObjectsExample?.showMapPolyline()
                    "Arrow" -> mapObjectsExample?.showMapArrow()
                    "Polygon" -> mapObjectsExample?.showMapPolygon()
                    "Circle" -> mapObjectsExample?.showMapCircle()
                    "Enable visibility ranges" -> {
                        Toast.makeText(
                            this,
                            "Enabled visibility ranges for MapPolyLine",
                            Toast.LENGTH_SHORT
                        ).show()
                        mapObjectsExample?.enableVisibilityRangesForPolyline()
                    }
                    "Clear Items" -> mapObjectsExample?.clearMapButtonClicked()
                }
            },
            onMapMarkerClick = { item ->
                when (item) {
                    "Anchored (2D)" -> mapItemsExample?.showAnchoredMapMarkers()
                    "Centered (2D)" -> mapItemsExample?.showCenteredMapMarkers()
                    "Marker with Text" -> mapItemsExample?.showMapMarkerWithText()
                    "MapMarkerCluster" -> mapItemsExample?.showMapMarkerCluster()
                    "Location (PED)" -> mapItemsExample?.showLocationIndicatorPedestrian()
                    "Location (NAV)" -> mapItemsExample?.showLocationIndicatorNavigation()
                    "Active/Inactive" -> mapItemsExample?.toggleActiveStateForLocationIndicator()
                    "Flat Marker" -> mapItemsExample?.showFlatMapMarker()
                    "2D Texture" -> mapItemsExample?.show2DTexture()
                    "3D Object" -> mapItemsExample?.showMapMarker3D()
                    "Clear Map" -> mapItemsExample?.clearMap()
                }
            },
            onMapViewPinClick = { item ->
                when (item) {
                    "Default" -> mapViewPinExample?.showMapViewPin()
                    "Anchored" -> mapViewPinExample?.showAnchoredMapViewPin()
                    "Clear Map" -> mapViewPinExample?.clearMap()
                }
            }
        )
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
        disposeHERESDK()
        super.onDestroy()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        mapView?.onSaveInstanceState(outState)
        super.onSaveInstanceState(outState)
    }

    private fun disposeHERESDK() {
        // Free HERE SDK resources before the application shuts down.
        // Usually, this should be called only on application termination.
        // Afterwards, the HERE SDK is no longer usable unless it is initialized again.
        SDKNativeEngine.getSharedInstance()?.dispose()
        // For safety reasons, we explicitly set the shared instance to null to avoid situations,
        // where a disposed instance is accidentally reused.
        SDKNativeEngine.setSharedInstance(null)
    }

    private companion object {
        private val TAG = MainActivity::class.java.simpleName
    }
}