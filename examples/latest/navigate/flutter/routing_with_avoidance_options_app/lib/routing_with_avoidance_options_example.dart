/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
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

import 'package:flutter/material.dart';
import 'package:here_sdk/animation.dart' as here;
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapdata.dart';
import 'package:here_sdk/mapmatcher.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/routing.dart' as here;

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

class RoutingWithAvoidanceOptionsExample {
  final HereMapController _hereMapController;
  final List<MapPolyline> _mapPolylines = [];
  final List<MapPolyline> _segmentPolylines = [];
  late RoutingEngine _routingEngine;
  final ShowDialogFunction _showDialog;
  List<Waypoint> waypoints = [];
  late here.Route _currentRoute;
  bool _setLongPressDestination = false;
  GeoCoordinates _startGeoCoordinates = GeoCoordinates(52.49047222554655, 13.296884483959285);
  GeoCoordinates _destinationGeoCoordinates = GeoCoordinates(52.51384077118386, 13.255752692114996);

  MapMarker? _startMapMarker;
  MapMarker? _destinationMapMarker;

  // A route in Berlin - can be changed via long press.
  GeoCoordinates startGeoCoordinates = GeoCoordinates(52.49047222554655, 13.296884483959285);
  GeoCoordinates destinationGeoCoordinates = GeoCoordinates(52.51384077118386, 13.255752692114996);

  late final SegmentDataLoader _segmentDataLoader;
  late final MapMatcher _mapMatcher;
  late final SDKNativeEngine _sdkNativeEngine;
  final String _metadataSegmentIdKey = 'segmentId';
  final String _metadataTilePartitionIdKey = 'tilePartitionId';
  final Map<String, SegmentReference> segmentAvoidanceList = {};
  bool segmentsAvoidanceViolated = false;
  bool _useRenderingLayers = true;

  RoutingWithAvoidanceOptionsExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
    : _showDialog = showDialogCallback,
      _hereMapController = hereMapController {
    double distanceToEarthInMeters = 10000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

    _startMapMarker = _addMapMarker(_startGeoCoordinates, "assets/poi_start.png");
    _destinationMapMarker = _addMapMarker(_destinationGeoCoordinates, "assets/poi_destination.png");

    try {
      _routingEngine = RoutingEngine();
    } on InstantiationException {
      throw ("Initialization of RoutingEngine failed.");
    }

    try {
      // With the SegmentDataLoader, information can be retrieved from cached or installed offline map data,
      // for example on road attributes. This feature can be used independent from a route.
      // It is recommended to not rely on the cache alone. For simplicity, this is left out for this example.
      _segmentDataLoader = SegmentDataLoader();
    } on InstantiationException catch (e) {
      throw Exception('SegmentDataLoader initialization failed: ${e.toString()}');
    }

    try {
      _sdkNativeEngine = SDKNativeEngine.sharedInstance!;
    } on InstantiationException catch (e) {
      throw Exception('SDKNativeEngine initialization failed: ${e.toString()}');
    }

    try {
      _mapMatcher = MapMatcher.withLayers(_sdkNativeEngine, _useRenderingLayers);
    } on InstantiationException catch (e) {
      throw Exception('MapMatcher initialization failed: ${e.toString()}');
    }

    // Fallback if no segments have been picked by the user.
    SegmentReference segmentReferenceInBerlin = createSegmentInBerlin();
    segmentAvoidanceList[segmentReferenceInBerlin.segmentId] = createSegmentInBerlin();

    _setLongPressGestureHandler();
    _setTapGestureHandler();
  }

  void _setTapGestureHandler() {
    _hereMapController.gestures.tapListener = TapListener((Point2D touchPoint) {
      _pickMapMarker(touchPoint);
    });
  }

  void _pickMapMarker(Point2D touchPoint) {
    Point2D originInPixels = Point2D(touchPoint.x, touchPoint.y);
    Size2D sizeInPixels = Size2D(50, 50);
    Rectangle2D rectangle = Rectangle2D(originInPixels, sizeInPixels);
    List<MapSceneMapPickFilterContentType> contentTypesToPickFrom = [];
    GeoCoordinates? geoCoordinates = _hereMapController.viewToGeoCoordinates(touchPoint);

    contentTypesToPickFrom.add(MapSceneMapPickFilterContentType.mapItems);
    MapSceneMapPickFilter filter = MapSceneMapPickFilter(contentTypesToPickFrom);
    _hereMapController.pick(filter, rectangle, (mapPickResult) {
      if (mapPickResult == null) {
        // An error occurred while performing the pick operation,
        // for example, when picking the horizon.
        return;
      }

      final pickMapItemsResult = mapPickResult.mapItems;

      assert(pickMapItemsResult != null);

      final polylines = pickMapItemsResult?.polylines;
      final listSize = polylines?.length;

      // If no polyLines are selected, load the segments.
      if (listSize == 0) {
        fetchOCMSegmentIDsAndLoadData(geoCoordinates!);
        return;
      }

      final mapPolyline = polylines?.first;

      if (mapPolyline != null) {
        handlePickedMapPolyline(mapPolyline);
      }
    });
  }

