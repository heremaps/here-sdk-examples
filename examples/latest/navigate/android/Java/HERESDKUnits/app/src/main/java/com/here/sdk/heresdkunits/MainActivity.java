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

package com.here.sdk.heresdkunits;

import android.content.Context;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.engine.AuthenticationMode;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.units.compass.CompassUnit;
import com.here.sdk.units.compass.CompassView;
import com.here.sdk.units.core.utils.PermissionsRequestor;
import com.here.sdk.units.core.utils.EnvironmentLogger;
import com.here.sdk.units.core.views.UnitDialog;
import com.here.sdk.units.mapruler.MapScaleView;
import com.here.sdk.units.mapswitcher.MapSwitcherUnit;
import com.here.sdk.units.mapswitcher.MapSwitcherView;
import com.here.sdk.units.popupmenu.PopupMenuUnit;
import com.here.sdk.units.popupmenu.PopupMenuView;
import com.here.sdk.units.speedlimit.SpeedLimitUnit;
import com.here.sdk.units.speedlimit.SpeedLimitView;
import com.here.sdk.units.cityselector.CitySelectorView;
import com.here.sdk.units.cityselector.CitySelectorUnit;

import java.util.LinkedHashMap;
import java.util.Map;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private EnvironmentLogger environmentLogger = new EnvironmentLogger();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        // Before creating a MapView instance please make sure that the HERE SDK is initialized.
        // Since in this example we inflate the MapView from a layout, make sure to initialize
        // the HERE SDK before calling setContentView(...).
        initializeHERESDK();

        // Log application and device details.
        // It expects a string parameter that describes the application source language.
        environmentLogger.logEnvironment("Java");

        setContentView(R.layout.activity_main);

        // Get a MapView instance from layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        // Set HERE SDK Units.
        setupPopupMenuUnit1();
        setupPopupMenuUnit2();
        setupCitySelectorUnit();
        setupMapSwitcher();
        setupMapScaleRuler();
        setupCompass();
        setupSpeedLimit();

        showUnitDialog();

        // Note that for this app handling of permissions is optional as no sensitive permissions
        // are required.
        handleAndroidPermissions();
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

    private void setupPopupMenuUnit1() {
        // Define menu items with the code that should be executed when clicking on the item.
        Map<String, Runnable> menuItems = new LinkedHashMap<>();
        menuItems.put("Item 1", () -> Log.d("Menu", "Item 1 clicked"));
        menuItems.put("Item 2", () -> Log.d("Menu", "Item 2 clicked"));

        PopupMenuView popupMenuView = findViewById(R.id.popup_menu_button1);
        PopupMenuUnit popupMenuUnit = popupMenuView.popupMenuUnit;
        popupMenuUnit.setMenuContent("Menu 1", menuItems);
    }

    private void setupMapScaleRuler() {
        MapScaleView mapScaleView = findViewById(R.id.map_ruler);
        mapScaleView.setup(mapView);
    }

    private void setupPopupMenuUnit2() {
        // Define menu items with the code that should be executed when clicking on the item.
        Map<String, Runnable> menuItems = new LinkedHashMap<>();
        menuItems.put("Item 3", () -> Log.d("Menu", "Item 3 clicked"));
        menuItems.put("Item 4", () -> Log.d("Menu", "Item 4 clicked"));

        PopupMenuView popupMenuView = findViewById(R.id.popup_menu_button2);
        PopupMenuUnit popupMenuUnit = popupMenuView.popupMenuUnit;
        popupMenuUnit.setMenuContent("Menu 2", menuItems);
    }

    private void setupCitySelectorUnit() {
        CitySelectorView citySelectorView = findViewById(R.id.city_selector);
        CitySelectorUnit citySelectorUnit = citySelectorView.citySelectorUnit;
        citySelectorUnit.setOnCitySelectedListener(new CitySelectorUnit.OnCitySelectedListener() {
            @Override
            public void onCitySelected(double latitude, double longitude, String cityName) {
                if (mapView != null) {
                    double distanceInMeters = 10000;
                    MapMeasure mapMeasureZoom = new MapMeasure(
                            MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters);
                    mapView.getCamera().lookAt(new GeoCoordinates(latitude, longitude), mapMeasureZoom);
                }
            }
        });
    }

    // Unit Dialog with title and description only.
    private void showUnitDialog() {
        UnitDialog unitDialog = new UnitDialog(MainActivity.this);
        unitDialog.showDialog("Note: Title", "This is scrollable long description message.");
    }

    private void setupMapSwitcher() {
        MapSwitcherView mapSwitcherView = findViewById(R.id.map_switcher);
        MapSwitcherUnit mapSwitcherUnit = mapSwitcherView.mapSwitcherUnit;
        mapSwitcherUnit.setup(mapView, getSupportFragmentManager());
    }

    private void setupSpeedLimit() {
        SpeedLimitView speedLimitView = findViewById(R.id.speed_limit);
        SpeedLimitUnit speedLimitUnit = speedLimitView.speedLimitUnit;
        speedLimitUnit.setLabel("Label");
        speedLimitUnit.setSpeedLimit("50");
    }

    private void setupCompass() {
        CompassView compassView = findViewById(R.id.compass);
        CompassUnit compassUnit = compassView.compassUnit;
        compassUnit.setup(mapView, getSupportFragmentManager());
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
        // The camera can be configured before or after a scene is loaded.
        double distanceInMeters = 1000 * 10;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters);
        mapView.getCamera().lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError != null) {
                    Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
                }
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
