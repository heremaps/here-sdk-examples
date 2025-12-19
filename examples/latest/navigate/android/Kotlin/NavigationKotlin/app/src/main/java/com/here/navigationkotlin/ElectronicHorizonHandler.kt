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
package com.here.navigation

import android.util.Log
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoPolyline
import com.here.sdk.core.GeoPolylineDirection
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.electronichorizon.ElectronicHorizon
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoadedStatus
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoader
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoaderResult
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoaderStatusListener
import com.here.sdk.electronichorizon.ElectronicHorizonListener
import com.here.sdk.electronichorizon.ElectronicHorizonOptions
import com.here.sdk.electronichorizon.ElectronicHorizonUpdate
import com.here.sdk.mapdata.DirectedOCMSegmentId
import com.here.sdk.mapdata.SegmentData
import com.here.sdk.mapdata.SegmentDataLoaderOptions
import com.here.sdk.navigation.MapMatchedLocation
import com.here.sdk.navigation.RoadSign
import com.here.sdk.routing.Route
import com.here.sdk.transport.TransportMode

// A class that handles electronic horizon related operations.
// This is not required for navigation, but can be used to get information about the road network ahead of the user.
// For this example, selected retrieved information is logged, such as road signs.
//
// Usage:
// 1. Create an instance of this class.
// 2. Call start(route) to initialize the ElectronicHorizon.
//    Optionally, null can be provided to operate in tracking mode without a route.
// 3. Call update(mapMatchedLocation) with a map-matched location to update the ElectronicHorizon.
// 4. Call stop() to stop getting ElectronicHorizon events.
//
// Note that in this example app we only enable the electronic horizon in car mode while following a route.
//
// For convenience, the ElectronicHorizonDataLoader wraps a SegmentDataLoader that allows to
// continuously load required map data segments based on the most preferred path(s) of the ElectronicHorizon.
// When it does not find cached, prefetched or preloaded region data for a segment,
// it will asynchronously request the data from the HERE backend services.
// It is recommended to use a prefetcher to prefetch region data along the route in advance (not shown in this class).
class ElectronicHorizonHandler {
    private var electronicHorizon: ElectronicHorizon? = null
    private val electronicHorizonDataLoader: ElectronicHorizonDataLoader
    private var electronicHorizonListener: ElectronicHorizonListener
    private var electronicHorizonDataLoaderStatusListener: ElectronicHorizonDataLoaderStatusListener

    // Keep track of the last requested electronic horizon update to access its segments
    // when data loading is completed.
    private var lastRequestedElectronicHorizonUpdate: ElectronicHorizonUpdate? = null

    init {
        electronicHorizonListener = createElectronicHorizonListener()
        electronicHorizonDataLoaderStatusListener =
            createElectronicHorizonDataLoaderStatusListener()

        // Many more options are available, see SegmentDataLoaderOptions in the API Reference.
        val segmentDataLoaderOptions = SegmentDataLoaderOptions()
        segmentDataLoaderOptions.loadRoadSigns = true
        segmentDataLoaderOptions.loadSpeedLimits = true
        segmentDataLoaderOptions.loadRoadAttributes = true

        // The cache size defines how many road segments are cached locally. A larger cache size
        // can reduce data usage, but requires more storage memory in the cache.
        val segmentDataCacheSize = 10
        try {
            electronicHorizonDataLoader = ElectronicHorizonDataLoader(
                this.sDKNativeEngine,
                segmentDataLoaderOptions,
                segmentDataCacheSize
            )
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("ElectronicHorizonDataLoader is not initialized: " + e.error.name)
        }
    }

