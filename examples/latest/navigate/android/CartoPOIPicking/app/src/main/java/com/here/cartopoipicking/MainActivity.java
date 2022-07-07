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

package com.here.cartopoipicking;

import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import com.here.cartopoipicking.PermissionsRequestor.ResultListener;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Rectangle2D;
import com.here.sdk.core.Size2D;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.gestures.TapListener;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.MapViewBase;
import com.here.sdk.mapview.PickMapContentResult;
import com.here.sdk.search.OfflineSearchEngine;
import com.here.sdk.search.Place;
import com.here.sdk.search.PlaceIdQuery;
import com.here.sdk.search.PlaceIdSearchCallback;
import com.here.sdk.search.SearchError;

import java.util.List;
import java.util.Objects;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;

    private OfflineSearchEngine offlineSearchEngine;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Get a MapView instance from the layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

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
                    startExample();
                } else {
                    Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
                }
            }
        });
    }

    private void startExample() {
        showDialog("Tap on Carto POIs",
                "This app show how to pick embedded markers on the map, such as subway stations and ATMs.");

        try {
            // Allows to search on already downloaded or cached map data.
            offlineSearchEngine = new OfflineSearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of OfflineSearchEngine failed: " + e.error.name());
        }

        // Setting a tap handler to pick embedded carto POIs from map.
        setTapGestureHandler();
    }

    private void setTapGestureHandler() {
        mapView.getGestures().setTapListener(new TapListener() {
            @Override
            public void onTap(@NonNull Point2D touchPoint) {
                pickMapMarker(touchPoint);
            }
        });
    }

    private void pickMapMarker(final Point2D touchPoint) {
        // You can also use a larger area to include multiple carto POIs.
        Rectangle2D rectangle2D = new Rectangle2D(touchPoint, new Size2D(1, 1));
        mapView.pickMapContent(rectangle2D, new MapViewBase.PickMapContentCallback() {
            @Override
            public void onPickMapContent(@Nullable PickMapContentResult pickMapContentResult) {
                if (pickMapContentResult == null) {
                    // An error occurred while performing the pick operation.
                    return;
                }

                List<PickMapContentResult.PoiResult> cartoPOIList = pickMapContentResult.getPois();
                int listSize = cartoPOIList.size();
                if (listSize == 0) {
                    return;
                }

                PickMapContentResult.PoiResult topmostCartoPOI = cartoPOIList.get(0);
                showDialog("Carto POI picked:", topmostCartoPOI.name + ", Location: " +
                        topmostCartoPOI.coordinates.latitude + ", " +
                        topmostCartoPOI.coordinates.longitude + ". " +
                        "See log for more place details.");

                fetchCartoPOIDetails(topmostCartoPOI.offlineSearchId);
            }
        });
    }

    // The ID is only given for cached or downloaded maps data.
    private void fetchCartoPOIDetails(String offlineSearchId) {
        // Set null to get the results in their local language.
        LanguageCode languageCode = null;
        offlineSearchEngine.search(new PlaceIdQuery(offlineSearchId), languageCode, new PlaceIdSearchCallback() {
            @Override
            public void onPlaceIdSearchCompleted(@Nullable SearchError searchError, @Nullable Place place) {
                if (searchError != null) {
                    showDialog("Place ID Search", "Error: " + searchError.toString());
                    return;
                }

                // Below are just a few examples. Much more details can be retrieved, if desired.
                Log.d(TAG, "Title: " + Objects.requireNonNull(place).getTitle());
                Log.d(TAG, "Title: " + place.getAddress().addressText);
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

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle(title)
                .setMessage(message)
                .show();
    }
}
