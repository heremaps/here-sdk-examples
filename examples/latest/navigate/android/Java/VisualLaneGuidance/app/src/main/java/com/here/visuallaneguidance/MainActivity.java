/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

package com.here.visuallaneguidance;

import android.content.Context;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.engine.AuthenticationMode;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapSceneLoadOptions;
import com.here.sdk.mapview.MapSceneLoadOptionsBuilder;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.units.core.utils.EnvironmentLogger;
import com.here.sdk.units.core.utils.PermissionsRequestor;
import com.here.sdk.units.core.views.UnitDialog;
import com.here.sdk.units.popupmenu.PopupMenuUnit;
import com.here.sdk.units.popupmenu.PopupMenuView;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();

    private final EnvironmentLogger environmentLogger = new EnvironmentLogger();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private VisualLaneGuidanceExample visualLaneGuidanceExample;
    private TextView infoTextView;
    private MapScheme currentMapScheme = MapScheme.CLUSTER_DAY;

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
        infoTextView = findViewById(R.id.status_text);

        setUpPopupMenu();
        setUpPopupSettings();
        handleAndroidPermissions();

        UnitDialog unitDialog = new UnitDialog(this);
        unitDialog.showDialog(
            "Visual lane guidance example",
            "This app shows automatic HD/SD transitions and automotive camera behavior during guidance.");
    }

    private void initializeHERESDK() {
        // Set your credentials for the HERE SDK. Note that this app requires the Navigate license and a separate license to enable visual lane guidance.
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

    private void setUpPopupMenu() {
        Map<String, Runnable> menuItems = new LinkedHashMap<>();
        menuItems.put("Calculate route in Chicago", this::calculateChicagoRoute);
        menuItems.put("Calculate route in Berlin", this::calculateBerlinRoute);
        menuItems.put("Start guidance", () -> visualLaneGuidanceExample.startGuidance());
        menuItems.put("Stop guidance", () -> visualLaneGuidanceExample.stopGuidance());

        PopupMenuView popupMenuView = findViewById(R.id.popup_menu_button);
        PopupMenuUnit popupMenuUnit = popupMenuView.popupMenuUnit;
        popupMenuUnit.setMenuContent("Menu", menuItems);
    }

    private void setUpPopupSettings() {
        Map<String, Runnable> menuItems = new LinkedHashMap<>();

        menuItems.put("Use Transition camera behavior", () -> setCameraMode(
                () -> visualLaneGuidanceExample.useTransitionCameraBehavior(),
                "Using TransitionCameraBehavior."));
        menuItems.put("Use Automotive camera behavior", () -> setCameraMode(
                () -> visualLaneGuidanceExample.useAutomotiveCameraBehavior(),
                "Using AutomotiveCameraBehavior."));

        menuItems.put("Use NORMAL DAY map scheme", () -> setMapScheme(
                MapScheme.NORMAL_DAY,
                "Map scheme switched to NORMAL DAY."));
        menuItems.put("Use CLUSTER_DAY map scheme", () -> setMapScheme(
                MapScheme.CLUSTER_DAY,
                "Map scheme switched to CLUSTER DAY."));

        PopupMenuView popupMenuView = findViewById(R.id.popup_settings_button);
        PopupMenuUnit popupMenuUnit = popupMenuView.popupMenuUnit;
        popupMenuUnit.setMenuContent("Settings", menuItems);
    }

    private void setMapScheme(MapScheme mapScheme, String toastMessage) {
        currentMapScheme = mapScheme;

        loadMapScene();
        showToast(toastMessage);
    }

    private void setCameraMode(CameraAction action, String toastMessage) {
        action.execute();
        updateInfoText();
        showToast(toastMessage);
    }

    private void showToast(String message) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }

    // Functional interface used to pass camera mode switch actions as lambdas.
    @FunctionalInterface
    private interface CameraAction {
        void execute();
    }

    private void updateInfoText() {
        if (visualLaneGuidanceExample == null) {
            infoTextView.setText("Camera: not initialized | Map scheme: " + getMapSchemeLabel(currentMapScheme)
                    + " | Route: not selected");
            return;
        }

        infoTextView.setText("Camera: "
                + visualLaneGuidanceExample.getCameraBehaviorStatus()
                + " | Map scheme: "
                + getMapSchemeLabel(currentMapScheme)
                + " | Route: "
                + getRouteLabel(visualLaneGuidanceExample.getSelectedRoute()));
    }

    private void calculateChicagoRoute() {
        if (visualLaneGuidanceExample == null) {
            return;
        }

        visualLaneGuidanceExample.calculateChicagoRoute();
        updateInfoText();
    }

    private void calculateBerlinRoute() {
        if (visualLaneGuidanceExample == null) {
            return;
        }

        visualLaneGuidanceExample.calculateBerlinRoute();
        updateInfoText();
    }

    private String getMapSchemeLabel(MapScheme mapScheme) {
        if (mapScheme == MapScheme.NORMAL_DAY) {
            return "NORMAL DAY";
        }

        if (mapScheme == MapScheme.CLUSTER_DAY) {
            return "CLUSTER DAY";
        }

        return mapScheme.name();
    }

    private String getRouteLabel(VisualLaneGuidanceExample.RouteSelection routeSelection) {
        if (routeSelection == VisualLaneGuidanceExample.RouteSelection.CHICAGO) {
            return "Chicago";
        }

        if (routeSelection == VisualLaneGuidanceExample.RouteSelection.BERLIN) {
            return "Berlin";
        }

        return "not selected";
    }

    // Note that this example app does not require any special permissions.
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
        permissionsRequestor.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    private void loadMapScene() {
        MapSceneLoadOptions mapSceneLoadOptions;

        try {
            mapSceneLoadOptions = new MapSceneLoadOptionsBuilder()
                    .withMapScheme(currentMapScheme)
                    .build();
        } catch (MapSceneLoadOptionsBuilder.InstantiationException e) {
            throw new RuntimeException(
                    "Initialization of MapSceneLoadOptions failed: "
                            + e.error.errorDescription
            );
        }

        // Load a scene from the HERE SDK to render the map with a map scheme and selected map features.
        mapView.getMapScene().loadScene(mapSceneLoadOptions, mapError -> {
            if (mapError == null) {
                if (visualLaneGuidanceExample == null) {
                    double distanceInMeters = 1000 * 10;
                    MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters);
                    mapView.getCamera().lookAt(
                            new GeoCoordinates(37.53931,-122.05891), mapMeasureZoom);

                    visualLaneGuidanceExample = new VisualLaneGuidanceExample(MainActivity.this, mapView);
                }
                updateInfoText();
            } else {
                Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
            }
        });
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
        super.onDestroy();
        if (isFinishing()) {
            disposeHERESDK();
        }
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
