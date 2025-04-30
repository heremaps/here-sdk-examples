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

class RoutingWithAvoidanceOptionsExample : LongPressDelegate, TapDelegate {
    
    private let mapView: MapView
    private var mapPolylines: [MapPolyline] = []
    private var segmentPolylines: [MapPolyline] = []
    private let routingEngine: RoutingEngine
    
    // A route in Berlin - can be changed via long press.
    private var startGeoCoordinates: GeoCoordinates? = GeoCoordinates(latitude: 52.49047222554655, longitude: 13.296884483959285)
    private var destinationGeoCoordinates: GeoCoordinates? = GeoCoordinates(latitude: 52.51384077118386, longitude: 13.255752692114996)
    private var tappedCoordinates: GeoCoordinates?
    
    private var startMapMarker: MapMarker?
    private var destinationMapMarker: MapMarker?
    
    private var currentlySelectedSegmentReference: SegmentReference?
    private let segmentDataLoader: SegmentDataLoader
    
    private let metadataSegmentIdKey = "segmentId"
    private let metadataTilePartitionIdKey = "tilePartitionId"
    
    private var setLongpressDestination = false
    private var segmentAvoidanceList: [String: SegmentReference] = [:]
    private var segmentsAvoidanceViolated = false
    
    
    init(_ mapView: MapView) {
        self.mapView = mapView
        
        let camera = mapView.camera
        let distanceInMeters: Double = 5000
        let mapMeasureZoom = MapMeasure(kind: .distanceInMeters, value: distanceInMeters)
        camera.lookAt(
            point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
            zoom: mapMeasureZoom
        )
        
        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }
        
        do {
            // With the segment data loader information can be retrieved from cached or installed offline map data, for example on road attributes.
            // This feature can be used independent from a route. It is recommended to not rely on the cache alone. For simplicity, this is left out for this example.
            try segmentDataLoader = SegmentDataLoader()
        } catch let InstantiationError {
            fatalError("Initialization failed. Cause: \(InstantiationError)")
        }
        
        // Add markers to indicate the currently selected starting point and destination.
        startMapMarker = addMapMarker(geoCoordinates: startGeoCoordinates!, imageName: "poi_start.png")!
        destinationMapMarker = addMapMarker(geoCoordinates: destinationGeoCoordinates!, imageName: "poi_destination.png")!
        
        
        // Fallback if no segments have been picked by the user.
        let segmentReferenceInBerlin = createSegmentInBerlin()
        segmentAvoidanceList[segmentReferenceInBerlin.segmentId] = segmentReferenceInBerlin
        
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
        
