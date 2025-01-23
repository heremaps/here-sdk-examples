/*
 * Copyright (C) 2022-2025 HERE Europe B.V.
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

package com.here.examples.positioningwithbackgroundupdates;

import android.app.Activity;
import android.app.Dialog;
import android.content.ComponentName;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.IBinder;
import android.util.Log;

import androidx.annotation.NonNull;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Location;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.location.LocationEngine;
import com.here.sdk.mapview.LocationIndicator;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapView;

import java.util.Date;

public class BackgroundPositioningExample {

    private static final String TAG = BackgroundPositioningExample.class.getSimpleName();

    private static final int CAMERA_DISTANCE_IN_METERS = 200;

    private final MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, CAMERA_DISTANCE_IN_METERS);
    private final GeoCoordinates defaultCoordinates = new GeoCoordinates(52.520798,13.409408);

    private MapView mapView;
    private Context context;
    private Activity activity;
    private LocationEngine locationEngine;
    private LocationIndicator locationIndicator;
    private boolean shouldUnbind;
    private HEREBackgroundPositioningService positioningService;

    public void onMapSceneLoaded(MapView mapView, Context context) {
        this.mapView = mapView;
        this.context = context;
        activity = (Activity) context;

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
    }

    private void addMyLocationToMap(@NonNull Location myLocation) {
        //Create and setup location indicator.
        locationIndicator = new LocationIndicator();
        locationIndicator.setLocationIndicatorStyle(LocationIndicator.IndicatorStyle.PEDESTRIAN);
        locationIndicator.enable(mapView);
        //Update the map location.
        updateMyLocationOnMap(myLocation);
    }

    public void updateMyLocationOnMap(@NonNull Location myLocation) {
        //Update the location indicator's location.
        locationIndicator.updateLocation(myLocation);
        //Update the map viewport to be centered on the location with zoom level.
        if (mapView.isValid()) {
            mapView.getCamera().lookAt(myLocation.coordinates, mapMeasureZoom);
        }
    }

    private final ServiceConnection connection = new ServiceConnection() {
        public void onServiceConnected(ComponentName className, IBinder service) {
            positioningService = ((HEREBackgroundPositioningService.LocalBinder)service).getService();
            positioningService.registerListener(new BackgroundServiceListener() {
                @Override
                public void onStateUpdate(HEREBackgroundPositioningService.State state) {
                    Log.i(TAG, "onStateUpdate: " + state);
                }

                @Override
                public void onLocationUpdated(Location location) {
                    updateMyLocationOnMap(location);
                }
            });
        }
        public void onServiceDisconnected(ComponentName className) {
            positioningService = null;
        }
    };

    public void startForegroundService() {
        // Starts service and connect a binder.
        HEREBackgroundPositioningService.start(context);
        openBinder();
    }

    public void stopForegroundService() {
        // Stops service and closes binder.
        HEREBackgroundPositioningService.stop(context);
        closeBinder();
    }

    public boolean isForegroundServiceRunning() {
        return shouldUnbind;
    }

    void openBinder() {
        Intent intent = new Intent(activity, HEREBackgroundPositioningService.class);
        if (activity.bindService(intent, connection, Context.BIND_NOT_FOREGROUND)) {
            shouldUnbind = true;
        } else {
            createErrorDialog(R.string.dialog_msg_service_connection_failed, android.R.string.ok, (dialog, which) -> {
                dialog.dismiss();
                activity.finish();
            }).show();
        }
    }

    void closeBinder() {
        if (shouldUnbind) {
            activity.unbindService(connection);
            shouldUnbind = false;
        }
    }

    private Dialog createErrorDialog(int messageId, int buttonId, DialogInterface.OnClickListener clickListener) {
        final android.app.AlertDialog.Builder builder = new android.app.AlertDialog.Builder(context);
        return builder.setMessage(messageId).setPositiveButton(buttonId, clickListener).create();
    }
}
