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
class NavigationWarnersExample : LongPressDelegate {
    
    private let mapView: MapView    
    private let routingEngine: RoutingEngine
    private let visualNavigator: VisualNavigator
    private var locationSimulator: LocationSimulator!
    private var navigationWarners: NavigationWarners
    private var startGeoCoordinates: GeoCoordinates
    private var destinationGeoCoordinates: GeoCoordinates
    private var changeDestination: Bool
    private var startMapMarker: MapMarker!
    private var destinationMapMarker: MapMarker!
    
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
        
        // The class holds several listeners that provide useful information during TBT.
        navigationWarners = NavigationWarners()
        
        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)

        // Default coordinated in Berlin, which can be change by long-tapping the map
        startGeoCoordinates = GeoCoordinates(latitude: 52.520798, longitude: 13.409408)
        destinationGeoCoordinates = GeoCoordinates(latitude: 52.530905, longitude: 13.385007)
        changeDestination = false
        startMapMarker = addMapMarker(geoCoordinates: startGeoCoordinates, imageName: "poi_start.png")!
        destinationMapMarker = addMapMarker(geoCoordinates: destinationGeoCoordinates, imageName: "poi_destination.png")!
        
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
        
        mapView.gestures.longPressDelegate = self
        
        showDialog(title: "Navigation Warners",
                   message: "This app routes to the HERE office in Berlin and logs various TBT events.")
        showDialog(title: "Note",
                   message: "Do a long press to change start and destination coordinates. " +
                   "Map icons are pickable.")
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
        }
    }
    
    func onLongPress(state: heresdk.GestureState, origin: Point2D) {
        let geoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: origin)
        
        if geoCoordinates == nil {
            showDialog(title: "Note", message: "Invalid GeoCoordinates.")
        }
        
        if (state == .begin) {
            // Set new route start or destination geographic coordinates based on long press location.
            if changeDestination {
                destinationGeoCoordinates = geoCoordinates!
                destinationMapMarker.coordinates = geoCoordinates!
            } else {
                startGeoCoordinates = geoCoordinates!
                startMapMarker.coordinates = geoCoordinates!
            }
            // Toggle the marker that should be updated on next long press.
            changeDestination = !changeDestination;
        }
    }
    
    func onStartGuidanceClicked() {
        calculateRoute(startWaypoint: Waypoint(coordinates: startGeoCoordinates), destinationWaypoint: Waypoint(coordinates: destinationGeoCoordinates))
    }
    
    // When route calculation is done, we automatically start navigation to keep this example simple.
    private func calculateRoute(startWaypoint: Waypoint, destinationWaypoint: Waypoint) {
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
        
        // Set up all the warners.
        navigationWarners.setupDelegates(visualNavigator)

        // Set a route to follow. This leaves tracking mode.
        visualNavigator.route = route

        // VisualNavigator acts as LocationDelegate to receive location updates directly from a location provider.
        // Any progress along the route is a result of getting a new location fed into the VisualNavigator.
        setupLocationSource(locationDelegate: visualNavigator, route: route)
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
    
    private func addMapMarker(geoCoordinates: GeoCoordinates, imageName: String) -> MapMarker? {
        guard
            let image = UIImage(named: imageName),
            let imageData = image.pngData() else {
            return nil
        }
        let mapMarker = MapMarker(at: geoCoordinates,
                                    image: MapImage(pixelData: imageData,
                                                    imageFormat: ImageFormat.png))
        mapMarker.anchor = Anchor2D(horizontal: 0.5, vertical: 1.0)
            
        mapView.mapScene.addMapMarker(mapMarker)
        return mapMarker
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
