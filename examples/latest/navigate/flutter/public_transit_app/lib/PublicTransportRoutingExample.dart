/*
 * Copyright (C) 2021-2024 HERE Europe B.V.
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
import 'package:here_sdk/animation.dart' as here;
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/routing.dart' as here;

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

class PublicTransportRoutingExample {
  final HereMapController _hereMapController;
  List<MapPolyline> _mapPolylines = [];
  late TransitRoutingEngine _transitRoutingEngine;
  final ShowDialogFunction _showDialog;
  final _BERLIN_HQ_GEO_COORDINATES = GeoCoordinates(52.530971, 13.385088);

  PublicTransportRoutingExample(this._showDialog, this._hereMapController) {
    double distanceToEarthInMeters = 10000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

    _transitRoutingEngine = TransitRoutingEngine();
  }

  Future<void> addTransitRoute() async {
    var startGeoCoordinates = _BERLIN_HQ_GEO_COORDINATES;
    var destinationGeoCoordinates = _createRandomGeoCoordinatesInViewport();

    var startWaypoint = TransitWaypoint(startGeoCoordinates);
    var destinationWaypoint = TransitWaypoint(destinationGeoCoordinates);

    var options = TransitRouteOptions();

    _transitRoutingEngine.calculateRoute(startWaypoint, destinationWaypoint, options,
        (RoutingError? routingError, List<here.Route>? routeList) async {
      if (routingError == null) {
        // When error is null, the list is guaranteed to be non empty.
        here.Route route = routeList!.first;
        _showRouteDetails(route);
        _showRouteOnMap(route);
        _logRouteViolations(route);
        _animateToRoute(route);

        // Log maneuver instructions per route section.
        List<Section> sections = route.sections;
        for (Section section in sections) {
          _logManeuverInstructions(section);
        }
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

  void _logManeuverInstructions(Section section) {
    print("Log maneuver instructions per route section:");
    List<Maneuver> maneuverInstructions = section.maneuvers;
    for (Maneuver maneuverInstruction in maneuverInstructions) {
      ManeuverAction maneuverAction = maneuverInstruction.action;
      GeoCoordinates maneuverLocation = maneuverInstruction.coordinates;
      String maneuverInfo = maneuverInstruction.text +
          ", Action: " +
          maneuverAction.toString() +
          ", Location: " +
          maneuverLocation.toString();
      print(maneuverInfo);
    }
  }

  void clearMap() {
    for (var mapPolyline in _mapPolylines) {
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
    }
    _mapPolylines.clear();
  }

  void _showRouteDetails(here.Route route) {
    int estimatedTravelTimeInSeconds = route.duration.inSeconds;
    int lengthInMeters = route.lengthInMeters;

    String routeDetails =
        'Travel Time: ' + _formatTime(estimatedTravelTimeInSeconds) + ', Length: ' + _formatLength(lengthInMeters);

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
    Color polylineColor = const Color.fromARGB(160, 0, 144, 138);
    MapPolyline routeMapPolyline;
    try {
      routeMapPolyline = MapPolyline.withRepresentation(
          routeGeoPolyline,
          MapPolylineSolidRepresentation(
              MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.pixels, widthInPixels),
              polylineColor,
              LineCap.round));
      _hereMapController.mapScene.addMapPolyline(routeMapPolyline);
      _mapPolylines.add(routeMapPolyline);
    } on MapPolylineRepresentationInstantiationException catch (e) {
      print("MapPolylineRepresentation Exception:" + e.error.name);
      return;
    } on MapMeasureDependentRenderSizeInstantiationException catch (e) {
      print("MapMeasureDependentRenderSize Exception:" + e.error.name);
      return;
    }
  }

  GeoCoordinates _createRandomGeoCoordinatesInViewport() {
    GeoBox? geoBox = _hereMapController.camera.boundingBox;
    if (geoBox == null) {
      // Happens only when map is not fully covering the viewport as the map is tilted.
      print("The map view is tilted, falling back to fixed destination coordinate.");
      return GeoCoordinates(52.520798, 13.409408);
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

  void _animateToRoute(here.Route route) {
    // The animation results in an untilted and unrotated map.
    double bearing = 0;
    double tilt = 0;
    // We want to show the route fitting in the map view with an additional padding of 50 pixels.
    Point2D origin = Point2D(50, 50);
    Size2D sizeInPixels =
        Size2D(_hereMapController.viewportSize.width - 100, _hereMapController.viewportSize.height - 100);
    Rectangle2D mapViewport = Rectangle2D(origin, sizeInPixels);

    // Animate to the route within a duration of 3 seconds.
    MapCameraUpdate update = MapCameraUpdateFactory.lookAtAreaWithGeoOrientationAndViewRectangle(
        route.boundingBox, GeoOrientationUpdate(bearing, tilt), mapViewport);
    MapCameraAnimation animation = MapCameraAnimationFactory.createAnimationFromUpdateWithEasing(
        update, const Duration(milliseconds: 3000), here.Easing(here.EasingFunction.inCubic));
    _hereMapController.camera.startAnimation(animation);
  }
}
