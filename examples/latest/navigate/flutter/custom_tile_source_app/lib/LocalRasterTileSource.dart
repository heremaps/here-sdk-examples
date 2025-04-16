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
import 'dart:typed_data';
import 'dart:ui';
import 'package:here_sdk/mapview.datasource.dart';

class LocalRasterTileSource implements RasterTileSource {
  // Tile source data version. A single version is supported for this example.
  final TileSourceDataVersion dataVersion = TileSourceDataVersion(1, 0);

  // Local tile data (auto-generated).
  var tileData = <Uint8List>[];

  // Transparent Colors for raster layers
  final int SEMI_TRANSPARENT_RED = 0x44FF0000;
  final int SEMI_TRANSPARENT_BLUE = 0x440000FF;
  final int SEMI_TRANSPARENT_GREEN = 0x4400FF00;
  final int SEMI_TRANSPARENT_BLACK = 0x44000000;
  final int SEMI_TRANSPARENT_WHITE = 0x44FFFFFF;
  final int SEMI_TRANSPARENT_YELLOW = 0x44FFFF00;
  final int SEMI_TRANSPARENT_CYAN = 0x4400FFFF;
  final int SEMI_TRANSPARENT_MAGENTA = 0x44FF00FF;

  Future<void> setupSource() async {
    // Create a set of images to provide as tile data.
    List<Uint8List?> generatedTileData = [
      await createTileData(512, 512, Color(SEMI_TRANSPARENT_RED)),
      await createTileData(512, 512, Color(SEMI_TRANSPARENT_BLUE)),
      await createTileData(512, 512, Color(SEMI_TRANSPARENT_GREEN)),
      await createTileData(512, 512, Color(SEMI_TRANSPARENT_BLACK)),
      await createTileData(512, 512, Color(SEMI_TRANSPARENT_WHITE)),
      await createTileData(512, 512, Color(SEMI_TRANSPARENT_YELLOW)),
      await createTileData(512, 512, Color(SEMI_TRANSPARENT_CYAN)),
      await createTileData(512, 512, Color(SEMI_TRANSPARENT_MAGENTA))
    ];

    tileData = generatedTileData.whereType<Uint8List>().toList();
  }

  @override
  TileSourceLoadTileRequestHandle? loadTile(
      TileKey tileKey, RasterTileSourceLoadResultHandler completionHandler) {
    // Pick one of the local tile images, based on the tile key x component.

    completionHandler.loaded(tileKey, tileData[tileKey.x % tileData.length],
        TileSourceTileMetadata(dataVersion, DateTime(0)));

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

  Future<Uint8List?> createTileData(int width, int height, Color color) async {
    PictureRecorder recorder = new PictureRecorder();
    Canvas canvas = new Canvas(recorder);
    Paint paint = Paint();
    paint.color = color;
    canvas.drawPaint(paint);
    Picture picture = recorder.endRecording();
    var pngBytes = await picture
        .toImageSync(width, height)
        .toByteData(format: ImageByteFormat.png);
    return pngBytes?.buffer.asUint8List();
  }
}
