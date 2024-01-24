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

import heresdk
import Foundation
import UIKit

class SpatialNavigationExample: SpatialManeuverNotificationDelegate, SpatialManeuverAzimuthDelegate {
    private var spatialAudioExample: SpatialAudioExample?
    private var visualNavigator: VisualNavigator?
    private var locationSimulator: LocationSimulator?
    private var routingEngine: RoutingEngine?
    private var mapView: MapView!
    
    public func setMapView(mapView: MapView) {
        self.mapView = mapView
    }
    
    public func calculateRoute() {
        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }
        
        let startWaypoint = Waypoint(coordinates: GeoCoordinates(latitude: 52.520798, longitude: 13.409408))
        let destinationWaypoint = Waypoint(coordinates: GeoCoordinates(latitude: 52.530905, longitude: 13.385007))
        
        routingEngine!.calculateRoute(with: [startWaypoint, destinationWaypoint],
                                      carOptions: CarOptions()) { (routingError, routes) in
            if let error = routingError {
                print("Error while calculating a route: \(error)")
                return
            }
            
            // When routingError is nil, routes is guaranteed to contain at least one route.
            self.startGuidance(route: routes!.first!)
        }
    }
    
    // Method to be called once navigation has finished or it is desired to finish it.
    public func stopNavigation() {
        if(spatialAudioExample?.isNavigating() == true) {
            spatialAudioExample?.stopNavigation()
            visualNavigator?.stopRendering()
            visualNavigator?.route = nil
            locationSimulator!.stop()
        }
    }
    
    func onSpatialManeuverNotification(spatialManeuver: SpatialManeuver, audioCuePanning: SpatialManeuverAudioCuePanning) {
        spatialAudioExample?.playSpatialAudioCue(audioCue: spatialManeuver.voiceText, initialAzimuthInDegrees: Float(spatialManeuver.initialAzimuthInDegrees), audioCuePanning: audioCuePanning)
    }
    
    func onAzimuthNotification(nextSpatialTrajectoryData: SpatialTrajectoryData) {
        print("Next azimuth value \(nextSpatialTrajectoryData.azimuthInDegrees)")

        spatialAudioExample?.updatePanning(azimuthInDegrees: Float(nextSpatialTrajectoryData.azimuthInDegrees))
        
        if(nextSpatialTrajectoryData.completedSpatialTrajectory) {
            print("Spatial audio trajectory completed")
        }
    }
    
    private func startGuidance(route: Route) {
        do {
            // Without a route set, this starts tracking mode.
            try visualNavigator = VisualNavigator()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize VisualNavigator. Cause: \(engineInstantiationError)")
        }
        
        spatialAudioExample = SpatialAudioExample()
        
        spatialAudioExample?.setupVoiceGuidance(visualNavigator: visualNavigator!)
        
        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator!.startRendering(mapView: mapView!)
        
        // Hook in one of the many listeners. Here we set up a listener to get instructions on the spatial maneuvers to take while driving.
        // For more details, please check the "Navigation" example app and the Developer's Guide.
        visualNavigator!.spatialManeuverNotificationDelegate = self
        
        // Here we set up a listener to get the next azimuth to be apply in order to follow the spatial audio trajectory
        visualNavigator!.spatialManeuverAzimuthDelegate = self
        
        // Set a route to follow. This leaves tracking mode.
        visualNavigator!.route = route
        
        // VisualNavigator acts as LocationDelegate to receive location updates directly from a location provider.
        // Any progress along the route is a result of getting a new location fed into the VisualNavigator.
        setupLocationSource(locationDelegate: visualNavigator!, route: route)
    }
    
    private func setupLocationSource(locationDelegate: LocationDelegate, route: Route) {
        do {
            // Provides fake GPS signals based on the route geometry.
            try locationSimulator = LocationSimulator(route: route,
                                                      options: LocationSimulatorOptions())
        } catch let instantiationError {
            fatalError("Failed to initialize LocationSimulator. Cause: \(instantiationError)")
        }
        
        spatialAudioExample?.setNavigating()
        locationSimulator!.delegate = locationDelegate
        locationSimulator!.start()
    }
}
