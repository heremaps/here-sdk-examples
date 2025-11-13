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

/// A class that handles electronic horizon related operations.
/// This is not required for navigation, but can be used to get information about the road network ahead of the user.
/// For this example, selected retrieved information is logged, such as road signs.
///
/// Usage:
/// 1. Create an instance of this class.
/// 2. Call start(route) to initialize the ElectronicHorizon.
///    Optionally, nil can be provided to operate in tracking mode without a route.
/// 3. Call update(mapMatchedLocation) with a map-matched location to update the ElectronicHorizon.
/// 4. Call stop() to stop getting ElectronicHorizon events.
///
/// Note that in this example app we only enable the electronic horizon in car mode while following a route.
///
/// For convenience, the ElectronicHorizonDataLoader wraps a SegmentDataLoader that allows to
/// continuously load required map data segments based on the most preferred path(s) of the ElectronicHorizon.
/// When it does not find cached, prefetched or preloaded region data for a segment,
/// it will asynchronously request the data from the HERE backend services.
/// It is recommended to use a prefetcher to prefetch region data along the route in advance (not shown in this class).
class ElectronicHorizonHandler {

    private static let LOG_TAG = String(describing: ElectronicHorizonHandler.self)

    private var electronicHorizon: ElectronicHorizon?
    private let electronicHorizonDataLoader: ElectronicHorizonDataLoader

    private lazy var electronicHorizonDelegate: ElectronicHorizonDelegate = {
        return createElectronicHorizonDelegate()
    }()

    private lazy var electronicHorizonDataLoaderStatusDelegate: ElectronicHorizonDataLoaderStatusDelegate = {
        return createElectronicHorizonDataLoaderStatusDelegate()
    }()
    
    // Keep track of the last requested electronic horizon update to access its segments
    // when data loading is completed.
    private var lastRequestedElectronicHorizonUpdate: ElectronicHorizonUpdate?

