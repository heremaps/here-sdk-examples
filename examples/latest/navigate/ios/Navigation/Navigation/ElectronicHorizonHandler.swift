/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
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

/// A class that handles electronic horizon related operations.
/// This is not required for navigation, but can be used to get information about the road network ahead of the user.
/// For this example, selected retrieved information is logged, such as road signs.
///
/// Usage:
/// 1. Create an instance of this class.
/// 2. Call start(route) to initialize the ElectronicHorizonEngine.
///    Optionally, nil can be provided to operate in tracking mode without a route.
/// 3. Call update(mapMatchedLocation) with a map-matched location to update the ElectronicHorizonEngine.
/// 4. Call stop() to stop getting ElectronicHorizonEngine events.
///
/// Note that in this example app we only enable the electronic horizon in car mode while following a route.
///
/// For convenience, the ElectronicHorizonDataLoader wraps a SegmentDataLoader that allows to
/// continuously load required map data segments based on the most preferred path(s) of the ElectronicHorizonEngine.
/// When it does not find cached, prefetched or preloaded region data for a segment,
/// it will asynchronously request the data from the HERE backend services.
/// It is recommended to use a prefetcher to prefetch region data along the route in advance (not shown in this class).
class ElectronicHorizonHandler {

    private static let LOG_TAG = String(describing: ElectronicHorizonHandler.self)
    // Optional: Using a small offset can help mark/log the side street more clearly for visualization.
    private static let SIDE_STREET_LOG_OFFSET_METERS = 20.0

    private let mapView: MapView
    private var electronicHorizonEngine: ElectronicHorizonEngine?
    private let electronicHorizonDataLoader: ElectronicHorizonDataLoader

    private lazy var electronicHorizonDelegate: ElectronicHorizonDelegate = {
        return createElectronicHorizonDelegate()
    }()

    private lazy var electronicHorizonDataLoaderStatusDelegate: ElectronicHorizonDataLoaderStatusDelegate = {
        return createElectronicHorizonDataLoaderStatusDelegate()
    }()

    // Keep track of the last electronic horizon to access its segments
    // when data loading is completed.
    private var lastElectronicHorizon: ElectronicHorizon?

    // Segment polyline map: maps the segment's OCM local ID to its drawn MapPolyline.
    // This allows individual polylines to be removed when segments leave the horizon.
    private var segmentPolylineMap: [Int64: MapPolyline] = [:]

    // Controls whether segment polylines are drawn on the map.
    private var isVisualizationEnabled = false

    init(mapView: MapView) {
        self.mapView = mapView

        // Many more options are available, see SegmentDataLoaderOptions in the API Reference.
        var segmentDataLoaderOptions = SegmentDataLoaderOptions()
        segmentDataLoaderOptions.loadRoadSigns = true
        segmentDataLoaderOptions.loadSpeedLimits = true
        segmentDataLoaderOptions.loadRoadAttributes = true
        segmentDataLoaderOptions.loadStreetNamesAndRoadNumbers = true

        // The cache size defines how many road segments are cached locally. A larger cache size
        // can reduce data usage, but requires more storage memory in the cache.
        // A small cache can replace previously loaded segments too early.
        let segmentDataCacheSize = 1000
        do {
            electronicHorizonDataLoader = try ElectronicHorizonDataLoader(
                sdkEngine: ElectronicHorizonHandler.getSDKNativeEngine(),
                options: segmentDataLoaderOptions,
                segmentDataCacheSize: Int32(segmentDataCacheSize)
            )
        } catch let instantiationError {
            fatalError("ElectronicHorizonDataLoader is not initialized: \(instantiationError)")
        }
    }

    /// Enable or disable the colored segment polyline visualization on the map.
    /// When disabled, all currently drawn polylines are removed from the map immediately.
    func toggleVisualization(enabled: Bool) {
        isVisualizationEnabled = enabled
        if !enabled {
            clearVisualization()
        }
        print("\(Self.LOG_TAG): EH visualization \(enabled ? "enabled" : "disabled").")
    }

