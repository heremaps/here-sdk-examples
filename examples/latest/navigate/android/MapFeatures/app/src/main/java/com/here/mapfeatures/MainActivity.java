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
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;

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

import java.util.Map;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();

    private PermissionsRequestor permissionsRequestor;
    private MapView mapViewGlobe, mapViewWebMercator;
    private MapFeaturesExample mapFeaturesExample;
    private MapSchemesExample mapSchemesExample;
    private MapScene mapScene;
    private Button webMercatorButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        // Get a MapView instance from layout
        mapViewGlobe = findViewById(R.id.map_view_globe);
        mapViewGlobe.setVisibility(MapView.VISIBLE);
        mapViewWebMercator = findViewById(R.id.map_view_web_mercator);
        webMercatorButton = findViewById(R.id.web_mercator_button);
        mapViewWebMercator.setVisibility(MapView.GONE);
        mapViewWebMercator.onCreate(savedInstanceState);
        mapViewGlobe.onCreate(savedInstanceState);

        webMercatorButton.setOnClickListener(v -> {
            changeMapProjection();
        });

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

    private MapView getCurrentVisibleMapView() {
        return mapViewGlobe.getVisibility() == View.VISIBLE ? mapViewGlobe : mapViewWebMercator;
    }

    private void changeMapProjection() {
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

        webMercatorButton.setText(isGlobeVisible ? "Switch to Globe" : "Switch to Web Mercator");
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

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater=getMenuInflater();
        inflater.inflate(R.menu.map_option_menu, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(@NonNull MenuItem item) {
        MapView currentMapView = getCurrentVisibleMapView();
        switch (item.getItemId()){
            // Map Schemes:
            case R.id.hybrid_day_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.HYBRID_DAY);
                return true;
            case R.id.hybrid_night_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.HYBRID_NIGHT);
                return true;
            case R.id.lite_day_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.LITE_DAY);
                return true;
            case R.id.lite_night_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.LITE_NIGHT);
                return true;
            case R.id.lite_hybrid_night_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.LITE_HYBRID_NIGHT);
                return true;
            case R.id.lite_hybrid_day_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.LITE_HYBRID_DAY);
                return true;
            case R.id.logistics_day_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.LOGISTICS_DAY);
                return true;
            case R.id.logistics_night_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.LOGISTICS_NIGHT);
                return true;
            case R.id.logistics_hybrid_day_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.LOGISTICS_HYBRID_DAY);
                return true;
            case R.id.logistics_hybrid_night_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.LOGISTICS_HYBRID_NIGHT);
                return true;
            case R.id.normal_day_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.NORMAL_DAY);
                return true;
            case R.id.normal_night_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.NORMAL_NIGHT);
                return true;
            case R.id.road_network_day_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.ROAD_NETWORK_DAY);
                return true;
            case R.id.road_network_night_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.ROAD_NETWORK_NIGHT);
                return true;
            case R.id.satellite_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.SATELLITE);
                return true;
            case R.id.topo_day_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.TOPO_DAY);
                return true;
            case R.id.topo_night_menu_item:
                mapSchemesExample.loadSchemeForCurrentView(currentMapView, MapScheme.TOPO_NIGHT);
                return true;

            // Map Features:
            case R.id.clear_menu_item:
                mapFeaturesExample.disableFeatures();
                return true;
            case R.id.building_footprints_menu_item:
                mapFeaturesExample.enableBuildingFootprints();
                return true;
            case R.id.congestion_zone_menu_item:
                mapFeaturesExample.enableCongestionZones();
                return true;
            case R.id.environmental_zones_menu_item:
                mapFeaturesExample.enableEnvironmentalZones();
                return true;
            case R.id.extruded_buildings_menu_item:
                mapFeaturesExample.enableExtrudedBuildings();
                return true;
            case R.id.landmarks_textured_menu_item:
                mapFeaturesExample.enableLandmarksTextured();
                return true;
            case R.id.landmarks_textureless_menu_item:
                mapFeaturesExample.enableLandmarksTextureless();
                return true;
            case R.id.safety_cameras_menu_item:
                mapFeaturesExample.enableSafetyCameras();
                return true;
            case R.id.shadows_menu_item:
                mapFeaturesExample.enableShadows();
                return true;
            case R.id.terrain_hillshade_menu_item:
                mapFeaturesExample.enableTerrainHillShade();
                return true;
            case R.id.terrain_3D_menu_item:
                mapFeaturesExample.enableTerrain3D();
                return true;
            case R.id.traffic_flow_with_freeflow_menu_item:
                mapFeaturesExample.enableTrafficFlowWithFreeFlow();
                return true;
            case R.id.traffic_flow_without_freeflow_menu_item:
                mapFeaturesExample.enableTrafficFlowWithoutFreeFlow();
                return true;
            case R.id.traffic_incidents_menu_item:
                mapFeaturesExample.enableTrafficIncidents();
                return true;
            case R.id.vehicle_restrictions_active_menu_item:
                mapFeaturesExample.enableVehicleRestrictionsActive();
                return true;
            case R.id.vehicle_restrictions_active_inactive_menu_item:
                mapFeaturesExample.enableVehicleRestrictionsActiveAndInactive();
                return true;
            case R.id.vehicle_restrictions_active_inactive_diff_menu_item:
                mapFeaturesExample.enableVehicleRestrictionsActiveAndInactiveDiff();
                return true;
            case R.id.road_exit_labels_menu_item:
                mapFeaturesExample.enableRoadExitLabels();
                return true;
            case R.id.road_exit_labels_numbers_menu_item:
                mapFeaturesExample.enableRoadExitLabelsNumbersOnly();
                return true;
            case R.id.ambient_occlusion_menu_item:
                mapFeaturesExample.enableAmbientOcclusion();
                return true;
            case R.id.contours_menu_item:
                mapFeaturesExample.enableContours();
                return true;
            case R.id.low_speed_zones_menu_item:
                mapFeaturesExample.enableLowSpeedZones();
                return true;
            default:
                return super.onOptionsItemSelected(item);
        }
    }
}

