/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

import 'dart:ui';

import 'package:here_sdk/animation.dart' as here;
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart' as HERE;
import 'package:here_sdk/routing.dart';

import 'CameraBehaviors.dart';

// Handles route calculation, guidance, and camera behavior switching for visual lane guidance.
// Note: Visual lane guidance is a beta feature and requires a Visual Lane Guidance license.
// Talk to your HERE representative for more information.
enum RouteSelection {
  none,
  chicago,
  berlin,
}

class VisualLaneGuidanceExample {
  final HereMapController mapController;
  final void Function(String title, String message) showDialog;

  late final HERE.RoutingEngine _routingEngine;
  late final VisualNavigator _visualNavigator;
  late final CameraBehaviors cameraBehaviors;

  LocationSimulator? _locationSimulator;
  HERE.Route? _route;
  RouteSelection _selectedRoute = RouteSelection.none;
  MapPolyline? _routeMapPolyline;
  final List<MapMarker> _mapMarkers = [];

  static final List<GeoCoordinates> _chicagoRoute = [
    GeoCoordinates(41.8756, -87.6622),
    GeoCoordinates(41.8924, -87.6485),
  ];

  static final List<GeoCoordinates> _berlinRoute = [
    GeoCoordinates(52.5012, 13.2753),
    GeoCoordinates(52.3839, 13.1509),
  ];

  VisualLaneGuidanceExample(this.mapController, this.showDialog) {
    try {
      _routingEngine = HERE.RoutingEngine();
      _visualNavigator = VisualNavigator();
    } on InstantiationException {
      rethrow;
    }

    cameraBehaviors = CameraBehaviors(_visualNavigator);
  }

  Future<void> initialize() async {
    await cameraBehaviors.initialize();
  }

  bool isGuidanceRunning() => _locationSimulator != null;

  RouteSelection get selectedRoute => _selectedRoute;

  String get cameraStatus => cameraBehaviors.getCameraBehaviorStatus();

  void useTransitionCameraBehavior() => cameraBehaviors.useTransitionCameraBehavior();

  void useAutomotiveCameraBehavior() => cameraBehaviors.useAutomotiveCameraBehavior();

  // Calculates the Chicago route.
  void calculateChicagoRoute() {
    _calculateRoute(_chicagoRoute, RouteSelection.chicago);
  }

  // Calculates the Berlin route.
  void calculateBerlinRoute() {
    _calculateRoute(_berlinRoute, RouteSelection.berlin);
  }

  void _calculateRoute(List<GeoCoordinates> coordinates, RouteSelection routeSelection) {
    if (isGuidanceRunning()) {
      showDialog('Guidance is active', 'Stop guidance before calculating a new route.');
      return;
    }

    _selectedRoute = routeSelection;

    _clearMap();
    _addStartAndDestinationMarkers(coordinates);

    final waypoints = coordinates.map((c) => Waypoint(c)).toList();
    _routingEngine.calculateRouteWithRoutingOptions(waypoints, RoutingOptions(), (routingError, routes) {
      if (routingError == null && routes != null && routes.isNotEmpty) {
        _route = routes.first;
        _showRoute(_route!);
        _animateToRoute(_route!);
      } else {
        showDialog('Route calculation error', '$routingError');
      }
    });
  }

  // Starts guidance for the current route.
  void startGuidance() {
    if (isGuidanceRunning()) {
      return;
    }

    if (_route == null) {
      showDialog('Error', 'Calculate a route first.');
      return;
    }

    _stopGuidanceInternal(clearMapContents: false, restoreRouteView: false);
    _useCurrentCameraBehavior();
    _removeRoutePolyline();

    // This enables a navigation view including a rendered navigation arrow.
    _visualNavigator.startRendering(mapController);

    // Hook in one of the many listeners to log maneuver instructions.
    _visualNavigator.eventTextListener = EventTextListener((EventText eventText) {
      print('Maneuver text: ${eventText.text}');
    });

    // Set a route to follow. This leaves tracking mode.
    _visualNavigator.route = _route;

    // HD lanes are rendered only while guidance is actively running.
    // Outside guidance, the map remains in the standard navigation view.

    // Any progress along the route is a result of getting a new location fed into the VisualNavigator.
    _setupLocationSource(_route!);
  }

