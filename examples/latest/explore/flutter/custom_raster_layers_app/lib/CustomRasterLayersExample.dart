/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/mapview.datasource.dart';

class CustomRasterLayersExample {
  HereMapController _hereMapController;
  MapLayer? _rasterMapLayerTonerStyle;
  RasterDataSource? _rasterDataSourceTonerStyle;
  MapImage? _poiMapImage;

  CustomRasterLayersExample(HereMapController this._hereMapController) {
    double distanceToEarthInMeters = 60 * 1000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

    String dataSourceName = "myRasterDataSourceTonerStyle";
    _rasterDataSourceTonerStyle = _createRasterDataSource(dataSourceName);
    _rasterMapLayerTonerStyle = _createMapLayer(dataSourceName);

    // We want to start with the default map style.
    _rasterMapLayerTonerStyle?.setEnabled(false);

    // Add a POI marker
    _addPOIMapMarker(GeoCoordinates(52.530932, 13.384915), 1);
  }

  void enableButtonClicked() {
    _rasterMapLayerTonerStyle?.setEnabled(true);
  }

  void disableButtonClicked() {
    _rasterMapLayerTonerStyle?.setEnabled(false);
  }

  // Note: Map tile data source by Stamen Design (http://stamen.com),
  // under CC BY 3.0 (http://creativecommons.org/licenses/by/3.0).
  // Data by OpenStreetMap, under ODbL (http://www.openstreetmap.org/copyright):
  // For more details, check: http://maps.stamen.com/#watercolor/12/37.7706/-122.3782.
  RasterDataSource _createRasterDataSource(String dataSourceName) {
    // The URL template that is used to download tiles from the device or a backend data source.
    String templateUrl = "https://stamen-tiles.a.ssl.fastly.net/toner/{z}/{x}/{y}.png";
    // The storage levels available for this data source. Supported range [0, 31].
    List<int> storageLevels = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
    RasterDataSourceProviderConfiguration rasterProviderConfig =
        RasterDataSourceProviderConfiguration.withDefaults(templateUrl, TilingScheme.quadTreeMercator, storageLevels);

    // If you want to add transparent layers then set this to true.
    rasterProviderConfig.hasAlphaChannel = false;

    // Raster tiles are stored in a separate cache on the device.
    String path = "cache/raster/toner";
    int maxDiskSizeInBytes = 1024 * 1024 * 32;
    RasterDataSourceCacheConfiguration cacheConfig = RasterDataSourceCacheConfiguration(path, maxDiskSizeInBytes);

    // Note that this will make the raster source already known to the passed map view.
    return RasterDataSource(_hereMapController.mapContext,
        RasterDataSourceConfiguration.withDefaults(dataSourceName, rasterProviderConfig, cacheConfig));
  }

  MapLayer _createMapLayer(String dataSourceName) {
    // The layer should be rendered on top of other layers except the labels layer so that we don't overlap raster layer over POI markers.
    MapLayerPriority priority = MapLayerPriorityBuilder().renderedLast().renderedBeforeLayer("labels").build();
    // And it should be visible for all zoom levels.
    MapLayerVisibilityRange range = MapLayerVisibilityRange(0, 22 + 1);

    try {
      // Build and add the layer to the map.
      MapLayer mapLayer = MapLayerBuilder()
          .forMap(_hereMapController.hereMapControllerCore) // mandatory parameter
          .withName(dataSourceName + "Layer") // mandatory parameter
          .withDataSource(dataSourceName, MapContentType.rasterImage)
          .withPriority(priority)
          .withVisibilityRange(range)
          .build();
      return mapLayer;
    } on MapLayerBuilderInstantiationException {
      throw Exception("MapLayer creation failed.");
    }
  }

  void onDestroy() {
    _rasterMapLayerTonerStyle?.destroy();
    _rasterDataSourceTonerStyle?.destroy();
  }

  Future<void> _addPOIMapMarker(GeoCoordinates geoCoordinates, int drawOrder) async {
    // Reuse existing MapImage for new map markers.
    if (_poiMapImage == null) {
      Uint8List imagePixelData = await _loadFileAsUint8List('assets/poi.png');
      _poiMapImage = MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    }

    // By default, the anchor point is set to 0.5, 0.5 (= centered).
    // Here the bottom, middle position should point to the location.
    Anchor2D anchor2D = Anchor2D.withHorizontalAndVertical(0.5, 1);

    MapMarker mapMarker = MapMarker.withAnchor(geoCoordinates, _poiMapImage!, anchor2D);
    mapMarker.drawOrder = drawOrder;

    _hereMapController.mapScene.addMapMarker(mapMarker);
  }

  Future<Uint8List> _loadFileAsUint8List(String assetPathToFile) async {
    // The path refers to the assets directory as specified in pubspec.yaml.
    ByteData fileData = await rootBundle.load(assetPathToFile);
    return Uint8List.view(fileData.buffer);
  }
}
