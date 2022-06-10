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

package com.here.navigation;

import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.os.Bundle;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.WindowManager;
import android.widget.TextView;
import android.widget.ToggleButton;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;

import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.VisibilityState;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();

    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private App app;
    private TextView messageView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LOCKED);

        // Keeping the screen alive is essential for a car navigation app.
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        Toolbar myToolbar = findViewById(R.id.toolbar);
        setSupportActionBar(myToolbar);

        // Get a MapView instance from layout.
        mapView = findViewById(R.id.map_view);
        // Get a TextView instance from layout to show selected log messages.
        messageView = findViewById(R.id.message_view);
        // Making the textView scrollable.
        messageView.setMovementMethod(new ScrollingMovementMethod());

        mapView.onCreate(savedInstanceState);

        handleAndroidPermissions();

        ToggleButton toggleTrackingButton = findViewById(R.id.toggleTrackingButton);
        toggleTrackingButton.setTextOn("Camera Tracking: ON");
        toggleTrackingButton.setTextOff("Camera Tracking: OFF");
        toggleTrackingButton.setChecked(true);
        toggleTrackingButton.setOnClickListener(v -> {
            if (app == null) return;
            if (toggleTrackingButton.isChecked()) {
                app.toggleTrackingButtonOnClicked();
            } else {
                app.toggleTrackingButtonOffClicked();
            }
        });
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.example_menu, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle item selection
        switch (item.getItemId()) {
            case R.id.about:
                // Required by HERE positioning.
                // User must be able to see & to change his consent to collect data.
                Intent intent = new Intent(this, ConsentStateActivity.class);
                startActivity(intent);
                return true;
            default:
                return super.onOptionsItemSelected(item);
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
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    // Start the app that contains the logic to calculate routes & start TBT guidance.
                    app = new App(MainActivity.this, mapView, messageView);

                    // Enable traffic flows by default.
                    mapView.getMapScene().setLayerVisibility(MapScene.Layers.TRAFFIC_FLOW, VisibilityState.VISIBLE);
                } else {
                    Log.d(TAG, "Loading map failed: " + mapError.name());
                }
            }
        });
    }

    public void addRouteSimulatedLocationButtonClicked(View view) {
        if (app != null) {
            app.addRouteSimulatedLocation();
        }
    }

    public void addRouteDeviceLocationButtonClicked(View view) {
        if (app != null) {
            app.addRouteDeviceLocation();
        }
    }

    public void clearMapButtonClicked(View view) {
        if (app != null) {
            app.clearMapButtonPressed();
        }
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
        if (app != null) {
            app.detach();
        }
        mapView.onDestroy();

        // Free HERE SDK resources before the application shuts down.
        SDKNativeEngine hereSDKEngine = SDKNativeEngine.getSharedInstance();
        if (hereSDKEngine != null) {
            hereSDKEngine.dispose();
        }
    }
}
