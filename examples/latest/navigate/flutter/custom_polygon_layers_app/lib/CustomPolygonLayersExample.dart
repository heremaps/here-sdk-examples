/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/mapview.datasource.dart';
import 'dart:math';

class CustomPolygonLayersExample {
  HereMapController _hereMapController;
  MapLayer? _polygonMapLayer;
  PolygonDataSource? _polygonDataSource;
  final _latitude = 52.530932;
  final _longitude = 13.384915;
  final _maxGeoCoordinateOffset = 0.5;
  final _maxRadiusInMeters = 3000.0;
  final _idAttributeName = "polygon_id";
  final _colorAttributeName = "polygon_color";
  final _latitudeAttributeName = "center_latitude";
  final _longitudeAttributeName = "center_longitude";
  final _random = Random();

  // Style for layer with 'technique' equal to 'polygon', 'layer' field equal to name of
  // map layer constructed later in code and 'color' attribute govern by
  // 'polygon_color' data attribute to be able to customize/modify colors of polygons.
  // See 'Developer Guide/Style guide for custom layers' and
  // 'Developer Guide/Style techniques reference for custom layers/polygon' for more details.
  final _polygonLayerStyle = """
  {
      "styles": [
          {
              "layer": "MyPolygonDataSourceLayer",
              "technique": "polygon",
              "attr": {
                  "color": ["to-color", ["get", "polygon_color"]]
              }
          }
      ]
  }
  """;

  CustomPolygonLayersExample(this._hereMapController) {
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.zoomLevel, 9);
    _hereMapController.camera.lookAtPointWithMeasure(
        GeoCoordinates(_latitude, _longitude), mapMeasureZoom);

    String dataSourceName = "MyPolygonDataSource";
    _polygonDataSource = _createPolygonDataSource(dataSourceName);
    _polygonMapLayer = _createMapLayer(dataSourceName);

    addRandomPolygons(100);
  }

  void enableButtonClicked() {
    _polygonMapLayer?.setEnabled(true);
  }

  void disableButtonClicked() {
    _polygonMapLayer?.setEnabled(false);
  }

  PolygonDataSource _createPolygonDataSource(String dataSourceName) {
    return PolygonDataSourceBuilder(_hereMapController.mapContext)
        .withName(dataSourceName)
        .build();
  }

  MapLayer _createMapLayer(String dataSourceName) {
    // The layer should be rendered on top of other layer.
    MapLayerPriority priority = MapLayerPriorityBuilder().renderedLast().build();
    // And it should be visible for all zoom levels. The minimum tilt level is 0 and maximum zoom level is 23.
    MapLayerVisibilityRange range = MapLayerVisibilityRange(MapCameraLimits.minTilt, MapCameraLimits.maxZoomLevel);

    try {
      // Build and add the layer to the map.
      MapLayer mapLayer = MapLayerBuilder()
          .forMap(_hereMapController.hereMapControllerCore)
          .withName(dataSourceName + "Layer")
          .withDataSource(dataSourceName, MapContentType.polygon)
          .withPriority(priority)
          .withVisibilityRange(range)
          .withStyle(JsonStyleFactory.createFromString(_polygonLayerStyle))
          .build();
      return mapLayer;
    } on MapLayerBuilderInstantiationException {
      throw Exception("MapLayer creation failed.");
    }
  }

  void onDestroy() {
    _polygonMapLayer?.destroy();
    _polygonDataSource?.destroy();
  }

  GeoPolygon _generateRandomGeoPolygon(GeoCoordinates center) {
    final geoCircle =
        GeoCircle(center, _random.nextDouble() * _maxRadiusInMeters);
    return GeoPolygon.withGeoCircle(geoCircle);
  }

  GeoCoordinates _generateRandomCoordinates() {
    return GeoCoordinates(
      (2 * _random.nextDouble() - 1) * _maxGeoCoordinateOffset + _latitude,
      (2 * _random.nextDouble() - 1) * _maxGeoCoordinateOffset + _longitude,
    );
  }

  String _randomColorString() {
    final randomColor =
        Color((_random.nextDouble() * 0xFFFFFF).toInt());
    final str = '#${randomColor.value.toRadixString(16)}';
    return str;
  }

  PolygonData _generateRandomPolygon() {
    final center = _generateRandomCoordinates();
    final attributesBuilder = DataAttributesBuilder()
        .withLong(_idAttributeName, _random.nextInt(2))
        .withString(_colorAttributeName, _randomColorString())
        .withDouble(_latitudeAttributeName, center.latitude)
        .withDouble(_longitudeAttributeName, center.longitude);

    final polygonData = PolygonDataBuilder()
        .withAttributes(attributesBuilder.build())
        .withGeometry(_generateRandomGeoPolygon(center))
        .build();
    return polygonData;
  }

  void addRandomPolygons(int numberOfPolygons) {
    List<PolygonData> polygons = [];
    for (var i = 0; i < numberOfPolygons; i++) {
      polygons.add(_generateRandomPolygon());
    }
    _polygonDataSource?.addPolygons(polygons);
  }

  void modifyPolygons() {
    _polygonDataSource?.forEach((polygonDataAccessor) {
      var attributesAccessor = polygonDataAccessor.getAttributes();

      // 'process' function is executed on each item in data source so here is place to
      // perform some kind of filtering. In our case we decide, based on parity of
      // 'polygon_id' data attribute, to either modify color or geometry of item.

      final objectId = attributesAccessor.getInt64(_idAttributeName) ?? 0;
      if (objectId % 2 == 0) {
        // modify color
        attributesAccessor.addOrReplaceString(
            _colorAttributeName, _randomColorString());
      } else {
        // read back polygon center
        final center = GeoCoordinates(
            attributesAccessor.getDouble(_latitudeAttributeName) ?? 0.0,
            attributesAccessor.getDouble(_longitudeAttributeName) ?? 0.0);
        // set new geometry centered at previous location

        polygonDataAccessor.setGeometry(_generateRandomGeoPolygon(center));
      }

      // Return value 'True' denotes we want to keep processing subsequent items in data
      // source. In case of performing modification on just one item, we could return
      // 'False' after processing the proper one.
      return true;
    });
  }

  void removePolygons() {
    _polygonDataSource?.removeAll();
  }
}
