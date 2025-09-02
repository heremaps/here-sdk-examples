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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

// This example shows how to animate the MapCamera from A to B with the Camera's flyTo()-method
class CameraExample {
  final HereMapController _hereMapController;
  final double distanceToEarthInMeters = 5000;
  MapPolygon? centerMapCircle;

  CameraExample(HereMapController hereMapController) : _hereMapController = hereMapController {
    // Set initial map center to a location in Berlin.
    GeoCoordinates mapCenter = GeoCoordinates(52.530932, 13.384915);
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(mapCenter, mapMeasureZoom);
  }

  void move() {
    GeoCoordinates newTarget = _createRandomGeoCoordinatesNearby();

    // Indicate the new map center with a circle.
    _setNewMapCircle(newTarget);

    _flyTo(newTarget);
  }

  void _flyTo(GeoCoordinates geoCoordinates) {
    GeoCoordinatesUpdate geoCoordinatesUpdate = GeoCoordinatesUpdate.fromGeoCoordinates(geoCoordinates);
    double bowFactor = 1;
    MapCameraAnimation animation = MapCameraAnimationFactory.flyTo(
      geoCoordinatesUpdate,
      bowFactor,
      Duration(seconds: 3),
    );
    _hereMapController.camera.startAnimation(animation);
  }

  void _setNewMapCircle(GeoCoordinates geoCoordinates) {
    if (centerMapCircle != null) {
      _hereMapController.mapScene.removeMapPolygon(centerMapCircle!);
    }
    centerMapCircle = _createMapCircle(geoCoordinates);
    _hereMapController.mapScene.addMapPolygon(centerMapCircle!);
  }

  MapPolygon _createMapCircle(GeoCoordinates geoCoordinates) {
    double radiusInMeters = 70;
    GeoCircle geoCircle = GeoCircle(geoCoordinates, radiusInMeters);

    GeoPolygon geoPolygon = GeoPolygon.withGeoCircle(geoCircle);
    Color fillColor = Color.fromARGB(255, 0, 138, 161);
    MapPolygon mapPolygon = MapPolygon(geoPolygon, fillColor);

    return mapPolygon;
  }

  GeoCoordinates _createRandomGeoCoordinatesNearby() {
    GeoBox? geoBox = _hereMapController.camera.boundingBox;
    if (geoBox == null) {
      // Happens only when map is not fully covering the viewport.
      return GeoCoordinates(52.530932, 13.384915);
    }

    GeoCoordinates northEast = geoBox.northEastCorner;
    GeoCoordinates southWest = geoBox.southWestCorner;

    double minLat = southWest.latitude;
    double maxLat = northEast.latitude;
    double lat = _getRandom(minLat, maxLat);

    double minLon = southWest.longitude;
    double maxLon = northEast.longitude;
    double lon = _getRandom(minLon, maxLon);

    int sign1 = math.Random().nextBool() ? 1 : -1;
    int sign2 = math.Random().nextBool() ? 1 : -1;

    return GeoCoordinates(lat + 0.05 * sign1, lon + 0.05 * sign2);
  }

  double _getRandom(double min, double max) {
    return min + math.Random().nextDouble() * (max - min);
  }
}
