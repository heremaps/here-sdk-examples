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
import UIKit

class ViewController: UIViewController, EventTextDelegate {

    @IBOutlet var mapView: MapView!
   
    private var routingEngine: RoutingEngine?
    private var visualNavigator: VisualNavigator?
    private var locationSimulator: LocationSimulator?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }

    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)
        
        startGuidanceExample()
    }
    
    private func startGuidanceExample() {
        showDialog(title: "Navigation Quick Start",
                   message: "This app routes to the HERE office in Berlin. See logs for guidance information.")

        // We start by calculating a car route.
        calculateRoute()
    }

    private func calculateRoute() {
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

    private func startGuidance(route: Route) {
        do {
            // Without a route set, this starts tracking mode.
            try visualNavigator = VisualNavigator()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize VisualNavigator. Cause: \(engineInstantiationError)")
        }

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator!.startRendering(mapView: mapView)

        // Hook in one of the many listeners. Here we set up a listener to get instructions on the maneuvers to take while driving.
        // For more details, please check the "Navigation" example app and the Developer's Guide.
        visualNavigator!.eventTextDelegate = self

        // Set a route to follow. This leaves tracking mode.
        visualNavigator!.route = route

        // VisualNavigator acts as LocationDelegate to receive location updates directly from a location provider.
        // Any progress along the route is a result of getting a new location fed into the VisualNavigator.
        setupLocationSource(locationDelegate: visualNavigator!, route: route)
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

        locationSimulator!.delegate = locationDelegate
        locationSimulator!.start()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
    
    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}
