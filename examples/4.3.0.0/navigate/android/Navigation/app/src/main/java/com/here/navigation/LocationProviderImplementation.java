package com.here.navigation;

import android.content.Context;
import android.os.Handler;
import android.support.annotation.Nullable;
import android.util.Log;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Location;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.navigation.LocationListener;
import com.here.sdk.navigation.LocationProvider;
import com.here.sdk.navigation.LocationSimulator;
import com.here.sdk.navigation.LocationSimulatorOptions;
import com.here.sdk.routing.Route;

import java.util.Date;

// A class that conforms the HERE SDK's LocationProvider interface.
// This class is required by Navigator to receive location updates from either the device or the LocationSimulator.
public class LocationProviderImplementation implements LocationProvider {

    private static final String TAG = LocationProviderImplementation.class.getName();

    public static final int TIMEOUT_POLL_INTERVAL_IN_MS = 500;
    public static final int TIMEOUT_INTERVAL_IN_MS = 3000;

    // Set by the Navigator instance to listen for location updates.
    @Nullable
    private LocationListener locationListener;
    @Nullable
    public Location lastKnownLocation;

    // A loop to check for timeouts between location events.
    private final Handler timeoutHandler = new Handler();
    private final PlatformPositioningProvider platformPositioningProvider;
    private LocationSimulator locationSimulator;
    private boolean isSimulated;

    public LocationProviderImplementation(Context context) {
        platformPositioningProvider = new PlatformPositioningProvider(context);
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
        platformPositioningProvider.startLocating(new PlatformPositioningProvider.PlatformLocationListener() {
            @Override
            public void onLocationUpdated(android.location.Location location) {
                if (!isSimulated) {
                    handleLocationUpdate(convertLocation(location));
                }
            }
        });

        timeoutHandler.postDelayed(timeoutRunnable, TIMEOUT_POLL_INTERVAL_IN_MS);
    }

    @Override
    public void stop() {
        platformPositioningProvider.stopLocating();
        timeoutHandler.removeCallbacks(timeoutRunnable);
    }

    @Nullable
    @Override
    public LocationListener getListener() {
        return locationListener;
    }

    @Override
    public void setListener(@Nullable LocationListener locationListener) {
        this.locationListener = locationListener;
    }

    private void handleLocationUpdate(Location location) {
        lastKnownLocation = location;

        if (locationListener != null) {
            // The GPS location we received from either the platform or the LocationSimulator is forwarded to the Navigator.
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

    // Converts platform location to com.here.sdk.core.Location.
    private Location convertLocation(android.location.Location nativeLocation) {
        GeoCoordinates geoCoordinates = new GeoCoordinates(
                nativeLocation.getLatitude(),
                nativeLocation.getLongitude(),
                nativeLocation.getAltitude());
        Location location = new Location(geoCoordinates, new Date());
        location.bearingInDegrees = (double) nativeLocation.getBearing();
        location.speedInMetersPerSecond = (double) nativeLocation.getSpeed();
        location.horizontalAccuracyInMeters = (double) nativeLocation.getAccuracy();

        return location;
    }
}
