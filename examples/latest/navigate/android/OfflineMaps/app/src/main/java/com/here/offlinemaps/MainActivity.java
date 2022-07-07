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

package com.here.offlinemaps;

import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import android.util.Log;
import android.view.View;

import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private OfflineMapsExample offlineMapsExample;

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
                    offlineMapsExample = new OfflineMapsExample(mapView);
                } else {
                    Log.d(TAG, "onLoadScene failed: " + mapError.toString());
                }
            }
        });
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

        // Free HERE SDK resources before the application shuts down.
        SDKNativeEngine hereSDKEngine = SDKNativeEngine.getSharedInstance();
        if (hereSDKEngine != null) {
            hereSDKEngine.dispose();
            // For safety reasons, we explicitly set the shared instance to null to avoid situations, where a disposed instance is accidentally reused.
            SDKNativeEngine.setSharedInstance(null);
        }
        super.onDestroy();
    }

    public void onDownloadListClicked(View view) {
        offlineMapsExample.onDownloadListClicked();
    }

    public void onDownloadMapClicked(View view) {
        offlineMapsExample.onDownloadMapClicked();
    }

    public void onCancelMapDownloadClicked(View view) {
        offlineMapsExample.onCancelMapDownloadClicked();
    }

    public void onSearchPlaceClicked(View view) {
        offlineMapsExample.onSearchPlaceClicked();
    }
}
