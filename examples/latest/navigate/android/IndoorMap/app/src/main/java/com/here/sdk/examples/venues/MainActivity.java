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

package com.here.sdk.examples.venues;

import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.examples.venues.PermissionsRequestor.ResultListener;
import com.here.sdk.gestures.TapListener;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.VisibilityState;
import com.here.sdk.venue.VenueEngine;
import com.here.sdk.venue.control.Venue;
import com.here.sdk.venue.control.VenueMap;
import com.here.sdk.venue.control.VenueSelectionListener;
import com.here.sdk.venue.service.VenueListener;
import com.here.sdk.venue.service.VenueService;
import com.here.sdk.venue.service.VenueServiceInitStatus;
import com.here.sdk.venue.service.VenueServiceListener;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private VenueEngine venueEngine;
    private EditText venueChooser;
    private Button goButton;
    private DrawingSwitcher drawingSwitcher;
    private LevelSwitcher levelSwitcher;
    private VenueTapController venueTapController;
    private VenueSearchController venueSearchController;

    // Replace "CATALOG_HRN" with your platform catalog HRN value.
    private final String HRN = "CATALOG_HRN";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Get a MapView instance from the layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        // Get UI elements for selection venue by id.
        venueChooser = findViewById(R.id.venueChooser);
        goButton = findViewById(R.id.goButton);

        // Get drawing and level UI switchers.
        drawingSwitcher = findViewById(R.id.drawing_switcher);
        levelSwitcher = findViewById(R.id.level_switcher);

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
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, mapError -> {
            if (mapError == null) {
                double distanceInMeters = 1000 * 10;
                MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
                mapView.getCamera().lookAt(
                        new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

                // Hide the extruded building layer, so that it does not overlap with the venues.
                mapView.getMapScene().setLayerVisibility(MapScene.Layers.EXTRUDED_BUILDINGS,
                        VisibilityState.HIDDEN);

                // Create a venue engine object. Once the initialization is done, a callback
                // will be called.
                try {
                    venueEngine = new VenueEngine(this ::onVenueEngineInitCompleted);
                } catch (InstantiationErrorException e) {
                    Log.e(TAG, "SDK Engine instantiation failed");
                    e.printStackTrace();
                }
            } else {
                Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
            }
        });
    }

    private void onVenueEngineInitCompleted() {
        // Get VenueService and VenueMap objects.
        VenueService service = venueEngine.getVenueService();
        VenueMap venueMap = venueEngine.getVenueMap();

        // Add needed listeners.
        service.add(serviceListener);
        service.add(venueListener);
        venueMap.add(venueSelectionListener);

        // Create a venue tap controller and connect VenueMap to it.
        venueTapController = new VenueTapController(venueEngine, mapView, this);
        venueTapController.setVenueMap(venueMap);

        venueSearchController = new VenueSearchController(venueMap, venueTapController,
                findViewById(R.id.venueSearchLayout), findViewById(R.id.searchButton));

        // Set a tap listener.
        mapView.getGestures().setTapListener(tapListener);

        // Connect VenueMap to switchers, to control selected drawing and level in the UI.
        drawingSwitcher.setVenueMap(venueMap);
        levelSwitcher.setVenueMap(venueMap);

        // Start VenueEngine. Once authentication is done, the authentication callback
        // will be triggered. Afterwards, VenueEngine will start VenueService. Once VenueService
        // is initialized, VenueServiceListener.onInitializationCompleted method will be called.
        venueEngine.start((authenticationError, authenticationData) -> {
            if (authenticationError != null) {
                Log.e(TAG, "Failed to authenticate, reason: " + authenticationError.value);
            }
        });

        // Set platform catalog HRN
        service.setHrn(HRN);
    }

    // Listener for the VenueService event.
    private final VenueServiceListener serviceListener = new VenueServiceListener() {
        @Override
        public void onInitializationCompleted(@NonNull VenueServiceInitStatus result) {
            if (result == VenueServiceInitStatus.ONLINE_SUCCESS) {
                // Enable button for venue selection. From this moment the venue loading
                // is available.
                setGoButtonClickListener();
            } else {
                Log.e(TAG, "Failed to initialize venue service.");
            }
        }

        @Override
        public void onVenueServiceStopped() {}
    };

    // Listener for the venue loading event.
    private final VenueListener venueListener = (venueId, venueModel, online, venueStyle) -> {
        if (venueModel == null) {
            setGoButtonEnabled(true);
            Log.e(TAG, "Failed to load the venue: " + venueId);
        }
    };

    // Listener for the venue selection event.
    private final VenueSelectionListener venueSelectionListener =
            (deselectedVenue, selectedVenue) -> {
                if (selectedVenue != null) {
                    // Move camera to the selected venue.
                    GeoCoordinates venueCenter = selectedVenue.getVenueModel().getCenter();
                    double distanceInMeters = 500;
                    MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
                    mapView.getCamera().lookAt(
                            new GeoCoordinates(venueCenter.latitude, venueCenter.longitude),
                            mapMeasureZoom);

                    // Venue selection is done, enable back the button for the venue selection
                    // to be able to select another venue.
                    setGoButtonEnabled(true);
                }
            };

    // Listener for the button which selects venues by id.
    private void setGoButtonClickListener() {
        goButton.setOnClickListener(v -> {
            String venueString = venueChooser.getText().toString();
            try {
                // Try to parse a venue id.
                final int venueId = Integer.parseInt(venueString);
                VenueMap venueMap = venueEngine.getVenueMap();
                Venue selectedVenue = venueMap.getSelectedVenue();
                if (selectedVenue == null || selectedVenue.getVenueModel().getId() != venueId) {
                    // Disable the button while a venue loading and selection is in progress.
                    setGoButtonEnabled(false);
                    // Select a venue by id.
                    venueMap.selectVenueAsync(venueId);
                }
            } catch (Exception e) {
                Log.d(TAG, e.toString());
            }
            hideKeyboard();
        });
    }

    // Hide a keyboard.
    public void hideKeyboard() {
        try {
            InputMethodManager imm =
                    (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
            View focusView = getCurrentFocus();
            if (imm != null && focusView != null) {
                imm.hideSoftInputFromWindow(focusView.getWindowToken(), 0);
            }
        } catch (Exception e) {
            Log.d(TAG, e.toString());
        }
    }

    private void setGoButtonEnabled(boolean value) {
        if (value) {
            goButton.setEnabled(true);
            goButton.setText(R.string.go);
        } else {
            goButton.setEnabled(false);
            goButton.setText(R.string.loading);
        }
    }

    // Tap listener for MapView
    private final TapListener tapListener = origin -> {
            // Redirect the event to the venue tap controller.
            venueTapController.onTap(origin);
    };

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
        if (mapView != null) {
            mapView.getGestures().setTapListener(null);
            mapView.getGestures().setLongPressListener(null);
        }
        venueEngine.destroy();
        mapView.onDestroy();

        // Free HERE SDK resources before the application shuts down.
        SDKNativeEngine hereSDKEngine = SDKNativeEngine.getSharedInstance();
        if (hereSDKEngine != null) {
            hereSDKEngine.dispose();
            // For safety reasons, we explicitly set the shared instance to null to avoid situations, where a disposed instance is accidentally reused.
            SDKNativeEngine.setSharedInstance(null);
        }
        super.onDestroy();
    }
}
