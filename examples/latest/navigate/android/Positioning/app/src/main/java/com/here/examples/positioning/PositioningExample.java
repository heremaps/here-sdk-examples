/*
 * Copyright (C) 2020-2025 HERE Europe B.V.
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

package com.here.examples.positioning;

import android.util.Log;

import androidx.annotation.NonNull;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Location;
import com.here.sdk.core.LocationListener;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.location.LocationAccuracy;
import com.here.sdk.location.LocationEngine;
import com.here.sdk.location.LocationEngineStatus;
import com.here.sdk.location.LocationFeature;
import com.here.sdk.location.LocationIssueListener;
import com.here.sdk.location.LocationIssueType;
import com.here.sdk.location.LocationStatusListener;
import com.here.sdk.mapview.LocationIndicator;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapView;

import java.util.Date;
import java.util.List;

public class PositioningExample {

    private static final String TAG = PositioningExample.class.getSimpleName();

    private static final int CAMERA_DISTANCE_IN_METERS = 200;

    private final GeoCoordinates defaultCoordinates = new GeoCoordinates(52.520798,13.409408);

    private MapView mapView;
    private LocationEngine locationEngine;
    private LocationIndicator locationIndicator;

    private final LocationListener locationListener = location -> {
        updateMyLocationOnMap(location);
    };

    private final LocationStatusListener locationStatusListener = new LocationStatusListener() {
        @Override
        public void onStatusChanged(@NonNull LocationEngineStatus locationEngineStatus) {
            if(locationEngineStatus == LocationEngineStatus.ENGINE_STOPPED) {
                locationEngine.removeLocationListener(locationListener);
                locationEngine.removeLocationStatusListener(locationStatusListener);
            }
        }

        @Override
        public void onFeaturesNotAvailable(@NonNull List<LocationFeature> features) {
            for (LocationFeature feature : features) {
                Log.d(TAG, "Feature not available: " + feature.name());
            }
        }
    };

    private final LocationIssueListener locationIssueListener = new LocationIssueListener() {
        @Override
        public void onLocationIssueChanged(@NonNull List<LocationIssueType> issues) {
            for (LocationIssueType issue : issues) {
                Log.d(TAG, "Location issue: " + issue.name());
            }
        }
    };

    public void onMapSceneLoaded(MapView mapView) {
        this.mapView = mapView;

        try {
            locationEngine = new LocationEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization failed: " + e.getMessage());
        }

        final Location myLastLocation = locationEngine.getLastKnownLocation();
        if (myLastLocation != null) {
            addMyLocationToMap(myLastLocation);
        } else {
            final Location defaultLocation = new Location(defaultCoordinates);
            defaultLocation.time = new Date();
            addMyLocationToMap(defaultLocation);
        }

        startLocating();
    }

    private void startLocating() {
        locationEngine.addLocationStatusListener(locationStatusListener);
        locationEngine.addLocationIssueListener(locationIssueListener);
        locationEngine.addLocationListener(locationListener);
        locationEngine.confirmHEREPrivacyNoticeInclusion();
        locationEngine.start(LocationAccuracy.BEST_AVAILABLE);
    }

    public void stopLocating() {
        locationEngine.removeLocationIssueListener(locationIssueListener);
        locationEngine.stop();
    }

    private void addMyLocationToMap(@NonNull Location myLocation) {
        //Create and setup location indicator.
        locationIndicator = new LocationIndicator();
        // Enable a halo to indicate the horizontal accuracy.
        locationIndicator.setAccuracyVisualized(true);
        locationIndicator.setLocationIndicatorStyle(LocationIndicator.IndicatorStyle.PEDESTRIAN);
        locationIndicator.updateLocation(myLocation);
        locationIndicator.enable(mapView);
        //Update the map viewport to be centered on the location.
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, CAMERA_DISTANCE_IN_METERS);
        mapView.getCamera().lookAt(myLocation.coordinates, mapMeasureZoom);
    }

    private void updateMyLocationOnMap(@NonNull Location myLocation) {
        //Update the location indicator's location.
        locationIndicator.updateLocation(myLocation);
        //Update the map viewport to be centered on the location, preserving zoom level.
        mapView.getCamera().lookAt(myLocation.coordinates);
    }
}