    // Without a route, electronic horizon operates in tracking mode and the most probable path is
    // estimated based on the current location and previous locations.
    // With a route, electronic horizon operates in map-matched mode and the route is used
    // to determine the most probable path. Therefore, the route will determine the main path ahead.
    fun start(route: Route?) {
        // The first entry of the list is for the most preferred path, the second is for the side paths of the first level,
        // the third is for the side paths of the second level, and so on.
        // Each entry defines how far ahead the path should be provided.
        val lookAheadDistancesInMeters = mutableListOf<Double?>(1000.0, 500.0, 250.0)
        // Segments will be removed by the HERE SDK once passed and distance to it exceeds the trailingDistanceInMeters.
        val trailingDistanceInMeters = 500.0
        val electronicHorizonOptions: ElectronicHorizonOptions =
            ElectronicHorizonOptions(lookAheadDistancesInMeters, trailingDistanceInMeters)

        val transportMode: TransportMode = TransportMode.CAR

        try {
            electronicHorizon = ElectronicHorizon(
                this.sDKNativeEngine,
                electronicHorizonOptions,
                transportMode,
                route
            )
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("ElectronicHorizon is not initialized: " + e.error.name)
        }

        // Remove any existing electronic horizon listeners.
        stop()

        // Create and add new listeners.
        electronicHorizonListener = createElectronicHorizonListener()
        electronicHorizon?.addElectronicHorizonListener(electronicHorizonListener)
        electronicHorizonDataLoaderStatusListener =
            createElectronicHorizonDataLoaderStatusListener()
        electronicHorizonDataLoader.addElectronicHorizonDataLoaderStatusListener(
            electronicHorizonDataLoaderStatusListener
        )
        Log.d(LOG_TAG, "ElectronicHorizon started.")
    }

    // Similar like the VisualNavigator, the ElectronicHorizon also needs to be updated with
    // a location, with the difference that the location must be map-matched. Therefore, the
    // location provided by the VisualNavigator can be used.
    fun update(mapMatchedLocation: MapMatchedLocation) {
        checkNotNull(electronicHorizon) { "ElectronicHorizon is not initialized. Call start() first." }
        electronicHorizon?.update(mapMatchedLocation)
        Log.d(LOG_TAG, "ElectronicHorizonUpdate mapMatchedLocation received.")
    }

    // Create a listener to get notified about electronic horizon updates while a user moves along the road.
    // This only informs on the available segement IDs and indexes, so that the actual data can be requested
    // by the ElectronicHorizonDataLoader.
    private fun createElectronicHorizonListener(): ElectronicHorizonListener {
        return object : ElectronicHorizonListener {
            override fun onElectronicHorizonUpdated(electronicHorizonUpdate: ElectronicHorizonUpdate) {
                Log.d(LOG_TAG, "ElectronicHorizonUpdate received.")
                // Asynchronously start to load required data for the new segments.
                // Use the ElectronicHorizonDataLoaderStatusListener to get notified when new data is arriving.
                lastRequestedElectronicHorizonUpdate = electronicHorizonUpdate
                electronicHorizonDataLoader.loadData(electronicHorizonUpdate)
            }
        }
    }