  // Stops guidance and clears the map.
  void stopGuidance() {
    _stopGuidanceInternal(clearMapContents: true);
  }

  void _stopGuidanceInternal({required bool clearMapContents, bool restoreRouteView = true}) {
    final wasGuidanceRunning = _locationSimulator != null;
    _visualNavigator.route = null;
    _visualNavigator.stopRendering();

    _locationSimulator?.stop();
    _locationSimulator = null;

    final route = _route;
    if (route == null) {
      return;
    }

    if (!restoreRouteView) {
      return;
    }

    if (wasGuidanceRunning) {
      _removeRoutePolyline();
      _showRoute(route);
      _animateToRoute(route);
      return;
    }

    if (clearMapContents) {
      _animateToRoute(route);
      _clearMap();
    }
  }

  void dispose() {
    _stopGuidanceInternal(clearMapContents: false, restoreRouteView: false);
  }

  // Sets up the location simulator for the given route.
  void _setupLocationSource(HERE.Route route) {
    try {
      final options = LocationSimulatorOptions();
      // Simulate with speedFactor x speed-on-current-segment.
      options.speedFactor = 2;
      // Provides fake GPS signals based on the route geometry.
      _locationSimulator = LocationSimulator.withRoute(route, options);
    } on InstantiationException {
      rethrow;
    }

    // Feed location updates into VisualNavigator to progress guidance on the route.
    _locationSimulator!.listener = _visualNavigator;
    _locationSimulator!.start();
  }

  void _addStartAndDestinationMarkers(List<GeoCoordinates> coordinates) {
    final start = coordinates.first;
    final destination = coordinates.last;
    _addMapMarker(start, 'assets/poi_start.png');
    _addMapMarker(destination, 'assets/poi_destination.png');
  }

  // Adds a map marker at the given coordinates with the specified asset.
  void _addMapMarker(GeoCoordinates coordinates, String asset) {
    final image = MapImage.withFilePathAndWidthAndHeight(asset, 60, 60);
    final marker = MapMarker(coordinates, image);
    mapController.mapScene.addMapMarker(marker);
    _mapMarkers.add(marker);
  }

  // Displays the given route as a polyline on the map.
  void _showRoute(HERE.Route route) {
    final polyline = route.geometry;
    try {
      _routeMapPolyline = MapPolyline.withRepresentation(
        polyline,
        MapPolylineSolidRepresentation(
          MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.pixels, 20),
          const Color.fromARGB(160, 0, 144, 138),
          LineCap.round,
        ),
      );
      mapController.mapScene.addMapPolyline(_routeMapPolyline!);
    } on Exception {
      _routeMapPolyline = null;
    }
  }

  // Animates the camera to fit the given route.
  void _animateToRoute(HERE.Route route) {
    // We want to show the route fitting in the map view with an additional padding of 300 pixels.
    Point2D origin = Point2D(300, 300);
    Size2D sizeInPixels = Size2D(
      mapController.viewportSize.width - 600,
      mapController.viewportSize.height - 600,
    );
    Rectangle2D mapViewport = Rectangle2D(origin, sizeInPixels);

    // Animate to the route within a duration of 3 seconds.
    MapCameraUpdate update = MapCameraUpdateFactory.lookAtAreaWithGeoOrientationAndViewRectangle(
      route.boundingBox,
      GeoOrientationUpdate(0, 0),
      mapViewport,
    );
    MapCameraAnimation animation = MapCameraAnimationFactory.createAnimationFromUpdateWithEasing(
      update,
      const Duration(milliseconds: 3000),
      here.Easing(here.EasingFunction.inCubic),
    );
    mapController.camera.startAnimation(animation);
  }

  // Removes all map markers and polylines from the map.
  void _clearMap() {
    // Clear all map markers from the map.
    for (final marker in _mapMarkers) {
      mapController.mapScene.removeMapMarker(marker);
    }
    _mapMarkers.clear();

    // Clear the route polyline from the map.
    _removeRoutePolyline();
  }

  void _removeRoutePolyline() {
    if (_routeMapPolyline != null) {
      mapController.mapScene.removeMapPolyline(_routeMapPolyline!);
      _routeMapPolyline = null;
    }
  }

  void _useCurrentCameraBehavior() {
    _visualNavigator.cameraBehavior = cameraBehaviors.activeCameraBehavior;
  }
}
