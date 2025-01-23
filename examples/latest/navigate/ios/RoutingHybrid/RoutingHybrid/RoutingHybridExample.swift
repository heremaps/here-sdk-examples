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

class RoutingHybridExample {

    private var mapView: MapView
    private var mapMarkers = [MapMarker]()
    private var mapPolylineList = [MapPolyline]()
    private var routingEngine: RoutingProtocol
    private var onlineRoutingEngine: RoutingEngine
    private var offlineRoutingEngine: OfflineRoutingEngine
    private var isDeviceConnected = false
    private var startGeoCoordinates: GeoCoordinates?
    private var destinationGeoCoordinates: GeoCoordinates?

    init(_ mapView: MapView) {
        self.mapView = mapView
        let camera = mapView.camera

        // Configure the map.
        let distanceInMeters = MapMeasure(kind: .distance, value: 5000)
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      zoom: distanceInMeters)

        do {
            try onlineRoutingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }

        do {
            // Allows to calculate routes on already downloaded or cached map data.
            // For downloading offline maps, please check the OfflineMaps example app.
            // This app uses only cached map data that gets downloaded when the user
            // pans the map. Please note that the OfflineRoutingEngine may not be able
            // to calculate a route, when not all map tiles are loaded. Especially, the
            // vector tiles for lower zoom levels are required to find possible paths.
            try offlineRoutingEngine = OfflineRoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize offline routing engine. Cause: \(engineInstantiationError)")
        }

