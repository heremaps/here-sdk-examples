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

package com.here.navigationheadlesskotlin

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AlertDialog
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.lifecycleScope
import com.here.navigationheadlesskotlin.ui.theme.NavigationHeadlesssTheme
import com.here.sdk.core.LocationListener
import com.here.sdk.core.engine.AuthenticationMode
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.engine.SDKOptions
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.navigation.GPXDocument
import com.here.sdk.navigation.GPXOptions
import com.here.sdk.navigation.GPXTrack
import com.here.sdk.navigation.LocationSimulator
import com.here.sdk.navigation.LocationSimulatorOptions
import com.here.sdk.navigation.Navigator
import com.here.sdk.navigation.RoadTextsListener
import com.here.sdk.navigation.SpeedLimit
import com.here.sdk.navigation.SpeedLimitListener
import com.here.sdk.routing.RoadTexts
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File
import com.here.sdk.units.core.utils.EnvironmentLogger

class MainActivity: ComponentActivity() {

    private val environmentLogger = EnvironmentLogger()
    private lateinit var permissionsRequestor: PermissionsRequestor
    private lateinit var navigator: Navigator

    private val speedLimitTextView = mutableStateOf("Current speed limit: n/a")
    private val roadnameTextView = mutableStateOf("Current road name: n/a")
    private val timerTextView = mutableStateOf("00:00:00")

    private var elapsedTime = 0L
    private var timerJob: Job? = null

    var isDialogVisible by mutableStateOf(false)
    var dialogTitle by mutableStateOf("")
    var dialogText by mutableStateOf("")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Needs to be called before the activity is started.

        // Log application and device details.
        // It expects a string parameter that describes the application source language.
        environmentLogger.logEnvironment("Kotlin")
        permissionsRequestor = PermissionsRequestor(this)

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK()

        handleAndroidPermissions()

        enableEdgeToEdge()
        
        startTimer(lifecycleScope)

