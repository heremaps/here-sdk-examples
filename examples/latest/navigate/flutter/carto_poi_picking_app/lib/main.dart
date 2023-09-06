/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/search.dart';

void main() {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  _initializeHERESDK();

  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(MaterialApp(home: MyApp()));
}

void _initializeHERESDK() async {
  // Needs to be called before accessing SDKOptions to load necessary libraries.
  SdkContext.init(IsolateOrigin.main);

  // Set your credentials for the HERE SDK.
  String accessKeyId = "YOUR_ACCESS_KEY_ID";
  String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
  SDKOptions sdkOptions = SDKOptions.withAccessKeySecret(accessKeyId, accessKeySecret);

  try {
    await SDKNativeEngine.makeSharedInstance(sdkOptions);
  } on InstantiationException {
    throw Exception("Failed to initialize the HERE SDK.");
  }
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
      MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
      _hereMapController!.camera.lookAtPointWithMeasure(HERE.GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);
      _startExample();
    });
  }

  _startExample() {
    _showDialog("Tap on Map Content",
        "This app shows how to pick vehicle restrictions and embedded markers on the map, such as subway stations and ATMs.");

    _enableVehicleRestrictionsOnMap();

    try {
      // Allows to search on already downloaded or cached map data.
      _offlineSearchEngine = OfflineSearchEngine();
    } on InstantiationException {
      throw ("Initialization of OfflineSearchEngine failed.");
    }

    // Setting a tap handler to pick embedded map content.
    _setTapGestureHandler();
  }

  void _enableVehicleRestrictionsOnMap() {
    _hereMapController!.mapScene.enableFeatures(
        {MapFeatures.vehicleRestrictions: MapFeatureModes.vehicleRestrictionsActiveAndInactiveDifferentiated});
  }

  void _setTapGestureHandler() {
    _hereMapController!.gestures.tapListener = TapListener((Point2D touchPoint) {
      _pickMapContent(touchPoint);
    });
  }

  void _pickMapContent(Point2D touchPoint) {
    // You can also use a larger area to include multiple map icons.
    Rectangle2D rectangle2D = new Rectangle2D(touchPoint, new Size2D(50, 50));
    _hereMapController!.pickMapContent(rectangle2D, (pickMapContentResult) {
      if (pickMapContentResult == null) {
        print("Pick operation failed.");
        return;
      }

      _handlePickedCartoPOIs(pickMapContentResult.pois);
      _handlePickedTrafficIncidents(pickMapContentResult.trafficIncidents);
      _handlePickedVehicleRestrictions(pickMapContentResult.vehicleRestrictions);
    });
  }

  void _handlePickedCartoPOIs(List<PickPoiResult> cartoPOIList) {
    int listSize = cartoPOIList.length;
    if (listSize == 0) {
      return;
    }

    PickPoiResult topmostCartoPOI = cartoPOIList.first;
    var name = topmostCartoPOI.name;
    var lat = topmostCartoPOI.coordinates.latitude;
    var lon = topmostCartoPOI.coordinates.longitude;
    _showDialog("Carto POI picked", "Name: $name. Location: $lat, $lon. See log for more place details.");

    // Now you can use the SearchEngine (via PickedPlace) or the OfflineSearchEngine
    // (via PickedPlace or offlineSearchId) to retrieve the Place object containing more details.
    // Below we use the offlineSearchId. Alternatively, you can use the
    // PickMapContentResult as data to create a PickedPlace object.
    _fetchCartoPOIDetails(topmostCartoPOI.offlineSearchId);
  }

  // The ID is only given for cached or downloaded maps data.
  void _fetchCartoPOIDetails(String offlineSearchId) {
    // Set null to get the results in their local language.
    LanguageCode? languageCode;
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

  void _handlePickedTrafficIncidents(List<PickTrafficIncidentResult> trafficIndicents) {
    // See Traffic example app.
  }

  void _handlePickedVehicleRestrictions(List<PickVehicleRestrictionsResult> vehicleRestrictions) {
    int listSize = vehicleRestrictions.length;
    if (listSize == 0) {
      return;
    }

    // The text is non-translated and will vary depending on the region.
    // For example, for a height restriction the text might be "5.5m" in Germany and "12'5"" in the US for a
    // restriction of type "HEIGHT". An example for a "WEIGHT" restriction: "15t".
    // The text might be empty, for example, in case of type "GENERAL_TRUCK_RESTRICTION", indicated by a "no-truck" sign.
    PickVehicleRestrictionsResult topmostVehicleRestriction = vehicleRestrictions.first;
    String text = topmostVehicleRestriction.text;
    if (text.isEmpty) {
      text = "General vehicle restriction";
    }

    var lat = topmostVehicleRestriction.coordinates.latitude;
    var lon = topmostVehicleRestriction.coordinates.longitude;
    // A textual normed representation of the type.
    var type = topmostVehicleRestriction.restrictionType;
    _showDialog("Vehicle restriction picked",
        "Text: $text. Location: $lat, $lon. Type: $type. See log for more place details.");

    // GDF time domains format according to ISO 14825.
    print("VR TimeIntervals: " + topmostVehicleRestriction.timeIntervals);
  }

  @override
  void dispose() {
    // Free HERE SDK resources before the application shuts down.
    SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    super.dispose();
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
