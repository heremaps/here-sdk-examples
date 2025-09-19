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
package com.here.mapfeatureskotlin

import android.os.Bundle
import android.util.Log
import android.widget.Toast
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
import com.here.mapfeatureskotlin.ui.theme.MapFeaturesTheme
import com.here.mapitemskotlin.DropdownMenu
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.engine.AuthenticationMode
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.engine.SDKOptions
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapProjection
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.MapViewOptions
import com.here.sdk.units.core.utils.EnvironmentLogger

class MainActivity : ComponentActivity() {


    private val environmentLogger = EnvironmentLogger()
    private lateinit var permissionsRequestor: PermissionsRequestor
    private var mapViewGlobe: MapView? = null
    private var mapViewWebMercator: MapView? = null
    private lateinit var mapFeaturesExample: MapFeaturesExample
    private lateinit var mapSchemesExample: MapSchemesExample
    private var isMapViewGlobeVisible by mutableStateOf(false)

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
            MapFeaturesTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize(),
                ) { paddingValues ->
                    Box(modifier = Modifier.padding(paddingValues)) {
                        if (isMapViewGlobeVisible) {
                            GlobalMapView(savedInstanceState)
                        } else {
                            MercatorMapView(savedInstanceState)
                        }
                        CustomDropDownMenu()
                        WebMercatorButton()
                    }
                }
            }
        }
    }

    @Composable
    private fun GlobalMapView(savedInstanceState: Bundle?) {
        AndroidView(factory = { context ->
            MapView(context).apply {
                mapViewGlobe = this
                mapViewGlobe?.onCreate(savedInstanceState)

                // Note that for this app handling of permissions is optional as no sensitive permissions
                // are required.
                // Only after permissions have been granted (if any), we load the map view and start the app.
                handleAndroidPermissions()
            }
        })
    }

    @Composable
    private fun MercatorMapView(savedInstanceState: Bundle?) {
        var mapViewOptions = MapViewOptions()
        mapViewOptions.projection = MapProjection.WEB_MERCATOR

        AndroidView(factory = { context ->
            MapView(context, mapViewOptions).apply {
                mapViewWebMercator = this
                mapViewWebMercator?.onCreate(savedInstanceState)

                // Note that for this app handling of permissions is optional as no sensitive permissions
                // are required.
                // Only after permissions have been granted (if any), we load the map view and start the app.
                handleAndroidPermissions()
            }
        })
    }

    @Composable
    fun WebMercatorButton() {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.Bottom,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            CustomButton(
                onClick = {
                    mapFeaturesExample.disableFeatures()
                    isMapViewGlobeVisible = !isMapViewGlobeVisible
                          },
                text = if (isMapViewGlobeVisible) "  Switch to Web Mercator  " else "  Switch to Globe  "
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
            val context = this
            SDKNativeEngine.makeSharedInstance(context, options)
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of HERE SDK failed: " + e.error.name)
        }
    }

    // Convenience method to check all permissions that have been added to the AndroidManifest.
    private fun handleAndroidPermissions() {
        permissionsRequestor.requestPermissionsFromManifest(
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

    private fun getCurrentVisibleMapView(): MapView? {
        return if (isMapViewGlobeVisible) mapViewGlobe else mapViewWebMercator
    }

    private fun loadMapScene() {
        val mapViewNonNull = (if (isMapViewGlobeVisible) mapViewGlobe else mapViewWebMercator) ?: run {
            Log.e(TAG, "mapView is null. Cannot load map scene.")
            return
        }

        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapViewNonNull.mapScene.loadScene(MapScheme.NORMAL_DAY) { mapError ->
            if (mapError == null) {
                mapSchemesExample = MapSchemesExample()
                mapFeaturesExample = MapFeaturesExample(mapViewNonNull.mapScene)
                mapFeaturesExample.applyEnabledFeaturesForMapScene(mapViewNonNull.mapScene)

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
            onMapSchemesClick = { item ->
                when (item) {
                    "Lite Night" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.LITE_NIGHT
                    )
                    "Hybrid Day" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.HYBRID_DAY
                    )
                    "Hybrid Night" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.HYBRID_NIGHT
                    )
                    "Lite Day" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.LITE_DAY
                    )
                    "Lite Hybrid Day" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.LITE_HYBRID_DAY
                    )
                    "Lite Hybrid Night" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.LITE_HYBRID_NIGHT
                    )
                    "Logistics Day" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.LOGISTICS_DAY
                    )
                    "Logistics Hybrid Day" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.LOGISTICS_HYBRID_DAY
                    )
                    "Logistics Night" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.LOGISTICS_NIGHT
                    )
                    "Logistics Hybrid Night" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.LOGISTICS_HYBRID_NIGHT
                    )
                    "Normal Day" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.NORMAL_DAY
                    )
                    "Normal Night" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.NORMAL_NIGHT
                    )
                    "Road Network Day" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.ROAD_NETWORK_DAY
                    )
                    "Road Network Night" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.ROAD_NETWORK_NIGHT
                    )
                    "Satellite" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.SATELLITE
                    )
                    "Topo Day" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.TOPO_DAY
                    )
                    "Topo Night" -> mapSchemesExample.loadSchemeForCurrentView(
                        getCurrentVisibleMapView(),
                        MapScheme.TOPO_NIGHT
                    )
                }
            },
            onMapFeaturesClick = { item ->
                when (item) {
                    "Clear Map Features" -> mapFeaturesExample.disableFeatures()
                    "Building Footprints" -> mapFeaturesExample.enableBuildingFootprints()
                    "Congestion Zone" -> mapFeaturesExample.enableCongestionZones()
                    "Environmental Zones" -> mapFeaturesExample.enableEnvironmentalZones()
                    "Extruded Buildings" -> mapFeaturesExample.enableExtrudedBuildings()
                    "Landmarks Textured" -> mapFeaturesExample.enableLandmarksTextured()
                    "Landmarks Textureless" -> mapFeaturesExample.enableLandmarksTextureless()
                    "Safety Cameras" -> mapFeaturesExample.enableSafetyCameras()
                    "Shadows" -> {
                        Toast.makeText(
                            this, "Enabled building shadows for non-satellite-based schemes.",
                            Toast.LENGTH_SHORT
                        ).show()
                        mapFeaturesExample.enableShadows()
                    }
                    "Terrain Hillshade" -> mapFeaturesExample.enableTerrainHillShade()
                    "Terrain 3D" -> mapFeaturesExample.enableTerrain3D()
                    "Ambient Occlusion" -> mapFeaturesExample.enableAmbientOcclusion()
                    "Contours" -> mapFeaturesExample.enableContours()
                    "Low Speed Zones" -> mapFeaturesExample.enableLowSpeedZones()
                    "Traffic Flow with Free Flow" -> mapFeaturesExample.enableTrafficFlowWithFreeFlow()
                    "Traffic Flow without Free Flow" -> mapFeaturesExample.enableTrafficFlowWithoutFreeFlow()
                    "Traffic Incidents" -> mapFeaturesExample.enableTrafficIncidents()
                    "Vehicle Restrictions Active" -> mapFeaturesExample.enableVehicleRestrictionsActive()
                    "Vehicle Restrictions Active/Inactive" -> mapFeaturesExample.enableVehicleRestrictionsActiveAndInactive()
                    "Vehicle Restrictions Active/Inactive Diff" -> mapFeaturesExample.enableVehicleRestrictionsActiveAndInactiveDiff()
                    "Road Exit Labels" -> mapFeaturesExample.enableRoadExitLabels()
                    "Road Exit Labels Numbers Only" -> mapFeaturesExample.enableRoadExitLabelsNumbersOnly()
                }
            }
        )
    }

    override fun onPause() {
        mapViewGlobe?.onPause()
        super.onPause()
    }

    override fun onResume() {
        mapViewGlobe?.onResume()
        super.onResume()
    }

    override fun onDestroy() {
        mapViewGlobe?.onDestroy()
        disposeHERESDK()
        super.onDestroy()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        mapViewGlobe?.onSaveInstanceState(outState)
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
