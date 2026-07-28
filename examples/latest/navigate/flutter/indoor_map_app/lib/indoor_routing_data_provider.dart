/*
 * Copyright (C) 2020-2026 HERE Europe B.V.
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

import 'package:flutter/cupertino.dart';
import 'package:indoor_map_app/indoor_routing_data_provider_interface.dart';
import 'package:indoor_map_app/venue_data_provider_interface.dart';
import 'package:indoor_map_app/venue_error_data.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart' as routing;
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.dart';
import 'package:here_sdk/venue.data.dart';
import 'package:here_sdk/venue.routing.dart';

/// Routing UI state machine.
enum RoutingUIState { hidden, spacePreview, mainRoutingMenu, spaceSelectionList }

enum EditingField { source, destination }

enum IndoorMarkerName { unknown, source, destination, walk, drive }

Anchor2D middleBottomAnchor = Anchor2D.withHorizontalAndVertical(0.5, 1.0);
Anchor2D centerAnchor = Anchor2D.withHorizontalAndVertical(0.5, 0.5);
String get tag => 'IndoorUtils';
const int indoorMarkerHeight = 64;
const int indoorMarkerWidth = 64;
const int indoorDestinationMarkerHeight = 100;
const int indoorDestinationMarkerWidth = 100;

/// convert screen coordinates to an [IndoorWaypoint].
IndoorWaypoint? _toWaypoint(VenueMap venueMap, GeoCoordinates coordinates) {
  final Venue? venue = venueMap.selectedVenue;
  if (venue != null) {
    return IndoorWaypoint(coordinates, venue.venueModel.identifier, venue.selectedLevel.identifier);
  }
  return IndoorWaypoint.withOutdoorCoordinates(coordinates);
}

/// convert geometry centre to an [IndoorWaypoint] for the given level.
IndoorWaypoint? _toWaypointWithLevel(VenueMap venueMap, GeoCoordinates coordinates, VenueLevel venueLevel) {
  final Venue? venue = venueMap.selectedVenue;
  if (venue != null) {
    return IndoorWaypoint(coordinates, venue.venueModel.identifier, venueLevel.identifier);
  }
  return IndoorWaypoint.withOutdoorCoordinates(coordinates);
}

class IndoorRoutingDataProvider extends ChangeNotifier implements IndoorRoutingDataProviderInterface {
  static String get _tag => 'IndoorRoutingDataProvider';

  VenueEngine? venueEngine;
  late VenueMap venueMap;
  late HereMapController _mapController;
  Venue? selectedVenue;
  List<VenueGeometry>? geometryList;
  VenueGeometry? selectedDestination;
  VenueGeometry? selectedSource;
  IndoorWaypoint? srcWayPoint;
  IndoorWaypoint? dstWayPoint;
  GeoCoordinates? srcPosition;
  GeoCoordinates? dstPosition;
  RoutingUIState currentState = RoutingUIState.hidden;
  EditingField? activeField;
  late VenueDataProviderInterface _venueDataProviderInterface;
  late IndoorRoutingEngine routingEngine;
  late IndoorRoutingController controller;
  final IndoorRouteOptions routeOptions = IndoorRouteOptions();
  final IndoorRouteStyle routeStyle = IndoorRouteStyle();
  MapMarker? dstMarker;
  MapImage? dstMarkerImage = MapImage.withFilePathAndWidthAndHeight(
    'assets/indoor_route_end.svg',
    indoorDestinationMarkerWidth,
    indoorDestinationMarkerHeight,
  );
  bool isRouteCalculating = false;
  bool isRouteRenderedOnMap = false;
  String? routingWarningMsg;
  final List<routing.IndoorLevelChangeFeatures> _pedestrianFeatures = <routing.IndoorLevelChangeFeatures>[
    routing.IndoorLevelChangeFeatures.elevator,
    routing.IndoorLevelChangeFeatures.escalator,
    routing.IndoorLevelChangeFeatures.stairs,
    routing.IndoorLevelChangeFeatures.pedestrianRamp,
    routing.IndoorLevelChangeFeatures.elevatorBank,
  ];

  void initializeIndoorRoutingDataProvider(
    VenueEngine engine,
    HereMapController mapController,
    VenueDataProviderInterface providerInterface,
  ) {
    _venueDataProviderInterface = providerInterface;
    _mapController = mapController;
    venueEngine = engine;
    if (venueEngine == null) {
      debugPrint('$_tag: VenueEngine is null');
      final VenueErrorData errorData = VenueErrorData(
        errorType: VenueErrorType.venueEngineFailure,
        title: _tag,
        errorMessage: 'VenueEngine set is null',
      );
      _venueDataProviderInterface.setVenueErrorData(errorData);
      return;
    }
    debugPrint('$_tag: initialized');
    venueMap = venueEngine!.venueMap;
    routingEngine = IndoorRoutingEngine(venueEngine!.venueService);
    controller = IndoorRoutingController(venueMap, _mapController);
    _setupIndoorRouteStyle();
  }

  MapMarker? getMapMarkerFromSvgFile(IndoorMarkerName name) {
    MapImage markerImage;
    String svgFileName = '';
    int height = indoorMarkerHeight;
    int width = indoorMarkerWidth;
    Anchor2D anchor = middleBottomAnchor;
    try {
      if (name == IndoorMarkerName.walk) {
        svgFileName = 'assets/indoor_walk.svg';
      } else if (name == IndoorMarkerName.drive) {
        svgFileName = 'assets/indoor_drive.svg';
      } else if (name == IndoorMarkerName.source) {
        svgFileName = 'assets/indoor_route_start.svg';
        anchor = centerAnchor;
      } else if (name == IndoorMarkerName.destination) {
        svgFileName = 'assets/indoor_route_end.svg';
        height = indoorDestinationMarkerHeight;
        width = indoorDestinationMarkerWidth;
      }
      if (svgFileName.isEmpty) {
        debugPrint('$tag: No SVG file found for feature: $name');
        return null;
      }
      markerImage = MapImage.withFilePathAndWidthAndHeight(svgFileName, width, height);
      return MapMarker.withAnchor(GeoCoordinates(0.0, 0.0), markerImage, anchor);
    } on InstantiationException catch (e) {
      debugPrint('$tag: Map Marker Image creation from SVG failed for feature: $name, with reason: $e');
    }
    return null;
  }

  MapMarker? getFeatureMapMarkerFromSvgFile(routing.IndoorLevelChangeFeatures feature, int deltaZ) {
    // deltaZ = 0 => No vertical level change.
    // deltaZ = 1 => Up marker to indicate move to upper level.
    // deltaZ = -1 => Down marker to indicate move to lower level.
    MapImage markerImage;
    String svgFileName = '';
    try {
      if (feature == routing.IndoorLevelChangeFeatures.elevator) {
        switch (deltaZ) {
          case 0:
            svgFileName = 'assets/indoor_elevator.svg';
            break;
          case 1:
            svgFileName = 'assets/indoor_elevator_up.svg';
            break;
          case -1:
            svgFileName = 'assets/indoor_elevator_down.svg';
            break;
        }
      } else if (feature == routing.IndoorLevelChangeFeatures.escalator) {
        switch (deltaZ) {
          case 0:
            svgFileName = 'assets/indoor_escalator.svg';
            break;
          case 1:
            svgFileName = 'assets/indoor_escalator_up.svg';
            break;
          case -1:
            svgFileName = 'assets/indoor_escalator_down.svg';
            break;
        }
      } else if (feature == routing.IndoorLevelChangeFeatures.pedestrianRamp) {
        switch (deltaZ) {
          case 0:
            svgFileName = 'assets/indoor_ramp.svg';
            break;
          case 1:
            svgFileName = 'assets/indoor_ramp_up.svg';
            break;
          case -1:
            svgFileName = 'assets/indoor_ramp_down.svg';
            break;
        }
      } else if (feature == routing.IndoorLevelChangeFeatures.stairs) {
        switch (deltaZ) {
          case 0:
            svgFileName = 'assets/indoor_stair.svg';
            break;
          case 1:
            svgFileName = 'assets/indoor_stair_up.svg';
            break;
          case -1:
            svgFileName = 'assets/indoor_stair_down.svg';
            break;
        }
      } else {
        debugPrint('$tag: Map Marker Image creation from SVG not supported for feature: $feature');
      }

      if (svgFileName.isEmpty) {
        debugPrint('$tag: No SVG file found for feature: $feature, delta: $deltaZ');
        return null;
      }
      markerImage = MapImage.withFilePathAndWidthAndHeight(svgFileName, indoorMarkerWidth, indoorMarkerHeight);
      return MapMarker.withAnchor(GeoCoordinates(0.0, 0.0), markerImage, middleBottomAnchor);
    } on InstantiationException catch (e) {
      debugPrint(
        '$tag: Map Marker Image creation from SVG failed for feature: $feature, delta:$deltaZ, with reason: $e',
      );
    }
    return null;
  }

  void _setupIndoorRouteStyle() {
    routeStyle.startMarker = getMapMarkerFromSvgFile(IndoorMarkerName.source);
    routeStyle.destinationMarker = getMapMarkerFromSvgFile(IndoorMarkerName.destination);
    routeStyle.walkMarker = getMapMarkerFromSvgFile(IndoorMarkerName.walk);
    routeStyle.driveMarker = getMapMarkerFromSvgFile(IndoorMarkerName.drive);

    for (final routing.IndoorLevelChangeFeatures feature in _pedestrianFeatures) {
      final MapMarker? marker = getFeatureMapMarkerFromSvgFile(feature, 0);
      final MapMarker? upMarker = getFeatureMapMarkerFromSvgFile(feature, 1);
      final MapMarker? downMarker = getFeatureMapMarkerFromSvgFile(feature, -1);
      routeStyle.setIndoorMarkersFor(feature, upMarker, downMarker, marker);
    }
  }

  @override
  void dispose() {
    _resetParams();
    super.dispose();
  }

  void _resetParams() {
    venueEngine = null;
    selectedVenue = null;
    geometryList = null;
    selectedDestination = null;
    selectedSource = null;
    srcWayPoint = null;
    dstWayPoint = null;
    srcPosition = null;
    dstPosition = null;
    currentState = RoutingUIState.hidden;
    activeField = null;
    dstMarker = null;
    dstMarkerImage = null;
    isRouteCalculating = false;
    isRouteRenderedOnMap = false;
  }

  void _setSelectedVenueForRouting() {
    selectedVenue = venueMap.selectedVenue;
    if (selectedVenue != null) {
      geometryList = selectedVenue!.venueModel.geometries;
    }
  }

  void setRoutingWarningMsg(String msg) {
    routingWarningMsg = msg.isEmpty ? null : msg;
    notifyListeners();
  }

  bool checkWaypointsEqual(IndoorWaypoint src, IndoorWaypoint dst) {
    return (src.coordinates.latitude == dst.coordinates.latitude &&
            src.coordinates.longitude == dst.coordinates.longitude) &&
        src.levelId == dst.levelId;
  }

  void calculateRoute() {
    if (selectedDestination == null || selectedSource == null) return;
    if (srcWayPoint == null) {
      setRoutingWarningMsg('Source waypoint is null');
      return;
    }
    if (dstWayPoint == null) {
      setRoutingWarningMsg('Destination waypoint is null');
      return;
    }
    if (checkWaypointsEqual(srcWayPoint!, dstWayPoint!)) {
      setRoutingWarningMsg('Source and destination are the same');
      return;
    }
    showProgressBarOnMap(true);
    routingEngine.calculateRouteWithRouteNotices(srcWayPoint!, dstWayPoint!, routeOptions, _showRouteInMap);
    debugPrint(
      '$_tag: Route calculation called with Source[levelId: ${srcWayPoint?.levelId}, levelName: '
      '${selectedSource?.level.shortName}, latitude: ${srcWayPoint?.coordinates.latitude}, longitude: '
      '${srcWayPoint?.coordinates.longitude}], Destination[levelId: ${dstWayPoint?.levelId}, levelName:'
      '${selectedDestination?.level.shortName}, latitude:${dstWayPoint?.coordinates.latitude}, longitude: ${dstWayPoint?.coordinates.longitude}]',
    );
  }

  void showProgressBarOnMap(bool val) {
    isRouteCalculating = val;
    notifyListeners();
  }

  void _showRouteInMap(IndoorRoutingError? indoorRoutingError, List<routing.Route>? routeList, List<IndoorRouteNotice>? routeNotices) {
    showProgressBarOnMap(false);
    controller.hideRoute();
    if (currentState == RoutingUIState.hidden || currentState == RoutingUIState.spacePreview) {
      return;
    }
    if (indoorRoutingError == null) {
      if (routeList != null && routeList.isNotEmpty) {
        final routing.Route route = routeList.first;
        if (route.lengthInMeters <= 0) {
          setRoutingWarningMsg('Source and destination are the same');
          return;
        }
        controller.showRoute(route, routeStyle);

        if (selectedVenue?.selectedLevel != selectedSource?.level) {
          selectedVenue?.selectedLevel = selectedSource!.level;
          _venueDataProviderInterface.onLevelChangeAfterGeometrySelection(
            selectedVenue!.selectedDrawing.levels.length - 1 - selectedVenue!.selectedLevelIndex,
          );
        }
        _mapController.camera.lookAtPoint(srcPosition!);
        _removeDstMarker();
        isRouteRenderedOnMap = true;
        currentState = RoutingUIState.mainRoutingMenu;
        notifyListeners();
      } else {
        isRouteRenderedOnMap = false;
        setRoutingWarningMsg('No route found.');
      }
    } else if (indoorRoutingError != null) {
      isRouteRenderedOnMap = false;
      final String errorMsg = _routingErrorToString(indoorRoutingError);
      setRoutingWarningMsg('Route calculation failed: $errorMsg');
    }
    if (routeNotices != null && routeNotices.isNotEmpty) {
      isRouteRenderedOnMap = false;
      final String noticeMessages = routeNotices.map((notice) => notice.title).join('\n');
      setRoutingWarningMsg('Route notices: $noticeMessages');
    }
  }

  String _routingErrorToString(IndoorRoutingError? error) {
    switch (error) {
      case IndoorRoutingError.noNetwork:
        return 'No network connection';
      case IndoorRoutingError.badRequest:
        return 'Bad request';
      case IndoorRoutingError.unauthorizedAccess:
        return 'Unauthorized access';
      case IndoorRoutingError.forbidden:
        return 'Forbidden';
      case IndoorRoutingError.notFound:
        return 'Not found';
      case IndoorRoutingError.tooManyRequests:
        return 'Too many requests';
      case IndoorRoutingError.internalServerError:
        return 'Internal server error';
      case IndoorRoutingError.badGateway:
        return 'Bad gateway';
      case IndoorRoutingError.serviceUnavailable:
        return 'Service unavailable';
      case IndoorRoutingError.mapNotFound:
        return 'Map not found';
      case IndoorRoutingError.parsingError:
        return 'Parsing error';
      default:
        return 'Unknown error';
    }
  }

  void _removeDstMarker() {
    if (dstMarker != null) {
      _mapController.mapScene.removeMapMarker(dstMarker!);
      dstMarker = null;
    }
  }

  void _handleDestinationMarkerOnMap() {
    if (isRouteRenderedOnMap) return;
    final Venue? venue = venueMap.selectedVenue;
    if (venue == null) return;
    if (selectedDestination?.level != venue.selectedLevel) {
      _removeDstMarker();
    } else if (dstMarker == null) {
      // If dstMarker is not null, it means marker is already on screen, no need
      // to put again. This scenario can happen when space selection happens from list
      // of spaces and at the same time level change is also detected.
      dstMarker = MapMarker.withAnchor(dstPosition!, dstMarkerImage!, middleBottomAnchor);
      if (dstMarker != null) {
        _mapController.mapScene.addMapMarker(dstMarker!);
        debugPrint(
          'Added Destination Marker at coordinates, lat:${dstPosition?.latitude}, lng:${dstPosition?.longitude}, level:${selectedDestination?.level.shortName}',
        );
      }
    }
  }

  void filterSpaces(String query) {
    final VenueModel? venueModel = selectedVenue?.venueModel;
    geometryList = venueModel?.geometries;
    if (query.isEmpty) {
      notifyListeners();
      return;
    }
    final List<int> indices = <int>[];
    for (int i = 0; i < (geometryList?.length ?? 0); i++) {
      final VenueGeometry g = geometryList![i];
      final String name = '${g.name.isNotEmpty ? g.name : g.identifier}, ${g.level.name}';
      if (name.toLowerCase().contains(query)) {
        indices.add(i);
      }
    }
    geometryList = indices.map((int i) => geometryList![i]).toList();
    notifyListeners();
  }

  void closeSpacePreviewUI() {
    if (selectedDestination != null) {
      venueMap.selectedVenue?.setCustomStyle(<VenueGeometry>[selectedDestination!], null, null);
    }
    _removeDstMarker();
    selectedDestination = null;
    dstWayPoint = null;
    dstPosition = null;
    currentState = RoutingUIState.hidden;
    notifyListeners();
  }

  void closeMainRoutingMenuUI() {
    srcWayPoint = null;
    selectedSource = null;
    srcPosition = null;
    currentState = RoutingUIState.spacePreview;
    _venueDataProviderInterface.showTopologyButtonOnMap(true);
    controller.hideRoute();
    if (isRouteCalculating) showProgressBarOnMap(false);
    isRouteRenderedOnMap = false;
    notifyListeners();
  }

  void closeSpaceSelectionListUI() {
    currentState = RoutingUIState.mainRoutingMenu;
    activeField = null;
    notifyListeners();
  }

  void handleBackButtonEvent() {
    switch (currentState) {
      case RoutingUIState.spaceSelectionList:
        closeSpaceSelectionListUI();
        // As Space Selection List UI is closed, we should show Main Menu UI
        onDirectionButtonClickInPreviewMode();
        break;
      case RoutingUIState.mainRoutingMenu:
        closeMainRoutingMenuUI();
        // As Main Menu UI is closed, we should show Space Selection UI
        onSpaceSelectionForPreview(selectedDestination!, dstPosition!);
        break;
      case RoutingUIState.spacePreview:
        closeSpacePreviewUI();
        break;
      case RoutingUIState.hidden:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // IndoorRoutingDataProviderInterface implementation
  // ---------------------------------------------------------------------------

  @override
  void onSpaceSelectionForPreview(VenueGeometry selectedGeometry, GeoCoordinates position) {
    currentState = RoutingUIState.spacePreview;
    isRouteRenderedOnMap = false;
    _setSelectedVenueForRouting();
    _removeDstMarker();
    controller.hideRoute();
    selectedDestination = selectedGeometry;
    dstWayPoint = _toWaypoint(venueMap, position);
    dstPosition = position;
    _handleDestinationMarkerOnMap();
    notifyListeners();
  }

  @override
  void onDirectionButtonClickInPreviewMode() {
    currentState = RoutingUIState.mainRoutingMenu;
    isRouteRenderedOnMap = false;
    _venueDataProviderInterface.showTopologyButtonOnMap(false);
    if (selectedDestination != null) {
      venueMap.selectedVenue?.setCustomStyle(<VenueGeometry>[selectedDestination!], null, null);
    }
    notifyListeners();
    calculateRoute();
  }

  @override
  void onEditDestinationInRoutingMenuMode() {
    currentState = RoutingUIState.spaceSelectionList;
    activeField = EditingField.destination;
    notifyListeners();
  }

  @override
  void onEditSourceInRoutingMenuMode() {
    currentState = RoutingUIState.spaceSelectionList;
    activeField = EditingField.source;
    notifyListeners();
  }

  @override
  void onSpaceSelectionFromList(VenueGeometry selectedGeometry) {
    currentState = RoutingUIState.mainRoutingMenu;
    _setSelectedVenueForRouting();
    if (activeField == EditingField.source) {
      selectedSource = selectedGeometry;
      srcWayPoint = _toWaypointWithLevel(venueMap, selectedGeometry.center, selectedGeometry.level);
      srcPosition = selectedGeometry.center;
    } else {
      selectedDestination = selectedGeometry;
      dstWayPoint = _toWaypointWithLevel(venueMap, selectedGeometry.center, selectedGeometry.level);
      dstPosition = selectedGeometry.center;
    }
    activeField = null;
    notifyListeners();
    calculateRoute();
  }

  @override
  void onTransportModeChangeInRoutingMenuMode(VenueTransportMode mode) {
    routeOptions.transportMode = mode;
    notifyListeners();
    calculateRoute();
  }

  @override
  void onSourceSelectionByTapOnMapInRoutingMenuMode(VenueGeometry selectedGeometry, GeoCoordinates position) {
    selectedSource = selectedGeometry;
    srcPosition = position;
    srcWayPoint = _toWaypoint(venueMap, position);
    notifyListeners();
    calculateRoute();
  }

  @override
  bool isRoutingMainMenuUIActiveOnMap() => currentState == RoutingUIState.mainRoutingMenu;

  @override
  bool isRoutingSpaceSelectionUIActiveOnMap() => currentState == RoutingUIState.spacePreview;

  @override
  void onSpaceDeselectionOnMap() {
    closeSpacePreviewUI();
    notifyListeners();
  }

  @override
  void handleDestinationMarkerOnMapInLevelChange() {
    _handleDestinationMarkerOnMap();
  }

  @override
  void onTap(Point2D origin) {
    final GeoCoordinates? position = _mapController.viewToGeoCoordinates(origin);
    if (position == null) {
      controller.hideRoute();
      selectedSource = null;
      srcPosition = null;
      srcWayPoint = null;
      isRouteRenderedOnMap = false;
      return;
    }
    if (currentState == RoutingUIState.mainRoutingMenu) {
      final VenueGeometry? geometry = venueMap.getGeometry(position);
      if (geometry != null) {
        onSourceSelectionByTapOnMapInRoutingMenuMode(geometry, position);
      } else {
        controller.hideRoute();
        selectedSource = null;
        srcWayPoint = null;
        srcPosition = null;
        isRouteRenderedOnMap = false;
        notifyListeners();
      }
    }
  }
}
