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

import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/mapview.datasource.dart';

class OutdoorRasterLayer {
  final HereMapController mapView;
  MapLayer? customRasterLayer;
  RasterDataSource? customRasterDataSourceStyle;

  OutdoorRasterLayer(this.mapView) {
    final dataSourceName = 'myRasterDataSourceStyle';
    customRasterDataSourceStyle = createRasterDataSource(dataSourceName);
    customRasterLayer = _createMapLayer(dataSourceName);

    // We want to start with the default map style.
    customRasterLayer!.setEnabled(false);
  }

  void enable() {
    customRasterLayer?.setEnabled(true);
  }

  void disable() {
    customRasterLayer?.setEnabled(false);
  }

  RasterDataSource createRasterDataSource(String dataSourceName) {
    // Note: As an example, below is an URL template of an outdoor layer from thunderforest.com.
    // On their web page you can register a key. Without setting a valid API key, the tiles will
    // show a watermark.
    // More details on the terms of usage can be found here: https://www.thunderforest.com/terms/
    // For example, your application must have working links to https://www.thunderforest.com
    // and https://www.osm.org/copyright.
    // For the below template URL, please pay attention to the following attribution:
    // Maps © www.thunderforest.com, Data © www.osm.org/copyright.
    // Alternatively, choose another tile provider or use the (customizable) map styles provided by HERE.
    final templateUrl = 'https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png';

    // The storage levels available for this data source. Supported range [0, 31].
    final storageLevels = <int>[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

    var rasterProviderConfig = RasterDataSourceProviderConfiguration.withDefaults(
      TileUrlProviderFactory.fromXyzUrlTemplate(templateUrl)!,
      TilingScheme.quadTreeMercator,
      storageLevels,
    );

    // If you want to add transparent layers then set this to true.
    rasterProviderConfig.hasAlphaChannel = false;

    // Raster tiles are stored in a separate cache on the device.
    final path = 'cache/raster/mycustomlayer';
    final maxDiskSizeInBytes = 1024 * 1024 * 128; // 128 MB
    final cacheConfig = RasterDataSourceCacheConfiguration(path, maxDiskSizeInBytes);

    // Note that this will make the raster source already known to the passed map view.
    return RasterDataSource(
      mapView.mapContext,
      RasterDataSourceConfiguration(dataSourceName, rasterProviderConfig, cacheConfig, true),
    );
  }

  _createMapLayer(String dataSourceName) {
    // The layer should be rendered on top of other layers except the layers showing the location indicator and polylines/polygons.
    final priority = MapLayerPriorityBuilder()
        .renderedAfterLayer("labels")
        .renderedBeforeLayer('&location_indicator_layer')
        .renderedBeforeLayer('&polyline_layer')
        .build();

    // And it should be visible for all zoom levels. The minimum tilt level is 0 and maximum zoom level is 23.
    final range = MapLayerVisibilityRange(MapCameraLimits.minTilt, MapCameraLimits.maxZoomLevel);

    try {
      // Build and add the layer to the map.
      final mapLayer = MapLayerBuilder()
          .forMap(mapView.hereMapControllerCore) // mandatory parameter
          .withName(dataSourceName + 'Layer') // mandatory parameter
          .withDataSource(dataSourceName, MapContentType.rasterImage)
          .withPriority(priority)
          .withVisibilityRange(range)
          .build();

      return mapLayer;
    } on InstantiationException catch (e) {
      print("Error: " + e.error.name);
    }
  }

  void onDestroy() {
    customRasterLayer?.destroy();
    customRasterDataSourceStyle?.destroy();
  }
}
