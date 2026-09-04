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

import heresdk
import UIKit

/// Handles indoor routing: calculates routes between two indoor waypoints and renders them on the map.
public class IndoorRoutingHandler: ObservableObject {
    private weak var venueService: VenueService?
    private weak var venueMap: VenueMap?
    private weak var mapView: MapView?

    private var routingEngine: IndoorRoutingEngine?
    private var routingController: IndoorRoutingController?
    private var routeOptions: IndoorRouteOptions = IndoorRouteOptions(
        routeOptions: RouteOptions(),
        transportMode: .pedestrian,
        indoorAvoidanceOptions: IndoorAvoidanceOptions(),
        speedInMetersPerSecond: 1.0)
    private var routeStyle: IndoorRouteStyle = IndoorRouteStyle()

    @Published var isCalculatingRoute = false
    @Published var routeError: String?

    /// Incremented each time a route request starts; checked in the callback to discard stale results.
    private var routeRequestId: Int = 0

    public func setup(_ venueEngine: VenueEngine?, mapView: MapView?) {
        self.mapView = mapView
        if let venueService = venueEngine?.venueService {
            self.venueService = venueService
        }
        if let venueMap = venueEngine?.venueMap {
            self.venueMap = venueMap
        }
        initRouting()
    }

    private func initRouting() {
        guard let venueMap = venueMap,
              let venueService = venueService,
              let mapView = mapView else { return }

        routingEngine = IndoorRoutingEngine(_: venueService)
        routingController = IndoorRoutingController(_: venueMap, mapView: mapView)

        let middleBottomAnchor = Anchor2D(horizontal: 0.5, vertical: 1.0)
        routeStyle.startMarker = initMapMarker(name: "indoor_route_start", anchor: Anchor2D(horizontal: 0.5, vertical: 0.5))
        routeStyle.destinationMarker = initMapMarker(name: "ic_route_end", anchor: middleBottomAnchor)
        routeStyle.walkMarker = initMapMarker(name: "indoor_walk")
        routeStyle.driveMarker = initMapMarker(name: "indoor_drive")

        let features: [IndoorLevelChangeFeatures] = [.stairs, .elevator, .escalator, .ramp]
        for feature in features {
            let featureString = toFeatureString(feature: feature)
            let marker = initMapMarker(name: "indoor_" + featureString)
            let upMarker = initMapMarker(name: "indoor_" + featureString + "_up")
            let downMarker = initMapMarker(name: "indoor_" + featureString + "_down")
            routeStyle.setIndoorMarkersFor(
                feature: feature, upMarker: upMarker, downMarker: downMarker, exitMarker: marker)
        }
    }

    private func initMapMarker(name: String, anchor: Anchor2D = Anchor2D(horizontal: 0.5, vertical: 0.5)) -> MapMarker? {
        if let image = UIImage(named: name), let pngData = image.pngData() {
            let markerImage = MapImage(pixelData: pngData, imageFormat: .png)
            return MapMarker(at: GeoCoordinates(latitude: 0.0, longitude: 0.0), image: markerImage, anchor: anchor)
        }
        return nil
    }

    private func toFeatureString(feature: IndoorLevelChangeFeatures) -> String {
        switch feature {
        case .elevator:
            return "elevator"
        case .escalator:
            return "escalator"
        case .stairs:
            return "stairs"
        case .ramp:
            return "ramp"
        case .pedestrianRamp:
            return "pedestrianRamp"
        case .driveRamp:
            return "driveRamp"
        case .carLift:
            return "carLift"
        case .elevatorBank:
            return "elevatorBank"
        case .connector:
            return "connector"
        @unknown default:
            return "connector"
        }
    }

