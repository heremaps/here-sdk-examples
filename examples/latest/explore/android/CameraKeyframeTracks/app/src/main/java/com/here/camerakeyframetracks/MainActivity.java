/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

package com.here.camerakeyframetracks;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import android.annotation.SuppressLint;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;

import com.here.camerakeyframetracks.animations.CameraKeyframeTracksExample;
import com.here.camerakeyframetracks.animations.RouteAnimationExample;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.VisibilityState;
import com.here.sdk.routing.Route;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private CameraKeyframeTracksExample cameraKeyframeTracksExample;
    private RouteAnimationExample routeAnimationExample;

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

    @SuppressLint("MissingSuperCall")
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        permissionsRequestor.onRequestPermissionsResult(requestCode, grantResults);
    }

    private void loadMapScene() {
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    mapView.getMapScene().setLayerVisibility(MapScene.Layers.LANDMARKS, VisibilityState.VISIBLE);

                    double distanceInMeters = 5000;
                    mapView.getCamera().lookAt(new GeoCoordinates(40.7116777285189, -74.01248494562448), distanceInMeters);

                    cameraKeyframeTracksExample = new CameraKeyframeTracksExample(mapView);
                    routeAnimationExample = new RouteAnimationExample(mapView, MainActivity.this);
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
        switch (item.getItemId()) {
            // An animation that moves the camera along a route.
            case R.id.calculateRoute:
                routeAnimationExample.calculateRoute();
                return true;
            case R.id.startRouteAnimation:
                Route route = routeAnimationExample.calculateRoute();
                if (route != null) {
                    routeAnimationExample.animateRoute(route);
                } else {
                    routeAnimationExample.showDialog("Route Empty: ", "Please create a route.");
                }
                return true;
            case R.id.stopRouteAnimation:
            case R.id.stopToRouteAnimation:
                routeAnimationExample.stopRouteAnimation();
                return true;
            case R.id.clearMap:
                routeAnimationExample.clearRoute();
                return true;
            case R.id.startToRouteAnimation:
                // An animation that moves the camera to the route without keyframe tracks.
                route = routeAnimationExample.calculateRoute();
                if (route != null) {
                    routeAnimationExample.animateToRoute(route);
                } else {
                    routeAnimationExample.showDialog("Route Empty: ", "Please create a route.");
                }
                return true;
            case R.id.startNYCAnimation:
                // A camera animation through New York.
                cameraKeyframeTracksExample.startTripToNYC();
                return true;
            case R.id.stopNYCAnimation:
                cameraKeyframeTracksExample.stopTripToNYCAnimation();
                return true;
            default:
                return super.onOptionsItemSelected(item);
        }
    }
}
