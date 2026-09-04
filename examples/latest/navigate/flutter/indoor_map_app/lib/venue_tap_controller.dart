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
import 'package:indoor_map_app/indoor_topology_info.dart';
import 'package:indoor_map_app/venue_data_provider_interface.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.data.dart';
import 'package:here_sdk/venue.routing.dart';
import 'package:here_sdk/venue.style.dart';

/// Tap controller for the indoor map.
///
/// Handles geometry and topology selection on the map and forwards events to
/// [VenueDataProviderInterface] and [IndoorRoutingDataProviderInterface].
class VenueTapController {
  VenueTapController({
    required this.hereMapController,
    required this.venueMap,
    required this.venueDataProviderInterface,
    required this.routingDataProviderInterface,
  }) {
    if (venueMap == null) {
      debugPrint('VenueTapController: venueMap is null');
      return;
    }
    levelChangeListener = VenueLevelSelectionListener((
      Venue venue,
      VenueDrawing drawing,
      VenueLevel? oldLevel,
      VenueLevel newLevel,
    ) {
      onLevelChanged(venue);
    });
    drawingChangeListener = VenueDrawingSelectionListener((
      Venue venue,
      VenueDrawing? oldDrawing,
      VenueDrawing newDrawing,
    ) {
      onLevelChanged(venue);
    });
    venueMap?.addLevelSelectionListener(levelChangeListener);
    venueMap?.addDrawingSelectionListener(drawingChangeListener);
    markerImage = MapImage.withFilePathAndWidthAndHeight('assets/indoor_route_end.svg', 100, 100);
  }

  HereMapController? hereMapController;
  VenueMap? venueMap;
  VenueDataProviderInterface venueDataProviderInterface;
  IndoorRoutingDataProviderInterface routingDataProviderInterface;
  Venue? selectedVenue;
  VenueGeometry? selectedGeometry;
  VenueTopology? selectedTopology;
  MapImage? markerImage;
  MapMarker? marker;
  final Anchor2D anchor2D = Anchor2D.withHorizontalAndVertical(0.5, 1.0);
  late VenueLevelSelectionListener levelChangeListener;
  late VenueDrawingSelectionListener drawingChangeListener;
  // When true, onLevelChanged skips deselect during intentional list selection.
  bool _isSelectingFromList = false;

  static const int _alpha = 255;

  final VenueGeometryStyle geometryStyle = VenueGeometryStyle(
    Color.fromARGB(_alpha, 72, 187, 245),
    Color.fromARGB(_alpha, 30, 170, 235),
    1,
  );
  final VenueLabelStyle labelStyle = VenueLabelStyle(
    Color.fromARGB(_alpha, 255, 255, 255),
    Color.fromARGB(_alpha, 0, 130, 195),
    1,
    28,
  );
  final VenueGeometryStyle topologyStyle = VenueGeometryStyle(
    Color.fromARGB(_alpha, 72, 187, 245),
    Color.fromARGB(_alpha, 90, 196, 193),
    4,
  );

  void removeListener() {
    venueMap?.removeLevelSelectionListener(levelChangeListener);
    venueMap?.removeDrawingSelectionListener(drawingChangeListener);
  }

  void onTap(Point2D origin) {
    if (selectedGeometry != null) {
      deselectGeometry();
      selectedGeometry = null;
    }
    if (selectedTopology != null) {
      deselectTopology();
      selectedTopology = null;
    }

    final GeoCoordinates? position = hereMapController!.viewToGeoCoordinates(origin);
    if (position == null) return;

    final VenueTopology? topology = venueMap?.getTopology(position);
    final VenueGeometry? geometry = venueMap?.getGeometry(position);

    if (topology != null) {
      selectTopology(topology, position);
    } else if (geometry != null) {
      selectGeometry(geometry, position, false);
    } else {
      final Venue? venue = venueMap?.getVenue(position);
      if (venue != null) {
        venueMap?.selectedVenue = venue;
      }
    }
  }

  /// Selects a geometry from the bottom sheet list with a guard to prevent
  /// the deselect-reselect cycle when level/drawing changes.
  void selectGeometryFromList(VenueGeometry geometry) {
    _isSelectingFromList = true;
    drawingChangeBasedOnGeometrySelection(geometry);
    levelChangeBasedOnGeometrySelection(geometry);
    selectGeometry(geometry, geometry.center, true);
    _isSelectingFromList = false;
  }

