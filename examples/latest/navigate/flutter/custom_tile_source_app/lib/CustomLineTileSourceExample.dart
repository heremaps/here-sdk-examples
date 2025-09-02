/*
 * Copyright (C) 2025 HERE Europe B.V.
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

import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/mapview.datasource.dart';
import 'LocalLineTileSource.dart';

/**
 * This example app demonstrates how to load custom line layers, implement line rendering using a custom line tile source,
 * and integrate custom styles. It enables the display of custom line tiles with configurable styling, with data sourced
 * either from the local file system or a custom backend.
 *
 * In this implementation, custom line data is provided to the HERE SDK based on the requested `TileKey`, allowing dynamic
 * rendering of line geometries.
 */
class CustomLineTileSourceExample {
  HereMapController _hereMapController;
  MapLayer? _lineMapLayer;
  LineTileDataSource? _lineDataSource;

  final String _lineLayerStyle = ''' 
  {
    "styles": [
      {
        "layer": "MyLineTileDataSourceLayer",
        "technique": "line",
        "attr": {
          "color": "#FF0000",
          "width": ["world-scale", 5]
        }
      }
    ]
  }
  ''';

  CustomLineTileSourceExample(this._hereMapController) {
    String dataSourceName = "MyLineTileDataSource";
    _lineDataSource = _createLineTileDataSource(dataSourceName);
    _lineMapLayer = _createMapLayer(dataSourceName);

    if (_lineMapLayer != null) {
      _lineMapLayer!.setEnabled(false);
      _lineMapLayer!.setStyle(_createCustomStyle());
    }

    double distanceToEarthInMeters = 60 * 1000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);
  }

  void enableLayer() {
    _lineMapLayer?.setEnabled(true);
  }

  void disableLayer() {
    _lineMapLayer?.setEnabled(false);
  }

  LineTileDataSource _createLineTileDataSource(String dataSourceName) {
    var localLineTileSource = LocalLineTileSource();

    return LineTileDataSource.create(_hereMapController.mapContext, dataSourceName, localLineTileSource);
  }

  MapLayer? _createMapLayer(String dataSourceName) {
    // The layer should be visible for all zoom levels. The minimum tilt level is 0 and maximum zoom level is 23.
    MapLayerVisibilityRange range = MapLayerVisibilityRange(MapCameraLimits.minTilt, MapCameraLimits.maxZoomLevel);

    try {
      return MapLayerBuilder()
          .forMap(_hereMapController.hereMapControllerCore)
          .withName("${dataSourceName}Layer")
          .withDataSource(dataSourceName, MapContentType.line)
          .withStyle(_createCustomStyle())
          .withVisibilityRange(range)
          .build();
    } on MapLayerBuilderInstantiationException catch (e) {
      print("Failed to create map layer: ${e.toString()}");
      return null;
    }
  }

  Style _createCustomStyle() {
    return JsonStyleFactory.createFromString(_lineLayerStyle);
  }

  void onDestroy() {
    _lineMapLayer?.destroy();
    _lineDataSource?.destroy();
  }
}
