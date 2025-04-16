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

package com.here.routingwithavoidanceoptions;

import android.content.Context;
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;

import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoOrientation;
import com.here.sdk.core.GeoOrientationUpdate;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.Metadata;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Rectangle2D;
import com.here.sdk.core.Size2D;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.gestures.GestureState;
import com.here.sdk.gestures.TapListener;
import com.here.sdk.mapdata.OCMSegmentId;
import com.here.sdk.mapdata.SegmentData;
import com.here.sdk.mapdata.SegmentDataLoader;
import com.here.sdk.mapdata.SegmentDataLoaderException;
import com.here.sdk.mapdata.SegmentDataLoaderOptions;
import com.here.sdk.mapdata.SegmentSpanData;
import com.here.sdk.mapview.LineCap;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapMeasureDependentRenderSize;
import com.here.sdk.mapview.MapPickResult;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.MapViewBase;
import com.here.sdk.mapview.PickMapItemsResult;
import com.here.sdk.mapview.RenderSize;
import com.here.sdk.routing.AvoidanceOptions;
import com.here.sdk.routing.CalculateRouteCallback;
import com.here.sdk.routing.CarOptions;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.RoutingError;
import com.here.sdk.routing.Section;
import com.here.sdk.routing.SectionNotice;
import com.here.sdk.routing.SectionNoticeCode;
import com.here.sdk.routing.SegmentReference;
import com.here.sdk.routing.Span;
import com.here.sdk.routing.Waypoint;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Objects;

// This example shows how to use avoidance options to block roads.
// Roads to avoid can be picked from the map.

// Segments near the route origin can be loaded with the SegmentDataLoader and then picked to
// mark them for avoidance in the next route calculation.
// If no segments have been picked yet, a hardcoded segment will be used for avoidance.
public class RoutingWithAvoidanceOptionExample {

    private static final String TAG = RoutingWithAvoidanceOptionExample.class.getName();

    private final Context context;
    private final MapView mapView;
    private final List<MapPolyline> mapPolylines = new ArrayList<>();
    private final List<MapPolyline> segmentPolyLines = new ArrayList<>();
    private final RoutingEngine routingEngine;
    // A route in Berlin - can be changed via longtap.
    private GeoCoordinates startGeoCoordinates = new GeoCoordinates(52.49047222554655, 13.296884483959285);
    private GeoCoordinates destinationGeoCoordinates = new GeoCoordinates(52.51384077118386, 13.255752692114996);
    private final MapMarker startMapMarker;
    private final MapMarker destinationMapMarker;
    private SegmentReference currentlySelectedsegmentReference;
    private final SegmentDataLoader segmentDataLoader;
    private final String METADATA_SEGMENT_ID_KEY = "segmentId";
    private final String METADATA_TILE_PARTITION_ID_KEY = "tilePartitionId";
    private boolean setLongpressDestination;
    HashMap<String, SegmentReference> segmentAvoidanceList = new HashMap<>();
    private boolean segmentsAvoidanceViolated = false;

    public RoutingWithAvoidanceOptionExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        MapCamera camera = mapView.getCamera();
        double distanceInMeters = 5000;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters);
        camera.lookAt(new GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);
        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }

        try {
            // With the segment data loader information can be retrieved from cached or installed offline map data, for example on road attributes.
            // This feature can be used independent from a route. It is recommended to not rely on the cache alone. For simplicity, this is left out for this example.
            segmentDataLoader = new SegmentDataLoader();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("SegmentDataLoader initialization failed." + e.getMessage());
        }

        // Fallback if no segments have been picked by the user.
        SegmentReference segmentReferenceInBerlin = createSegmentInBerlin();
        segmentAvoidanceList.put(segmentReferenceInBerlin.segmentId, createSegmentInBerlin());

        // Add markers to indicate the currently selected starting point and destination.
        startMapMarker = addMapMarker(startGeoCoordinates, R.drawable.poi_start);
        destinationMapMarker = addMapMarker(destinationGeoCoordinates, R.drawable.poi_destination);

        setTapGestureHandler();
        setLongPressGestureHandler();
        showDialog(
                "How to use this app",
                "- Long press to set origin and destination of a route.\n \n" +
                        "- Tap anywhere on the map to load segments to avoidance list.\n \n" +
                        "- Again tap on the same segment to remove it from avoidance list when calculating a route."
        );
    }

    private void setLongPressGestureHandler() {
        mapView.getGestures().setLongPressListener((gestureState, touchPoint) -> {
            GeoCoordinates geoCoordinates = mapView.viewToGeoCoordinates(touchPoint);
            if (geoCoordinates == null) {
                // If the mapview render surface is not attached, it will return null.
                return;
            }
            if (gestureState == GestureState.BEGIN) {
                // Set new route start or destination geographic coordinates based on long press location.
                if (setLongpressDestination) {
                    destinationGeoCoordinates = geoCoordinates;
                    destinationMapMarker.setCoordinates(geoCoordinates);
                } else {
                    startGeoCoordinates = geoCoordinates;
                    startMapMarker.setCoordinates(geoCoordinates);
                }
                // Toggle the marker that should be updated on next long press.
                setLongpressDestination = !setLongpressDestination;
            }
        });
    }

    private void setTapGestureHandler() {
        mapView.getGestures().setTapListener(new TapListener() {
            @Override
            public void onTap(@NonNull Point2D touchPoint) {
                pickMapPolyLine(touchPoint);
            }
        });
    }

    private void pickMapPolyLine(final Point2D touchPoint) {
        Point2D originInPixels = new Point2D(touchPoint.x, touchPoint.y);
        Size2D sizeInPixels = new Size2D(50, 50);
        Rectangle2D rectangle = new Rectangle2D(originInPixels, sizeInPixels);
        GeoCoordinates geoCoordinates = mapView.viewToGeoCoordinates(touchPoint);
        ArrayList<MapScene.MapPickFilter.ContentType> contentTypesToPickFrom = new ArrayList<>();

        contentTypesToPickFrom.add(MapScene.MapPickFilter.ContentType.MAP_ITEMS);
        MapScene.MapPickFilter filter = new MapScene.MapPickFilter(contentTypesToPickFrom);

        mapView.pick(filter, rectangle, new MapViewBase.MapPickCallback() {
            @Override
            public void onPickMap(@Nullable MapPickResult mapPickResult) {
                if (mapPickResult == null) {
                    // An error occurred while performing the pick operation,
                    // for example, when picking the horizon.
                    return;
                }
                PickMapItemsResult pickMapItemsResult = mapPickResult.getMapItems();

                assert pickMapItemsResult != null;
                List<MapPolyline> polylines = pickMapItemsResult.getPolylines();
                int listSize = polylines.size();
                if (listSize == 0) {
                    loadSegmentData(geoCoordinates);
                    return;
                }
                MapPolyline mapPolyline = polylines.get(0);
                handlePickedMapPolyline(mapPolyline);
            }
        });
    }

    private void handlePickedMapPolyline(MapPolyline mapPolyline) {
        Metadata metadata = mapPolyline.getMetadata();
        if (metadata != null) {
            Double partitionId = metadata.getDouble(METADATA_TILE_PARTITION_ID_KEY);
            String segmentId = metadata.getString(METADATA_SEGMENT_ID_KEY);
            showDialog("Segment removed:", "Removed Segment ID " + segmentId + " Tile partition ID " + partitionId.longValue());
            segmentPolyLines.remove(mapPolyline);
            mapView.getMapScene().removeMapPolyline(mapPolyline);
            segmentAvoidanceList.remove(segmentId);
        } else {
            showDialog("Map polyline picked:", "You picked a route polyline");
        }
    }

    // Load segment data and fetch information from the map around
    // the given geo-coordinate.
    public void loadSegmentData(GeoCoordinates geoCoordinates) {
        clearMap();
        clearSegmentPolyLines();
        segmentAvoidanceList.clear();

        List<OCMSegmentId> segmentIds;
        SegmentData segmentData;

        // The necessary SegmentDataLoaderOptions need to be turned on in order to find the
        // requested information.
        // It is recommended to turn on only the data you are interested in by setting
        // the corresponding fields to true.
        SegmentDataLoaderOptions segmentDataLoaderOptions = new SegmentDataLoaderOptions();

        segmentDataLoaderOptions.loadBaseSpeeds = true;
        segmentDataLoaderOptions.loadRoadAttributes = true;
        segmentDataLoaderOptions.loadFunctionalRoadClass = true;

        Toast.makeText(context, "Loading attributes of map segments around origin. For more details check the logs.", Toast.LENGTH_LONG).show();

        try {
            // The smaller the radius, the more precisely a user can select a road on the map.
            // With a broader area around the origin multiple segments can be vizualized at once.
            double radiusInMeters = 5;
            segmentIds = segmentDataLoader.getSegmentsAroundCoordinates(geoCoordinates, radiusInMeters);

            for (OCMSegmentId segmentId : segmentIds) {
                segmentData = segmentDataLoader.loadData(segmentId, segmentDataLoaderOptions);

                List<SegmentSpanData> segmentSpanDataList = segmentData.getSpans();
                SegmentReference segmentReference = segmentData.getSegmentReference();

                Metadata metadata = new Metadata();
                metadata.setString(METADATA_SEGMENT_ID_KEY, segmentReference.segmentId);
                metadata.setDouble(METADATA_TILE_PARTITION_ID_KEY, segmentReference.tilePartitionId);

                MapPolyline segmentPolyLine = createMapPolyline(Color.valueOf(1, 0, 0, 1), segmentData.getPolyline());
                segmentPolyLine.setMetadata(metadata);
                mapView.getMapScene().addMapPolyline(segmentPolyLine);
                segmentPolyLines.add(segmentPolyLine);
                segmentAvoidanceList.put(segmentReference.segmentId, segmentReference);

                for (SegmentSpanData span : segmentSpanDataList) {
                    Log.d(TAG, "Physical attributes of " + span.toString() + " span.");
                    Log.d(TAG, "Private roads: " + Objects.requireNonNull(span.getPhysicalAttributes()).isPrivate);
                    Log.d(TAG, "Dirt roads: " + span.getPhysicalAttributes().isDirtRoad);
                    Log.d(TAG, "Bridge: " + span.getPhysicalAttributes().isBridge);
                    Log.d(TAG, "Tollway: " + Objects.requireNonNull(span.getRoadUsages()).isTollway);
                    Log.d(TAG, "Average expected speed: " + span.getPositiveDirectionBaseSpeedInMetersPerSecond());
                }
            }
        } catch (SegmentDataLoaderException e) {
            throw new RuntimeException(e);
        }
    }

    public void addRouteButtonClicked() {
        if (startGeoCoordinates == null || destinationGeoCoordinates == null) {
            showDialog("Error", "Long press on the map to select source and destination.");
            return;
        }

        Waypoint startWaypoint = new Waypoint(startGeoCoordinates);
        Waypoint destinationWaypoint = new Waypoint(destinationGeoCoordinates);
        CarOptions carOptions = new CarOptions();
        carOptions.avoidanceOptions = getAvoidanceOptions();

        List<Waypoint> waypoints =
                new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint));

        routingEngine.calculateRoute(
                waypoints,
                carOptions,
                new CalculateRouteCallback() {
                    @Override
                    public void onRouteCalculated(@Nullable RoutingError routingError, @Nullable List<Route> routes) {
                        if (routingError == null) {
                            assert routes != null;
                            Route route = routes.get(0);
                            logRouteViolations(route);
                            showRouteOnMap(route);
                            showRouteDetails(route);
                        } else {
                            showDialog("Error while calculating a route:", routingError.toString());
                        }
                    }
                });
    }

    // If it is not possible to block the segment, a spanSectionNotice will indicate this.
    // For example, the violation VIOLATED_BLOCKED_ROAD starts at ... and ends at ... .
    private void logRouteViolations(Route route) {
        for (Section section : route.getSections()) {
            for (Span span : section.getSpans()) {
                List<GeoCoordinates> spanGeometryVertices = span.getGeometry().vertices;
                // This route violation spreads across the whole span geometry.
                GeoCoordinates violationStartPoint = spanGeometryVertices.get(0);
                GeoCoordinates violationEndPoint = spanGeometryVertices.get(spanGeometryVertices.size() - 1);
                for (int index : span.getNoticeIndexes()) {
                    SectionNotice spanSectionNotice = section.getSectionNotices().get(index);
                    if (spanSectionNotice.code == SectionNoticeCode.VIOLATED_BLOCKED_ROAD) {
                        segmentsAvoidanceViolated = true;
                    }

                    // The violation code such as "VIOLATED_BLOCKED_ROAD".
                    String violationCode = spanSectionNotice.code.toString();
                    Log.d(TAG, "The violation " + violationCode + " starts at " + toString(violationStartPoint) + " and ends at " + toString(violationEndPoint) + " .");
                }
            }
        }
    }

    private String toString(GeoCoordinates geoCoordinates) {
        return geoCoordinates.latitude + ", " + geoCoordinates.longitude;
    }

    private AvoidanceOptions getAvoidanceOptions() {
        AvoidanceOptions avoidanceOptions = new AvoidanceOptions();
        avoidanceOptions.segments = new ArrayList<SegmentReference>(segmentAvoidanceList.values());
        return avoidanceOptions;
    }

    // A hardcoded segment in Berlin that will be used as fallback to create
    // AvoidanceOptions when no segments have been picked yet.
    private SegmentReference createSegmentInBerlin() {
        // Alternatively, segmentId and tilePartitionId can be obtained from each span of a Route object.
        // For example, the segmentId and tilePartitionId used below was taken from a route.
        String segmentId = "here:cm:segment:807958890";
        long tilePartitionId = 377894441;
        currentlySelectedsegmentReference = new SegmentReference();
        currentlySelectedsegmentReference.segmentId = segmentId;
        currentlySelectedsegmentReference.tilePartitionId = tilePartitionId;
        return currentlySelectedsegmentReference;
    }

    private SegmentReference createSegment(String segmentId, long tilePartitionId) {
        currentlySelectedsegmentReference = new SegmentReference();
        currentlySelectedsegmentReference.segmentId = segmentId;
        currentlySelectedsegmentReference.tilePartitionId = tilePartitionId;
        return currentlySelectedsegmentReference;
    }

    private void showRouteDetails(Route route) {
        String routeDetails = "Route length in m: " + route.getLengthInMeters();

        if (segmentsAvoidanceViolated) {
            routeDetails = routeDetails + "\n" + "Some segments cannot be avoided. See logs!";
            segmentsAvoidanceViolated = false;
        }
        showDialog("Route Details", routeDetails);
    }

    private void showRouteOnMap(Route route) {
        GeoPolyline routeGeoPolyline = route.getGeometry();
        MapPolyline routeMapPolyline =
                createMapPolyline(Color.valueOf(0, 0.6f, 1, 1), routeGeoPolyline);
        mapView.getMapScene().addMapPolyline(routeMapPolyline);
        mapPolylines.add(routeMapPolyline);
        mapView.getCamera().lookAt(route.getBoundingBox(),
                new GeoOrientationUpdate(new GeoOrientation(0.0, 0.0)));
    }

    private MapPolyline createMapPolyline(Color color, GeoPolyline geoPolyline) {
        MapPolyline mapPolyline = null;
        try {
            int widthInPixels = 15;
            mapPolyline = new MapPolyline(geoPolyline, new MapPolyline.SolidRepresentation(
                    new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                    color,
                    LineCap.ROUND));
        } catch (MapPolyline.Representation.InstantiationException e) {
            Log.e("MapPolyline Representation Exception:", e.error.name());
        } catch (MapMeasureDependentRenderSize.InstantiationException e) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name());
        }
        return mapPolyline;
    }

    public void clearMap() {
        clearRoute();
    }

    private void clearRoute() {
        for (MapPolyline mapPolyline : mapPolylines) {
            mapView.getMapScene().removeMapPolyline(mapPolyline);
        }
        mapPolylines.clear();
    }

    private void clearSegmentPolyLines() {
        for (MapPolyline segmentPolyline : segmentPolyLines) {
            mapView.getMapScene().removeMapPolyline(segmentPolyline);
        }
        segmentPolyLines.clear();
    }

    private MapMarker addMapMarker(GeoCoordinates geoCoordinates, int resourceId) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), resourceId);
        Anchor2D anchor2D = new Anchor2D(0.5F, 1);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage, anchor2D);
        mapView.getMapScene().addMapMarker(mapMarker);
        return mapMarker;
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }
}

