/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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
class CameraAnimator {

    private let camera: CameraLite
    private var currentCamera: CameraUpdateLite!
    private var targetCamera: CameraUpdateLite!
    private var startTimeInSeconds: Double = 0
    private var previousTimeInSeconds: Double = 0
    private var animationDurationInSeconds: Double = 2

    private lazy var displayLink = CADisplayLink(target: self,
                                                 selector: #selector(animatorLoop))

    init(_ camera: CameraLite) {
        self.camera = camera
    }

    func setDurationInSeconds(animationDurationInSeconds: Double) {
        self.animationDurationInSeconds = animationDurationInSeconds
    }

    func moveTo(_ destination: GeoCoordinates, _ targetZoom: Double) {
        currentCamera = CameraUpdateLite(tilt: camera.getTilt(),
                                         bearing: camera.getBearing(),
                                         zoomLevel: camera.getZoomLevel(),
                                         target: camera.getTarget())

        // Take the shorter bearing difference.
        let targetBearing: Double = camera.getBearing() > 180 ? 360 : 0

        targetCamera = CameraUpdateLite(tilt: 0,
                                        bearing: targetBearing,
                                        zoomLevel: targetZoom,
                                        target: destination)

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
            camera.updateCamera(cameraUpdate: targetCamera)
            return
        }

        camera.updateCamera(cameraUpdate: currentCamera)
        previousTimeInSeconds = displayLink.timestamp
    }

    private func interpolate(_ currentCamera: CameraUpdateLite,
                             _ targetCamera: CameraUpdateLite,
                             _ remainingFrames: Double) -> CameraUpdateLite {
        let newTilt = interpolateLinear(currentValue: currentCamera.tilt,
                                        targetValue: targetCamera.tilt,
                                        remainingFrames: remainingFrames)

        let newBearing = interpolateLinear(currentValue: currentCamera.bearing,
                                           targetValue: targetCamera.bearing,
                                           remainingFrames: remainingFrames)

        let newZoomLevel = interpolateLinear(currentValue: currentCamera.zoomLevel,
                                             targetValue: targetCamera.zoomLevel,
                                             remainingFrames: remainingFrames)

        let newTargetLatitude = interpolateLinear(currentValue: currentCamera.target.latitude,
                                                  targetValue: targetCamera.target.latitude,
                                                  remainingFrames: remainingFrames)

        let newTargetLongitude = interpolateLinear(currentValue: currentCamera.target.longitude,
                                                   targetValue: targetCamera.target.longitude,
                                                   remainingFrames: remainingFrames)

        return CameraUpdateLite(tilt: newTilt,
                                bearing: newBearing,
                                zoomLevel: newZoomLevel,
                                target: GeoCoordinates(latitude: newTargetLatitude,
                                                       longitude: newTargetLongitude))
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
