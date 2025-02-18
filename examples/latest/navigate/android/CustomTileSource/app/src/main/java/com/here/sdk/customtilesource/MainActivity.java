/*
 * Copyright (C) 2025 HERE Europe B.V.
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

package com.here.sdk.customtilesource;

import android.content.Context;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import android.util.Log;
import android.view.View;
import android.widget.RadioGroup;
import android.widget.RadioButton;

import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.customtilesource.PermissionsRequestor.ResultListener;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private CustomPointTileSourceExample customPointTileSourceExample;
    private CustomRasterTileSourceExample customRasterTileSourceExample;
    private MapView mapView;
    private boolean isPointTileSelected = true;
    private RadioGroup tileSourceGroup;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        // Get a MapView instance from the layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        // Initialize tile source objects early
        customPointTileSourceExample = new CustomPointTileSourceExample();
        customRasterTileSourceExample = new CustomRasterTileSourceExample();

        // Setup RadioGroup for selecting tile source
        tileSourceGroup = findViewById(R.id.radioGroupTileSource);
        tileSourceGroup.setOnCheckedChangeListener((group, checkedId) -> {
            isPointTileSelected = (checkedId == R.id.radioCustomPointTileSource);
        });

        handleAndroidPermissions();
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

    private void loadMapScene() {
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, mapError -> {
            if (mapError == null) {
                // Ensure objects are initialized
                customPointTileSourceExample.onMapSceneLoaded(mapView, MainActivity.this);
                customRasterTileSourceExample.onMapSceneLoaded(mapView, MainActivity.this);
            } else {
                Log.e(TAG, "onLoadScene failed: " + mapError.toString());
            }
        });
    }

    public void enableButtonClicked(View view) {
        if (isPointTileSelected) {
            if (customPointTileSourceExample != null) {
                customPointTileSourceExample.enableButtonClicked();
            } else {
                Log.e(TAG, "customPointTileSourceExample is null");
            }
        } else {
            if (customRasterTileSourceExample != null) {
                customRasterTileSourceExample.enableButtonClicked();
            } else {
                Log.e(TAG, "customRasterTileSourceExample is null");
            }
        }
    }

    public void disableButtonClicked(View view) {
        if (isPointTileSelected) {
            if (customPointTileSourceExample != null) {
                customPointTileSourceExample.disableButtonClicked();
            } else {
                Log.e(TAG, "customPointTileSourceExample is null");
            }
        } else {
            if (customRasterTileSourceExample != null) {
                customRasterTileSourceExample.disableButtonClicked();
            } else {
                Log.e(TAG, "customRasterTileSourceExample is null");
            }
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
        if (customPointTileSourceExample != null) {
            customPointTileSourceExample.onDestroy();
        }
        if (customRasterTileSourceExample != null) {
            customRasterTileSourceExample.onDestroy();
        }
        mapView.onDestroy();
        disposeHERESDK();
        super.onDestroy();
    }

    private void disposeHERESDK() {
        SDKNativeEngine sdkNativeEngine = SDKNativeEngine.getSharedInstance();
        if (sdkNativeEngine != null) {
            sdkNativeEngine.dispose();
            SDKNativeEngine.setSharedInstance(null);
        }
    }
}
