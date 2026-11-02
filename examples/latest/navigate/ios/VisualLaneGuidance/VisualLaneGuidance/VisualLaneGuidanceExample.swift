/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

import Foundation
import heresdk
import UIKit
// Handles route calculation, guidance, and camera behavior switching for visual lane guidance.
// Note: Visual lane guidance is a beta feature and requires a Visual Lane Guidance license.
// Talk to your HERE representative for more information.
enum RouteSelection {
    case none
    case chicago
    case berlin
}

class VisualLaneGuidanceExample: EventTextDelegate {
    private let mapView: MapView
    private let routingEngine: RoutingEngine
    private let visualNavigator: VisualNavigator
    private let cameraBehaviors: CameraBehaviors

    private var locationSimulator: LocationSimulator?
    private var route: Route?
    private var selectedRoute: RouteSelection = .none
    private var routePolyline: MapPolyline?
    private var mapMarkers: [MapMarker] = []

    static let chicagoRoute = [
        GeoCoordinates(latitude: 41.8756, longitude: -87.6622),
        GeoCoordinates(latitude: 41.8924, longitude: -87.6485)
    ]

    static let berlinRoute = [
        GeoCoordinates(latitude: 52.5012, longitude: 13.2753),
        GeoCoordinates(latitude: 52.3839, longitude: 13.1509)
    ]

    init(mapView: MapView) {
        self.mapView = mapView
        self.routingEngine = try! RoutingEngine()
        self.visualNavigator = try! VisualNavigator()
        self.cameraBehaviors = CameraBehaviors(visualNavigator: visualNavigator)
    }

    func getSelectedRoute() -> RouteSelection {
        return selectedRoute
    }

    func getCameraBehaviorStatus() -> String {
        return cameraBehaviors.getCameraBehaviorStatus()
    }

    func useTransitionCameraBehavior() {
        cameraBehaviors.useTransitionCameraBehavior()
    }

    func useAutomotiveCameraBehavior() {
        cameraBehaviors.useAutomotiveCameraBehavior()
    }

    func isGuidanceRunning() -> Bool {
        return locationSimulator != nil
    }

    // Calculates the Chicago route.
    func calculateChicagoRoute(onError: @escaping (String) -> Void) {
        selectedRoute = .chicago
        calculateRoute(coords: VisualLaneGuidanceExample.chicagoRoute, onError: onError)
    }

    // Calculates the Berlin route.
    func calculateBerlinRoute(onError: @escaping (String) -> Void) {
        selectedRoute = .berlin
        calculateRoute(coords: VisualLaneGuidanceExample.berlinRoute, onError: onError)
    }

    private func calculateRoute(coords: [GeoCoordinates], onError: @escaping (String) -> Void) {
        if isGuidanceRunning() {
            onError("Guidance is active. Stop guidance before calculating a new route.")
            return
        }

        clearMap()
        addStartAndDestinationMarkers(coords)

        let waypoints = coords.map { Waypoint(coordinates: $0) }
        routingEngine.calculateRoute(with: waypoints, options: RoutingOptions()) { routingError, routes in
            if routingError == nil, let route = routes?.first {
                self.route = route
                self.showRoute(route: route)
                self.animateToRoute(route: route)
            } else {
                onError("Route calculation error: \(String(describing: routingError))")
            }
        }
    }

    // Starts guidance for the current route.
    func startGuidance(onError: (String) -> Void) {
        guard let route = route else {
            onError("Calculate a route first.")
            return
        }

        stopGuidanceInternal(clearMapContents: false)
        useCurrentCameraBehavior()
        removeRoutePolyline()

        // This enables a navigation view including a rendered navigation arrow.
        visualNavigator.startRendering(mapView: mapView)

        // Hook in one of the many listeners to log maneuver instructions.
        visualNavigator.eventTextDelegate = self

        // Set a route to follow. This leaves tracking mode.
        visualNavigator.route = route

        // HD lanes are rendered only while guidance is actively running.
        // Outside guidance, the map remains in the standard navigation view.

        // Any progress along the route is a result of getting a new location fed into the VisualNavigator.
        setupLocationSource(route: route, onError: onError)
    }

    // Stops guidance and clears the map.
    func stopGuidance() {
        stopGuidanceInternal(clearMapContents: true)
    }

