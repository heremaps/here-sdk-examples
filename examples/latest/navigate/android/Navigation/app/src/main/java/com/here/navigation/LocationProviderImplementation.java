package com.here.navigation;

import com.here.sdk.core.Location;
import com.here.sdk.core.LocationListener;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.location.LocationUpdateListener;
import com.here.sdk.navigation.LocationSimulator;
import com.here.sdk.navigation.LocationSimulatorOptions;
import com.here.sdk.routing.Route;

import androidx.annotation.Nullable;

// This class allows to switch between simulated location events (requires a route) and real location updates using
// the advanced capabilities of the HERE positioning features.
public class LocationProviderImplementation {

    @Nullable
    private LocationListener locationListener;
    @Nullable
    public Location lastKnownLocation;

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

    public void start() {
        herePositioningProvider.startLocating(new LocationUpdateListener() {
            @Override
            public void onLocationUpdated(Location location) {
                if (!isSimulated) {
                    handleLocationUpdate(location);
                }
            }
        });
    }

    public void stop() {
        herePositioningProvider.stopLocating();
    }

    // Set by anyone who wants to listen to location updates from either HERE Positioning or LocationSimulator.
    public void setListener(@Nullable LocationListener locationListener) {
        this.locationListener = locationListener;
    }

    private void handleLocationUpdate(Location location) {
        lastKnownLocation = location;

        if (locationListener != null) {
            // The GPS location we received from either the platform or the LocationSimulator is forwarded to a listener.
            locationListener.onLocationUpdated(location);
        }
    }

    // Provides fake GPS signals based on the route geometry.
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
                // Note: This method is deprecated and will be removed
                // from the LocationListener interface with release HERE SDK v4.7.0.
            }
        });

        return locationSimulator;
    }
}
