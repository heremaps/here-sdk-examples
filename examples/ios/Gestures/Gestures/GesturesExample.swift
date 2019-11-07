/*
 * Copyright (C) 2019 HERE Europe B.V.
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
import UIKit

class GesturesExample: TapDelegate, DoubleTapDelegate, LongPressDelegate {

    private var viewController: UIViewController
    private var mapView: MapViewLite

    init(viewController: UIViewController, mapView: MapViewLite) {
        self.viewController = viewController
        self.mapView = mapView

        mapView.camera.setTarget(GeoCoordinates(latitude: 52.530932, longitude: 13.384915))
        mapView.camera.setZoomLevel(14)

        mapView.gestures.tapDelegate = self
        mapView.gestures.doubleTapDelegate = self
        mapView.gestures.longPressDelegate = self

        // Disabling the default map gesture behavior for a double tap (zooms in).
        mapView.gestures.disableDefaultAction(forGesture: .doubleTap)

        showDialog(title: "Note", message: "Shows Tap, DoubleTap and LongPress gesture handling. "
            + "See log for details. DoubleTap map action (zoom in) is disabled as an example.")
    }

    // Conform to the TapDelegate protocol.
    func onTap(origin: Point2D) {
        let geoCoordinates = mapView.camera.viewToGeoCoordinates(viewCoordinates: origin)
        print("Tap at: \(String(describing: geoCoordinates))")
    }

    // Conform to the DoubleTapDelegate protocol.
    func onDoubleTap(origin: Point2D) {
        let geoCoordinates = mapView.camera.viewToGeoCoordinates(viewCoordinates: origin)
        print("Zooming in is disabled. DoubleTap at: \(String(describing: geoCoordinates))")
    }

    // Conform to the LongPressDelegate protocol.
    func onLongPress(state: GestureState, origin: Point2D) {
        if (state == .begin) {
            let geoCoordinates = mapView.camera.viewToGeoCoordinates(viewCoordinates: origin)
            print("LongPress detected at: \(String(describing: geoCoordinates))")
        }

        if (state == .update) {
            let geoCoordinates = mapView.camera.viewToGeoCoordinates(viewCoordinates: origin)
            print("LongPress update at: \(String(describing: geoCoordinates))")
        }

        if (state == .end) {
            let geoCoordinates = mapView.camera.viewToGeoCoordinates(viewCoordinates: origin)
            print("LongPress finger lifted at: \(String(describing: geoCoordinates))")
        }
    }

    // Unused - it's just an example how to clean up.
    private func removeGestureHandler(mapView: MapViewLite) {
        mapView.gestures.tapDelegate = nil
        mapView.gestures.doubleTapDelegate = nil
        mapView.gestures.longPressDelegate = nil

        // Enabling the default map gesture behavior for a double tap (zooms in).
        // It was disabled for this example, see above.
        mapView.gestures.enableDefaultAction(forGesture: .doubleTap)
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
