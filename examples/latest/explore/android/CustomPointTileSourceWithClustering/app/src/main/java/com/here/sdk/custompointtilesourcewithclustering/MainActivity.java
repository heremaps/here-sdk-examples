/*
 * Copyright (C) 2024 HERE Europe B.V.
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

package com.here.sdk.custompointtilesourcewithclustering;

import android.content.Context;
import android.os.Bundle;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.custompointtilesourcewithclustering.PermissionsRequestor.ResultListener;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;

public class MainActivity extends AppCompatActivity {

  private static final String TAG = MainActivity.class.getSimpleName();
  // Name of the custom point tile data source.

  private PermissionsRequestor permissionsRequestor;
  private MapView mapView;

  private CustomPointTileSourceExample customPointTileSourceExample;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    // Usually, you need to initialize the HERE SDK only once during the
    // lifetime of an application.
    initializeHERESDK();

    setContentView(R.layout.activity_main);

    // Get a MapView instance from layout.
    mapView = findViewById(R.id.map_view);
    mapView.onCreate(savedInstanceState);

    handleAndroidPermissions();
  }

  private void initializeHERESDK() {
    // Set your credentials for the HERE SDK.
    String accessKeyID = "";
    String accessKeySecret = "";
    SDKOptions options = new SDKOptions(accessKeyID, accessKeySecret);
    try {
      Context context = this;
      SDKNativeEngine.makeSharedInstance(context, options);
    } catch (InstantiationErrorException e) {
      throw new RuntimeException("Initialization of HERE SDK failed: " +
                                 e.error.name());
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
  public void onRequestPermissionsResult(int requestCode,
                                         @NonNull String[] permissions,
                                         @NonNull int[] grantResults) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    permissionsRequestor.onRequestPermissionsResult(requestCode, grantResults);
  }

  private void loadMapScene() {
    // Load a scene from the HERE SDK to render the map with a map scheme.
    mapView.getMapScene().loadScene(
        MapScheme.NORMAL_DAY, new MapScene.LoadSceneCallback() {
          @Override
          public void onLoadScene(@Nullable MapError mapError) {
            if (mapError != null) {
              Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
            } else {
              customPointTileSourceExample = new CustomPointTileSourceExample();
              customPointTileSourceExample.onMapSceneLoaded(mapView);
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
    customPointTileSourceExample.onDestroy();
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
    // Afterwards, the HERE SDK is no longer usable unless it is initialized
    // again.
    SDKNativeEngine sdkNativeEngine = SDKNativeEngine.getSharedInstance();
    if (sdkNativeEngine != null) {
      sdkNativeEngine.dispose();
      // For safety reasons, we explicitly set the shared instance to null to
      // avoid situations, where a disposed instance is accidentally reused.
      SDKNativeEngine.setSharedInstance(null);
    }
  }
}
