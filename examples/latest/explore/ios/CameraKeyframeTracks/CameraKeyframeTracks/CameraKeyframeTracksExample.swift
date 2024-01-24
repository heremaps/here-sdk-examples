/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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

public class CameraKeyframeTracksExample: AnimationDelegate {
    private final let tag = String(describing: CameraKeyframeTracksExample.self)
    
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
        let mapCameraKeyframeTracks: [MapCameraKeyframeTrack]? = createMapCameraKeyframeTracks()

        let mapCameraAnimation: MapCameraAnimation

        do {
            mapCameraAnimation = try MapCameraAnimationFactory.createAnimation(tracks: mapCameraKeyframeTracks!)
        } catch let mapCameraKeyframeTrackException {
            print(tag + "Error occured: " + mapCameraKeyframeTrackException.localizedDescription)
        return
        }
 
       // This animation can be started and replayed. When started, it will always start from the first keyframe.
       mapView.camera.startAnimation(mapCameraAnimation, animationDelegate: self)
    }

    public func onAnimationStateChanged(state: AnimationState) {
        switch (state) {
            case .started:
                    print(tag + "Animation started.")
                    break
            case .cancelled:
                    print(tag + "Animation cancelled.")
                    break
            case .completed:
                    print(tag + "Animation finished.")
                    break
            default:
                    print(tag + "An unknown error occured.")
                    break
        }
    }
    
    public func stopTripToNYCAnimation() {
        mapView.camera.cancelAnimations()
    }
    
    private func createMapCameraKeyframeTracks() -> [MapCameraKeyframeTrack] {
        let geoCoordinatesMapCameraKeyframeTrack: MapCameraKeyframeTrack
        let scalarMapCameraKeyframeTrack: MapCameraKeyframeTrack
        let geoOrientationMapCameraKeyframeTrack: MapCameraKeyframeTrack

        let geoCoordinatesKeyframes: [GeoCoordinatesKeyframe] = createGeoCoordinatesKeyframes()
        let scalarKeyframes: [ScalarKeyframe] = createScalarKeyframes()
        let geoOrientationKeyframes: [GeoOrientationKeyframe] = createGeoOrientationKeyframes()

        do {
            geoCoordinatesMapCameraKeyframeTrack = try MapCameraKeyframeTrack.lookAtTarget(keyframes: geoCoordinatesKeyframes, easing: Easing(EasingFunction.linear), interpolationMode: KeyframeInterpolationMode.linear)
            scalarMapCameraKeyframeTrack = try MapCameraKeyframeTrack.lookAtDistance(keyframes: scalarKeyframes, easing: Easing(EasingFunction.linear), interpolationMode: KeyframeInterpolationMode.linear)
            geoOrientationMapCameraKeyframeTrack = try MapCameraKeyframeTrack.lookAtOrientation(keyframes: geoOrientationKeyframes, easing: Easing(EasingFunction.linear), interpolationMode: KeyframeInterpolationMode.linear)
        } catch let mapCameraKeyframeTrackException {
        // Throws an error if keyframes are empty or the duration of keyframes is invalid.
            print(tag + mapCameraKeyframeTrackException.localizedDescription)
        return []
        }

        // Add different kinds of animation tracks that can be played back simultaneously.
        // Each track can have a different total duration.
        // The animation completes, when the longest track has been competed.
        var mapCameraKeyframeTracks: [MapCameraKeyframeTrack] = []

        // This changes the camera's location over time.
        mapCameraKeyframeTracks.append(geoCoordinatesMapCameraKeyframeTrack)
        // This changes the camera's distance (= scalar) to earth over time.
        mapCameraKeyframeTracks.append(scalarMapCameraKeyframeTrack)
        // This changes the camera's orientation over time.
        mapCameraKeyframeTracks.append(geoOrientationMapCameraKeyframeTrack)

        return mapCameraKeyframeTracks
    }
    
    func createGeoCoordinatesKeyframes() -> [GeoCoordinatesKeyframe] {
        var geoCoordinatesKeyframes:[GeoCoordinatesKeyframe] = []
        
        geoCoordinatesKeyframes.append(contentsOf: [
            
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.685869754854544, longitude: -74.02550202768754), duration: TimeInterval(0)), // Statue of Liberty
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.69051652745291, longitude: -74.04455943649657), duration: TimeInterval(5)), // Statue of Liberty
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.69051652745291, longitude: -74.04455943649657), duration: TimeInterval(7)), // Statue of Liberty
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.69051652745291, longitude: -74.04455943649657), duration: TimeInterval(9)), // Statue of Liberty
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.690266839135, longitude: -74.01237515471776), duration: TimeInterval(5)), // Governor Island
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.7116777285189, longitude: -74.01248494562448), duration: TimeInterval(6)), // World Trade Center
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.71083291395444, longitude: -74.01226399217569), duration: TimeInterval(6)), // World Trade Center
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.719259512385506, longitude: -74.01171007254635), duration: TimeInterval(5)), // Manhattan College
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.73603959180013, longitude: -73.98968489844603), duration: TimeInterval(6)), // Union Square
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.741732824650214, longitude: -73.98825255774022), duration: TimeInterval(5)), // Flatiron
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.74870637098952, longitude: -73.98515306630678), duration: TimeInterval(6)), // Empire State Building
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.742693509776856, longitude: -73.95937093336781), duration: TimeInterval(3)), // Queens Midtown
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.75065611103842, longitude: -73.96053139022635), duration: TimeInterval(4)), // Roosevelt Island
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.756823163883794, longitude: -73.95461519921352), duration: TimeInterval(4)), // Queens Bridge
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.763573707276784, longitude: -73.94571562970638), duration: TimeInterval(4)), // Roosevelt Bridge
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.773052036400294, longitude: -73.94027981305442), duration: TimeInterval(3)), // Roosevelt Lighthouse
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.78270548734745, longitude: -73.92189566092568), duration: TimeInterval(3)), // Hell gate Bridge
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.78406704306872, longitude: -73.91746017917936), duration: TimeInterval(2)), // Ralph Park
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.768075472169045, longitude: -73.97446921306035), duration: TimeInterval(2)), // Wollman Rink
            GeoCoordinatesKeyframe(value: GeoCoordinates(latitude: 40.78255966255712, longitude: -73.9586425508515), duration: TimeInterval(3)) // Solomon Museum
        ])
        
        return geoCoordinatesKeyframes
    }
    
    func createScalarKeyframes() -> [ScalarKeyframe] {
        var scalarKeyframes: [ScalarKeyframe] = []
        
        scalarKeyframes.append(ScalarKeyframe(value: 80000000.0, duration: TimeInterval(0)))
        scalarKeyframes.append(ScalarKeyframe(value: 8000000.0, duration: TimeInterval(2)))
        scalarKeyframes.append(ScalarKeyframe(value: 8000.0, duration: TimeInterval(2)))
        scalarKeyframes.append(ScalarKeyframe(value: 1000.0, duration: TimeInterval(2)))
        scalarKeyframes.append(ScalarKeyframe(value: 400.0, duration: TimeInterval(3)))
        
        return scalarKeyframes
    }
    
    func createGeoOrientationKeyframes() -> [GeoOrientationKeyframe] {
        var geoOrientationKeyframe: [GeoOrientationKeyframe] = []
        
        geoOrientationKeyframe.append(contentsOf: [
            GeoOrientationKeyframe(value: GeoOrientation(bearing: 30, tilt: 60), duration: TimeInterval(0)),
            GeoOrientationKeyframe(value: GeoOrientation(bearing: -40, tilt: 80), duration: TimeInterval(6)),
            GeoOrientationKeyframe(value: GeoOrientation(bearing: 30, tilt: 70), duration: TimeInterval(6)),
            GeoOrientationKeyframe(value: GeoOrientation(bearing: 70, tilt: 30), duration: TimeInterval(4)),
            GeoOrientationKeyframe(value: GeoOrientation(bearing: -30, tilt: 70), duration: TimeInterval(5)),
            GeoOrientationKeyframe(value: GeoOrientation(bearing: 30, tilt: 70), duration: TimeInterval(5)),
            GeoOrientationKeyframe(value: GeoOrientation(bearing: 40, tilt: 70), duration: TimeInterval(5)),
            GeoOrientationKeyframe(value: GeoOrientation(bearing: 80, tilt: 40), duration: TimeInterval(5)),
            GeoOrientationKeyframe(value: GeoOrientation(bearing: 30, tilt: 70), duration: TimeInterval(5))
        ])
        
        return geoOrientationKeyframe
    }
    
    func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