        setContent {
            NavigationHeadlesssTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize()
                ) { paddingValues ->
                    Box(modifier = Modifier.padding(paddingValues)) {
                        CustomTextColumn()
                        DisplayDialog()
                    }
                }
            }
        }
    }

    @Composable
    fun DisplayDialog() {
        if (isDialogVisible) {
            AlertDialog(
                onDismissRequest = { isDialogVisible = false },
                title = { Text(dialogTitle) },
                text = { Text(dialogText) },
                confirmButton = {
                    TextButton(onClick = { isDialogVisible = false }) {
                        Text("OK")
                    }
                }
            )
        }
    }

    @Composable
    fun CustomTextColumn() {
        val timerTextView by remember { timerTextView }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(6.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            CustomText(roadnameTextView.value)
            CustomText(speedLimitTextView.value)
            CustomText(timerTextView)
        }
    }

    @Composable
    fun CustomText(text: String) {
        Text(
            text = text,
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = MaterialTheme.colorScheme.primary,
                    shape = RoundedCornerShape(8.dp)
                )
                .padding(8.dp), // Adjust as needed
            textAlign = TextAlign.Center,
            fontSize = 12.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            color = MaterialTheme.colorScheme.onPrimary,
            softWrap = true
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
            throw RuntimeException("Initialization of HERE SDK failed: " + e.error.name)
        }
    }

    // Convenience method to check all permissions that have been added to the AndroidManifest.
    private fun handleAndroidPermissions() {
        permissionsRequestor = PermissionsRequestor(this)
        permissionsRequestor.request(object :
            PermissionsRequestor.ResultListener {
            override fun permissionsGranted() {
                startGuidanceExample()
            }

            override fun permissionsDenied() {
                Log.e(com.here.navigationheadlesskotlin.MainActivity.Companion.TAG, "Permissions denied by user.")
            }
        })
    }

    private fun startGuidanceExample() {
        val context = this
        val gpxTrack = loadGPXTrack(context)
        gpxTrack?.let {
            showDialog("Headless Navigation Started", "Tracking started using a predefined GPX file. Check logs for updates.")
            startTracking(it)
        } ?: showDialog("Error", "GPX track not found.")
    }

    private fun loadGPXTrack(context: Context): GPXTrack? {
        return try {
            // We added a GPX file to app/src/main/res/raw/berlin_trace.gpx.
            val absolutePath: String? = getPathForRawResource(context, "berlin_trace.gpx", R.raw.berlin_trace)
            return absolutePath?.let { path ->
                val document = GPXDocument(path, GPXOptions())
                if (document.tracks.isNotEmpty()) {
                    document.tracks[0]
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            println("It seems no GPXDocument was found: $e")
            null
        }
    }

    fun getPathForRawResource(context: Context, filename: String, resourceId: Int): String? {
        return try {
            val inputStream = context.resources.openRawResource(resourceId)
            val file = File(context.cacheDir, filename)
            inputStream.use { input ->
                file.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            file.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun startTimer(scope: CoroutineScope) {
        timerJob = scope.launch {
            while (isActive) {
                delay(1000)
                elapsedTime++
                updateTimerText()
            }
        }
    }

    private fun updateTimerText() {
        val seconds: Long = elapsedTime % 60
        val minutes: Long = (elapsedTime % 3600) / 60
        val hours: Long = elapsedTime / 3600

        // Format the text as HH:mm:ss.
        timerTextView.value = String.format("%02d:%02d:%02d", hours, minutes, seconds)
    }

    private fun startTracking(gpxTrack: GPXTrack) {
        try {
            // Without a route set, this starts tracking mode.
            navigator = Navigator()
        } catch (e: InstantiationErrorException) {
            throw java.lang.RuntimeException("Initialization of Navigator failed: " + e.error.name)
        }

        // For this example, we listen only to a few selected events, such as speed limits along the current road.
        setupSelectedEventHandlers()

        // `Navigator` acts as `LocationListener` to receive location updates directly from a location provider.
        // Any progress along the simulate locations is a result of getting a new location fed into the Navigator.
        setupLocationSource(navigator, gpxTrack)
    }

    private fun setupSelectedEventHandlers() {
        // Notifies whenever any textual attribute of the current road changes, i.e., the current road texts differ
        // from the previous one. This can be useful during tracking mode, when no maneuver information is provided.
        navigator.roadTextsListener = object : RoadTextsListener {
            override fun onRoadTextsUpdated(roadTexts: RoadTexts) {
                val currentRoadName = roadTexts.names.defaultValue
                val currentRoadNumber = roadTexts.numbersWithDirection.defaultValue
                var roadName = currentRoadName ?: currentRoadNumber
                if (roadName == null) {
                    // Happens only in rare cases, when also the fallback is null.
                    roadName = "unnamed road"
                }
                roadnameTextView.value = "Current road name: $roadName"
            }
        }

        navigator.speedLimitListener = object : SpeedLimitListener {
            override fun onSpeedLimitUpdated(speedLimit: SpeedLimit) {
                val currentEffectiveSpeedLimit = speedLimit.effectiveSpeedLimitInMetersPerSecond()
                
                speedLimitTextView.value = currentEffectiveSpeedLimit?.let { speedLimit ->
                    if (speedLimit == 0.0) {
                        "Current speed limit: no speed limit"
                    } else {
                        "Current speed limit: " + metersPerSecondToKilometersPerHour(speedLimit)
                    }
                } ?: "Current speed limit: no data"
            }
        }
    }

    private fun metersPerSecondToKilometersPerHour(metersPerSecond: Double): String {
        val kmh = (metersPerSecond * 3.6).toInt()
        return "$kmh km/h"
    }

    private fun setupLocationSource(locationListener: LocationListener?, gpxTrack: GPXTrack) {
        val locationSimulator: LocationSimulator?
        try {
            // Provides fake GPS signals based on the GPX track's geometry.
            val locationSimulatorOptions = LocationSimulatorOptions()
            locationSimulatorOptions.speedFactor = 15.0
            locationSimulator = LocationSimulator(gpxTrack, locationSimulatorOptions)
        } catch (e: InstantiationErrorException) {
            throw java.lang.RuntimeException("Initialization of LocationSimulator failed: " + e.error.name)
        }

        locationSimulator.setListener(locationListener)
        locationSimulator.start()
    }

    private fun showDialog(title: String, text: String) {
        dialogTitle = title
        dialogText = text
        isDialogVisible = true
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

    companion object {
        private val TAG: String = MainActivity::class.java.simpleName
    }
}
