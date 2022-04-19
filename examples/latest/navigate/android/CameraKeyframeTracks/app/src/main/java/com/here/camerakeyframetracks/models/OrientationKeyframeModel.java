package com.here.camerakeyframetracks.models;

import com.here.sdk.core.GeoOrientation;
import com.here.time.Duration;

// A data class meant to be used for the creation of GeoOrientationKeyframe instances that hold
// a GeoOrientation and the animation duration to reach the GeoOrientation.
public class OrientationKeyframeModel {
    public GeoOrientation geoOrientation;
    public Duration duration;

    public OrientationKeyframeModel(GeoOrientation geoOrientation, Duration duration) {
        this.geoOrientation = geoOrientation;
        this.duration = duration;
    }
}
