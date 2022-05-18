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

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart' as routes;

// A class that creates car Routes with the HERE SDK.
class RouteCalculator {
  final HereMapController _hereMapController;
  late final routes.RoutingEngine _routingEngine;
  static routes.Route? testRoute;

  RouteCalculator(HereMapController hereMapController) : _hereMapController = hereMapController {
    try {
      _routingEngine = routes.RoutingEngine();
    } on InstantiationException {
      throw Exception('Initialization of RoutingEngine failed.');
    }
  }

  void createRoute() {
    routes.Waypoint startWaypoint = routes.Waypoint(GeoCoordinates(40.7133, -74.0112));
    routes.Waypoint destinationWaypoint = routes.Waypoint(GeoCoordinates(40.7203, -74.3122));
    List<routes.Waypoint> waypoints = [startWaypoint, destinationWaypoint];

    _routingEngine.calculateCarRoute(waypoints, routes.CarOptions.withDefaults(), (_routingError, _routes) {
      if (_routingError == null) {
        testRoute = _routes?.elementAt(0);
        _showRouteOnMap(testRoute!);
      } else {
        print("Error while calculating a route:" + _routingError.toString());
      }
    });
  }

  void _showRouteOnMap(routes.Route route) {
    // Show route as polyline.
    GeoPolyline routeGeoPolyline = route.geometry;
    double widthInPixels = 20;
    MapPolyline routeMapPolyline =
    MapPolyline(routeGeoPolyline, widthInPixels, const Color.fromARGB(160, 0, 144, 138)); // RGBA
    _hereMapController.mapScene.addMapPolyline(routeMapPolyline);
  }
}
