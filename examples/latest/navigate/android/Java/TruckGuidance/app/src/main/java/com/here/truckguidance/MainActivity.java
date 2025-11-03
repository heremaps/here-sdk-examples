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

package com.here.truckguidance;

import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Color;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.here.sdk.core.engine.AuthenticationMode;
import com.here.sdk.core.engine.LogControl;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.units.core.utils.EnvironmentLogger;
import com.here.sdk.units.core.utils.PermissionsRequestor;

public class MainActivity extends AppCompatActivity {

    private EnvironmentLogger environmentLogger = new EnvironmentLogger();
    private static final String TAG = MainActivity.class.getSimpleName();

    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private TruckGuidanceExample truckGuidanceExample;
    private SpeedView truckSpeedLimitView;
    private SpeedView carSpeedLimitView;
    private SpeedView drivingSpeedView;
    private TruckRestrictionView truckRestrictionView;

    public interface UICallback {
        void onTruckSpeedLimit(String speedLimit);
        void onCarSpeedLimit(String speedLimit);
        void onDrivingSpeed(String drivingSpeed);

        void onTruckRestrictionWarning(String description);
        void onHideTruckRestrictionWarning();
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Log application and device details.
        // It expects a string parameter that describes the application source language.
        environmentLogger.logEnvironment("Java");

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        // Get a MapView instance from layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        handleAndroidPermissions();
    }

    private void initializeHERESDK() {
        // Disable any logs from HERE SDK.
        // Make sure to call this before initializing the HERE SDK.
        LogControl.disableLoggingToConsole();

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
        permissionsRequestor.request(new PermissionsRequestor.ResultListener(){

            @Override
            public void permissionsGranted() {
                loadMapScene();
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

    private void loadMapScene() {
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, mapError -> {
            if (mapError == null) {
                handleUIUpdates();
                truckGuidanceExample = new TruckGuidanceExample(MainActivity.this, mapView);
                setupEventHandling();
            } else {
                Log.d(TAG, "Loading map failed: mapErrorCode: " + mapError.name());
            }
        });
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        handleUIUpdates();
    }

    private void handleUIUpdates() {
        // Get the root ViewGroup of the existing layout.
        ViewGroup rootView = findViewById(android.R.id.content);

        // Delay the execution of the code using View.post() to ensure any orientation change has completed
        // and the view's properties are updated.
        rootView.post(() -> setupUIComponents(rootView));
    }

    private void setupUIComponents(ViewGroup rootView) {
        int rootViewHeightInDP = getHeightInDP(rootView);
        int marginInDP = 5;

        if (truckSpeedLimitView == null) {
            // Add a view to show the current truck speed limit during guidance or tracking.
            truckSpeedLimitView = new SpeedView(rootView.getContext());
            rootView.addView(truckSpeedLimitView);
            truckSpeedLimitView.setLabel("Truck");
            truckSpeedLimitView.setSpeedLimit("n/a");
        }

        if (carSpeedLimitView == null) {
            // Add a view to show the current car speed limit during guidance or tracking.
            carSpeedLimitView = new SpeedView(rootView.getContext());
            rootView.addView(carSpeedLimitView);
            carSpeedLimitView.setLabel("Car");
            carSpeedLimitView.setSpeedLimit("n/a");
        }

        if (drivingSpeedView == null) {
            // Another view to show the current driving speed.
            drivingSpeedView = new SpeedView(rootView.getContext());
            rootView.addView(drivingSpeedView);
            drivingSpeedView.circleColor = Color.WHITE;
            drivingSpeedView.setSpeedLimit("n/a");
        }

        if (truckRestrictionView == null) {
            // A view to show TruckRestrictionWarnings.
            truckRestrictionView = new TruckRestrictionView(rootView.getContext());
            rootView.addView(truckRestrictionView);
        }

        // Set x,y position in density-independent pixels based on bottom-left corner of screen.
        truckSpeedLimitView.xInDP = marginInDP;
        truckSpeedLimitView.yInDP = rootViewHeightInDP - truckSpeedLimitView.getHeightInDP();
        truckSpeedLimitView.redraw();

        // Set x,y position in density-independent pixels relative to truckSpeedLimitView.
        carSpeedLimitView.xInDP = marginInDP * 2 + truckSpeedLimitView.getWidthInDP();
        carSpeedLimitView.yInDP = rootViewHeightInDP - truckSpeedLimitView.getHeightInDP();
        carSpeedLimitView.redraw();

        // Set x,y position in density-independent pixels relative to truckSpeedLimitView and carSpeedLimitView.
        drivingSpeedView.xInDP = marginInDP * 3 +
                truckSpeedLimitView.getWidthInDP() +
                carSpeedLimitView.getWidthInDP();
        drivingSpeedView.yInDP = rootViewHeightInDP - truckSpeedLimitView.getHeightInDP();
        drivingSpeedView.redraw();

        // Set x,y position in density-independent pixels relative to truckSpeedLimitView.
        truckRestrictionView.xInDP = marginInDP;
        truckRestrictionView.yInDP = rootViewHeightInDP -
                                     truckSpeedLimitView.getHeightInDP() -
                                     truckRestrictionView.getHeightInDP() - marginInDP * 2;
        truckRestrictionView.redraw();
    }

    private int getHeightInDP(View rootView) {
        float density = getResources().getDisplayMetrics().density;
        return (int) (rootView.getHeight() / density);
    }

    // Allow simple communication with the example class and update our UI based
    // on the events we get from the visual navigator.
    private void setupEventHandling() {
        truckGuidanceExample.setUICallback(new UICallback() {
            @Override
            public void onTruckSpeedLimit(String speedLimit) {
                truckSpeedLimitView.setSpeedLimit(speedLimit);
            }

            @Override
            public void onCarSpeedLimit(String speedLimit) {
                carSpeedLimitView.setSpeedLimit(speedLimit);
            }

            @Override
            public void onDrivingSpeed(String drivingSpeed) {
                drivingSpeedView.setSpeedLimit(drivingSpeed);
            }

            @Override
            public void onTruckRestrictionWarning(String description) {
                truckRestrictionView.onTruckRestrictionWarning(description);
            }

            @Override
            public void onHideTruckRestrictionWarning() {
                truckRestrictionView.onHideTruckRestrictionWarning();
            }
        });
    }

    public void onShowRouteButtonClicked(View view) {
        truckGuidanceExample.onShowRouteButtonClicked();
    }

    public void onStartStopButtonClicked(View view) {
        truckGuidanceExample.onStartStopButtonClicked();
    }

    public void onClearMapButtonClicked(View view) {
        truckGuidanceExample.onClearMapButtonClicked();
    }

    public void onTrackingButtonClicked(View view) {
        truckGuidanceExample.onTrackingButtonClicked();
    }

    public void addWeightButtonClicked(View view) {
        truckGuidanceExample.onSpeedButtonClicked();
    }

    @Override
    protected void onPause() {
        mapView.onPause();
        super.onPause();
    }

    @Override
    protected void onResume() {
        mapView.onResume();
        super.onResume();
    }

    @Override
    protected void onDestroy() {
        mapView.onDestroy();
        disposeHERESDK();
        super.onDestroy();
    }

    @Override
    protected void onSaveInstanceState(@NonNull Bundle outState) {
        mapView.onSaveInstanceState(outState);
        super.onSaveInstanceState(outState);
    }

    private void disposeHERESDK() {
        if (truckGuidanceExample != null) {
            truckGuidanceExample.dispose();
        }

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
}
