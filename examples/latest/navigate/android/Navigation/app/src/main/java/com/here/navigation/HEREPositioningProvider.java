package com.here.navigation;

import androidx.annotation.NonNull;
import android.util.Log;

import com.here.sdk.consent.Consent;
import com.here.sdk.consent.ConsentEngine;
import com.here.sdk.core.Location;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.location.LocationAccuracy;
import com.here.sdk.location.LocationEngine;
import com.here.sdk.location.LocationEngineStatus;
import com.here.sdk.location.LocationFeature;
import com.here.sdk.location.LocationStatusListener;
import com.here.sdk.location.LocationUpdateListener;

import java.util.List;

// A reference implementation using HERE positioning.
// It is not necessary to use this class directly, as the location features can be controlled
// from the LocationProviderImplementation which uses this class to get location updates from
// the device.
public class HEREPositioningProvider {

    public static final String LOG_TAG = HEREPositioningProvider.class.getName();

    private LocationEngine locationEngine;
    private ConsentEngine consentEngine;
    private LocationUpdateListener updateListener;

    private final LocationUpdateListener locationUpdateListener = new LocationUpdateListener() {
        @Override
        public void onLocationUpdated(@NonNull Location location) {
            Log.d(LOG_TAG, "Location update received.");
        }
    };

    private final LocationStatusListener locationStatusListener = new LocationStatusListener() {
        @Override
        public void onStatusChanged(@NonNull LocationEngineStatus locationEngineStatus) {
            Log.d(LOG_TAG, "Location engine status: " + locationEngineStatus.name());
        }

        @Override
        public void onFeaturesNotAvailable(@NonNull List<LocationFeature> features) {
            for (LocationFeature feature : features) {
                Log.d(LOG_TAG, "Location feature not available: " + feature.name());
            }
        }
    };

    public HEREPositioningProvider() {
        try {
            consentEngine = new ConsentEngine();
            locationEngine = new LocationEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization failed: " + e.getMessage());
        }

        // Ask user to optionally opt in to HERE's data collection / improvement program.
        if (consentEngine.getUserConsentState() == Consent.UserReply.NOT_HANDLED) {
            consentEngine.requestUserConsent();
        }

        Location myLastLocation = locationEngine.getLastKnownLocation();
        if (myLastLocation != null) {
            Log.d(LOG_TAG, "Last known location: " + myLastLocation.timestamp);
        } else {
            Log.d(LOG_TAG, "No last known location found.");
        }
    }

    public void startLocating(LocationUpdateListener updateListener) {
        if (locationEngine.isStarted()) {
            return;
        }

        this.updateListener = updateListener;

        // Set listeners to get location updates.
        locationEngine.addLocationUpdateListener(updateListener);
        locationEngine.addLocationUpdateListener(locationUpdateListener);
        locationEngine.addLocationStatusListener(locationStatusListener);

        // Choose the best accuracy for the tbt navigation use case.
        locationEngine.start(LocationAccuracy.NAVIGATION);
    }

    // Use this optionally to hook in additional listeners.
    public void addLocationUpdateListener(LocationUpdateListener locationUpdateListener) {
        locationEngine.addLocationUpdateListener(locationUpdateListener);
    }

    public void removeLocationUpdateListener(LocationUpdateListener locationUpdateListener) {
        locationEngine.removeLocationUpdateListener(locationUpdateListener);
    }

    public void stopLocating() {
        if (!locationEngine.isStarted()) {
            return;
        }

        // Remove listeners and stop location engine.
        locationEngine.removeLocationUpdateListener(updateListener);
        locationEngine.removeLocationUpdateListener(locationUpdateListener);
        locationEngine.removeLocationStatusListener(locationStatusListener);
        locationEngine.stop();
    }
}
