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

package com.here.cartopoipicking;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import com.here.sdk.core.engine.AuthenticationMode;

import com.here.cartopoipicking.PermissionsRequestor.ResultListener;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.PickedPlace;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Rectangle2D;
import com.here.sdk.core.Size2D;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.gestures.TapListener;
import com.here.sdk.mapview.IconProvider;
import com.here.sdk.mapview.IconProviderAssetType;
import com.here.sdk.mapview.IconProviderError;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapFeatureModes;
import com.here.sdk.mapview.MapFeatures;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.PickMapContentResult;
import com.here.sdk.search.SearchEngine;
import com.here.sdk.search.Place;
import com.here.sdk.search.PlaceIdSearchCallback;
import com.here.sdk.search.SearchError;
import com.here.sdk.transport.VehicleRestriction;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private IconProvider iconProvider;

    private SearchEngine searchEngine;
    private MapScheme currentMapScheme;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        // Get a MapView instance from the layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        currentMapScheme = MapScheme.NORMAL_DAY;
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
        mapView.getMapScene().loadScene(currentMapScheme, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    double distanceInMeters = 1000 * 10;
                    MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters);
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
        iconProvider = new IconProvider(mapView.getMapContext());

        try {
            // Allows to search online.
            searchEngine = new SearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of searchEngine failed: " + e.error.name());
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
        // Creates a list of map content type from which the results will be picked.
        // The content type values can be MAP_CONTENT, MAP_ITEMS and CUSTOM_LAYER_DATA.
        ArrayList<MapScene.MapPickFilter.ContentType> contentTypesToPickFrom = new ArrayList<>();

        // MAP_CONTENT is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
        // MAP_ITEMS is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
        // Currently we need carto POIs so adding the MAP_CONTENT filter.
        contentTypesToPickFrom.add(MapScene.MapPickFilter.ContentType.MAP_CONTENT);
        MapScene.MapPickFilter filter = new MapScene.MapPickFilter(contentTypesToPickFrom);

        // If you do not want to specify any filter you can pass filter as NULL and all of the pickable contents will be picked.
        mapView.pick(filter, rectangle2D, mapPickResult -> {
            if (mapPickResult == null) {
                Log.e("onPickMapContent", "An error occurred while performing the pick operation.");
                return;
            }
            PickMapContentResult pickedContent = mapPickResult.getMapContent();
            handlePickedCartoPOIs(pickedContent.getPickedPlaces());
            handlePickedTrafficIncidents(pickedContent.getTrafficIncidents());
            handlePickedVehicleRestrictions(pickedContent.getVehicleRestrictions());
        });
    }

    private void handlePickedCartoPOIs(List<PickedPlace> cartoPOIList) {
        int listSize = cartoPOIList.size();
        if (listSize == 0) {
            return;
        }

        PickedPlace topmostPickedPlace = cartoPOIList.get(0);
        showDialog("Carto POI picked:", topmostPickedPlace.name + ", Location: " +
                topmostPickedPlace.coordinates.latitude + ", " +
                topmostPickedPlace.coordinates.longitude + ". " +
                "See log for more place details.");

        // Now you can use the SearchEngine (via PickedPlace)
        // (via PickedPlace or placeCategoryId) to retrieve the Place object containing more details.
        // Below we use the placeCategoryId.
        fetchCartoPOIDetails(topmostPickedPlace);
    }

    private void fetchCartoPOIDetails(PickedPlace pickedPlace) {
        // Set null to get the results in their local language.
        LanguageCode languageCode = null;
        searchEngine.searchByPickedPlace(pickedPlace, languageCode, new PlaceIdSearchCallback() {
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

        PickMapContentResult.VehicleRestrictionResult topmostVehicleRestriction = vehicleRestrictions.get(0);
        createVehicleRestrictionIcon(topmostVehicleRestriction);
    }

    private void createVehicleRestrictionIcon(PickMapContentResult.VehicleRestrictionResult vehicleRestrictionResult) {

        IconProvider.IconCallback iconProviderCallback = new IconProvider.IconCallback() {
            @Override
            public void onCreateIconReply(@Nullable Bitmap bitmap, @Nullable String description, @Nullable IconProviderError iconProviderError) {
                if (iconProviderError == null) {
                    showDialog("Vehicle Restriction", "Description: " + ((description==null || description.isBlank())?"Not Available":description), bitmap);
                    return;
                }
                showDialog("IconProvider error", "An error occurred while creating the icon: " + iconProviderError.name());
            }
        };

        // Creates an image representing a vehicle restriction based on the picked content.
        // Parameters:
        // - vehicleRestrictionResult: The result of picking a vehicle restriction object from PickMapContentResult.
        // - currentMapScheme: The current map scheme of the MapView.
        // - IconProviderAssetType: Specifies icon optimization for either UI or MAP.
        // - size: The size of the generated image in the callback.
        // - iconProviderCallback: The callback object for receiving the generated icon.
        iconProvider.createVehicleRestrictionIcon(vehicleRestrictionResult, currentMapScheme, IconProviderAssetType.UI, new Size2D(), iconProviderCallback);
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

    private void showDialog(String title, String message, Bitmap icon) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle(title)
                .setMessage(message)
                .setIcon(new BitmapDrawable(getApplicationContext().getResources(),icon))
                .show();
    }
}
