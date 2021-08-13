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
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.design.widget.NavigationView;
import android.support.v4.view.GravityCompat;
import android.support.v4.widget.DrawerLayout;
import android.support.v7.app.ActionBarDrawerToggle;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.Toolbar;
import android.util.Log;
import android.view.MenuItem;

import com.here.mapitems.PermissionsRequestor.ResultListener;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.mapviewlite.Camera;
import com.here.sdk.mapviewlite.MapScene;
import com.here.sdk.mapviewlite.MapStyle;
import com.here.sdk.mapviewlite.MapViewLite;

public class MainActivity extends AppCompatActivity
        implements NavigationView.OnNavigationItemSelectedListener {

    private static final String TAG = MainActivity.class.getSimpleName();

    private PermissionsRequestor permissionsRequestor;
    private MapViewLite mapView;
    private MapItemsExample mapItemsExample;
    private MapObjectsExample mapObjectsExample;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Get a Toolbar instance
        Toolbar toolbar = (Toolbar) findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);

        // Get a DrawerLayout instance
        DrawerLayout drawer =
                (DrawerLayout) findViewById(R.id.drawer_layout);
        ActionBarDrawerToggle toggle = new ActionBarDrawerToggle(
                this, drawer, toolbar,
                R.string.drawer_open,
                R.string.drawer_close);
        getSupportActionBar().setTitle(getString(R.string.app_name));
        drawer.addDrawerListener(toggle);
        toggle.syncState();

        // Get a NavigationView instance
        NavigationView navigationView = (NavigationView) findViewById(R.id.navigation_view);
        navigationView.setNavigationItemSelectedListener(this);

        // Get a MapView instance from layout
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        handleAndroidPermissions();
    }

    private void handleAndroidPermissions() {
        permissionsRequestor = new PermissionsRequestor(this);
        permissionsRequestor.request(new ResultListener(){

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
        // Load a scene from the SDK to render the map with a map style.
        mapView.getMapScene().loadScene(MapStyle.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapScene.ErrorCode errorCode) {
                if (errorCode == null) {
                    mapItemsExample = new MapItemsExample(MainActivity.this, mapView);
					mapObjectsExample = new MapObjectsExample(mapView);

                    Camera mapViewCamera = mapView.getCamera();
                    mapViewCamera.setTarget(new GeoCoordinates(52.530932, 13.384915));
                    mapViewCamera.setZoomLevel(13);
                } else {
                    Log.d(TAG, "onLoadScene failed: " + errorCode.toString());
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
    public boolean onNavigationItemSelected(@NonNull MenuItem menuItem) {

        int id = menuItem.getItemId();

        switch(menuItem.getItemId()){
            case R.id.menu_marker_anchored:
                mapItemsExample.showAnchoredMapMarkers();
                break;
            case R.id.menu_menu_marker_centered:
                mapItemsExample.showCenteredMapMarkers();
                break;
            case R.id.menu_objects_polyline:
                mapObjectsExample.showMapPolyline();
                break;
            case R.id.menu_menu_objects_polygon:
                mapObjectsExample.showMapPolygon();
                break;
            case R.id.menu_menu_objects_circle:
                mapObjectsExample.showMapCircle();
                break;
            case R.id.menu_clear:
                mapItemsExample.clearMap();
                mapObjectsExample.clearMap();
                break;
        }

        DrawerLayout drawer = (DrawerLayout) findViewById(R.id.drawer_layout);
        drawer.closeDrawer(GravityCompat.START);
        return true;
    }
}
