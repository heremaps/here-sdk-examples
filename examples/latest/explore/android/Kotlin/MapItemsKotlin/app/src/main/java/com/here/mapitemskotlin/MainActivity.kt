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
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
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
import com.here.sdk.units.core.views.UnitButton
import com.here.sdk.units.popupmenu.PopupMenuView
import com.here.sdk.units.core.utils.EnvironmentLogger

class MainActivity : ComponentActivity() {


    private val environmentLogger = EnvironmentLogger()
    private var permissionsRequestor: PermissionsRequestor? = null
    private var mapView: MapView? = null
    private var mapItemsExample: MapItemsExample? = null
    private var mapObjectsExample: MapObjectsExample? = null
    private var mapViewPinExample: MapViewPinExample? = null

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
            MapItemsTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize()
                ) { paddingValues ->
                    Box(modifier = Modifier.padding(paddingValues)) {
                        HereMapView(savedInstanceState)
                        ButtonRows()
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

    @Composable
    fun ButtonRows() {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(DEFAULT_UI_SPACE.dp),
            verticalArrangement = Arrangement.spacedBy(DEFAULT_UI_SPACE.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                PopupMenuViewComposable(modifier = Modifier.weight(ROW_WEIGHT)) { view -> setupPopupMenuForMapObjects(view) }
                Spacer(modifier = Modifier.width(DEFAULT_UI_SPACE.dp))
                PopupMenuViewComposable(modifier = Modifier.weight(ROW_WEIGHT)) { view -> setupPopupMenuForMapMarkers(view) }
                Spacer(modifier = Modifier.width(DEFAULT_UI_SPACE.dp))
                PopupMenuViewComposable(modifier = Modifier.weight(ROW_WEIGHT)) { view -> setupPopupMenuForMapViewPins(view) }
            }
        }
    }

    // Wrap the PopupMenuView into a Composable in order to use it with Jetpack Compose.
    @Composable
    fun PopupMenuViewComposable(
        modifier: Modifier = Modifier,
        onViewReady: (PopupMenuView) -> Unit = {}
    ) {
        AndroidView(
            modifier = modifier,
            factory = { context ->
                PopupMenuView(context).apply {
                    val button = getChildAt(0) as? UnitButton
                    button?.setPadding(DEFAULT_UI_SPACE * 2, DEFAULT_UI_SPACE, DEFAULT_UI_SPACE * 2, DEFAULT_UI_SPACE)
                 }},
            update = { view -> onViewReady(view) }
        )
    }

    private fun setupPopupMenuForMapObjects(popupMenuView: PopupMenuView) {
        val menuItems = mutableMapOf<String?, Runnable?>()
        menuItems["Polyline"] = Runnable { mapObjectsExample?.showMapPolyline() }
        menuItems["Polyline with gradients"] = Runnable { mapObjectsExample?.showGradientMapPolyLine() }
        menuItems["Arrow"] = Runnable { mapObjectsExample?.showMapArrow() }
        menuItems["Polygon"] = Runnable { mapObjectsExample?.showMapPolygon() }
        menuItems["Circle"] = Runnable { mapObjectsExample?.showMapCircle() }
        menuItems["Enable visibility ranges for polylines"] = Runnable { mapObjectsExample?.enableVisibilityRangesForPolyline() }
        menuItems["Clear items"] = Runnable { mapObjectsExample?.clearMapButtonClicked() }

        val popupMenuUnit = popupMenuView.popupMenuUnit
        popupMenuUnit.setMenuContent("Map objects", menuItems)
    }

    private fun setupPopupMenuForMapMarkers(popupMenuView: PopupMenuView) {
        val menuItems = mutableMapOf<String?, Runnable?>()
        menuItems["Anchored (2D)"] = Runnable { mapItemsExample?.showAnchoredMapMarkers() }
        menuItems["Centered (2D)"] = Runnable { mapItemsExample?.showCenteredMapMarkers() }
        menuItems["Marker with text"] = Runnable { mapItemsExample?.showMapMarkerWithText() }
        menuItems["MapMarkerCluster"] = Runnable { mapItemsExample?.showMapMarkerCluster() }
        menuItems["LocationIndicator (PED)"] = Runnable { mapItemsExample?.showLocationIndicatorPedestrian() }
        menuItems["LocationIndicator (NAV)"] = Runnable { mapItemsExample?.showLocationIndicatorNavigation() }
        menuItems["LocationIndicator Active/Inactive"] = Runnable { mapItemsExample?.toggleActiveStateForLocationIndicator() }
        menuItems["Flat marker"] = Runnable { mapItemsExample?.showFlatMapMarker() }
        menuItems["2D texture"] = Runnable { mapItemsExample?.show2DTexture() }
        menuItems["3D object"] = Runnable { mapItemsExample?.showMapMarker3D() }
        menuItems["Clear map"] = Runnable { mapItemsExample?.clearMap() }

        val popupMenuUnit = popupMenuView.popupMenuUnit
        popupMenuUnit.setMenuContent("Map markers", menuItems)
    }

    private fun setupPopupMenuForMapViewPins(popupMenuView: PopupMenuView) {
        val menuItems = mutableMapOf<String?, Runnable?>()
        menuItems["Default"] = Runnable { mapViewPinExample?.showMapViewPin() }
        menuItems["Anchored"] = Runnable { mapViewPinExample?.showAnchoredMapViewPin() }
        menuItems["Clear map"] = Runnable { mapViewPinExample?.clearMap() }

        val popupMenuUnit = popupMenuView.popupMenuUnit
        popupMenuUnit.setMenuContent("Map view pins", menuItems)
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
                mapObjectsExample = MapObjectsExample(this@MainActivity, mapViewNonNull)
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
        const val ROW_WEIGHT = 1f
        const val DEFAULT_UI_SPACE = 16
    }
}