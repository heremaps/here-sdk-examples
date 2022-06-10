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

package com.here.navigationquickstart;

import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import android.util.Log;

import com.here.navigationquickstart.PermissionsRequestor.ResultListener;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LocationListener;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.navigation.LocationSimulator;
import com.here.sdk.navigation.LocationSimulatorOptions;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.routing.CarOptions;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.Waypoint;

import java.util.ArrayList;
import java.util.Arrays;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;

    private RoutingEngine routingEngine;
    private VisualNavigator visualNavigator;
    private LocationSimulator locationSimulator;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Get a MapView instance from the layout.
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
        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    double distanceInMeters = 1000 * 10;
                    MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
                    mapView.getCamera().lookAt(
                            new GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);
                    startGuidanceExample();
                } else {
                    Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
                }
            }
        });
    }

    private void startGuidanceExample() {
        showDialog("Navigation Quick Start",
                "This app routes to the HERE office in Berlin. See logs for guidance information.");

        // We start by calculating a car route.
        calculateRoute();
    }

    private void calculateRoute() {
        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }

        Waypoint startWaypoint = new Waypoint(new GeoCoordinates(52.520798, 13.409408));
        Waypoint destinationWaypoint = new Waypoint(new GeoCoordinates(52.530905, 13.385007));

        routingEngine.calculateRoute(
                new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint)),
                new CarOptions(),
                (routingError, routes) -> {
                    if (routingError == null) {
                        Route route = routes.get(0);
                        startGuidance(route);
                      } else {
                        Log.e("Route calculation error", routingError.toString());
                    }
                });
    }

    private void startGuidance(Route route) {
        try {
            // Without a route set, this starts tracking mode.
            visualNavigator = new VisualNavigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of VisualNavigator failed: " + e.error.name());
        }

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator.startRendering(mapView);

        // Hook in one of the many listeners. Here we set up a listener to get instructions on the maneuvers to take while driving.
        // For more details, please check the "Navigation" example app and the Developer's Guide.
        visualNavigator.setManeuverNotificationListener(maneuverText -> {
            Log.d("ManeuverNotifications", maneuverText);
        });

        // Set a route to follow. This leaves tracking mode.
        visualNavigator.setRoute(route);

        // VisualNavigator acts as LocationListener to receive location updates directly from a location provider.
        // Any progress along the route is a result of getting a new location fed into the VisualNavigator.
        setupLocationSource(visualNavigator, route);
    }

    private void setupLocationSource(LocationListener locationListener, Route route) {
        try {
            // Provides fake GPS signals based on the route geometry.
            locationSimulator = new LocationSimulator(route, new LocationSimulatorOptions());
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of LocationSimulator failed: " + e.error.name());
        }

        locationSimulator.setListener(locationListener);
        locationSimulator.start();
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

        // Free HERE SDK resources before the application shuts down.
        SDKNativeEngine hereSDKEngine = SDKNativeEngine.getSharedInstance();
        if (hereSDKEngine != null) {
            hereSDKEngine.dispose();
        }
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle(title)
                .setMessage(message)
                .show();
    }
}
