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

import heresdk
import UIKit

// A class that creates car Routes with the HERE SDK.
public class RouteCalculator {
    
    private let routingEngine: RoutingEngine
    
    init(viewController: UIViewController) {
        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }
    }
    
    func calculateRoute(calculateRouteCompletionHandler: @escaping CalculateRouteCompletionHandler) {
        
        let start: Waypoint = Waypoint(coordinates: GeoCoordinates(latitude: 40.71335297425111, longitude: -74.01128262379694))
        let destination: Waypoint = Waypoint(coordinates: GeoCoordinates(latitude: 40.72039108039512, longitude: -74.01226967669756))
        
        routingEngine.calculateRoute(with: [start, destination],
                                     carOptions: CarOptions(),
                                     completion: calculateRouteCompletionHandler)
    }
}
