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

import SwiftUI
import heresdk

/// `RouteAnimationExample` is responsible for animating the camera along a predefined route on the HERE SDK map.
/// This class provides functions to start and stop route animations, moving the camera to display a route with transitions.
public class RouteAnimationExample {
 
    private var mapView: MapView!
    private var tracks: [MapCameraKeyframeTrack]!
    private var mapPolylines: [MapPolyline] = []
    private var routeCalculator: RouteCalculator
    private var route: Route?
    private let geoCoordinates = GeoCoordinates(latitude: 40.685869754854544, longitude: -74.02550202768754)
    
    init(_ mapView: MapView) {
        self.mapView = mapView
        
        routeCalculator = RouteCalculator(mapView: mapView)
        routeCalculator.createRoute()
    }
    
    func stopRouteAnimation() {
        mapView.camera.cancelAnimations()
    }
    
    func animateToRoute() {
        if (RouteCalculator.testRoute == nil) {
            print("RouteAnimationExample: Error: No route for testing ...")
            return
        }

        animateToRoute(route: RouteCalculator.testRoute!)
    }
    
    func animateToRoute(route: Route) {
        // Untilt and unrotate the map.
        let bearing: Double = 0
        let tilt: Double = 0
        
        // We want to show the route fitting in the map view with an additional padding of 50 pixels.
        let origin:Point2D = Point2D(x: 50.0, y: 50.0)
        let sizeInPixels:Size2D = Size2D(width: mapView.viewportSize.width - 100, height: mapView.viewportSize.height - 100)
        let mapViewport:Rectangle2D = Rectangle2D(origin: origin, size: sizeInPixels)

        // Animate to the route within a duration of 3 seconds.
        let update:MapCameraUpdate = MapCameraUpdateFactory.lookAt(area: route.boundingBox, orientation: GeoOrientationUpdate(GeoOrientation(bearing: bearing, tilt: tilt)), viewRectangle: mapViewport)
        let animation: MapCameraAnimation = MapCameraAnimationFactory.createAnimation(from: update, duration: TimeInterval(3), easing: Easing(EasingFunction.inCubic))
        mapView.camera.startAnimation(animation)
    }
}

