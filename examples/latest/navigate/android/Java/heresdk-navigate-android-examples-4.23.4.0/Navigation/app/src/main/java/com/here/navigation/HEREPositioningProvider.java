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

package com.here.navigation;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;

import com.here.sdk.core.Location;
import com.here.sdk.core.LocationListener;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.location.LocationAccuracy;
import com.here.sdk.location.LocationEngine;
import com.here.sdk.location.LocationEngineStatus;
import com.here.sdk.location.LocationFeature;
import com.here.sdk.location.LocationStatusListener;

import java.util.List;

// A reference implementation using HERE Positioning to get notified on location updates
// from various location sources available from a device and HERE services.
public class HEREPositioningProvider {

    private final Context context;

    private static final String LOG_TAG = HEREPositioningProvider.class.getName();

    private final LocationEngine locationEngine;
    private LocationListener updateListener;

    private final LocationStatusListener locationStatusListener = new LocationStatusListener() {
        @Override
        public void onStatusChanged(@NonNull LocationEngineStatus locationEngineStatus) {
            if (locationEngineStatus == LocationEngineStatus.LOCATION_SERVICES_DISABLED) {
                new AlertDialog.Builder(context)
                        .setTitle("Enable Location Services")
                        .setMessage("The app may not function properly because Location Services are disabled. Please enable Location Services.")
                        .setPositiveButton("OK", null)
                        .setCancelable(false)
                        .show();
            }
            Log.d(LOG_TAG, "Location engine status: " + locationEngineStatus.name());
        }

        @Override
        public void onFeaturesNotAvailable(@NonNull List<LocationFeature> features) {
            for (LocationFeature feature : features) {
                Log.d(LOG_TAG, "Location feature not available: " + feature.name());
            }
        }
    };

    public HEREPositioningProvider(Context context) {
        this.context = context;
        try {
            locationEngine = new LocationEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization failed: " + e.getMessage());
        }
    }

    @Nullable
    public Location getLastKnownLocation() {
        return locationEngine.getLastKnownLocation();
    }

    // Does nothing when engine is already running.
    public void startLocating(LocationListener updateListener, LocationAccuracy accuracy) {
        if (locationEngine.isStarted()) {
            return;
        }

        this.updateListener = updateListener;

        // Set listeners to get location updates.
        locationEngine.addLocationListener(updateListener);
        locationEngine.addLocationStatusListener(locationStatusListener);

        // By calling confirmHEREPrivacyNoticeInclusion() you confirm that this app informs on
        // data collection, which is done for this app via HEREPositioningTermsAndPrivacyHelper,
        // which shows a possible example for this.
        locationEngine.confirmHEREPrivacyNoticeInclusion();

        locationEngine.start(accuracy);
    }

    // Does nothing when engine is already stopped.
    public void stopLocating() {
        if (!locationEngine.isStarted()) {
            return;
        }

        // Remove listeners and stop location engine.
        locationEngine.removeLocationListener(updateListener);
        locationEngine.removeLocationStatusListener(locationStatusListener);
        locationEngine.stop();
    }
}
