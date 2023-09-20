/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart' as HERE;
import 'package:navigation_app/RouteCalculator.dart';

import 'NavigationExample.dart';

// An app that allows to calculate a car route and start navigation using simulated or real locations.
class AppLogic {
  MapPolyline? _calculatedRouteMapPolyline;
  final HereMapController _hereMapController;
  final NavigationExample _navigationExample;
  final RouteCalculator _routeCalculator;
  final ValueChanged<String> _updateMessageState;
  final Function _showDialogCallback;
  final List<MapMarker> _mapMarkerList = [];
  final List<MapPolyline> _mapPolylines = [];

  HERE.Waypoint? _startWaypoint;
  HERE.Waypoint? _destinationWaypoint;
  bool _setLongPressDestination = false;

  AppLogic(HereMapController hereMapController, ValueChanged<String> updateMessageState, Function showDialogCallback)
      : _hereMapController = hereMapController,
        _updateMessageState = updateMessageState,
        _showDialogCallback = showDialogCallback,
        _navigationExample = NavigationExample(hereMapController, updateMessageState),
        _routeCalculator = RouteCalculator() {
    _setLongPressGestureHandler();
    _updateMessageState("Long press to set start/destination or use random ones.");
  }

  _setLongPressGestureHandler() {
    _hereMapController.gestures.longPressListener = LongPressListener((gestureState, touchPoint) {
      GeoCoordinates? geoCoordinates = _hereMapController.viewToGeoCoordinates(touchPoint);
      if (geoCoordinates == null) {
        return;
      }

      if (gestureState == GestureState.begin) {
        if (_setLongPressDestination) {
          _destinationWaypoint = HERE.Waypoint(geoCoordinates);
          _addCircleMapMarker(_destinationWaypoint!.coordinates, "assets/green_dot.png");
          _updateMessageState("New long press destination set.");
        } else {
          _startWaypoint = HERE.Waypoint(geoCoordinates);
          _addCircleMapMarker(_startWaypoint!.coordinates, "assets/green_dot.png");
          _updateMessageState("New long press starting point set.");
        }
        _setLongPressDestination = !_setLongPressDestination;
      }
    });
  }

  // Calculate a route and start navigation using a location simulator.
  // Start is map center and destination location is set random within viewport,
  // unless a destination is set via long press.
  // Shows navigation simulation along a route.
  void startNavigationSimulation() {
    // Once route is calculated navigation is started.
    bool isSimulated = true;
    _calculateRoute(isSimulated);
  }

  // Calculate a route and start navigation using locations from device.
  // Start is current location and destination is set random within viewport,
  // unless a destination is set via long press.
  // Shows navigation with real location data.
  void startNavigation() {
    // Once route is calculated navigation is started.
    bool isSimulated = false;
    _calculateRoute(isSimulated);
  }

  void setTracking(bool isTracking) {
    _navigationExample.followCurrentCarPosition(isTracking);
  }

  void stopNavigation() {
    _navigationExample.stopNavigation();
    _clearMap();
  }

  void detach() {
    _navigationExample.detach();
  }

  Future<void> _calculateRoute(bool isSimulated) async {
    _clearMap();
    var currentLocation = _navigationExample.getLastKnownLocation();
    if (currentLocation == null) {
      _updateMessageState("Error: No current location found.");
      return;
    }

    if (!_determineRouteWaypoints(isSimulated)) {
      return;
    }

    _routeCalculator.calculateCarRoute(_startWaypoint!, _destinationWaypoint!,
        (HERE.RoutingError? routingError, List<HERE.Route>? routeList) async {
      if (routingError == null) {
        // When error is null, it is guaranteed that the routeList is not empty.
        HERE.Route _calculatedRoute = routeList!.first;
        _showRouteOnMap(_calculatedRoute);
        _showRouteDetails(_calculatedRoute, isSimulated);
      } else {
        final error = routingError.toString();
        _updateMessageState("Error while calculating a route: $error");
      }
    });
  }

  void _showRouteDetails(HERE.Route route, bool isSimulated) {
    var estimatedTravelTimeInSeconds = route.duration.inSeconds;
    int lengthInMeters = route.lengthInMeters;

    String routeDetails =
        "Travel Time: " + _formatTime(estimatedTravelTimeInSeconds) + ", Length: " + _formatLength(lengthInMeters);

    _showDialogCallback("Route Details", routeDetails);
    _startNavigationOnRoute(isSimulated, route);
  }

  String _formatTime(num sec) {
    int hours = (sec ~/ 3600);
    int minutes = ((sec % 3600) ~/ 60);
    String formattedTime = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';

    return formattedTime;
  }

  String _formatLength(int meters) {
    int kilometers = (meters ~/ 1000);
    int remainingMeters = (meters % 1000);
    String formattedDistance =
        '${kilometers.toString().padLeft(2, '0')}.${remainingMeters.toString().padLeft(2, '0')} km';

    return formattedDistance;
  }

  void _startNavigationOnRoute(bool isSimulated, HERE.Route route) {
    if (isSimulated) {
      // Starts simulated navigation from current location to a random destination.
      _updateMessageState("Starting simulated navigation.");
      _navigationExample.startNavigationSimulation(route);
    } else {
      // Starts real navigation from current location to a random destination.
      _updateMessageState("Starting navigation.");
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

  bool _determineRouteWaypoints(bool isSimulated) {
    // When using real GPS locations, we always start from the current location of user.
    if (!isSimulated) {
      Location? location = _navigationExample.getLastKnownLocation();
      if (location == null) {
        _showDialogCallback("Error", "No GPS location found.");
        return false;
      }

      _startWaypoint = HERE.Waypoint(location!.coordinates);
      // If a driver is moving, the bearing value can help to improve the route calculation.
      _startWaypoint!.headingInDegrees = location!.bearingInDegrees;
      _hereMapController.camera.lookAtPoint(location!.coordinates);
    } 

    if (_startWaypoint == null) {
      _startWaypoint = HERE.Waypoint(_createRandomGeoCoordinatesAroundMapCenter());
    }

    if (_destinationWaypoint == null) {
      _destinationWaypoint = HERE.Waypoint(_createRandomGeoCoordinatesAroundMapCenter());
    }

    return true;
  }

  void _clearMap() {
    _clearWaypointMapMarker();
    _clearRoute();

    _navigationExample.stopNavigation();
  }

  void _clearWaypointMapMarker() {
    for (MapMarker mapMarker in _mapMarkerList) {
      _hereMapController.mapScene.removeMapMarker(mapMarker);
    }
    _mapMarkerList.clear();
  }

  void _clearRoute() {
    for (MapPolyline mapPolyline in _mapPolylines) {
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
    }
    _mapPolylines.clear();

    if (_calculatedRouteMapPolyline != null) {
      _hereMapController.mapScene.removeMapPolyline(_calculatedRouteMapPolyline!);
    }
  }

  void _addCircleMapMarker(GeoCoordinates geoCoordinates, String imageName) {
    // For this app, we only add images of size 60x60 pixels.
    int imageWidth = 60;
    int imageHeight = 60;
    // Note that you can reuse the same mapImage instance for other MapMarker instances
    // to save resources.
    MapImage mapImage = MapImage.withFilePathAndWidthAndHeight(imageName, imageWidth, imageHeight);
    MapMarker mapMarker = MapMarker(geoCoordinates, mapImage);
    _hereMapController.mapScene.addMapMarker(mapMarker);
    _mapMarkerList.add(mapMarker);
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
