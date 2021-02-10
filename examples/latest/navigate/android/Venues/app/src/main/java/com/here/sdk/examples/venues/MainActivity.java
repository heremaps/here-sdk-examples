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

package com.here.sdk.examples.venues;

import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.v7.app.AppCompatActivity;
import android.util.Log;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.examples.venues.PermissionsRequestor.ResultListener;
import com.here.sdk.gestures.TapListener;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
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
    private IndoorRoutingUIController indoorRoutingController;
    private VenuesController venuesController;

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
                final double distanceInMeters = 1000 * 10;
                mapView.getCamera().lookAt(
                        new GeoCoordinates(52.530932, 13.384915), distanceInMeters);

                // Hide the extruded building layer, so that it does not overlap with the venues.
                mapView.getMapScene().setLayerState(MapScene.Layers.EXTRUDED_BUILDINGS,
                        MapScene.LayerState.HIDDEN);

                // Create a venue engine object. Once the initialization is done, a callback
                // will be called.
                venueEngine = new VenueEngine(this ::onVenueEngineInitCompleted);
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

        indoorRoutingController = new IndoorRoutingUIController(
                venueEngine,
                mapView,
                findViewById(R.id.indoorRoutingLayout),
                findViewById(R.id.indoorRoutingButton));

        // Set a tap listener.
        mapView.getGestures().setTapListener(tapListener);

        venuesController = new VenuesController(venueMap, findViewById(R.id.venuesLayout),
                findViewById(R.id.editVenuesButton));

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
                    final double distanceInMeters = 500;
                    mapView.getCamera().lookAt(
                            new GeoCoordinates(venueCenter.latitude, venueCenter.longitude),
                            distanceInMeters);

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
        if (indoorRoutingController.isVisible()) {
            indoorRoutingController.onTap(origin);
        } else {
            venueTapController.onTap(origin);
        }
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
        super.onDestroy();
        if (mapView != null) {
            mapView.getGestures().setTapListener(null);
        }
        venueEngine.destroy();
        mapView.onDestroy();
    }
}
