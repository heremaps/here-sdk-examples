/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/routing.dart' as here;
import 'package:here_sdk/traffic.dart';

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

// This example shows how to request and visualize realtime traffic flow information
// with the TrafficEngine along a route corridor.
// Note that the request time may differ from the refresh cycle for TRAFFIC_FLOWs.
// Note that this does not consider future traffic predictions that are available based on
// the traffic information of the route object based on the ETA and historical traffic patterns.
class RoutingExample {
  final HereMapController _hereMapController;
  final List<MapPolyline> _mapPolylines = [];
  late RoutingEngine _routingEngine;
  late TrafficEngine _trafficEngine;
  ShowDialogFunction _showDialog;

  RoutingExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
    : _showDialog = showDialogCallback,
      _hereMapController = hereMapController {
    try {
      _routingEngine = RoutingEngine();
    } on InstantiationException {
      throw ("Initialization of RoutingEngine failed.");
    }

    try {
      // The traffic engine can be used to request additional information about
      // the current traffic situation anywhere on the road network.
      _trafficEngine = TrafficEngine();
    } on InstantiationException {
      throw ("Initialization of TrafficEngine failed.");
    }
  }

  void addRoute() {
    Waypoint startWaypoint = Waypoint(_createRandomGeoCoordinatesAroundMapCenter());
    Waypoint destinationWaypoint = Waypoint(_createRandomGeoCoordinatesAroundMapCenter());

    var waypoints = [startWaypoint, destinationWaypoint];

    _routingEngine.calculateCarRoute(waypoints, CarOptions(), (routingError, routes) {
      if (routingError == null && routes != null && routes.isNotEmpty) {
        here.Route route = routes.first;
        _showRouteOnMap(route);
      } else {
        _showDialog("Error while calculating a route:", routingError.toString());
      }
    });
  }

  void _showRouteOnMap(here.Route route) {
    // Optionally, clear any previous route
    clearMap();

    // Show route as polyline
    GeoPolyline routeGeoPolyline = route.geometry;
    double widthInPixels = 20;
    Color polylineColor = const Color.fromARGB(160, 0, 144, 138);

    MapPolyline routeMapPolyline;
    try {
      routeMapPolyline = MapPolyline.withRepresentation(
        routeGeoPolyline,
        MapPolylineSolidRepresentation(
          MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.pixels, widthInPixels),
          polylineColor,
          LineCap.round,
        ),
      );
      _hereMapController.mapScene.addMapPolyline(routeMapPolyline);
      _mapPolylines.add(routeMapPolyline);
    } on MapPolylineRepresentationInstantiationException catch (e) {
      print("MapPolylineRepresentationInstantiationException:" + e.error.name);
      return;
    } on MapMeasureDependentRenderSizeInstantiationException catch (e) {
      print("MapMeasureDependentRenderSizeInstantiationException:" + e.error.name);
      return;
    }

    _hereMapController.mapScene.addMapPolyline(routeMapPolyline);
    _mapPolylines.add(routeMapPolyline);

    if (route.lengthInMeters / 1000 > 5000) {
      _showDialog("Note", "Skipped showing traffic-on-route for longer routes.");
      return;
    }

