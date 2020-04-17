package com.here.navigation;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.location.LocationProvider;
import android.os.Bundle;
import android.support.annotation.Nullable;
import android.support.v4.app.ActivityCompat;
import android.util.Log;

import static android.content.Context.LOCATION_SERVICE;

// A simple Android based positioning implementation.
public class PlatformPositioningProvider implements LocationListener {

    public static final String LOG_TAG = PlatformPositioningProvider.class.getName();
    public static final int LOCATION_UPDATE_INTERVAL_IN_MS = 100;

    private Context context;
    private LocationManager locationManager;
    @Nullable
    private PlatformLocationListener platformLocationListener;

    public interface PlatformLocationListener {
        void onLocationUpdated(Location location);
    }

    public PlatformPositioningProvider(Context context) {
        this.context = context;
    }

    @Override
    public void onLocationChanged(android.location.Location location) {
        if (platformLocationListener != null) {
            platformLocationListener.onLocationUpdated(location);
        }
    }

    @Override
    public void onStatusChanged(String provider, int status, Bundle extras) {
        switch(status){
            case LocationProvider.AVAILABLE:
                Log.d(LOG_TAG, "PlatformPositioningProvider status: AVAILABLE");
                break;
            case LocationProvider.OUT_OF_SERVICE:
                Log.d(LOG_TAG, "PlatformPositioningProvider status: OUT_OF_SERVICE");
                break;
            case LocationProvider.TEMPORARILY_UNAVAILABLE:
                Log.d(LOG_TAG, "PlatformPositioningProvider status: TEMPORARILY_UNAVAILABLE");
                break;
            default:
                Log.d(LOG_TAG, "PlatformPositioningProvider status: UNKNOWN");
        }
    }

    @Override
    public void onProviderEnabled(String provider) {
        Log.d(LOG_TAG, "PlatformPositioningProvider enabled.");
    }

    @Override
    public void onProviderDisabled(String provider) {
        Log.d(LOG_TAG, "PlatformPositioningProvider disabled.");
    }

    public void startLocating(PlatformLocationListener locationCallback) {
        if (this.platformLocationListener != null) {
            throw new RuntimeException("Please stop locating before starting again.");
        }

        if (ActivityCompat.checkSelfPermission(context,
                Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(context,
                        Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            // Should never happen. PermissionsRequestor already took care.
            Log.d(LOG_TAG, "Positioning permissions denied.");
            return;
        }

        this.platformLocationListener = locationCallback;
        locationManager = (LocationManager) context.getSystemService(LOCATION_SERVICE);

        if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) &&
                context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS)) {
            locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, LOCATION_UPDATE_INTERVAL_IN_MS, 1,this);
        } else if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, LOCATION_UPDATE_INTERVAL_IN_MS, 1,this);
        } else {
            Log.d(LOG_TAG, "Positioning not possible.");
            stopLocating();
        }
    }

    public void stopLocating() {
        if (locationManager == null) {
            return;
        }

        locationManager.removeUpdates(this);
        platformLocationListener = null;
    }
}
