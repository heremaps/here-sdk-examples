/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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
import SwiftUI

// A class that starts turn-by-turn navigation in simulation mode using a hardcoded route.
class NavigationQuickStartExample: EventTextDelegate {
    
    private let mapView: MapView    
    private let routingEngine: RoutingEngine
    private let visualNavigator: VisualNavigator
    private var locationSimulator: LocationSimulator!
    
    init(_ mapView: MapView) {
        self.mapView = mapView
        
        do {
            // Before we can start turn-by-turn navigation, we need a route to follow.
            // Note that navigation is also supported without a route in tracking mode,
            // See Developer Guide for more details.
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }
        
        do {
            // Without a route set, this starts tracking mode.
            try visualNavigator = VisualNavigator()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize VisualNavigator. Cause: \(engineInstantiationError)")
        }
        
        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)
        
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
        }
    }
    
    func startGuidanceExample() {
        showDialog(title: "Navigation Quick Start",
                   message: "This app routes to the HERE office in Berlin. See logs for guidance information.")

        // We start by calculating a car route.
        calculateRoute()
    }
    
    // When route calculation is done, we automatically start navigation to keep this example simple.
    private func calculateRoute() {
        // Define starting and end point of a route for testing.
        let startWaypoint = Waypoint(coordinates: GeoCoordinates(latitude: 52.520798, longitude: 13.409408))
        let destinationWaypoint = Waypoint(coordinates: GeoCoordinates(latitude: 52.530905, longitude: 13.385007))

        routingEngine.calculateRoute(with: [startWaypoint, destinationWaypoint],
                                     carOptions: CarOptions()) { (routingError, routes) in
            if let error = routingError {
                print("Error while calculating a route: \(error)")
                return
            }

            // When routingError is nil, routes is guaranteed to contain at least one route.
            self.startTurnByTurnNavigation(route: routes!.first!)
        }
    }

    private func startTurnByTurnNavigation(route: Route) {
        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator.startRendering(mapView: mapView)

        // Hook in one of the many listeners. Here we set up a listener to get instructions on the maneuvers to take while driving.
        // For more details, please check the "Navigation" example app and the Developer's Guide.
        visualNavigator.eventTextDelegate = self

        // Set a route to follow. This leaves tracking mode.
        visualNavigator.route = route

        // VisualNavigator acts as LocationDelegate to receive location updates directly from a location provider.
        // Any progress along the route is a result of getting a new location fed into the VisualNavigator.
        setupLocationSource(locationDelegate: visualNavigator, route: route)
    }

    // Conform to EventTextDelegate.
    func onEventTextUpdated(_ eventText: heresdk.EventText) {
        print("Maneuver text: \(eventText.text)")
    }
    
    private func setupLocationSource(locationDelegate: LocationDelegate, route: Route) {
        do {
            // Provides fake GPS signals based on the route geometry.
            try locationSimulator = LocationSimulator(route: route,
                                                      options: LocationSimulatorOptions())
        } catch let instantiationError {
            fatalError("Failed to initialize LocationSimulator. Cause: \(instantiationError)")
        }
        
        locationSimulator.delegate = locationDelegate
        locationSimulator.start()
    }
    
    private func showDialog(title: String, message: String) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {

            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                // Handle OK button action.
                alert.dismiss(animated: true, completion: nil)
            }))

            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
}
