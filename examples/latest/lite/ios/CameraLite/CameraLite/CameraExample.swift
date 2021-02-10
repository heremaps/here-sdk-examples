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

//
// This example shows how to use the Camera class to rotate and tilt the map programmatically, to set
// a new transform center that influences those operations, and to move to a new location using
// Apple's CADisplayLink to animate the map smoothly.
// For more features of the Camera class, please consult the API Reference and the Developer's Guide.
//
class CameraExample: TapDelegate, CameraObserverLite {

    private let defaultZoomLevel: Double = 14
    private let viewController: UIViewController
    private let mapView: MapViewLite
    private let camera: CameraLite
    private var cameraTargetView: UIImageView
    private var poiMapCircle: MapCircleLite!

    private lazy var cameraAnimator = CameraAnimator(mapView.camera)

    init(viewController: UIViewController, mapView: MapViewLite) {
        self.viewController = viewController
        self.mapView = mapView
        camera = mapView.camera
        camera.setTarget(GeoCoordinates(latitude: 52.750731,longitude: 13.007375))
        camera.setZoomLevel(defaultZoomLevel)

        // The red circle dot indicates the camera's current target location.
        // By default, the dot is centered on the map view.
        // Same as the camera, which is also centered above the map view.
        // Later on, we will adjust the dot's location on screen programmatically when the camera's target changes.
        cameraTargetView = UIImageView(image: UIImage(named: "red_dot.png"))
        cameraTargetView.center = CGPoint(x: mapView.frame.size.width  / 2,
                                          y: mapView.frame.size.height / 2)
        mapView.addSubview(cameraTargetView)

        // The POI MapCircle (green) indicates the next location to move to.
        updatePoiCircle(getRandomGeoCoordinates())

        mapView.gestures.tapDelegate = self
        mapView.camera.addObserver(self)

        showDialog(title: "Note", message: "Tap the map to set a new transform center.")
    }

    func onRotateButtonClicked() {
        rotateMap(bearingStepInDegrees: 10)
    }

    func onTiltButtonClicked() {
        tiltMap(tiltStepInDegrees: 5)
    }

    func onMoveToXYButtonClicked() {
        let geoCoordinates = getRandomGeoCoordinates()
        updatePoiCircle(geoCoordinates)
        cameraAnimator.moveTo(geoCoordinates, defaultZoomLevel)
    }

    // Rotate the map by x degrees. Tip: Try to see what happens for negative values.
    private func rotateMap(bearingStepInDegrees: Double) {
        let currentBearing = camera.getBearing()
        let newBearing = currentBearing + bearingStepInDegrees

        //By default, bearing will be clamped to the range (0, 360].
        camera.setBearing(degreesClockwiseFromNorth: newBearing)
    }

    // Tilt the map by x degrees.
    private func tiltMap(tiltStepInDegrees: Double) {
        let currentTilt = camera.getTilt()
        let newTilt = currentTilt + tiltStepInDegrees

        //By default, tilt will be clamped to the range [0, 70].
        camera.setTilt(degreesFromNadir: newTilt)
    }

    // Conform to the TapDelegate protocol.
    func onTap(origin: Point2D) {
        setTransformCenter(mapViewTouchPointInPixels: origin)
    }

    // Conform to the CameraObserverLite protocol.
    func onCameraUpdated(_ cameraUpdate: CameraUpdateLite) {
        print("New camera target \(cameraUpdate.target.latitude), \(cameraUpdate.target.longitude)")
    }

    // The new transform center will be used for all programmatical map transformations (like rotate and tilt)
    // and determines where the target is located in the view.
    // By default, the anchor point is located at x = 0.5, y = 0.5.
    // Note: Gestures are not affected, for example, the pinch-rotate gesture and
    // the two-finger-pan (=> tilt) will work like before.
    private func setTransformCenter(mapViewTouchPointInPixels: Point2D) {
        let scaleFactor = UIScreen.main.scale
        let mapViewWidthInPixels = Double(mapView.bounds.width * scaleFactor)
        let mapViewHeightInPixels = Double(mapView.bounds.height * scaleFactor)

        let normalizedX = (1.0 / mapViewWidthInPixels) * mapViewTouchPointInPixels.x
        let normalizedY = (1.0 / mapViewHeightInPixels) * mapViewTouchPointInPixels.y

        let transformationCenter = Anchor2D(horizontal: normalizedX,
                                            vertical: normalizedY)
        camera.targetAnchorPoint = transformationCenter

        // Reposition view on screen to indicate the new target.
        cameraTargetView.center = CGPoint(x: mapViewTouchPointInPixels.x / Double(scaleFactor),
                                          y: mapViewTouchPointInPixels.y / Double(scaleFactor))

        print("New transform center: \(transformationCenter.horizontal), \(transformationCenter.vertical)")
    }

    private func updatePoiCircle(_ geoCoordinates: GeoCoordinates) {
        if poiMapCircle != nil {
            mapView.mapScene.removeMapCircle(poiMapCircle)
        }
        poiMapCircle = createMapCircle(geoCoordinates: geoCoordinates,
                                       color: 0x00FF00A0,
                                       radiusInMeters: 80,
                                       drawOrder: 1000)
        mapView.mapScene.addMapCircle(poiMapCircle)
    }

    private func createMapCircle(geoCoordinates: GeoCoordinates,
                                 color: UInt32,
                                 radiusInMeters: Double,
                                 drawOrder: UInt32) -> MapCircleLite {
        let geoCircle = GeoCircle(center: geoCoordinates, radiusInMeters: radiusInMeters)
        let mapCircleStyle = MapCircleStyleLite()
        mapCircleStyle.setFillColor(color, encoding: PixelFormatLite.rgba8888)
        mapCircleStyle.setDrawOrder(drawOrder)
        return MapCircleLite(geometry: geoCircle, style: mapCircleStyle)
    }

    private func getRandomGeoCoordinates() -> GeoCoordinates {
        let currentTarget = camera.getTarget()
        let amount = 0.05
        let latitude = getRandom(min: currentTarget.latitude - amount,
                                 max: currentTarget.latitude + amount)
        let longitude = getRandom(min: currentTarget.longitude - amount,
                                  max: currentTarget.longitude + amount)
        return GeoCoordinates(latitude: latitude, longitude: longitude)
    }

    private func getRandom(min: Double, max: Double) -> Double {
        return Double.random(in: min ... max)
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
