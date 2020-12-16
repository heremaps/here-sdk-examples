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

// This example shows how to calculate routes for electric vehicles that contain necessary charging stations
// (indicated with red charging icon). In addition, all existing charging stations are searched along the route
// (indicated with green charging icon). You can also visualize the reachable area from your starting point
// (isoline routing).
class RoutingExample {

    private var viewController: UIViewController
    private var mapView: MapView
    private var mapMarkers = [MapMarker]()
    private var mapPolylineList = [MapPolyline]()
    private var mapPolygonList = [MapPolygon]()
    private var routingEngine: RoutingEngine
    private var searchEngine: SearchEngine
    private var startGeoCoordinates: GeoCoordinates?
    private var destinationGeoCoordinates: GeoCoordinates?
    private var chargingStationsIDs = [String]()

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      distanceInMeters: 1000 * 10)

        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }

        do {
            // Add search engine to search for places along a route.
            try searchEngine = SearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize search engine. Cause: \(engineInstantiationError)")
        }
    }

    // Calculates an EV car route based on random start / destination coordinates near viewport center.
    func addRoute() {
        clearMap()
        chargingStationsIDs.removeAll()

        startGeoCoordinates = createRandomGeoCoordinatesInViewport()
        destinationGeoCoordinates = createRandomGeoCoordinatesInViewport()

        routingEngine.calculateRoute(with: [Waypoint(coordinates: startGeoCoordinates!),
                                            Waypoint(coordinates: destinationGeoCoordinates!)],
                                     evCarOptions: getEVCarOptions()) { (routingError, routes) in

            if let error = routingError {
                self.showDialog(title: "Error while calculating a route:", message: "\(error)")
                return
            }

            // When routingError is nil, routes is guaranteed to contain at least one route.
            let route = routes!.first
            self.showRouteOnMap(route: route!)
            self.logRouteViolations(route: route!)
            self.logEVDetails(route: route!)
            self.searchAlongARoute(route: route!)
        }
    }

    private func getEVCarOptions() -> EVCarOptions {
        var evCarOptions = EVCarOptions()

        // The below three options are the minimum you must specify or routing will result in an error.
        evCarOptions.consumptionModel.ascentConsumptionInWattHoursPerMeter = 9
        evCarOptions.consumptionModel.descentRecoveryInWattHoursPerMeter = 4.3
        evCarOptions.consumptionModel.freeFlowSpeedTable = [0: 0.239,
                                                            27: 0.239,
                                                            60: 0.196,
                                                            90: 0.238]

        // Ensure that the vehicle does not run out of energy along the way and charging stations are added as additional waypoints.
        evCarOptions.ensureReachability = true

        // The below options are required when setting the ensureReachability option to true.
        evCarOptions.routeOptions.optimizationMode = .fastest
        evCarOptions.routeOptions.alternatives = 0
        evCarOptions.batterySpecifications.connectorTypes = [.tesla, .iec62196Type1Combo, .iec62196Type2Combo]
        evCarOptions.batterySpecifications.totalCapacityInKilowattHours = 80.0
        evCarOptions.batterySpecifications.initialChargeInKilowattHours = 10.0
        evCarOptions.batterySpecifications.targetChargeInKilowattHours = 72.0
        evCarOptions.batterySpecifications.chargingCurve = [0: 239.0,
                                                            64: 111.0,
                                                            72: 1.0]

        // Note: More EV options are availeble, the above shows only the minimum viable options.

        return evCarOptions
    }

    private func logEVDetails(route: Route) {
        // Find inserted charging stations that are required for this route.
        // Note that this example assumes only one start waypoint and one destination waypoint.
        // By default, each route has one section.
        let additionalSectionCount = route.sections.count - 1
        if (additionalSectionCount > 0) {
            // Each additional waypoint splits the route into two sections.
            print("Number of required stops at charging stations: \(additionalSectionCount)")
        } else {
            print("Based on the provided options, the destination can be reached without a stop at a charging station.")
        }

        var sectionIndex = 0
        let sections = route.sections
        for section in sections {
            let evDetails = section.evDetails
            print("Estimated net energy consumption in kWh for this section: \(String(describing: evDetails?.consumptionInKilowattHour))")
            for postAction in section.postActions {
                switch postAction.action {
                    case .chargingSetup:
                        print("At the end of this section you need to setup charging for \(postAction.durationInSeconds) s.")
                    break
                    case .charging:
                        print("At the end of this section you need to charge for \(postAction.durationInSeconds) s.")
                    break
                    case .wait:
                        print("At the end of this section you need to wait for \(postAction.durationInSeconds) s.")
                    break
                    default: fatalError("Unknown post action type.")
                }
            }

            print("Section \(sectionIndex): Estimated departure battery charge in kWh: \(String(describing: section.departure.chargeInKilowattHours))")
            print("Section \(sectionIndex): Estimated arrival battery charge in kWh: \(String(describing: section.arrival.chargeInKilowattHours))")

            // Only charging stations that are needed to reach the destination are listed below.
            let depStation = section.departure.chargingStation
            if depStation != nil  && !chargingStationsIDs.contains(depStation?.id ?? "-1") {
                print("Section \(sectionIndex), name of charging station: \(String(describing: depStation?.name))")
                chargingStationsIDs.append(depStation?.id ?? "-1")
                addCircleMapMarker(geoCoordinates: section.departure.mapMatchedCoordinates, imageName: "required_charging.png")
            }

            let arrStation = section.departure.chargingStation
            if arrStation != nil && !chargingStationsIDs.contains(arrStation?.id ?? "-1") {
                print("Section \(sectionIndex), name of charging station: \(String(describing: arrStation?.name))")
                chargingStationsIDs.append(arrStation?.id ?? "-1")
                addCircleMapMarker(geoCoordinates: section.arrival.mapMatchedCoordinates, imageName: "required_charging.png")
            }

            sectionIndex += 1
        }
    }

    // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
    // An implementation may decide to reject a route if one or more violations are detected.
    private func logRouteViolations(route: Route) {
        let sections = route.sections
        for section in sections {
            for notice in section.notices {
                print("This route contains the following warning: \(notice.code)")
            }
        }
    }

    private func showRouteOnMap(route: Route) {
        // Show route as polyline.
        let routeGeoPolyline = try! GeoPolyline(vertices: route.polyline)
        let routeMapPolyline = MapPolyline(geometry: routeGeoPolyline,
                                           widthInPixels: 20,
                                           color: UIColor(red: 0,
                                                          green: 0.56,
                                                          blue: 0.54,
                                                          alpha: 0.63))
        mapView.mapScene.addMapPolyline(routeMapPolyline)
        mapPolylineList.append(routeMapPolyline)

        // Draw a circle to indicate starting point and destination.
        addCircleMapMarker(geoCoordinates: startGeoCoordinates!, imageName: "green_dot.png")
        addCircleMapMarker(geoCoordinates: destinationGeoCoordinates!, imageName: "green_dot.png")
    }

    // Perform a search for charging stations along the found route.
    private func searchAlongARoute(route: Route) {
        // We specify here that we only want to include results
        // within a max distance of xx meters from any point of the route.
        let routeCorridor = GeoCorridor(polyline: route.polyline,
                                        radiusInMeters: Int32(200))
        let textQuery = TextQuery("charging station",
                                  in: routeCorridor,
                                  near: mapView.camera.state.targetCoordinates)

        let searchOptions = SearchOptions(languageCode: LanguageCode.enUs,
                                          maxItems: 30)
        searchEngine.search(textQuery: textQuery,
                            options: searchOptions,
                            completion: onSearchCompleted)
    }

    // Completion handler to receive results for found charging stations along the route.
    func onSearchCompleted(error: SearchError?, items: [Place]?) {
        if let searchError = error {
            if searchError == .polylineTooLong {
                // Increasing corridor radius will result in less precise results with the benefit of a less
                // complex route shape.
                print("Route too long or route corridor radius too small.")
            } else {
                print("No charging stations found along the route. Error: \(searchError)")
            }
            return
        }

        // If error is nil, it is guaranteed that the items will not be nil.
        print("Search along route found \(items!.count) charging stations:")

        for place in items! {
            if chargingStationsIDs.contains(place.id) {
                print("Skipping: This charging station was already required to reach the destination (see red charging icon).")
            } else {
                // Only suggestions may not contain geoCoordinates, so it's safe to unwrap this search result's coordinates.
                self.addCircleMapMarker(geoCoordinates: place.geoCoordinates!, imageName: "charging.png")
                print(place.address.addressText)
            }
        }
    }

    // Shows the reachable area for this electric vehicle from the current start coordinates and EV car options when the goal is
    // to consume 400 Wh or less (see options below).
    func showReachableArea() {
        guard
            let startGeoCoordinates = startGeoCoordinates else {
                showDialog(title: "Error", message: "Please add at least one route first.")
                return
        }

        // This finds the area that an electric vehicle can reach by consuming 400 Wh or less,
        // while trying to take the fastest possible route into any possible straight direction from start.
        // Note: We have specified evCarOptions.routeOptions.optimizationMode = .fastest for EV car options above.
        let calculationOptions = IsolineOptions.Calculation(rangeType: .consumptionInWattHours, rangeValues: [400])
        let isolineOptions = IsolineOptions(calculationOptions: calculationOptions,
                                            evCarOptions: getEVCarOptions())

        routingEngine.calculateIsoline(center: Waypoint(coordinates: startGeoCoordinates),
                                       isolineOptions: isolineOptions) { (routingError, isolines) in

            if let error = routingError {
                self.showDialog(title: "Error while calculating reachable area:", message: "\(error)")
                return
            }

            // When routingError is nil, the isolines list is guaranteed to contain at least one isoline.
            // The number of isolines matches the number of requested range values. Here we have used one range value,
            // so only one isoline object is expected.
            let isoline = isolines!.first!

            // If there is more than one polygon, the other polygons indicate separate areas, for example, islands, that
            // can only be reached by a ferry.
            for geoPolygon in isoline.polygons {
                // Show polygon on map.
                let fillColor = UIColor(red: 0, green: 0.56, blue: 0.54, alpha: 0.5)
                let mapPolygon = MapPolygon(geometry: geoPolygon, color: fillColor)
                self.mapView.mapScene.addMapPolygon(mapPolygon)
                self.mapPolygonList.append(mapPolygon)
            }
        }
    }

    func clearMap() {
        clearWaypointMapMarker()
        clearRoute()
        clearIsolines()
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

    private func clearIsolines() {
        for mapPolygon in mapPolygonList {
            mapView.mapScene.removeMapPolygon(mapPolygon)
        }
        mapPolygonList.removeAll()
    }

    private func createRandomGeoCoordinatesInViewport() -> GeoCoordinates {
        let geoBox = mapView.camera.boundingBox
        let northEast = geoBox?.northEastCorner
        let southWest = geoBox?.southWestCorner

        guard let minLat = southWest?.latitude else { return mapView.camera.state.targetCoordinates }
        guard let maxLat = northEast?.latitude else { return mapView.camera.state.targetCoordinates }
        let lat = getRandom(min: minLat, max: maxLat)

        guard let minLon = southWest?.longitude else { return mapView.camera.state.targetCoordinates }
        guard let maxLon = northEast?.longitude else { return mapView.camera.state.targetCoordinates }
        let lon = getRandom(min: minLon, max: maxLon)

        return GeoCoordinates(latitude: lat, longitude: lon)
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

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
