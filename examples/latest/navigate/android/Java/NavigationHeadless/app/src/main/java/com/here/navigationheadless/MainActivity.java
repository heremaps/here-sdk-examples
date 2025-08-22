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

package com.here.navigationheadless;

import android.content.Context;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import com.here.navigationheadless.PermissionsRequestor.ResultListener;
import com.here.sdk.core.LocationListener;
import com.here.sdk.core.engine.AuthenticationMode;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.navigation.GPXDocument;
import com.here.sdk.navigation.GPXOptions;
import com.here.sdk.navigation.GPXTrack;
import com.here.sdk.navigation.LocationSimulator;
import com.here.sdk.navigation.LocationSimulatorOptions;
import com.here.sdk.navigation.Navigator;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

// The Navigation Headless example app shows how the HERE SDK can be set up to navigate without
// following a route in the simplest way without showing a map view. The app uses the `Navigator` class.
// It loads a hardcoded GPX trace in the Berlin area to start tracking along that trace using the `LocationSimulator`.
// It does not include HERE SDK Positioning features and does no route calculation.
//
// Instead, the app provides basic notifications on the following events:
//
// - current speed limit
// - current road name
//
// Note that the GPX trace is played back faster to make it easier to see changing events.
// See `speedFactor` setting below to adjust the simulation speed.
// In addition, a timer is shown to present the elapsed time while the example app is running.
public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;

    private Navigator navigator;

    private TextView speedLimitTextView;
    private TextView roadnameTextView;
    private TextView timerTextView;
    private Handler timerHandler;
    private long elapsedTime = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        if (SDKNativeEngine.getSharedInstance() == null) {
            initializeHERESDK();
            // We are starting from scratch without a bundled state.
            handleAndroidPermissions();
        }

        setContentView(R.layout.activity_main);

        speedLimitTextView = findViewById(R.id.speedLimitTextView);
        roadnameTextView = findViewById(R.id.roadnameTextView);
        timerTextView = findViewById(R.id.timerTextView);

        timerHandler = new Handler(Looper.getMainLooper());
        startTimer();
    }

    private void startTimer() {
        int delayMillis = 1000;
        Runnable timerRunnable = new Runnable() {
            @Override
            public void run() {
                elapsedTime++;
                updateTimerText();
                timerHandler.postDelayed(this, delayMillis);
            }
        };
        timerHandler.post(timerRunnable);
    }

    private void updateTimerText() {
        long seconds = elapsedTime % 60;
        long minutes = (elapsedTime % 3600) / 60;
        long hours = elapsedTime / 3600;

        // Format the text as HH:mm:ss.
        timerTextView.setText(String.format("%02d:%02d:%02d", hours, minutes, seconds));
    }

    private void initializeHERESDK() {
        // Set your credentials for the HERE SDK.
        String accessKeyID = "YOUR_ACCESS_KEY_ID";
        String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
        AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyID, accessKeySecret);
        SDKOptions options = new SDKOptions(authenticationMode);
        try {
            Context context = this;
            SDKNativeEngine.makeSharedInstance(context, options);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of HERE SDK failed: " + e.error.name());
        }
    }

    private void handleAndroidPermissions() {
        permissionsRequestor = new PermissionsRequestor(this);
        permissionsRequestor.request(new ResultListener(){

            @Override
            public void permissionsGranted() {
                startGuidanceExample();
            }

            @Override
            public void permissionsDenied() {
                Log.e(TAG, "Permissions denied by user.");
            }
        });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        permissionsRequestor.onRequestPermissionsResult(requestCode, grantResults);
    }

    private void startGuidanceExample() {
        // We start tracking by loading a GPX trace for location simulation.
        Context context = MainActivity.this;
        GPXTrack gpxTrack = loadGPXTrack(context);
        if (gpxTrack != null) {
            showDialog("Navigation Headless Start",
                    "This app shows headless tracking following a hardcoded GPX trace. Watch the logs for events.");
            startTracking(gpxTrack);
        } else {
            showDialog("Error",
                    "GPX track not found.");
        }
    }

    @Nullable
    private GPXTrack loadGPXTrack(Context context) {
        GPXTrack gpxTrack;

        try {
            // We added a GPX file to app/src/main/res/raw/berlin_trace.gpx.
            String absolutePath = getPathForRawResource(context, "berlin_trace.gpx", R.raw.berlin_trace);
            if (absolutePath == null) {
                return null;
            }
            GPXDocument gpxDocument = new GPXDocument(absolutePath, new GPXOptions());
            if (gpxDocument.getTracks().isEmpty()) {
                return null;
            }
            gpxTrack = gpxDocument.getTracks().get(0);
        } catch (Exception instantiationError) {
            System.out.println("It seems no GPXDocument was found: " + instantiationError);
            return null;
        }

        return gpxTrack;
    }

    // Retrieves the file path for a raw resource by copying it to the app's internal storage.
    //
    // Android does not provide direct file paths for raw resources. This method ensures the
    // raw resource is accessible as a file by copying it to internal storage. The copy operation
    // is performed only on the first call. Subsequent calls return the file path from the internal
    // storage if the resource was successfully copied earlier.
    @Nullable
    public static String getPathForRawResource(Context context, String fileName, int rawID) {
        File destinationFile = new File(context.getFilesDir(), fileName);
        // Check if the file was copied before.
        if (!destinationFile.exists()) {
            try {
                try (InputStream inputStream = context.getResources().openRawResource(rawID)) {
                    try (FileOutputStream outputStream = new FileOutputStream(destinationFile)) {
                        // Copy file content to internal storage, since Android allows to
                        // get a file path only from File class.
                        byte[] buffer = new byte[1024];
                        int bytesRead;
                        while ((bytesRead = inputStream.read(buffer)) > 0) {
                            outputStream.write(buffer, 0, bytesRead);
                        }
                    }
                }
            } catch (IOException e) {
                Log.e(TAG, "Error copying file to internal storage: " + e.getMessage(), e);
                return null;
            }
        }
        return destinationFile.getAbsolutePath();
    }

    private void startTracking(GPXTrack gpxTrack) {
        try {
            // Without a route set, this starts tracking mode.
            navigator = new Navigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of Navigator failed: " + e.error.name());
        }

        // For this example, we listen only to a few selected events, such as speed limits along the current road.
        setupSelectedEventHandlers();

        // `Navigator` acts as `LocationListener` to receive location updates directly from a location provider.
        // Any progress along the simulate locations is a result of getting a new location fed into the Navigator.
        setupLocationSource(navigator, gpxTrack);
    }

    // More examples can be found in the Navigation example app.
    private void setupSelectedEventHandlers() {
        // Notifies whenever any textual attribute of the current road changes, i.e., the current road texts differ
        // from the previous one. This can be useful during tracking mode, when no maneuver information is provided.
        navigator.setRoadTextsListener(roadTexts -> {
            String currentRoadName = roadTexts.names.getDefaultValue();
            String currentRoadNumber = roadTexts.numbersWithDirection.getDefaultValue();
            String roadName = currentRoadName == null ? currentRoadNumber : currentRoadName;
            if (roadName == null) {
                // Happens only in rare cases, when also the fallback is null.
                roadName = "unnamed road";
            }
            roadnameTextView.setText("Current road name: " + roadName);
        });

        // Notifies on the current speed limit valid on the current road.
        navigator.setSpeedLimitListener(speedLimit -> {
            Double currentEffectiveSpeedLimit = speedLimit.effectiveSpeedLimitInMetersPerSecond();

            if (currentEffectiveSpeedLimit == null) {
                speedLimitTextView.setText("Current speed limit: no data");
            } else if (currentEffectiveSpeedLimit == 0) {
                speedLimitTextView.setText("Current speed limit: no speed limit");
            } else {
                speedLimitTextView.setText("Current speed limit: " + metersPerSecondToKilometersPerHour(currentEffectiveSpeedLimit));
            }
        });
    }

    private static String metersPerSecondToKilometersPerHour(double metersPerSecond) {
        int kmh =  (int) (metersPerSecond * 3.6);
        return kmh + " km/h";
    }

    private void setupLocationSource(LocationListener locationListener, GPXTrack gpxTrack) {
        LocationSimulator locationSimulator;
        try {
            // Provides fake GPS signals based on the GPX track's geometry.
            LocationSimulatorOptions locationSimulatorOptions = new LocationSimulatorOptions();
            locationSimulatorOptions.speedFactor = 15;
            locationSimulator = new LocationSimulator(gpxTrack, locationSimulatorOptions);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of LocationSimulator failed: " + e.error.name());
        }

        locationSimulator.setListener(locationListener);
        locationSimulator.start();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (isFinishing()) {
            timerHandler.removeCallbacksAndMessages(null);
            disposeHERESDK();
        }
    }

    private void disposeHERESDK() {
        // Free HERE SDK resources before the application shuts down.
        // Usually, this should be called only on application termination.
        // Afterwards, the HERE SDK is no longer usable unless it is initialized again.
        SDKNativeEngine sdkNativeEngine = SDKNativeEngine.getSharedInstance();
        if (sdkNativeEngine != null) {
            sdkNativeEngine.dispose();
            // For safety reasons, we explicitly set the shared instance to null to avoid situations,
            // where a disposed instance is accidentally reused.
            SDKNativeEngine.setSharedInstance(null);
        }
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle(title)
                .setMessage(message)
                .show();
    }
}
