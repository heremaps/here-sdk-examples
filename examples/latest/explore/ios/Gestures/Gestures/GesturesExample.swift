/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

class GesturesExample: TapDelegate,
                       DoubleTapDelegate,
                       TwoFingerTapDelegate,
                       LongPressDelegate {

    private var viewController: UIViewController
    private var mapView: MapView

    private lazy var gestureMapAnimator = GestureMapAnimator(mapView.camera)

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView

        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      distanceInMeters: 1000 * 10)

        mapView.gestures.tapDelegate = self
        mapView.gestures.doubleTapDelegate = self
        mapView.gestures.twoFingerTapDelegate = self
        mapView.gestures.longPressDelegate = self

        // Disable the default map gesture behavior for DoubleTap (zooms in) and TwoFingerTap (zooms out)
        // as we want to enable custom map animations when such gestures are detected.
        mapView.gestures.disableDefaultAction(forGesture: .doubleTap)
        mapView.gestures.disableDefaultAction(forGesture: .twoFingerTap)

        showDialog(title: "Note", message: "Shows Tap and LongPress gesture handling. "
            + "See log for details. DoubleTap / TwoFingerTap map action (zoom in/out) is disabled and replaced with a custom animation.")
    }

    // Conform to the TapDelegate protocol.
    func onTap(origin: Point2D) {
        let geoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: origin)
        print("Tap at: \(String(describing: geoCoordinates))")
    }

    // Conform to the DoubleTapDelegate protocol.
    func onDoubleTap(origin: Point2D) {
        let geoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: origin)
        print("Default zooming in is disabled. DoubleTap at: \(String(describing: geoCoordinates))")

        // Start our custom zoom in animation.
        gestureMapAnimator.zoomIn(origin)
    }

    // Conform to the TwoFingerTapDelegate protocol.
    func onTwoFingerTap(origin: Point2D) {
        let geoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: origin)
        print("Default zooming in is disabled. TwoFingerTap at: \(String(describing: geoCoordinates))")

        // Start our custom zoom out animation.
        gestureMapAnimator.zoomOut(origin)
    }

    // Conform to the LongPressDelegate protocol.
    func onLongPress(state: GestureState, origin: Point2D) {
        if (state == .begin) {
            let geoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: origin)
            print("LongPress detected at: \(String(describing: geoCoordinates))")
        }

        if (state == .update) {
            let geoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: origin)
            print("LongPress update at: \(String(describing: geoCoordinates))")
        }

        if (state == .end) {
            let geoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: origin)
            print("LongPress finger lifted at: \(String(describing: geoCoordinates))")
        }
    }

    // Unused. This is just an example how to clean up.
    private func removeGestureHandler(mapView: MapView) {
        // Stop listening.
        mapView.gestures.tapDelegate = nil
        mapView.gestures.doubleTapDelegate = nil
        mapView.gestures.twoFingerTapDelegate = nil
        mapView.gestures.longPressDelegate = nil

        // Bring back the default map gesture behavior for DoubleTap (zooms in)
        // and TwoFingerTap (zooms out). These actions were disabled above.
        mapView.gestures.enableDefaultAction(forGesture: .doubleTap)
        mapView.gestures.enableDefaultAction(forGesture: .twoFingerTap)
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
