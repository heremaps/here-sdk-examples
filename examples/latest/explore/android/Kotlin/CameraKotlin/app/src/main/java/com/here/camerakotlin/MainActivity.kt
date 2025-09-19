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
package com.here.camerakotlin

import android.os.Bundle
import android.util.Log
import android.widget.ImageView
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.annotation.DrawableRes
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
import com.here.camerakotlin.ui.theme.CameraTheme
import com.here.sdk.core.engine.AuthenticationMode
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.engine.SDKOptions
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView
import com.here.sdk.units.core.utils.EnvironmentLogger

class MainActivity : ComponentActivity() {

    private val environmentLogger = EnvironmentLogger()
    private var permissionsRequestor: PermissionsRequestor? = null
    private var mapView: MapView? = null
    private var cameraExample: CameraExample? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Needs to be called before the activity is started.
        permissionsRequestor = PermissionsRequestor(this)

        // Log application and device details.
        // It expects a string parameter that describes the application source language.
        environmentLogger.logEnvironment("Kotlin")

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        // Before creating a MapView instance please make sure that the HERE SDK is initialized.
        initializeHERESDK()

        enableEdgeToEdge()

        setContent {
            CameraTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize()
                ) { paddingValues ->
                    Box(modifier = Modifier.padding(paddingValues)) {
                        HereMapView(savedInstanceState)
                        ButtonRows()
                        CameraTargetDot(
                            cameraExample = cameraExample,
                            modifier = Modifier.fillMaxSize()
                        )
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
                CustomButton(onClick = { cameraExample?.rotateButtonClicked() },
                    text = "Rotate"
                )
                Spacer(modifier = Modifier.width(16.dp))
                CustomButton(onClick = { cameraExample?.tiltButtonClicked() },
                    text = "Tilt"
                )
                Spacer(modifier = Modifier.width(16.dp))
                CustomButton(onClick = { cameraExample?.moveToXYButtonClicked() },
                    text = "Move"
                )
            }
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

    @Composable
    fun CameraTargetDot(
        cameraExample: CameraExample?,
        modifier: Modifier = Modifier
    ) {
        // Fill the entire parent so we can center or manually move the dot as needed
        CustomImageView(
            modifier = modifier,
            drawableRes = R.drawable.red_dot,
            contentDescription = "Camera Target Dot",
            scaleType = ImageView.ScaleType.CENTER_INSIDE
        ) { imageView ->
            // Capture the ImageView reference so CameraExample can manipulate it.
            // The red circle dot indicates the camera's current target location.
            // By default, the dot is centered on the full screen map view.
            // Same as the camera, which is also centered above the map view.
            // Later on, we will adjust the dot's location on screen programmatically when the camera's target changes.
            cameraExample?.cameraTargetView = imageView
        }
    }

    @Composable
    fun CustomImageView(
        modifier: Modifier = Modifier,
        @DrawableRes drawableRes: Int,
        contentDescription: String? = null,
        scaleType: ImageView.ScaleType = ImageView.ScaleType.CENTER_INSIDE,
        onImageViewCreated: ((ImageView) -> Unit)? = null
    ) {
        AndroidView(
            modifier = modifier,
            factory = { context ->
                ImageView(context).apply {
                    setImageResource(drawableRes)
                    this.contentDescription = contentDescription
                    this.scaleType = scaleType
                    // If you need to keep a reference in your ViewModel or somewhere else:
                    onImageViewCreated?.invoke(this)
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
                cameraExample = CameraExample(this@MainActivity, mapViewNonNull)
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
}
