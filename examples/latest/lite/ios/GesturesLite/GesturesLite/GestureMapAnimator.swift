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

// A simple class that takes care of smooth zoom gestures
// using Apple's CADisplayLink.
class GestureMapAnimator {

    private let camera: CameraLite
    private let startZoomVelocity: Double = 0.1
    private let zoomDelta: Double = 0.005
    private var zoomVelocity: Double
    private var isZoomIn: Bool = true

    // A run loop to zoom in/out the map continuously until zoomVelocity is zero.
    private lazy var displayLinkZoom = CADisplayLink(target: self,
                                                     selector: #selector(animatorLoopZoom))

    init(_ camera: CameraLite) {
        self.camera = camera
        zoomVelocity = startZoomVelocity
    }

    // Starts the zoom in animation.
    func zoomIn(_ mapView: MapViewLite, _ origin: Point2D) {
        // Change the anchor point to zoom in at the touched point.
        // Note that this affects all further programmatical map transformations.
        camera.targetAnchorPoint = getAnchorPoint(mapView, origin)

        isZoomIn = true
        startZoomAnimation()
    }

    // Starts the zoom out animation.
    func zoomOut() {
        // Make sure we use the map's center as target when zooming out (default).
        camera.targetAnchorPoint = Anchor2D(horizontal: 0.5, vertical: 0.5)

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
        var zoom = camera.getZoomLevel()
        zoom = isZoomIn ? zoom + zoomVelocity : zoom - zoomVelocity;
        camera.setZoomLevel(zoom)
        zoomVelocity = zoomVelocity - zoomDelta
        if (zoomVelocity <= 0) {
            stopAnimations()
        }
    }

    // Convert a pixel position on a map view to a transform center.
    private func getAnchorPoint(_ mapView: MapViewLite, _ origin: Point2D) -> Anchor2D {
        let scaleFactor = UIScreen.main.scale
        let mapViewWidthInPixels = Double(mapView.bounds.width * scaleFactor)
        let mapViewHeightInPixels = Double(mapView.bounds.height * scaleFactor)

        let normalizedX = (1.0 / mapViewWidthInPixels) * origin.x
        let normalizedY = (1.0 / mapViewHeightInPixels) * origin.y

        let transformCenter = Anchor2D(horizontal: normalizedX,
                                       vertical: normalizedY)
        return transformCenter
    }
}
