/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

package com.here.camerakeyframetracks;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.here.sdk.animation.AnimationListener;
import com.here.sdk.animation.AnimationState;
import com.here.sdk.animation.EasingFunction;
import com.here.sdk.animation.GeoCoordinatesKeyframe;
import com.here.sdk.animation.GeoOrientationKeyframe;
import com.here.sdk.animation.KeyframeInterpolationMode;
import com.here.sdk.animation.ScalarKeyframe;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoOrientation;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapCameraKeyframeTrack;
import com.here.sdk.mapview.MapView;
import com.here.time.Duration;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class CameraKeyframeTracksExample {

    private static final String TAG = CameraKeyframeTracksExample.class.getName();

    private final MapView mapView;

    public CameraKeyframeTracksExample(MapView mapView) {
        this.mapView = mapView;
    }

    public void startTripToNYC() {
        List<MapCameraKeyframeTrack> mapCameraKeyframeTracks = createMapCameraKeyframeTracks();

        MapCameraAnimation mapCameraAnimation;

        try {
            mapCameraAnimation = MapCameraAnimationFactory.createAnimation(mapCameraKeyframeTracks);
        } catch (MapCameraAnimation.InstantiationException e) {
            Log.e(TAG, e.error.name());
            return;
        }

        // This animation can be started and replayed. When started, it will always start from the first keyframe.
        mapView.getCamera().startAnimation(mapCameraAnimation, new AnimationListener() {
            @Override
            public void onAnimationStateChanged(@NonNull AnimationState animationState) {
                switch (animationState) {
                    case STARTED:
                        Log.d(TAG, "Animation started.");
                        break;
                    case CANCELLED:
                        Log.d(TAG, "Animation cancelled.");
                        break;
                    case COMPLETED:
                        Log.d(TAG, "Animation finished.");
                        break;
                }
            }
        });
    }

    public void stopTripToNYCAnimation() {
        mapView.getCamera().cancelAnimations();
    }

    @Nullable
    private List<MapCameraKeyframeTrack> createMapCameraKeyframeTracks() {
        MapCameraKeyframeTrack geoCoordinatesMapCameraKeyframeTrack;
        MapCameraKeyframeTrack scalarMapCameraKeyframeTrack;
        MapCameraKeyframeTrack geoOrientationMapCameraKeyframeTrack;

        List<GeoCoordinatesKeyframe> geoCoordinatesKeyframes = createGeoCoordinatesKeyframes();
        List<ScalarKeyframe> scalarKeyframes = createScalarKeyframes();
        List<GeoOrientationKeyframe> geoOrientationKeyframes = createGeoOrientationKeyframes();

        try {
            geoCoordinatesMapCameraKeyframeTrack = MapCameraKeyframeTrack.lookAtTarget(geoCoordinatesKeyframes, EasingFunction.LINEAR, KeyframeInterpolationMode.LINEAR);
            scalarMapCameraKeyframeTrack = MapCameraKeyframeTrack.lookAtDistance(scalarKeyframes, EasingFunction.LINEAR, KeyframeInterpolationMode.LINEAR);
            geoOrientationMapCameraKeyframeTrack = MapCameraKeyframeTrack.lookAtOrientation(geoOrientationKeyframes, EasingFunction.LINEAR, KeyframeInterpolationMode.LINEAR);
        } catch (MapCameraKeyframeTrack.InstantiationException e) {
            // Throws an error if keyframes are empty or the duration of keyframes is invalid.
            Log.e(TAG, e.toString());
            return null;
        }

        // Add different kinds of animation tracks that can be played back simultaneously.
        // Each track can have a different total duration.
        // The animation completes, when the longest track has been competed.
        List<MapCameraKeyframeTrack> mapCameraKeyframeTracks = new ArrayList<>();

        // This changes the camera's location over time.
        mapCameraKeyframeTracks.add(geoCoordinatesMapCameraKeyframeTrack);
        // This changes the camera's distance (= scalar) to earth over time.
        mapCameraKeyframeTracks.add(scalarMapCameraKeyframeTrack);
        // This changes the camera's orientation over time.
        mapCameraKeyframeTracks.add(geoOrientationMapCameraKeyframeTrack);

        return mapCameraKeyframeTracks;
    }

    private List<GeoCoordinatesKeyframe> createGeoCoordinatesKeyframes() {
        List<GeoCoordinatesKeyframe> geoCoordinatesKeyframes = new ArrayList<>();

        // The duration indicates the time it takes to reach the GeoCoordinates of the keyframe.
        Collections.addAll(
                geoCoordinatesKeyframes,
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.685869754854544, -74.02550202768754), Duration.ofMillis(0)), // Statue of Liberty
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.69051652745291, -74.04455943649657), Duration.ofMillis(5000)), // Statue of Liberty
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.69051652745291, -74.04455943649657), Duration.ofMillis(7000)), // Statue of Liberty
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.69051652745291, -74.04455943649657), Duration.ofMillis(9000)), // Statue of Liberty
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.690266839135, -74.01237515471776), Duration.ofMillis(5000)), // Governor Island
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.7116777285189, -74.01248494562448), Duration.ofMillis(6000)), // World Trade Center
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.71083291395444, -74.01226399217569), Duration.ofMillis(6000)), // World Trade Center
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.719259512385506, -74.01171007254635), Duration.ofMillis(5000)), // Manhattan College
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.73603959180013, -73.98968489844603), Duration.ofMillis(6000)), // Union Square
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.741732824650214, -73.98825255774022), Duration.ofMillis(5000)), // Flatiron
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.74870637098952, -73.98515306630678), Duration.ofMillis(6000)), // Empire State Building
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.742693509776856, -73.95937093336781), Duration.ofMillis(3000)), // Queens Midtown
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.75065611103842, -73.96053139022635), Duration.ofMillis(4000)), // Roosevelt Island
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.756823163883794, -73.95461519921352), Duration.ofMillis(4000)), // Queens Bridge
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.763573707276784, -73.94571562970638), Duration.ofMillis(4000)), // Roosevelt Bridge
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.773052036400294, -73.94027981305442), Duration.ofMillis(3000)), // Roosevelt Lighthouse
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.78270548734745, -73.92189566092568), Duration.ofMillis(3000)), // Hell gate Bridge
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.78406704306872, -73.91746017917936), Duration.ofMillis(2000)), // Ralph Park
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.768075472169045, -73.97446921306035), Duration.ofMillis(2000)), // Wollman Rink
                new GeoCoordinatesKeyframe(new GeoCoordinates(40.78255966255712, -73.9586425508515), Duration.ofMillis(3000))); // Solomon Museum

        return geoCoordinatesKeyframes;
    }

    private List<ScalarKeyframe> createScalarKeyframes() {
        List<ScalarKeyframe> scalarKeyframesList = new ArrayList<>();

        // The duration indicates the time it takes to reach the scalar (= camera distance in meters) of the keyframe.
        Collections.addAll(
                scalarKeyframesList,
                // Change the camera distance from 80000000 meters to 400 meters over time.
                new ScalarKeyframe(80000000.0, Duration.ofMillis(0)),
                new ScalarKeyframe(8000000.0, Duration.ofMillis(2000)),
                new ScalarKeyframe(8000.0, Duration.ofMillis(2000)),
                new ScalarKeyframe(1000.0, Duration.ofMillis(2000)),
                new ScalarKeyframe(400.0, Duration.ofMillis(3000)));

        return scalarKeyframesList;
    }

    private List<GeoOrientationKeyframe> createGeoOrientationKeyframes() {
        List<GeoOrientationKeyframe> geoOrientationKeyframeList = new ArrayList<>();

        // The duration indicates the time it takes to achieve the GeoOrientation of the keyframe.
        Collections.addAll(
                geoOrientationKeyframeList,
                new GeoOrientationKeyframe(new GeoOrientation(30, 60) , Duration.ofMillis(0)),
                new GeoOrientationKeyframe(new GeoOrientation(-40, 80), Duration.ofMillis(6000)),
                new GeoOrientationKeyframe(new GeoOrientation(30, 70), Duration.ofMillis(6000)),
                new GeoOrientationKeyframe(new GeoOrientation(70, 30), Duration.ofMillis(4000)),
                new GeoOrientationKeyframe(new GeoOrientation(-30, 70), Duration.ofMillis(5000)),
                new GeoOrientationKeyframe(new GeoOrientation(30, 70), Duration.ofMillis(5000)),
                new GeoOrientationKeyframe(new GeoOrientation(40, 70), Duration.ofMillis(5000)),
                new GeoOrientationKeyframe(new GeoOrientation(80, 40), Duration.ofMillis(5000)),
                new GeoOrientationKeyframe(new GeoOrientation(30, 70), Duration.ofMillis(5000)));

        return geoOrientationKeyframeList;
    }
}
