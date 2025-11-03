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
package com.here.offlinemapskotlin

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Snackbar
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.here.offlinemapskotlin.ui.theme.OfflineMapsTheme
import com.here.sdk.core.engine.AuthenticationMode
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.engine.SDKOptions
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.MapFeatureModes
import com.here.sdk.mapview.MapFeatures
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView
import com.here.sdk.units.core.utils.EnvironmentLogger
import com.here.sdk.units.core.utils.PermissionsRequestor

class MainActivity : ComponentActivity() {


    private val environmentLogger = EnvironmentLogger()
    private lateinit var permissionsRequestor: PermissionsRequestor
    private var mapView: MapView? = null
    private lateinit var offlineMapsExample: OfflineMapsExample
    private lateinit var snackBarUpdater: SnackBarUpdater
    private lateinit var accessKeyID: String
    private lateinit var accessKeySecret: String
    private var savedInstanceState: Bundle? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)


        // Log application and device details.
        // It expects a string parameter that describes the application source language.
        environmentLogger.logEnvironment("Kotlin")
        this.savedInstanceState = savedInstanceState

        // Needs to be called before the activity is started.
        permissionsRequestor = PermissionsRequestor(this)

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        // Before creating a MapView instance please make sure that the HERE SDK is initialized.
        initializeHERESDK()

        snackBarUpdater = SnackBarUpdater()

        enableEdgeToEdge()

        setContent {
            OfflineMapsTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize()
                ) { paddingValues ->
                    Box(modifier = Modifier.padding(paddingValues)) {
                        HereMapView(savedInstanceState)
                        ButtonRows()
                    }
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.Bottom
                    ) {
                        SnackBar(snackBarUpdater)
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

    @Preview
    @Composable
    fun ButtonRows() {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(6.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                CustomButton(
                    onClick = { offlineMapsExample.onDownloadListClicked() },
                    text = "Regions"
                )
                Spacer(modifier = Modifier.width(18.dp))
                CustomButton(
                    onClick = { offlineMapsExample.onDownloadMapClicked() },
                    text = "Download"
                )
                Spacer(modifier = Modifier.width(18.dp))
                CustomButton(
                    onClick = { offlineMapsExample.onCancelMapDownloadClicked() },
                    text = "Cancel"
                )
                Spacer(modifier = Modifier.width(18.dp))
                CustomButton(
                    onClick = { offlineMapsExample.onDownloadAreaClicked() },
                    text = "Area"
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                CustomButton(
                    onClick = { offlineMapsExample.onSearchPlaceClicked() },
                    text = "Test Offline Search"
                )
                Spacer(modifier = Modifier.width(18.dp))
                CustomButton(
                    onClick = { offlineMapsExample.clearCache() },
                    text = "Clear Cache"
                )
                Spacer(modifier = Modifier.width(18.dp))
                CustomButton(
                    onClick = { offlineMapsExample.deleteInstalledRegions() },
                    text = "Delete Regions"
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                ToggleButton(
                    initiallyToggled = true,
                    onToggle = {
                        offlineMapsExample.toggleLayerConfiguration(
                            accessKeyID,
                            accessKeySecret,
                            this@MainActivity,
                            this@MainActivity.savedInstanceState
                        )
                    },
                    textOn = "OFFLINE_SEARCH LAYER: On",
                    textOff = "OFFLINE_SEARCH LAYER: Off"
                )
                Spacer(modifier = Modifier.width(18.dp))
                ToggleButton(
                    initiallyToggled = true,
                    onToggle = { offlineMapsExample.toggleOfflineMode() },
                    textOn = "Offline mode: Off",
                    textOff = "Offline mode: On"
                )
            }
        }
    }

    @Composable
    fun CustomButton(onClick: () -> Unit, text: String) {
        Button(
            onClick = onClick,
            contentPadding = PaddingValues(10.dp),
            modifier = Modifier.height(IntrinsicSize.Min),
            shape = RoundedCornerShape(10.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color(0xFF005CB9)
            )
        ) {
            Text(
                text = text,
                textAlign = TextAlign.Center,
                fontSize = 12.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                softWrap = true
            )
        }
    }

    @Composable
    fun ToggleButton(
        initiallyToggled: Boolean = false,
        onToggle: (Boolean) -> Unit,
        textOn: String = "On",
        textOff: String = "Off"
    ) {
        var isToggled by remember { mutableStateOf(initiallyToggled) }

        Button(
            onClick = {
                isToggled = !isToggled
                onToggle(isToggled)
            },
            contentPadding = PaddingValues(10.dp),
            modifier = Modifier.height(IntrinsicSize.Min),
            shape = RoundedCornerShape(10.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = if (isToggled) Color(0xFF005CB9) else Color.LightGray
            )
        ) {
            Text(
                text = if (isToggled) textOn else textOff,
                textAlign = TextAlign.Center,
                fontSize = 12.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                softWrap = true
            )
        }
    }

    @Composable
    fun SnackBar(snackBarUpdater: SnackBarUpdater) {
        val messageViewText by remember { snackBarUpdater.textState }
        if (messageViewText.isNotBlank()){
            Snackbar(
                modifier = Modifier.padding(4.dp),
                dismissAction = {
                    IconButton(onClick = {
                        snackBarUpdater.textState.value = ""
                    }) {
                        Icon(Icons.Filled.Close, contentDescription = "Close")
                    }
                }
            ) {
                Text(text = messageViewText)
            }
        }
    }

    private fun initializeHERESDK() {
        // Set your credentials for the HERE SDK.
        accessKeyID = "YOUR_ACCESS_KEY_ID"
        accessKeySecret = "YOUR_ACCESS_KEY_SECRET"
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

                offlineMapsExample = OfflineMapsExample(
                    mapViewNonNull,
                    this@MainActivity,
                    object : SnackBackCallback {
                        override fun show(text: String) {
                            snackBarUpdater.updateText(text)
                        }
                    })
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
    }

    interface SnackBackCallback {
        fun show(text: String)
    }
}
