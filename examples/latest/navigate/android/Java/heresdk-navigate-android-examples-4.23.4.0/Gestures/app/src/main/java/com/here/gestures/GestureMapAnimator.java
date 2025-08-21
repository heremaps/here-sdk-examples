/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

import com.here.sdk.core.Point2D;
import com.here.sdk.mapview.MapCamera;

/**
 * A simple class that takes care of smooth zoom gestures.
 */
public class GestureMapAnimator {

    private final MapCamera camera;
    private ValueAnimator zoomValueAnimator;
    private Point2D zoomOrigin;

    @SuppressLint("ClickableViewAccessibility")
    public GestureMapAnimator(MapCamera camera) {
        this.camera = camera;
    }

    // Starts the zoom in animation.
    public void zoomIn(Point2D touchPoint) {
        zoomOrigin = touchPoint;
        startZoomAnimation(true);
    }

    // Starts the zoom out animation.
    public void zoomOut(Point2D touchPoint) {
        zoomOrigin = touchPoint;
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
            double zoomFactor = 1;
            zoomFactor = zoomIn ? zoomFactor + zoomVelocity : zoomFactor - zoomVelocity;
            // zoomFactor values > 1 will zoom in and values < 1 will zoom out.
            camera.zoomBy(zoomFactor, zoomOrigin);
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
