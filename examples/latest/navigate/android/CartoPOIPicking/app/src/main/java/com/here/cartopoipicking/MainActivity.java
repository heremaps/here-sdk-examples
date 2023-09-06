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

package com.here.cartopoipicking;

import android.content.Context;
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
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.gestures.TapListener;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapFeatureModes;
import com.here.sdk.mapview.MapFeatures;
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

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;

    private OfflineSearchEngine offlineSearchEngine;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        // Get a MapView instance from the layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

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
        showDialog("Tap on Map Content",
                "This app shows how to pick vehicle restrictions and embedded markers on the map, such as subway stations and ATMs.");

        enableVehicleRestrictionsOnMap();

        try {
            // Allows to search on already downloaded or cached map data.
            offlineSearchEngine = new OfflineSearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of OfflineSearchEngine failed: " + e.error.name());
        }

        // Setting a tap handler to pick embedded map content.
        setTapGestureHandler();
    }

    private void enableVehicleRestrictionsOnMap() {
        Map<String, String> mapFeatures = new HashMap<>();
        mapFeatures.put(MapFeatures.VEHICLE_RESTRICTIONS,
                        MapFeatureModes.VEHICLE_RESTRICTIONS_ACTIVE_AND_INACTIVE_DIFFERENTIATED);
        mapView.getMapScene().enableFeatures(mapFeatures);
    }

    private void setTapGestureHandler() {
        mapView.getGestures().setTapListener(new TapListener() {
            @Override
            public void onTap(@NonNull Point2D touchPoint) {
                pickMapContent(touchPoint);
            }
        });
    }

    private void pickMapContent(final Point2D touchPoint) {
        // You can also use a larger area to include multiple map icons.
        Rectangle2D rectangle2D = new Rectangle2D(touchPoint, new Size2D(50, 50));
        mapView.pickMapContent(rectangle2D, new MapViewBase.PickMapContentCallback() {
            @Override
            public void onPickMapContent(@Nullable PickMapContentResult pickMapContentResult) {
                if (pickMapContentResult == null) {
                    Log.e("onPickMapContent", "An error occurred while performing the pick operation.");
                    return;
                }

                handlePickedCartoPOIs(pickMapContentResult.getPois());
                handlePickedTrafficIncidents(pickMapContentResult.getTrafficIncidents());
                handlePickedVehicleRestrictions(pickMapContentResult.getVehicleRestrictions());
            }
        });
    }

    private void handlePickedCartoPOIs(List<PickMapContentResult.PoiResult> cartoPOIList) {
        int listSize = cartoPOIList.size();
        if (listSize == 0) {
            return;
        }

        PickMapContentResult.PoiResult topmostCartoPOI = cartoPOIList.get(0);
        showDialog("Carto POI picked:", topmostCartoPOI.name + ", Location: " +
                topmostCartoPOI.coordinates.latitude + ", " +
                topmostCartoPOI.coordinates.longitude + ". " +
                "See log for more place details.");

        // Now you can use the SearchEngine (via PickedPlace) or the OfflineSearchEngine
        // (via PickedPlace or offlineSearchId) to retrieve the Place object containing more details.
        // Below we use the offlineSearchId. Alternatively, you can use the
        // PickMapContentResult as data to create a PickedPlace object.
        fetchCartoPOIDetails(topmostCartoPOI.offlineSearchId);
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

    private void handlePickedTrafficIncidents(List<PickMapContentResult.TrafficIncidentResult> trafficIndicents) {
        // See Traffic example app.
    }

    private void handlePickedVehicleRestrictions(List<PickMapContentResult.VehicleRestrictionResult> vehicleRestrictions) {
        int listSize = vehicleRestrictions.size();
        if (listSize == 0) {
            return;
        }

        // The text is non-translated and will vary depending on the region.
        // For example, for a height restriction the text might be "5.5m" in Germany and "12'5"" in the US for a
        // restriction of type "HEIGHT". An example for a "WEIGHT" restriction: "15t".
        // The text might be empty, for example, in case of type "GENERAL_TRUCK_RESTRICTION", indicated by a "no-truck" sign.
        PickMapContentResult.VehicleRestrictionResult topmostVehicleRestriction = vehicleRestrictions.get(0);
        String text = topmostVehicleRestriction.text;
        if (text.isEmpty()) {
            text = "General vehicle restriction.";
        }

        showDialog("Vehicle restriction picked:", text + ", Location: " +
                topmostVehicleRestriction.coordinates.latitude + ", " +
                topmostVehicleRestriction.coordinates.longitude + ". " +
                // A textual normed representation of the type.
                "Type: " + topmostVehicleRestriction.restrictionType +
                ". See log for more details.");

        // GDF time domains format according to ISO 14825.
        Log.d("VR TimeIntervals", topmostVehicleRestriction.timeIntervals);
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

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle(title)
                .setMessage(message)
                .show();
    }
}
