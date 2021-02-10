/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

// This example shows how to animate the MapCamera of the HERE SDK using Flutter's animation framework to
// animate from the map center location to a random location inside the viewport.
// See more about Flutter's Tween class and AnimationController here:
// https://flutter.dev/docs/development/ui/animations/tutorial
// Note: Alternatively, you can run basic animations from A to B with the Camera's flyTo()-method. 
class CameraExample {
  TickerProvider _tickerProvider;
  HereMapController _hereMapController;
  final double distanceToEarthInMeters = 5000;
  MapPolygon centerMapCircle;

  CameraExample(TickerProvider tickerProvider, HereMapController hereMapController) {
    // We use Flutter's TickerProvider within the scope of the hosting widget to sync animations with the frame rate.
    _tickerProvider = tickerProvider;
    _hereMapController = hereMapController;

    // Set initial map center to a location in Berlin by locating the MapCamera above.
    GeoCoordinates mapCenter = GeoCoordinates(52.530932, 13.384915);
    _hereMapController.camera.lookAtPointWithDistance(mapCenter, distanceToEarthInMeters);
    _setNewMapCircle(mapCenter);
  }

  void move() {
    // 1. Create a linear animation from one GeoCoordinates instance to another using a customized Tween class.
    GeoCoordinates startGeoCoordinates = _hereMapController.camera.state.targetCoordinates;
    GeoCoordinates destinationGeoCoordinates = _createRandomGeoCoordinatesNearby();
    var geoCoordinatesAnimation = GeoTween(
      begin: startGeoCoordinates,
      end: destinationGeoCoordinates,
    );

    // Indicate the new map center with a circle.
    _setNewMapCircle(destinationGeoCoordinates);

    // 2. Create an animation for the MapCamera's distance to earth for a bow effect
    // using some of Flutter's predefined Curves.
    var cameraDistanceAnimation = TweenSequence(<TweenSequenceItem<double>>[
      // Zoom out.
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: distanceToEarthInMeters,
          end: distanceToEarthInMeters * 3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      // Zoom in.
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: distanceToEarthInMeters * 3,
          end: distanceToEarthInMeters,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]);

    // 3. Create an AnimationController and set a fixed duration for the animation no matter how far the map moves.
    const int animationDurationInSeconds = 2;
    var animationController = AnimationController(
      duration: const Duration(seconds: animationDurationInSeconds),
      vsync: _tickerProvider,
    );

    // 4. Start listening to receive interpolated animation values.
    animationController.addListener(() {
      // As this is called multiple times per second (for each rendered frame), the map moves smoothly to the
      // new target location.
      GeoCoordinates targetLocation = geoCoordinatesAnimation.evaluate(animationController);

      // Changes over time to create a bow animation effect for the MapCamera.
      double distanceToEarthInMeters = cameraDistanceAnimation.evaluate(animationController);

      // Instantly sets the map to a new target center.
      _hereMapController.camera.lookAtPointWithDistance(
        targetLocation,
        distanceToEarthInMeters,
      );
    });

    // 5. Start the animation.
    animationController.forward().then((value) => animationController.dispose());
  }

  void _setNewMapCircle(GeoCoordinates geoCoordinates) {
    if (centerMapCircle != null) {
      _hereMapController.mapScene.removeMapPolygon(centerMapCircle);
    }
    centerMapCircle = _createMapCircle(geoCoordinates);
    _hereMapController.mapScene.addMapPolygon(centerMapCircle);
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
    GeoBox geoBox = _hereMapController.camera.boundingBox;
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

// Finds the GeoCoordinates that equate to the location between two other GeoCoordinates
// for a given animation clock value t.
class GeoTween extends Tween<GeoCoordinates> {
  GeoTween({GeoCoordinates begin, GeoCoordinates end}) : super(begin: begin, end: end);

  @override
  GeoCoordinates lerp(double t) {
    var p1 = _toRadians(this.begin.latitude), l1 = _toRadians(this.begin.longitude);
    var p2 = _toRadians(this.end.latitude), l2 = _toRadians(this.end.longitude);

    // Determines the great-circle distance between two points on a sphere given their latitudes and longitudes
    // using haversine formula.
    // The Haversine implementation is based on Chris Veness (www.movable-type.co.uk/scripts/geodesy-library.html#latlon-spherical).
    // Note: Alternatively, for most animation use cases a flat straight line interpolation between GeoCoordinates
    // is also sufficient.
    var dp = p2 - p1;
    var dl = l2 - l1;
    var a = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    var dist = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    var A = math.sin((1 - t) * dist) / math.sin(dist);
    var B = math.sin(t * dist) / math.sin(dist);

    var x = A * math.cos(p1) * math.cos(l1) + B * math.cos(p2) * math.cos(l2);
    var y = A * math.cos(p1) * math.sin(l1) + B * math.cos(p2) * math.sin(l2);
    var z = A * math.sin(p1) + B * math.sin(p2);

    var p3 = math.atan2(z, math.sqrt(x * x + y * y));
    var l3 = math.atan2(y, x);

    return GeoCoordinates(_toDegrees(p3), _toDegrees(l3));
  }

  // Alternatively, use a math lib like https://pub.dev/packages/vector_math.
  double _toRadians(x) {
    return x * (math.pi) / 180;
  }

  double _toDegrees(rad) {
    return (rad * 180.0) / math.pi;
  }
}