    // Handle newly arriving map data segments provided by the ElectronicHorizonDataLoader.
    // This listener is called when the status of the data loader is updated and new segments have been added
    // or removed.
    private fun createElectronicHorizonDataLoaderStatusListener(): ElectronicHorizonDataLoaderStatusListener {
        return object : ElectronicHorizonDataLoaderStatusListener {
            override fun onElectronicHorizonDataLoaderStatusUpdated(statusMap: MutableMap<Int?, ElectronicHorizonDataLoadedStatus?>) {
                Log.d(LOG_TAG, "ElectronicHorizonDataLoaderStatus updated.")
                val lastUpdate = lastRequestedElectronicHorizonUpdate ?: return

                // Access the segments that were part of the last requested electronic horizon update.
                // Newly added segments were requested to be loaded in the call to electronicHorizonDataLoader.loadData().
                // Internally, the data loader keeps track of which segments were requested and keeps updating
                // the provided ElectronicHorizonUpdate instance over time.
                for (entry in statusMap.entries) {
                    val status: ElectronicHorizonDataLoadedStatus? = entry.value
                    // The integer key represents the level of the most preferred path (0) and side paths (1, 2, ...).
                    val level: Int = entry.key!!
                    // This example shows only how to look at the fully loaded segments of the most preferred path (level 0).
                    if (level == 0 && status == ElectronicHorizonDataLoadedStatus.FULLY_LOADED) {
                        // Now, level 0 segments have been fully loaded and you can access their data.
                        // The electronicHorizonPaths list contains segments from all levels, so you need to filter for level 0 below.
                        val electronicHorizonPaths = lastUpdate.electronicHorizonPaths
                        for (electronicHorizonPath in electronicHorizonPaths) {
                            val electronicHorizonPathSegments = electronicHorizonPath.segments
                            for (segment in electronicHorizonPathSegments) {
                                // For any segment you can check the parentPathIndex to determine
                                // if it is part of the most preferred path (MPP) or a side path.
                                if (segment.parentPathIndex != 0) {
                                    // Skip side path segments as we only want to log MPP segment data in this example.
                                    // And we only want to log fully loaded segments.
                                    continue
                                }

                                val directedOCMSegmentId: DirectedOCMSegmentId = segment.segmentId.ocmSegmentId ?: continue

                                // Retrieving segment data from the loader is executed synchronous. However, since the data has been
                                // already loaded, this is a fast operation.
                                val result: ElectronicHorizonDataLoaderResult =
                                    electronicHorizonDataLoader.getSegment(directedOCMSegmentId)
                                if (result.errorCode == null) {
                                    // When errorCode is null, segmentData is guaranteed to be non-null.
                                    val segmentData: SegmentData = checkNotNull(result.segmentData)
                                    // Access the data that was requested to be loaded in SegmentDataLoaderOptions.
                                    // For this example, we just log road signs.
                                    val roadSigns: MutableList<RoadSign>? =
                                        segmentData.getRoadSigns()
                                    if (roadSigns == null || roadSigns.isEmpty()) {
                                        continue
                                    }
                                    for (roadSign in roadSigns) {
                                        val roadSignCoordinates: GeoCoordinates =
                                            getGeoCoordinatesFromOffsetInMeters(
                                                segmentData.getPolyline(),
                                                roadSign.offsetInMeters.toDouble()
                                            )
                                        Log.d(
                                            LOG_TAG, ("RoadSign: type = "
                                                    + roadSign.roadSignType.name
                                                    + ", offsetInMeters = " + roadSign.offsetInMeters
                                                    + ", lat/lon: " + roadSignCoordinates.latitude + "/" + roadSignCoordinates.longitude
                                                    + ", segmentId = " + directedOCMSegmentId.id.localId)
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

    // Convert an offset in meters along a GeoPolyline to GeoCoordinates using the HERE SDK's coordinatesAtOffsetInMeters.
    private fun getGeoCoordinatesFromOffsetInMeters(
        geoPolyline: GeoPolyline,
        offsetInMeters: Double
    ): GeoCoordinates {
        return geoPolyline.coordinatesAtOffsetInMeters(
            offsetInMeters,
            GeoPolylineDirection.FROM_BEGINNING
        )
    }

    fun stop() {
        electronicHorizon?.removeElectronicHorizonListener(electronicHorizonListener)
        electronicHorizonDataLoader.removeElectronicHorizonDataLoaderStatusListener(
            electronicHorizonDataLoaderStatusListener
        )
        Log.d(LOG_TAG, "ElectronicHorizon stopped.")
    }

    private val sDKNativeEngine: SDKNativeEngine
        get() {
            val sdkNativeEngine: SDKNativeEngine = SDKNativeEngine.getSharedInstance()!!
            return sdkNativeEngine
        }

    companion object {
        private val LOG_TAG: String = ElectronicHorizonHandler::class.java.getName()
    }
}
