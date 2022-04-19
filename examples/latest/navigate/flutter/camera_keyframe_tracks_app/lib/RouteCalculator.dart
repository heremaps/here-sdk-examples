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

import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/routing.dart' as routes;

// A class that creates car Routes with the HERE SDK.
class RouteCalculator {
  late final routes.RoutingEngine _routingEngine;

  RouteCalculator() {
    try {
      _routingEngine = routes.RoutingEngine();
    } on InstantiationException {
      throw Exception('Initialization of RoutingEngine failed.');
    }
  }

  void calculateCarRoute(routes.CalculateRouteCallback calculateRouteCallback) {
    routes.Waypoint startWaypoint = routes.Waypoint(GeoCoordinates(40.71335297425111, -74.01128262379694));
    routes.Waypoint destinationWaypoint = routes.Waypoint(GeoCoordinates(40.72039108039512, -74.01226967669756));
    List<routes.Waypoint> waypoints = [startWaypoint, destinationWaypoint];

    _routingEngine.calculateCarRoute(waypoints, routes.CarOptions.withDefaults(), calculateRouteCallback);
  }
}
