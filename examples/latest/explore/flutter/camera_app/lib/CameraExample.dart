/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
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

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';

/**
 * This example shows how to use the Camera class to rotate and tilt the map programmatically, to set
 * a new transform center that influences those operations, and to move to a new location.
 * For more features of the Camera class, please consult the API Reference and the Developer's Guide.
 */
class CameraExample {
  static const double _defaultDistanceToEarthInMeters = 8000;

  final HereMapController _hereMapController;
  late final MapCamera _camera;

  MapPolygon? _poiMapCircle;

  /// Notifies UI about a new principal point (tap position in pixels).
  final StreamController<Point2D> _principalPointController = StreamController<Point2D>.broadcast();
  Stream<Point2D> get principalPointStream => _principalPointController.stream;

  /// Notifies UI to show a toast-like message.
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  Stream<String> get messageStream => _messageController.stream;

  MapCameraListener? _cameraListener;

  CameraExample(HereMapController hereMapController) : _hereMapController = hereMapController {
    _camera = _hereMapController.camera;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, _defaultDistanceToEarthInMeters);
    _camera.lookAtPointWithMeasure(GeoCoordinates(52.750731, 13.007375), mapMeasureZoom);

    // The POI MapCircle (green) indicates the next location to move to.
    _updatePoiCircle(_getRandomGeoCoordinates());

    _addCameraObserver();
    _setTapGestureHandler();

    _showNote();
  }

  void dispose() {
    // Important: remove listeners to avoid leaks.
    _hereMapController.gestures.tapListener = null;

    _camera.removeListener(_cameraListener!);
    _cameraListener = null;

    _principalPointController.close();
    _messageController.close();
  }

  void rotateButtonClicked() {
    _rotateMap(10);
  }

  void tiltButtonClicked() {
    _tiltMap(5);
  }

  void moveButtonClicked() {
    GeoCoordinates geoCoordinates = _getRandomGeoCoordinates();
    _updatePoiCircle(geoCoordinates);
    _flyTo(geoCoordinates);
  }

  void _flyTo(GeoCoordinates geoCoordinates) {
    GeoCoordinatesUpdate geoCoordinatesUpdate = GeoCoordinatesUpdate.fromGeoCoordinates(geoCoordinates);
    double bowFactor = 1;
    MapCameraAnimation animation = MapCameraAnimationFactory.flyTo(
      geoCoordinatesUpdate,
      bowFactor,
      const Duration(seconds: 3),
    );
    _camera.startAnimation(animation);
  }

  // Rotate the map by x degrees. Tip: Try to see what happens for negative values.
  void _rotateMap(int bearingStepInDegrees) {
    double currentBearing = _camera.state.orientationAtTarget.bearing;
    double newBearing = currentBearing + bearingStepInDegrees;

    //By default, bearing will be clamped to the range (0, 360].
    GeoOrientationUpdate orientationUpdate = GeoOrientationUpdate(newBearing, null);
    _camera.setOrientationAtTarget(orientationUpdate);
  }

  // Tilt the map by x degrees.
  void _tiltMap(int tiltStepInDegrees) {
    double currentTilt = _camera.state.orientationAtTarget.tilt;
    double newTilt = currentTilt + tiltStepInDegrees;

    //By default, tilt will be clamped to the range [0, 70].
    GeoOrientationUpdate orientationUpdate = GeoOrientationUpdate(null, newTilt);
    _camera.setOrientationAtTarget(orientationUpdate);
  }

  void _setTapGestureHandler() {
    _hereMapController.gestures.tapListener = TapListener(_setTransformCenter);
  }

  // The new transform center will be used for all programmatical map transformations
  // and determines where the target is located in the view.
  // By default, the target point is located at the center of the view.
  // Note: Gestures are not affected, for example, the pinch-rotate gesture and
  // the two-finger-pan (=> tilt) will work like before.
  void _setTransformCenter(Point2D mapViewTouchPointInPixels) {
    if (_principalPointController.isClosed) return;
    // Note that this moves the current camera's target at the location where you tapped the screen.
    // Effectively, you move the map by changing the camera's target.
    _camera.principalPoint = mapViewTouchPointInPixels;

    // Reposition circle view on screen to indicate the new target.
    _principalPointController.add(mapViewTouchPointInPixels);

    _messageController.add(
      "New transform center: ${mapViewTouchPointInPixels.x.toStringAsFixed(1)}, ${mapViewTouchPointInPixels.y.toStringAsFixed(1)}",
    );
  }

  void _addCameraObserver() {
    _cameraListener = MapCameraListener((state) {
      if (_messageController.isClosed) return;
      GeoCoordinates camTarget = state.targetCoordinates;
      // ignore: avoid_print
      print("CameraListener: New camera target: ${camTarget.latitude}, ${camTarget.longitude}");
    });

    _camera.addListener(_cameraListener!);
  }

  void _showNote() {
    _messageController.add("Note: Tap the map to set a new transform center.");
  }

  // ---- Implementation details (ported from Java) ----

  void _updatePoiCircle(GeoCoordinates geoCoordinates) {
    if (_poiMapCircle != null) {
      _hereMapController.mapScene.removeMapPolygon(_poiMapCircle!);
    }

    _poiMapCircle = _createMapCircle(geoCoordinates);
    _hereMapController.mapScene.addMapPolygon(_poiMapCircle!);
  }

  MapPolygon _createMapCircle(GeoCoordinates geoCoordinates) {
    double radiusInMeters = 300;
    GeoCircle geoCircle = GeoCircle(geoCoordinates, radiusInMeters);

    GeoPolygon geoPolygon = GeoPolygon.withGeoCircle(geoCircle);
    Color fillColor = const Color.fromARGB(255, 0, 255, 0); // RGBA
    MapPolygon mapPolygon = MapPolygon(geoPolygon, fillColor);

    return mapPolygon;
  }

  GeoCoordinates _getRandomGeoCoordinates() {
    final currentTarget = _camera.state.targetCoordinates;
    const amount = 0.05;

    final latitude = _getRandom(currentTarget.latitude - amount, currentTarget.latitude + amount);
    final longitude = _getRandom(currentTarget.longitude - amount, currentTarget.longitude + amount);

    return GeoCoordinates(latitude, longitude);
  }

  double _getRandom(double min, double max) {
    return min + math.Random().nextDouble() * (max - min);
  }
}
