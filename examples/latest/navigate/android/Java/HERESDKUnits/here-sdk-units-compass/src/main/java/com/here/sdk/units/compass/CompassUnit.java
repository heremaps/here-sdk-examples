/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

package com.here.sdk.units.compass;

import android.util.Log;
import android.view.View;
import android.widget.ImageButton;

import androidx.annotation.NonNull;
import androidx.fragment.app.FragmentManager;

import com.here.sdk.animation.AnimationListener;
import com.here.sdk.animation.AnimationState;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoCoordinatesUpdate;
import com.here.sdk.core.GeoOrientationUpdate;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapCameraListener;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapView;
import com.here.time.Duration;

// The HERE SDK unit class that defines the logic for the view.
// The logic controls what to show.
public class CompassUnit {

    private static final String TAG = CompassUnit.class.getSimpleName();
    private final ImageButton button;

    protected CompassUnit(ImageButton button) {
        this.button = button;
    }

    /**
     * Sets up the button to show the map switcher menu.
     * It allows to select four map schemes.
     *
     * Call this from i.e. an AppCompatActivity to get the FragmentManager with
     * getSupportFragmentManager().
     */
    public void setup(MapView mapView, FragmentManager manager) {
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                resetNorthUpWithAnimation(mapView);
            }
        });

        // When the rotation of the map changes, rotate the compass button accordingly.
        listenToRotationChanges(mapView);
    }

    // Show the button again, after hide() was called.
    public void show() {
        button.setVisibility(View.VISIBLE);
    }

    // Hide the button and do not keep the space it occupies in the layout.
    public void hide() {
        button.setVisibility(View.GONE);
    }
    
    // Animate the map to North-Up orientation.
    private void resetNorthUpWithAnimation(@NonNull MapView mapView) {
        GeoCoordinates currentLocation = mapView.getCamera().getState().targetCoordinates;
        GeoCoordinatesUpdate geoCoordinatesUpdate = new GeoCoordinatesUpdate(currentLocation);

        double bearingInDegrees = 0;
        double tiltInDegrees = 0;
        GeoOrientationUpdate orientationUpdate = new GeoOrientationUpdate(bearingInDegrees, tiltInDegrees);

        double currentDistanceInMeters = mapView.getCamera().getState().distanceToTargetInMeters;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, currentDistanceInMeters);

        double bowFactor = 1;
        MapCameraAnimation animation = MapCameraAnimationFactory.flyTo(
                geoCoordinatesUpdate, orientationUpdate, mapMeasureZoom, bowFactor, Duration.ofSeconds(3));
        mapView.getCamera().startAnimation(animation, new AnimationListener() {
            @Override
            public void onAnimationStateChanged(@NonNull AnimationState animationState) {
                if (animationState == AnimationState.COMPLETED || animationState == AnimationState.CANCELLED) {
                    Log.d(TAG, "Reset North-Up animation finished with state: " + animationState);
                }
            }
        });
    }

    private void listenToRotationChanges(@NonNull MapView mapView) {
        mapView.getCamera().addListener(new MapCameraListener() {
            @Override
            public void onMapCameraUpdated(@NonNull MapCamera.State state) {
                if (button.getVisibility() == View.GONE) {
                    return;
                }

                double bearingInDegrees = mapView.getCamera().getState().orientationAtTarget.bearing;
                rotateButton(-bearingInDegrees);
            }
        });
    }

    // Rotate the button clockwise in degrees to indicate the current bearing.
    private void rotateButton(double bearingInDegrees) {
        button.setRotation((float) bearingInDegrees);
    }
}
