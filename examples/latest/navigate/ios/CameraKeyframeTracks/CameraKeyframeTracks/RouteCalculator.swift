/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

// A class that creates car Routes with the HERE SDK.
public class RouteCalculator {
    
    private let mapView: MapView
    private let routingEngine: RoutingEngine
    public static var testRoute: Route?
    
    init(mapView: MapView) {
        self.mapView = mapView
        
        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }
    }
    
    public func createRoute() {
        // A fixed test route.
        let start: Waypoint = Waypoint(coordinates: GeoCoordinates(latitude: 40.7133, longitude: -74.0112))
        let destination: Waypoint = Waypoint(coordinates: GeoCoordinates(latitude: 40.7203, longitude: -74.3122))
        
        routingEngine.calculateRoute(with:  [start, destination],
                                     carOptions: CarOptions(),
                                     completion: { (routingError, routes) in
            if let error = routingError {
                print("Error while calculating a route: \(error)")
            }
            
            // When routingError is nil, routes is guaranteed to contain at least one route.
            RouteCalculator.testRoute = routes?.first
            self.showRouteOnMap(route: RouteCalculator.testRoute!)
        })
    }
    
    private func showRouteOnMap(route: Route) {
        // Show route as polyline.
        let routeGeoPolyline = route.geometry
        let widthInPixels = 20.0
        let polylineColor = UIColor(red: 0, green: 0.56, blue: 0.54, alpha: 0.63)
        do {
            let routeMapPolyline =  try MapPolyline(geometry: routeGeoPolyline,
                                                    representation: MapPolyline.SolidRepresentation(
                                                        lineWidth: MapMeasureDependentRenderSize(
                                                            sizeUnit: RenderSize.Unit.pixels,
                                                            size: widthInPixels),
                                                        color: polylineColor,
                                                        capShape: LineCap.round))
            
            mapView.mapScene.addMapPolyline(routeMapPolyline)
        } catch let error {
            fatalError("Failed to render MapPolyline. Cause: \(error)")
        }
    }
}
