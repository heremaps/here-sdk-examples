/*
 * Copyright (C) 2019 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
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

package com.here.gestures;

import android.animation.ValueAnimator;
import android.annotation.SuppressLint;
import android.view.animation.AccelerateDecelerateInterpolator;

import com.here.sdk.mapviewlite.Camera;
import com.here.sdk.mapviewlite.MapViewLite;

/**
 * A simple class that takes care of smooth zoom gestures.
 */
public class GestureMapAnimator {

    private final Camera camera;
    private ValueAnimator zoomValueAnimator;

    @SuppressLint("ClickableViewAccessibility")
    public GestureMapAnimator(MapViewLite mapView) {
        camera = mapView.getCamera();
    }

    // Starts the zoom in animation.
    public void zoomIn() {
        startZoomAnimation(true);
    }

    // Starts the zoom out animation.
    public void zoomOut() {
        startZoomAnimation(false);
    }

    private void startZoomAnimation(boolean zoomIn) {
        stopAnimations();

        // A new Animator that zooms the map.
        zoomValueAnimator = createZoomValueAnimator(zoomIn);

        // Start the animation.
        zoomValueAnimator.start();
    }

    private ValueAnimator createZoomValueAnimator(boolean zoomIn) {
        ValueAnimator zoomValueAnimator = ValueAnimator.ofFloat(0.1F, 0);
        zoomValueAnimator.setInterpolator(new AccelerateDecelerateInterpolator());
        zoomValueAnimator.addUpdateListener(animation -> {
            // Called periodically until zoomVelocity is zero.
            float zoomVelocity = (float) animation.getAnimatedValue();
            double zoom = camera.getZoomLevel();
            zoom = zoomIn ? zoom + zoomVelocity : zoom - zoomVelocity;
            camera.setZoomLevel(zoom);
        });

        long halfSecond = 500;
        zoomValueAnimator.setDuration(halfSecond);

        return zoomValueAnimator;
    }

    // Stop any ongoing zoom animation.
    public void stopAnimations() {
        if (zoomValueAnimator != null) {
            zoomValueAnimator.cancel();
        }
    }
}
