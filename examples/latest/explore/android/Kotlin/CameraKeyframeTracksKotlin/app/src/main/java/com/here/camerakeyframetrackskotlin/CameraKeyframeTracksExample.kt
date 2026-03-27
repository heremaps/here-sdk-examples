/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

package com.here.camerakeyframetrackskotlin

import android.util.Log
import com.here.sdk.animation.AnimationListener
import com.here.sdk.animation.AnimationState
import com.here.sdk.animation.Easing
import com.here.sdk.animation.EasingFunction
import com.here.sdk.animation.GeoCoordinatesKeyframe
import com.here.sdk.animation.GeoOrientationKeyframe
import com.here.sdk.animation.KeyframeInterpolationMode
import com.here.sdk.animation.ScalarKeyframe
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoOrientation
import com.here.sdk.mapview.MapCameraAnimationFactory
import com.here.sdk.mapview.MapCameraKeyframeTrack
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapView
import com.here.time.Duration

class CameraKeyframeTracksExample(private val mapView: MapView) {
    fun startTripToNYC() {
        val mapCameraKeyframeTracks = createMapCameraKeyframeTracks()

        val mapCameraKeyframeTracksNonNull = mapCameraKeyframeTracks ?: return logError("MapCameraKeyframeTracks are null. Cannot start route animation.")

        val mapCameraAnimation =
            MapCameraAnimationFactory.createAnimation(mapCameraKeyframeTracksNonNull)

        // This animation can be started and replayed. When started, it will always start from the first keyframe.
        mapView.camera.startAnimation(mapCameraAnimation, object : AnimationListener {
            override fun onAnimationStateChanged(animationState: AnimationState) {
                when (animationState) {
                    AnimationState.STARTED -> Log.d(TAG, "Animation started.")
                    AnimationState.CANCELLED -> Log.d(TAG, "Animation cancelled.")
                    AnimationState.COMPLETED -> Log.d(TAG, "Animation finished.")
                }
            }
        })
    }

    fun stopTripToNYCAnimation() {
        mapView.camera.cancelAnimations()
    }

    private fun createMapCameraKeyframeTracks(): MutableList<MapCameraKeyframeTrack>? {
        val geoCoordinatesMapCameraKeyframeTrack: MapCameraKeyframeTrack?
        val scalarMapCameraKeyframeTrack: MapCameraKeyframeTrack?
        val geoOrientationMapCameraKeyframeTrack: MapCameraKeyframeTrack?

        val geoCoordinatesKeyframes = createGeoCoordinatesKeyframes()
        val scalarKeyframes = createScalarKeyframes()
        val geoOrientationKeyframes = createGeoOrientationKeyframes()

        try {
            geoCoordinatesMapCameraKeyframeTrack = MapCameraKeyframeTrack.lookAtTarget(
                geoCoordinatesKeyframes,
                Easing(EasingFunction.LINEAR),
                KeyframeInterpolationMode.LINEAR
            )
            scalarMapCameraKeyframeTrack = MapCameraKeyframeTrack.lookAtDistance(
                MapMeasure.Kind.DISTANCE_IN_METERS,
                scalarKeyframes,
                Easing(EasingFunction.LINEAR),
                KeyframeInterpolationMode.LINEAR
            )
            geoOrientationMapCameraKeyframeTrack = MapCameraKeyframeTrack.lookAtOrientation(
                geoOrientationKeyframes,
                Easing(EasingFunction.LINEAR),
                KeyframeInterpolationMode.LINEAR
            )
        } catch (e: MapCameraKeyframeTrack.InstantiationException) {
            // Throws an error if keyframes are empty or the duration of keyframes is invalid.
            Log.e(TAG, e.toString())
            return null
        }

        // Add different kinds of animation tracks that can be played back simultaneously.
        // Each track can have a different total duration.
        // The animation completes, when the longest track has been competed.
        val mapCameraKeyframeTracks = mutableListOf<MapCameraKeyframeTrack>()

        // This changes the camera's location over time.
        mapCameraKeyframeTracks.add(geoCoordinatesMapCameraKeyframeTrack)
        // This changes the camera's distance (= scalar) to earth over time.
        mapCameraKeyframeTracks.add(scalarMapCameraKeyframeTrack)
        // This changes the camera's orientation over time.
        mapCameraKeyframeTracks.add(geoOrientationMapCameraKeyframeTrack)

        return mapCameraKeyframeTracks
    }

