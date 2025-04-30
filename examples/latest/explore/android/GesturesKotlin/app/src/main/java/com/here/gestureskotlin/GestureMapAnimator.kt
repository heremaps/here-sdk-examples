/*
 * Copyright (C) 2025 HERE Europe B.V.
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
package com.here.gestureskotlin

import android.animation.ValueAnimator
import android.view.animation.AccelerateDecelerateInterpolator
import com.here.sdk.core.Point2D
import com.here.sdk.mapview.MapCamera

/**
 * A simple class that takes care of smooth zoom gestures.
 */
class GestureMapAnimator(private val mapCamera: MapCamera) {

    private var camera: MapCamera? = null
    private var zoomValueAnimator: ValueAnimator? = null
    private var zoomOrigin: Point2D? = null

    init {
        this.camera = mapCamera
    }

    // Starts the zoom in animation.
    fun zoomIn(touchPoint: Point2D) {
        zoomOrigin = touchPoint
        startZoomAnimation(true)
    }

    // Starts the zoom out animation.
    fun zoomOut(touchPoint: Point2D) {
        zoomOrigin = touchPoint
        startZoomAnimation(false)
    }

    private fun startZoomAnimation(zoomIn: Boolean) {
        stopAnimations()

        // A new Animator that zooms the map.
        zoomValueAnimator = createZoomValueAnimator(zoomIn)

        // Start the animation.
        zoomValueAnimator!!.start()
    }

    private fun createZoomValueAnimator(zoomIn: Boolean): ValueAnimator {
        val zoomValueAnimator = ValueAnimator.ofFloat(0.1f, 0f)
        zoomValueAnimator.interpolator = AccelerateDecelerateInterpolator()
        zoomValueAnimator.addUpdateListener { animation: ValueAnimator ->
            // Called periodically until zoomVelocity is zero.
            val zoomVelocity = animation.animatedValue as Float
            var zoomFactor = 1.0
            zoomFactor = if (zoomIn) zoomFactor + zoomVelocity else zoomFactor - zoomVelocity
            // zoomFactor values > 1 will zoom in and values < 1 will zoom out.
            camera!!.zoomBy(zoomFactor, zoomOrigin!!)
        }

        val halfSecond: Long = 500
        zoomValueAnimator.setDuration(halfSecond)

        return zoomValueAnimator
    }

    // Stop any ongoing zoom animation.
    fun stopAnimations() {
        if (zoomValueAnimator != null) {
            zoomValueAnimator!!.cancel()
        }
    }
}