  void handlePickedMapPolyline(MapPolyline mapPolyline) {
    final metadata = mapPolyline.metadata;
    if (metadata != null) {
      final partitionId = metadata.getDouble(_metadataTilePartitionIdKey);
      final segmentId = metadata.getString(_metadataSegmentIdKey);

      _showDialog("Segment removed:", "Removed Segment ID $segmentId\nTile partition ID ${partitionId?.toInt()}");

      _segmentPolylines.remove(mapPolyline);
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
      segmentAvoidanceList.remove(segmentId);
    } else {
      _showDialog("Map polyline picked:", "You picked a route polyline");
    }
  }

  void _setLongPressGestureHandler() {
    _hereMapController.gestures.longPressListener = LongPressListener((gestureState, touchPoint) {
      GeoCoordinates? geoCoordinates = _hereMapController.viewToGeoCoordinates(touchPoint);
      if (geoCoordinates == null) {
        // If the MapView render surface is not attached, it will return null.
        return;
      }

      if (gestureState == GestureState.begin) {
        // Set new route start or destination geographic coordinates based on long press location.
        if (_setLongPressDestination) {
          _destinationGeoCoordinates = geoCoordinates;
          _destinationMapMarker?.coordinates = geoCoordinates;
        } else {
          _startGeoCoordinates = geoCoordinates;
          _startMapMarker?.coordinates = geoCoordinates;
        }
        _matchLocation(geoCoordinates);

        // Toggle the marker that should be updated on next long press.
        _setLongPressDestination = !_setLongPressDestination;
      }
    });
  }

  // Fetch information from the map around the given GeoCoordinates and load segment data synchronously..
  void fetchOCMSegmentIDsAndLoadData(GeoCoordinates geoCoordinates) {
    List<OCMSegmentId> segmentIds;

    _showDialog("SegmentData",
        "Loading attributes of a map segment. Check logs for details.");

    try {
      // The smaller the radius, the more precisely a user can select a road on the map.
      // With a broader area around the origin multiple segments can be vizualized at once.
      const double radiusInMeters = 5.0;

      segmentIds = _segmentDataLoader.getSegmentsAroundCoordinates(
        geoCoordinates,
        radiusInMeters,
      );

      for (OCMSegmentId ocmSegmentId in segmentIds) {
        _loadSegmentData(ocmSegmentId);
      }
    } catch (e) {
      throw Exception('SegmentDataLoader failed: ${e.toString()}');
    }
  }

  // The MapMatcher aligns location signals to the road network, improving
  // accuracy during navigation. Raw coordinates often differ from the actual
  // position, so the MapMatcher uses past locations, plus speed and bearing,
  // to refine results. If map data is missing, it returns null and requests
  // the needed tiles online; later calls can use the cached data. A tile
  // covers a larger area, so future matches often benefit. Both VisualNavigator
  // and Navigator use the MapMatcher to match each signal to a road. Here we
  // show matching for a single long-tap, though repeated taps may improve accuracy.
  void _matchLocation(GeoCoordinates geoCoordinates) {
    // The MapMatcher evaluates all parameters in the Location object to produce the most accurate result.
    // The `time` parameter must be set for each Location object.
    // While missing parameters are tolerated, providing additional parameters such as speed or bearing improves matching quality.
    Location location = Location.withCoordinates(geoCoordinates);
    location.time = DateTime.now();
    MapMatchedLocation? mapMatchedLocation = _mapMatcher.match(location);

    // A null mapMatchedLocation indicates that the location could not be matched to the road network.
    // This means the location is offroad or the data is not in the cache.
    if (mapMatchedLocation != null) {
      _showDialog("MapMatcher", "Map-matched location is highlighted with red dot on the map. Check logs for more information on matched location.");

      // Show the map-matched location on the map.
      MapMarker mapMatcherMapMarker = _addMapMarker(mapMatchedLocation.coordinates, "assets/map_matched_location_dot.png");

      // Fetch IDs from mapMatchedLocation and convert them into OCMSegmentID required by loadSegmentData method.
      OCMSegmentId mapMatchedSegmentId = OCMSegmentId();
      mapMatchedSegmentId.localId = mapMatchedLocation.segmentReference.localId!;
      mapMatchedSegmentId.tilePartitionId = mapMatchedLocation.segmentReference.tilePartitionId;

      _loadSegmentData(mapMatchedSegmentId);
    } else {
      debugPrint(
          "Location could not be map-matched. Check if the picked location is within 50-meter radius of a road.");
    }
  }

