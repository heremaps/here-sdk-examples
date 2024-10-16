/*
 * Copyright (C) 2024 HERE Europe B.V.
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
import 'LocalPointTileSource.dart';

class CustomPointTileSourceExample {
  HereMapController _hereMapController;
  MapLayer? _pointMapLayer;
  PointTileDataSource? _pointDataSource;

  // Style for layer with 'technique' equal to 'icon-text', 'layer' field equal to name of
  // map layer constructed later in code and 'text' attribute govern by 'pointText' data
  // attribute to be able to customize/modify the text of points.
  // See 'Developer Guide/Style guide for custom layers' and
  // 'Developer Guide/Style techniques reference for custom layers/icon-text' for more details.
  final _pointLayerStyle = """
  {
      "styles": [
          {
              "layer": "MyPointDataSourceLayer",
              "technique": "icon-text",
              "attr": {
                  "text-color": "#ff0000ff",
                  "text-size": 30,
                  "text": ["get", "pointText"]
              }
          }
      ]
  }
  """;

  CustomPointTileSourceExample(this._hereMapController) {
  
    String dataSourceName = "MyPointDataSource";
    _pointDataSource = _createPointTileDataSource(dataSourceName);
    _pointMapLayer = _createMapLayer(dataSourceName);

    double distanceToEarthInMeters = 60 * 1000;
    MapMeasure mapMeasureZoom =
        MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(
        GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);
  }

  void enableButtonClicked() {
    _pointMapLayer?.setEnabled(true);
  }

  void disableButtonClicked() {
    _pointMapLayer?.setEnabled(false);
  }

  PointTileDataSource _createPointTileDataSource(String dataSourceName)  {
    var localPointTileSource = LocalPointTileSource();

    // Note that this will make the point source already known to the passed map view.
    return PointTileDataSource.create(
        _hereMapController.mapContext, dataSourceName, localPointTileSource);
  }

  MapLayer _createMapLayer(String dataSourceName) {
    // The layer should be visible for all zoom levels.
    MapLayerVisibilityRange range = MapLayerVisibilityRange(0, 22 + 1);

    try {
      // Build and add the layer to the map.
      MapLayer mapLayer = MapLayerBuilder()
          .forMap(
              _hereMapController.hereMapControllerCore) // mandatory parameter
          .withName(dataSourceName + "Layer") // mandatory parameter
          .withDataSource(dataSourceName, MapContentType.point)
          .withStyle(JsonStyleFactory.createFromString(_pointLayerStyle))
          .withVisibilityRange(range)
          .build();
      return mapLayer;
    } on MapLayerBuilderInstantiationException {
      throw Exception("MapLayer creation failed.");
    }
  }

  void onDestroy() {
    _pointMapLayer?.destroy();
    _pointDataSource?.destroy();
  }
}
