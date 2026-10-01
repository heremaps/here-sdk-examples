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

package com.here.navigation;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.GeoPolylineDirection;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.electronichorizon.ElectronicHorizon;
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoadedStatus;
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoader;
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoaderResult;
import com.here.sdk.electronichorizon.ElectronicHorizonDataLoaderStatusListener;
import com.here.sdk.electronichorizon.ElectronicHorizonEngine;
import com.here.sdk.electronichorizon.ElectronicHorizonErrorCode;
import com.here.sdk.electronichorizon.ElectronicHorizonListener;
import com.here.sdk.electronichorizon.ElectronicHorizonOptions;
import com.here.sdk.electronichorizon.ElectronicHorizonPath;
import com.here.sdk.electronichorizon.ElectronicHorizonPosition;
import com.here.sdk.electronichorizon.ElectronicHorizonSegment;
import com.here.sdk.electronichorizon.ElectronicHorizonSegmentId;
import com.here.sdk.electronichorizon.ElectronicHorizonUpdate;
import com.here.sdk.mapdata.DirectedOCMSegmentId;
import com.here.sdk.mapdata.SegmentData;
import com.here.sdk.mapdata.SegmentDataLoaderOptions;
import com.here.sdk.mapdata.SegmentSpanData;
import com.here.sdk.mapview.LineCap;
import com.here.sdk.mapview.MapMeasureDependentRenderSize;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.RenderSize;
import com.here.sdk.navigation.MapMatchedLocation;
import com.here.sdk.navigation.RoadSign;
import com.here.sdk.routing.Route;
import com.here.sdk.transport.TransportMode;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

// A class that handles electronic horizon related operations.
// This is not required for navigation, but can be used to get information about the road network ahead of the user.
// For this example, selected retrieved information is logged, such as road signs.
//
// Usage:
// 1. Create an instance of this class.
// 2. Call start(route) to initialize the ElectronicHorizonEngine.
//    Optionally, null can be provided to operate in tracking mode without a route.
// 3. Call update(mapMatchedLocation) with a map-matched location to update the ElectronicHorizonEngine.
// 4. Call stop() to stop getting ElectronicHorizonEngine events.
//
// Note that in this example app we only enable the electronic horizon in car mode while following a route.
//
// For convenience, the ElectronicHorizonDataLoader wraps a SegmentDataLoader that allows to
// continuously load required map data segments based on the most preferred path(s) of the ElectronicHorizonEngine.
// When it does not find cached, prefetched or preloaded region data for a segment,
// it will asynchronously request the data from the HERE backend services.
// It is recommended to use a prefetcher to prefetch region data along the route in advance (not shown in this class).
public class ElectronicHorizonHandler {

    private static final String LOG_TAG = ElectronicHorizonHandler.class.getName();
    // Optional: Using a small offset can help mark/log the side street more clearly for visualization.
    private static final int SIDE_STREET_LOG_OFFSET_METERS = 20;

    private final MapView mapView;
    @Nullable
    private ElectronicHorizonEngine electronicHorizonEngine;
    private final ElectronicHorizonDataLoader electronicHorizonDataLoader;
    private ElectronicHorizonListener electronicHorizonListener;
    private ElectronicHorizonDataLoaderStatusListener electronicHorizonDataLoaderStatusListener;

    // Keep track of the last electronic horizon to access its segments
    // when data loading is completed.
    private ElectronicHorizon lastElectronicHorizon;

    // Segment polyline map: maps the segment's OCM local ID to its drawn MapPolyline.
    // This allows individual polylines to be removed when segments leave the horizon.
    private final Map<Long, MapPolyline> segmentPolylineMap = new HashMap<>();

    // Controls whether segment polylines are drawn on the map.
    private boolean isVisualizationEnabled = false;

