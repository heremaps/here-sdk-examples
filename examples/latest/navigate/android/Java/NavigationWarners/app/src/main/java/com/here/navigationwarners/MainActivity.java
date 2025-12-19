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

package com.here.navigationwarners;

import android.content.Context;
import android.os.Bundle;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LocationListener;
import com.here.sdk.core.engine.AuthenticationMode;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.gestures.GestureState;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
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
import com.here.sdk.units.core.utils.EnvironmentLogger;
import com.here.sdk.units.core.utils.PermissionsRequestor;

public class MainActivity extends AppCompatActivity {

    private EnvironmentLogger environmentLogger = new EnvironmentLogger();
    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private RoutingEngine routingEngine;
    private VisualNavigator visualNavigator;
    private LocationSimulator locationSimulator;
    private NavigationWarnersExample navigationWarnersExample;
    private boolean changeDestination = false;
    private GeoCoordinates startGeoCoordinates;
    private GeoCoordinates destinationGeoCoordinates;
    private MapMarker startMapMarker;
    private MapMarker destinationMapMarker;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Log application and device details.
        // It expects a string parameter that describes the application source language.
        environmentLogger.logEnvironment("Java");

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        if (SDKNativeEngine.getSharedInstance() == null) {
            initializeHERESDK();
            // We are starting from scratch without a bundled state.
            setupMapView(null);
            handleAndroidPermissions();
        } else {
            // The Activity is recreated, for example, due to an orientation change:
            // We can reuse the bundled state and keep the existing HERE SDK instance.
            setupMapView(savedInstanceState);
        }

        showDialog("Navigation Warners",
                "This app routes to the HERE office in Berlin and logs various TBT events.");

        showDialog("Note", "Do a long press to change start and destination coordinates. " +
                "Map icons are pickable.");

        startGeoCoordinates = new GeoCoordinates(52.520798, 13.409408);
        destinationGeoCoordinates =  new GeoCoordinates(52.530905, 13.385007);

        startMapMarker = addPOIMapMarker(startGeoCoordinates, R.drawable.poi_start);
        destinationMapMarker = addPOIMapMarker(destinationGeoCoordinates, R.drawable.poi_destination);
    }

    private void setupMapView(Bundle savedInstanceState) {
        setContentView(R.layout.activity_main);
        // Get MapView instance from layout.
        mapView = findViewById(R.id.map_view);
        // If the Activity is recreated, we can start with the last bundled state of the map view.
        mapView.onCreate(savedInstanceState);
        setLongPressGestureHandler(mapView);
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
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        permissionsRequestor.onRequestPermissionsResult(requestCode, grantResults);
    }

    private void loadMapScene() {
        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    double distanceInMeters = 1000 * 10;
                    MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters);
                    mapView.getCamera().lookAt(
                            new GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);
                } else {
                    Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
                }
            }
        });
    }

    private void calculateRoute(Waypoint startWaypoint, Waypoint destinationWaypoint) {
        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }

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

    // Use a LongPress handler to define destination waypoint.
    private void setLongPressGestureHandler(MapView mapView) {
        mapView.getGestures().setLongPressListener((gestureState, touchPoint) -> {
            GeoCoordinates geoCoordinates = mapView.viewToGeoCoordinates(touchPoint);

            if (geoCoordinates == null) {
                showDialog("Note", "Invalid GeoCoordinates.");
                return;
            }
            if (gestureState == GestureState.BEGIN) {
                // Set new route start or destination geographic coordinates based on long press location.
                if (changeDestination) {
                    destinationGeoCoordinates = geoCoordinates;
                    destinationMapMarker.setCoordinates(geoCoordinates);
                } else {
                    startGeoCoordinates = geoCoordinates;
                    startMapMarker.setCoordinates(geoCoordinates);
                }
                // Toggle the marker that should be updated on next long press.
                changeDestination = !changeDestination;
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

        // The example shows how to set-up several listeners that provide useful information during TBT.
        navigationWarnersExample = new NavigationWarnersExample(MainActivity.this);
        navigationWarnersExample.setupListeners(visualNavigator);

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator.startRendering(mapView);

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

    public void onStartGuidanceClicked(View view) {
        calculateRoute(new Waypoint(startGeoCoordinates), new Waypoint(destinationGeoCoordinates));
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

    private MapMarker addPOIMapMarker(GeoCoordinates geoCoordinates, int resourceId) {
        MapImage mapImage = MapImageFactory.fromResource(this.getResources(), resourceId);
        Anchor2D anchor2D = new Anchor2D(0.5F, 1);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage, anchor2D);
        mapView.getMapScene().addMapMarker(mapMarker);
        return mapMarker;
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle(title)
                .setMessage(message)
                .show();
    }
}
