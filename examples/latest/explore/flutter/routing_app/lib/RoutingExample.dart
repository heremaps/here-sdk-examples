/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/routing.dart' as here;

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

class RoutingExample {
  final HereMapController _hereMapController;
  List<MapPolyline> _mapPolylines = [];
  late RoutingEngine _routingEngine;
  final ShowDialogFunction _showDialog;

  RoutingExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
      : _showDialog = showDialogCallback,
        _hereMapController = hereMapController {
    double distanceToEarthInMeters = 10000;
    _hereMapController.camera.lookAtPointWithDistance(GeoCoordinates(52.520798, 13.409408), distanceToEarthInMeters);

    try {
      _routingEngine = RoutingEngine();
    } on InstantiationException {
      throw ("Initialization of RoutingEngine failed.");
    }
  }

  Future<void> addRoute() async {
    var startGeoCoordinates = _createRandomGeoCoordinatesInViewport();
    var destinationGeoCoordinates = _createRandomGeoCoordinatesInViewport();
    var startWaypoint = Waypoint.withDefaults(startGeoCoordinates);
    var destinationWaypoint = Waypoint.withDefaults(destinationGeoCoordinates);

    List<Waypoint> waypoints = [startWaypoint, destinationWaypoint];

    _routingEngine.calculateCarRoute(waypoints, CarOptions.withDefaults(),
        (RoutingError? routingError, List<here.Route>? routeList) async {
      if (routingError == null) {
        // When error is null, then the list guaranteed to be not null.
        here.Route route = routeList!.first;
        _showRouteDetails(route);
        _showRouteOnMap(route);
        _logRouteSectionDetails(route);
        _logRouteViolations(route);
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

  void clearMap() {
    for (var mapPolyline in _mapPolylines) {
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
    }
    _mapPolylines.clear();
  }

  void _logRouteSectionDetails(here.Route route) {
    DateFormat dateFormat = DateFormat().add_Hm();

    for (int i = 0; i < route.sections.length; i++) {
      Section section = route.sections.elementAt(i);

      print("Route Section : " + (i+1).toString());
      print("Route Section Departure Time : " + dateFormat.format(section.departureTime!));
      print("Route Section Arrival Time : " + dateFormat.format(section.arrivalTime!));
      print("Route Section length : " + section.lengthInMeters.toString() + " m");
      print("Route Section duration : " + section.duration.inSeconds.toString() + " s");
    }
  }

  void _showRouteDetails(here.Route route) {
    int estimatedTravelTimeInSeconds = route.duration.inSeconds;
    int lengthInMeters = route.lengthInMeters;

    String routeDetails = 'Travel Time: ' + _formatTime(estimatedTravelTimeInSeconds)
                        + ', Length: ' + _formatLength(lengthInMeters);

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
