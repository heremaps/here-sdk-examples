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

import heresdk
import SwiftUI

/// A simple wrapper over a `MapView` that allows generating images
/// without adding a `MapView` to a view hierarchy.
///
/// The principle on which it operates is fairly simple.
/// The `generateImage` method takes a closure that can manipulate
/// the map and once the map achieves idle state (ie. the new state is fully rendered),
/// then it uses MapView's `takeScreenshot` method to generate
/// the final image and pass it to the caller through the provided
/// callback.
///
/// There is no queueing, only one operation can be done at any one time.
class OffscreenMapViewWrapper: MapIdleDelegate {
    private let mapView: MapView

    /// `true` if ready for generating a new map image, `false` otherwise.
    var isReady = false

    /// `true` if map is being updated/rendered.
    private var isBusy = false;

    /// The completion handler for the currently running image generation task.
    /// `nil` if there is no ongoing task.
    private var taskCompletionHandler: ((UIImage?) -> Void)?

    /// Initializes `OffscreenMapViewWrapper` to generate images of the map
    /// with specific dimensions and using specified `MapScheme`.
    ///
    /// - Parameter size: The size of generated image.
    /// - Parameter mapScheme: The map scheme to use for the map.
    /// - Parameter handler: Will be called after map scene is loaded.
    ///
    init(size: Size2D, mapScheme: MapScheme, completion handler: @escaping  () -> Void) {
        mapView = MapView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        mapView.layoutSubviews() // triggers internal map renderer initialization

        mapView.mapScene.loadScene(mapScheme: mapScheme) { error in
            // Initially, we do not care if idle state has been reached.
            // We can start generating new images immediately after scene is loaded.
            self.isReady = true
            handler()
        }
    }

    /// Generates a new image of the map. The caller must modify the state of the map inside
    /// the provided `mapTransformer` closure.
    ///
    /// - Parameter modifyMap: Modifies the underlying map to a desired state for the image to be captured.
    /// - Parameter handler: Will be called after image is generated.
    func generateImage(mapTransformer modifyMap: @escaping (MapViewBase) -> Void, completion handler: @escaping (UIImage?) -> Void) -> Bool {
        if isReady {
            taskCompletionHandler = handler
            isReady = false

            // Register as idle delegate to be notified once new map state is fully rendered.
            mapView.hereMap.addMapIdleDelegate(self)

            // Call user specified code on the map that modifies its state.
            // Warning: if there is no action performed on the map, resulting in
            // no change to the state, then this will block this `OffscreenMapViewWrapper`
            // indefinietely, with nothing happening and no new tasks being accepted.
            modifyMap(mapView)

            return true
        }
        return false
    }

    func onMapBusy() {
        isBusy = true
    }

    func onMapIdle() {
        if !isBusy {
            // Ignore idle notifications if not already busy.
            // When MapIdleDelegate is registered, it is immediately notified
            // of the current state, which can be either busy od idle (in this example app,
            // it will be idle). We need to make sure we only act on
            // idle notification that comes after a busy period (map being rendered).
            return
        }
        isBusy = false

        // Rendering is done, no need to be registered anymore.
        mapView.hereMap.removeMapIdleDelegate(self)

        if let completionHandler = taskCompletionHandler {
            // Take a screenshot and pass the result thtough the provided handler.
            mapView.takeScreenshot { image in
                completionHandler(image)
                self.taskCompletionHandler = nil

                // Everything is finished, mark as ready to take further tasks.
                self.isReady = true
            }
        }
    }
}