    /// Calculate and display a route between source and destination geometries.
    /// - Parameters:
    ///   - source: The source geometry (used for venue/level info)
    ///   - destination: The destination geometry (used for venue/level info)
    ///   - sourceCoordinates: Optional exact coordinates for source. If nil, uses source.center.
    ///   - destinationCoordinates: Optional exact coordinates for destination. If nil, uses destination.center.
    public func startRouting(source: VenueGeometry, destination: VenueGeometry,
                             sourceCoordinates: GeoCoordinates? = nil,
                             destinationCoordinates: GeoCoordinates? = nil) {
        let sourceVenueModel = source.level.drawing.venueModel
        let destinationVenueModel = destination.level.drawing.venueModel
        let sourceLevel = source.level
        let destinationLevel = destination.level

        let departure = IndoorWaypoint(
            coordinates: sourceCoordinates ?? source.center,
            venueId: sourceVenueModel.identifier,
            levelId: sourceLevel.identifier)
        let arrival = IndoorWaypoint(
            coordinates: destinationCoordinates ?? destination.center,
            venueId: destinationVenueModel.identifier,
            levelId: destinationLevel.identifier)

        isCalculatingRoute = true
        routeError = nil

        guard let routingEngine = routingEngine else {
            isCalculatingRoute = false
            routeError = "Routing engine not initialized"
            return
        }

        routeRequestId += 1
        let currentRequestId = routeRequestId

        routingEngine.calculateRoute(from: departure, to: arrival, routeOptions: routeOptions) { [weak self] (error: IndoorRoutingError?, routes: [Route]?, notices: [IndoorRouteNotice]?) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Discard result if a newer request was made or routing was stopped
                guard currentRequestId == self.routeRequestId else { return }

                self.isCalculatingRoute = false
                self.routingController?.hideRoute()

                // 1. If error, show error and return
                if let error = error {
                    self.routeError = self.errorMessage(for: error)
                    return
                }

                // 2. If routeNotices exist and not empty, show the first one
                if let notices = notices, !notices.isEmpty {
                    let firstNotice = notices[0]
                    self.routeError = firstNotice.title.isEmpty ? self.noticeCodeMessage(for: firstNotice.code) : firstNotice.title
                }

                // 3. If routes exist, show the route
                if let routes = routes, let firstRoute = routes.first {
                    self.routingController?.showRoute(route: firstRoute, style: self.routeStyle)
                }
            }
        }
    }

    /// Hide the currently displayed route.
    public func stopRouting() {
        routeRequestId += 1
        isCalculatingRoute = false
        routingController?.hideRoute()
        routeError = nil
    }

    private func errorMessage(for error: IndoorRoutingError?) -> String {
        guard let error = error else { return "Unknown Error encountered" }
        switch error {
        case .noNetwork:
            return "The device has no internet connectivity"
        case .badRequest:
            return "A bad request was made"
        case .unauthorizedAccess:
            return "You don't have access to routing service"
        case .forbidden:
            return "Cannot serve this route"
        case .notFound:
            return "Resource not found"
        case .tooManyRequests:
            return "Too many requests received by service"
        case .internalServerError:
            return "Internal server error"
        case .badGateway:
            return "Bad gateway"
        case .serviceUnavailable:
            return "Routing service is currently unavailable"
        case .noRouteFound:
            return "No route found between selected waypoints"
        case .couldNotMatchOrigin:
            return "Origin could not be matched"
        case .couldNotMatchDestination:
            return "Destination could not be matched"
        case .mapNotFound:
            return "Requested map not found"
        case .parsingError:
            return "Routing response not in correct format"
        case .unknownError:
            return "Unknown Error encountered"
        default:
            return "Unknown Error encountered"
        }
    }

    private func noticeCodeMessage(for code: IndoorRouteNoticeCode) -> String {
        switch code {
        case .noRouteFound:
            return "No route found between selected waypoints"
        case .couldNotMatchOrigin:
            return "Origin could not be matched"
        case .couldNotMatchDestination:
            return "Destination could not be matched"
        case .violatedRouteHeadCondition:
            return "Route head condition violated"
        case .violatedRouteTailCondition:
            return "Route tail condition violated"
        case .violatedEntireRouteCondition:
            return "Entire route condition violated"
        case .ignoredVehicleEnable:
            return "Vehicle enable setting was ignored"
        case .ignoredVehicleSpeed:
            return "Vehicle speed setting was ignored"
        case .ignoredVehicleAvoidFeatures:
            return "Vehicle avoid features setting was ignored"
        case .violatedTransportMode:
            return "Transport mode was violated"
        case .couldNotMatchWaypoint:
            return "Waypoint could not be matched"
        case .noRouteFoundWithWaypoint:
            return "No route found with the given waypoint"
        @unknown default:
            return "Route notice encountered"
        }
    }
}
