/*
 * Copyright (C) 2019 HERE Europe B.V.
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

class RoutingExample {

    private var viewController: UIViewController!
    private var mapView: MapView!
    private var mapMarkers = [MapMarker]()
    private var mapPolylineList = [MapPolyline]()
    private var routingEngine: RoutingEngine!
    private var startGeoCoordinates: GeoCoordinates?
    private var destinationGeoCoordinates: GeoCoordinates?

    func onMapSceneLoaded(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
        let camera = mapView.camera
        camera.setTarget(GeoCoordinates(latitude: 52.520798, longitude: 13.409408))
        camera.setZoomLevel(12)

        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }
    }

    func addRoute() {
        clearMap()

        startGeoCoordinates = createRandomGeoCoordinatesInViewport()
        destinationGeoCoordinates = createRandomGeoCoordinatesInViewport()

        let carOptions = CarOptions()
        routingEngine.calculateRoute(with: [Waypoint(coordinates: startGeoCoordinates!),
                                            Waypoint(coordinates: destinationGeoCoordinates!)],
                                     carOptions: carOptions) { (routingError, routes) in

                                        if let error = routingError {
                                            self.showDialog(title: "Error while calculating a route:", message: "\(error)")
                                            return
                                        }

                                        let route = routes!.first
                                        self.showRouteDetails(route: route!)
                                        self.showRouteOnMap(route: route!)
        }
    }

    private func showRouteDetails(route: Route) {
        let estimatedTravelTimeInSeconds = route.travelTimeInSeconds
        let lengthInMeters = route.lengthInMeters

        let routeDetails =
            "Travel Time: " + formatTime(sec: estimatedTravelTimeInSeconds)
                + ", Length: " + formatLength(meters: lengthInMeters)

        showDialog(title: "Route Details", message: routeDetails)
    }

    private func formatTime(sec: Int32) -> String {
        let hours: Int32 = sec / 3600
        let minutes: Int32 = (sec % 3600) / 60

        return "\(hours):\(minutes)"
    }

    private func formatLength(meters: Int32) -> String {
        let kilometers: Int32 = meters / 1000
        let remainingMeters: Int32 = meters % 1000

        return "\(kilometers).\(remainingMeters) km"
    }

    private func showRouteOnMap(route: Route) {
        // Show route as polyline.
        let routeGeoPolyline = try! GeoPolyline(vertices: route.shape)
        let mapPolylineStyle = MapPolylineStyle()
        mapPolylineStyle.setColor(0x00908AA0, encoding: .rgba8888)
        mapPolylineStyle.setWidth(inPixels: 10)
        let routeMapPolyline = MapPolyline(geometry: routeGeoPolyline, style: mapPolylineStyle)
        mapView.mapScene.addMapPolyline(routeMapPolyline)
        mapPolylineList.append(routeMapPolyline)

        // Draw a circle to indicate starting point and destination.
        addCircleMapMarker(geoCoordinates: startGeoCoordinates!, imageName: "green_dot.png")
        addCircleMapMarker(geoCoordinates: destinationGeoCoordinates!, imageName: "green_dot.png")

        // Log maneuver instructions per route leg.
        let routeLegs = route.legs
        for routeLeg in routeLegs {
            logManeuverInstructions(routeLeg: routeLeg)
        }
    }

    private func logManeuverInstructions(routeLeg: RouteLeg) {
        print("Log maneuver instructions per route leg:")
        let maneuverInstructions = routeLeg.instructions
        for maneuverInstruction in maneuverInstructions {
            let maneuverAction = maneuverInstruction.action
            let maneuverDirection = maneuverInstruction.direction
            let maneuverLocation = maneuverInstruction.coordinates
            let maneuverInfo = "\(maneuverInstruction.text)"
                + ", Action: \(maneuverAction)"
                + ", Direction: \(maneuverDirection)"
                + ", Location: \(maneuverLocation)"
            print(maneuverInfo)
        }
    }

    func addWaypoints() {
        guard let startGeoCoordinates = startGeoCoordinates, let destinationGeoCoordinates = destinationGeoCoordinates else {
            showDialog(title: "Error", message: "Please add a route first.")
            return
        }

        clearWaypointMapMarker()
        clearRoute()

        let waypoint1GeoCoordinates = createRandomGeoCoordinatesInViewport()
        let waypoint2GeoCoordinates = createRandomGeoCoordinatesInViewport()
        let waypoints = [Waypoint(coordinates: startGeoCoordinates),
                         Waypoint(coordinates: waypoint1GeoCoordinates),
                         Waypoint(coordinates: waypoint2GeoCoordinates),
                         Waypoint(coordinates: destinationGeoCoordinates)]

        let carOptions = CarOptions()
        routingEngine!.calculateRoute(with: waypoints,
                                      carOptions: carOptions) { (routingError, routes) in

                                        if let error = routingError {
                                            self.showDialog(title: "Error while calculating a route:", message: "\(error)")
                                            return
                                        }

                                        let route = routes!.first
                                        self.showRouteDetails(route: route!)
                                        self.showRouteOnMap(route: route!)

                                        // Draw a circle to indicate the location of the waypoints.
                                        self.addCircleMapMarker(geoCoordinates: waypoint1GeoCoordinates, imageName: "red_dot.png")
                                        self.addCircleMapMarker(geoCoordinates: waypoint2GeoCoordinates, imageName: "red_dot.png")
        }
    }

    func clearMap() {
        clearWaypointMapMarker()
        clearRoute()

        startGeoCoordinates = nil
        destinationGeoCoordinates = nil
    }

    private func clearWaypointMapMarker() {
        for mapMarker in mapMarkers {
            mapView.mapScene.removeMapMarker(mapMarker)
        }
        mapMarkers.removeAll()
    }

    private func clearRoute() {
        for mapPolyline in mapPolylineList {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylineList.removeAll()
    }

    private func createRandomGeoCoordinatesInViewport() -> GeoCoordinates {
        let geoBoundingRect = mapView.camera.boundingRect
        let northEast = geoBoundingRect.northEastCorner
        let southWest = geoBoundingRect.southWestCorner

        let minLat = southWest.latitude
        let maxLat = northEast.latitude
        let lat = getRandom(min: minLat, max: maxLat)

        let minLon = southWest.longitude
        let maxLon = northEast.longitude
        let lon = getRandom(min: minLon, max: maxLon)

        return GeoCoordinates(latitude: lat, longitude: lon)
    }

    private func getRandom(min: Double, max: Double) -> Double {
        return Double.random(in: min ... max)
    }

    private func addCircleMapMarker(geoCoordinates: GeoCoordinates, imageName: String) {
        let mapMarker = MapMarker(at: geoCoordinates)
        let image = UIImage(named: imageName)
        let mapImage = MapImage(image!)
        mapMarker.addImage(mapImage!, style: MapMarkerImageStyle())
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
