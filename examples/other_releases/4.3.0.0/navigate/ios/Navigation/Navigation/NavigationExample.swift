/*
 * Copyright (C) 2019-2020 HERE Europe B.V.
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

// Shows how to start and stop turn-by-turn navigation.
// By default, tracking mode is enabled. When navigation is stopped, tracking mode is enabled again.
class NavigationExample : CurrentLocationDelegate,
                          RouteProgressDelegate,
                          RouteDeviationDelegate {

    private let viewController: UIViewController
    private let mapView: MapView
    private let navigator: Navigator
    private let locationProvider: LocationProviderImplementation
    private var previousManeuverIndex: Int32 = -1
    private lazy var navigationArrow = createArrow(asset: "arrow_blue.png")
    private lazy var trackingArrow = createArrow(asset: "arrow_green.png")

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView

        locationProvider = LocationProviderImplementation()
        locationProvider.start()

        do {
            // Without a route set, this starts tracking mode.
            try navigator = Navigator(locationProvider: locationProvider)
        } catch let engineInstantiationError {
            fatalError("Failed to initialize navigator. Cause: \(engineInstantiationError)")
        }

        navigator.currentLocationDelegate = self
        navigator.routeDeviationDelegate = self
        navigator.routeProgressDelegate = self
    }

    private func createArrow(asset: String) -> MapMarker {
        guard
            let image = UIImage(named: asset),
            let imageData = image.pngData() else {
                fatalError("Image data not available.")
        }

        let mapImage = MapImage(pixelData: imageData,
                                imageFormat: ImageFormat.png)
        let mapMarker = MapMarker(at: ConstantsEnum.DEFAULT_MAP_CENTER,
                                  image: mapImage)
        return mapMarker
    }

    // Conform to RouteProgressDelegate.
    func onRouteProgressUpdated(_ routeProgress: RouteProgress) {
        // [SectionProgress] is guaranteed to be non-empty.
        let distanceToDestination = routeProgress.sectionProgress.last!.remainingDistanceInMeters
        print("Distance to destination in meters: \(distanceToDestination)")
        let trafficDelayAhead = routeProgress.sectionProgress.last!.trafficDelayInSeconds
        print("Traffic delay ahead in seconds: \(trafficDelayAhead)")

        let maneuverIndex = routeProgress.currentManeuverIndex
        guard let maneuver = navigator.getManeuver(index: maneuverIndex) else {
            print("No maneuver available.")
            return
        }

        let action = maneuver.action
        let nextRoadName = maneuver.nextRoadName
        var road = nextRoadName == nil ? maneuver.nextRoadNumber : nextRoadName
        if action == ManeuverAction.arrive {
            // We are reaching destination, so there's no next road.
            let roadName = maneuver.roadName
            road = roadName == nil ? maneuver.roadNumber : roadName
        }

        let logMessage = "'\(String(describing: action))' on \(road ?? "unnamed road") in \(routeProgress.currentManeuverRemainingDistanceInMeters) meters."

        if previousManeuverIndex != maneuverIndex {
            // Log only new maneuvers and ignore changes in distance.
            showMessage("New maneuver: " + logMessage)
        }

        previousManeuverIndex = maneuverIndex
    }

    // Conform to CurrentLocationDelegate.
    func onCurrentLocationUpdated(_ currentLocation: CurrentLocation) {
        guard let mapMatchedLocation = currentLocation.mapMatchedLocation else {
            showMessage("This new location could not be map-matched. Using raw location.")
            updateMapView(currentLocation.rawLocation)
            return
        }

        print("Current street: \(String(describing: currentLocation.streetName))")

        if currentLocation.speedLimitInMetersPerSecond == 0 {
            print("No speed limits on this road! Drive as fast as you feel safe ...")
        } else {
            // Can be nil if data could not be retrieved. In this case the real speed limits are unknown.
            print("Current speed limit (m/s): \(String(describing: currentLocation.speedLimitInMetersPerSecond))")
        }

        updateMapView(mapMatchedLocation)
    }

    // Conform to RouteDeviationDelegate.
    func onRouteDeviation(_ routeDeviation: RouteDeviation) {
        let distanceInMeters = routeDeviation.currentLocation.coordinates.distance(
            to: routeDeviation.lastLocationOnRoute.coordinates)
        print("RouteDeviation in meters is \(distanceInMeters)")
    }

    // Update location and rotation of map. Update location of arrow.
    private func updateMapView(_ currentLocation: Location) {
        var orientation = MapCamera.OrientationUpdate()
        if let bearing = currentLocation.bearingInDegrees {
            orientation.bearing = bearing
        }

        let currentGeoCoordinates = currentLocation.coordinates
        mapView.camera.lookAt(point: currentGeoCoordinates,
                              orientation: orientation,
                              distanceInMeters: ConstantsEnum.DEFAULT_DISTANCE_IN_METERS)
        navigationArrow.coordinates = currentGeoCoordinates
        trackingArrow.coordinates = currentGeoCoordinates
    }

    func startNavigation(route: Route,
                                isSimulated: Bool) {
        navigator.route = route

        if isSimulated {
            locationProvider.enableRoutePlayback(route: route)
        } else {
            locationProvider.enableDevicePositioning()
        }

        mapView.mapScene.addMapMarker(navigationArrow)
        updateArrowLocations()
    }

    func stopNavigation() {
        navigator.route = nil
        mapView.mapScene.removeMapMarker(navigationArrow)
    }

    func startTracking() {
        // Reset route in case TBT was started before.
        navigator.route = nil
        locationProvider.enableDevicePositioning()

        mapView.mapScene.addMapMarker(trackingArrow)
        updateArrowLocations()
        showMessage("Free tracking: Running.")
    }

    func stopTracking() {
        mapView.mapScene.removeMapMarker(trackingArrow)
        showMessage("Free tracking: Stopped.")
    }

    private func updateArrowLocations() {
        guard let lastKnownLocation = getLastKnownGeoCoordinates() else {
            print("No location found.")
            return
        }

        navigationArrow.coordinates = lastKnownLocation
        trackingArrow.coordinates = lastKnownLocation
    }

    func getLastKnownGeoCoordinates() -> GeoCoordinates? {
        return locationProvider.lastKnownLocation?.coordinates
    }

    private var messageTextView = UITextView()
    private func showMessage(_ message: String) {
        messageTextView.text = message
        messageTextView.textColor = .white
        messageTextView.backgroundColor = UIColor(red: 0, green: 144 / 255, blue: 138 / 255, alpha: 1)
        messageTextView.layer.cornerRadius = 8
        messageTextView.isEditable = false
        messageTextView.textAlignment = NSTextAlignment.center
        messageTextView.font = .systemFont(ofSize: 14)
        messageTextView.frame = CGRect(x: 0, y: 0, width: mapView.frame.width * 0.9, height: 50)
        messageTextView.center = CGPoint(x: mapView.frame.width * 0.5, y: mapView.frame.height * 0.9)

        UIView.transition(with: mapView, duration: 0.2, options: [.transitionCrossDissolve], animations: {
            self.mapView.addSubview(self.messageTextView)
        })

        // Hide message after 5 seconds.
        let messageDurationInSeconds: Double = 5
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + messageDurationInSeconds) {
            UIView.transition(with: self.mapView, duration: 0.2, options: [.transitionCrossDissolve], animations: {
                self.messageTextView.removeFromSuperview()
            })
        }
    }
}
