/*
 * Copyright (C) 2021 HERE Europe B.V.
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

// Disabled null safety for this file:
// @dart=2.9
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

class ImageHelper {
  static Future<Uint8List> loadFileAsUint8List(String fileName) async {
    // The path refers to the assets directory as specified in pubspec.yaml.
    ByteData fileData = await rootBundle.load('assets/' + fileName);
    return Uint8List.view(fileData.buffer);
  }

  // Creates a marker with a file name of an image and an anchor.
  static Future<MapMarker> initMapMarker(String fileName, Anchor2D anchor) async
  {
    anchor ??= new Anchor2D();
    final imagePixelData = await ImageHelper.loadFileAsUint8List(fileName);
    return MapMarker.withAnchor(GeoCoordinates(0.0, 0.0),
        MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png), anchor);
  }
}
