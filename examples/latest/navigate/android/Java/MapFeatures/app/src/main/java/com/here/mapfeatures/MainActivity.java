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

package com.here.mapfeatures;

import android.content.Context;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.constraintlayout.widget.ConstraintLayout;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.engine.AuthenticationMode;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapProjection;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.MapViewOptions;
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
    private MapView mapViewGlobe, mapViewWebMercator;
    private MapFeaturesExample mapFeaturesExample;
    private MapSchemesExample mapSchemesExample;
    private MapViewOptions mapViewOptions;
    private ConstraintLayout constraintLayout;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Log application and device details.
        // It expects a string parameter that describes the application source language.
        environmentLogger.logEnvironment("Java");

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        // Grab the root ConstraintLayout defined in activity_main.xml.
        // We will dynamically add two MapView instances into it.
        constraintLayout = findViewById(R.id.main);

        mapViewOptions = new MapViewOptions();

        // Create MapView with Globe MapProjection and add it to the root ConstraintLayout
        mapViewOptions.projection = MapProjection.GLOBE;
        mapViewGlobe = new MapView(this, mapViewOptions);
        constraintLayout.addView(mapViewGlobe, 0);

        // Initialize MapView using the Web Mercator projection and add it to the root layout.
        // Keep it hidden initially; only the globe is shown on start-up.
        // Visibility can be toggled when the user taps the "Web Mercator" button.
        mapViewOptions.projection = MapProjection.WEB_MERCATOR;
        mapViewWebMercator = new MapView(this, mapViewOptions);
        mapViewWebMercator.setVisibility(MapView.GONE);
        constraintLayout.addView(mapViewWebMercator, 1);

        mapViewWebMercator.onCreate(savedInstanceState);
        mapViewGlobe.onCreate(savedInstanceState);

        // Use the HERE SDK Units library for a simple popup menu, see libs folder.
        setMapFeaturesMenu();
        setMapSchemesMenu();

        handleAndroidPermissions();
    }

    public void onWebMercatorButtonClicked(View view) {
        changeMapProjection((Button) view);
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

    private MapView getCurrentVisibleMapView() {
        return mapViewGlobe.getVisibility() == View.VISIBLE ? mapViewGlobe : mapViewWebMercator;
    }

    private void changeMapProjection(Button webMercatorButton) {
        Map<String, String> enabledFeatures = mapFeaturesExample.getEnabledFeatures();
        boolean isGlobeVisible = mapViewGlobe.getVisibility() == View.VISIBLE;

        MapView mapViewToHide = isGlobeVisible ? mapViewGlobe : mapViewWebMercator;
        MapView mapViewToShow = isGlobeVisible ? mapViewWebMercator : mapViewGlobe;

        mapViewToHide.setVisibility(View.GONE);
        mapViewToShow.setVisibility(View.VISIBLE);

        if (mapSchemesExample != null) {
            MapScheme currentScheme = mapSchemesExample.getCurrentMapScheme();
            if (currentScheme == null) {
                // Load a default scheme if none is currently set
                currentScheme = MapScheme.NORMAL_DAY;
            }
            mapSchemesExample.loadSchemeForCurrentView(mapViewToShow, currentScheme);
        }

        if (mapFeaturesExample != null) {
            mapFeaturesExample = new MapFeaturesExample(mapViewToShow.getMapScene());
            mapFeaturesExample.applyEnabledFeaturesForMapScene(mapViewToShow.getMapScene());
        }

        for (Map.Entry<String, String> feature : enabledFeatures.entrySet()) {
            mapFeaturesExample.enableFeature(feature.getKey(), feature.getValue());
        }

        webMercatorButton.setText(isGlobeVisible ? "  Switch to Globe  " : "  Switch to Web Mercator  ");
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
        MapView currentMapView = getCurrentVisibleMapView();
        currentMapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    mapSchemesExample = new MapSchemesExample();
                    mapFeaturesExample = new MapFeaturesExample(currentMapView.getMapScene());
                    mapFeaturesExample.applyEnabledFeaturesForMapScene(currentMapView.getMapScene());

                    double distanceInMeters = 1000 * 20;
                    MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters);
                    currentMapView.getCamera().lookAt(new GeoCoordinates(52.51760485151816, 13.380312380535472), mapMeasureZoom);
                } else {
                    Log.d(TAG, "onLoadScene failed: " + mapError);
                }
            }
        });
    }

    @Override
    protected void onPause() {
        mapViewGlobe.onPause();
        super.onPause();
    }

    @Override
    protected void onResume() {
        mapViewGlobe.onResume();
        super.onResume();
    }

    @Override
    protected void onDestroy() {
        mapViewGlobe.onDestroy();
        disposeHERESDK();
        super.onDestroy();
    }

    @Override
    protected void onSaveInstanceState(@NonNull Bundle outState) {
        mapViewGlobe.onSaveInstanceState(outState);
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

    private void setMapSchemesMenu() {
        // Define menu items with the code that should be executed when clicking on the item.
        Map<String, MapScheme> schemeMap = new LinkedHashMap<>();
        schemeMap.put("Lite Night", MapScheme.LITE_NIGHT);
        schemeMap.put("Hybrid Day", MapScheme.HYBRID_DAY);
        schemeMap.put("Hybrid Night", MapScheme.HYBRID_NIGHT);
        schemeMap.put("Lite Day", MapScheme.LITE_DAY);
        schemeMap.put("Lite Hybrid Day", MapScheme.LITE_HYBRID_DAY);
        schemeMap.put("Lite Hybrid Night", MapScheme.LITE_HYBRID_NIGHT);
        schemeMap.put("Logistics Day", MapScheme.LOGISTICS_DAY);
        schemeMap.put("Logistics Hybrid Day", MapScheme.LOGISTICS_HYBRID_DAY);
        schemeMap.put("Logistics Night", MapScheme.LOGISTICS_NIGHT);
        schemeMap.put("Logistics Hybrid Night", MapScheme.LOGISTICS_HYBRID_NIGHT);
        schemeMap.put("Normal Day", MapScheme.NORMAL_DAY);
        schemeMap.put("Normal Night", MapScheme.NORMAL_NIGHT);
        schemeMap.put("Road Network Day", MapScheme.ROAD_NETWORK_DAY);
        schemeMap.put("Road Network Night", MapScheme.ROAD_NETWORK_NIGHT);
        schemeMap.put("Satellite", MapScheme.SATELLITE);
        schemeMap.put("Topo Day", MapScheme.TOPO_DAY);
        schemeMap.put("Topo Night", MapScheme.TOPO_NIGHT);

        Map<String, Runnable> menuItems = new LinkedHashMap<>();
        for (Map.Entry<String, MapScheme> entry : schemeMap.entrySet()) {
            menuItems.put(entry.getKey(), () -> {
                mapSchemesExample.loadSchemeForCurrentView(getCurrentVisibleMapView(), entry.getValue());
                mapFeaturesExample.applyEnabledFeaturesForMapScene(getCurrentVisibleMapView().getMapScene());
            });
        }

        PopupMenuView popupMenuView = findViewById(R.id.menu_button_map_schemes);
        PopupMenuUnit popupMenuUnit = popupMenuView.popupMenuUnit;
        popupMenuUnit.setMenuContent("Map Schemes", menuItems);
    }

    private void setMapFeaturesMenu() {
        // Define menu items with the code that should be executed when clicking on the item.
        Map<String, Runnable> mapFeaturesMenuItems = new LinkedHashMap<>();
        mapFeaturesMenuItems.put("Clear Map Features", () -> mapFeaturesExample.disableFeatures());
        mapFeaturesMenuItems.put("Building Footprints", () -> mapFeaturesExample.enableBuildingFootprints());
        mapFeaturesMenuItems.put("Congestion Zone", () -> mapFeaturesExample.enableCongestionZones());
        mapFeaturesMenuItems.put("Environmental Zones", () -> mapFeaturesExample.enableEnvironmentalZones());
        mapFeaturesMenuItems.put("Extruded Buildings", () -> mapFeaturesExample.enableExtrudedBuildings());
        mapFeaturesMenuItems.put("Landmarks Textured", () -> mapFeaturesExample.enableLandmarksTextured());
        mapFeaturesMenuItems.put("Landmarks Textureless", () -> mapFeaturesExample.enableLandmarksTextureless());
        mapFeaturesMenuItems.put("Safety Cameras", () -> mapFeaturesExample.enableSafetyCameras());
        mapFeaturesMenuItems.put("Shadows", () -> {
            Toast.makeText(this, "Enabled building shadows for non-satellite-based schemes.", Toast.LENGTH_SHORT).show();
            mapFeaturesExample.enableShadows();
        });
        mapFeaturesMenuItems.put("Terrain Hillshade", () -> mapFeaturesExample.enableTerrainHillShade());
        mapFeaturesMenuItems.put("Terrain 3D", () -> mapFeaturesExample.enableTerrain3D());
        mapFeaturesMenuItems.put("Ambient Occlusion", () -> mapFeaturesExample.enableAmbientOcclusion());
        mapFeaturesMenuItems.put("Contours", () -> mapFeaturesExample.enableContours());
        mapFeaturesMenuItems.put("Low Speed Zones", () -> mapFeaturesExample.enableLowSpeedZones());
        mapFeaturesMenuItems.put("Traffic Flow with Free Flow", () -> mapFeaturesExample.enableTrafficFlowWithFreeFlow());
        mapFeaturesMenuItems.put("Traffic Flow without Free Flow", () -> mapFeaturesExample.enableTrafficFlowWithoutFreeFlow());
        mapFeaturesMenuItems.put("Traffic Incidents", () -> mapFeaturesExample.enableTrafficIncidents());
        mapFeaturesMenuItems.put("Vehicle Restrictions Active", () -> mapFeaturesExample.enableVehicleRestrictionsActive());
        mapFeaturesMenuItems.put("Vehicle Restrictions Active/Inactive", () -> mapFeaturesExample.enableVehicleRestrictionsActiveAndInactive());
        mapFeaturesMenuItems.put("Vehicle Restrictions Active/Inactive Diff", () -> mapFeaturesExample.enableVehicleRestrictionsActiveAndInactiveDiff());
        mapFeaturesMenuItems.put("Road Exit Labels", () -> mapFeaturesExample.enableRoadExitLabels());
        mapFeaturesMenuItems.put("Road Exit Labels Numbers Only", () -> mapFeaturesExample.enableRoadExitLabelsNumbersOnly());

        PopupMenuView popupMenuView = findViewById(R.id.menu_button_map_features);
        PopupMenuUnit popupMenuUnit = popupMenuView.popupMenuUnit;
        popupMenuUnit.setMenuContent("Map Features", mapFeaturesMenuItems);
    }
}