  void _loadSegmentData(OCMSegmentId ocmSegmentId) {
    SegmentData segmentData;

    // The necessary SegmentDataLoaderOptions need to be turned on to retrieve the desired information.
    final segmentDataLoaderOptions =
        SegmentDataLoaderOptions()
          ..loadBaseSpeeds = true
          ..loadRoadAttributes = true
          ..loadFunctionalRoadClass = true;

    segmentData = _segmentDataLoader.loadData(
      ocmSegmentId,
      segmentDataLoaderOptions,
    );

    final segmentSpanDataList = segmentData.spans;
    final segmentReference = segmentData.segmentReference;

    final metadata = Metadata();
    metadata.setString(_metadataSegmentIdKey, segmentReference.segmentId);
    metadata.setDouble(_metadataTilePartitionIdKey, segmentReference.tilePartitionId.toDouble());

    final segmentPolyline = createMapPolyline(
      const Color.fromARGB(255, 255, 0, 0), // Red color
      segmentData.polyline,
    );

    if (segmentPolyline == null) {
      return;
    }

    segmentPolyline.metadata = metadata;
    _hereMapController.mapScene.addMapPolyline(segmentPolyline);
    _segmentPolylines.add(segmentPolyline);
    segmentAvoidanceList[segmentReference.segmentId] = segmentReference;

    for (SegmentSpanData span in segmentSpanDataList) {
      _logSegmentDataDetails(span, segmentReference.segmentId);
    }
  }

  void _logSegmentDataDetails(SegmentSpanData span, String segmentID) {
    debugPrint("Segment data for span belonging to OCM segment with ID: $segmentID");
    debugPrint("Private roads: ${span.physicalAttributes?.isPrivate}");
    debugPrint("Dirt roads: ${span.physicalAttributes?.isDirtRoad}");
    debugPrint("Bridge: ${span.physicalAttributes?.isBridge}");
    debugPrint("Tollway: ${span.roadUsages?.isTollway}");
    debugPrint(
        "Average expected speed: ${span.positiveDirectionBaseSpeedInMetersPerSecond}");
  }

  Future<void> addRoute() async {
    // Optionally, clear any previous route.
    clearMap();

    var startWaypoint = Waypoint.withDefaults(_startGeoCoordinates);
    var destinationWaypoint = Waypoint.withDefaults(_destinationGeoCoordinates);

    waypoints = [startWaypoint, destinationWaypoint];

    _calculateRoute(waypoints);
  }

  void _calculateRoute(List<Waypoint> waypoints) {
    CarOptions carOptions = CarOptions();
    carOptions.avoidanceOptions = _getAvoidanceOptions();

    _routingEngine.calculateCarRoute(waypoints, carOptions, (
      RoutingError? routingError,
      List<here.Route>? routeList,
    ) async {
      if (routingError == null) {
        // When error is null, then the list guaranteed to be not null.
        _currentRoute = routeList!.first;
        _showRouteDetails(_currentRoute);
        _showRouteOnMap(_currentRoute);
        _logRouteViolations(_currentRoute);
        _animateToRoute(_currentRoute);
      } else {
        var error = routingError.toString();
        _showDialog('Error', 'Error while calculating a route: $error');
      }
    });
  }

  AvoidanceOptions _getAvoidanceOptions() {
    final avoidanceOptions = AvoidanceOptions();
    avoidanceOptions.segments = segmentAvoidanceList.values.toList();
    return avoidanceOptions;
  }

  void _logRouteViolations(here.Route route) {
    for (final section in route.sections) {
      for (final span in section.spans) {
        final spanGeometryVertices = span.geometry.vertices;
        final violationStartPoint = spanGeometryVertices.first;
        final violationEndPoint = spanGeometryVertices.last;

        for (final index in span.noticeIndexes) {
          final spanSectionNotice = section.sectionNotices[index];

          if (spanSectionNotice.code == SectionNoticeCode.violatedBlockedRoad) {
            segmentsAvoidanceViolated = true;
          }

          final violationCode = spanSectionNotice.code.toString();
          debugPrint(
            "The violation $violationCode starts at ${_toString(violationStartPoint)} "
            "and ends at ${_toString(violationEndPoint)} .",
          );
        }
      }
    }
  }

