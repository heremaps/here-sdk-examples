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
package com.here.reroutingkotlin

import android.os.Bundle
import android.util.Log
import android.graphics.Bitmap
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
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.here.reroutingkotlin.ui.ManeuverView
import com.here.reroutingkotlin.utils.ManeuverIconProvider
import com.here.reroutingkotlin.ui.theme.ReroutingTheme
import com.here.sdk.core.engine.*
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.MapFeatureModes
import com.here.sdk.mapview.MapFeatures
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView
import com.here.sdk.routing.ManeuverAction
import com.here.sdk.units.core.utils.EnvironmentLogger
import com.here.sdk.units.core.utils.PermissionsRequestor

class MainActivity : ComponentActivity() {


    private val environmentLogger = EnvironmentLogger()
    private lateinit var permissionsRequestor: PermissionsRequestor
    private var mapView: MapView? = null
    private var reroutingExample: ReroutingExample? = null
    private var maneuverView: ManeuverView? = null
    private var maneuverIconProvider: ManeuverIconProvider? = null

    interface UICallback {
        fun onManeuverEvent(action: ManeuverAction, message1: String, message2: String)
        fun onRoadShieldEvent(maneuverIcon: Bitmap?)
        fun onHideRoadShieldIcon()
        fun onHideManeuverPanel()
    }

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
            ReroutingTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize()
                ) { paddingValues ->
                    Box(modifier = Modifier.padding(paddingValues)) {
                        HereMapView(savedInstanceState)
                        ButtonRows()
                        ManeuverPanel()
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
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                CustomButton(onClick = { reroutingExample?.onShowRouteButtonClicked() }, text = "Show Route")
                Spacer(modifier = Modifier.width(16.dp))
                CustomButton(onClick = { reroutingExample?.onStartStopButtonClicked() }, text = "Start/Stop")
                Spacer(modifier = Modifier.width(16.dp))
                CustomButton(onClick = { reroutingExample?.onClearMapButtonClicked() }, text = "Clear")
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                CustomButton(onClick = { reroutingExample?.onDefineDeviationPointsButtonClicked() }, text = "Deviation Points")
                Spacer(modifier = Modifier.width(16.dp))
                CustomButton(onClick = { reroutingExample?.onSpeedButtonClicked() }, text = "Toggle Speed")
            }
        }
    }

    @Composable
    fun ManeuverPanel() {
        AndroidView(factory = { context ->
            ManeuverView(context).apply {
                maneuverView = this
            }
        }, update = { view ->
            view.redraw()
        })
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
        // Disable any logs from HERE SDK. Call this before initializing the HERE SDK.
        LogControl.disableLoggingToConsole()
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
        val mapViewNonNull = mapView ?: run {
            Log.e(TAG, "mapView is null. Cannot load map scene.")
            return
        }

        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapViewNonNull.mapScene.loadScene(MapScheme.NORMAL_DAY) { mapError ->
            if (mapError == null) {
                val mapFeatures = HashMap<String, String>()
                mapFeatures[MapFeatures.LOW_SPEED_ZONES] = MapFeatureModes.LOW_SPEED_ZONES_ALL
                mapViewNonNull.mapScene.enableFeatures(mapFeatures)

                maneuverIconProvider = ManeuverIconProvider().also { it.loadManeuverIcons() }
                reroutingExample = ReroutingExample(this@MainActivity, mapViewNonNull)
                setupEventHandling()
            } else {
                Log.d(TAG, "Map loading failed: ${mapError.name}")
            }
        }
    }

    private fun setupEventHandling() {
        reroutingExample?.setUICallback(object : UICallback {
            override fun onManeuverEvent(action: ManeuverAction, message1: String, message2: String) {
                val maneuverIcon = maneuverIconProvider?.getManeuverIcon(action)
                val maneuverIconText = action.name
                maneuverView?.onManeuverEvent(maneuverIcon, maneuverIconText, message1, message2)
            }

            override fun onRoadShieldEvent(maneuverIcon: Bitmap?) {
                maneuverView?.onRoadShieldEvent(maneuverIcon)
            }

            override fun onHideRoadShieldIcon() {
                maneuverView?.onHideRoadShieldIcon()
            }

            override fun onHideManeuverPanel() {
                maneuverView?.onHideManeuverPanel()
            }
        })
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
        reroutingExample?.dispose()

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