    init() {
        // Many more options are available, see SegmentDataLoaderOptions in the API Reference.
        var segmentDataLoaderOptions = SegmentDataLoaderOptions()
        segmentDataLoaderOptions.loadRoadSigns = true
        segmentDataLoaderOptions.loadSpeedLimits = true
        segmentDataLoaderOptions.loadRoadAttributes = true

        // The cache size defines how many road segments are cached locally. A larger cache size
        // can reduce data usage, but requires more storage memory in the cache.
        let segmentDataCacheSize = 10
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
    
    /// Without a route, electronic horizon operates in tracking mode and the most probable path is
    /// estimated based on the current location and previous locations.
    /// With a route, electronic horizon operates in map-matched mode and the route is used
    /// to determine the most probable path. Therefore, the route will determine the main path ahead.
    func start(route: Route?) {
        // The first entry of the list is for the most preferred path, the second is for the side paths of the first level,
        // the third is for the side paths of the second level, and so on.
        // Each entry defines how far ahead the path should be provided.
        let lookAheadDistancesInMeters = [1000.0, 500.0, 250.0]
        // Segments will be removed by the HERE SDK once passed and distance to it exceeds the trailingDistanceInMeters.
        let trailingDistanceInMeters = 500.0
        let electronicHorizonOptions = ElectronicHorizonOptions(
            lookAheadDistancesInMeters: lookAheadDistancesInMeters,
            trailingDistanceInMeters: trailingDistanceInMeters
        )

        let transportMode = TransportMode.car

        do {
            electronicHorizon = try ElectronicHorizon(
                sdkEngine: ElectronicHorizonHandler.getSDKNativeEngine(),
                options: electronicHorizonOptions,
                transportMode: transportMode,
                route: route
            )
        } catch let instantiationError {
            fatalError("ElectronicHorizon is not initialized: \(instantiationError)")
        }

        // Remove any existing electronic horizon delegates.
        stop()

        // Create and add new delegates.
        electronicHorizonDelegate = createElectronicHorizonDelegate()
        electronicHorizon!.addElectronicHorizonListener(electronicHorizonListener: electronicHorizonDelegate)

        electronicHorizonDataLoaderStatusDelegate = createElectronicHorizonDataLoaderStatusDelegate()
        electronicHorizonDataLoader.addElectronicHorizonDataLoaderStatusListener(electronicHorizonListener: electronicHorizonDataLoaderStatusDelegate)

        print("\(Self.LOG_TAG): ElectronicHorizon started.")
    }

    /// Similar like the VisualNavigator, the ElectronicHorizon also needs to be updated with
    /// a location, with the difference that the location must be map-matched. Therefore, the
    /// location provided by the VisualNavigator can be used.
    func update(mapMatchedLocation: MapMatchedLocation) {
        guard let electronicHorizon = electronicHorizon else {
            fatalError("ElectronicHorizon is not initialized. Call start() first.")
        }
        electronicHorizon.update(mapMatchedLocation: mapMatchedLocation)
        print("\(Self.LOG_TAG): ElectronicHorizonUpdate mapMatchedLocation received.")
    }

    /// Create a delegate to get notified about electronic horizon updates while a user moves along the road.
    /// This only informs on the available segment IDs and indexes, so that the actual data can be requested
    /// by the ElectronicHorizonDataLoader.
    private func createElectronicHorizonDelegate() -> ElectronicHorizonDelegate {
        class EHDelegate: ElectronicHorizonDelegate {
            weak var handler: ElectronicHorizonHandler?

            init(handler: ElectronicHorizonHandler) {
                self.handler = handler
            }

            func onElectronicHorizonUpdated(electronicHorizonUpdate: ElectronicHorizonUpdate) {
                print("\(ElectronicHorizonHandler.LOG_TAG): ElectronicHorizonUpdate received.")
                // Asynchronously start to load required data for the new segments.
                // Use the ElectronicHorizonDataLoaderStatusDelegate to get notified when new data is arriving.
                handler?.lastRequestedElectronicHorizonUpdate = electronicHorizonUpdate
                if let update = handler?.lastRequestedElectronicHorizonUpdate {
                    handler?.electronicHorizonDataLoader.loadData(electronicHorizonUpdate: update)
                }
            }
        }
        return EHDelegate(handler: self)
    }

    /// Handle newly arriving map data segments provided by the ElectronicHorizonDataLoader.
    /// This delegate is called when the status of the data loader is updated and new segments have been loaded.
    private func createElectronicHorizonDataLoaderStatusDelegate() -> ElectronicHorizonDataLoaderStatusDelegate {
        class EHStatusDelegate: ElectronicHorizonDataLoaderStatusDelegate {
            weak var handler: ElectronicHorizonHandler?

            init(handler: ElectronicHorizonHandler) {
                self.handler = handler
            }

            func onElectronicHorizonDataLoaderStatusUpdated(electronicHorizonDataLoaderStatuses statusMap: [Int32: ElectronicHorizonDataLoadedStatus]) {
                print("\(ElectronicHorizonHandler.LOG_TAG): ElectronicHorizonDataLoaderStatus updated.")

                guard let handler = handler,
                      let lastUpdate = handler.lastRequestedElectronicHorizonUpdate else { return }

                // Access the segments that were part of the last requested electronic horizon update.
                // These segments were requested to be loaded in the call to electronicHorizonDataLoader.loadData().
                // Internally, the data loader keeps track of which segments were requested for loading and provides them
                // in order - i.e. a call to electronicHorizonDataLoader.loadData() is followed by a call to this delegate with the
                // loaded status for the segments that were part of that previous request.
                for (level, status) in statusMap {
                    // The integer key represents the level of the most preferred path (0) and side paths (1, 2, ...).
                    // For this example, we only look into fully loaded segments of the most preferred path (level 0).
                    if status == .fullyLoaded && level == 0 {
                        // Now, we know that all level 0 segments have been fully loaded and we can access their data.
                        // Note that addedSegments still contains all levels, so we need to filter for level 0 segments below.
                        for segment in lastUpdate.addedSegments {
                            // For any segment you can check the parentPathIndex to determine
                            // if it is part of the most preferred path (MPP) or a side path.
                            if segment.parentPathIndex != 0 {
                                // Skip side path segments as we only want to log MPP segment data in this example.
                                // And we only want to log fully loaded segments.
                                continue
                            }

                            guard let directedOCMSegmentId = segment.segmentId.ocmSegmentId else {
                                continue
                            }

                            // Retrieving segment data from the loader is executed synchronous. However, since the data has been
                            // already loaded, this is a fast operation.
                            let result = handler.electronicHorizonDataLoader.getSegment(segmentId: directedOCMSegmentId.id)
                            if result.errorCode == nil, let segmentData = result.segmentData {
                                // Access the data that was requested to be loaded in SegmentDataLoaderOptions.
                                // For this example, we just log road signs.
                                guard let roadSigns = segmentData.roadSigns, !roadSigns.isEmpty else {
                                    continue
                                }
                                for roadSign in roadSigns {
                                    let roadSignCoordinates = handler.getGeoCoordinatesFromOffsetInMeters(
                                        geoPolyline: segmentData.polyline,
                                        offsetInMeters: Double(roadSign.offsetInMeters)
                                    )
                                    print("\(ElectronicHorizonHandler.LOG_TAG): RoadSign: type = \(roadSign.roadSignType.rawValue), offsetInMeters = \(roadSign.offsetInMeters), lat/lon: \(roadSignCoordinates.latitude)/\(roadSignCoordinates.longitude), segmentId = \(directedOCMSegmentId.id.localId)")
                                }
                            }
                        }
                    }
                }
            }
        }

        return EHStatusDelegate(handler: self)
    }

    /// Convert an offset in meters along a GeoPolyline to GeoCoordinates using the HERE SDK's coordinatesAtOffsetInMeters.
    private func getGeoCoordinatesFromOffsetInMeters(geoPolyline: GeoPolyline, offsetInMeters: Double) -> heresdk.GeoCoordinates {
        return geoPolyline.coordinatesAt(offsetInMeters: offsetInMeters,
                                         direction: .fromBeginning)
    }

    func stop() {
        guard let electronicHorizon = electronicHorizon else { return }

        electronicHorizon.removeElectronicHorizonListener(electronicHorizonListener: electronicHorizonDelegate)
        electronicHorizonDataLoader.removeElectronicHorizonDataLoaderStatusListener(electronicHorizonListener: electronicHorizonDataLoaderStatusDelegate)
        print("\(Self.LOG_TAG): ElectronicHorizon stopped.")
    }
   
    private static func getSDKNativeEngine() -> SDKNativeEngine {
        guard let sdkNativeEngine = SDKNativeEngine.sharedInstance else {
            fatalError("SDKNativeEngine is not initialized.")
        }
        return sdkNativeEngine
    }

}
