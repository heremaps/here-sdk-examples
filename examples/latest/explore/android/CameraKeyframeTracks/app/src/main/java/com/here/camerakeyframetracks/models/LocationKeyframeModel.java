package com.here.camerakeyframetracks.models;

import com.here.sdk.core.GeoCoordinates;
import com.here.time.Duration;

// A data class meant to be used for the creation of GeoCoordinatesKeyframe instances that hold
// a GeoCoordinates object and the animation duration to reach these coordinates.
public class LocationKeyframeModel {
     public GeoCoordinates geoCoordinates;
     public Duration duration;

    public LocationKeyframeModel(GeoCoordinates geoCoordinates, Duration duration) {
        this.geoCoordinates = geoCoordinates;
        this.duration = duration;
    }
}
