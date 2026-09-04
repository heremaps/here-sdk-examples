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
package com.here.navigationkotlin

import android.util.Log
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoPolyline
import com.here.sdk.core.GeoPolylineDirection
import com.here.sdk.core.engine.*
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.electronichorizon.ElectronicHorizon
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoadedStatus
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoader
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoaderResult
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoaderStatusListener
import com.here.sdk.electronichorizon.ElectronicHorizonEngine
import com.here.sdk.electronichorizon.ElectronicHorizonErrorCode
import com.here.sdk.electronichorizon.ElectronicHorizonListener
import com.here.sdk.electronichorizon.ElectronicHorizonOptions
import com.here.sdk.electronichorizon.ElectronicHorizonPosition
import com.here.sdk.electronichorizon.ElectronicHorizonUpdate
import com.here.sdk.mapdata.*
import com.here.sdk.mapview.LineCap
import com.here.sdk.mapview.MapMeasureDependentRenderSize
import com.here.sdk.mapview.MapPolyline
import com.here.sdk.mapview.MapPolyline.SolidRepresentation
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.RenderSize
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
class ElectronicHorizonHandler(private val mapView: MapView) {

    private var electronicHorizon: ElectronicHorizonEngine? = null
    private val electronicHorizonDataLoader: ElectronicHorizonDataLoader
    private var electronicHorizonListener: ElectronicHorizonListener
    private var electronicHorizonDataLoaderStatusListener: ElectronicHorizonDataLoaderStatusListener

    // Keep track of the last requested electronic horizon update to access its segments
    // when data loading is completed.
    private var lastElectronicHorizon: ElectronicHorizon? = null

    // Segment polyline map: maps the segment's OCM local ID to its drawn MapPolyline.
    // This allows us to remove individual polylines when segments leave the horizon.
    private val segmentPolylineMap: MutableMap<Long, MapPolyline> = HashMap()

    // Controls whether segment polylines are drawn on the map.
    private var isVisualizationEnabled = false

