package com.here.navigation;

import android.os.Handler;
import androidx.annotation.Nullable;
import android.util.Log;

import com.here.sdk.core.Location;
import com.here.sdk.core.LocationListener;
import com.here.sdk.core.LocationProvider;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.location.LocationUpdateListener;
import com.here.sdk.navigation.LocationSimulator;
import com.here.sdk.navigation.LocationSimulatorOptions;
import com.here.sdk.routing.Route;

// A class that conforms the HERE SDK's LocationProvider interface.
// This class is required by Navigator to receive location updates from either the device or the LocationSimulator.
public class LocationProviderImplementation implements LocationProvider {

    private static final String TAG = LocationProviderImplementation.class.getName();

    public static final int TIMEOUT_POLL_INTERVAL_IN_MS = 500;
    public static final int TIMEOUT_INTERVAL_IN_MS = 2000;

    // Used by the Navigator instance to listen for location updates.
    @Nullable
    private LocationListener locationListener;
    @Nullable
    public Location lastKnownLocation;

    // A loop to check for timeouts between location events.
    private final Handler timeoutHandler = new Handler();
    private final HEREPositioningProvider herePositioningProvider;
    private LocationSimulator locationSimulator;
    private boolean isSimulated;

    public LocationProviderImplementation() {
        herePositioningProvider = new HEREPositioningProvider();
    }

    // Provides location updates based on the given route.
    public void enableRoutePlayback(Route route) {
        if (locationSimulator != null) {
            locationSimulator.stop();
        }

        locationSimulator = createLocationSimulator(route);
        locationSimulator.start();
        isSimulated = true;
    }

    // Provides location updates based on the device's GPS sensor.
    public void enableDevicePositioning() {
        if (locationSimulator != null) {
            locationSimulator.stop();
            locationSimulator = null;
        }

        isSimulated = false;
    }

    @Override
    public void start() {
        herePositioningProvider.startLocating(new LocationUpdateListener() {
            @Override
            public void onLocationUpdated(Location location) {
                if (!isSimulated) {
                    handleLocationUpdate(location);
                }
            }
        });

        timeoutHandler.postDelayed(timeoutRunnable, TIMEOUT_POLL_INTERVAL_IN_MS);
    }

    // Use this optionally to hook in additional listeners.
    public void addLocationUpdateListener(LocationUpdateListener locationUpdateListener) {
        herePositioningProvider.addLocationUpdateListener(locationUpdateListener);
    }

    public void removeLocationUpdateListener(LocationUpdateListener locationUpdateListener) {
        herePositioningProvider.removeLocationUpdateListener(locationUpdateListener);
    }

    @Override
    public void stop() {
        herePositioningProvider.stopLocating();
        timeoutHandler.removeCallbacks(timeoutRunnable);
    }

    @Nullable
    @Override
    public LocationListener getListener() {
        return locationListener;
    }

    // Called by Navigator instance to listen for location updates.
    @Override
    public void setListener(@Nullable LocationListener locationListener) {
        this.locationListener = locationListener;
    }

    private void handleLocationUpdate(Location location) {
        lastKnownLocation = location;

        if (locationListener != null) {
            // The location we received from either the platform or the LocationSimulator is forwarded to the Navigator.
            locationListener.onLocationUpdated(location);
        }
    }

    private final Runnable timeoutRunnable = new Runnable(){
        public void run(){
            try {
                timeoutLoop();
                timeoutHandler.postDelayed(this, TIMEOUT_POLL_INTERVAL_IN_MS);
            } catch (Exception exception) {
                exception.printStackTrace();
            }
        }
    };

    private void timeoutLoop() {
        if (isSimulated) {
            // LocationSimulator already includes simulated timeout events.
            return;
        }

        if (lastKnownLocation != null) {
            double millisecondsSince1970 = lastKnownLocation.timestamp.getTime();
            double timeIntervalInMs = System.currentTimeMillis() - millisecondsSince1970;
            if (locationListener != null && timeIntervalInMs > TIMEOUT_INTERVAL_IN_MS) {
                //If the last location is older than TIMEOUT_INTERVAL_IN_MS, we forward a timeout event to Navigator.
                locationListener.onLocationTimeout();
                Log.d(TAG, "GPS timeout detected: " + timeIntervalInMs);
            }
        }
    }

    // Provides fake GPS signals based on the route geometry.
    // LocationSimulator can also be set directly to the Navigator, but here we want to have the flexibility to
    // switch between real and simulated GPS data.
    private LocationSimulator createLocationSimulator(Route route) {
        double speedFactor = 10;
        int notificationIntervalInMilliseconds = 100;
        LocationSimulatorOptions locationSimulatorOptions =
                new LocationSimulatorOptions(speedFactor, notificationIntervalInMilliseconds);

        LocationSimulator locationSimulator;

        try {
            locationSimulator = new LocationSimulator(route, locationSimulatorOptions);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of LocationSimulator failed: " + e.error.name());
        }

        locationSimulator.setListener(new LocationListener() {
            @Override
            public void onLocationUpdated(Location location) {
                if (isSimulated) {
                    handleLocationUpdate(location);
                }
            }

            @Override
            public void onLocationTimeout() {
                if (isSimulated) {
                    locationListener.onLocationTimeout();
                }
            }
        });

        return locationSimulator;
    }
}
