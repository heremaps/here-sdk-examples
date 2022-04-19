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

public class RouteAnimationExample {
    
    private let viewController: UIViewController
    private var mapView: MapView!
    private var tracks: [MapCameraKeyframeTrack]!
    private var mapPolylines: [MapPolyline] = []
    private var routeCalculator: RouteCalculator
    private var route: Route?
    private let geoCoordinates = GeoCoordinates(latitude: 40.685869754854544, longitude: -74.02550202768754)
    
    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
        
        routeCalculator = RouteCalculator(viewController: viewController)
        calculateRoute()
    }
    
    // Provide hard-coded route for testing.
    public func calculateRoute() {
        routeCalculator.calculateRoute() { (routingError, routes) in
            if let error = routingError {
                self.showDialog(title: "Error while calculating a route:", message: "\(error)")
                return
            }
            
            // When routingError is nil, routes is guaranteed to contain at least one route.
            self.route = routes?.first
            self.showRouteOnMap(route: self.route!)
        }
    }
    
    public func getRoute() -> Route? {
        return route
    }
    
    private func showRouteOnMap(route: Route) {
        // Show route as polyline.
        let routeGeoPolyline = route.geometry
        let routeMapPolyline = MapPolyline(geometry: routeGeoPolyline,
                                           widthInPixels: 20,
                                           color: UIColor(red: 0,
                                                          green: 0.56,
                                                          blue: 0.54,
                                                          alpha: 0.63))
        mapView.mapScene.addMapPolyline(routeMapPolyline)
        mapPolylines.append(routeMapPolyline)
    }
    
    func clearRoute() {
        mapPolylines.forEach { mapPolyline in
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylines.removeAll()
    }
    
    func createLocationsForRouteAnimation(route: Route) -> [LocationKeyframeModel] {
        var locationList: [LocationKeyframeModel] = []
        let geoCoordinatesList: [GeoCoordinates] = route.geometry.vertices
        
        locationList.append(LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.71335297425111, longitude: -74.01128262379694), duration: TimeInterval(0)))
        locationList.append(LocationKeyframeModel(geoCoordinates: route.boundingBox.southWestCorner, duration: TimeInterval(0.5)))
        
        geoCoordinatesList.forEach { geoCoordinates in
            locationList.append(LocationKeyframeModel(geoCoordinates: geoCoordinates, duration: TimeInterval(0.5)))
        }
        
        locationList.append(LocationKeyframeModel(geoCoordinates: GeoCoordinates(latitude: 40.72040734322057, longitude: -74.01225894785958), duration: TimeInterval(2)))
        
        return locationList
    }
    
    func createOrientationForRouteAnimation() -> [OrientationKeyframeModel] {
        var orientationList: [OrientationKeyframeModel] = []
        orientationList.append(OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: 30, tilt: 60), duration: TimeInterval(0)))
        orientationList.append(OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: -40, tilt: 70), duration: TimeInterval(2)))
        orientationList.append(OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: -10, tilt: 70), duration: TimeInterval(1)))
        orientationList.append(OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: 10, tilt: 70), duration: TimeInterval(4)))
        orientationList.append(OrientationKeyframeModel(geoOrientation: GeoOrientation(bearing: 10, tilt: 70), duration: TimeInterval(4)))
        
        return orientationList
    }
    
    func createScalarForRouteAnimation() -> [ScalarKeyframeModel] {
        var scalarList: [ScalarKeyframeModel] = []
        scalarList.append(ScalarKeyframeModel(scalar: 80000000.0, duration: TimeInterval(0)))
        scalarList.append(ScalarKeyframeModel(scalar: 8000000.0, duration: TimeInterval(1)))
        scalarList.append(ScalarKeyframeModel(scalar: 500.0, duration: TimeInterval(2)))
        scalarList.append(ScalarKeyframeModel(scalar: 500.0, duration: TimeInterval(4)))
        scalarList.append(ScalarKeyframeModel(scalar: 100.0, duration: TimeInterval(3)))
        
        return scalarList
    }
    
    public func animateRoute(route: Route) {
        // A list of location key frames for moving the map camera from one geo coordinate to another.
        var locationKeyframesList: [GeoCoordinatesKeyframe] = []
        let locationList: [LocationKeyframeModel] = createLocationsForRouteAnimation(route: route)
        
        locationList.forEach { locationKeyframeModel in
            locationKeyframesList.append(GeoCoordinatesKeyframe(value: locationKeyframeModel.geoCoordinates , duration: locationKeyframeModel.duration))
        }
                
        // A list of geo orientation keyframes for changing the map camera orientation.
        var orientationKeyframeList: [GeoOrientationKeyframe] = []
        let orientationList: [OrientationKeyframeModel] = createOrientationForRouteAnimation()
        
        orientationList.forEach { orientationKeyframeModel in
            orientationKeyframeList.append(GeoOrientationKeyframe(value: orientationKeyframeModel.geoOrientation, duration: orientationKeyframeModel.duration))
        }
        
        // A list of scalar key frames for changing the map camera distance from the earth.
        var scalarKeyframesList: [ScalarKeyframe] = []
        let scalarList: [ScalarKeyframeModel] = createScalarForRouteAnimation()
        
        scalarList.forEach { scalarKeyframeModel in
            scalarKeyframesList.append(ScalarKeyframe(value: scalarKeyframeModel.scalar, duration: scalarKeyframeModel.duration))
        }
        
        // Creating a track to add different kinds of animations to the MapCameraKeyframeTrack.
        var tracks: [MapCameraKeyframeTrack] = []
        do {
            try tracks.append(MapCameraKeyframeTrack.lookAtDistance(keyframes: scalarKeyframesList, easingFunction: EasingFunction.linear, interpolationMode: KeyframeInterpolationMode.linear))
            try tracks.append(MapCameraKeyframeTrack.lookAtTarget(keyframes: locationKeyframesList, easingFunction: EasingFunction.linear, interpolationMode: KeyframeInterpolationMode.linear))
            try tracks.append(MapCameraKeyframeTrack.lookAtOrientation(keyframes: orientationKeyframeList, easingFunction: EasingFunction.linear, interpolationMode: KeyframeInterpolationMode.linear))
            
            // All animation tracks being played here.
            startRouteAnimation(tracks: tracks)
        } catch let mapCameraKeyframeTrackException {
            print("KeyframeTrackTag: \(mapCameraKeyframeTrackException.localizedDescription)")
        }
    }
    
    func startRouteAnimation(tracks: [MapCameraKeyframeTrack]) {
        do {
            try mapView.camera.startAnimation(MapCameraAnimationFactory.createAnimation(tracks: tracks))
        } catch let mapCameraKeyframeTrackException {
            print("KeyframeTrackTag: \(mapCameraKeyframeTrackException.localizedDescription)")
        }
    }
    
    func stopRouteAnimation() {
        mapView.camera.cancelAnimations()
    }
    
    func animateToRoute(route: Route) {
        let update: MapCameraUpdate = MapCameraUpdateFactory.lookAt(area: route.boundingBox)
        let animation: MapCameraAnimation = MapCameraAnimationFactory.createAnimation(from: update, duration: TimeInterval(3), easingFunction: EasingFunction.inCubic)
        mapView.camera.startAnimation(animation)
    }
    
    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