    init {
        electronicHorizonListener = createElectronicHorizonListener()
        electronicHorizonDataLoaderStatusListener =
            createElectronicHorizonDataLoaderStatusListener()

        // Many more options are available, see SegmentDataLoaderOptions in the API Reference.
        val segmentDataLoaderOptions = SegmentDataLoaderOptions()
        segmentDataLoaderOptions.loadRoadSigns = true
        segmentDataLoaderOptions.loadSpeedLimits = true
        segmentDataLoaderOptions.loadRoadAttributes = true
        segmentDataLoaderOptions.loadStreetNamesAndRoadNumbers = true

        // The cache size defines how many road segments are cached locally. A larger cache size
        // can reduce data usage, but requires more storage memory in the cache.
        // A small cache can replace previously loaded segments too early.
        val segmentDataCacheSize = 1000
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

    // Enable or disable the colored segment polyline visualization on the map.
    // When disabled all currently drawn polylines are removed from the map immediately.
    fun toggleVisualization(enabled: Boolean) {
        isVisualizationEnabled = enabled
        if (!enabled) {
            clearVisualization()
        }
        Log.d(LOG_TAG, "EH visualization ${if (enabled) "enabled" else "disabled"}.")
    }

    // Without a route, electronic horizon operates in tracking mode and the most probable path is
    // estimated based on the current location and previous locations.
    // With a route, electronic horizon operates in map-matched mode and the route is used
    // to determine the most probable path. Therefore, the route will determine the main path ahead.
    fun start(route: Route?) {
        // The first entry of the list is for the most preferred path, the second is for the side paths of the first level,
        // the third is for the side paths of the second level, and so on.
        // Each entry defines how far ahead the path should be provided.
        val lookAheadDistancesInMeters = listOf(1000.0, 500.0, 250.0)
        // Segments will be removed by the HERE SDK once passed and the distance to them exceeds trailingDistanceInMeters.
        // Segments are also removed when the vehicle passes the decision point for alternative side paths.
        val trailingDistanceInMeters = 500.0
        val electronicHorizonOptions =
            ElectronicHorizonOptions(lookAheadDistancesInMeters, trailingDistanceInMeters)

        val transportMode: TransportMode = TransportMode.CAR

        try {
            electronicHorizon = ElectronicHorizonEngine(
                this.sDKNativeEngine,
                electronicHorizonOptions,
                transportMode,
                route
            )
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("ElectronicHorizon is not initialized: " + e.error.name)
        }

        // Remove any existing listeners before re-registering.
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

    // Similar to the VisualNavigator, the ElectronicHorizon also needs to be updated with
    // a location - with the difference that the location must be map-matched. Therefore, the
    // location provided by the VisualNavigator can be used directly.
    fun update(mapMatchedLocation: MapMatchedLocation) {
        checkNotNull(electronicHorizon) { "ElectronicHorizon is not initialized. Call start() first." }
        electronicHorizon?.update(mapMatchedLocation)
        Log.d(LOG_TAG, "ElectronicHorizonUpdate mapMatchedLocation received.")
    }

    // Create a listener to get notified about electronic horizon updates while a user moves along the road.
    // This informs on the available segment IDs and indexes so that the actual data can be requested
    // by the ElectronicHorizonDataLoader. It also carries the list of removed segment IDs so that their
    // polylines can be cleared from the map immediately.
    private fun createElectronicHorizonListener(): ElectronicHorizonListener {
        return object : ElectronicHorizonListener {
            override fun onElectronicHorizonUpdated(
                errorCode: ElectronicHorizonErrorCode?,
                electronicHorizonUpdate: ElectronicHorizonUpdate?
            ) {
                if (errorCode != null) {
                    Log.e(LOG_TAG, "ElectronicHorizonUpdate error: " + errorCode.name)
                    return
                }
                Log.d(LOG_TAG, "ElectronicHorizonUpdate received.")

                // The update always carries the vehicle's current position in the horizon tree.
                // pathIndex identifies which path the vehicle is on; pathSegmentIndex identifies
                // the segment within that path; pathSegmentOffsetInMeters gives the offset from the segment start.
                val position: ElectronicHorizonPosition? = electronicHorizonUpdate?.position
                if (position != null) {
                    Log.d(
                        LOG_TAG, "EH position: pathIndex=${position.pathIndex}, " +
                                "pathSegmentIndex=${position.pathSegmentIndex}, " +
                                "offsetInMeters=${position.pathSegmentOffsetInMeters}"
                    )
                }

                // Store last known ElectronicHorizon if present.
                if (electronicHorizonUpdate?.electronicHorizon != null) {
                    lastElectronicHorizon = electronicHorizonUpdate.electronicHorizon
                }

                // Remove map polylines for segments that have left the horizon.
                // Segments are removed by the HERE SDK in two cases:
                //   1. They are behind the vehicle and exceed trailingDistanceInMeters.
                //   2. The vehicle passes the decision point for an alternative side path.
                if (isVisualizationEnabled) {
                    electronicHorizonUpdate?.segmentChanges?.removedIds?.forEach { segmentId ->
                        val localId: Long =
                            (segmentId.ocmSegmentId?.id?.localId ?: return@forEach).toLong()
                        val polyline = segmentPolylineMap.remove(localId)
                        polyline?.let { mapView.mapScene.removeMapPolyline(it) }
                        Log.d("eh segments", "Removing segment polyline - localId=$localId")
                    }
                }

                // Asynchronously start to load required data for the new segments.
                // Use the ElectronicHorizonDataLoaderStatusListener to get notified when new data arrives.
                if (electronicHorizonUpdate?.segmentChanges != null) {
                    electronicHorizonDataLoader.loadData(electronicHorizonUpdate)
                }
            }
        }
    }

    // Handle newly arriving map data segments provided by the ElectronicHorizonDataLoader.
    // This listener is called when the data loader's status is updated and segments are ready.
    // When visualization is enabled, newly loaded segments are drawn as colored polylines.
    private fun createElectronicHorizonDataLoaderStatusListener(): ElectronicHorizonDataLoaderStatusListener {
        return object : ElectronicHorizonDataLoaderStatusListener {
            override fun onElectronicHorizonDataLoaderStatusUpdated(
                electronicHorizonDataLoaderStatuses: Map<Int, ElectronicHorizonDataLoadedStatus>
            ) {
                Log.d(LOG_TAG, "ElectronicHorizonDataLoaderStatus updated.")
                val lastUpdate = lastElectronicHorizon ?: return
                val allPaths = lastUpdate.paths

                for ((loadedLevel, status) in electronicHorizonDataLoaderStatuses) {
                    if (status != ElectronicHorizonDataLoadedStatus.FULLY_LOADED) continue

                    // Level 0 = MPP. Process MPP segments for road sign logging.
                    if (loadedLevel == 0 && allPaths.isNotEmpty()) {
                        val mpp = allPaths[0]
                        for (segment in mpp.segments) {
                            val directedOCMSegmentId = segment.segmentId.ocmSegmentId ?: continue
                            val result = electronicHorizonDataLoader.getSegment(directedOCMSegmentId)
                            if (result.errorCode == null) {
                                logRoadSigns(checkNotNull(result.segmentData), directedOCMSegmentId)
                            }
                        }
                        continue
                    }

                    // Wait until first-level side-path data is fully loaded before logging side streets
                    // that branch directly from the active route.
                    if (loadedLevel == 1) {
                        notifySideStreetInfos(allPaths)
                    }

                    // For side-path levels (level > 0): walk all path segments and use
                    // sidePathIndexes to find paths that branch off at each segment.
                    // sidePathIndexes contains indexes into allPaths[], pointing to branching paths.
                    // Track processed path indexes to avoid redundant getSegment() calls.
                    val processedSidePathIndexes = mutableSetOf<Int>()
                    for (path in allPaths) {
                        for (segment in path.segments) {
                            for (sidePathIndex in segment.sidePathIndexes) {
                                if (sidePathIndex < 0 || sidePathIndex >= allPaths.size) continue
                                if (!processedSidePathIndexes.add(sidePathIndex)) continue
                                val branchingPath = allPaths[sidePathIndex]

                                // Only process branching paths at the loaded level.
                                if (branchingPath.level != loadedLevel) continue

                                Log.d(LOG_TAG, "Branching path index: $sidePathIndex, level: ${branchingPath.level}")

                                // Draw all segments of this branching path.
                                for (branchSegment in branchingPath.segments) {
                                    val directedOCMSegmentId = branchSegment.segmentId.ocmSegmentId ?: continue
                                    val localId = directedOCMSegmentId.id.localId
                                    val result = electronicHorizonDataLoader.getSegment(directedOCMSegmentId)
                                    if (result.errorCode == null) {
                                        val segmentData = checkNotNull(result.segmentData)
                                        if (isVisualizationEnabled) {
                                            val polyline = segmentData.polyline ?: continue
                                            drawSegmentPolyline(localId, polyline, branchingPath.level)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Draw a colored MapPolyline for the given road segment and register it in segmentPolylineMap
    // so it can be removed when the segment leaves the horizon.
    //   - MPP (level == 0):        Already rendered as main route
    //   - Side paths level 1:       Cyan
    //   - Side paths level 2:       Pink
    //   - Side paths level 3:       Orange
    //   - Side paths level 4:       Green
    private fun drawSegmentPolyline(localId: Int, geoPolyline: GeoPolyline, level: Int) {
        // MPP (Most Preferred Path, level == 0) is already rendered as the main route
        // We only draw visual polylines for alternative side-paths (level > 0)
        if (level == 0) {
            Log.d("eh segments", "MPP SEGMENT - localId=$localId (already rendered as main route)")
            return
        }


        val localIdLong: Long = localId.toLong()
        // Skip if a polyline for this segment is already on the map.
        if (segmentPolylineMap.containsKey(localIdLong)) return

        val color: Color = when (level) {
            1 -> Color.valueOf(0f, 1f, 1f, 1.0f)    // Cyan - first side-path level
            2 -> Color.valueOf(1f, 0.2f, 0.8f, 0.85f) // Pink/Fuchsia - second side-path level
            3 -> Color.valueOf(1f, 0.65f, 0f, 0.85f) // Orange - third side-path level
            4 -> Color.valueOf(0f, 1f, 0f, 0.85f) // Green - fourth side-path level
            else -> return // Don't draw levels beyond 4
        }

        val colorName = when (level) {
            1 -> "CYAN"
            2 -> "PINK"
            3 -> "ORANGE"
            4 -> "GREEN"
            else -> "" // unreachable: color when-expression already returns for level > 4
        }

        Log.d(
            "eh segments",
            "Drawing segment polyline - localId=$localId, level=$level, color=$colorName"
        )

        val widthInPixels = 25f
        val mapPolyline: MapPolyline = try {
            MapPolyline(
                geoPolyline,
                SolidRepresentation(
                    MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels.toDouble()),
                    color,
                    LineCap.ROUND
                )
            )
        } catch (e: MapPolyline.Representation.InstantiationException) {
            Log.e(LOG_TAG, "MapPolyline instantiation failed: " + e.error.name)
            return
        } catch (e: MapMeasureDependentRenderSize.InstantiationException) {
            Log.e(LOG_TAG, "MapMeasureDependentRenderSize instantiation failed: " + e.error.name)
            return
        }
        mapView.mapScene.addMapPolyline(mapPolyline)
        segmentPolylineMap[localIdLong] = mapPolyline
        Log.d("eh segments", "Successfully added polyline to map scene - localId=$localId")
    }

    // Remove all EH segment polylines from the map.
    private fun clearVisualization() {
        for (polyline in segmentPolylineMap.values) {
            mapView.mapScene.removeMapPolyline(polyline)
        }
        segmentPolylineMap.clear()
    }

    // Finds first-level side streets whose parent is the currently followed navigation path.
    private fun notifySideStreetInfos(allPaths: List<com.here.sdk.electronichorizon.ElectronicHorizonPath>) {
        for ((pathIndex, path) in allPaths.withIndex()) {
            if (path.level != 1 || path.parentPathIndex == null || path.parentPathIndex != 0) {
                continue
            }

            val sideStreetInfo = findSideStreetInfo(path, pathIndex) ?: continue
            Log.d(
                LOG_TAG,
                "SideStreetName near active route: ${sideStreetInfo.streetName} at lat/lon: " +
                    "${sideStreetInfo.coordinateAtOffsetFromSegmentStart.latitude}/" +
                    "${sideStreetInfo.coordinateAtOffsetFromSegmentStart.longitude}, " +
                    "pathIndex=${sideStreetInfo.pathIndex}, segmentLocalId=${sideStreetInfo.segmentLocalId}"
            )
        }
    }

    private fun findSideStreetInfo(
        branchingPath: com.here.sdk.electronichorizon.ElectronicHorizonPath,
        pathIndex: Int
    ): SideStreetInfo? {
        for (segment in branchingPath.segments) {
            val directedOCMSegmentId = segment.segmentId.ocmSegmentId ?: continue
            val result = electronicHorizonDataLoader.getSegment(directedOCMSegmentId)
            if (result.errorCode != null || result.segmentData == null) {
                continue
            }

            val segmentData = result.segmentData!!
            val sideStreetName = getFirstStreetLabel(segmentData) ?: continue
            val polyline = segmentData.polyline ?: continue
            val sideStreetCoordinates = polyline.coordinatesAtOffsetInMeters(
                SIDE_STREET_LOG_OFFSET_METERS,
                GeoPolylineDirection.FROM_BEGINNING
            )
            return SideStreetInfo(
                sideStreetName,
                sideStreetCoordinates,
                pathIndex,
                directedOCMSegmentId.id.localId
            )
        }

        return null
    }

    // Returns the first non-empty street label (street name or road number).
    private fun getFirstStreetLabel(segmentData: SegmentData): String? {
        val segmentSpans = segmentData.spans ?: return null
        if (segmentSpans.isEmpty()) {
            return null
        }

        for (segmentSpanData in segmentSpans) {
            var streetName: String? = segmentSpanData.streetNames?.getDefaultValue()
            if (streetName.isNullOrBlank()) {
                streetName = segmentSpanData.roadNumbers?.getDefaultValue()
            }
            if (!streetName.isNullOrBlank()) {
                return streetName
            }
        }

        return null
    }

    // Log road sign information from a fully loaded segment. Demonstrates how to read
    // road attributes from SegmentData for MPP segments.
    private fun logRoadSigns(segmentData: SegmentData, directedOCMSegmentId: DirectedOCMSegmentId) {
        val roadSigns: List<RoadSign>? = segmentData.roadSigns
        if (roadSigns == null || roadSigns.isEmpty()) return
        val polyline = segmentData.polyline ?: return
        for (roadSign in roadSigns) {
            val roadSignCoordinates: GeoCoordinates = getGeoCoordinatesFromOffsetInMeters(
                polyline,
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
        clearVisualization()
        Log.d(LOG_TAG, "ElectronicHorizon stopped.")
    }

    private val sDKNativeEngine: SDKNativeEngine
        get() {
            val sdkNativeEngine: SDKNativeEngine = SDKNativeEngine.getSharedInstance()!!
            return sdkNativeEngine
        }

    companion object {
        // Optional: Using a small offset can help mark/log the side street more clearly for visualization.
        private const val SIDE_STREET_LOG_OFFSET_METERS = 20.0
        private val LOG_TAG: String = ElectronicHorizonHandler::class.java.name
    }

    private data class SideStreetInfo(
        val streetName: String,
        // Representative point on the matched side-street segment.
        val coordinateAtOffsetFromSegmentStart: GeoCoordinates,
        val pathIndex: Int,
        val segmentLocalId: Int,
    )
}
