/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart' as HERE;

import 'NavigationExample.dart';

// An app that allows to calculate a car route in Berlin and start navigation using simulated locations.
class AppLogic {
  HERE.Route _route;
  GeoCoordinates _startGeoCoordinates = GeoCoordinates(52.512271, 13.410537);
  GeoCoordinates _destinationGeoCoordinates = GeoCoordinates(52.530898, 13.385010);
  HereMapController _hereMapController;
  NavigationExample _navigationExample;

  AppLogic(HereMapController hereMapController) {
    _hereMapController = hereMapController;

    double distanceToEarthInMeters = 10000;
    _hereMapController.camera.lookAtPointWithDistance(
      GeoCoordinates(52.520798, 13.409408),
      distanceToEarthInMeters,
    );

    _calculateRoute();

    _navigationExample = NavigationExample(_hereMapController);
  }

  void startNavigation() {
    if (_route == null) {
      print('Error: No route to navigate on.');
      return;
    }

    _navigationExample.startNavigation(_route);
  }

  void stopNavigation() {
    _navigationExample.stopNavigation();
  }

  Future<void> _calculateRoute() async {
    var startWaypoint = HERE.Waypoint.withDefaults(_startGeoCoordinates);
    var destinationWaypoint = HERE.Waypoint.withDefaults(_destinationGeoCoordinates);
    List<HERE.Waypoint> waypoints = [startWaypoint, destinationWaypoint];

    HERE.RoutingEngine routingEngine;

    try {
      routingEngine = HERE.RoutingEngine();
    } on InstantiationException {
      throw Exception('Initialization of RoutingEngine failed.');
    }

    await routingEngine.calculateCarRoute(waypoints, HERE.CarOptions.withDefaults(),
        (HERE.RoutingError routingError, List<HERE.Route> routeList) async {
      if (routingError == null) {
        _route = routeList.first;
        _showRouteOnMap(_route);
      } else {
        final error = routingError.toString();
        print('Error while calculating a route: $error');
      }
    });
  }

  _showRouteOnMap(HERE.Route route) {
    // Show route as polyline.
    GeoPolyline routeGeoPolyline = GeoPolyline(route.polyline);

    double widthInPixels = 20;
    MapPolyline routeMapPolyline = MapPolyline(
      routeGeoPolyline,
      widthInPixels,
      Color.fromARGB(160, 0, 144, 138),
    );

    _hereMapController.mapScene.addMapPolyline(routeMapPolyline);
  }
}
