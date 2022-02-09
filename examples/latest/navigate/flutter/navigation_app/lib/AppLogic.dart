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

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart' as HERE;
import 'package:navigation_app/RouteCalculator.dart';

import 'NavigationExample.dart';

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

// An app that allows to calculate a car route and start navigation using simulated or real locations.
class AppLogic {
  MapPolyline? _calculatedRouteMapPolyline;
  HereMapController _hereMapController;
  NavigationExample _navigationExample;
  ShowDialogFunction _showDialog;
  RouteCalculator _routeCalculator;

  AppLogic(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
      : _showDialog = showDialogCallback,
        _hereMapController = hereMapController,
        _navigationExample = NavigationExample(hereMapController),
        _routeCalculator = RouteCalculator();

  // Shows navigation simulation along a route.
  void startNavigationSimulation() {
    // Once route is calculated navigation is started.
    bool isSimulated = true;
    _calculateRouteFromCurrentLocation(isSimulated);
  }

  // Shows navigation with real location data.
  void startNavigation() {
    // Once route is calculated navigation is started.
    bool isSimulated = false;
    _calculateRouteFromCurrentLocation(isSimulated);
  }

  void setTracking(bool isTracking) {
    _navigationExample.setTracking(isTracking);
  }

  void stopNavigation() {
    _navigationExample.stopNavigation();
  }

  void detach() {
    _navigationExample.detach();
  }

  Future<void> _calculateRouteFromCurrentLocation(bool isSimulated) async {
    var currentLocation = _navigationExample.getLastKnownLocation();
    if (currentLocation == null) {
      _showDialog('Error', 'No current location found.');
      return;
    }

    double distanceToEarthInMeters = 10000;
    _hereMapController.camera.lookAtPointWithDistance(
      currentLocation.coordinates,
      distanceToEarthInMeters,
    );

    var startWaypoint = HERE.Waypoint.withDefaults(currentLocation.coordinates);

    // If a driver is moving, the bearing value can help to improve the route calculation.
    startWaypoint.headingInDegrees = currentLocation.bearingInDegrees;

    var destinationWaypoint = HERE.Waypoint.withDefaults(_createRandomGeoCoordinatesAroundMapCenter());

    _routeCalculator.calculateCarRoute(startWaypoint, destinationWaypoint,
        (HERE.RoutingError? routingError, List<HERE.Route>? routeList) async {
      if (routingError == null) {
        // When error is null, it is guaranteed that the routeList is not empty.
        HERE.Route _calculatedRoute = routeList!.first;
        _showRouteOnMap(_calculatedRoute);
        _startNavigationOnRoute(isSimulated, _calculatedRoute);
      } else {
        final error = routingError.toString();
        _showDialog('Error', 'Error while calculating a route: $error');
      }
    });
  }

  void _startNavigationOnRoute(bool isSimulated, HERE.Route route) {
    if (isSimulated) {
      // Starts simulated navigation from current location to a random destination.
      _navigationExample.startNavigationSimulation(route);
    } else {
      // Starts real navigation from current location to a random destination.
      _navigationExample.startNavigation(route);
    }
  }

  void _showRouteOnMap(HERE.Route route) {
    // Remove previous route, if any.
    if (_calculatedRouteMapPolyline != null) {
      _hereMapController.mapScene.removeMapPolyline(_calculatedRouteMapPolyline!);
    }

    // Show route as polyline.
    GeoPolyline routeGeoPolyline = route.geometry;
    double widthInPixels = 20;
    MapPolyline routeMapPolyline = MapPolyline(
      routeGeoPolyline,
      widthInPixels,
      Color.fromARGB(160, 0, 144, 138),
    );

    _calculatedRouteMapPolyline = routeMapPolyline;
    _hereMapController.mapScene.addMapPolyline(_calculatedRouteMapPolyline!);
  }

  GeoCoordinates _createRandomGeoCoordinatesAroundMapCenter() {
    GeoCoordinates centerGeoCoordinates = _hereMapController.camera.state.targetCoordinates;
    double lat = centerGeoCoordinates.latitude;
    double lon = centerGeoCoordinates.longitude;
    return GeoCoordinates(_getRandom(lat - 0.02, lat + 0.02), _getRandom(lon - 0.02, lon + 0.02));
  }

  double _getRandom(double min, double max) {
    return min + Random().nextDouble() * (max - min);
  }
}