    _requestRealtimeTrafficOnRoute(route);
  }

  void clearMap() {
    for (MapPolyline mapPolyline in _mapPolylines) {
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
    }
    _mapPolylines.clear();
  }

  // This code uses the TrafficEngine to request the current state of the traffic situation
  // along the specified route corridor. Note that this information might dynamically change while
  // traveling along a route and it might not relate with the given ETA for the route.
  // Whereas the traffic-flow map feature shows pre-rendered vector tiles to achieve a smooth
  // map performance, the TrafficEngine requests the same information only for a specified area.
  // Depending on the time of the request and other backend factors like rendering the traffic
  // vector tiles, there can be cases, where both results differ.
  // Note that the HERE SDK allows to specify how often to request updates for the traffic-flow
  // map feature. It is recommended to not show traffic-flow and traffic-on-route together as it
  // might lead to redundant information. Instead, consider to show the traffic-flow map feature
  // side-by-side with the route's polyline (not shown in the method below). See Routing app for an
  // example.
  void _requestRealtimeTrafficOnRoute(here.Route route) {
    // We are interested to see traffic also for side paths.
    int halfWidthInMeters = 500;
    GeoCorridor geoCorridor = GeoCorridor(route.geometry.vertices, halfWidthInMeters);
    TrafficFlowQueryOptions trafficFlowQueryOptions = TrafficFlowQueryOptions();

    _trafficEngine.queryForFlowInCorridor(geoCorridor, trafficFlowQueryOptions, (trafficQueryError, trafficFlowList) {
      if (trafficQueryError == null && trafficFlowList != null) {
        for (TrafficFlow trafficFlow in trafficFlowList) {
          double? confidence = trafficFlow.confidence;
          if (confidence != null && confidence <= 0.5) {
            // Exclude speed-limit data and include only real-time and historical
            // flow information.
            continue;
          }

          // Visualize all polylines unfiltered as we get them from the TrafficEngine.
          GeoPolyline trafficGeoPolyline = trafficFlow.location.polyline;
          _addTrafficPolylines(trafficFlow.jamFactor, trafficGeoPolyline);
        }
      } else {
        _showDialog("Error while fetching traffic flow:", trafficQueryError.toString());
      }
    });
  }

  void _addTrafficPolylines(double jamFactor, GeoPolyline geoPolyline) {
    Color? lineColor = _getTrafficColor(jamFactor);

    // We skip rendering low traffic.
    if (lineColor == null) return;

    double widthInPixels = 10;

    MapPolyline trafficSpanMapPolyline;
    try {
      trafficSpanMapPolyline = MapPolyline.withRepresentation(
        geoPolyline,
        MapPolylineSolidRepresentation(
          MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.pixels, widthInPixels),
          lineColor,
          LineCap.round,
        ),
      );
      _hereMapController.mapScene.addMapPolyline(trafficSpanMapPolyline);
      _mapPolylines.add(trafficSpanMapPolyline);
    } on MapPolylineRepresentationInstantiationException catch (e) {
      print("MapPolylineRepresentationInstantiationException:" + e.error.name);
      return;
    } on MapMeasureDependentRenderSizeInstantiationException catch (e) {
      print("MapMeasureDependentRenderSizeInstantiationException:" + e.error.name);
      return;
    }

    _hereMapController.mapScene.addMapPolyline(trafficSpanMapPolyline);
    _mapPolylines.add(trafficSpanMapPolyline);
  }

  // Define a traffic color scheme based on the traffic jam factor.
  // 0 <= jamFactor < 4: No or light traffic.
  // 4 <= jamFactor < 8: Moderate or slow traffic.
  // 8 <= jamFactor < 10: Severe traffic.
  // jamFactor = 10: No traffic, ie. the road is blocked.
  // Returns null in case of no or light traffic.
  Color? _getTrafficColor(double? jamFactor) {
    if (jamFactor == null || jamFactor < 4) {
      return null;
    } else if (jamFactor >= 4 && jamFactor < 8) {
      return Color.fromARGB(160, 255, 255, 0); // Yellow
    } else if (jamFactor >= 8 && jamFactor < 10) {
      return Color.fromARGB(160, 255, 0, 0); // Red
    }
    return Color.fromARGB(160, 0, 0, 0); // Black
  }

  GeoCoordinates _createRandomGeoCoordinatesAroundMapCenter() {
    Point2D mapCenter = Point2D(_hereMapController.viewportSize.width / 2, _hereMapController.viewportSize.height / 2);
    GeoCoordinates? centerGeoCoordinates = _hereMapController.viewToGeoCoordinates(mapCenter);

    if (centerGeoCoordinates == null) {
      // Should never happen for center coordinates.
      throw Exception("CenterGeoCoordinates are null");
    }

    double lat = centerGeoCoordinates.latitude;
    double lon = centerGeoCoordinates.longitude;
    return GeoCoordinates(_getRandom(lat - 0.02, lat + 0.02), _getRandom(lon - 0.02, lon + 0.02));
  }

  double _getRandom(double min, double max) {
    return min + Random().nextDouble() * (max - min);
  }
}
