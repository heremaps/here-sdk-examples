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
import 'package:camera_keyframe_tracks_app/RouteCalculator.dart';
import 'package:camera_keyframe_tracks_app/models/LocationKeyframeModel.dart';
import 'package:camera_keyframe_tracks_app/models/OrientationKeyframeModel.dart';
import 'package:camera_keyframe_tracks_app/models/ScalarKeyframeModel.dart';
import 'package:flutter/material.dart';
import 'package:here_sdk/animation.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart' as routes;

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

class RouteAnimationExample {
  final HereMapController _hereMapController;
  final List<MapPolyline> _mapPolylines = [];
  late RouteCalculator _routeCalculator;
  routes.Route? route;
  final ShowDialogFunction _showDialog;

  RouteAnimationExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
      : _showDialog = showDialogCallback,
        _hereMapController = hereMapController {
    _routeCalculator = RouteCalculator();
  }

  routes.Route? calculateRoute() {
    double distanceInMeters = 5000;
    _hereMapController.camera
        .lookAtPointWithDistance(GeoCoordinates(40.7116777285189, -74.01248494562448), distanceInMeters);

    // Calculates a car route.
    _routeCalculator.calculateCarRoute((_routingError, _routes) {
      if (_routingError == null) {
        routes.Route? _route = _routes?.elementAt(0);
        route = _route;
        _showRouteOnMap(route);
      } else {
        _showDialog("Error while calculating a route:", _routingError.toString());
      }
    });

    return route;
  }

  void _showRouteOnMap(routes.Route? route) {
    // Show route as polyline.
    GeoPolyline routeGeoPolyline = route!.geometry;
    double widthInPixels = 20;
    MapPolyline routeMapPolyline =
        MapPolyline(routeGeoPolyline, widthInPixels, const Color.fromARGB(160, 0, 144, 138)); // RGBA
    _hereMapController.mapScene.addMapPolyline(routeMapPolyline);
    _mapPolylines.add(routeMapPolyline);
  }

  void clearRoute() {
    for (MapPolyline mapPolyline in _mapPolylines) {
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
    }
    _mapPolylines.clear();
  }

  List<LocationKeyframeModel> _createLocationsForRouteAnimation(routes.Route route) {
    List<LocationKeyframeModel> locationList = [];
    List<GeoCoordinates> geoCoordinatesList = route.geometry.vertices;

    locationList.add(
        LocationKeyframeModel(GeoCoordinates(40.71335297425111, -74.01128262379694), const Duration(milliseconds: 0)));
    locationList.add(LocationKeyframeModel(route.boundingBox.southWestCorner, const Duration(milliseconds: 500)));

    for (int i = 0; i < geoCoordinatesList.length - 1; i++) {
      locationList.add(LocationKeyframeModel(geoCoordinatesList.elementAt(i), const Duration(milliseconds: 500)));
    }

    locationList.add(LocationKeyframeModel(
        GeoCoordinates(40.72040734322057, -74.01225894785958), const Duration(milliseconds: 1000)));

    return locationList;
  }

  List<OrientationKeyframeModel> _createOrientationForRouteAnimation() {
    List<OrientationKeyframeModel> orientationList = [];
    orientationList.add(OrientationKeyframeModel(GeoOrientation(30, 60), const Duration(milliseconds: 0)));
    orientationList.add(OrientationKeyframeModel(GeoOrientation(-40, 70), const Duration(milliseconds: 2000)));
    orientationList.add(OrientationKeyframeModel(GeoOrientation(-10, 70), const Duration(milliseconds: 1000)));
    orientationList.add(OrientationKeyframeModel(GeoOrientation(10, 70), const Duration(milliseconds: 4000)));
    orientationList.add(OrientationKeyframeModel(GeoOrientation(10, 70), const Duration(milliseconds: 4000)));

    return orientationList;
  }

  List<ScalarKeyframeModel> _createScalarForRouteAnimation() {
    List<ScalarKeyframeModel> scalarList = [];
    scalarList.add(ScalarKeyframeModel(80000000.0, const Duration(milliseconds: 0)));
    scalarList.add(ScalarKeyframeModel(8000000.0, const Duration(milliseconds: 1000)));
    scalarList.add(ScalarKeyframeModel(500.0, const Duration(milliseconds: 3000)));
    scalarList.add(ScalarKeyframeModel(500.0, const Duration(milliseconds: 6000)));
    scalarList.add(ScalarKeyframeModel(100.0, const Duration(milliseconds: 4000)));

    return scalarList;
  }

  void animateRoute(routes.Route? route) {
    // A list of location key frames for moving the map camera from one geo coordinate to another.
    List<GeoCoordinatesKeyframe> locationKeyframesList = [];
    List<LocationKeyframeModel> locationList = _createLocationsForRouteAnimation(route!);

    for (LocationKeyframeModel locationKeyframeModel in locationList) {
      locationKeyframesList
          .add(GeoCoordinatesKeyframe(locationKeyframeModel.geoCoordinates, locationKeyframeModel.duration));
    }

    // A list of geo orientation keyframes for changing the map camera orientation.
    List<GeoOrientationKeyframe> orientationKeyframeList = [];
    List<OrientationKeyframeModel> orientationList = _createOrientationForRouteAnimation();

    for (OrientationKeyframeModel orientationKeyframeModel in orientationList) {
      orientationKeyframeList
          .add(GeoOrientationKeyframe(orientationKeyframeModel.geoOrientation, orientationKeyframeModel.duration));
    }

    // A list of scalar key frames for changing the map camera distance from the earth.
    List<ScalarKeyframe> scalarKeyframesList = [];
    List<ScalarKeyframeModel> scalarList = _createScalarForRouteAnimation();

    for (ScalarKeyframeModel scalarKeyframeModel in scalarList) {
      scalarKeyframesList.add(ScalarKeyframe(scalarKeyframeModel.scalar, scalarKeyframeModel.duration));
    }

    try {
      // Creating a track to add different kinds of animations to the MapCameraKeyframeTrack.
      List<MapCameraKeyframeTrack> tracks = [];
      tracks.add(MapCameraKeyframeTrack.lookAtDistance(
          scalarKeyframesList, EasingFunction.linear, KeyframeInterpolationMode.linear));
      tracks.add(MapCameraKeyframeTrack.lookAtTarget(
          locationKeyframesList, EasingFunction.linear, KeyframeInterpolationMode.linear));
      tracks.add(MapCameraKeyframeTrack.lookAtOrientation(
          orientationKeyframeList, EasingFunction.linear, KeyframeInterpolationMode.linear));

      // All animation tracks being played here.
      startRouteAnimation(tracks);
    } on MapCameraKeyframeTrackInstantiationException catch (e) {
      print("KeyframeTrackTag: " + e.error.name);
    }
  }

  void startRouteAnimation(List<MapCameraKeyframeTrack> tracks) {
    try {
      _hereMapController.camera.startAnimation(MapCameraAnimationFactory.createAnimationFromKeyframeTracks(tracks));
    } on MapCameraKeyframeTrackInstantiationException catch (e) {
      print("KeyframeTrackTag: " + e.error.name);
    }
  }

  void stopRouteAnimation() {
    _hereMapController.camera.cancelAnimations();
  }

  void animateToRoute(routes.Route? route) {
    MapCameraUpdate update = MapCameraUpdateFactory.lookAtArea(route!.boundingBox);
    MapCameraAnimation animation = MapCameraAnimationFactory.createAnimationFromUpdate(
        update, const Duration(milliseconds: 3000), EasingFunction.inCubic);
    _hereMapController.camera.startAnimation(animation);
  }
}
