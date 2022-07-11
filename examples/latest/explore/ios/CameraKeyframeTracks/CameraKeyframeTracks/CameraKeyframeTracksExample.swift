/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

import UIKit
import heresdk

public class CameraKeyframeTracksExample {
    private let viewController: UIViewController
    private var mapView: MapView!
    private var tracks: [MapCameraKeyframeTrack]!
    private let geoCoordinates = GeoCoordinates(latitude: 40.685869754854544, longitude: -74.02550202768754)
    
    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
    }
    
    public func startTripToNYC() {
        // This animation can be started and replayed. When started, it will always start from globe view.
        let tracks: [MapCameraKeyframeTrack] = createTripToNYCAnimation()
        startTripToNYCAnimation(tracks: tracks)
    }
    
    public func stopTripToNYCAnimation() {
        mapView.camera.cancelAnimations()
    }
    
    func createLocationsForTripToNYC() -> [LocationKeyframeModel] {
        var locationList:[LocationKeyframeModel] = []
        
        locationList.append(contentsOf: [
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.685869754854544, longitude: -74.02550202768754), duration: TimeInterval(0)), // Statue of Liberty
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.69051652745291, longitude: -74.04455943649657), duration: TimeInterval(5)), // Statue of Liberty
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.69051652745291, longitude: -74.04455943649657), duration: TimeInterval(7)), // Statue of Liberty
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.69051652745291, longitude: -74.04455943649657), duration: TimeInterval(9)), // Statue of Liberty
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.690266839135, longitude: -74.01237515471776), duration: TimeInterval(5)), // Governor Island
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.7116777285189, longitude: -74.01248494562448), duration: TimeInterval(6)), // World Trade Center
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.71083291395444, longitude: -74.01226399217569), duration: TimeInterval(6)), // World Trade Center
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.719259512385506, longitude: -74.01171007254635), duration: TimeInterval(5)), // Manhattan College
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.73603959180013, longitude: -73.98968489844603), duration: TimeInterval(6)), // Union Square
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.741732824650214, longitude: -73.98825255774022), duration: TimeInterval(5)), // Flatiron
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.74870637098952, longitude: -73.98515306630678), duration: TimeInterval(6)), // Empire State Building
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.742693509776856, longitude: -73.95937093336781), duration: TimeInterval(3)), // Queens Midtown
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.75065611103842, longitude: -73.96053139022635), duration: TimeInterval(4)), // Roosevelt Island
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.756823163883794, longitude: -73.95461519921352), duration: TimeInterval(4)), // Queens Bridge
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.763573707276784, longitude: -73.94571562970638), duration: TimeInterval(4)), // Roosevelt Bridge
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.773052036400294, longitude: -73.94027981305442), duration: TimeInterval(3)), // Roosevelt Lighthouse
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.78270548734745, longitude: -73.92189566092568), duration: TimeInterval(3)), // Hell gate Bridge
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.78406704306872, longitude: -73.91746017917936), duration: TimeInterval(2)), // Ralph Park
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.768075472169045, longitude: -73.97446921306035), duration: TimeInterval(2)), // Wollman Rink
            LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.78255966255712, longitude: -73.9586425508515), duration: TimeInterval(3)) // Solomon Museum
        ])
        
        return locationList
    }
    
    func createOrientationsForTripToNYC() -> [OrientationKeyframeModel] {
        var orientationList: [OrientationKeyframeModel] = []
        
        orientationList.append(contentsOf: [
            OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: 30, tilt: 60), duration: TimeInterval(0)),
            OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: -40, tilt: 80), duration: TimeInterval(6)),
            OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: 30, tilt: 70), duration: TimeInterval(6)),
            OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: 70, tilt: 30), duration: TimeInterval(4)),
            OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: -30, tilt: 70), duration: TimeInterval(5)),
            OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: 30, tilt: 70), duration: TimeInterval(5)),
            OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: 40, tilt: 70), duration: TimeInterval(5)),
            OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: 80, tilt: 40), duration: TimeInterval(5)),
            OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: 30, tilt: 70), duration: TimeInterval(5))
        ])
        
        return orientationList
    }
    
    func createScalarsForTripToNYC() -> [ScalarKeyframeModel] {
        var scalarList: [ScalarKeyframeModel] = []
        
        scalarList.append(ScalarKeyframeModel(scalar: 80000000.0, duration: TimeInterval(0)))
        scalarList.append(ScalarKeyframeModel(scalar: 8000000.0, duration: TimeInterval(2)))
        scalarList.append(ScalarKeyframeModel(scalar: 8000.0, duration: TimeInterval(2)))
        scalarList.append(ScalarKeyframeModel(scalar: 1000.0, duration: TimeInterval(2)))
        scalarList.append(ScalarKeyframeModel(scalar: 400.0, duration: TimeInterval(3)))
        
        return scalarList
    }
    
    func createTripToNYCAnimation() -> [MapCameraKeyframeTrack] {
        // A list of location key frames for moving the map camera from one geo coordinate to another.
        var locationKeyframesList: [GeoCoordinatesKeyframe] = []
        let locationList: [LocationKeyframeModel] = createLocationsForTripToNYC()
        
        locationList.forEach { locationKeyframeModel in
            print(locationKeyframeModel.geoCoordinates)
            locationKeyframesList.append(GeoCoordinatesKeyframe(value: locationKeyframeModel.geoCoordinates , duration: locationKeyframeModel.duration))
        }
        
        // A list of geo orientation keyframes for changing the map camera orientation.
        var orientationKeyframeList: [GeoOrientationKeyframe] = []
        let orientationList: [OrientationKeyframeModel] = createOrientationsForTripToNYC()
        
        orientationList.forEach { orientationKeyframeModel in
            orientationKeyframeList.append(GeoOrientationKeyframe(value: orientationKeyframeModel.geoOrientation , duration: orientationKeyframeModel.duration))
        }
        
        // A list of scalar key frames for changing the map camera distance from the earth.
        var scalarKeyframesList: [ScalarKeyframe] = []
        let scalarList: [ScalarKeyframeModel] = createScalarsForTripToNYC()
        
        scalarList.forEach { scalarKeyframeModel in
            scalarKeyframesList.append(ScalarKeyframe(value: scalarKeyframeModel.scalar, duration: scalarKeyframeModel.duration))
        }
        
        // Creating a track to add different kinds of animations to the MapCameraKeyframeTrack.
        tracks = []
        do {
            try tracks.append(MapCameraKeyframeTrack.lookAtDistance(keyframes: scalarKeyframesList, easingFunction: EasingFunction.linear, interpolationMode: KeyframeInterpolationMode.linear))
            try tracks.append(MapCameraKeyframeTrack.lookAtTarget(keyframes: locationKeyframesList, easingFunction: EasingFunction.linear, interpolationMode: KeyframeInterpolationMode.linear))
            try tracks.append(MapCameraKeyframeTrack.lookAtOrientation(keyframes: orientationKeyframeList, easingFunction: EasingFunction.linear, interpolationMode: KeyframeInterpolationMode.linear))
        } catch let mapCameraKeyframeTrackException {
            print("KeyframeTrackTag: \(mapCameraKeyframeTrackException.localizedDescription)")
        }
        
        return tracks
    }
    
    func startTripToNYCAnimation(tracks: [MapCameraKeyframeTrack]) {
        do {
            try mapView.camera.startAnimation(MapCameraAnimationFactory.createAnimation(tracks: tracks))
        } catch let mapCameraKeyframeTrackException {
            print("KeyframeTrackTag: \(mapCameraKeyframeTrackException.localizedDescription)")
        }
    }
    
    func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
