/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/search.dart';

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

/**
 * The W3WSearchExample class demonstrates the use of the W3WSearchEngine
 * to perform operations with what3words terms.
 *
 * With the W3WSearchEngine, you can:
 * - Resolve a what3words term to an address and geographic coordinates.
 * - Find a what3words term for given geographic coordinates.
 *
 * Both approaches are demonstrated in the examples below.
 * The W3WSearchEngine interacts with the https://what3words.com/ backend
 * to perform these operations.
 */
class W3WSearchExample {
  late W3WSearchEngine _w3wSearchEngine;
  ShowDialogFunction _showDialog;

  W3WSearchExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
    : _showDialog = showDialogCallback {
    double distanceToEarthInMeters = 10000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
    hereMapController.camera.lookAtPointWithMeasure(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

    try {
      _w3wSearchEngine = W3WSearchEngine();
    } on InstantiationException {
      throw Exception("Initialization of W3WSearchEngine failed.");
    }
  }

  Future<void> handleW3WSearchResult(String title, dynamic error, W3WSquare? w3WSquare) async {
    if (error != null) {
      // If an error occurred, show the error dialog.
      _showDialog("$title Error", "Error: ${error.toString()}");
      return;
    }

    if (w3WSquare != null) {
      // If the search was successful, extract the What3Words and other details.
      String w3wAddress = w3WSquare.words;

      GeoCoordinates southWest = w3WSquare.square.southWestCorner;
      GeoCoordinates northEast = w3WSquare.square.northEastCorner;

      // Display the details in a dialog.
      _showDialog(
        "$title Details",
        "W3Words: $w3wAddress\n"
            "Language: ${w3WSquare.languageCode}\n"
            "SouthWest: ${southWest.latitude}, ${southWest.longitude}\n"
            "NorthEast: ${northEast.latitude}, ${northEast.longitude}",
      );
    }
  }

  Future<void> onW3WSearchButtonClicked() async {
    // W3W sample "dizzy.vanilla.singer" used for demonstration purposes. Replace with user input as needed.
    String searchWords = "dizzy.vanilla.singer";

    try {
      /* Finds the location of a known What3Words term.
       * This method searches for the geographic location corresponding to a given three-word address
       * (e.g., "dizzy.vanilla.singer").
       */
      _w3wSearchEngine.searchByWords(searchWords, (error, W3WSquare) {
        handleW3WSearchResult("W3W Search", error, W3WSquare);
      });
    } catch (e) {
      _showDialog("Error", "An exception occurred: $e");
    }
  }

  Future<void> onW3WGeocodinButtonClicked() async {
    GeoCoordinates geoCoordinates = GeoCoordinates(53.520798, 13.409408);
    // The language code for the desired three-word address.
    // ISO 639-1 code "en" specifies that the three-word address will be in English.
    String? w3wLanguage = "en";

    try {
      /* Resolves geographic coordinates to a What3Words address (three-word format).
       * This method uses the What3Words search engine to find a three-word address based
       * on the provided coordinates (latitude and longitude).
       */
      _w3wSearchEngine.searchByCoordinates(geoCoordinates, w3wLanguage, (error, W3WSquare) {
        handleW3WSearchResult("W3W Geocoding", error, W3WSquare);
      });
    } catch (e) {
      _showDialog("Error", "An exception occurred: $e");
    }
  }
}
