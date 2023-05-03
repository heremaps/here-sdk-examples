package com.here.hikingdiary.locationfilter;

import com.here.sdk.core.Location;

/*
 * LocationFilterStrategy interface defines the structure for filtering locations based on a given criteria.
 * Adopting this interface allows for easy customization and implementation of different strategies for location
 * filtering algorithms without changing the core functionality of the hiking app.
 */
public interface LocationFilterInterface {
    boolean checkIfLocationCanBeUsed(Location location);
}
