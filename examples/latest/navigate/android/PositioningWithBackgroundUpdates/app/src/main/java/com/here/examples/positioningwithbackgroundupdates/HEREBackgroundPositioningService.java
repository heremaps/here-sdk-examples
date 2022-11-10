/*
 * Copyright (C) 2022 HERE Europe B.V.
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

import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Binder;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import androidx.annotation.NonNull;

import com.here.sdk.consent.Consent;
import com.here.sdk.consent.ConsentEngine;
import com.here.sdk.core.Location;
import com.here.sdk.core.LocationListener;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.location.LocationAccuracy;
import com.here.sdk.location.LocationEngine;
import com.here.sdk.location.LocationEngineStatus;
import com.here.sdk.location.LocationFeature;
import com.here.sdk.location.LocationStatusListener;

import java.util.List;

interface BackgroundServiceListener {
    void onStateUpdate(HEREBackgroundPositioningService.State state);
    void onLocationUpdated(Location location);
}

public class HEREBackgroundPositioningService extends Service {
    public enum State {STOPPED, STARTING, RUNNING, FAILED}

    private static final String TAG = HEREBackgroundPositioningService.class.getSimpleName();
    private static final String KEY_CONTENT_INTENT = "contentIntent";
    private static boolean running;
    private NotificationUtils notificationUtils;
    private LocationEngine locationEngine;
    private BackgroundServiceListener serviceListener;
    private State serviceState = State.STOPPED;
    private Location location;

    final private LocationListener locationListener = new LocationListener() {
        @Override
        public void onLocationUpdated(@NonNull Location updateLocation) {
            Log.v(TAG, "onLocationUpdated");
            location = updateLocation;
            setStateRunning();
            reportLocationUpdate();
        }
    };

    final private LocationStatusListener statusListener = new LocationStatusListener() {
        @Override
        public void onStatusChanged(@NonNull LocationEngineStatus locationEngineStatus) {
            Log.i(TAG, "onStatusChanged: " + locationEngineStatus.name());
            switch (locationEngineStatus) {
                case OK:
                case ENGINE_STARTED:
                case ALREADY_STARTED:
                    break;

                default:
                    setStateStopped();
                    break;
            }
        }

        @Override
        public void onFeaturesNotAvailable(@NonNull List<LocationFeature> list) {
            for (final LocationFeature feature : list) {
                Log.i(TAG, "onFeaturesNotAvailable: " + feature.name());
            }
        }
    };

    /**
     * Class for clients to access.  Because we know this service always
     * runs in the same process as its clients, we don't need to deal with
     * IPC.
     */
    public class LocalBinder extends Binder {
        HEREBackgroundPositioningService getService() {
            return HEREBackgroundPositioningService.this;
        }
    }

    public void registerListener(BackgroundServiceListener listener) {
        serviceListener = listener;
    }

    // Start foreground service.
    public static void start(Context context) {
        if (running) {
            return;
        }
        final Intent activityIntent = new Intent(context, MainActivity.class);
        final PendingIntent contentIntent = createPendingIntentGetActivity(context, 0, activityIntent, 0);
        final Intent serviceIntent = new Intent(context, HEREBackgroundPositioningService.class);
        serviceIntent.putExtra(KEY_CONTENT_INTENT, contentIntent);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent);
        } else {
            context.startService(serviceIntent);
        }
    }

    // Stop foreground service.
    public static void stop(Context context) {
        final Intent serviceIntent = new Intent(context, HEREBackgroundPositioningService.class);
        context.stopService(serviceIntent);
    }

    @SuppressWarnings("deprecation")
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // The service is starting, due to a call to startService()
        running = true;
        final PendingIntent contentIntent = intent.getParcelableExtra(KEY_CONTENT_INTENT);
        notificationUtils = new NotificationUtils(getApplicationContext(), contentIntent);
        return startForegroundService();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        // The service is no longer used and is being destroyed
        stopLocating();
        running = false;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    // This is the object that receives interactions from clients.
    private final IBinder binder = new LocalBinder();

    // Start foreground service.
    // Returns start flags, which will be passed to OS
    private int startForegroundService() {
        notificationUtils.setupNotificationChannel();
        setStateValue(State.STARTING);
        startForeground(
                NotificationUtils.getNotificationId(),
                notificationUtils.createNotification(
                        R.drawable.update_notification_status_bar,
                        R.string.status_yellow_title,
                        R.string.status_yellow));
        handleConsent();
        if (!startLocating()) {
            setStateStopped();
            stopSelf();
        }
        return START_NOT_STICKY;
    }

    // Handle SDK user consent.
    private void handleConsent() {
        try {
            final ConsentEngine consentEngine = new ConsentEngine();
            if (consentEngine.getUserConsentState() == Consent.UserReply.NOT_HANDLED) {
                consentEngine.requestUserConsent();
            }
        } catch (InstantiationErrorException ex) {
            Log.e(TAG, "checkConsent: " + ex.getMessage());
        }
    }

    // Start location updates.
    private boolean startLocating() {
        stopLocating();
        try {
            locationEngine = new LocationEngine();
            locationEngine.addLocationListener(locationListener);
            locationEngine.addLocationStatusListener(statusListener);
            final LocationEngineStatus status = locationEngine.start(LocationAccuracy.BEST_AVAILABLE);
            switch (status) {
                case ENGINE_STARTED:
                case ALREADY_STARTED:
                case OK:
                    return true;
                default:
                    Log.e(TAG, "startLocating: start() failed: " + status.name());
                    break;
            }
        } catch (InstantiationErrorException ex) {
            Log.e(TAG, "startLocating: " + ex.getMessage());
        }
        return false;
    }

    // Sets service state to STOPPED and updates notification.
    private void setStateStopped() {
        if (!setStateValue(State.STOPPED)) {
            return;
        }
        notificationUtils.updateNotification(
                R.drawable.update_notification_status_bar,
                R.string.status_grey_title,
                R.string.status_grey);
    }

    // Sets service state to FAILED and updates notification.
    private void setStateFailed() {
        if (!setStateValue(State.FAILED)) {
            return;
        }
        notificationUtils.updateNotification(
                R.drawable.update_notification_status_bar,
                R.string.status_red_title,
                R.string.status_red);
    }

    // Sets service state to RUNNING and updates notification.
    private void setStateRunning() {
        if (!setStateValue(State.RUNNING)) {
            return;
        }
        notificationUtils.updateNotification(
                R.drawable.update_notification_status_bar,
                R.string.status_green_title,
                R.string.status_green);
    }

    // Set service state and report to registered listener if the state changes.
    private boolean setStateValue(State state) {
        if (serviceState == state) {
            return false;
        }
        serviceState = state;
        reportStateValue();
        return true;
    }

    // Reports service state to registered listener.
    private void reportStateValue() {
        final BackgroundServiceListener listener = serviceListener;
        if (listener != null) {
            listener.onStateUpdate(serviceState);
        }
    }

    // Reports location update to registered listener.
    private void reportLocationUpdate() {
        if (location == null) {
            return;
        }
        final BackgroundServiceListener listener = serviceListener;
        if (listener != null) {
            listener.onLocationUpdated(location);
        }
    }

    // Stops location updates.
    private void stopLocating() {
        if (locationEngine == null) {
            return;
        }
        locationEngine.stop();
        locationEngine.removeLocationListener(locationListener);
        locationEngine.removeLocationStatusListener(statusListener);
        locationEngine = null;
    }

    private static PendingIntent createPendingIntentGetActivity(Context context, int id, Intent intent, int flag) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return PendingIntent.getActivity(context, id, intent, PendingIntent.FLAG_IMMUTABLE | flag);
        } else {
            return PendingIntent.getActivity(context, id, intent, flag);
        }
    }
}

