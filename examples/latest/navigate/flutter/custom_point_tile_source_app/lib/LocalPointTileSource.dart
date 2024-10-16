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

import 'dart:core';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.datasource.dart';

class LocalPointTileSource implements PointTileSource {
  // Tile source data version. A single version is supported for this example.
  final TileSourceDataVersion dataVersion = TileSourceDataVersion(1, 0);

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
  
  // Computes the geo box out of a tile key, assuming a TMS tile key, spherical projection and quadtree
  // mercator tiling scheme.
  // @param tileKey Key of the tile for which to compute
  // @return Tile geo box (SW, NE).
  (GeoCoordinates, GeoCoordinates) tileKeyToGeoBox(TileKey tileKey) {
    // TMS -> XYZ
    final int tileZ = tileKey.level;
    final int tileX = tileKey.x;
    final int tileY = (1 << tileZ) - 1 - tileKey.y;

    final int tileSize = 256;
    final double earthRadius = 6378137.0;
    final double twoPi = 2.0 * pi;
    final double halfPi = pi * 0.5;
    final double toRadiansFactor = pi / 180.0;
    final double toDegreesFactor = 180.0 / pi;
    final double originShift = twoPi * earthRadius * 0.5;
    final double initialResolution = twoPi * earthRadius / tileSize;

    final double pointXWest = (tileX * tileSize).toDouble();
    final double pointYNorth = (tileY * tileSize).toDouble();
    final double pointXEast = ((tileX + 1) * tileSize).toDouble();
    final double pointYSouth = ((tileY + 1) * tileSize).toDouble();

    // Compute corner coordinates.
    final double resolutionAtCurrentZ = initialResolution / (1 << tileZ);
    final double halfSize = tileSize * (1 << tileZ) * 0.5;
    // SW
    final double meterXW = (pointXWest * resolutionAtCurrentZ - originShift).abs() *
                 (pointXWest < halfSize ? -1 : 1);
    final double meterYS = (pointYSouth * resolutionAtCurrentZ - originShift).abs() *
                 (pointYSouth > halfSize ? -1 : 1);
    double longitudeSW = (meterXW / originShift) * 180.0;
    double latitudeSW = (meterYS / originShift) * 180.0;
    latitudeSW = toDegreesFactor * (2 * atan(exp(latitudeSW * toRadiansFactor)) - halfPi);
    // NE
    final double meterXE = (pointXEast * resolutionAtCurrentZ - originShift).abs() *
                 (pointXEast < halfSize ? -1 : 1);
    final double meterYN = (pointYNorth * resolutionAtCurrentZ - originShift).abs() *
                 (pointYNorth > halfSize ? -1 : 1);
    double longitudeNE = (meterXE / originShift) * 180.0;
    double latitudeNE = (meterYN / originShift) * 180.0;
    latitudeNE = toDegreesFactor * (2 * atan(exp(latitudeNE * toRadiansFactor)) - halfPi);

    return (GeoCoordinates(latitudeSW, longitudeSW), GeoCoordinates(latitudeNE, longitudeNE));
  }
  
  GeoCoordinates getTileCenter(TileKey tileKey) {
    var (sw, ne) = tileKeyToGeoBox(tileKey);
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
