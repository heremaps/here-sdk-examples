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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/location.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/prefetcher.dart';
import 'package:here_sdk/routing.dart' as HERE;
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/trafficawarenavigation.dart';

import 'HEREPositioningProvider.dart';
import 'HEREPositioningSimulator.dart';

// Shows how to start and stop turn-by-turn navigation along a route.
class NavigationExample {
  final HereMapController _hereMapController;
  late VisualNavigator _visualNavigator;
  HEREPositioningSimulator _locationSimulationProvider;
  HEREPositioningProvider _herePositioningProvider;
  late DynamicRoutingEngine _dynamicRoutingEngine;
  final ValueChanged<String> _updateMessageState;
  RoutePrefetcher _routePrefetcher;

  NavigationExample(HereMapController hereMapController, ValueChanged<String> updateMessageState)
      : _hereMapController = hereMapController,
        _updateMessageState = updateMessageState,
        // For easy testing, this location provider simulates location events along a route.
        // You can use HERE positioning to feed real locations, see the "Positioning"-section in
        // our Developer's Guide for an example
        _locationSimulationProvider = HEREPositioningSimulator(),
        // Access the device's GPS sensor and other data.
        _herePositioningProvider = HEREPositioningProvider(),
        // The RoutePrefetcher downloads map data in advance into the map cache.
        // This is not mandatory, but can help to improve the guidance experience.
        _routePrefetcher = RoutePrefetcher(SDKNativeEngine.sharedInstance!) {
    try {
      _visualNavigator = VisualNavigator();
    } on InstantiationException {
      throw Exception("Initialization of VisualNavigator failed.");
    }

    // Enable auto-zoom during guidance.
    _visualNavigator.cameraBehavior = DynamicCameraBehavior();

    // This enables a navigation view including a rendered navigation arrow.
    _visualNavigator.startRendering(_hereMapController);

    // Set navigator as delegate to receive locations from HERE Positioning.
    // Choose a suitable accuracy for the tbt navigation use case.
    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);

    // An engine to find better routes during guidance.
    _createDynamicRoutingEngine();
  }

  void prefetchMapData(GeoCoordinates currentGeoCoordinates) {
    // Prefetches map data around the provided location with a radius of 2 km into the map cache.
    // For the best experience, prefetchAroundLocation() should be called as early as possible.
    _routePrefetcher.prefetchAroundLocation(currentGeoCoordinates);
    // Prefetches map data within a corridor along the route that is currently set to the provided Navigator instance.
    // This happens continuously in discrete intervals.
    // If no route is set, no data will be prefetched.
    _routePrefetcher.prefetchAroundRouteOnIntervals(_visualNavigator);
  }

  // Use this engine to periodically search for better routes during guidance, ie. when the traffic
  // situation changes.
  void _createDynamicRoutingEngine() {
    var dynamicRoutingOptions = DynamicRoutingEngineOptions();
    // Both, minTimeDifference and minTimeDifferencePercentage, will be checked:
    // When the poll interval is reached, the smaller difference will win.
    dynamicRoutingOptions.minTimeDifference = Duration(seconds: 1);
    dynamicRoutingOptions.minTimeDifferencePercentage = 0.1;
    dynamicRoutingOptions.pollInterval = Duration(minutes: 5);

    try {
      // With the dynamic routing engine you can poll the HERE backend services to search for routes with less traffic.
      // This can happen during guidance - or you can periodically update a route that is shown in a route planner.
      //
      // Make sure to call dynamicRoutingEngine.updateCurrentLocation(...) to trigger execution. If this is not called,
      // no events will be delivered even if the next poll interval has been reached.
      _dynamicRoutingEngine = DynamicRoutingEngine(dynamicRoutingOptions);
    } on InstantiationException {
      throw Exception("Initialization of DynamicRoutingEngine failed.");
    }
  }

  Location? getLastKnownLocation() {
    return _herePositioningProvider.getLastKnownLocation();
  }

  void startNavigationSimulation(HERE.Route route) {
    // Set the route to follow.
    _visualNavigator.route = route;

    // Stop in case it was started before.
    _herePositioningProvider.stop();

    // Simulates location events based on the given route.
    // The navigator is set as listener to receive location updates.
    _locationSimulationProvider.startLocating(route, _visualNavigator);

    _startDynamicSearchForBetterRoutes(route);
  }

  void startNavigation(HERE.Route route) {
    GeoCoordinates startGeoCoordinates = route.geometry.vertices[0];
    prefetchMapData(startGeoCoordinates);

    // Set the route to follow.
    _visualNavigator.route = route;

    // Stop in case it was started before.
    _locationSimulationProvider.stop();

    // Access the device's GPS sensor and other data.
    // The navigator is set as listener to receive location updates.
    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);

    _startDynamicSearchForBetterRoutes(route);
  }

  void _startDynamicSearchForBetterRoutes(HERE.Route route) {
    try {
      // Note that the engine will be internally stopped, if it was started before.
      // Therefore, it is not necessary to stop the engine before starting it again.
      _dynamicRoutingEngine.start(
          route,
          // Notifies on traffic-optimized routes that are considered better than the current route.
          DynamicRoutingListener((Route newRoute, int etaDifferenceInSeconds, int distanceDifferenceInMeters) {
            _updateMessageState("DynamicRoutingEngine: Calculated a new route");
            print("DynamicRoutingEngine: etaDifferenceInSeconds: $etaDifferenceInSeconds.");
            print("DynamicRoutingEngine: distanceDifferenceInMeters: $distanceDifferenceInMeters.");

            // An implementation needs to decide when to switch to the new route based
            // on above criteria.
          }, (RoutingError routingError) {
            final error = routingError.toString();
            _updateMessageState("Error while dynamically searching for a better route: $error");
          }));
    } on DynamicRoutingEngineStartException {
      throw Exception("Start of DynamicRoutingEngine failed. Is the RouteHandle missing?");
    }
  }

  void followCurrentCarPosition(bool isFollowing) {
    if (isFollowing) {
      _visualNavigator.cameraBehavior = DynamicCameraBehavior();
    } else {
      _visualNavigator.cameraBehavior = null;
    }
  }

  void stopNavigation() {
    // Stop in case it was started before.
    _locationSimulationProvider.stop();
    _dynamicRoutingEngine.stop();
    _routePrefetcher.stopPrefetchAroundRoute();
    _startTracking();
    _updateMessageState("Tracking device's location.");
  }

  // Starts tracking the device's location using HERE Positioning.
  void _startTracking() {
    // Leaves guidance (if it was running) and enables tracking mode. The camera may optionally follow, see toggleTracking().
    _visualNavigator.route = null;
    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);
  }

  void detach() {
    // It is recommended to stop rendering before leaving the app.
    // This also removes the current location marker.
    _visualNavigator.stopRendering();

    // Stop LocationSimulator and DynamicRoutingEngine in case they were started before.
    _locationSimulationProvider.stop();
    _dynamicRoutingEngine.stop();

    // It is recommended to stop the LocationEngine before leaving the app.
    _herePositioningProvider.stop();
  }
}