    /// Without a route, electronic horizon operates in tracking mode and the most probable path is
    /// estimated based on the current location and previous locations.
    /// With a route, electronic horizon operates in map-matched mode and the route is used
    /// to determine the most probable path. Therefore, the route will determine the main path ahead.
    func start(route: Route?) {
        // The first entry of the list is for the most preferred path, the second is for the side paths of the first level,
        // the third is for the side paths of the second level, and so on.
        // Each entry defines how far ahead the path should be provided.
        let lookAheadDistancesInMeters = [1000.0, 500.0, 250.0]
        // Segments will be removed by the HERE SDK once passed and the distance to them exceeds trailingDistanceInMeters.
        // Segments are also removed when the vehicle passes the decision point for alternative side paths.
        let trailingDistanceInMeters = 500.0
        let electronicHorizonOptions = ElectronicHorizonOptions(
            lookAheadDistancesInMeters: lookAheadDistancesInMeters,
            trailingDistanceInMeters: trailingDistanceInMeters
        )

        let transportMode = TransportMode.car

        do {
            electronicHorizonEngine = try ElectronicHorizonEngine(
                sdkEngine: ElectronicHorizonHandler.getSDKNativeEngine(),
                options: electronicHorizonOptions,
                transportMode: transportMode,
                route: route
            )
        } catch let instantiationError {
            fatalError("ElectronicHorizonEngine is not initialized: \(instantiationError)")
        }

        // Remove any existing delegates before re-registering.
        stop()

        // Create and add new delegates.
        electronicHorizonDelegate = createElectronicHorizonDelegate()
        electronicHorizonEngine!.addElectronicHorizonDelegate(_: electronicHorizonDelegate)

        electronicHorizonDataLoaderStatusDelegate = createElectronicHorizonDataLoaderStatusDelegate()
        electronicHorizonDataLoader.addElectronicHorizonDataLoaderStatusDelegate(_: electronicHorizonDataLoaderStatusDelegate)

        print("\(Self.LOG_TAG): ElectronicHorizonEngine started.")
    }

    /// Similar to the VisualNavigator, the ElectronicHorizonEngine also needs to be updated with
    /// a location - with the difference that the location must be map-matched. Therefore, the
    /// location provided by the VisualNavigator can be used directly.
    func update(mapMatchedLocation: MapMatchedLocation) {
        guard let electronicHorizon = electronicHorizonEngine else {
            fatalError("ElectronicHorizonEngine is not initialized. Call start() first.")
        }
        electronicHorizon.update(mapMatchedLocation: mapMatchedLocation)
        print("\(Self.LOG_TAG): ElectronicHorizonUpdate mapMatchedLocation received.")
    }

    /// Create a delegate to get notified about electronic horizon updates while a user moves along the road.
    /// This informs on the available segment IDs and indexes so that the actual data can be requested
    /// by the ElectronicHorizonDataLoader. It also carries removed segment IDs so their polylines
    /// can be cleared from the map immediately.
    private func createElectronicHorizonDelegate() -> ElectronicHorizonDelegate {
        class EHDelegate: ElectronicHorizonDelegate {
            weak var handler: ElectronicHorizonHandler?

            init(handler: ElectronicHorizonHandler) {
                self.handler = handler
            }

            func onElectronicHorizonUpdated(errorCode: ElectronicHorizonErrorCode?, update: ElectronicHorizonUpdate?) {
                if let error = errorCode {
                    print("\(ElectronicHorizonHandler.LOG_TAG): ElectronicHorizonUpdate error: \(error)")
                    return
                }

                guard let electronicHorizonUpdate = update else { return }

                print("\(ElectronicHorizonHandler.LOG_TAG): ElectronicHorizonUpdate received.")

                // The update always carries the vehicle's current position in the horizon tree.
                let position = electronicHorizonUpdate.position
                print("\(ElectronicHorizonHandler.LOG_TAG): EH position: pathIndex=\(position.pathIndex), pathSegmentIndex=\(position.pathSegmentIndex), offsetInMeters=\(position.pathSegmentOffsetInMeters)")

                // Store last known horizon if present.
                if electronicHorizonUpdate.electronicHorizon != nil {
                    handler?.lastElectronicHorizon = electronicHorizonUpdate.electronicHorizon
                }

                // Remove map polylines for segments that have left the horizon.
                // Segments are removed by the HERE SDK in two cases:
                //   1. They are behind the vehicle and exceed trailingDistanceInMeters.
                //   2. The vehicle passes the decision point for an alternative side path.
                if handler?.isVisualizationEnabled == true {
                    electronicHorizonUpdate.segmentChanges?.removedIds.forEach { segmentId in
                        guard let localId = segmentId.ocmSegmentId?.id.localId else { return }
                        if let polyline = handler?.segmentPolylineMap.removeValue(forKey: Int64(localId)) {
                            handler?.mapView.mapScene.removeMapPolyline(polyline)
                        }
                    }
                }

                // Asynchronously start to load required data for the new segments.
                // Use the ElectronicHorizonDataLoaderStatusDelegate to get notified when new data arrives.
                if electronicHorizonUpdate.segmentChanges != nil {
                    handler?.electronicHorizonDataLoader.loadData(electronicHorizonUpdate: electronicHorizonUpdate)
                }
            }
        }
        return EHDelegate(handler: self)
    }

