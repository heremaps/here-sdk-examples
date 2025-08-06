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
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.widget.Toast;

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

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();

    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private MapItemsExample mapItemsExample;
    private MapObjectsExample mapObjectsExample;
    private MapViewPinExample mapViewPinExample;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        // Get a MapView instance from layout
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

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
                    mapObjectsExample = new MapObjectsExample(mapView);
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

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater=getMenuInflater();
        inflater.inflate(R.menu.map_option_menu, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(@NonNull MenuItem item) {
        switch (item.getItemId()){
            // Map Objects:
            case R.id.arrow_menu_item:
                mapObjectsExample.showMapArrow();
                return true;
            case R.id.circle_menu_item:
                mapObjectsExample.showMapCircle();
                return true;
            case R.id.polygon_menu_item:
                mapObjectsExample.showMapPolygon();
                return true;
            case R.id.polyline_menu_item:
                mapObjectsExample.showMapPolyline();
                return true;
            case R.id.gradient_polyline_menu_item:
                mapObjectsExample.showGradientMapPolyLine();
                return true;
            case R.id.polyline_enable_visibility:
                Toast.makeText(this, "Enabled visibility ranges for MapPolyLine", Toast.LENGTH_SHORT).show();
                mapObjectsExample.enableVisibilityRangesForPolyline();
                return true;
            case R.id.clear_map_objects_menu_item:
                mapObjectsExample.clearMapButtonClicked();
                return true;

            // Map Marker:
            case R.id.anchored_2D_menu_item:
                mapItemsExample.showAnchoredMapMarkers();
                return true;
            case R.id.centered_2D_menu_item:
                mapItemsExample.showCenteredMapMarkers();
                return true;
            case R.id.map_marker_with_text:
                mapItemsExample.showMapMarkerWithText();
                return true;
            case R.id.map_marker_cluster_menu_item:
                mapItemsExample.showMapMarkerCluster();
                return true;
            case R.id.location_ped_menu_item:
                mapItemsExample.showLocationIndicatorPedestrian();
                return true;
            case R.id.location_nav_menu_item:
                mapItemsExample.showLocationIndicatorNavigation();
                return true;
            case R.id.active_inactive_menu_item:
                mapItemsExample.toggleActiveStateForLocationIndicator();
                return true;
            case R.id.flat_menu_item_image:
                mapItemsExample.showFlatMapMarker();
                return true;
            case R.id.flat_menu_item:
                mapItemsExample.show2DTexture();
                return true;
            case R.id.obj_3D_menu_item:
                mapItemsExample.showMapMarker3D();
                return true;
            case R.id.clear_map_marker_menu_item:
                mapItemsExample.clearMap();
                return true;

            // MapView Pins:
            case R.id.default_menu_item:
                mapViewPinExample.showMapViewPin();
                return true;
            case R.id.anchored_menu_item:
                mapViewPinExample.showAnchoredMapViewPin();
                return true;
            case R.id.clear_map_view_pins_menu_item:
                mapViewPinExample.clearMap();
                return true;

            default:
                return super.onOptionsItemSelected(item);
        }
    }
}
