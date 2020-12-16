/*
 * Copyright (C) 2019-2020 HERE Europe B.V.
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

import heresdk
import UIKit

// A simple class that takes care of smooth map "moveTo"-animations
// using Apple's CADisplayLink.
// Note: To interrup animations, optionally listen to map gestures like
// panning and stop an ongoing animation once detected.
class CameraAnimator {

    private let camera: MapCamera
    private var currentCamera: MapCamera.State!
    private var targetCamera: MapCamera.State!
    private var startTimeInSeconds: Double = 0
    private var previousTimeInSeconds: Double = 0

    // Use a fixed duration, no matter how far to move.
    private var animationDurationInSeconds: Double = 2

    private lazy var displayLink = CADisplayLink(target: self,
                                                 selector: #selector(animatorLoop))

    init(_ camera: MapCamera) {
        self.camera = camera
    }

    func moveTo(_ destination: GeoCoordinates, _ distanceToEarthInMeters: Double) {
        currentCamera = camera.state

        // Take the shorter bearing difference.
        let targetBearing: Double = camera.state.targetOrientation.bearing > 180 ? 360 : 0

        targetCamera = MapCamera.State(targetCoordinates: destination,
                                       targetOrientation: MapCamera.Orientation(bearing: targetBearing,
                                                                                tilt: 0),
                                       distanceToTargetInMeters: distanceToEarthInMeters,
                                       // Note: We do not use zoomLevel for this use case.
                                       zoomLevel: -1)

        // Start the run loop to execute animatorLoop() periodically.
        startTimeInSeconds = -1
        displayLink.isPaused = false
        displayLink.add(to: .current, forMode: .common)
    }

    @objc private func animatorLoop() {
        if startTimeInSeconds == -1 {
            // 1st frame, there's no previous frame.
            startTimeInSeconds = displayLink.timestamp
            previousTimeInSeconds = startTimeInSeconds
            return
        }

        let currentTimeInSeconds = displayLink.timestamp
        let elapsedTimeInSeconds = currentTimeInSeconds - startTimeInSeconds

        let frameDurationInSeconds = currentTimeInSeconds - previousTimeInSeconds
        let remainingFrames = (animationDurationInSeconds - elapsedTimeInSeconds) / frameDurationInSeconds

        // Calculate the new camera update.
        currentCamera = interpolate(currentCamera, targetCamera, remainingFrames)

        if elapsedTimeInSeconds >= animationDurationInSeconds {
            displayLink.isPaused = true
            updateCamera(cameraState: targetCamera)
            return
        }

        updateCamera(cameraState: currentCamera)
        previousTimeInSeconds = displayLink.timestamp
    }

    private func updateCamera(cameraState: MapCamera.State) {
        camera.lookAt(point: cameraState.targetCoordinates,
                      orientation: MapCamera.OrientationUpdate(bearing: cameraState.targetOrientation.bearing,
                                                               tilt: cameraState.targetOrientation.tilt),
                      distanceInMeters: cameraState.distanceToTargetInMeters)
    }

    private func interpolate(_ currentCamera: MapCamera.State,
                             _ targetCamera: MapCamera.State,
                             _ remainingFrames: Double) -> MapCamera.State {
        let newTilt = interpolateLinear(currentValue: currentCamera.targetOrientation.tilt,
                                        targetValue: targetCamera.targetOrientation.tilt,
                                        remainingFrames: remainingFrames)

        let newBearing = interpolateLinear(currentValue: currentCamera.targetOrientation.bearing,
                                           targetValue: targetCamera.targetOrientation.bearing,
                                           remainingFrames: remainingFrames)

        let newDistanceInMeters = interpolateLinear(currentValue: currentCamera.distanceToTargetInMeters,
                                                    targetValue: targetCamera.distanceToTargetInMeters,
                                                    remainingFrames: remainingFrames)

        let newTargetLatitude = interpolateLinear(currentValue: currentCamera.targetCoordinates.latitude,
                                                  targetValue: targetCamera.targetCoordinates.latitude,
                                                  remainingFrames: remainingFrames)

        let newTargetLongitude = interpolateLinear(currentValue: currentCamera.targetCoordinates.longitude,
                                                   targetValue: targetCamera.targetCoordinates.longitude,
                                                   remainingFrames: remainingFrames)

        return MapCamera.State(targetCoordinates: GeoCoordinates(latitude: newTargetLatitude,
                                                                 longitude: newTargetLongitude),
                               targetOrientation: MapCamera.Orientation(bearing: newBearing,
                                                                        tilt: newTilt),
                               distanceToTargetInMeters: newDistanceInMeters,
                               // Note: We do not use zoomLevel for this use case.
                               zoomLevel: -1)
    }

    private func interpolateLinear(currentValue: Double,
                                   targetValue: Double,
                                   remainingFrames: Double) -> Double {
        let delta = (currentValue - targetValue) / remainingFrames
        let newValue = currentValue - delta

        // Overflow check.
        if (currentValue < targetValue) {
            if newValue >= targetValue {
                return targetValue
            }
        } else {
            if newValue <= targetValue {
                return targetValue
            }
        }

        return newValue
    }
}
