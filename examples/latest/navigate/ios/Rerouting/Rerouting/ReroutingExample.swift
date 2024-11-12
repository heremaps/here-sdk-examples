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
import SwiftUI

// An example that shows how to handle rerouting during guidance alongside.
// The simulated driver will follow the black line showing on the map - this is done with
// a second route that is using additional waypoints. This route is set as
// location source for the LocationSimulator.
// This example also shows a maneuver panel with road shield icons.
class ReroutingExample: LongPressDelegate,
                        RouteProgressDelegate,
                        RouteDeviationDelegate,
                        DestinationReachedDelegate,
                        OffRoadProgressDelegate,
                        OffRoadDestinationReachedDelegate {

    private let mapView: MapView
    private var routingEngine: RoutingEngine
    private var visualNavigator: VisualNavigator
    private let herePositioningSimulator: HEREPositioningSimulator
    private var mapMarkers = [MapMarker]()
    private var mapPolylines = [MapPolyline]()
    private var deviationWaypoints = [Waypoint]()
    private var previousManeuver: Maneuver?
    private var changeDestination = true
    private let iconProvider: IconProvider
    private var lastRoadShieldText = ""
    private var simulationSpeedFactor: Double = 1
    private var lastCalculatedRoute: Route?
    private var lastCalculatedDeviationRoute: Route?
    private var setDeviationPoints = false
    private var isReturningToRoute = false
    private var isGuidance = false
    private var deviationCounter = 0
    
    // The model class to provide data via binding to the ManeuverView.
    private var maneuverModel: ManeuverModel
    
    // A helper class to provide the necessary maneuver icons.
    private var maneuverIconProvider: ManeuverIconProvider!
    
    // A route in Berlin - can be changed via longtap.
    private var startWaypoint = Waypoint(coordinates: GeoCoordinates(latitude: 52.49047222554655, longitude: 13.296884483959285))
    private var destinationWaypoint = Waypoint(coordinates: GeoCoordinates(latitude: 52.51384077118386, longitude: 13.255752692114996))
    // A default deviation point - multiple points can be added via longtap.
    private var defaultDeviationGeoCoordinates: GeoCoordinates?
    
    private var startMapMarker: MapMarker!
    private var destinationMapMarker: MapMarker!
    
    init(_ mapView: MapView, _ maneuverModel: ManeuverModel) {
        self.mapView = mapView
        self.maneuverModel = maneuverModel
               
        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }
        
        do {
            try visualNavigator = VisualNavigator()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize VisualNavigator. Cause: \(engineInstantiationError)")
        }
       
        // For RoadShields icons.
        iconProvider = IconProvider(mapView.mapContext)
        
        // For maneuver icons.
        maneuverIconProvider = ManeuverIconProvider()
        maneuverIconProvider.loadManeuverIcons()
        
        // A class to receive simulated location events.
        herePositioningSimulator = HEREPositioningSimulator()
        
        // Enable off-road visualization (if any) with a dotted straight-line
        // between the map-matched and the original destination (which is off-road).
        // Note that the color of the dashed line can be customized, if desired.
        // The line will not be rendered if the destination is not off-road.
        // By default, this is enabled.
        visualNavigator.isOffRoadDestinationVisible = true
        
        defaultDeviationGeoCoordinates = GeoCoordinates(latitude: 52.4925023888559,
                                                        longitude: 13.296233624033844)

        // Add markers to indicate the currently selected starting point and destination.
        startMapMarker = createMapMarker(geoCoordinates: startWaypoint.coordinates,
                                      imageName: "poi_start.png")
        destinationMapMarker = createMapMarker(geoCoordinates: destinationWaypoint.coordinates,
                                            imageName: "poi_destination.png")

        mapView.mapScene.addMapMarker(startMapMarker)
        mapView.mapScene.addMapMarker(destinationMapMarker)

        // Indicate also the default deviation point - can be changed by the user via longtap.
        let deviationMapMarker = createMapMarker(geoCoordinates: defaultDeviationGeoCoordinates!,
                                              imageName: "poi_deviation.png")
        mapView.mapScene.addMapMarker(deviationMapMarker)
        mapMarkers.append(deviationMapMarker)
        
        mapView.gestures.longPressDelegate = self
        
        visualNavigator.routeProgressDelegate = self
        visualNavigator.routeDeviationDelegate = self
        visualNavigator.destinationReachedDelegate = self
        visualNavigator.offRoadProgressDelegate = self
        visualNavigator.offRoadDestinationReachedDelegate = self
        
        // Center map in Berlin.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 1000 * 90)
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      zoom: distanceInMeters)
       
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
        
        showDialog(title: "Note",
                   message: "Do a long press to change start and destination coordinates.")
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
    }
    
    func onShowRouteButtonClicked() {
        lastCalculatedRoute = nil
        lastCalculatedDeviationRoute = nil

        calculateRouteForUseWithVisualNavigator()
        calculateDeviationRouteForUseLocationSimulator()
    }
    
    private func calculateRouteForUseWithVisualNavigator() {
        var carOptions = CarOptions()
        // A route handle is necessary for rerouting.
        carOptions.routeOptions.enableRouteHandle = true

        let waypoints = getCurrentWaypoints(insertDeviationWaypoints: false)
                
        routingEngine.calculateRoute(with: waypoints,
                                     carOptions: carOptions) { (routingError, routes) in
            self.handleRouteResults(routingError, routes)
        }
    }

    private func calculateDeviationRouteForUseLocationSimulator() {
        guard !deviationWaypoints.isEmpty || defaultDeviationGeoCoordinates != nil else {
            // No deviation waypoints have been set by the user.
            return
        }

        // Use deviationWaypoints to create a second route and set it as the source for LocationSimulator.
        let waypoints = getCurrentWaypoints(insertDeviationWaypoints: true)

        routingEngine.calculateRoute(with: waypoints,
                                     carOptions: CarOptions()) { (routingError, routes) in
            self.handleDeviationRouteResults(routingError, routes)
        }
    }
   
    func onStartStopButtonClicked() {
        guard let lastCalculatedRoute = lastCalculatedRoute else {
            showDialog(title: "Note", message: "Show a route first.")
            return
        }

        isGuidance = !isGuidance
        if isGuidance {
            startGuidance(lastCalculatedRoute)
        } else {
            stopGuidance()
        }
    }

    private func startGuidance(_ route: Route) {
        visualNavigator.route = route
        visualNavigator.startRendering(mapView: mapView)

        // If we do not have a deviation route set for testing, we simply follow the route.
        let sourceForLocationSimulation = lastCalculatedDeviationRoute ?? route

        // Note that we provide location updates based on the route that deviates from the original route,
        // based on the set deviation waypoints by the user (if provided).
        // Note: This is for testing purposes only.
        herePositioningSimulator.setSpeedFactor(simulationSpeedFactor)
        herePositioningSimulator.startLocating(locationDelegate: visualNavigator,
                                               route: sourceForLocationSimulation)
    }
    
    private func stopGuidance() {
        visualNavigator.route = nil
        previousManeuver = nil
        visualNavigator.stopRendering()
        herePositioningSimulator.stopLocating()
        onHideManeuverPanel()
        untiltUnrotateMap()
    }
    
    private func untiltUnrotateMap() {
        let cameraOrientation = GeoOrientationUpdate(bearing: 0, tilt: 0)
        mapView.camera.setOrientationAtTarget(cameraOrientation)
    }

    func onSpeedButtonClicked() {
        // Toggle simulation speed factor.
        if simulationSpeedFactor == 1 {
            simulationSpeedFactor = 8
        } else {
            simulationSpeedFactor = 1
        }

        showDialog(title: "Note",
                   message: "Changed simulation speed factor to \(simulationSpeedFactor)."
                   + " Start again to use the new value.");
    }
    
    private func handleRouteResults(_ routingError: RoutingError?, _ routes: [Route]?) {
        if let routingError = routingError {
            showDialog(title: "Error while calculating a route:",
                       message: "Error code: \(routingError.rawValue)")
            return
        }

        // Reset previous text, if any.
        lastRoadShieldText = ""

        // When routingError is nil, routes is guaranteed to contain at least one route.
        lastCalculatedRoute = routes![0]

        let routeColor = UIColor(red: 0, green: 0.6, blue: 1, alpha: 1)
        let routeWidthInPixels: Double = 30
        showRouteOnMap(route: lastCalculatedRoute!,
                       color: routeColor,
                       widthInPixels: routeWidthInPixels)
    }

    private func handleDeviationRouteResults(_ routingError: RoutingError?, _ routes: [Route]?) {
        if let routingError = routingError {
            showDialog(title: "Error while calculating a route:",
                       message: "Error code: \(routingError.rawValue)")
            return
        }

        // When routingError is nil, routes is guaranteed to contain at least one route.
        lastCalculatedDeviationRoute = routes![0]

        let blackColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        let routeWidthInPixels: Double = 15
        showRouteOnMap(route: lastCalculatedDeviationRoute!,
                       color: blackColor,
                       widthInPixels: routeWidthInPixels)
    }
    
    private func showRouteOnMap(route: Route, color: UIColor, widthInPixels: Double) {
        let routeGeoPolyline = route.geometry
        
        do {
            let routeMapPolyline =  try MapPolyline(geometry: routeGeoPolyline,
                                                    representation: MapPolyline.SolidRepresentation(
                                                        lineWidth: MapMeasureDependentRenderSize(
                                                            sizeUnit: RenderSize.Unit.pixels,
                                                            size: widthInPixels),
                                                        color: color,
                                                        capShape: LineCap.round))
            
            mapView.mapScene.addMapPolyline(routeMapPolyline)
            mapPolylines.append(routeMapPolyline)
        } catch let error {
            fatalError("Failed to render MapPolyline. Cause: \(error)")
        }
        
        animateToRoute(route: route)
    }
    
    func onClearMapButtonClicked() {
        clearRoute()
        clearMapMarker()
        deviationWaypoints.removeAll()
        // Clear also the default deviation waypoint.
        defaultDeviationGeoCoordinates = nil
    }
    
    private func clearRoute() {
        for mapPolyline in mapPolylines {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylines.removeAll()
    }

    private func clearMapMarker() {
        for mapMarker in mapMarkers {
            mapView.mapScene.removeMapMarker(mapMarker)
        }
        mapMarkers.removeAll()
    }
    
    func onDeviationPointsButtonClicked() {
        setDeviationPoints = !setDeviationPoints
        if setDeviationPoints {
            showDialog(title: "Note",
                       message: "Set deviation waypoints now. " +
                    "These points will become stopovers to shape the route that is used for location simulation." +
                    "The original (blue) route will be kept as before for use with the VisualNavigator." +
                    "Click button again to stop setting deviation waypoints.")
        } else {
            showDialog(title: "Note",
                       message: "Stopped setting deviation waypoints.")
        }
    }
    
    // Conform to RouteProgressDelegate.
    func onRouteProgressUpdated(_ routeProgress: heresdk.RouteProgress) {
        let maneuverProgressList = routeProgress.maneuverProgress
        guard let nextManeuverProgress = maneuverProgressList.first else {
            print("No next maneuver available.")
            return
        }
        
        let maneuverDescription = parseManeuver(nextManeuverProgress)
        print("Next maneuver: \(maneuverDescription)")
        
        let nextManeuverIndex = nextManeuverProgress.maneuverIndex
        let nextManeuver = visualNavigator.getManeuver(index: nextManeuverIndex)
        
        if previousManeuver == nextManeuver {
            // We are still trying to reach the next maneuver.
            return;
        }
        previousManeuver = nextManeuver;
        
        // A new maneuver takes places. Hide the existing road shield icon, if any.
        onHideRoadShieldIcon()
        
        guard let maneuverSpan = getSpanForManeuver(route: visualNavigator.route!,
                                                    maneuver: nextManeuver!) else {
            return
        }
        createRoadShieldIconForSpan(maneuverSpan)
    }
    
    // Conform to RouteDeviationDelegate.
    // Notifies on a possible deviation from the route.
    func onRouteDeviation(_ routeDeviation: heresdk.RouteDeviation) {
        guard let route = visualNavigator.route else {
            // May happen in rare cases when route was set to nil inbetween.
            return;
        }
        
        // Get current geographic coordinates.
        var currentGeoCoordinates = routeDeviation.currentLocation.originalLocation.coordinates
        let currentMapMatchedLocation = routeDeviation.currentLocation.mapMatchedLocation
        if let currentMapMatchedLocation = currentMapMatchedLocation {
            currentGeoCoordinates = currentMapMatchedLocation.coordinates
        }

        // Get last geographic coordinates on route.
        var lastGeoCoordinates: GeoCoordinates?
        if let lastLocationOnRoute = routeDeviation.lastLocationOnRoute {
            lastGeoCoordinates = lastLocationOnRoute.originalLocation.coordinates
            if let lastMapMatchedLocationOnRoute = lastLocationOnRoute.mapMatchedLocation {
                lastGeoCoordinates = lastMapMatchedLocationOnRoute.coordinates
            }
        } else {
            print("User was never following the route. So, we take the start of the route instead.")
            lastGeoCoordinates = route.sections.first?.departurePlace.originalCoordinates
        }

        guard let lastGeoCoordinatesOnRoute = lastGeoCoordinates else {
            print("No lastGeoCoordinatesOnRoute found. Should never happen.")
            return
        }

        let distanceInMeters = currentGeoCoordinates.distance(to: lastGeoCoordinatesOnRoute)
        print("RouteDeviation in meters is \(distanceInMeters)")
        
        // Decide if rerouting should happen and if yes, then return to the original route.
        handleRerouting(routeDeviation: routeDeviation,
                        distanceInMeters: Int(distanceInMeters),
                        currentGeoCoordinates: currentGeoCoordinates,
                        currentMapMatchedLocation: currentMapMatchedLocation)
    }
    
    // Conform to DestinationReachedDelegate.
    // Notifies when the destination of the route is reached.
    func onDestinationReached() {
        guard let lastSection = lastCalculatedRoute?.sections.last else {
            // A new route is calculated, drop out.
            return
        }
        if lastSection.arrivalPlace.isOffRoad() {
            print("End of navigable route reached.")
            let message1 = "Your destination is off-road."
            let message2 = "Follow the dashed line with caution."            
            onManeuverEvent(action: ManeuverAction.arrive,
                            message1: message1,
                            message2: message2)
        } else {
            print("Destination reached.")
            let distanceText = "0 m"
            let message = "You have reached your destination."
            onManeuverEvent(action: ManeuverAction.arrive,
                            message1: distanceText,
                            message2: message)
        }
    }
    
    // Conform to OffRoadProgressDelegate.
    // Notifies on the progress when heading towards an off-road destination.
    // Off-road progress events will be sent only after the user has reached
    // the map-matched destination and the original destination is off-road.
    // Note that when a location cannot be map-matched to a road, then it is considered
    // to be off-road.
    func onOffRoadProgressUpdated(_ offRoadProgress: heresdk.OffRoadProgress) {
        let distanceText = convertDistance(meters: offRoadProgress.remainingDistanceInMeters)
        // Bearing of the destination compared to the user's current position.
        // The bearing angle indicates the direction into which the user should walk in order
        // to reach the off-road destination - when the device is held up in north-up direction.
        // For example, when the top of the screen points to true north, then 180° means that
        // the destination lies in south direction. 315° would mean the user has to head north-west, and so on.
        let message = "Direction of your destination: \(round(offRoadProgress.bearingInDegrees))°"
        onManeuverEvent(action: ManeuverAction.arrive,
                        message1: distanceText,
                        message2: message)
    }
    
    // Conform to OffRoadDestinationReachedDelegate.
    // Notifies when the off-road destination of the route has been reached (if any).
    func onOffRoadDestinationReached() {
        print("Off-road destination reached.")
        let distanceText = "0 m"
        let message = "You have reached your off-road destination."
        onManeuverEvent(action: ManeuverAction.arrive,
                        message1: distanceText,
                        message2: message)
    }
    
    // For more warners and events during guidance, please check the Navigation example app, available on GitHub.
    
    func handleRerouting(routeDeviation: RouteDeviation,
                         distanceInMeters: Int,
                         currentGeoCoordinates: GeoCoordinates,
                         currentMapMatchedLocation: MapMatchedLocation?) {
        // Counts the number of received deviation events. When the user is following a route, no deviation
        // event will occur.
        // It is recommended to await at least 3 deviation events before deciding on an action.
        deviationCounter += 1

        if isReturningToRoute {
            // Rerouting is ongoing.
            print("Rerouting is ongoing ...")
            return
        }

        // When the user has deviated more than distanceThresholdInMeters. Now we try to return to the original route.
        let distanceThresholdInMeters: Int = 50
        if distanceInMeters > distanceThresholdInMeters && deviationCounter >= 3 {
            isReturningToRoute = true

            // Use current location as the new starting point for the route.
            var newStartingPoint = Waypoint(coordinates: currentGeoCoordinates)

            // Improve the route calculation by setting the heading direction.
            if let bearingInDegrees = currentMapMatchedLocation?.bearingInDegrees {
                newStartingPoint.headingInDegrees = bearingInDegrees
            }

            guard let lastCalculatedRoute = lastCalculatedRoute else {
                //
                return
            }
            
            // In general, the return.to-route algorithm will try to find the fastest way back to the original route,
            // but it will also respect the distance to the destination. The new route will try to preserve the shape
            // of the original route if possible, and it will use the same route options.
            // When the user can now reach the destination faster than with the previously chosen route, a completely new
            // route is calculated.
            print("Rerouting: Calculating a new route.")
            routingEngine.returnToRoute(lastCalculatedRoute,
                                        startingPoint: newStartingPoint,
                                        lastTraveledSectionIndex: routeDeviation.lastTraveledSectionIndex,
                                        traveledDistanceOnLastSectionInMeters: routeDeviation.traveledDistanceOnLastSectionInMeters,
                                        completion: onReroutingCompleted)
        }
    }

    // Handle completetion results from calling returnToRoute().
    private func onReroutingCompleted(routingError: RoutingError?, list: [Route]?) {
        // For simplicity, we use the same route handling.
        // The previous route will still be visible on the map for reference.
        handleRouteResults(routingError, list)
        // Instruct the navigator to follow the calculated route (which will be the new one if no error occurred).
        visualNavigator.route = lastCalculatedRoute
        // Reset flag and counter.
        isReturningToRoute = false
        deviationCounter = 0
        print("Rerouting: New route set.")
    }
    
    private func parseManeuver(_ maneuverProgress: ManeuverProgress) -> String {
        let nextManeuverIndex = maneuverProgress.maneuverIndex
        guard let nextManeuver = visualNavigator.getManeuver(index: nextManeuverIndex) else {
            // Should never happen.
            return "Error: No next maneuver."
        }

        let action = nextManeuver.action
        let roadName = getRoadName(maneuver: nextManeuver)
        let distanceText = convertDistance(meters: maneuverProgress.remainingDistanceInMeters)
        let maneuverText = "Action: \(String(describing: action)) on \(roadName) in \(distanceText)"

        // Notify UI to show the next maneuver data.
        onManeuverEvent(action: action,
                        message1: distanceText,
                        message2: roadName)
        return maneuverText
    }

    private func convertDistance(meters: Int32) -> String {
        let meters = Double(meters)
        
        if meters < 1000 {
            // Convert meters to meters.
            let roundedMeters = Int(round(meters))
            return "\(roundedMeters) m"
        } else if meters >= 1000 && meters <= 20000 {
            // Convert meters to kilometers with one digit rounded.
            let kilometers = meters / 1000
            let roundedKilometers = roundToDigits(kilometers, digits: 1)
            return "\(roundedKilometers) km"
        } else {
            // Convert meters to kilometers rounded without comma.
            let kilometers = Int(round(meters / 1000))
            return "\(kilometers) km"
        }
    }

    private func roundToDigits(_ value: Double, digits: Int) -> Double {
        let divisor = pow(10.0, Double(digits))
        return (value * divisor).rounded() / divisor
    }

    private func getRoadName(maneuver: Maneuver) -> String {
        let currentRoadTexts = maneuver.roadTexts
        let nextRoadTexts = maneuver.nextRoadTexts

        let currentRoadName = currentRoadTexts.names.defaultValue()
        let currentRoadNumber = currentRoadTexts.numbersWithDirection.defaultValue()
        let nextRoadName = nextRoadTexts.names.defaultValue()
        let nextRoadNumber = nextRoadTexts.numbersWithDirection.defaultValue()

        var roadName = nextRoadName == nil ? nextRoadNumber : nextRoadName

        // On highways, we want to show the highway number instead of a possible road name,
        // while for inner city and urban areas road names are preferred over road numbers.
        if maneuver.nextRoadType == RoadType.highway {
            roadName = nextRoadNumber == nil ? nextRoadName : nextRoadNumber
        }

        if maneuver.action == ManeuverAction.arrive {
            // We are approaching destination, so there's no next road.
            roadName = currentRoadName == nil ? currentRoadNumber : currentRoadName
        }

        // Nil happens only in rare cases, when also the fallback above is nil.
        return roadName ?? "unnamed road"
    }

    private func getSpanForManeuver(route: Route, maneuver: Maneuver) -> Span? {
        let index = Int(maneuver.sectionIndex)
        let sectionOfManeuver = route.sections[index]
        let spansInSection = sectionOfManeuver.spans

        // The last maneuver is located on the last span.
        // Note: Its offset points to the last GeoCoordinates of the route's polyline:
        // maneuver.offset = sectionOfManeuver.geometry.vertices.last.
        if maneuver.action == ManeuverAction.arrive {
            return spansInSection.last
        }

        let indexOfManeuverInSection = maneuver.offset
        for span in spansInSection {
            // A maneuver always lies on the first point of a span. Except for the
            // the destination that is located somewhere on the last span (see above).
            let firstIndexOfSpanInSection = span.sectionPolylineOffset
            if firstIndexOfSpanInSection >= indexOfManeuverInSection {
                return span
            }
        }

        // Should never happen.
        return nil
    }

    private func createRoadShieldIconForSpan(_ span: Span) {
        guard !span.roadNumbers.items.isEmpty else {
            // Road shields are only provided for roads that have route numbers such as US-101 or A100.
            // Many streets in a city like "Invalidenstr." have no route number.
            return
        }

        // For simplicity, we use the 1st item as fallback. There can be more numbers you can pick per desired language.
        guard var localizedRoadNumber = span.roadNumbers.items.first else {
            // First time should not be nil when list is not empty.
            return
        }

        // Desired locale identifier for the road shield text.
        let desiredLocale = Locale(identifier: "en_US")
        for roadNumber in span.roadNumbers.items {
            if roadNumber.localizedNumber.locale == desiredLocale {
                localizedRoadNumber = roadNumber
                break
            }
        }

        // The route type indicates if this is a major road or not.
        let routeType = localizedRoadNumber.routeType
        // The text that should be shown on the road shield.
        let shieldText = span.getShieldText(roadNumber: localizedRoadNumber)
        // This text is used to additionally determine the road shield's visuals.
        let routeNumberName = localizedRoadNumber.localizedNumber.text

        if lastRoadShieldText == shieldText {
            // It looks like this shield was already created before, so we opt out.
            return
        }

        lastRoadShieldText = shieldText

        // Most icons can be created even if some properties are empty.
        // If countryCode is empty, then this will result in an IconProviderError.ICON_NOT_FOUND. Practically,
        // the country code should never be null, unless when there is a very rare data issue.
        let countryCode = span.countryCode ?? ""
        let stateCode = span.countryCode ?? ""

        let roadShieldIconProperties = RoadShieldIconProperties(
            routeType: routeType,
            countryCode: countryCode,
            stateCode: stateCode,
            routeNumberName: routeNumberName,
            shieldText: shieldText
        )

        // Set the desired default constraints. The icon will fit in while preserving its aspect ratio.
        let widthConstraintInPixels: UInt32 = 100
        let heightConstraintInPixels: UInt32 = 100

        // Create the icon offline. Several icons could be created in parallel, but in reality, the road shield
        // will not change very quickly, so that a previous icon will not be overwritten by a parallel call.
        iconProvider.createRoadShieldIcon(properties: roadShieldIconProperties,
                                          mapScheme: MapScheme.normalDay,
                                          widthConstraintInPixels: widthConstraintInPixels,
                                          heightConstraintInPixels: heightConstraintInPixels,
                                          callback: handleIconProviderCallback)
    }

    private func handleIconProviderCallback(image: UIImage?,
                                            description: String?,
                                            error: IconProviderError?) {
        if let iconProviderError = error {
            print("Cannot create road shield icon: \(iconProviderError.rawValue)")
            return
        }

        // If iconProviderError is nil, it is guaranteed that bitmap and description are not nil.
        guard let roadShieldIcon = image else {
            return
        }

        // A further description of the generated icon, such as "Federal" or "Autobahn".
        let shieldDescription = description ?? ""
        print("New road shield icon: \(shieldDescription)")

        // An implementation can now decide to show the icon, for example, together with the
        // next maneuver actions.
        onRoadShieldEvent(roadShieldIcon: roadShieldIcon)
    }

    // Conform to the LongPressDelegate protocol.
    // Use a LongPress handler to define start / destination waypoints.
    func onLongPress(state: heresdk.GestureState, origin: Point2D) {
        if state != .begin {
            return;
        }

        guard let geoCoordinates =
                mapView.viewToGeoCoordinates(viewCoordinates: origin) else {
            showDialog(title: "Note",
                       message: "No geo coordinates, maybe you tapped the horizon?")
            return
        }

        
        if (setDeviationPoints) {
            defaultDeviationGeoCoordinates = nil
            let mapMarker = createMapMarker(geoCoordinates: geoCoordinates,
                                         imageName: "poi_deviation.png")
            mapView.mapScene.addMapMarker(mapMarker)
            mapMarkers.append(mapMarker)
            deviationWaypoints.append(Waypoint(coordinates: geoCoordinates))
        } else {
            // Set new route start or destination geographic coordinates based on long press location.
            if (changeDestination) {
                destinationWaypoint = Waypoint(coordinates: geoCoordinates)
                destinationMapMarker.coordinates = geoCoordinates
            } else {
                startWaypoint = Waypoint(coordinates: geoCoordinates)
                startMapMarker.coordinates = geoCoordinates
            }
            
            // Toggle the marker that should be updated on next long press.
            changeDestination = !changeDestination;
        }
    }

    // Get the waypoint list using the last two long press points and optional deviation waypoints.
    private func getCurrentWaypoints(insertDeviationWaypoints: Bool) -> [Waypoint] {
        var waypoints: [Waypoint] = []

        if insertDeviationWaypoints {
            waypoints.append(startWaypoint)
            // If no custom deviation waypoints have been set, we use initially the default one.
            if let defaultDeviationGeoCoordinates = defaultDeviationGeoCoordinates {
                waypoints.append(Waypoint(coordinates: defaultDeviationGeoCoordinates))
            }
            waypoints += deviationWaypoints
            waypoints.append(destinationWaypoint)
        } else {
            waypoints = [startWaypoint, destinationWaypoint]
        }

        // Log used waypoints for reference.
        print("Start Waypoint: \(startWaypoint.coordinates.latitude), \(startWaypoint.coordinates.longitude)")
        for wp in deviationWaypoints {
            print("Deviation Waypoint: \(wp.coordinates.latitude), \(wp.coordinates.longitude)")
        }
        print("Destination Waypoint: \(destinationWaypoint.coordinates.latitude), \(destinationWaypoint.coordinates.longitude)")

        return waypoints
    }

    private func animateToRoute(route: Route) {
        // Untilt and unrotate the map.
        let bearing: Double = 0
        let tilt: Double = 0
        
        // We want to show the route fitting in the map view with an additional padding of 50 pixels.
        let origin:Point2D = Point2D(x: 50.0, y: 50.0)
        let sizeInPixels:Size2D = Size2D(width: mapView.viewportSize.width - 100, height: mapView.viewportSize.height - 100)
        let mapViewport:Rectangle2D = Rectangle2D(origin: origin, size: sizeInPixels)

        // Animate to the route within a duration of 3 seconds.
        let update:MapCameraUpdate = MapCameraUpdateFactory.lookAt(area: route.boundingBox, orientation: GeoOrientationUpdate(GeoOrientation(bearing: bearing, tilt: tilt)), viewRectangle: mapViewport)
        let animation: MapCameraAnimation = MapCameraAnimationFactory.createAnimation(from: update, duration: TimeInterval(3), easing: Easing(EasingFunction.inCubic))
        mapView.camera.startAnimation(animation)
    }
    
    private func createMapMarker(geoCoordinates: GeoCoordinates, imageName: String) -> MapMarker {
        guard
            let image = UIImage(named: imageName),
            let imageData = image.pngData() else {
            fatalError("Failed to find image: \(imageName)")
        }
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png))
        return mapMarker
    }

    // Update the maneuver view via data binding.
    private func onManeuverEvent(action: ManeuverAction, message1: String, message2: String) {
        maneuverModel.isManeuverPanelVisible = true
        maneuverModel.distanceText = message1
        maneuverModel.maneuverText = message2
        maneuverModel.maneuverIcon = maneuverIconProvider.getManeuverIconForAction(action)
    }
    
    // Update the maneuver view via data binding.
    func onRoadShieldEvent(roadShieldIcon: UIImage) {
        maneuverModel.roadShieldImage = roadShieldIcon
    }

    // Update the maneuver view via data binding.
    func onHideRoadShieldIcon() {
        maneuverModel.roadShieldImage = nil
    }

    // Update the maneuver view via data binding.
    func onHideManeuverPanel() {
        maneuverModel.isManeuverPanelVisible = false
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
