 /*
  * Copyright (C) 2019-2020 HERE Europe B.V.
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

package com.here.sdk.camera;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.AnimatorSet;
import android.animation.TimeInterpolator;
import android.animation.ValueAnimator;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.mapview.MapCamera;

import java.util.ArrayList;
import java.util.List;

/**
 * A simple class that takes care of smooth map "moveTo"-animations
 * using Android's Animation framework.
 * Note: To interrup animations, optionally listen to map gestures like
 * panning and stop an ongoing animation once detected.
 */
public class CameraAnimator {

    // Default animation should take 2 seconds.
    // Tip: Use a fixed duration, no matter how far to move.
    private static final int DURATION_IN_MILLIS = 2 * 1000;

    // Only one instance allowed.
    private static AnimatorSet animatorSet;

    private final MapCamera camera;
    private final List<Animator> valueAnimatorList = new ArrayList<>();
    private TimeInterpolator timeInterpolator;

    public CameraAnimator(MapCamera camera) {
        this.camera = camera;
    }

    public void setTimeInterpolator(TimeInterpolator timeInterpolator) {
        this.timeInterpolator = timeInterpolator;
    }

    public void moveTo(GeoCoordinates destination, double distanceToEarthInMeters) {
        MapCamera.State targetCameraUpdate = createTargetCameraUpdate(destination, distanceToEarthInMeters);
        createAnimation(targetCameraUpdate);
        startAnimation(targetCameraUpdate);
    }

    private MapCamera.State createTargetCameraUpdate(GeoCoordinates destination, double distanceToEarthInMeters) {
        double targetTilt = 0;

        // Take the shorter bearing difference.
        double targetBearing = camera.getState().targetOrientation.bearing > 180 ? 360 : 0;

        MapCamera.Orientation orientation = new MapCamera.Orientation(targetBearing, targetTilt);
        // Note: We do not use zoomLevel for this use case.
        double zoomLevel = -1;
        return new MapCamera.State(destination, orientation, distanceToEarthInMeters, zoomLevel);
    }

    private void createAnimation(MapCamera.State cameraState) {
        valueAnimatorList.clear();

        // Interpolate current camera values for distanceToEarth, tilt, bearing, lat/lon to the desired new values.
        ValueAnimator distanceToEarthValueAnimator =
                createAnimator(camera.getState().distanceToTargetInMeters, cameraState.distanceToTargetInMeters);
        ValueAnimator tiltValueAnimator =
                createAnimator(camera.getState().targetOrientation.tilt, cameraState.targetOrientation.tilt);
        ValueAnimator bearingValueAnimator =
                createAnimator(camera.getState().targetOrientation.bearing, cameraState.targetOrientation.bearing);
        ValueAnimator latitudeValueAnimator = createAnimator(
                camera.getState().targetCoordinates.latitude, cameraState.targetCoordinates.latitude);
        ValueAnimator longitudeValueAnimator = createAnimator(
                camera.getState().targetCoordinates.longitude, cameraState.targetCoordinates.longitude);

        valueAnimatorList.add(distanceToEarthValueAnimator);
        valueAnimatorList.add(tiltValueAnimator);
        valueAnimatorList.add(bearingValueAnimator);
        valueAnimatorList.add(latitudeValueAnimator);
        valueAnimatorList.add(longitudeValueAnimator);

        // Update all values together.
        longitudeValueAnimator.addUpdateListener(animation -> {
            float distanceToEarth = (float) distanceToEarthValueAnimator.getAnimatedValue();
            float tilt = (float) tiltValueAnimator.getAnimatedValue();
            float bearing = (float) bearingValueAnimator.getAnimatedValue();
            float latitude = (float) latitudeValueAnimator.getAnimatedValue();
            float longitude = (float) longitudeValueAnimator.getAnimatedValue();

            GeoCoordinates intermediateGeoCoordinates = new GeoCoordinates(latitude, longitude);
            MapCamera.Orientation orientation = new MapCamera.Orientation(bearing, tilt);
            // Note: We do not use zoomLevel for this use case.
            double zoomLevel = -1;
            MapCamera.State newCameraState =
                    new MapCamera.State(intermediateGeoCoordinates, orientation, distanceToEarth, zoomLevel);

            updateCamera(newCameraState);
        });
    }

    private void updateCamera(MapCamera.State cameraState) {
        MapCamera.OrientationUpdate orientationUpdate =
                new MapCamera.OrientationUpdate(cameraState.targetOrientation.bearing, cameraState.targetOrientation.tilt);
        camera.lookAt(cameraState.targetCoordinates, orientationUpdate, cameraState.distanceToTargetInMeters);
    }

    private ValueAnimator createAnimator(double from, double to) {
        ValueAnimator valueAnimator = ValueAnimator.ofFloat((float) from, (float )to);
        if (timeInterpolator != null) {
            valueAnimator.setInterpolator(timeInterpolator);
        }
        return valueAnimator;
    }

    private void startAnimation(MapCamera.State cameraState) {
        if (animatorSet != null) {
            animatorSet.cancel();
        }

        animatorSet = new AnimatorSet();
        animatorSet.addListener(new AnimatorListenerAdapter() {
            @Override
            public void onAnimationEnd(Animator animation) {
                updateCamera(cameraState);
            }
        });

        animatorSet.playTogether(valueAnimatorList);
        animatorSet.setDuration(DURATION_IN_MILLIS);
        animatorSet.start();
    }
}