  void selectGeometry(VenueGeometry geometry, GeoCoordinates position, bool center) {
    deselectGeometry();
    selectedVenue = venueMap?.selectedVenue;
    if (selectedVenue == null) return;

    selectedGeometry = geometry;
    if (selectedVenue!.venueModel.topologies.isEmpty) {
      venueDataProviderInterface.showTappedGeometryInfo(geometry);
      if (selectedGeometry?.lookupType == VenueGeometryLookupType.icon) {
        _addMarkerImageToMap(position);
      }
    } else {
      routingDataProviderInterface.onSpaceSelectionForPreview(selectedGeometry!, position);
    }
    selectedVenue?.setCustomStyle(<VenueGeometry>[geometry], geometryStyle, labelStyle);
    if (center) {
      hereMapController!.camera.lookAtPoint(position);
    }
    debugPrint(
      'Selected Geometry: ${geometry.identifier}, level: ${geometry.level.shortName}, drawing: ${geometry.level.drawing.identifier}',
    );
  }

  void deselectGeometry() {
    if (routingDataProviderInterface.isRoutingSpacePreviewUIActiveOnMap()) {
      routingDataProviderInterface.onSpaceDeselectionOnMap();
      return;
    }
    if (marker != null) {
      hereMapController!.mapScene.removeMapMarker(marker!);
      marker = null;
    }
    if (selectedVenue != null && selectedGeometry != null) {
      selectedVenue?.setCustomStyle(<VenueGeometry>[selectedGeometry!], null, null);
    }
    selectedGeometry = null;
    venueDataProviderInterface.onDeselectGeometryFromTapController();
  }

  void _addMarkerImageToMap(GeoCoordinates coordinates) {
    if (markerImage == null) return;
    marker = MapMarker.withAnchor(coordinates, markerImage!, anchor2D);
    if (marker != null) {
      hereMapController?.mapScene.addMapMarker(marker!);
    }
  }

  void selectTopology(VenueTopology topology, GeoCoordinates position) {
    selectedVenue = venueMap?.selectedVenue;
    if (selectedVenue == null) return;
    selectedTopology = topology;

    final List<VenueTransportMode> modes = <VenueTransportMode>[];
    final List<VenueTopologyTopologyDirectionality> directions = <VenueTopologyTopologyDirectionality>[];
    final VenueTopologyAccessCharacteristicsList accessList = topology.accessibility;
    for (final VenueTopologyAccessCharacteristics access in accessList) {
      modes.add(access.mode);
      directions.add(access.direction);
    }

    venueDataProviderInterface.showTappedTopologyInfo(
      IndoorTopologyInfo(topologyId: topology.identifier, modes: modes, directions: directions),
    );

    selectedVenue?.setCustomStyleToTopology(<VenueTopology>[topology], topologyStyle);
    hereMapController!.camera.lookAtPoint(position);
  }

  void deselectTopology() {
    if (selectedVenue != null && selectedTopology != null) {
      selectedVenue?.setCustomStyleToTopology(<VenueTopology>[selectedTopology!], null);
    }
    selectedTopology = null;
    venueDataProviderInterface.onDeselectTopologyFromTapController();
  }

  void levelChangeBasedOnGeometrySelection(VenueGeometry geometry) {
    selectedVenue = venueMap?.selectedVenue;
    if (geometry.level.identifier != selectedVenue?.selectedLevel.identifier) {
      selectedVenue?.selectedLevel = geometry.level;
      venueDataProviderInterface.onLevelChangeAfterGeometrySelection(
        selectedVenue!.selectedDrawing.levels.length - 1 - selectedVenue!.selectedLevelIndex,
      );
    }
  }

  void drawingChangeBasedOnGeometrySelection(VenueGeometry geometry) {
    selectedVenue = venueMap?.selectedVenue;
    if (selectedVenue?.selectedDrawing.identifier != geometry.level.drawing.identifier) {
      selectedVenue?.selectedDrawing = geometry.level.drawing;
      final int drawingIndex = selectedVenue!.venueModel.drawings.indexWhere(
        (VenueDrawing d) => d.identifier == geometry.level.drawing.identifier,
      );
      if (drawingIndex != -1) {
        venueDataProviderInterface.onDrawingChangeAfterGeometrySelection(drawingIndex);
      }
    }
  }

  void onLevelChanged(Venue venue) {
    // Skip deselect when selecting from list (level change is intentional).
    if (_isSelectingFromList) return;

    if (routingDataProviderInterface.isRoutingMainMenuUIActiveOnMap() ||
        routingDataProviderInterface.isRoutingSpacePreviewUIActiveOnMap()) {
      routingDataProviderInterface.handleDestinationMarkerOnMapInLevelChange();
      return;
    }
    if ((venue == selectedVenue) && (selectedGeometry != null) && (venue.selectedLevel == selectedGeometry?.level)) {
      return;
    }
    deselectTopology();
    deselectGeometry();
  }
}
