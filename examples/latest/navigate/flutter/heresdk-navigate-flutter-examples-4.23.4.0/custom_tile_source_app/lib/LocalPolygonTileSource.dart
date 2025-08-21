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
import 'dart:core';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.datasource.dart';

class LocalPolygonTileSource implements PolygonTileSource {
  // Tile source data version. A single version is supported for this example.
  final TileSourceDataVersion dataVersion = TileSourceDataVersion(1, 0);

  // Tile geo-bounds calculator for supported tiling scheme.
  final TileGeoBoundsCalculator tileBoundsCalculator = TileGeoBoundsCalculator(TilingScheme.quadTreeMercator);

  @override
  TileSourceLoadTileRequestHandle? loadTile(
      TileKey tileKey, PolygonTileSourceLoadResultHandler completionHandler) {
    print("Loading Polygon tile for key: ${tileKey.hashCode}");

    try {
      // Create the polygon tile data
      PolygonData tileData = PolygonDataBuilder()
          .withGeometry(GeoPolygon(getPolygonTileCoordinates(tileKey)))
          .withAttributes(DataAttributesBuilder().build())
          .build();

      print("Tile loaded successfully");
      completionHandler.loaded(
          tileKey, [tileData], TileSourceTileMetadata(dataVersion, DateTime(0)));
    } catch (e) {
      print("Failed to create LineData: $e");
      completionHandler.failed(tileKey);
    }

    return null;
  }

  @override
  TileSourceDataVersion getDataVersion(TileKey tileKey) {
    // Latest version of the tile data.
    return dataVersion;
  }

  @override
  void addListener(TileSourceListener listener) {
    // Not needed by this implementation.
  }

  @override
  void removeListener(TileSourceListener listener) {
    // Not used by this implementation.
  }

  @override
  final TilingScheme tilingScheme = TilingScheme.quadTreeMercator;

  @override
  final List<int> storageLevels = List.generate(16, (index) => index + 1);

  List<GeoCoordinates> getPolygonTileCoordinates(TileKey tileKey) {
    GeoBox tileBoundingBox = tileBoundsCalculator.boundsOf(tileKey);
    return [
      tileBoundingBox.southWestCorner,
      new GeoCoordinates(tileBoundingBox.northEastCorner.longitude, tileBoundingBox.northEastCorner.latitude),
      new GeoCoordinates(tileBoundingBox.northEastCorner.latitude, tileBoundingBox.northEastCorner.longitude),
      tileBoundingBox.southWestCorner
    ];
  }
}
