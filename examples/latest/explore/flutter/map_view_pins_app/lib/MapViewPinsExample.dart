/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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
import 'package:here_sdk/mapview.dart';

class MapViewPinsExample {
  HereMapController _hereMapController;
  final GeoCoordinates MAP_CENTER_GEO_COORDINATES = GeoCoordinates(52.520798, 13.409408);

  MapViewPinsExample(HereMapController hereMapController) {
    _hereMapController = hereMapController;

    double distanceToEarthInMeters = 7000;
    _hereMapController.camera.lookAtPointWithDistance(MAP_CENTER_GEO_COORDINATES, distanceToEarthInMeters);

    // Add circle to indicate map center.
    _addCirclePolygon(MAP_CENTER_GEO_COORDINATES);
  }

  void addDefaultMapViewPinButtonClicked() {
    _hereMapController.pinWidget(
        _createWidget("Centered ViewPin", Color.fromARGB(150, 0, 194, 138)), MAP_CENTER_GEO_COORDINATES);
  }

  void addAnchoredMapViewPinButtonClicked() {
    var widgetPin = _hereMapController.pinWidget(
        _createWidget("Anchored MapViewPin", Color.fromARGB(200, 0, 144, 138)), MAP_CENTER_GEO_COORDINATES);
    widgetPin.anchor = Anchor2D.withHorizontalAndVertical(0.5, 1);
  }

  void clearMap() {
    // Note: We make a deep copy of the list as we modify it during iteration.
    List<WidgetPin> mapViewPins = [..._hereMapController.widgetPins];
    mapViewPins.forEach((widgetPin) {
      widgetPin.unpin();
    });
  }

  Widget _createWidget(String label, Color backgroundColor) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: Colors.black),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 20.0),
      ),
    );
  }

  void _addCirclePolygon(GeoCoordinates geoCoordinates) {
    double radiusInMeters = 120;
    GeoCircle geoCircle = GeoCircle(MAP_CENTER_GEO_COORDINATES, radiusInMeters);

    GeoPolygon geoPolygon = GeoPolygon.withGeoCircle(geoCircle);
    Color fillColor = Color.fromARGB(160, 255, 165, 0);
    MapPolygon mapPolygon = MapPolygon(geoPolygon, fillColor);

    _hereMapController.mapScene.addMapPolygon(mapPolygon);
  }
}