        mapView.gestures.tapDelegate = self
        mapView.gestures.longPressDelegate = self
    }
    
    // Conform to the TapDelegate protocol.
    func onTap(origin: Point2D) {
        tappedCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: origin)
        
        let originInPixels = Point2D(x:origin.x,y:origin.y);
        let sizeInPixels = Size2D(width:50,height:50);
        let rectangle = Rectangle2D(origin: originInPixels, size: sizeInPixels);
        var contentTypesToPickFrom = Array<MapScene.MapPickFilter.ContentType>();
        
        contentTypesToPickFrom.append(MapScene.MapPickFilter.ContentType.mapItems);
        let filter = MapScene.MapPickFilter(filter: contentTypesToPickFrom);
        
        mapView.pick(filter: filter, inside: rectangle, completion:onMapItemsPicked);
    }
    
    // Completion handler to receive picked map items.
    func onMapItemsPicked(mapPickResults: MapPickResult?) {
        
        guard let mapPickResult = mapPickResults else {
            // An error occurred during the pick operation, e.g., picking the horizon.
            return
        }

        let pickMapItemsResult = mapPickResult.mapItems
        let polylines = pickMapItemsResult?.polylines
        let listSize = polylines?.count

        if listSize == 0 {
            loadAndProcessSegmentData(startGeoCoordinates: tappedCoordinates!)
            return
        }

        let mapPolyline = (polylines?[0])!
        handlePickedMapPolyline(mapPolyline)
    }
    
    private func handlePickedMapPolyline(_ mapPolyline: MapPolyline) {
        if let metadata = mapPolyline.metadata {
            let partitionId = metadata.getInteger(key: metadataTilePartitionIdKey)
            let segmentId = metadata.getString(key: metadataSegmentIdKey)!

            showDialog(
                title: "Segment removed:",
                message: "Removed Segment ID \(String(describing: segmentId)) Tile partition ID \(String(describing: partitionId))"
            )

            if let index = segmentPolylines.firstIndex(of: mapPolyline) {
                segmentPolylines.remove(at: index)
            }
            mapView.mapScene.removeMapPolyline(mapPolyline)
            segmentAvoidanceList.removeValue(forKey: segmentId)
        } else {
            showDialog(
                title: "Map polyline picked:",
                message: "You picked a route polyline"
            )
        }
    }

    
    // Load segment data and fetch information from the map around the starting point of the requested route.
    func loadAndProcessSegmentData(startGeoCoordinates : GeoCoordinates) {
        
        // The necessary SegmentDataLoaderOptions need to be turned on in order to find the requested information.
        // It is recommended to turn on only the fields that you are interested in.
        var segmentDataLoaderOptions = SegmentDataLoaderOptions()
        segmentDataLoaderOptions.loadBaseSpeeds = true
        segmentDataLoaderOptions.loadRoadAttributes = true
        
        let radiusInMeters = 5.0
        
        
        do {
            let segmentIds = try segmentDataLoader.getSegmentsAroundCoordinates(startGeoCoordinates, radiusInMeters: radiusInMeters)
            
            
            for segmentId in segmentIds {
                let segmentData = try segmentDataLoader.loadData(segment: segmentId, options: segmentDataLoaderOptions)
                
                let segmentSpanDataList = segmentData.spans
                let segmentReference = segmentData.segmentReference
                
                let metadata = Metadata()
                metadata.setString(key: metadataSegmentIdKey, value: segmentReference.segmentId)
                metadata.setInteger(key: metadataTilePartitionIdKey, value: Int32(segmentReference.tilePartitionId))
                
                if let segmentPolyline = createMapPolyline(
                    color: UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                    geoPolyline: segmentData.polyline
                ) {
                    segmentPolyline.metadata = metadata
                    mapView.mapScene.addMapPolyline(segmentPolyline)
                    segmentPolylines.append(segmentPolyline)
                    segmentAvoidanceList[segmentReference.segmentId] = segmentReference
                }
                
                
                for span in segmentSpanDataList {
                    print("Physical attributes of \(span) span.")
                    
                    print("Private roads: \(String(describing: span.physicalAttributes?.isPrivate))")
                    print("Dirt roads: \(String(describing: span.physicalAttributes?.isDirtRoad))")
                    print("Bridge: \(String(describing: span.physicalAttributes?.isBridge))")
                    print("Tollway: \(String(describing: span.roadUsages?.isTollway))")
                    print("Average expected speed: \(String(describing: span.positiveDirectionBaseSpeedInMetersPerSecond))")
                }
            }
        } catch let SegmentDataLoaderError {
            print("Error loading segment data: \(SegmentDataLoaderError)")
        }
        
    }
    
    // Conform to LongPressDelegate protocol.
    func onLongPress(state: heresdk.GestureState, origin: Point2D) {
        guard let geoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: origin) else {
            print("Warning: Long press coordinate is not on map view.")
            return
        }
        
        if state == GestureState.begin {
            if (setLongpressDestination) {
                destinationGeoCoordinates = geoCoordinates;
                destinationMapMarker?.coordinates = geoCoordinates;
            } else {
                startGeoCoordinates = geoCoordinates;
                startMapMarker?.coordinates = geoCoordinates
            }
            setLongpressDestination = !setLongpressDestination;
        }
    }
    
    /// A hardcoded segment in Berlin used as a fallback when no segments are picked.
    private func createSegmentInBerlin() -> SegmentReference {
        // Alternatively, segmentId and tilePartitionId can be extracted from a Route object's spans.
        let segmentId = "here:cm:segment:807958890"
        let tilePartitionId: UInt32 = 377894441
        
        var segmentReference = SegmentReference()
        segmentReference.segmentId = segmentId
        segmentReference.tilePartitionId = tilePartitionId
        return segmentReference
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
        guard let startGeoCoordinates = startGeoCoordinates,
              let destinationGeoCoordinates = destinationGeoCoordinates else {
            showDialog(title: "Error", message: "Long press on the map to select source and destination.")
            return
        }
        
        let startWaypoint = Waypoint(coordinates: startGeoCoordinates)
        let destinationWaypoint = Waypoint(coordinates: destinationGeoCoordinates)
        var carOptions = CarOptions()
        carOptions.avoidanceOptions = getAvoidanceOptions()
        
        let waypoints: [Waypoint] = [startWaypoint, destinationWaypoint]
        
        routingEngine.calculateRoute(with: waypoints,
                                     carOptions: carOptions) { (routingError, routes) in
            
            if let error = routingError {
                self.showDialog(title: "Error while calculating a route:", message: "\(error)")
                return
            }
            
            // When routingError is nil, routes is guaranteed to contain at least one route.
            let route = routes!.first
            self.logRouteViolations(route: route!)
            self.showRouteOnMap(route: route!)
            self.showRouteDetails(route: route!)
        }
    }
    
    private func getAvoidanceOptions() -> AvoidanceOptions {
        var avoidanceOptions = AvoidanceOptions()
        avoidanceOptions.segments = Array(segmentAvoidanceList.values)
        return avoidanceOptions
    }
    
    // Logs violations for spans where segment blocking was not possible.
    private func logRouteViolations(route: Route) {
        segmentsAvoidanceViolated = false
        for section in route.sections {
            for span in section.spans {
                let spanGeometryVertices = span.geometry.vertices
                guard let violationStartPoint = spanGeometryVertices.first,
                      let violationEndPoint = spanGeometryVertices.last else {
                    continue
                }
                
                for index in span.noticeIndexes {
                    let spanSectionNotice = section.sectionNotices[Int(index)]
                    if spanSectionNotice.code == .violatedBlockedRoad {
                        segmentsAvoidanceViolated = true
                    }
                    
                    let violationCode = spanSectionNotice.code
                    print("The violation \(violationCode) starts at \(toString(geoCoordinates: violationStartPoint)) and ends at \(toString(geoCoordinates: violationEndPoint)).")
                }
            }
        }
    }
    
    
    private func toString(geoCoordinates: GeoCoordinates) -> String {
        return String(geoCoordinates.latitude) + ", " + String(geoCoordinates.longitude);
    }
    
    private func showRouteDetails(route: Route) {
        var routeDetails = "Route length in m: \(route.lengthInMeters)"
        
        if segmentsAvoidanceViolated {
            routeDetails += "\nSome segments cannot be avoided. See logs!"
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
        let routeGeoPolyline = route.geometry
        let routeMapPolyline = createMapPolyline(
            color: UIColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 1.0),
            geoPolyline: routeGeoPolyline
        )
        if let routeMapPolyline = routeMapPolyline {
            mapView.mapScene.addMapPolyline(routeMapPolyline)
            mapPolylines.append(routeMapPolyline)
            mapView.camera.lookAt(
                area: route.boundingBox,
                orientation: GeoOrientationUpdate(GeoOrientation(bearing: 0.0, tilt: 0.0))
            )
        }
    }
    
    private func createMapPolyline(color: UIColor, geoPolyline: GeoPolyline) -> MapPolyline? {
        let widthInPixels = 15.0
        do {
            let routeMapPolyline =  try MapPolyline(geometry: geoPolyline,
                                                    representation: MapPolyline.SolidRepresentation(
                                                        lineWidth: MapMeasureDependentRenderSize(
                                                            sizeUnit: RenderSize.Unit.pixels,
                                                            size: widthInPixels),
                                                        color: color,
                                                        capShape: LineCap.round))
            
            return routeMapPolyline
        } catch let error {
            fatalError("Failed to render MapPolyline. Cause: \(error)")
        }
    }
    
    func clearMap() {
        clearRoute()
    }
    
    private func clearRoute() {
        for mapPolyline in mapPolylines {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylines.removeAll()
    }
    
    private func clearSegmentPolylines() {
        for segmentPolyline in segmentPolylines {
            mapView.mapScene.removeMapPolyline(segmentPolyline)
        }
        segmentPolylines.removeAll()
    }
    
    private func addMapMarker(geoCoordinates: GeoCoordinates, imageName: String) -> MapMarker? {
        
        guard
            let image = UIImage(named: imageName),
            let imageData = image.pngData() else {
            return nil
        }
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png))
        mapMarker.anchor = Anchor2D(horizontal: 0.5, vertical: 1.0)
        
        mapView.mapScene.addMapMarker(mapMarker)
        return mapMarker
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