    /// Handle newly arriving map data segments provided by the ElectronicHorizonDataLoader.
    /// This delegate is called when the data loader's status is updated and segments are ready.
    /// When visualization is enabled, newly loaded segments are drawn as colored polylines on the map.
    private func createElectronicHorizonDataLoaderStatusDelegate() -> ElectronicHorizonDataLoaderStatusDelegate {
        class EHStatusDelegate: ElectronicHorizonDataLoaderStatusDelegate {
            weak var handler: ElectronicHorizonHandler?

            init(handler: ElectronicHorizonHandler) {
                self.handler = handler
            }

            func onElectronicHorizonDataLoaderStatusUpdated(electronicHorizonDataLoaderStatuses statusMap: [Int32: ElectronicHorizonDataLoadedStatus]) {
                print("\(ElectronicHorizonHandler.LOG_TAG): ElectronicHorizonDataLoaderStatus updated.")

                guard let handler = handler,
                      let lastUpdate = handler.lastElectronicHorizon else { return }

                let allPaths = lastUpdate.paths

                for (loadedLevel, status) in statusMap {
                    guard status == .fullyLoaded else { continue }

                    // Level 0 = MPP. Process MPP segments for road sign logging.
                    if loadedLevel == 0, let mpp = allPaths.first {
                        for segment in mpp.segments {
                            guard let directedOCMSegmentId = segment.segmentId.ocmSegmentId else { continue }
                            let result = handler.electronicHorizonDataLoader.getSegment(segmentId: directedOCMSegmentId)
                            if result.errorCode == nil, let segmentData = result.segmentData {
                                handler.logRoadSigns(segmentData: segmentData, directedOCMSegmentId: directedOCMSegmentId)
                            }
                        }
                        continue
                    }

                    // Wait until first-level side-path data is fully loaded before logging side streets
                    // that branch directly from the active route.
                    if loadedLevel == 1 {
                        handler.notifySideStreetInfos(allPaths: allPaths)
                    }

                    // For side-path levels (level > 0): walk all path segments and use
                    // sidePathIndexes to find paths that branch off at each segment.
                    // sidePathIndexes contains indexes into allPaths[], pointing to branching paths.
                    // Track processed path indexes to avoid redundant getSegment() calls.
                    var processedSidePathIndexes = Set<Int>()
                    for path in allPaths {
                        for segment in path.segments {
                            for sidePathIndex in segment.sidePathIndexes {
                                let idx = Int(sidePathIndex)
                                guard idx >= 0 && idx < allPaths.count else { continue }
                                guard processedSidePathIndexes.insert(idx).inserted else { continue }
                                let branchingPath = allPaths[idx]

                                // Only process branching paths at the loaded level.
                                guard branchingPath.level == loadedLevel else { continue }

                                print("\(ElectronicHorizonHandler.LOG_TAG): Branching path index: \(sidePathIndex), level: \(branchingPath.level)")

                                // Draw all segments of this branching path.
                                for branchSegment in branchingPath.segments {
                                    guard let directedOCMSegmentId = branchSegment.segmentId.ocmSegmentId else { continue }
                                    let result = handler.electronicHorizonDataLoader.getSegment(segmentId: directedOCMSegmentId)
                                    if result.errorCode == nil, let segmentData = result.segmentData, let polyline = segmentData.polyline {
                                        if handler.isVisualizationEnabled {
                                            
                                            handler.drawSegmentPolyline(
                                                localId: Int64(directedOCMSegmentId.id.localId),
                                                geoPolyline: polyline,
                                                level: Int(branchingPath.level)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        return EHStatusDelegate(handler: self)
    }

    // Finds first-level side streets whose parent is the currently followed navigation path.
    private func notifySideStreetInfos(allPaths: [ElectronicHorizonPath]) {
        for (pathIndex, path) in allPaths.enumerated() {
            if path.level != 1 || path.parentPathIndex == nil || path.parentPathIndex != 0 {
                continue
            }

            guard let sideStreetInfo = findSideStreetInfo(branchingPath: path, pathIndex: pathIndex) else {
                continue
            }

            print("\(Self.LOG_TAG): SideStreetName near active route: \(sideStreetInfo.streetName) at lat/lon: \(sideStreetInfo.coordinateAtOffsetFromSegmentStart.latitude)/\(sideStreetInfo.coordinateAtOffsetFromSegmentStart.longitude), pathIndex=\(sideStreetInfo.pathIndex), segmentLocalId=\(sideStreetInfo.segmentLocalId)")
        }
    }

    private func findSideStreetInfo(branchingPath: ElectronicHorizonPath, pathIndex: Int) -> SideStreetInfo? {
        for segment in branchingPath.segments {
            guard let directedOCMSegmentId = segment.segmentId.ocmSegmentId else { continue }

            let result = electronicHorizonDataLoader.getSegment(segmentId: directedOCMSegmentId)
            if result.errorCode != nil || result.segmentData == nil {
                continue
            }

            guard let segmentData = result.segmentData,
                  let sideStreetName = getFirstStreetLabel(segmentData: segmentData),
                  let polyline = segmentData.polyline else {
                continue
            }

            let sideStreetCoordinates = polyline.coordinatesAt(
                offsetInMeters: Self.SIDE_STREET_LOG_OFFSET_METERS,
                direction: .fromBeginning
            )

            return SideStreetInfo(
                streetName: sideStreetName,
                coordinateAtOffsetFromSegmentStart: sideStreetCoordinates,
                pathIndex: pathIndex,
                segmentLocalId: Int64(directedOCMSegmentId.id.localId)
            )
        }

        return nil
    }

    // Returns the first non-empty street label (street name or road number).
    private func getFirstStreetLabel(segmentData: SegmentData) -> String? {
        let segmentSpans = segmentData.spans
        if segmentSpans.isEmpty {
            return nil
        }

        for segmentSpanData in segmentSpans {
            var streetName = segmentSpanData.streetNames?.defaultValue()
            if streetName == nil || streetName!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                streetName = segmentSpanData.roadNumbers?.defaultValue()
            }
            if let streetName = streetName, !streetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return streetName
            }
        }

        return nil
    }

    /// Draw a colored MapPolyline for the given road segment and register it in segmentPolylineMap
    /// so it can be removed when the segment leaves the horizon.
    ///   - MPP (level == 0):        Already rendered as main route
    ///   - Side paths level 1:       Cyan
    ///   - Side paths level 2:       Pink
    ///   - Side paths level 3:       Orange
    ///   - Side paths level 4:       Green
    private func drawSegmentPolyline(localId: Int64, geoPolyline: GeoPolyline, level: Int) {
        // MPP (Most Preferred Path, level == 0) is already rendered as the main route
        // We only draw visual polylines for alternative side-paths (level > 0)
        if level == 0 {
            print("\(Self.LOG_TAG): MPP SEGMENT - localId=\(localId) (already rendered as main route)")
            return
        }

        // Skip if a polyline for this segment is already on the map.
        guard segmentPolylineMap[localId] == nil else { return }

        let color: UIColor
        let colorName: String
        switch level {
        case 1:
            color = UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0) // Cyan - first side-path level
            colorName = "CYAN"
        case 2:
            color = UIColor(red: 1.0, green: 0.2, blue: 0.8, alpha: 0.85) // Pink/Fuchsia - second side-path level
            colorName = "PINK"
        case 3:
            color = UIColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 0.85) // Orange - third side-path level
            colorName = "ORANGE"
        case 4:
            color = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.85) // Green - fourth side-path level
            colorName = "GREEN"
        default:
            return // Don't draw levels beyond 4
        }

        print("\(Self.LOG_TAG): Drawing segment polyline - localId=\(localId), level=\(level), color=\(colorName)")

        do {
            let mapPolyline = try MapPolyline(
                geometry: geoPolyline,
                representation: MapPolyline.SolidRepresentation(
                    lineWidth: MapMeasureDependentRenderSize(
                        sizeUnit: RenderSize.Unit.pixels,
                        size: 25.0
                    ),
                    color: color,
                    capShape: LineCap.round
                )
            )
            mapView.mapScene.addMapPolyline(mapPolyline)
            segmentPolylineMap[localId] = mapPolyline
            print("\(Self.LOG_TAG): Successfully added polyline to map scene - localId=\(localId)")
        } catch {
            print("\(Self.LOG_TAG): MapPolyline instantiation failed: \(error)")
        }
    }

    /// Remove all EH segment polylines from the map.
    private func clearVisualization() {
        for polyline in segmentPolylineMap.values {
            mapView.mapScene.removeMapPolyline(polyline)
        }
        segmentPolylineMap.removeAll()
    }

    /// Log road sign information from a fully loaded segment. Demonstrates how to read
    /// road attributes from SegmentData for MPP segments.
    private func logRoadSigns(segmentData: SegmentData, directedOCMSegmentId: DirectedOCMSegmentId) {
        guard let roadSigns = segmentData.roadSigns, !roadSigns.isEmpty else { return }
        for roadSign in roadSigns {
            if let polyline = segmentData.polyline {
                let roadSignCoordinates = getGeoCoordinatesFromOffsetInMeters(
                    geoPolyline: polyline,
                    offsetInMeters: Double(roadSign.offsetInMeters)
                )
                print("\(ElectronicHorizonHandler.LOG_TAG): RoadSign: type = \(roadSign.roadSignType.rawValue), offsetInMeters = \(roadSign.offsetInMeters), lat/lon: \(roadSignCoordinates.latitude)/\(roadSignCoordinates.longitude), segmentId = \(directedOCMSegmentId.id.localId)")
            }
        }
    }

    /// Convert an offset in meters along a GeoPolyline to GeoCoordinates.
    private func getGeoCoordinatesFromOffsetInMeters(geoPolyline: GeoPolyline, offsetInMeters: Double) -> heresdk.GeoCoordinates {
        return geoPolyline.coordinatesAt(offsetInMeters: offsetInMeters,
                                         direction: .fromBeginning)
    }

    func stop() {
        guard let electronicHorizon = electronicHorizonEngine else { return }

        electronicHorizon.removeElectronicHorizonDelegate(_: electronicHorizonDelegate)
        electronicHorizonDataLoader.removeElectronicHorizonDataLoaderStatusDelegate(_: electronicHorizonDataLoaderStatusDelegate)
        clearVisualization()
        print("\(Self.LOG_TAG): ElectronicHorizonEngine stopped.")
    }

    private static func getSDKNativeEngine() -> SDKNativeEngine {
        guard let sdkNativeEngine = SDKNativeEngine.sharedInstance else {
            fatalError("SDKNativeEngine is not initialized.")
        }
        return sdkNativeEngine
    }

}

private struct SideStreetInfo {
    let streetName: String
    let coordinateAtOffsetFromSegmentStart: GeoCoordinates
    let pathIndex: Int
    let segmentLocalId: Int64
}
