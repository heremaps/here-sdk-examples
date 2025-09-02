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

import 'package:custom_tile_source_app/LocalPolygonTileSource.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/mapview.datasource.dart';

class CustomPolygonTileSourceExample {
  HereMapController _hereMapController;
  MapLayer? _polygonMapLayer;
  PolygonTileDataSource? _polygonDataSource;

  String _polygonLayerStyle = """
{
  "styles": [
    {
        "layer": "MyPolygonTileDataSourceLayer",
        "technique": "polygon",
        "attr": {
            "color": "#ff000066"
        }
    }
  ]
}
""";

  CustomPolygonTileSourceExample(this._hereMapController) {
    final String dataSourceName = "MyPolygonTileDataSource";
    _polygonDataSource = _createPolygonTileDataSource(dataSourceName);
    _polygonMapLayer = _createMapLayer(dataSourceName);

    if (_polygonMapLayer != null) {
      _polygonMapLayer!.setEnabled(false);
      _polygonMapLayer!.setStyle(_createCustomStyle());
    }

    double distanceToEarthInMeters = 60 * 1000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);
  }

  void enableLayer() {
    _polygonMapLayer?.setEnabled(true);
  }

  void disableLayer() {
    _polygonMapLayer?.setEnabled(false);
  }

  PolygonTileDataSource _createPolygonTileDataSource(String dataSourceName) {
    return PolygonTileDataSource.create(_hereMapController.mapContext, dataSourceName, LocalPolygonTileSource());
  }

  MapLayer? _createMapLayer(String dataSourceName) {
    // Set the layer to be rendered on top of other layers.
    MapLayerPriority priority = MapLayerPriorityBuilder().renderedLast().build();

    // The layer should be visible for all zoom levels. The minimum tilt level is 0 and maximum zoom level is 23.
    MapLayerVisibilityRange range = MapLayerVisibilityRange(MapCameraLimits.minTilt, MapCameraLimits.maxZoomLevel);

    try {
      MapLayer mapLayer = MapLayerBuilder()
          .forMap(_hereMapController.hereMapControllerCore)
          .withName("${dataSourceName}Layer")
          .withDataSource(dataSourceName, MapContentType.polygon)
          .withPriority(priority)
          .withVisibilityRange(range)
          .build();
      return mapLayer;
    } on MapLayerBuilderInstantiationException catch (e) {
      print("Failed to create map layer: ${e.toString()}");
      return null;
    }
  }

  Style _createCustomStyle() {
    return JsonStyleFactory.createFromString(_polygonLayerStyle);
  }

  void onDestroy() {
    _polygonMapLayer?.destroy();
    _polygonDataSource?.destroy();
  }
}
