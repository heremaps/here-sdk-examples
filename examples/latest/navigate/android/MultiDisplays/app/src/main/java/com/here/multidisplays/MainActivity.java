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

package com.here.multidisplays;

import android.app.ActivityOptions;
import android.content.Context;
import android.content.Intent;
import android.hardware.display.DisplayManager;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.Display;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.appcompat.app.AppCompatActivity;

import com.here.multidisplays.PermissionsRequestor.ResultListener;
import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCircle;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolygon;
import com.here.sdk.core.engine.AuthenticationMode;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapPolygon;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;

// This activity is shown on the primary display.
public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;

    // Handle messages coming from secondary display.
    private final DataBroadcast dataBroadcast = new DataBroadcast() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent.getAction().equals(DataBroadcast.MESSAGE_FROM_SECONDARY_DISPLAY)) {
                double latitude = intent.getDoubleExtra("latitude", 0);
                double longitude = intent.getDoubleExtra("longitude", 0);
                Log.d(TAG, "Current center of secondary display: lat:" + latitude + ", lon: " + longitude);

                // Add circle to this map view's center.
                GeoCoordinates mapCenterGeoCoordinates = mapView.getCamera().getState().targetCoordinates;
                addMapCircle(mapCenterGeoCoordinates);
            }
        }
    };

    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        // Get a MapView instance from the layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(null);

        registerReceiver(dataBroadcast, dataBroadcast.getFilter(DataBroadcast.MESSAGE_FROM_SECONDARY_DISPLAY), Context.RECEIVER_EXPORTED);
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
        permissionsRequestor.request(new ResultListener() {

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
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, mapError -> {
            if (mapError == null) {
                double distanceInMeters = 1000 * 5;
                MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
                mapView.getCamera().lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);
            } else {
                Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
            }
        });

        launchSecondaryDisplayIfAny();
    }

    private void launchSecondaryDisplayIfAny() {
        DisplayManager displayManager = (DisplayManager) getSystemService(Context.DISPLAY_SERVICE);
        Display[] displays = displayManager.getDisplays();

        // Check if we have a secondary display.
        if (displays.length > 1) {
            // Multi-Displays require Android 8 or higher.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // The ID of the second display.
                int secondaryDisplayID = displays[1].getDisplayId();

                // Make sure we launch the secondary display not on the primary display.
                if (secondaryDisplayID != Display.DEFAULT_DISPLAY) {
                    ActivityOptions activityOptions = ActivityOptions.makeBasic();
                    activityOptions.setLaunchDisplayId(secondaryDisplayID);

                    // Start the secondary activity on the secondary display.
                    Intent intent = new Intent(this, SecondaryActivity.class);
                    startActivity(intent, activityOptions.toBundle());
                }
            }
        }
    }

    public void addButtonClicked(View view) {
        // Send message to secondary display.
        GeoCoordinates mapCenterGeoCoordinates = mapView.getCamera().getState().targetCoordinates;
        dataBroadcast.sendMessageToSecondaryDisplay(this, mapCenterGeoCoordinates);
    }

    private void addMapCircle(GeoCoordinates geoCoordinates) {
        float radiusInMeters = 100;
        GeoCircle geoCircle = new GeoCircle(geoCoordinates, radiusInMeters);
        GeoPolygon geoPolygon = new GeoPolygon(geoCircle);
        Color fillColor = Color.valueOf(0, 0.56f, 0.54f, 0.63f); // RGBA
        MapPolygon mapPolygon = new MapPolygon(geoPolygon, fillColor);
        mapView.getMapScene().addMapPolygon(mapPolygon);
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
        unregisterReceiver(dataBroadcast);
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
