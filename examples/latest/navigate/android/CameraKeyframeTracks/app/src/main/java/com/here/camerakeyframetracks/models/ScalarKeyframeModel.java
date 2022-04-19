package com.here.camerakeyframetracks.models;

import com.here.time.Duration;

// A data class meant to be used for the creation of ScalarKeyframe instances that hold
// a distance in meters and the animation duration to reach this distance.
public class ScalarKeyframeModel {
    public Double scalar;
    public Duration duration;

    public ScalarKeyframeModel(Double scalar, Duration duration) {
        this.scalar = scalar;
        this.duration = duration;
    }
}
