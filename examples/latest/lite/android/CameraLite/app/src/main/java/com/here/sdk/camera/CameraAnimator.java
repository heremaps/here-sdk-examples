 /*
  * Copyright (C) 2019-2022 HERE Europe B.V.
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
import com.here.sdk.mapviewlite.Camera;
import com.here.sdk.mapviewlite.CameraUpdate;

import java.util.ArrayList;
import java.util.List;

/**
 * A simple class that takes care of smooth map "moveTo"-animations
 * using Android's Animation framework.
 */
public class CameraAnimator {

    // Default animation should take 2 seconds.
    private static final int DURATION_IN_MILLIS = 2 * 1000;

    // Only one instance allowed.
    private static AnimatorSet animatorSet;

    private final Camera camera;
    private final List<Animator> valueAnimatorList = new ArrayList<>();
    private TimeInterpolator timeInterpolator;
    private int animationDurationInMillis = DURATION_IN_MILLIS;

    public CameraAnimator(Camera camera) {
        this.camera = camera;
    }

    public void setTimeInterpolator(TimeInterpolator timeInterpolator) {
        this.timeInterpolator = timeInterpolator;
    }

    public void setDurationInMillis(int animationDurationInMillis) {
        this.animationDurationInMillis = animationDurationInMillis;
    }

    public void moveTo(GeoCoordinates destination, double targetZoom) {
        CameraUpdate targetCameraUpdate = createTargetCameraUpdate(destination, targetZoom);
        createAnimation(targetCameraUpdate);
        startAnimation(targetCameraUpdate);
    }

    private CameraUpdate createTargetCameraUpdate(GeoCoordinates destination, double targetZoom) {
        double targetTilt = 0;

        // Take the shorter bearing difference.
        double targetBearing = camera.getBearing() > 180 ? 360 : 0;

        return new CameraUpdate(targetTilt, targetBearing, targetZoom, destination);
    }

    private void createAnimation(CameraUpdate cameraUpdate) {
        valueAnimatorList.clear();

        // Interpolate current values for zoom, tilt, bearing, lat/lon to the desired new values.
        ValueAnimator zoomValueAnimator = createAnimator(camera.getZoomLevel(), cameraUpdate.zoomLevel);
        ValueAnimator tiltValueAnimator = createAnimator(camera.getTilt(), cameraUpdate.tilt);
        ValueAnimator bearingValueAnimator = createAnimator(camera.getBearing(), cameraUpdate.bearing);
        ValueAnimator latitudeValueAnimator = createAnimator(
                camera.getTarget().latitude, cameraUpdate.target.latitude);
        ValueAnimator longitudeValueAnimator = createAnimator(
                camera.getTarget().longitude, cameraUpdate.target.longitude);

        valueAnimatorList.add(zoomValueAnimator);
        valueAnimatorList.add(tiltValueAnimator);
        valueAnimatorList.add(bearingValueAnimator);
        valueAnimatorList.add(latitudeValueAnimator);
        valueAnimatorList.add(longitudeValueAnimator);

        // Update all values together.
        longitudeValueAnimator.addUpdateListener(animation -> {
            float zoom = (float) zoomValueAnimator.getAnimatedValue();
            float tilt = (float) tiltValueAnimator.getAnimatedValue();
            float bearing = (float) bearingValueAnimator.getAnimatedValue();
            float latitude = (float) latitudeValueAnimator.getAnimatedValue();
            float longitude = (float) longitudeValueAnimator.getAnimatedValue();

            GeoCoordinates intermediateGeoCoordinates = new GeoCoordinates(latitude, longitude);
            camera.updateCamera(new CameraUpdate(tilt, bearing, zoom, intermediateGeoCoordinates));
        });
    }

    private ValueAnimator createAnimator(double from, double to) {
        ValueAnimator valueAnimator = ValueAnimator.ofFloat((float) from, (float )to);
        if (timeInterpolator != null) {
            valueAnimator.setInterpolator(timeInterpolator);
        }
        return valueAnimator;
    }

    private void startAnimation(CameraUpdate cameraUpdate) {
        if (animatorSet != null) {
            animatorSet.cancel();
        }

        animatorSet = new AnimatorSet();
        animatorSet.addListener(new AnimatorListenerAdapter() {
            @Override
            public void onAnimationEnd(Animator animation) {
                camera.updateCamera(cameraUpdate);
            }
        });

        animatorSet.playTogether(valueAnimatorList);
        animatorSet.setDuration(animationDurationInMillis);
        animatorSet.start();
    }
}