    private func stopGuidanceInternal(clearMapContents: Bool) {
        let wasGuidanceRunning = locationSimulator != nil
        visualNavigator.route = nil
        visualNavigator.stopRendering()
        locationSimulator?.stop()
        locationSimulator = nil

        guard let route = route else {
            return
        }

        if wasGuidanceRunning {
            removeRoutePolyline()
            showRoute(route: route)
            animateToRoute(route: route)
            return
        }

        if clearMapContents {
            animateToRoute(route: route)
            clearMap()
        }
    }

    func onEventTextUpdated(_ eventText: heresdk.EventText) {
        print("Maneuver text: \(eventText.text)")
    }

    // Sets up the location simulator for the given route.
    private func setupLocationSource(route: Route, onError: (String) -> Void) {
        locationSimulator?.stop()

        let notificationIntervalInSeconds: TimeInterval = 0.5
        let options = LocationSimulatorOptions(
            speedFactor: 2,
            notificationInterval: notificationIntervalInSeconds
        )

        do {
            // Provides fake GPS signals based on the route geometry.
            let simulator = try LocationSimulator(route: route, options: options)
            simulator.delegate = visualNavigator
            simulator.start()
            locationSimulator = simulator
        } catch {
            locationSimulator = nil
            onError("Failed to start location simulation: \(error)")
        }
    }

    private func addStartAndDestinationMarkers(_ coords: [GeoCoordinates]) {
        addMapMarker(coords.first!, imageName: "poi_start")
        addMapMarker(coords.last!, imageName: "poi_destination")
    }

    // Adds a map marker at the given coordinates with the specified image name.
    private func addMapMarker(_ coordinates: GeoCoordinates, imageName: String) {
        guard let image = UIImage(named: imageName), let data = image.pngData() else { return }
        let mapImage = MapImage(pixelData: data, imageFormat: .png)
        let marker = MapMarker(at: coordinates, image: mapImage)
        mapView.mapScene.addMapMarker(marker)
        mapMarkers.append(marker)
    }

    // Displays the given route as a polyline on the map.
    private func showRoute(route: Route) {
        let color = UIColor(red: 0, green: 0.56, blue: 0.54, alpha: 0.63)
        routePolyline = try? MapPolyline(
            geometry: route.geometry,
            representation: MapPolyline.SolidRepresentation(
                lineWidth: MapMeasureDependentRenderSize(sizeUnit: .pixels, size: 20),
                color: color,
                capShape: .round))

        if let routePolyline = routePolyline {
            mapView.mapScene.addMapPolyline(routePolyline)
        }
    }

    // Animates the camera to fit the given route.
    private func animateToRoute(route: Route) {
        let bearing: Double = 0
        let tilt: Double = 0
        // We want to show the route fitting in the map view with an additional padding of 300 pixels.
        let origin = Point2D(x: 300, y: 300)
        let sizeInPixels = Size2D(width: mapView.viewportSize.width - 600,
                                  height: mapView.viewportSize.height - 600)
        let mapViewport = Rectangle2D(origin: origin, size: sizeInPixels)

        // Animate to the route within a duration of 3 seconds.
        let update = MapCameraUpdateFactory.lookAt(
            area: route.boundingBox,
            orientation: GeoOrientationUpdate(GeoOrientation(bearing: bearing, tilt: tilt)),
            viewRectangle: mapViewport)
        let animation = MapCameraAnimationFactory.createAnimation(
            from: update,
            duration: 3,
            easing: Easing(EasingFunction.inCubic))
        mapView.camera.startAnimation(animation)
    }

    // Removes all map markers and polylines from the map.
    private func clearMap() {
        // Clear all map markers from the map.
        for marker in mapMarkers {
            mapView.mapScene.removeMapMarker(marker)
        }
        mapMarkers.removeAll()

        // Clear the route polyline from the map.
        removeRoutePolyline()
    }

    private func removeRoutePolyline() {
        if let routePolyline = routePolyline {
            mapView.mapScene.removeMapPolyline(routePolyline)
        }
        routePolyline = nil
    }

    private func useCurrentCameraBehavior() {
        visualNavigator.cameraBehavior = cameraBehaviors.activeCameraBehavior
    }
}
