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

import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/routing.dart' as HERE;
import 'package:here_sdk/routing.dart';

// A class that creates car Routes with the HERE SDK.
class RouteCalculator {
  late final HERE.RoutingEngine _routingEngine;

  RouteCalculator() {
    try {
      _routingEngine = new HERE.RoutingEngine();
    } on InstantiationException {
      throw Exception('Initialization of RoutingEngine failed.');
    }
  }

  void calculateCarRoute(
      Waypoint startWaypoint, Waypoint destinationWaypoint, CalculateRouteCallback calculateRouteCallback) {
    List<Waypoint> waypoints = [startWaypoint, destinationWaypoint];

    // A route handle is required for the DynamicRoutingEngine to get updates on traffic-optimized routes.
    var routingOptions = HERE.CarOptions.withDefaults();
    routingOptions.routeOptions.enableRouteHandle = true;

    _routingEngine.calculateCarRoute(waypoints, routingOptions, calculateRouteCallback);
  }
}
