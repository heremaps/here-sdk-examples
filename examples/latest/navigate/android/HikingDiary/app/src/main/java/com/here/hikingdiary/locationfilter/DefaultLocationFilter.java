package com.here.hikingdiary.locationfilter;

import com.here.sdk.core.Location;

// The DefaultLocationFilter class implements the LocationFilterInterface and
// allows every location signal to pass in order to visualize the raw GPS signals on the map.
public class DefaultLocationFilter implements LocationFilterInterface {
    @Override
    public boolean checkIfLocationCanBeUsed(Location location) {
        return true;
    }
}