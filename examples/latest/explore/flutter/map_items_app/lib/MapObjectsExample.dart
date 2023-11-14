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

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';

class MapObjectsExample {
  final GeoCoordinates _berlinGeoCoordinates = new GeoCoordinates(52.51760485151816, 13.380312380535472);

  final MapScene _mapScene;
  final MapCamera _mapCamera;
  MapPolyline? _mapPolyline;
  MapArrow? _mapArrow;
  MapPolygon? _mapPolygon;
  MapPolygon? _mapCircle;

  MapObjectsExample(HereMapController hereMapController)
      : _mapScene = hereMapController.mapScene,
        _mapCamera = hereMapController.camera {
    double distanceToEarthInMeters = 5000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    hereMapController.camera
        .lookAtPointWithMeasure(GeoCoordinates(52.51760485151816, 13.380312380535472), mapMeasureZoom);
  }

  void showMapPolyline() {
    clearMap();
    // Move map to expected location.
    _flyTo(_berlinGeoCoordinates);

    _mapPolyline = _createPolyline();
    _mapScene.addMapPolyline(_mapPolyline!);
  }

  void showMapArrow() {
    clearMap();
    // Move map to expected location.
    _flyTo(_berlinGeoCoordinates);

    _mapArrow = _createMapArrow();
    _mapScene.addMapArrow(_mapArrow!);
  }

  void showMapPolygon() {
    clearMap();
    // Move map to expected location.
    _flyTo(_berlinGeoCoordinates);

    _mapPolygon = _createPolygon();
    _mapScene.addMapPolygon(_mapPolygon!);
  }

  void showMapCircle() {
    clearMap();
    // Move map to expected location.
    _flyTo(_berlinGeoCoordinates);

    _mapCircle = _createMapCircle();
    _mapScene.addMapPolygon(_mapCircle!);
  }

  void clearMap() {
    if (_mapPolyline != null) {
      _mapScene.removeMapPolyline(_mapPolyline!);
    }

    if (_mapArrow != null) {
      _mapScene.removeMapArrow(_mapArrow!);
    }

    if (_mapPolygon != null) {
      _mapScene.removeMapPolygon(_mapPolygon!);
    }

    if (_mapCircle != null) {
      _mapScene.removeMapPolygon(_mapCircle!);
    }
  }

  MapPolyline? _createPolyline() {
    List<GeoCoordinates> coordinates = [];
    coordinates.add(GeoCoordinates(52.53032, 13.37409));
    coordinates.add(GeoCoordinates(52.5309, 13.3946));
    coordinates.add(GeoCoordinates(52.53894, 13.39194));
    coordinates.add(GeoCoordinates(52.54014, 13.37958));

    GeoPolyline geoPolyline;
    try {
      geoPolyline = GeoPolyline(coordinates);
    } on InstantiationException {
      // Thrown when less than two vertices.
      return null;
    }

    double widthInPixels = 20;
    Color lineColor = Color.fromARGB(160, 0, 144, 138);
    MapPolyline? mapPolyline;
    try {
      mapPolyline = MapPolyline.withRepresentation(
          geoPolyline,
          MapPolylineSolidRepresentation(
              MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.pixels, widthInPixels),
              lineColor,
              LineCap.round));
    } on MapPolylineRepresentationInstantiationException catch (e) {
      print("MapPolylineRepresentation Exception:" + e.error.name);
    } on MapMeasureDependentRenderSizeInstantiationException catch (e) {
      print("MapMeasureDependentRenderSize Exception:" + e.error.name);
    }

    return mapPolyline;
  }

  MapArrow? _createMapArrow() {
    List<GeoCoordinates> coordinates = [];
    coordinates.add(GeoCoordinates(52.53032, 13.37409));
    coordinates.add(GeoCoordinates(52.5309, 13.3946));
    coordinates.add(GeoCoordinates(52.53894, 13.39194));
    coordinates.add(GeoCoordinates(52.54014, 13.37958));

    GeoPolyline geoPolyline;
    try {
      geoPolyline = GeoPolyline(coordinates);
    } on InstantiationException {
      // Thrown when less than two vertices.
      return null;
    }

    double widthInPixels = 20;
    Color lineColor = Color.fromARGB(160, 0, 144, 138);
    MapArrow mapArrow = MapArrow(geoPolyline, widthInPixels, lineColor);

    return mapArrow;
  }

  MapPolygon? _createPolygon() {
    List<GeoCoordinates> coordinates = [];
    // Note that a polygon requires a clockwise or counter-clockwise order of the coordinates.
    coordinates.add(GeoCoordinates(52.54014, 13.37958));
    coordinates.add(GeoCoordinates(52.53894, 13.39194));
    coordinates.add(GeoCoordinates(52.5309, 13.3946));
    coordinates.add(GeoCoordinates(52.53032, 13.37409));

    GeoPolygon geoPolygon;
    try {
      geoPolygon = GeoPolygon(coordinates);
    } on InstantiationException {
      // Less than three vertices.
      return null;
    }

    Color fillColor = Color.fromARGB(160, 0, 144, 138);
    MapPolygon mapPolygon = MapPolygon(geoPolygon, fillColor);

    return mapPolygon;
  }

  MapPolygon _createMapCircle() {
    double radiusInMeters = 300;
    GeoCircle geoCircle = GeoCircle(GeoCoordinates(52.51760485151816, 13.380312380535472), radiusInMeters);

    GeoPolygon geoPolygon = GeoPolygon.withGeoCircle(geoCircle);
    Color fillColor = Color.fromARGB(160, 0, 144, 138);
    MapPolygon mapPolygon = MapPolygon(geoPolygon, fillColor);

    return mapPolygon;
  }

  void _flyTo(GeoCoordinates geoCoordinates) {
    GeoCoordinatesUpdate geoCoordinatesUpdate = GeoCoordinatesUpdate.fromGeoCoordinates(geoCoordinates);
    double distanceToEarthInMeters = 1000 * 8;
    var mapMeasure = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    double bowFactor = 1;
    MapCameraAnimation animation =
        MapCameraAnimationFactory.flyToWithZoom(geoCoordinatesUpdate, mapMeasure, bowFactor, Duration(seconds: 3));
    _mapCamera.startAnimation(animation);
  }
}
