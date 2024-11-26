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

// This example shows how to request and visualize realtime traffic flow information
// with the TrafficEngine along a route corridor.
// Note that the request time may differ from the refresh cycle for TRAFFIC_FLOWs.
// Note that this does not consider future traffic predictions that are available based on
// the traffic information of the route object based on the ETA and historical traffic patterns.
class RoutingExample {

    private let mapView: MapView
    private var mapPolylines = [MapPolyline]()
    private let routingEngine: RoutingEngine
    private let trafficEngine: TrafficEngine
    
    init(_ mapView: MapView) {
        self.mapView = mapView
        
        do {
            routingEngine = try RoutingEngine()
        } catch let error {
            fatalError("Initialization of RoutingEngine failed: \(error.localizedDescription)")
        }
        
        do {
            // The traffic engine can be used to request additional information about
            // the current traffic situation anywhere on the road network.
            trafficEngine = try TrafficEngine()
        } catch let error {
            fatalError("Initialization of TrafficEngine failed: \(error.localizedDescription)")
        }
    }
    
    func addRoute() {
        let startWaypoint = Waypoint(coordinates: createRandomGeoCoordinatesAroundMapCenter())
        let destinationWaypoint = Waypoint(coordinates: createRandomGeoCoordinatesAroundMapCenter())
        let waypoints = [startWaypoint, destinationWaypoint]
        let carOptions = CarOptions()
            
        routingEngine.calculateRoute(with: waypoints,
                                     carOptions: carOptions) { (routingError, routes) in
            if let error = routingError {
                self.showDialog(title: "Error while calculating a route", message: "\(error)")
                return
            }
            
            if let route = routes?.first {
                self.showRouteOnMap(route: route)
            }
        }
    }
    
    private func showRouteOnMap(route: Route) {
        // Optionally, clear any previous route.
        clearMap()
        
        // Show route as polyline.
        let widthInPixels = 20.0
        let polylineColor = UIColor(red: 0, green: 0.56, blue: 0.54, alpha: 0.63)
        
        do {
            let routeMapPolyline =  try MapPolyline(geometry: route.geometry,
                                                    representation: MapPolyline.SolidRepresentation(
                                                        lineWidth: MapMeasureDependentRenderSize(
                                                            sizeUnit: RenderSize.Unit.pixels,
                                                            size: widthInPixels),
                                                        color: polylineColor,
                                                        capShape: LineCap.round))
            mapView.mapScene.addMapPolyline(routeMapPolyline)
            mapPolylines.append(routeMapPolyline)
        } catch let error {
            print("Failed to create MapPolyline: \(error.localizedDescription)")
        }
        
        if route.lengthInMeters / 1000 > 5000 {
            showDialog(title: "Note", message: "Skipped showing traffic-on-route for longer routes.")
            return
        }
        
        requestRealtimeTrafficOnRoute(route: route)
    }
    
    func clearMap() {
        for mapPolyline in mapPolylines {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylines.removeAll()
    }
    
    // This code uses the TrafficEngine to request the current state of the traffic situation
    // along the specified route corridor. Note that this information might dynamically change while
    // traveling along a route and it might not relate with the given ETA for the route.
    // Whereas the traffic-flow map feature shows pre-rendered vector tiles to achieve a smooth
    // map performance, the TrafficEngine requests the same information only for a specified area.
    // Depending on the time of the request and other backend factors like rendering the traffic
    // vector tiles, there can be cases, where both results differ.
    // Note that the HERE SDK allows to specify how often to request updates for the traffic-flow
    // map feature. It is recommended to not show traffic-flow and traffic-on-route together as it
    // might lead to redundant information. Instead, consider to show the traffic-flow map feature
    // side-by-side with the route's polyline (not shown in the method below). See Routing app for an
    // example.
    private func requestRealtimeTrafficOnRoute(route: Route) {
        // We are interested to see traffic also for side paths.
        let halfWidthInMeters = 500
        let geoCorridor = GeoCorridor(polyline: route.geometry.vertices, 
                                      halfWidthInMeters: Int32(halfWidthInMeters))
        let trafficFlowQueryOptions = TrafficFlowQueryOptions()

        trafficEngine.queryForFlow(inside: geoCorridor,
                                   queryOptions: trafficFlowQueryOptions) { (trafficQueryError, trafficFlowList) in
            if let error = trafficQueryError {
                self.showDialog(title: "Error while fetching traffic flow", message: "\(error)")
                return
            }
            
            if let trafficFlows = trafficFlowList {
                for trafficFlow in trafficFlows {
                    guard let confidence = trafficFlow.confidence, confidence > 0.5 else {
                        // Exclude speed-limit data and include only real-time and historical
                        // flow information.
                        continue
                    }
                    
                    // Visualize all polylines unfiltered as we get them from the TrafficEngine.
                    let trafficGeoPolyline = trafficFlow.location.polyline
                    self.addTrafficPolylines(jamFactor: trafficFlow.jamFactor, 
                                             geoPolyline: trafficGeoPolyline)
                }
            }
        }
    }
    
    private func addTrafficPolylines(jamFactor: Double, geoPolyline: GeoPolyline) {
        guard let lineColor = getTrafficColor(jamFactor: jamFactor) else {
            // We skip rendering low traffic.
            return
        }
        
        let widthInPixels: Float = 10
        do {
            let trafficSpanMapPolyline =  try MapPolyline(geometry: geoPolyline,
                                                          representation: MapPolyline.SolidRepresentation(
                                                                lineWidth: MapMeasureDependentRenderSize(
                                                                    sizeUnit: RenderSize.Unit.pixels,
                                                                    size: Double(widthInPixels)),
                                                                color: lineColor,
                                                                capShape: LineCap.round))
            mapView.mapScene.addMapPolyline(trafficSpanMapPolyline)
            mapPolylines.append(trafficSpanMapPolyline)
        } catch let error {
            print("Failed to create MapPolyline: \(error.localizedDescription)")
        }
    }
    
    // Define a traffic color scheme based on the traffic jam factor.
    // 0 <= jamFactor < 4: No or light traffic.
    // 4 <= jamFactor < 8: Moderate or slow traffic.
    // 8 <= jamFactor < 10: Severe traffic.
    // jamFactor = 10: No traffic, ie. the road is blocked.
    // Returns null in case of no or light traffic.
    private func getTrafficColor(jamFactor: Double) -> UIColor? {
        if jamFactor < 4 {
            return nil
        } else if jamFactor < 8 {
            return UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.63) // Yellow
        } else if jamFactor < 10 {
            return UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.63) // Red
        }
        return UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.63) // Black
    }
    
    private func createRandomGeoCoordinatesAroundMapCenter() -> GeoCoordinates {
        let mapCenter = Point2D(x: Double(Float(mapView.frame.size.width)) / 2, 
                                y: Double(Float(mapView.frame.size.height)) / 2)
        guard let centerGeoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: mapCenter) else {
            // Should never happen for center coordinates.
            fatalError("CenterGeoCoordinates are null")
        }
        
        let lat = centerGeoCoordinates.latitude
        let lon = centerGeoCoordinates.longitude
        return GeoCoordinates(latitude: getRandom(min: lat - 0.02, max: lat + 0.02),
                              longitude: getRandom(min: lon - 0.02, max: lon + 0.02))
    }
    
    private func getRandom(min: Double, max: Double) -> Double {
        return Double.random(in: min...max)
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
