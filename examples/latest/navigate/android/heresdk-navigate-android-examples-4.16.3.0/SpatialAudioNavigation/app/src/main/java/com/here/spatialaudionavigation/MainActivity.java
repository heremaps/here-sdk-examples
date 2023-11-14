/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

package com.here.spatialaudionavigation;

import android.content.Context;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import android.util.Log;
import android.view.View;


import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.LocationListener;
import com.here.sdk.core.UnitSystem;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.navigation.LocationSimulator;
import com.here.sdk.navigation.LocationSimulatorOptions;
import com.here.sdk.navigation.ManeuverNotificationOptions;
import com.here.sdk.navigation.SpatialManeuver;
import com.here.sdk.navigation.SpatialManeuverAudioCuePanning;
import com.here.sdk.navigation.SpatialManeuverAzimuthListener;
import com.here.sdk.navigation.SpatialManeuverNotificationListener;
import com.here.sdk.navigation.SpatialTrajectoryData;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.routing.CarOptions;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.Waypoint;
import com.here.spatialaudionavigation.PermissionsRequestor.ResultListener;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private com.here.spatialaudionavigation.PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private RoutingEngine routingEngine;
    private VisualNavigator visualNavigator;
    private LocationSimulator locationSimulator;
    private SpatialAudioExample spatialAudioExample;
    private VoiceAssistant voiceAssistant;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

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
    }

    private void setupMapView(Bundle savedInstanceState) {
        setContentView(R.layout.activity_main);
        // Get MapView instance from layout.
        mapView = findViewById(R.id.map_view);
        // If the Activity is recreated, we can start with the last bundled state of the map view.
        mapView.onCreate(savedInstanceState);
    }

    private void initializeHERESDK() {
        // Set your credentials for the HERE SDK.
        String accessKeyID = "YOUR_ACCESS_KEY_ID";
        String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
        SDKOptions options = new SDKOptions(accessKeyID, accessKeySecret);
        try {
            Context context = this;
            SDKNativeEngine.makeSharedInstance(context, options);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of HERE SDK failed: " + e.error.name());
        }
    }

    private void handleAndroidPermissions() {
        permissionsRequestor = new com.here.spatialaudionavigation.PermissionsRequestor(this);
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
        showDialog("Spatial Audio Navigation",
                "This app routes to the HERE office in Berlin using spatial audio guidance. See logs for guidance information.");

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

        setupVoiceGuidance();
        setupSpatialAudio();

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator.startRendering(mapView);

        // Notifies on voice maneuver messages and data related to the SpatialManeuver
        visualNavigator.setSpatialManeuverNotificationListener(new SpatialManeuverNotificationListener() {
            @Override
            public void onSpatialManeuverNotification(@NonNull SpatialManeuver spatialManeuver, @NonNull SpatialManeuverAudioCuePanning spatialManeuverAudioCuePanning) {
                Log.d(TAG, "New spatial maneuver notification");;
                spatialAudioExample.initSpatialAudioExecutors();
                // Prepares the audio file to be played
                spatialAudioExample.synthesizeStringToAudioFile(spatialManeuver.voiceText, (float) spatialManeuver.initialAzimuthInDegrees, spatialManeuverAudioCuePanning, MainActivity.this);
            }
        });

        // Notifies the next azimuth for the current spatial audio trajectory
        visualNavigator.setSpatialManeuverAzimuthListener(new SpatialManeuverAzimuthListener() {
            @Override
            public void onAzimuthNotification(@NonNull SpatialTrajectoryData spatialTrajectoryData) {
                Log.d(TAG, "New azimuth notification:" + spatialTrajectoryData.azimuthInDegrees);
                spatialAudioExample.updatePanning(spatialTrajectoryData);
            }
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


    private void setupVoiceGuidance() {
        if(this.voiceAssistant == null) {
            this.voiceAssistant = new VoiceAssistant(MainActivity.this);

            LanguageCode ttsLanguageCode = getLanguageCodeForDevice(VisualNavigator.getAvailableLanguagesForManeuverNotifications());
            visualNavigator.setManeuverNotificationOptions(new ManeuverNotificationOptions(ttsLanguageCode, UnitSystem.METRIC));
            Log.d(TAG, "LanguageCode for maneuver notifications: " + ttsLanguageCode);

            // Set language to our TextToSpeech engine.
            Locale locale = LanguageCodeConverter.getLocale(ttsLanguageCode);
            if (voiceAssistant.setLanguage(locale)) {
                Log.d(TAG, "TextToSpeech engine uses this language: " + locale);
            } else {
                Log.e(TAG, "TextToSpeech engine does not support this language: " + locale);
            }
        }
    }

    // Get the language preferably used on this device.
    private LanguageCode getLanguageCodeForDevice(List<LanguageCode> supportedVoiceSkins) {

        // 1. Determine if preferred device language is supported by our TextToSpeech engine.
        Locale localeForCurrentDevice = Locale.getDefault();
        if (!voiceAssistant.isLanguageAvailable(localeForCurrentDevice)) {
            Log.e(TAG, "TextToSpeech engine does not support: " + localeForCurrentDevice + ", falling back to EN_US.");
            localeForCurrentDevice = new Locale("en", "US");
        }

        // 2. Determine supported voice skins from HERE SDK.
        LanguageCode languageCodeForCurrenDevice = LanguageCodeConverter.getLanguageCode(localeForCurrentDevice);
        if (!supportedVoiceSkins.contains(languageCodeForCurrenDevice)) {
            Log.e(TAG, "No voice skins available for " + languageCodeForCurrenDevice + ", falling back to EN_US.");
            languageCodeForCurrenDevice = LanguageCode.EN_US;
        }

        return languageCodeForCurrenDevice;
    }

    private void setupSpatialAudio() {
        if (spatialAudioExample == null) {
            spatialAudioExample = new SpatialAudioExample(voiceAssistant);
            spatialAudioExample.shutdownExecutors();
            spatialAudioExample.initSpatialAudioExample();
        }
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
    protected void onSaveInstanceState(@NonNull Bundle outState) {
        mapView.onSaveInstanceState(outState);
        super.onSaveInstanceState(outState);
    }
    
    private void showDialog(String title, String message) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle(title)
                .setMessage(message)
                .show();
    }
}