    public ElectronicHorizonHandler(@NonNull MapView mapView) {
        this.mapView = mapView;
        electronicHorizonListener = createElectronicHorizonListener();
        electronicHorizonDataLoaderStatusListener = createElectronicHorizonDataLoaderStatusListener();

        // Many more options are available, see SegmentDataLoaderOptions in the API Reference.
        SegmentDataLoaderOptions segmentDataLoaderOptions = new SegmentDataLoaderOptions();
        segmentDataLoaderOptions.loadRoadSigns = true;
        segmentDataLoaderOptions.loadSpeedLimits = true;
        segmentDataLoaderOptions.loadRoadAttributes = true;
        segmentDataLoaderOptions.loadStreetNamesAndRoadNumbers = true;

        // The cache size defines how many road segments are cached locally. A larger cache size
        // can reduce data usage, but requires more storage memory in the cache.
        // A small cache can replace previously loaded segments too early.
        int segmentDataCacheSize = 1000;
        try {
            electronicHorizonDataLoader = new ElectronicHorizonDataLoader(getSDKNativeEngine(), segmentDataLoaderOptions, segmentDataCacheSize);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("ElectronicHorizonDataLoader is not initialized: " + e.error.name());
        }
    }

    // Enable or disable the colored segment polyline visualization on the map.
    // When disabled all currently drawn polylines are removed from the map immediately.
    public void toggleVisualization(boolean enabled) {
        isVisualizationEnabled = enabled;
        if (!enabled) {
            clearVisualization();
        }
    }

    // Without a route, electronic horizon operates in tracking mode and the most probable path is
    // estimated based on the current location and previous locations.
    // With a route, electronic horizon operates in map-matched mode and the route is used
    // to determine the most probable path. Therefore, the route will determine the main path ahead.
    public void start(@Nullable Route route) {
        // The first entry of the list is for the most preferred path, the second is for the side paths of the first level,
        // the third is for the side paths of the second level, and so on.
        // Each entry defines how far ahead the path should be provided.
        List<Double> lookAheadDistancesInMeters = List.of(1000.0, 500.0, 250.0);
        // Segments will be removed by the HERE SDK once passed and the distance to them exceeds trailingDistanceInMeters.
        // Segments are also removed when the vehicle passes the decision point for alternative side paths.
        double trailingDistanceInMeters = 500;
        ElectronicHorizonOptions electronicHorizonOptions = new ElectronicHorizonOptions(lookAheadDistancesInMeters, trailingDistanceInMeters);

        TransportMode transportMode = TransportMode.CAR;

        try {
            electronicHorizonEngine = new ElectronicHorizonEngine(getSDKNativeEngine(), electronicHorizonOptions, transportMode, route);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("ElectronicHorizonEngine is not initialized: " + e.error.name());
        }

        // Remove any existing listeners before re-registering.
        stop();

        // Create and add new listeners.
        electronicHorizonListener = createElectronicHorizonListener();
        electronicHorizonEngine.addElectronicHorizonListener(electronicHorizonListener);

        electronicHorizonDataLoaderStatusListener = createElectronicHorizonDataLoaderStatusListener();
        electronicHorizonDataLoader.addElectronicHorizonDataLoaderStatusListener(electronicHorizonDataLoaderStatusListener);
        Log.d(LOG_TAG, "ElectronicHorizonEngine started.");
    }

    // Similar to the VisualNavigator, the ElectronicHorizonEngine also needs to be updated with
    // a location - with the difference that the location must be map-matched. Therefore, the
    // location provided by the VisualNavigator can be used directly.
    public void update(@NonNull MapMatchedLocation mapMatchedLocation) {
        if (electronicHorizonEngine == null) {
            throw new IllegalStateException("ElectronicHorizonEngine is not initialized. Call start() first.");
        }
        electronicHorizonEngine.update(mapMatchedLocation);
        Log.d(LOG_TAG, "ElectronicHorizonUpdate mapMatchedLocation received.");
    }