    private fun createGeoCoordinatesKeyframes(): List<GeoCoordinatesKeyframe> {
        // The duration indicates the time it takes to reach the GeoCoordinates of the keyframe.
        return listOf(
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.685869754854544, -74.02550202768754),
                Duration.ofMillis(0)
            ),  // Statue of Liberty
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.69051652745291, -74.04455943649657),
                Duration.ofMillis(5000)
            ),  // Statue of Liberty
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.69051652745291, -74.04455943649657),
                Duration.ofMillis(7000)
            ),  // Statue of Liberty
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.69051652745291, -74.04455943649657),
                Duration.ofMillis(9000)
            ),  // Statue of Liberty
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.690266839135, -74.01237515471776),
                Duration.ofMillis(5000)
            ),  // Governor Island
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.7116777285189, -74.01248494562448),
                Duration.ofMillis(6000)
            ),  // World Trade Center
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.71083291395444, -74.01226399217569),
                Duration.ofMillis(6000)
            ),  // World Trade Center
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.719259512385506, -74.01171007254635),
                Duration.ofMillis(5000)
            ),  // Manhattan College
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.73603959180013, -73.98968489844603),
                Duration.ofMillis(6000)
            ),  // Union Square
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.741732824650214, -73.98825255774022),
                Duration.ofMillis(5000)
            ),  // Flatiron
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.74870637098952, -73.98515306630678),
                Duration.ofMillis(6000)
            ),  // Empire State Building
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.742693509776856, -73.95937093336781),
                Duration.ofMillis(3000)
            ),  // Queens Midtown
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.75065611103842, -73.96053139022635),
                Duration.ofMillis(4000)
            ),  // Roosevelt Island
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.756823163883794, -73.95461519921352),
                Duration.ofMillis(4000)
            ),  // Queens Bridge
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.763573707276784, -73.94571562970638),
                Duration.ofMillis(4000)
            ),  // Roosevelt Bridge
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.773052036400294, -73.94027981305442),
                Duration.ofMillis(3000)
            ),  // Roosevelt Lighthouse
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.78270548734745, -73.92189566092568),
                Duration.ofMillis(3000)
            ),  // Hell gate Bridge
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.78406704306872, -73.91746017917936),
                Duration.ofMillis(2000)
            ),  // Ralph Park
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.768075472169045, -73.97446921306035),
                Duration.ofMillis(2000)
            ),  // Wollman Rink
            GeoCoordinatesKeyframe(
                GeoCoordinates(40.78255966255712, -73.9586425508515),
                Duration.ofMillis(3000)
            ) // Solomon Museum
        )
    }

    private fun createScalarKeyframes(): List<ScalarKeyframe> {
        // The duration indicates the time it takes to reach the scalar (= camera distance in meters) of the keyframe.
        // Change the camera distance from 80000000 meters to 400 meters over time.
        return listOf(
            ScalarKeyframe(80000000.0, Duration.ofMillis(0)),
            ScalarKeyframe(8000000.0, Duration.ofMillis(2000)),
            ScalarKeyframe(8000.0, Duration.ofMillis(2000)),
            ScalarKeyframe(1000.0, Duration.ofMillis(2000)),
            ScalarKeyframe(400.0, Duration.ofMillis(3000))
        )
    }

    private fun createGeoOrientationKeyframes(): List<GeoOrientationKeyframe> {
        // The duration indicates the time it takes to achieve the GeoOrientation of the keyframe.
        return listOf(
            GeoOrientationKeyframe(GeoOrientation(30.0, 60.0), Duration.ofMillis(0)),
            GeoOrientationKeyframe(GeoOrientation(-40.0, 80.0), Duration.ofMillis(6000)),
            GeoOrientationKeyframe(GeoOrientation(30.0, 70.0), Duration.ofMillis(6000)),
            GeoOrientationKeyframe(GeoOrientation(70.0, 30.0), Duration.ofMillis(4000)),
            GeoOrientationKeyframe(GeoOrientation(-30.0, 70.0), Duration.ofMillis(5000)),
            GeoOrientationKeyframe(GeoOrientation(30.0, 70.0), Duration.ofMillis(5000)),
            GeoOrientationKeyframe(GeoOrientation(40.0, 70.0), Duration.ofMillis(5000)),
            GeoOrientationKeyframe(GeoOrientation(80.0, 40.0), Duration.ofMillis(5000)),
            GeoOrientationKeyframe(GeoOrientation(30.0, 70.0), Duration.ofMillis(5000))
        )
    }

    private fun logError(error: String) {
        Log.e(TAG, error)
    }

    companion object {
        private val TAG: String = CameraKeyframeTracksExample::class.java.getName()
    }
}