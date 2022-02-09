/*
 * Copyright (C) 2021-2022 HERE Europe B.V.
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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/routing.dart' as here;

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

class PublicTransportRoutingExample {
  final HereMapController _hereMapController;
  List<MapPolyline> _mapPolylines = [];
  late TransitRoutingEngine _transitRoutingEngine;
  final ShowDialogFunction _showDialog;

  PublicTransportRoutingExample(this._showDialog, this._hereMapController) {
    double distanceToEarthInMeters = 10000;
    _hereMapController.camera.lookAtPointWithDistance(GeoCoordinates(52.520798, 13.409408), distanceToEarthInMeters);

    _transitRoutingEngine = TransitRoutingEngine();
  }

  Future<void> addTransitRoute() async {
    var startGeoCoordinates = _createRandomGeoCoordinatesInViewport();
    var destinationGeoCoordinates = _createRandomGeoCoordinatesInViewport();

    var startWaypoint = TransitWaypoint.withDefaults(startGeoCoordinates);
    var destinationWaypoint = TransitWaypoint.withDefaults(destinationGeoCoordinates);

    var options = TransitRouteOptions.withDefaults();

    _transitRoutingEngine.calculateRoute(startWaypoint, destinationWaypoint, options,
        (RoutingError? routingError, List<here.Route>? routeList) async {
      if (routingError == null) {
        // Whenn error is null, the list is guaranteed to be non empty.
        here.Route route = routeList!.first;
        _showRouteDetails(route);
        _showRouteOnMap(route);
        _logRouteViolations(route);

        // Log maneuver instructions per route section.
        List<Section> sections = route.sections;
        for (Section section in sections) {
          _logManeuverInstructions(section);
        }
      } else {
        var error = routingError.toString();
        _showDialog('Error', 'Error while calculating a route: $error');
      }
    });
  }

  // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
  // An implementation may decide to reject a route if one or more violations are detected.
  void _logRouteViolations(here.Route route) {
    for (var section in route.sections) {
      for (var notice in section.sectionNotices) {
        print("This route contains the following warning: " + notice.code.toString());
      }
    }
  }

  void _logManeuverInstructions(Section section) {
    print("Log maneuver instructions per route section:");
    List<Maneuver> maneuverInstructions = section.maneuvers;
    for (Maneuver maneuverInstruction in maneuverInstructions) {
      ManeuverAction maneuverAction = maneuverInstruction.action;
      GeoCoordinates maneuverLocation = maneuverInstruction.coordinates;
      String maneuverInfo = maneuverInstruction.text +
          ", Action: " +
          maneuverAction.toString() +
          ", Location: " +
          maneuverLocation.toString();
      print(maneuverInfo);
    }
  }

  void clearMap() {
    for (var mapPolyline in _mapPolylines) {
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
    }
    _mapPolylines.clear();
  }

  void _showRouteDetails(here.Route route) {
    int estimatedTravelTimeInSeconds = route.durationInSeconds;
    int lengthInMeters = route.lengthInMeters;

    String routeDetails =
        'Travel Time: ' + _formatTime(estimatedTravelTimeInSeconds) + ', Length: ' + _formatLength(lengthInMeters);

    _showDialog('Route Details', '$routeDetails');
  }

  String _formatTime(int sec) {
    int hours = sec ~/ 3600;
    int minutes = (sec % 3600) ~/ 60;

    return '$hours:$minutes min';
  }

  String _formatLength(int meters) {
    int kilometers = meters ~/ 1000;
    int remainingMeters = meters % 1000;

    return '$kilometers.$remainingMeters km';
  }

  _showRouteOnMap(here.Route route) {
    // Show route as polyline.
    GeoPolyline routeGeoPolyline = route.geometry;
    double widthInPixels = 20;
    MapPolyline routeMapPolyline = MapPolyline(routeGeoPolyline, widthInPixels, Color.fromARGB(160, 0, 144, 138));
    _hereMapController.mapScene.addMapPolyline(routeMapPolyline);
    _mapPolylines.add(routeMapPolyline);
  }

  GeoCoordinates _createRandomGeoCoordinatesInViewport() {
    GeoBox? geoBox = _hereMapController.camera.boundingBox;
    if (geoBox == null) {
      // Happens only when map is not fully covering the viewport.
      return GeoCoordinates(52.530932, 13.384915);
    }

    GeoCoordinates northEast = geoBox.northEastCorner;
    GeoCoordinates southWest = geoBox.southWestCorner;

    double minLat = southWest.latitude;
    double maxLat = northEast.latitude;
    double lat = _getRandom(minLat, maxLat);

    double minLon = southWest.longitude;
    double maxLon = northEast.longitude;
    double lon = _getRandom(minLon, maxLon);

    return GeoCoordinates(lat, lon);
  }

  double _getRandom(double min, double max) {
    return min + Random().nextDouble() * (max - min);
  }
}
