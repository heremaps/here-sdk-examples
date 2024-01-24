/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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

package com.here.rerouting;

import android.content.Context;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.here.sdk.core.engine.LogControl;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.routing.ManeuverAction;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();

    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private ReroutingExample reroutingExample;
    private ManeuverView maneuverView;
    private ManeuverIconProvider maneuverIconProvider;

    public interface UICallback {
        void onManeuverEvent(ManeuverAction action, String message1, String message2);
        void onRoadShieldEvent(Bitmap maneuverIcon);
        void onHideRoadShieldIcon();
        void onHideManeuverPanel();
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        // Get a MapView instance from layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        maneuverView = findViewById(R.id.maneuver_panel);
        maneuverIconProvider = new ManeuverIconProvider();
        maneuverIconProvider.loadManeuverIcons();

        handleAndroidPermissions();
    }

    private void initializeHERESDK() {
        // Disable any logs from HERE SDK.
        // Make sure to call this before initializing the HERE SDK.
        LogControl.disableLoggingToConsole();

        // Set your credentials for the HERE SDK.
        String accessKeyID = "YOUR_ACCESS_KEY_ID";
        String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
        SDKOptions options = new SDKOptions(accessKeyID, accessKeySecret);
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
                reroutingExample = new ReroutingExample(MainActivity.this, mapView);
                setupEventHandling();
            } else {
                Log.d(TAG, "Loading map failed: mapErrorCode: " + mapError.name());
            }
        });
    }

    // Allow simple communication with the example class and update our UI based
    // on the events we get from the visual navigator.
    private void setupEventHandling() {
        reroutingExample.setUICallback(new UICallback() {
            @Override
            public void onManeuverEvent(ManeuverAction action, String message1, String message2) {
                Bitmap maneuverIcon = maneuverIconProvider.getManeuverIcon(action);
                String maneuverIconText = action.name();
                maneuverView.onManeuverEvent(maneuverIcon, maneuverIconText, message1, message2);
            }

            @Override
            public void onRoadShieldEvent(Bitmap maneuverIcon) {
                maneuverView.onRoadShieldEvent(maneuverIcon);
            }

            @Override
            public void onHideRoadShieldIcon() {
                maneuverView.onHideRoadShieldIcon();
            }

            @Override
            public void onHideManeuverPanel() {
                maneuverView.onHideManeuverPanel();
            }
        });
    }

    public void onShowRouteButtonClicked(View view) {
        reroutingExample.onShowRouteButtonClicked();
    }

    public void onStartStopButtonClicked(View view) {
        reroutingExample.onStartStopButtonClicked();
    }

    public void onClearMapButtonClicked(View view) {
        reroutingExample.onClearMapButtonClicked();
    }

    public void onDeviationPointsButtonClicked(View view) {
        reroutingExample.onDefineDeviationPointsButtonClicked();
    }

    public void addSpeedButtonClicked(View view) {
        reroutingExample.onSpeedButtonClicked();
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