  String _toString(GeoCoordinates geoCoordinates) {
    return "${geoCoordinates.latitude},  ${geoCoordinates.longitude}";
  }

  void clearMap() {
    _clearRoute();
  }

  void _clearRoute() {
    for (var mapPolyline in _mapPolylines) {
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
    }
    _mapPolylines.clear();
  }

  void _showRouteDetails(here.Route route) {
    String routeDetails = "Route length in m: ${route.lengthInMeters}";

    if (segmentsAvoidanceViolated) {
      routeDetails += "\nSome segments cannot be avoided. See logs!";
      segmentsAvoidanceViolated = false;
    }

    _showDialog("Route Details", routeDetails);
  }

  _showRouteOnMap(here.Route route) {
    // Show route as polyline.
    GeoPolyline routeGeoPolyline = route.geometry;
    Color polylineColor = const Color.fromARGB(160, 0, 144, 138);
    MapPolyline? routeMapPolyline;
    routeMapPolyline = createMapPolyline(polylineColor, routeGeoPolyline);
    _hereMapController.mapScene.addMapPolyline(routeMapPolyline!);
    _mapPolylines.add(routeMapPolyline);
  }

  MapPolyline? createMapPolyline(Color color, GeoPolyline geoPolyline) {
    try {
      const int widthInPixels = 15;

      final renderSize = MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.pixels, widthInPixels.toDouble());

      final polylineRepresentation = MapPolylineSolidRepresentation(renderSize, color, LineCap.round);

      final mapPolyline = MapPolyline.withRepresentation(geoPolyline, polylineRepresentation);
      return mapPolyline;
    } on InstantiationException catch (e) {
      print('MapPolyline Representation Instantiation Exception: ${e.toString()}');
    } on MapMeasureDependentRenderSizeInstantiationException catch (e) {
      print('MapMeasureDependentRenderSize Instantiation Exception: ${e.toString()}');
    }
    return null;
  }

  void _animateToRoute(here.Route route) {
    // The animation results in an untilted and unrotated map.
    double bearing = 0;
    double tilt = 0;
    // We want to show the route fitting in the map view with an additional padding of 50 pixels.
    Point2D origin = Point2D(50, 50);
    Size2D sizeInPixels = Size2D(
      _hereMapController.viewportSize.width - 100,
      _hereMapController.viewportSize.height - 100,
    );
    Rectangle2D mapViewport = Rectangle2D(origin, sizeInPixels);

    // Animate to the route within a duration of 3 seconds.
    MapCameraUpdate update = MapCameraUpdateFactory.lookAtAreaWithGeoOrientationAndViewRectangle(
      route.boundingBox,
      GeoOrientationUpdate(bearing, tilt),
      mapViewport,
    );
    MapCameraAnimation animation = MapCameraAnimationFactory.createAnimationFromUpdateWithEasing(
      update,
      const Duration(milliseconds: 3000),
      here.Easing(here.EasingFunction.inCubic),
    );
    _hereMapController.camera.startAnimation(animation);
  }

  // A hardcoded segment in Berlin that will be used as fallback to create
  // AvoidanceOptions when no segments have been picked yet.
  SegmentReference createSegmentInBerlin() {
    // Alternatively, segmentId and tilePartitionId can be obtained from each span of a Route object.
    // For example, the segmentId and tilePartitionId used below were taken from a route.
    final segmentId = 'here:cm:segment:807958890';
    final tilePartitionId = 377894441;

    final currentlySelectedSegmentReference = SegmentReference();
    currentlySelectedSegmentReference.segmentId = segmentId;
    currentlySelectedSegmentReference.tilePartitionId = tilePartitionId;

    return currentlySelectedSegmentReference;
  }

  MapMarker _addMapMarker(GeoCoordinates geoCoordinates, String assetPath) {
    final mapImage = MapImage.withFilePathAndWidthAndHeight(assetPath, 100, 100); // adjust size as needed
    final anchor2D = Anchor2D.withHorizontalAndVertical(0.5, 1.0);
    final mapMarker = MapMarker.withAnchor(geoCoordinates, mapImage, anchor2D);
    _hereMapController.mapScene.addMapMarker(mapMarker);
    return mapMarker;
  }
}
