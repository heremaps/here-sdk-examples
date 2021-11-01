/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart' as HERE;
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/search.dart';

void main() {
  HERE.SdkContext.init(HERE.IsolateOrigin.main);
  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late HereMapController? _hereMapController;
  late OfflineSearchEngine? _offlineSearchEngine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Carto POI Picking'),
      ),
      body: Stack(
        children: [
          HereMap(onMapCreated: _onMapCreated),
        ],
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    _hereMapController = hereMapController;
    _hereMapController!.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) {
      if (error != null) {
        print('Map scene not loaded. MapError: ${error.toString()}');
        return;
      }

      const double distanceToEarthInMeters = 8000;
      _hereMapController!.camera
          .lookAtPointWithDistance(HERE.GeoCoordinates(52.520798, 13.409408), distanceToEarthInMeters);
      _startExample();
    });
  }

  _startExample() {
    _showDialog("Tap on Carto POIs",
        "This app show how to pick embedded markers on the map, such as subway stations and ATMs.");

    try {
      // Allows to search on already downloaded or cached map data.
      _offlineSearchEngine = OfflineSearchEngine();
    } on InstantiationException {
      throw ("Initialization of OfflineSearchEngine failed.");
    }

    // Setting a tap handler to pick embedded carto POIs from map.
    _setTapGestureHandler();
  }

  void _setTapGestureHandler() {
    _hereMapController!.gestures.tapListener = TapListener((Point2D touchPoint) {
      _pickMapMarker(touchPoint);
    });
  }

  void _pickMapMarker(Point2D touchPoint) {
    // You can also use a larger area to include multiple carto POIs.
    Rectangle2D rectangle2D = new Rectangle2D(touchPoint, new Size2D(1, 1));
    _hereMapController!.pickMapFeatures(rectangle2D, (pickMapFeaturesResult) {
      if (pickMapFeaturesResult == null) {
        // Pick operation failed.
        return;
      }

      List<PickMapFeaturesResultPickPoiResult> cartoPOIList = pickMapFeaturesResult.pois;
      int listSize = cartoPOIList.length;
      if (listSize == 0) {
        return;
      }

      PickMapFeaturesResultPickPoiResult topmostCartoPOI = cartoPOIList.first;
      var name = topmostCartoPOI.name;
      var lat = topmostCartoPOI.coordinates.latitude;
      var lon = topmostCartoPOI.coordinates.longitude;
      _showDialog("Carto POI picked", "Name: $name. Location: $lat, $lon. See log for more place details.");

      _fetchCartoPOIDetails(topmostCartoPOI.offlineSearchId);
    });
  }

  // The ID is only given for cached or downloaded maps data.
  void _fetchCartoPOIDetails(String offlineSearchId) {
    // Set null to get the results in their local language.
    LanguageCode? languageCode = null;
    _offlineSearchEngine!.searchByPlaceIdWithLanguageCode(PlaceIdQuery(offlineSearchId), languageCode,
        (SearchError? searchError, Place? place) async {
      _handleSearchResult(searchError, place);
    });
  }

  void _handleSearchResult(SearchError? searchError, Place? place) {
    if (searchError != null) {
      _showDialog("Place ID Search", "Error: " + searchError.toString());
      return;
    }

    // Below are just a few examples. Much more details can be retrieved, if desired.
    var title = place?.title;
    var addressText = place?.address.addressText;
    print("Title: $title");
    print("Address: $addressText");
  }

  // A helper method to show a dialog.
  Future<void> _showDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
