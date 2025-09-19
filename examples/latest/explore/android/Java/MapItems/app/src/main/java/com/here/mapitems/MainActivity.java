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

package com.here.mapitems;

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
import com.here.sdk.units.popupmenu.PopupMenuUnit;
import com.here.sdk.units.popupmenu.PopupMenuView;

import java.util.LinkedHashMap;
import java.util.Map;
import com.here.sdk.units.core.utils.EnvironmentLogger;
import com.here.sdk.units.core.utils.PermissionsRequestor;

public class MainActivity extends AppCompatActivity {

    private EnvironmentLogger environmentLogger = new EnvironmentLogger();
    private static final String TAG = MainActivity.class.getSimpleName();

    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private MapObjectsExample mapObjectsExample;
    private MapItemsExample mapItemsExample;
    private MapViewPinExample mapViewPinExample;

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

        // Use the HERE SDK Units library for a simple popup menu, see libs folder.
        // HERE SDK Units are compiled with the HERESDKUnits app you can find in this repo.
        setMapObjectsMenu();
        setMapMarkerMenu();
        setMapViewPinsMenu();

        handleAndroidPermissions();
    }

    private void setMapObjectsMenu() {
        // Define menu items with the code that should be executed when clicking on the item.
        Map<String, Runnable> menuItems = new LinkedHashMap<>();
        menuItems.put("Polyline", () -> mapObjectsExample.showMapPolyline());
        menuItems.put("Polyline with gradients", () -> mapObjectsExample.showGradientMapPolyLine());
        menuItems.put("Polyline with visibility ranges", () -> mapObjectsExample.enableVisibilityRangesForPolyline());
        menuItems.put("Arrow", () -> mapObjectsExample.showMapArrow());
        menuItems.put("Polygon", () -> mapObjectsExample.showMapPolygon());
        menuItems.put("Circle", () -> mapObjectsExample.showMapCircle());
        menuItems.put("Clear map", () -> mapObjectsExample.clearMapButtonClicked());

        PopupMenuView popupMenuView = findViewById(R.id.menu_button_map_objects);
        PopupMenuUnit popupMenuUnit = popupMenuView.popupMenuUnit;
        popupMenuUnit.setMenuContent("Map objects", menuItems);
    }

    private void setMapMarkerMenu() {
        // Define menu items with the code that should be executed when clicking on the item.
        Map<String, Runnable> menuItems = new LinkedHashMap<>();
        menuItems.put("Anchored (2D)", () -> mapItemsExample.showAnchoredMapMarkers());
        menuItems.put("Centered (2D)", () -> mapItemsExample.showCenteredMapMarkers());
        menuItems.put("Marker with text", () -> mapItemsExample.showMapMarkerWithText());
        menuItems.put("MapMarkerCluster", () -> mapItemsExample.showMapMarkerCluster());
        menuItems.put("Location (PED)", () -> mapItemsExample.showLocationIndicatorPedestrian());
        menuItems.put("Location (NAV)", () -> mapItemsExample.showLocationIndicatorNavigation());
        menuItems.put("Active/Inactive", () -> mapItemsExample.toggleActiveStateForLocationIndicator());
        menuItems.put("Flat marker", () -> mapItemsExample.showFlatMapMarker());
        menuItems.put("2D texture", () -> mapItemsExample.show2DTexture());
        menuItems.put("3D object", () -> mapItemsExample.showMapMarker3D());
        menuItems.put("Clear map", () -> mapItemsExample.clearMap());

        PopupMenuView popupMenuView = findViewById(R.id.menu_button_map_markers);
        PopupMenuUnit popupMenuUnit = popupMenuView.popupMenuUnit;
        popupMenuUnit.setMenuContent("Map markers", menuItems);
    }

    private void setMapViewPinsMenu() {
        // Define menu items with the code that should be executed when clicking on the item.
        Map<String, Runnable> menuItems = new LinkedHashMap<>();
        menuItems.put("Default", () -> mapViewPinExample.showMapViewPin());
        menuItems.put("Anchored", () -> mapViewPinExample.showAnchoredMapViewPin());
        menuItems.put("Clear map", () -> mapViewPinExample.clearMap());

        PopupMenuView popupMenuView = findViewById(R.id.menu_button_mapview_pins);
        PopupMenuUnit popupMenuUnit = popupMenuView.popupMenuUnit;
        popupMenuUnit.setMenuContent("MapView pins", menuItems);
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
        permissionsRequestor.onRequestPermissionsResult(requestCode, grantResults);
    }

    private void loadMapScene() {
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    mapObjectsExample = new MapObjectsExample(MainActivity.this, mapView);
                    mapItemsExample = new MapItemsExample(MainActivity.this, mapView);
                    mapViewPinExample = new MapViewPinExample(MainActivity.this, mapView);

                    double distanceInMeters = 1000 * 20;
                    MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters);
                    mapView.getCamera().lookAt(new GeoCoordinates(52.51760485151816, 13.380312380535472), mapMeasureZoom);
                } else {
                    Log.d(TAG, "onLoadScene failed: " + mapError.toString());
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
