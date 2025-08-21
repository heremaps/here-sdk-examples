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
import 'dart:math';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.datasource.dart';

class LocalPointTileSource implements PointTileSource {
  // Tile source data version. A single version is supported for this example.
  final TileSourceDataVersion dataVersion = TileSourceDataVersion(1, 0);

  // Tile geo-bounds calculator for supported tiling scheme.
  final TileGeoBoundsCalculator tileBoundsCalculator = TileGeoBoundsCalculator(TilingScheme.quadTreeMercator);

  @override
  TileSourceLoadTileRequestHandle? loadTile(
      TileKey tileKey, PointTileSourceLoadResultHandler completionHandler) {
    // For each tile, provide the tile geodetic center as a custom point, with a single
    // named attribute "pointText" containing the tile key representation as a string.
    DataAttributes pointAttributes = DataAttributesBuilder()
            .withString("pointText", 'Tile: (${tileKey.x}, ${tileKey.y}, ${tileKey.level})')
            .build();
    PointData tileData = PointDataBuilder().withCoordinates(getTileCenter(tileKey))
                                         .withAttributes(pointAttributes)
                                         .build();

    completionHandler.loaded(tileKey, [tileData], TileSourceTileMetadata(dataVersion, DateTime(0)));

    // No request handle is returned here since there is no asynchronous loading happening.
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
    // Listener can be used to signal the data source the update of data version.
  }

  @override
  void removeListener(TileSourceListener listener) {
    // Not used by this implementation.
  }

  // Tile source supported tiling scheme.
  @override
  final TilingScheme tilingScheme = TilingScheme.quadTreeMercator;

  // Tile source supported data levels.
  @override
  final List<int> storageLevels = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16
  ];

  GeoCoordinates getTileCenter(TileKey tileKey) {
    var tileBoundingBox = tileBoundsCalculator.boundsOf(tileKey);
    var sw = tileBoundingBox.southWestCorner;
    var ne = tileBoundingBox.northEastCorner;

    final double latitude = (sw.latitude + ne.latitude) * 0.5;

    final double west = sw.longitude;
    final double east = ne.longitude;

    if (west <= east)
    {
      return GeoCoordinates(latitude, (west + east) * 0.5);
    }

    double longitude = (2 * pi + east + west) * 0.5;
    if (longitude > pi )
    {
      longitude -= 2 * pi;
    }

    return GeoCoordinates(latitude, longitude);
  }
}
