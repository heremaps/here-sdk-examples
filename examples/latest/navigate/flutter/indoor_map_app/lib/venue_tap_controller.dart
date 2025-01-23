/*
 * Copyright (C) 2020-2025 HERE Europe B.V.
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

import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/src/sdk/venue/routing/venue_transport_mode.dart';
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.data.dart';
import 'package:here_sdk/venue.style.dart';
import 'package:here_sdk/venue.dart';
import 'package:indoor_map_app/geometry_info.dart';
import 'package:indoor_map_app/image_helper.dart';
import 'events.dart';
import 'events.dart';

enum TopologyDirectionality { toStart, fromStart, bidirectional, undefined }
enum VenueTransportMode { auto, taxi, motorcycle, emergencyVehicle, pedestrian }

class VenueTapController {
  final HereMapController? hereMapController;
  final VenueMap venueMap;
  final GeometryInfoState? geometryInfoState;
  String tappedSpaceName = "";
  int clickCount = 0;
  int lineCount = 0;
  String topologyDetails = "";

  MapImage? _markerImage;
  MapMarker? _marker;
  Venue? _selectedVenue;
  VenueGeometry? _selectedGeometry;
  VenueTopology? _selectedTopology;

  // Create geometry and label styles for the selected geometry.
  final VenueGeometryStyle _geometryStyle =
      VenueGeometryStyle(Color.fromARGB(255, 72, 187, 245), Color.fromARGB(255, 30, 170, 235), 1);
  final VenueLabelStyle _labelStyle =
      VenueLabelStyle(Color.fromARGB(255, 255, 255, 255), Color.fromARGB(255, 0, 130, 195), 1, 28);
  final VenueGeometryStyle _topologyStyle =
      VenueGeometryStyle(Color.fromARGB(255, 72, 187, 245), Color.fromARGB(255, 90, 196, 193), 4);

  VenueTapController({required this.hereMapController, required this.venueMap, required this.geometryInfoState}) {
    // Get an image for MapMarker.
    ImageHelper.loadFileAsUint8List('poi.png')
        .then((imagePixelData) => _markerImage = MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png));
  }

  onTap(Point2D origin) {
    _deselectGeometry();
    deselectTopology();

    // Get geo coordinates of the tapped point.
    GeoCoordinates? position = hereMapController!.viewToGeoCoordinates(origin);
    if (position == null) {
      return;
    }

    VenueTopology? topology = venueMap.getTopology(position);
    if (topology != null) {
      selectTopology(topology, position);
    } else {
      // Get a VenueGeometry under the tapped position.
      VenueGeometry? geometry = venueMap.getGeometry(position);
      if (geometry != null) {
        spaceTapped.isSpaceTapped.value = false;
        spaceTapped.isSpaceTapped.value = true;
        clickCount = 1;
        selectGeometry(geometry, position, false);
        tappedSpaceName = geometry.name + ", " + geometry.level.name;
        print('tappedSpaceName : $tappedSpaceName');
      } else {
        spaceTapped.isSpaceTapped.value = false;
        // If no geometry was tapped, check if there is a not-selected venue under
        // the tapped position. If there is one, select it.
        Venue? venue = venueMap.getVenue(position);
        if (venue != null) {
          venueMap.selectedVenue = venue;
        }
      }
    }
  }

  onLevelChanged(Venue? selectedVenue) {
    if (selectedVenue == _selectedVenue &&
        _selectedGeometry != null &&
        selectedVenue!.selectedLevel == _selectedGeometry!.level) {
      return;
    }
    _deselectGeometry();
  }

  selectTopology(VenueTopology topology, GeoCoordinates position) {
    _selectedVenue = venueMap.selectedVenue;
    topologyDetails = getTopologyInfo(topology);
    _selectedTopology = topology;
    if(_selectedTopology != null) {
      topologyLineTapped.isTopologyLineTapped.value = true;
      _selectedVenue!.setCustomStyleToTopology([topology], _topologyStyle);
    }
    _selectedTopology = topology;

    hereMapController!.camera.lookAtPoint(position);
  }

  String getTopologyInfo(VenueTopology topology) {
    StringBuffer result = StringBuffer();
    Map<String, List<String>> vehicleGroups = {};
    String pedestrianDirectionality = " ";
    lineCount = 0;

    // First line: topology ID
    result.writeln(topology.identifier);
    lineCount++;

    // Process accessibility
    for (int i = 0; i < topology.accessibility.length; i++) {
      var access = topology.accessibility[i];
      var mode = access.mode;
      String imageName = '';

      switch (mode.name) {
        case 'auto':
          imageName = 'img_car';
          break;
        case 'taxi':
          imageName = 'img_taxi';
          break;
        case 'motorcycle':
          imageName = 'img_bike';
          break;
        case 'emergencyVehicle':
          imageName = 'img_ambulance';
          break;
        case 'pedestrian':
          imageName = 'img_pedestrian';
          pedestrianDirectionality = access.direction.name;
          break;
      }

      if (mode.name == 'pedestrian') {
        // Second line: pedestrian image and directionality
        result.write('img_pedestrian.png ');
        if (pedestrianDirectionality.isNotEmpty) {
          result.writeln(pedestrianDirectionality.toUpperCase());
          lineCount++;
        }
      } else if (imageName.isNotEmpty) {
        var direction = access.direction.name;

        vehicleGroups.putIfAbsent(direction, () => []);
        vehicleGroups[direction]!.add(imageName);
      }
    }

    // Process vehicle groups
    for (var direction in vehicleGroups.keys) {
      var imageNames = vehicleGroups[direction];
      if (imageNames != null && imageNames.isNotEmpty) {
        for (var imageName in imageNames) {
          result.write('$imageName.png ');
        }
        result.writeln(direction.toUpperCase());
        lineCount++;
      }
    }

    return result.toString();
  }

  deselectTopology() {
    if (_selectedVenue != null && _selectedTopology != null) {
      _selectedVenue!.setCustomStyleToTopology([_selectedTopology!], null);
      _selectedTopology = null;
    }
    topologyLineTapped.isTopologyLineTapped.value = false;
  }

  selectGeometry(VenueGeometry geometry, GeoCoordinates position, bool center) {
    _deselectGeometry();
    _selectedVenue = venueMap.selectedVenue;
    _selectedVenue!.selectedDrawing = geometry.level.drawing;
    _selectedVenue!.selectedLevel = geometry.level;
    _selectedGeometry = geometry;
    // Set a selected geometry to the GeometryInfoState, to display
    // the information about it.
    geometryInfoState!.geometry = geometry;
    // Set a selected style for the geometry.
    _selectedVenue!.setCustomStyle([geometry], _geometryStyle, _labelStyle);
    // If there is a geometry, put a marker on top of it.
    if (_selectedGeometry!.lookupType == VenueGeometryLookupType.icon) {
      _addPOIMapMarker(position);
    }
    if (center) {
      hereMapController!.camera.lookAtPoint(position);
    }
  }

  _deselectGeometry() {
    // If the map marker is already on the screen, remove it.
    if (_marker != null) {
      hereMapController!.mapScene.removeMapMarker(_marker!);
      _marker = null;
    }

    // If there is a selected geometry, reset its style.
    if (_selectedVenue != null && _selectedGeometry != null) {
      _selectedVenue!.setCustomStyle([_selectedGeometry!], null, null);
    }

    // Reset the geometry in the GeometryInfoState.
    geometryInfoState!.geometry = null;
  }

  _addPOIMapMarker(GeoCoordinates geoCoordinates) {
    if (_markerImage == null) {
      return;
    }

    // By default, the anchor point is set to 0.5, 0.5 (= centered).
    // Here the bottom, middle position should point to the location.
    Anchor2D anchor2D = Anchor2D.withHorizontalAndVertical(0.5, 1);
    _marker = MapMarker.withAnchor(geoCoordinates, _markerImage!, anchor2D);
    hereMapController!.mapScene.addMapMarker(_marker!);
  }
}
