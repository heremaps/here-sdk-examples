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

public class IndoorRoutingHandler {
    private weak var venueService: VenueService?
    private weak var venueMap: VenueMap?
    private weak var mapView: MapView?
    private var routingEngine: IndoorRoutingEngine?
    private var routingController: IndoorRoutingController?
    private var departure: IndoorWaypoint?
    private var arrival: IndoorWaypoint?
    private var routeOptions: IndoorRouteOptions = IndoorRouteOptions()
    private var routeStyle: IndoorRouteStyle = IndoorRouteStyle()
    private var errorBanner = IndoorMap.BannerViewController()
    weak var viewController: ViewController?
    
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
    
    private func initRouting() {
        if let venueMap = venueMap, let venueService = venueService, let mapView = mapView {
            routingEngine = IndoorRoutingEngine(_: venueService)
            routingController = IndoorRoutingController(_: venueMap, mapView: mapView)
            let middleBottomAnchor = Anchor2D(horizontal: 0.5, vertical: 1.0)
            routeStyle.startMarker = initMapMarker(name: "indoor_route_start", anchor: Anchor2D(horizontal: 0.5, vertical: 0.5))
            routeStyle.destinationMarker = initMapMarker(name: "ic_route_end", anchor: middleBottomAnchor)
            routeStyle.walkMarker = initMapMarker(name: "indoor_walk")
            routeStyle.driveMarker = initMapMarker(name: "indoor_drive")
            let features = [IndoorLevelChangeFeatures.stairs, IndoorLevelChangeFeatures.elevator, IndoorLevelChangeFeatures.escalator, IndoorLevelChangeFeatures.ramp]
            for feature in features {
                let featureString = toFeatureString(feature: feature)
                let marker = initMapMarker(name: "indoor_" + featureString)
                let upMarker = initMapMarker(name: "indoor_" + featureString + "_up")
                let downMarker = initMapMarker(name: "indoor_" + featureString + "_down")
                routeStyle.setIndoorMarkersFor(
                    feature: feature, upMarker: upMarker, downMarker: downMarker, exitMarker: marker)
            }
        }
    }
    
    private func toIndoorFeature(_ tag: Int) -> IndoorLevelChangeFeatures {
        switch tag {
        case 0:
            return IndoorLevelChangeFeatures.elevator
        case 1:
            return IndoorLevelChangeFeatures.escalator
        case 2:
            return IndoorLevelChangeFeatures.stairs
        case 3:
            return IndoorLevelChangeFeatures.ramp
        case 4:
            return IndoorLevelChangeFeatures.driveRamp
        case 5:
            return IndoorLevelChangeFeatures.carLift
        case 6:
            return IndoorLevelChangeFeatures.elevatorBank
        default:
            return IndoorLevelChangeFeatures.connector
        }
    }

    public func startRouting(source: heresdk.VenueGeometry, destination: heresdk.VenueGeometry) {
        let sourceVenueModel = source.level.drawing.venueModel
        let destinationVenueModel = destination.level.drawing.venueModel
        let sourceLevel = source.level
        let destinationLevel = destination.level
        departure = IndoorWaypoint(coordinates: source.center, venueId: sourceVenueModel.identifier, levelId: sourceLevel.identifier)
        arrival = IndoorWaypoint(coordinates: destination.center, venueId: destinationVenueModel.identifier, levelId: destinationLevel.identifier)
        viewController?.spinnerView.isHidden = false
        viewController?.startRotation()
        
        routingEngine?.calculateRoute(from: departure!, to: arrival!, routeOptions: routeOptions) { error, routes in
            if error == nil, let routes = routes {
                self.routingController?.showRoute(route: routes[0], style: self.routeStyle)
                self.viewController?.spinnerView.isHidden = true
                self.viewController?.stopRotation()
            } else {
                self.viewController?.spinnerView.isHidden = true
                self.viewController?.stopRotation()
                self.routingController?.hideRoute()
                var errorMessage: String
                switch error {
                case .noNetwork:
                    errorMessage = "The device has no internet connectivity"
                case .badRequest:
                    errorMessage = "A bad request was made"
                case .unauthorizedAccess:
                    errorMessage = "You don't have access to routing service"
                case .forbidden:
                    errorMessage = "Cannot serve this route"
                case .notFound:
                    errorMessage = "Resource not found"
                case .tooManyRequests:
                    errorMessage = "Too many request received by service"
                case .internalServerError:
                    errorMessage = "Internal server error"
                case .badGateway:
                    errorMessage = "Bad gateway"
                case .serviceUnavailable:
                    errorMessage = "Routing service is currently unavailable"
                case .noRouteFound:
                    errorMessage = "No route found between selected waypoints"
                case .couldNotMatchOrigin:
                    errorMessage = "Origin could not be matched"
                case .couldNotMatchDestination:
                    errorMessage = "Destination could not be matched"
                case .mapNotFound:
                    errorMessage = "Requested map not found"
                case .parsingError:
                    errorMessage = "Routing response not in correct format"
                case .unknownError:
                    errorMessage = "Unknown Error encountered"
                default:
                    errorMessage = "Unknown Error encountered"
                }
                
                // Ensure errorBanner is initialized only once
                if self.errorBanner.parent == nil {
                    self.errorBanner.showErrorBanner(withMessage: errorMessage)
                    self.showBannerView()
                }
            }
        }
    }
    
    private func showBannerView() {
        viewController!.addChild(errorBanner)
        viewController!.view.addSubview(errorBanner.view)
        errorBanner.didMove(toParent: viewController)
    }
    
    public func stopRouting() {
        self.routingController?.hideRoute()
    }
}
