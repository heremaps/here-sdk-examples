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

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/mapview.datasource.dart';
import 'LocalRasterTileSource.dart';

class CustomRasterTileSourceExample {
  HereMapController _hereMapController;
  MapLayer? _rasterMapLayerStyle;
  RasterDataSource? _rasterDataSourceStyle;
  MapImage? _poiMapImage;

  CustomRasterTileSourceExample(this._hereMapController) {
    double distanceToEarthInMeters = 60 * 1000;
    MapMeasure mapMeasureZoom =
    MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(
        GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);
  }

  void setup() async {
    String dataSourceName = "myColorfulRasterDataSource";
    _rasterDataSourceStyle = await _createRasterDataSource(dataSourceName);
    _rasterMapLayerStyle = _createMapLayer(dataSourceName);

    // We want to start with the default map style.
    _rasterMapLayerStyle?.setEnabled(false);

    // Add a POI marker
    _addPOIMapMarker(GeoCoordinates(52.530932, 13.384915), 1);
  }

  void enableButtonClicked() {
    _rasterMapLayerStyle?.setEnabled(true);
  }

  void disableButtonClicked() {
    _rasterMapLayerStyle?.setEnabled(false);
  }

  Future<RasterDataSource> _createRasterDataSource(
      String dataSourceName) async {
    var localRasterTileSource = LocalRasterTileSource();
    await localRasterTileSource.setupSource();

    // Note that this will make the raster source already known to the passed map view.
    return RasterDataSource.withTileSource(
        _hereMapController.mapContext, dataSourceName, localRasterTileSource);
  }

  MapLayer _createMapLayer(String dataSourceName) {
    // The layer should be rendered on top of other layers except the "labels" layer
    // so that we don't overlap the raster layer over POI markers.
    MapLayerPriority priority =
    MapLayerPriorityBuilder().renderedBeforeLayer("labels").build();

    // And it should be visible for all zoom levels.
    MapLayerVisibilityRange range = MapLayerVisibilityRange(0, 22 + 1);

    try {
      // Build and add the layer to the map.
      MapLayer mapLayer = MapLayerBuilder()
          .forMap(
          _hereMapController.hereMapControllerCore) // mandatory parameter
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
    _rasterMapLayerStyle?.destroy();
    _rasterDataSourceStyle?.destroy();
  }

  Future<void> _addPOIMapMarker(
      GeoCoordinates geoCoordinates, int drawOrder) async {
    // Reuse existing MapImage for new map markers.
    if (_poiMapImage == null) {
      Uint8List imagePixelData = await _loadFileAsUint8List('assets/poi.png');
      _poiMapImage =
          MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    }

    // By default, the anchor point is set to 0.5, 0.5 (= centered).
    // Here the bottom, middle position should point to the location.
    Anchor2D anchor2D = Anchor2D.withHorizontalAndVertical(0.5, 1);

    MapMarker mapMarker =
    MapMarker.withAnchor(geoCoordinates, _poiMapImage!, anchor2D);
    mapMarker.drawOrder = drawOrder;

    _hereMapController.mapScene.addMapMarker(mapMarker);
  }

  Future<Uint8List> _loadFileAsUint8List(String assetPathToFile) async {
    // The path refers to the assets directory as specified in pubspec.yaml.
    ByteData fileData = await rootBundle.load(assetPathToFile);
    return Uint8List.view(fileData.buffer);
  }
}