    // Create a listener to get notified about electronic horizon updates while a user moves along the road.
    // This informs on the available segment IDs and indexes so that the actual data can be requested
    // by the ElectronicHorizonDataLoader. It also carries removed segment IDs so their polylines
    // can be cleared from the map immediately.
    private ElectronicHorizonListener createElectronicHorizonListener() {
        return new ElectronicHorizonListener() {
            @Override
            public void onElectronicHorizonUpdated(@Nullable ElectronicHorizonErrorCode errorCode,
                                                   @NonNull ElectronicHorizonUpdate electronicHorizonUpdate) {
                if (errorCode != null) {
                    Log.e(LOG_TAG, "ElectronicHorizonUpdate error: " + errorCode.name());
                    return;
                }
                Log.d(LOG_TAG, "ElectronicHorizonUpdate received.");

                // The update always carries the vehicle's current position in the horizon tree.
                ElectronicHorizonPosition position = electronicHorizonUpdate.position;
                Log.d(LOG_TAG, "EH position: pathIndex=" + position.pathIndex
                        + ", pathSegmentIndex=" + position.pathSegmentIndex
                        + ", offsetInMeters=" + position.pathSegmentOffsetInMeters);

                // Store last known horizon if present.
                if (electronicHorizonUpdate.electronicHorizon != null) {
                    lastElectronicHorizon = electronicHorizonUpdate.electronicHorizon;
                }

                // Remove map polylines for segments that have left the horizon.
                // Segments are removed by the HERE SDK in two cases:
                //   1. They are behind the vehicle and exceed trailingDistanceInMeters.
                //   2. The vehicle passes the decision point for an alternative side path.
                if (isVisualizationEnabled && electronicHorizonUpdate.segmentChanges != null) {
                    for (ElectronicHorizonSegmentId segmentId : electronicHorizonUpdate.segmentChanges.removedIds) {
                        if (segmentId.ocmSegmentId == null) continue;
                        long localId = segmentId.ocmSegmentId.id.localId;
                        MapPolyline polyline = segmentPolylineMap.remove(localId);
                        if (polyline != null) {
                            Log.d("eh segments", "Removing segment polyline - localId=" + localId);
                            mapView.getMapScene().removeMapPolyline(polyline);
                        }
                    }
                }

                // Asynchronously start to load required data for the new segments.
                // Use the ElectronicHorizonDataLoaderStatusListener to get notified when new data arrives.
                if (electronicHorizonUpdate.segmentChanges != null) {
                    electronicHorizonDataLoader.loadData(electronicHorizonUpdate);
                }
            }
        };
    }

