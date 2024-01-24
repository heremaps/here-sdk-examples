/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

class MapViewPinsExample {
  final GeoCoordinates mapCenterGeoCoordinates = GeoCoordinates(52.51760485151816, 13.380312380535472);

  final HereMapController _hereMapController;
  final MapCamera _mapCamera;

  MapViewPinsExample(HereMapController hereMapController)
      : _hereMapController = hereMapController,
        _mapCamera = hereMapController.camera {
    double distanceToEarthInMeters = 7000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    _mapCamera.lookAtPointWithMeasure(mapCenterGeoCoordinates, mapMeasureZoom);

    // Add circle to indicate map center.
    _addCircle(mapCenterGeoCoordinates);
  }

  void showDefaultMapViewPin() {
    // Move map to expected location.
    _flyTo(mapCenterGeoCoordinates);

    _hereMapController.pinWidget(
        _createWidget("Centered ViewPin", Color.fromARGB(150, 0, 194, 138)), mapCenterGeoCoordinates);
  }

  void showAnchoredMapViewPin() {
    // Move map to expected location.
    _flyTo(mapCenterGeoCoordinates);

    var widgetPin = _hereMapController.pinWidget(
        _createWidget("Anchored MapViewPin", Color.fromARGB(200, 0, 144, 138)), mapCenterGeoCoordinates);
    widgetPin?.anchor = Anchor2D.withHorizontalAndVertical(0.5, 1);
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
      child: GestureDetector(child: Text(
        label,
        style: TextStyle(fontSize: 20.0),
      ),
        onTap: () {
        print("Tapped on " + label);
        },
      ),
    );
  }

  Future<void> _addCircle(GeoCoordinates geoCoordinates) async {
    Uint8List imagePixelData = await _loadFileAsUint8List('assets/circle.png');
    MapImage circleMapImage = MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    MapMarker mapMarker = MapMarker(geoCoordinates, circleMapImage);
    _hereMapController.mapScene.addMapMarker(mapMarker);
  }

  Future<Uint8List> _loadFileAsUint8List(String assetPathToFile) async {
    // The path refers to the assets directory as specified in pubspec.yaml.
    ByteData fileData = await rootBundle.load(assetPathToFile);
    return Uint8List.view(fileData.buffer);
  }

  void _flyTo(GeoCoordinates geoCoordinates) {
    GeoCoordinatesUpdate geoCoordinatesUpdate = GeoCoordinatesUpdate.fromGeoCoordinates(geoCoordinates);
    double bowFactor = 1;
    MapCameraAnimation animation =
    MapCameraAnimationFactory.flyTo(geoCoordinatesUpdate, bowFactor, Duration(seconds: 3));
    _mapCamera.startAnimation(animation);
  }
}
