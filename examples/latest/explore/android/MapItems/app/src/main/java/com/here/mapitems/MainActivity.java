/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

import android.os.Bundle;

import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapError;
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
        setContentView(R.layout.activity_main);

        // Get a MapView instance from layout
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        handleAndroidPermissions();
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
                    mapView.getCamera().lookAt(new GeoCoordinates(52.51760485151816, 13.380312380535472), distanceInMeters);
                } else {
                    Log.d(TAG, "onLoadScene failed: " + mapError.toString());
                }
            }
        });
    }

    @Override
    protected void onPause() {
        super.onPause();
        mapView.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        mapView.onResume();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        mapView.onDestroy();
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
            case R.id.flat_menu_item:
                mapItemsExample.showFlatMarker();
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