    // Handle newly arriving map data segments provided by the ElectronicHorizonDataLoader.
    // This listener is called when the data loader's status is updated and segments are ready.
    // When visualization is enabled, newly loaded segments are drawn as colored polylines on the map.
    private ElectronicHorizonDataLoaderStatusListener createElectronicHorizonDataLoaderStatusListener() {
        return new ElectronicHorizonDataLoaderStatusListener() {
            @Override
            public void onElectronicHorizonDataLoaderStatusUpdated(@NonNull Map<Integer, ElectronicHorizonDataLoadedStatus> statusMap) {
                Log.d(LOG_TAG, "ElectronicHorizonDataLoaderStatus updated.");

                if (lastElectronicHorizon == null) {
                    return;
                }

                List<ElectronicHorizonPath> allPaths = lastElectronicHorizon.paths;

                for (Map.Entry<Integer, ElectronicHorizonDataLoadedStatus> entry : statusMap.entrySet()) {
                    int loadedLevel = entry.getKey();
                    if (entry.getValue() != ElectronicHorizonDataLoadedStatus.FULLY_LOADED) {
                        continue;
                    }

                    // Level 0 = MPP. Process MPP segments for road sign logging.
                    if (loadedLevel == 0 && !allPaths.isEmpty()) {
                        ElectronicHorizonPath mpp = allPaths.get(0);
                        for (ElectronicHorizonSegment segment : mpp.segments) {
                            if (segment.segmentId.ocmSegmentId == null) {
                                continue;
                            }
                            DirectedOCMSegmentId directedOCMSegmentId = segment.segmentId.ocmSegmentId;
                            ElectronicHorizonDataLoaderResult result = electronicHorizonDataLoader.getSegment(directedOCMSegmentId);
                            if (result.errorCode == null && result.segmentData != null) {
                                logRoadSigns(result.segmentData, directedOCMSegmentId);
                            }
                        }
                        continue;
                    }

                    // Wait until first-level side-path data is fully loaded before logging side streets
                    // that branch directly from the active route.
                    if (loadedLevel == 1) {
                        notifySideStreetInfos(allPaths);
                    }

                    // For side-path levels (level > 0): walk all path segments and use
                    // sidePathIndexes to find paths that branch off at each segment.
                    // sidePathIndexes contains indexes into allPaths[], pointing to branching paths.
                    // Track processed path indexes to avoid redundant getSegment() calls.
                    Set<Integer> processedSidePathIndexes = new HashSet<>();
                    for (ElectronicHorizonPath path : allPaths) {
                        for (ElectronicHorizonSegment segment : path.segments) {
                            if (segment.sidePathIndexes.isEmpty()) {
                                continue;
                            }
                            for (Integer sidePathIndex : segment.sidePathIndexes) {
                                if (sidePathIndex < 0 || sidePathIndex >= allPaths.size()) continue;
                                if (!processedSidePathIndexes.add(sidePathIndex)) continue;
                                ElectronicHorizonPath branchingPath = allPaths.get(sidePathIndex);

                                // Only process branching paths at the loaded level.
                                if (branchingPath.level != loadedLevel) {
                                    continue;
                                }

                                Log.d(LOG_TAG, "Branching path index: " + sidePathIndex + ", level: " + branchingPath.level);

                                // Draw all segments of this branching path.
                                for (ElectronicHorizonSegment branchSegment : branchingPath.segments) {
                                    if (branchSegment.segmentId.ocmSegmentId == null) {
                                        continue;
                                    }
                                    DirectedOCMSegmentId directedOCMSegmentId = branchSegment.segmentId.ocmSegmentId;

                                    ElectronicHorizonDataLoaderResult result = electronicHorizonDataLoader.getSegment(directedOCMSegmentId);
                                    if (result.errorCode == null && result.segmentData != null) {
                                        if (isVisualizationEnabled) {
                                            drawSegmentPolyline(directedOCMSegmentId.id.localId, result.segmentData.getPolyline(), branchingPath.level);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        };
    }

    // Draw a colored MapPolyline for the given road segment and register it in segmentPolylineMap
    // so it can be removed when the segment leaves the horizon.
    private void drawSegmentPolyline(long localId, @Nullable GeoPolyline geoPolyline, int level) {
        // MPP (Most Preferred Path, level == 0) is already rendered as the main route
        // We only draw visual polylines for alternative side-paths (level > 0)
        if (level == 0) {
            Log.d(LOG_TAG, "MPP SEGMENT - localId=" + localId + " (already rendered as main route)");
            return;
        }

        // Skip if a polyline for this segment is already on the map.
        if (segmentPolylineMap.containsKey(localId)) return;

        // Segment data may not carry geometry; passing null crashes the native MapPolyline constructor.
        if (geoPolyline == null) {
            Log.w(LOG_TAG, "Skipping polyline for localId=" + localId + " - no geometry available.");
            return;
        }

        Color color;
        String colorName;
        switch (level) {
            case 1:  
                color = Color.valueOf(0f, 1f, 1f, 1.0f);    // Cyan - first side-path level
                colorName = "CYAN";
                break;
            case 2:
                color = Color.valueOf(1f, 0.2f, 0.8f, 0.85f); // Pink/Fuchsia - second side-path level
                colorName = "PINK";
                break;
            case 3:
                color = Color.valueOf(1f, 0.65f, 0f, 0.85f); // Orange - third side-path level
                colorName = "ORANGE";
                break;
            case 4:
                color = Color.valueOf(0f, 1f, 0f, 0.85f); // Green - fourth side-path level
                colorName = "GREEN";
                break;
            default:
                return; // Don't draw levels beyond 4
        }
        
        Log.d("eh segments", "Drawing segment polyline - localId=" + localId 
                + ", level=" + level 
                + ", color=" + colorName);
        
        float widthInPixels = 25f;
        MapPolyline mapPolyline;
        try {
            mapPolyline = new MapPolyline(
                    geoPolyline,
                    new MapPolyline.SolidRepresentation(
                            new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                            color,
                            LineCap.ROUND
                    )
            );
            Log.d("eh segments", "MapPolyline created successfully for localId=" + localId);
        } catch (MapPolyline.Representation.InstantiationException e) {
            Log.e(LOG_TAG, "MapPolyline instantiation failed: " + e.error.name());
            return;
        } catch (MapMeasureDependentRenderSize.InstantiationException e) {
            Log.e(LOG_TAG, "MapMeasureDependentRenderSize instantiation failed: " + e.error.name());
            return;
        }

        try {
            mapView.getMapScene().addMapPolyline(mapPolyline);
            segmentPolylineMap.put(localId, mapPolyline);
        } catch (Exception e) {
            Log.e(LOG_TAG, "ERROR adding polyline to map scene: " + e.getMessage());
            return;
        }
    }

    // Remove all EH segment polylines from the map.
    private void clearVisualization() {
        for (MapPolyline polyline : segmentPolylineMap.values()) {
            mapView.getMapScene().removeMapPolyline(polyline);
        }
        segmentPolylineMap.clear();
    }

    // Finds first-level side streets whose parent is the currently followed navigation path.
    private void notifySideStreetInfos(@NonNull List<ElectronicHorizonPath> allPaths) {
        for (int pathIndex = 0; pathIndex < allPaths.size(); pathIndex++) {
            ElectronicHorizonPath path = allPaths.get(pathIndex);
            if (path.level != 1 || path.parentPathIndex == null || path.parentPathIndex != 0) {
                continue;
            }

            SideStreetInfo sideStreetInfo = findSideStreetInfo(path, pathIndex);
            if (sideStreetInfo != null) {
                Log.d(LOG_TAG, "SideStreetName near active route: " + sideStreetInfo.streetName
                        + " at lat/lon: " + sideStreetInfo.coordinateAtOffsetFromSegmentStart.latitude
                        + "/" + sideStreetInfo.coordinateAtOffsetFromSegmentStart.longitude
                        + ", pathIndex=" + sideStreetInfo.pathIndex
                        + ", segmentLocalId=" + sideStreetInfo.segmentLocalId);
            }
        }
    }

    @Nullable
    private SideStreetInfo findSideStreetInfo(@NonNull ElectronicHorizonPath branchingPath, int pathIndex) {
        for (ElectronicHorizonSegment segment : branchingPath.segments) {
            DirectedOCMSegmentId directedOCMSegmentId = segment.segmentId.ocmSegmentId;
            if (directedOCMSegmentId == null) {
                continue;
            }

            ElectronicHorizonDataLoaderResult result = electronicHorizonDataLoader.getSegment(directedOCMSegmentId);
            if (result.errorCode != null || result.segmentData == null) {
                continue;
            }

            SegmentData segmentData = result.segmentData;
            String sideStreetName = getFirstStreetLabel(segmentData);
            if (sideStreetName == null) {
                continue;
            }

            GeoPolyline polyline = segmentData.getPolyline();
            if (polyline == null) {
                continue;
            }

                GeoCoordinates sideStreetCoordinates = polyline.coordinatesAtOffsetInMeters(
                    SIDE_STREET_LOG_OFFSET_METERS,
                    GeoPolylineDirection.FROM_BEGINNING);
                return new SideStreetInfo(
                    sideStreetName,
                    sideStreetCoordinates,
                    pathIndex,
                    directedOCMSegmentId.id.localId);
        }

        return null;
    }

    // Returns the first non-empty street label (street name or road number).
    @Nullable
    private String getFirstStreetLabel(@NonNull SegmentData segmentData) {
        List<SegmentSpanData> segmentSpans = segmentData.getSpans();
        if (segmentSpans == null || segmentSpans.isEmpty()) {
            return null;
        }

        for (SegmentSpanData segmentSpanData : segmentSpans) {
            if (segmentSpanData == null) {
                continue;
            }

            String streetName = null;
            if (segmentSpanData.getStreetNames() != null) {
                streetName = segmentSpanData.getStreetNames().getDefaultValue();
            }
            if ((streetName == null || streetName.trim().isEmpty()) && segmentSpanData.getRoadNumbers() != null) {
                streetName = segmentSpanData.getRoadNumbers().getDefaultValue();
            }
            if (streetName != null && !streetName.trim().isEmpty()) {
                return streetName;
            }
        }

        return null;
    }

    // Log road sign information from a fully loaded segment.
    private void logRoadSigns(SegmentData segmentData, DirectedOCMSegmentId directedOCMSegmentId) {
        List<RoadSign> roadSigns = segmentData.getRoadSigns();
        if (roadSigns == null || roadSigns.isEmpty()) return;
        GeoPolyline segmentPolyline = segmentData.getPolyline();
        if (segmentPolyline == null) {
            Log.w(LOG_TAG, "Skipping road sign logging: segment polyline is null for segmentId=" + directedOCMSegmentId.id.localId);
            return;
        }
        for (RoadSign roadSign : roadSigns) {
            @Nullable GeoCoordinates roadSignCoordinates = getGeoCoordinatesFromOffsetInMeters(segmentPolyline, roadSign.offsetInMeters);
            if (roadSignCoordinates == null) {
                Log.w(LOG_TAG, "Skipping road sign: coordinates lookup failed for offset=" + roadSign.offsetInMeters
                        + " on segmentId=" + directedOCMSegmentId.id.localId);
                continue;
            }
            Log.d(LOG_TAG, "RoadSign: type = "
                    + roadSign.roadSignType.name()
                    + ", offsetInMeters = " + roadSign.offsetInMeters
                    + ", lat/lon: " + roadSignCoordinates.latitude + "/" + roadSignCoordinates.longitude
                    + ", segmentId = " + directedOCMSegmentId.id.localId);
        }
    }

    // Convert an offset in meters along a GeoPolyline to GeoCoordinates using the HERE SDK's coordinatesAtOffsetInMeters.
    @Nullable
    private GeoCoordinates getGeoCoordinatesFromOffsetInMeters(@Nullable GeoPolyline geoPolyline, int offsetInMeters) {
        if (geoPolyline == null) {
            return null;
        }
        return geoPolyline.coordinatesAtOffsetInMeters(offsetInMeters, GeoPolylineDirection.FROM_BEGINNING);
    }

    public void stop() {
        if (electronicHorizonEngine == null) {
            return;
        }

        electronicHorizonEngine.removeElectronicHorizonListener(electronicHorizonListener);
        electronicHorizonDataLoader.removeElectronicHorizonDataLoaderStatusListener(electronicHorizonDataLoaderStatusListener);
        clearVisualization();
        Log.d(LOG_TAG, "ElectronicHorizonEngine stopped.");
    }

    private static class SideStreetInfo {
        private final String streetName;
        // Representative point on the matched side-street segment.
        private final GeoCoordinates coordinateAtOffsetFromSegmentStart;
        private final int pathIndex;
        private final long segmentLocalId;

        private SideStreetInfo(
                @NonNull String streetName,
                @NonNull GeoCoordinates coordinateAtOffsetFromSegmentStart,
                int pathIndex,
                long segmentLocalId) {
            this.streetName = streetName;
            this.coordinateAtOffsetFromSegmentStart = coordinateAtOffsetFromSegmentStart;
            this.pathIndex = pathIndex;
            this.segmentLocalId = segmentLocalId;
        }
    }

    private SDKNativeEngine getSDKNativeEngine() {
        SDKNativeEngine sdkNativeEngine = SDKNativeEngine.getSharedInstance();
        if (sdkNativeEngine == null) {
            throw new RuntimeException("SDKNativeEngine is not initialized.");
        }
        return sdkNativeEngine;
    }
}
