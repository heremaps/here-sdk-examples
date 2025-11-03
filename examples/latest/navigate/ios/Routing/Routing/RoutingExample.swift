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

class RoutingExample {
    
    private let mapView: MapView
    private var mapMarkers = [MapMarker]()
    private var mapPolylineList = [MapPolyline]()
    private let routingEngine: RoutingEngine
    private var startGeoCoordinates: GeoCoordinates?
    private var destinationGeoCoordinates: GeoCoordinates?
    private var disableOptimization = true
    private var waypoints = [Waypoint]()
    private let timeUtils: TimeUtils
    private var currentRoute: Route?
    private let offroadDistanceThresholdMeters: Double = 500.0
    private var currentRouteCalculationTask: TaskHandle?
    
    init(_ mapView: MapView) {
        self.mapView = mapView
        self.timeUtils = TimeUtils()

        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }
        
        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      zoom: distanceInMeters)
        
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Optionally, enable low speed zone map layer.
        mapView.mapScene.enableFeatures([MapFeatures.lowSpeedZones : MapFeatureModes.lowSpeedZonesAll]);
    }
    
    func addRoute() {
        if (isRouteCalculationRunning()) {
            print("Previous route calculation still in progress.");
            return;
        }

        // Optionally, clear any previous route.
        clearMap()

        startGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        destinationGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        waypoints = [Waypoint(coordinates: startGeoCoordinates!),
                     Waypoint(coordinates: destinationGeoCoordinates!)]

        addMapMarker(geoCoordinates: startGeoCoordinates!, imageName: "poi_start.png")
        addMapMarker(geoCoordinates: destinationGeoCoordinates!, imageName: "poi_destination.png")

        calculateRoute(waypoints: waypoints)
    }
    
    private func isRouteCalculationRunning() -> Bool {
        return currentRouteCalculationTask != nil && currentRouteCalculationTask?.isFinished == false
    }
    
    func onUpdateTrafficOnRouteButtonClick() {
        if currentRoute != nil {
            updateTrafficOnRoute(route: currentRoute)
        } else {
            showDialog(title: "Error", message: "Add a route first to get traffic information on route.")
        }
    }

    func updateTrafficOnRoute(route: Route?) {
        guard !disableOptimization else {
            showDialog(title: "Traffic", message: "Disabled traffic optimization.")
            return
        }
        
        // Since traffic is being calculated for the entire route, lastTraveledSectionIndex and traveledDistanceOnLastSectionInMeters are set to 0.
        let lastTraveledSectionIndex = 0
        let traveledDistanceOnLastSectionInMeters = 0
        
        routingEngine.calculateTrafficOnRoute(
            route: route!,
            lastTraveledSectionIndex: Int32(lastTraveledSectionIndex),
            traveledDistanceOnLastSectionInMeters: Int32(traveledDistanceOnLastSectionInMeters)
        ) { routingError, trafficOnRoute in
            if let error = routingError {
                print("CalculateTrafficOnRoute error: \(error)")
            } else if let trafficOnRoute = trafficOnRoute {
                self.showUpdatedETA(trafficOnRoute: trafficOnRoute)
            }
        }
    }

    private func showUpdatedETA(trafficOnRoute: TrafficOnRoute) {
        for section in trafficOnRoute.trafficSections {
            var updatedETAInSeconds = 0.0;
            section.trafficSpans.forEach{ updatedETAInSeconds = updatedETAInSeconds + Double($0.duration)}
            var updatedTrafficDelayInSeconds = 0.0;
            section.trafficSpans.forEach{ updatedTrafficDelayInSeconds = updatedTrafficDelayInSeconds + Double($0.trafficDelay)}
            let updatedETAString = String(format: "Updated travel duration %@\nUpdated traffic delay %@",
                                          timeUtils.formatTime(sec: updatedETAInSeconds),
                                          timeUtils.formatTime(sec: updatedTrafficDelayInSeconds))
            showDialog(title: "Updated traffic", message: updatedETAString)
        }
    }

    private func calculateRoute(waypoints: Array<Waypoint>) {
        currentRouteCalculationTask = routingEngine.calculateRoute(with: waypoints,
                                     carOptions: getCaroptions()) { (routingError, routes) in
            
            if let error = routingError {
                self.showDialog(title: "Error while calculating a route:", message: "\(error)")
                return
            }
            
            // When routingError is nil, routes is guaranteed to contain at least one route.
            let route = routes!.first
            self.currentRoute = routes!.first!
            self.showRouteDetails(route: self.currentRoute!)
            self.showRouteOnMap(route: self.currentRoute!)
            self.logRouteRailwayCrossingDetails(route: self.currentRoute!)
            self.logRouteSectionDetails(route: self.currentRoute!)
            self.logRouteViolations(route: self.currentRoute!)
            self.logTollDetails(route: self.currentRoute!)
        }
    }
    
    // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
    // An implementation may decide to reject a route if one or more violations are detected.
    private func logRouteViolations(route: Route) {
        let sections = route.sections
        for section in sections {
            for span in section.spans {
                let spanGeometryVertices = span.geometry.vertices;
                // This route violation spreads across the whole span geometry.
                guard let violationStartPoint: GeoCoordinates  = spanGeometryVertices.first else {
                    print("Error: violation start geocoordinate is empty.")
                    return
                };
                guard let violationEndPoint : GeoCoordinates = spanGeometryVertices.last else {
                    print("Error: violation end geocoordinate is empty.")
                    return
                };
                for index in span.noticeIndexes{
                    let spanSectionNotice : SectionNotice = section.sectionNotices[Int(index)];
                    // The violation code such as "violatedVehicleRestriction".
                    let violationCode = spanSectionNotice.code;
                    print("The violation \(violationCode)  starts at \(toString(geoCoordinates: violationStartPoint))  and ends at  \(toString(geoCoordinates: violationEndPoint)) .");
                    
                }
            }
        }
    }
    
    private func getCaroptions() -> CarOptions {
        var carOptions = CarOptions()
        carOptions.routeOptions.enableTolls = true
        // This is needed when e.g. requesting TrafficOnRoute data.
        carOptions.routeOptions.enableRouteHandle = true
        
        // Enable usage of HOV and HOT lanes.
        // Note: These lanes will only be used if they are available in the selected country.
        carOptions.allowOptions.allowHov = true
        carOptions.allowOptions.allowHot = true
        
        // In some cities (e.g., Bogotá, Mexico City, Jakarta), the last digit of the
        // license plate is used intentionally to control traffic in low-emission zones.
        // When you calculate a route, the HERE SDK may avoid roads or areas where entry
        // would be restricted based on your individual license plate's last character,
        // for example, on certain week days.
        // Make sure to update this value to the actual last character of your license
        // attached to your vehicle!
        carOptions.lastCharacterOfLicensePlate = "7";

        // When occupantsNumber is greater than 1, it enables the vehicle to use HOV/HOT lanes.
        carOptions.occupantsNumber = 4
        
        // Disabled - Traffic optimization is completely disabled, including long-term road closures. It helps in producing stable routes.
        // Time dependent - Traffic optimization is enabled, the shape of the route will be adjusted according to the traffic situation which depends on departure time and arrival time.
        carOptions.routeOptions.trafficOptimizationMode = disableOptimization ? TrafficOptimizationMode.disabled : TrafficOptimizationMode.timeDependent

        return carOptions
    }
    
    func toggleTrafficOptimization() {
        disableOptimization = !disableOptimization
        if !waypoints.isEmpty {
            calculateRoute(waypoints: waypoints)
        }
    }
    
    private func toString(geoCoordinates: GeoCoordinates) -> String {
        return String(geoCoordinates.latitude) + ", " + String(geoCoordinates.longitude);
    }
    
    private func logRouteSectionDetails(route: Route) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        for (i, sections) in route.sections.enumerated() {
            print("Route Section : " + String(i));
            print("Route Section Departure Time : " + dateFormatter.string(from: sections.departureLocationTime!.localTime));
            print("Route Section Arrival Time : " + dateFormatter.string(from: sections.arrivalLocationTime!.localTime));
            print("Route Section length : " + "\(sections.lengthInMeters)" + " m");
            print("Route Section duration : " + "\(sections.duration)" + " s");
        }
    }
    
    private func logRouteRailwayCrossingDetails(route: Route) {
        for routeRailwayCrossing in route.railwayCrossings {
            // Coordinates of the route offset
            let routeOffsetCoordinates = routeRailwayCrossing.coordinates
            // Index of the corresponding route section. The start of the section indicates the start of the offset.
            let routeOffsetSectionIndex = routeRailwayCrossing.routeOffset.sectionIndex
            // Offset from the start of the specified section to the specified location along the route.
            let routeOffsetInMeters = routeRailwayCrossing.routeOffset.offsetInMeters

            print("A railway crossing of type \(routeRailwayCrossing.type) is situated \(routeOffsetInMeters) meters away from start of section: \(routeOffsetSectionIndex)")
        }

    }

    private func logTollDetails(route: Route) {
        for section in route.sections {
            // The spans that make up the polyline along which tolls are required or
            // where toll booths are located.
            let spans = section.spans
            let tolls = section.tolls
            if !tolls.isEmpty {
                print("Attention: This route may require tolls to be paid.")
            }
            for toll in tolls {
                print("Toll information valid for this list of spans:")
                print("Toll systems: \(toll.tollSystems).")
                print("Toll country code (ISO-3166-1 alpha-3): \(toll.countryCode).")
                print("Toll fare information: ")
                for tollFare in toll.fares {
                    // A list of possible toll fares which may depend on time of day, payment method and
                    // vehicle characteristics. For further details please consult the local
                    // authorities.
                    print("Toll price: \(tollFare.price) \(tollFare.currency).")
                    for paymentMethod in tollFare.paymentMethods {
                        print("Accepted payment methods for this price: \(paymentMethod).")
                    }
                }
            }
        }
    }
    
    private func showRouteDetails(route: Route) {
        // estimatedTravelTimeInSeconds includes traffic delay.
        let estimatedTravelTimeInSeconds = route.duration
        let estimatedTrafficDelayInSeconds = route.trafficDelay
        let lengthInMeters = route.lengthInMeters
        
        // Timezones can vary depending on the device's geographic location.
        // For instance, when calculating a route, the device's current timezone may differ from that of the destination.
        // Consider a scenario where a user calculates a route from Berlin to London — each city operates in a different timezone.
        // To address this, you can display the Estimated Time of Arrival (ETA) in multiple timezones: the device's current timezone (Berlin), the destination's timezone (London), and UTC (Coordinated Universal Time), which serves as a global reference.
        var routeDetails = ""
        routeDetails += "Travel Time (h:m): " + timeUtils.formatTime(sec: estimatedTravelTimeInSeconds)
        routeDetails += "\nTraffic Delay (h:m): " + timeUtils.formatTime(sec: estimatedTrafficDelayInSeconds)
        routeDetails += "\nLength: " + timeUtils.formatLength(meters: lengthInMeters)
        routeDetails += "\nETA in device timezone: " + timeUtils.getETAinDeviceTimeZone(route: route)
        routeDetails += "\nETA in destination timezone: " + timeUtils.getETAinDestinationTimeZone(route: route)
        routeDetails += "\nETA in UTC: " + timeUtils.getEstimatedTimeOfArrivalInUTC(route: route)

        // Add off-road warning.
        if checkIfWaypointsAreOffRoad(route: route) {
            routeDetails += "\n\nNote: At least one waypoint is off-road by more than "
            routeDetails += "\(Int(offroadDistanceThresholdMeters)) meters."
        }

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
            mapPolylineList.append(routeMapPolyline)
        } catch let error {
            fatalError("Failed to render MapPolyline. Cause: \(error)")
        }
        
        // Optionally, render traffic on route.
        // Please note that this is not the recommended way. It is recommeded to display the default traffic polylines adjacent to route polyline.
        showTrafficOnRoute(route)
        
        // Log maneuver instructions per route leg / sections.
        let sections = route.sections
        for section in sections {
            logManeuverInstructions(section: section)
        }
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
    
    func addWaypoints() {
        // Optionally, clear any previous route.
        clearMap()

        guard
            let startGeoCoordinates = startGeoCoordinates,
            let destinationGeoCoordinates = destinationGeoCoordinates else {
            showDialog(title: "Error", message: "Please add a route first.")
            return
        }
        
        let waypoint1GeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        let waypoint2GeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        waypoints = [Waypoint(coordinates: startGeoCoordinates),
                         Waypoint(coordinates: waypoint1GeoCoordinates),
                         Waypoint(coordinates: waypoint2GeoCoordinates),
                         Waypoint(coordinates: destinationGeoCoordinates)]
        
        addMapMarker(geoCoordinates: startGeoCoordinates, imageName: "poi_start.png")
        addMapMarker(geoCoordinates: waypoint1GeoCoordinates, imageName: "waypoint_one.png")
        addMapMarker(geoCoordinates: waypoint2GeoCoordinates, imageName: "waypoint_two.png")
        addMapMarker(geoCoordinates: destinationGeoCoordinates, imageName: "poi_destination.png")
        
        calculateRoute(waypoints: waypoints)
    }

    // A waypoint is considered off-road if its original coordinates (as specified by the user)
    // are more than offroadDistanceThresholdMeters away from the location map-matched to the road network during route calculation.
    // This function ensures that only waypoints explicitly added by the user are evaluated.
    // Automatically generated waypoints are skipped.
    // Returns true if at least one user-defined waypoint is off-road, false otherwise.
    func checkIfWaypointsAreOffRoad(route: Route) -> Bool {
        let sections = route.sections

        for section in sections {
            // Check departure waypoint.
            let departure = section.departurePlace
            if isWaypointOffRoad(place: departure) {
                return true
            }

            // Check arrival waypoint.
            let arrival = section.arrivalPlace
            if isWaypointOffRoad(place: arrival) {
                return true
            }
        }

        return false // All user-defined waypoints are close to the road network
    }

    // Helper method to check if a waypoint is off-road.
    // Compares the original (user-specified) coordinates with the map-matched coordinates.
    // If originalCoordinates is null (e.g., the waypoint was added automatically during routing), it is skipped.
    // Returns true if the waypoint is off-road (more than offroadDistanceThresholdMeters meters away), false otherwise.
    func isWaypointOffRoad(place: RoutePlace) -> Bool {
        guard let originalCoordinates = place.originalCoordinates else {
            // Skip waypoints that were not explicitly defined by the user.
            return false
        }

        let matchedCoordinates = place.mapMatchedCoordinates

        let distance = originalCoordinates.distance(to: matchedCoordinates)

        return distance > offroadDistanceThresholdMeters
    }

    // This renders the traffic jam factor on top of the route as multiple MapPolylines per span.
    private func showTrafficOnRoute(_ route: Route) {
        if route.lengthInMeters / 1000 > 5000 {
            print("Skip showing traffic-on-route for longer routes.");
            return
        }
        
        for section in route.sections {
            for span in section.spans {
                let dynamicSpeedInfo : DynamicSpeedInfo? = span.dynamicSpeedInfo
                guard let lineColor = getTrafficColor(dynamicSpeedInfo?.calculateJamFactor()) else {
                    // Skip rendering low traffic.
                    continue
                }
                let widthInPixels = 10.0
                do {
                    let trafficSpanMapPolyline =  try MapPolyline(geometry: span.geometry,
                                                                  representation: MapPolyline.SolidRepresentation(
                                                                    lineWidth: MapMeasureDependentRenderSize(
                                                                        sizeUnit: RenderSize.Unit.pixels,
                                                                        size: widthInPixels),
                                                                    color: lineColor,
                                                                    capShape: LineCap.round))
                    
                    mapView.mapScene.addMapPolyline(trafficSpanMapPolyline)
                    mapPolylineList.append(trafficSpanMapPolyline)
                } catch let error {
                    fatalError("Failed to render MapPolyline. Cause: \(error)")
                }
            }
        }
    }
    
    // Define a traffic color scheme based on the route's jam factor.
    // 0 <= jamFactor < 4: No or light traffic.
    // 4 <= jamFactor < 8: Moderate or slow traffic.
    // 8 <= jamFactor < 10: Severe traffic.
    // jamFactor = 10: No traffic, ie. the road is blocked.
    // Returns nil in case of no or light traffic.
    private func getTrafficColor(_ jamFactor: Double?) -> UIColor? {
        guard let jamFactor = jamFactor else {
            return nil
        }
        if jamFactor < 4 {
            return nil
        } else if jamFactor >= 4 && jamFactor < 8 {
            return UIColor(red: 1, green: 1, blue: 0, alpha: 0.63) // Yellow
        } else if jamFactor >= 8 && jamFactor < 10 {
            return UIColor(red: 1, green: 0, blue: 0, alpha: 0.63) // Red
        }
        return UIColor(red: 0, green: 0, blue: 0, alpha: 0.63) // Black
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
        currentRoute = nil
        for mapPolyline in mapPolylineList {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylineList.removeAll()
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
    
    private func addMapMarker(geoCoordinates: GeoCoordinates, imageName: String) {
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