        // By default, use online routing engine.
        routingEngine = onlineRoutingEngine

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }

    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        mapView.mapScene.enableFeatures([MapFeatures.trafficFlow : MapFeatureModes.defaultMode]);
        mapView.mapScene.enableFeatures([MapFeatures.trafficIncidents : MapFeatureModes.defaultMode]);
    }

    // Calculates a route with two waypoints (start / destination).
    func addRoute() {
        setRoutingEngine()

        startGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        destinationGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        let carOptions = CarOptions()
        routingEngine.calculateRoute(with: [Waypoint(coordinates: startGeoCoordinates!),
                                            Waypoint(coordinates: destinationGeoCoordinates!)],
                                     carOptions: carOptions) { (routingError, routes) in

                                        if let error = routingError {
                                            self.showDialog(title: "Error while calculating a route:", message: "\(error)")
                                            return
                                        }

                                        // When routingError is nil, routes is guaranteed to contain at least one route.
                                        let route = routes!.first
                                        self.showRouteDetails(route: route!)
                                        self.showRouteOnMap(route: route!)
                                        self.logRouteViolations(route: route!)
        }
    }

    // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
    // An implementation may decide to reject a route if one or more violations are detected.
    private func logRouteViolations(route: Route) {
        let sections = route.sections
        for section in sections {
            for notice in section.sectionNotices {
                print("This route contains the following warning: \(notice.code)")
            }
        }
    }

    private func showRouteDetails(route: Route) {
        let estimatedTravelTimeInSeconds = route.duration
        let lengthInMeters = route.lengthInMeters

        let routeDetails = "Travel Time: " + formatTime(sec: estimatedTravelTimeInSeconds)
                         + ", Length: " + formatLength(meters: lengthInMeters)

        showDialog(title: "Route Details", message: routeDetails)
    }

    private func formatTime(sec: Double) -> String {
        let hours: Double = sec / 3600
        let minutes: Double = (sec.truncatingRemainder(dividingBy: 3600)) / 60

        return "\(Int32(hours)):\(Int32(minutes))"
    }

    private func formatLength(meters: Int32) -> String {
        let kilometers: Int32 = meters / 1000
        let remainingMeters: Int32 = meters % 1000

        return "\(kilometers).\(remainingMeters) km"
    }

    private func showRouteOnMap(route: Route) {
        clearMap()

        // Show route as polyline.
        let routeGeoPolyline = route.geometry
        let polylineColor = UIColor(red: 0.051, green: 0.380, blue: 0.871, alpha: 1)
        let outlineColor = UIColor(red: 0.043, green: 0.325, blue: 0.749, alpha: 1)
        do {
            // Below, we're creating an instance of MapMeasureDependentRenderSize. This instance will use the scaled width values to render the route polyline.
            // We can also apply the same values to MapArrow.setMeasureDependentTailWidth().
            // The parameters for the constructor are: the kind of MapMeasure (in this case, ZOOM_LEVEL), the unit of measurement for the render size (PIXELS), and the scaled width values.
            let mapMeasureDependentLineWidth = try MapMeasureDependentRenderSize(measureKind: MapMeasure.Kind.zoomLevel, sizeUnit: RenderSize.Unit.pixels, sizes: getDefaultLineWidthValues())

            // We can also use MapMeasureDependentRenderSize to specify the outline width of the polyline.
            let outlineWidthInPixel = 1.23 * mapView.pixelScale
            let mapMeasureDependentOutlineWidth = try MapMeasureDependentRenderSize(sizeUnit: RenderSize.Unit.pixels, size: outlineWidthInPixel)
            let routeMapPolyline =  try MapPolyline(geometry: routeGeoPolyline,
                                                    representation: MapPolyline.SolidRepresentation(
                                                        lineWidth: mapMeasureDependentLineWidth,
                                                        color: polylineColor,
                                                        outlineWidth: mapMeasureDependentOutlineWidth,
                                                        outlineColor: outlineColor,
                                                        capShape: LineCap.round))

            mapView.mapScene.addMapPolyline(routeMapPolyline)
            mapPolylineList.append(routeMapPolyline)
        } catch let error {
            fatalError("Failed to render MapPolyline. Cause: \(error)")
        }

        let startPoint = route.sections.first!.departurePlace.mapMatchedCoordinates
        let destination = route.sections.last!.arrivalPlace.mapMatchedCoordinates

        // Draw a circle to indicate starting point and destination.
        addCircleMapMarker(geoCoordinates: startPoint, imageName: "green_dot.png")
        addCircleMapMarker(geoCoordinates: destination, imageName: "green_dot.png")

        // Log maneuver instructions per route leg / sections.
        let sections = route.sections
        for section in sections {
            logManeuverInstructions(section: section)
        }
    }

    // Retrieves the default widths of a route polyline and maneuver arrows from VisualNavigator,
    // scaling them based on the screen's pixel density.
    // Note that the VisualNavigator stores the width values per zoom level MapMeasure.Kind.
    private func getDefaultLineWidthValues() -> [Double:Double] {
        var widthsPerZoomLevel: [Double: Double] = [:];
        for defaultValues in VisualNavigator.defaultRouteManeuverArrowMeasureDependentWidths() {
                let key = defaultValues.key.value
                let value = defaultValues.value * mapView.pixelScale
                widthsPerZoomLevel[key] = value
            }
        return widthsPerZoomLevel
    }

    private func logManeuverInstructions(section: heresdk.Section) {
        print("Log maneuver instructions per section:")
        let maneuverInstructions = section.maneuvers
        for maneuverInstruction in maneuverInstructions {
            let maneuverAction = maneuverInstruction.action
            let maneuverLocation = maneuverInstruction.coordinates
            let maneuverInfo = "\(maneuverInstruction.text)"
                + ", Action: \(maneuverAction)"
                + ", Location: \(maneuverLocation)"
            print(maneuverInfo)
        }
    }

    // Calculates a route with additional waypoints.
    func addWaypoints() {
        setRoutingEngine()

        guard
            let startGeoCoordinates = startGeoCoordinates,
            let destinationGeoCoordinates = destinationGeoCoordinates else {
                showDialog(title: "Error", message: "Please add a route first.")
                return
        }

        let waypoint1GeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        let waypoint2GeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        let waypoints = [Waypoint(coordinates: startGeoCoordinates),
                         Waypoint(coordinates: waypoint1GeoCoordinates),
                         Waypoint(coordinates: waypoint2GeoCoordinates),
                         Waypoint(coordinates: destinationGeoCoordinates)]

        let carOptions = CarOptions()
        routingEngine.calculateRoute(with: waypoints,
                                     carOptions: carOptions) { (routingError, routes) in

                                        if let error = routingError {
                                            self.showDialog(title: "Error while calculating a route:", message: "\(error)")
                                            return
                                        }

                                        let route = routes!.first
                                        self.showRouteDetails(route: route!)
                                        self.showRouteOnMap(route: route!)
                                        self.logRouteViolations(route: route!)

                                        // Draw a circle to indicate the location of the waypoints.
                                        self.addCircleMapMarker(geoCoordinates: waypoint1GeoCoordinates, imageName: "red_dot.png")
                                        self.addCircleMapMarker(geoCoordinates: waypoint2GeoCoordinates, imageName: "red_dot.png")
        }
    }

    func clearMap() {
        clearWaypointMapMarker()
        clearRoute()
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

    func onSwitchOnlineButtonClicked() {
        isDeviceConnected = true
        showDialog(title: "Note", message: "The app uses now the RoutingEngine.")
    }

    func onSwitchOfflineButtonClicked() {
        isDeviceConnected = false
        showDialog(title: "Note", message: "The app uses now the OfflineRoutingEngine.")
    }

    private func createRandomGeoCoordinatesAroundMapCenter() -> GeoCoordinates {
        let scaleFactor = UIScreen.main.scale
        let mapViewWidthInPixels = Double(mapView.bounds.width * scaleFactor)
        let mapViewHeightInPixels = Double(mapView.bounds.height * scaleFactor)
        let centerPoint2D = Point2D(x: mapViewWidthInPixels / 2,
                                    y: mapViewHeightInPixels / 2)

        let centerGeoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: centerPoint2D)
        let lat = centerGeoCoordinates!.latitude
        let lon = centerGeoCoordinates!.longitude
        return GeoCoordinates(latitude: getRandom(min: lat - 0.02,
                                                  max: lat + 0.02),
                              longitude: getRandom(min: lon - 0.02,
                                                   max: lon + 0.02))
    }

    private func getRandom(min: Double, max: Double) -> Double {
        return Double.random(in: min ... max)
    }

    private func addCircleMapMarker(geoCoordinates: GeoCoordinates, imageName: String) {
        guard
            let image = UIImage(named: imageName),
            let imageData = image.pngData() else {
                return
        }
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png))
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    // Sets the OfflineRoutingEngine as main engine when the device is not connected, otherwise this will set the
    // RoutingEngine that requires connectivity.
    private func setRoutingEngine() {
        if isDeviceConnected {
            routingEngine = onlineRoutingEngine
        } else {
            routingEngine = offlineRoutingEngine
        }
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
