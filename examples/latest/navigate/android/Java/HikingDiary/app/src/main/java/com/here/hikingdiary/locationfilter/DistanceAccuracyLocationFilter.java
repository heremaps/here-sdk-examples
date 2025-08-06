package com.here.hikingdiary.locationfilter;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Location;

/*
 * The DistanceAccuracyLocationFilter class implements the LocationFilterInterface and provides a filtering strategy based on accuracy
 * and distance from last accepted location. This class works on two filter mechanisms.
 * AccuracyFilter - Filters the location data based on the accuracy of the GPS readings, and only includes the readings with a certain level of accuracy.
 * DistanceFilter - Filters the location data based on the locations that are within the specified distance from the last accepted location.
 */
public class DistanceAccuracyLocationFilter implements LocationFilterInterface {
    // These two parameters define if incoming location updates are considered to be good enough.
    // In the field, the GPS signal can be very unreliable, so we need to filter out inaccurate signals.
    private static final double ACCURACY_RADIUS_THRESHOLD_IN_METERS = 10.0;
    private static final double DISTANCE_THRESHOLD_IN_METERS = 15.0;
    private GeoCoordinates lastAcceptedGeoCoordinates;

    @Override
    public boolean checkIfLocationCanBeUsed(Location location) {
        if (isAccuracyGoodEnough(location) && isDistanceFarEnough(location)) {
            lastAcceptedGeoCoordinates = location.coordinates;
            return true;
        }
        return false;
    }

    // Checks if the accuracy of the received GPS signal is good enough.
    private boolean isAccuracyGoodEnough(Location location) {
        Double horizontalAccuracyInMeters = location.horizontalAccuracyInMeters;
        if (horizontalAccuracyInMeters == null) {
            return false;
        }

        // If the location lies within the radius of ACCURACY_RADIUS_THRESHOLD_IN_METERS then we accept it.
        if (horizontalAccuracyInMeters <= ACCURACY_RADIUS_THRESHOLD_IN_METERS) {
            return true;
        }
        return false;
    }

    // Checks if last accepted location is farther away than xx meters.
    // If it is, the new location will be accepted.
    // This way we can filter out signals that are caused by a non-moving user.
    private boolean isDistanceFarEnough(Location location) {
        if (lastAcceptedGeoCoordinates == null) {
            // We always accept the first location.
            lastAcceptedGeoCoordinates = location.coordinates;
            return true;
        }

        double distance = location.coordinates.distanceTo(lastAcceptedGeoCoordinates);
        if (distance >= DISTANCE_THRESHOLD_IN_METERS) {
            return true;
        }
        return false;
    }
}