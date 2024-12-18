/*
 * Copyright (C) 2022-2024 HERE Europe B.V.
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

package com.here.hikingdiary;

import android.app.Activity;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.widget.CompoundButton;
import android.widget.ImageButton;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.SwitchCompat;
import androidx.appcompat.widget.Toolbar;

import com.here.HikingDiary.R;
import com.here.hikingdiary.menu.MenuActivity;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapFeatureModes;
import com.here.sdk.mapview.MapFeatures;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    public static final String CLICKED_INDEX_KEY = MenuActivity.CLICKED_INDEX_KEY;
    public static final String DELETE_INDEX_KEY = MenuActivity.DELETE_INDEX_KEY;
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private ImageButton diaryScreenButton;
    private HikingApp hikingApp;
    private ActivityResultLauncher<Intent> menuActivityResultLauncher;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        Toolbar myToolbar = (Toolbar) findViewById(R.id.toolbar);
        setSupportActionBar(myToolbar);

        // Get a MapView instance from layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        SwitchCompat mySwitch = findViewById(R.id.switchMapLayer);
        mySwitch.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                if (hikingApp != null) {
                    if (isChecked) {
                        disableMapFeatures();
                        hikingApp.enableOutdoorRasterLayer();
                    } else {
                        enableMapFeatures();
                        hikingApp.disableOutdoorRasterLayer();
                    }
                }
            }
        });

        menuActivityResultLauncher = registerForActivityResult(
                new ActivityResultContracts.StartActivityForResult(),
                result -> {
                    if (result.getResultCode() == Activity.RESULT_OK) {
                        Intent data = result.getData();
                        if (data != null) {
                            int index = data.getIntExtra(CLICKED_INDEX_KEY, -1);
                            boolean isIndexDeleted = data.getBooleanExtra(DELETE_INDEX_KEY, false);
                            // Handle the returned index here.
                            if (hikingApp != null) {
                                hikingApp.loadDiaryEntry(index);
                                if (isIndexDeleted) {
                                    hikingApp.deleteDiaryEntry(index);
                                }
                            }
                        }
                    }
                }
        );

        diaryScreenButton = findViewById(R.id.diary_button);
        diaryScreenButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (hikingApp != null) {
                    ArrayList<String> entryKeys = hikingApp.getMenuEntryKeys() != null ? new ArrayList<>(hikingApp.getMenuEntryKeys()) : new ArrayList<>();
                    ArrayList<String> entryDescriptions = hikingApp.getMenuEntryDescriptions() != null ? new ArrayList<>(hikingApp.getMenuEntryDescriptions()) : new ArrayList<>();

                    if (entryKeys.isEmpty()) {
                        hikingApp.setMessage("No hiking diary entries saved yet.");
                    } else {
                        Bundle bundle = new Bundle();
                        bundle.putStringArrayList("key_names", entryKeys);
                        bundle.putStringArrayList("key_descriptions", entryDescriptions);

                        Intent intent = new Intent(MainActivity.this, MenuActivity.class);
                        intent.putExtras(bundle);

                        menuActivityResultLauncher.launch(intent);
                    }
                }

            }
        });

        mapView.setOnReadyListener(new MapView.OnReadyListener() {
            @Override
            public void onMapViewReady() {
                // This will be called each time after this activity is resumed.
                // It will not be called before the first map scene was loaded.
                // Any code that requires map data may not work as expected until this event is received.
                Log.d(TAG, "HERE Rendering Engine attached.");
            }
        });

        handleAndroidPermissions();
        
        String message = "For this example app, an outdoor layer from thunderforest.com is used. " +
                "Without setting a valid API key, these raster tiles will show a watermark (terms of usage: https://www.thunderforest.com/terms/)." +
                "\n Attribution for the outdoor layer: \n Maps © www.thunderforest.com, \n Data © www.osm.org/copyright.";

        showDialog("Note", message);
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
                Intent intent = new Intent(this, ConsentStateActivity.class);
                startActivity(intent);
                return true;
            case R.id.stop:
                if (hikingApp != null) {
                    hikingApp.hereBackgroundPositioningServiceProvider.stopForegroundService();
                }
                return true;
            default:
                return super.onOptionsItemSelected(item);
        }
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
        permissionsRequestor = new PermissionsRequestor(this);
        permissionsRequestor.request(new PermissionsRequestor.ResultListener() {

            @Override
            public void permissionsGranted() {
                Log.v(TAG, "checkPermissions: Permissions OK, load map UI");
                loadMapScene();
            }

            @Override
            public void permissionsDenied() {
                Log.v(TAG, "checkPermissions: Permissions denied");
                if (permissionsRequestor.isLocationAccessDenied() ||
                        permissionsRequestor.isBackgroundLocationDenied() ||
                        permissionsRequestor.isNotificationDenied()) {
                    openAppSettingsDialog();
                }
            }
        });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        permissionsRequestor.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    private void openAppSettingsDialog() {
        AlertDialog.Builder builder = new AlertDialog.Builder(MainActivity.this);
        builder.setPositiveButton("Open", new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int id) {
                // User clicked OK button
                Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                Uri uri = Uri.fromParts("package", getPackageName(), null);
                intent.setData(uri);
                startActivity(intent);
            }
        });
        builder.setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int id) {
                // User cancelled the dialog.
                dialog.cancel();
            }
        });

        AlertDialog dialog = builder.create();
        CharSequence title = "Open App Settings";
        CharSequence message = "Cannot start app: Location permissions are needed";
        dialog.setIcon(android.R.drawable.ic_menu_mylocation);
        dialog.setTitle(title);
        dialog.setMessage(message);

        dialog.show();
    }

    private void loadMapScene() {
        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapView.getMapScene().loadScene(MapScheme.TOPO_DAY, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    double distanceInMeters = 1000 * 10;
                    MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
                    mapView.getCamera().lookAt(new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);
                    hikingApp = new HikingApp(mapView, MainActivity.this);
                    hikingApp.hereBackgroundPositioningServiceProvider.startForegroundService();
                    enableMapFeatures();
                } else {
                    Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
                }
            }
        });
    }

    // Enhance the scene with map features suitable for hiking trips.
    private void enableMapFeatures() {
        Map<String, String> mapFeatures = new HashMap<>();
        mapFeatures.put(MapFeatures.TERRAIN, MapFeatureModes.TERRAIN_3D);
        mapFeatures.put(MapFeatures.CONTOURS, MapFeatureModes.CONTOURS_ALL);
        mapFeatures.put(MapFeatures.BUILDING_FOOTPRINTS, MapFeatureModes.BUILDING_FOOTPRINTS_ALL);
        mapFeatures.put(MapFeatures.EXTRUDED_BUILDINGS, MapFeatureModes.EXTRUDED_BUILDINGS_ALL);
        mapFeatures.put(MapFeatures.LANDMARKS, MapFeatureModes.LANDMARKS_TEXTURED);
        mapFeatures.put(MapFeatures.AMBIENT_OCCLUSION, MapFeatureModes.AMBIENT_OCCLUSION_ALL);
        mapView.getMapScene().enableFeatures(mapFeatures);
    }

    // When a custom raster outdoor layer is shown, we do not need to load
    // hidden map features to save bandwidth.
    private void disableMapFeatures() {
        List<String> mapFeatures = new ArrayList<>();
        mapFeatures.add(MapFeatures.TERRAIN);
        mapFeatures.add(MapFeatures.CONTOURS);
        mapFeatures.add(MapFeatures.BUILDING_FOOTPRINTS);
        mapFeatures.add(MapFeatures.EXTRUDED_BUILDINGS);
        mapFeatures.add(MapFeatures.LANDMARKS);
        mapFeatures.add(MapFeatures.AMBIENT_OCCLUSION);
        mapView.getMapScene().disableFeatures(mapFeatures);
    }

    private void showDialog(String title, String message) {
        new AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton("OK", null)
                .show();
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
        if (hikingApp != null) {
            hikingApp.hereBackgroundPositioningServiceProvider.stopForegroundService();
        }
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

    public void startHikeButtonClicked(View view) {
        if (hikingApp != null) {
            hikingApp.onStartHikingButtonClicked();
        }
    }

    public void stopHikeButtonClicked(View view) {
        if (hikingApp != null) {
            hikingApp.onStopHikingButtonClicked();
        }
    }
}
