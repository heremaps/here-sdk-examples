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

// This example shows how to use the Camera class to rotate and tilt the map programmatically, to set
// a new transform center that influences those operations, and to move to a new location using
// Apple's CADisplayLink to animate the map smoothly.
// For more features of the Camera class, please consult the API Reference and the Developer's Guide.
class CameraExample: TapDelegate, MapCameraObserver {

    private let defaultDistanceToEarthInMeters: Double = 8000
    private let viewController: UIViewController
    private let mapView: MapView
    private let camera: MapCamera
    private var cameraTargetView: UIImageView
    private var poiMapCircle: MapPolygon!

    private lazy var cameraAnimator = CameraAnimator(mapView.camera)

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView

        camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.750731,longitude: 13.007375),
                      distanceInMeters: defaultDistanceToEarthInMeters)

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
        cameraAnimator.moveTo(geoCoordinates, defaultDistanceToEarthInMeters)
    }

    // Rotate the map by x degrees. Tip: Try to see what happens for negative values.
    private func rotateMap(bearingStepInDegrees: Double) {
        let currentBearing = camera.state.targetOrientation.bearing
        let newBearing = currentBearing + bearingStepInDegrees

        //By default, bearing will be clamped to the range (0, 360].
        let orientationUpdate = MapCamera.OrientationUpdate(bearing: newBearing,
                                                            tilt: nil)
        camera.setTargetOrientation(orientation: orientationUpdate)
    }

    // Tilt the map by x degrees.
    private func tiltMap(tiltStepInDegrees: Double) {
        let currentTilt = camera.state.targetOrientation.tilt
        let newTilt = currentTilt + tiltStepInDegrees

        //By default, tilt will be clamped to the range [0, 70].
        let orientationUpdate = MapCamera.OrientationUpdate(bearing: nil,
                                                            tilt: newTilt)
        camera.setTargetOrientation(orientation: orientationUpdate)
    }

    // Conform to the TapDelegate protocol.
    func onTap(origin: Point2D) {
        setTransformCenter(mapViewTouchPointInPixels: origin)
    }

    // Conform to the MapCameraObserver protocol.
    func onCameraUpdated(_ cameraState: heresdk.MapCamera.State) {
        print("New camera target \(cameraState.targetCoordinates.latitude), \(cameraState.targetCoordinates.longitude)")
    }

    // The new transform center will be used for all programmatical map transformations
    // and determines where the target is located in the view.
    // By default, the target point is located at the center of the view.
    // Note: Gestures are not affected, for example, the pinch-rotate gesture and
    // the two-finger-pan (=> tilt) will work like before.
    private func setTransformCenter(mapViewTouchPointInPixels: Point2D) {
        // Note that this moves the current camera's target at the locatiion where you tapped the screen.
        // Effectively, you move the map by changing the camera's target.
        camera.principalPoint = mapViewTouchPointInPixels

        // Reposition circle view on screen to indicate the new target.
        let scaleFactor = UIScreen.main.scale
        cameraTargetView.center = CGPoint(x: mapViewTouchPointInPixels.x / Double(scaleFactor),
                                          y: mapViewTouchPointInPixels.y / Double(scaleFactor))

        print("New transform center: \(mapViewTouchPointInPixels.x), \(mapViewTouchPointInPixels.y)")
    }

    private func updatePoiCircle(_ geoCoordinates: GeoCoordinates) {
        if poiMapCircle != nil {
            mapView.mapScene.removeMapPolygon(poiMapCircle)
        }
        poiMapCircle = createMapCircle(geoCoordinates: geoCoordinates)
        mapView.mapScene.addMapPolygon(poiMapCircle)
    }

    private func createMapCircle(geoCoordinates: GeoCoordinates) -> MapPolygon {
        let geoCircle = GeoCircle(center: geoCoordinates,
                                  radiusInMeters: 300.0)
        let geoPolygon = GeoPolygon(geoCircle: geoCircle)
        let fillColor = UIColor(red: 0, green: 1, blue: 0, alpha: 1)
        let mapPolygon = MapPolygon(geometry: geoPolygon, color: fillColor)
        return mapPolygon
    }

    private func getRandomGeoCoordinates() -> GeoCoordinates {
        let currentTarget = camera.state.targetCoordinates
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
