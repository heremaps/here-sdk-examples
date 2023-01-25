/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

// A simple class that takes care of smooth zoom gestures
// using Apple's CADisplayLink.
class GestureMapAnimator {

    private let camera: MapCamera
    private let startZoomVelocity: Double = 0.1
    private let zoomDelta: Double = 0.005
    private var zoomVelocity: Double
    private var isZoomIn: Bool = true
    private var zoomOrigin = Point2D(x: 0, y: 0)

    // A run loop to zoom in/out the map continuously until zoomVelocity is zero.
    private lazy var displayLinkZoom = CADisplayLink(target: self,
                                                     selector: #selector(animatorLoopZoom))

    init(_ camera: MapCamera) {
        self.camera = camera
        zoomVelocity = startZoomVelocity
    }

    // Starts the zoom in animation.
    func zoomIn(_ origin: Point2D) {
        zoomOrigin = origin
        isZoomIn = true
        startZoomAnimation()
    }

    // Starts the zoom out animation.
    func zoomOut(_ origin: Point2D) {
        zoomOrigin = origin
        isZoomIn = false
        startZoomAnimation()
    }

    private func startZoomAnimation() {
        stopAnimations()

        zoomVelocity = startZoomVelocity
        displayLinkZoom.isPaused = false
        displayLinkZoom.add(to: .current, forMode: .common)
    }

    // Stop any ongoing zoom animation.
    func stopAnimations() {
        displayLinkZoom.isPaused = true
    }

    // Called periodically until zoomVelocity is zero.
    @objc private func animatorLoopZoom() {
        var zoomFactor: Double = 1
        zoomFactor = isZoomIn ? zoomFactor + zoomVelocity : zoomFactor - zoomVelocity;
        // zoomFactor values > 1 will zoom in and values < 1 will zoom out.
        camera.zoomBy(zoomFactor, around: zoomOrigin)
        zoomVelocity = zoomVelocity - zoomDelta
        if (zoomVelocity <= 0) {
            stopAnimations()
        }
    }
}
