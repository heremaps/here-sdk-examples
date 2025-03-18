/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

void main() async {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  await _initializeHERESDK();

  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(MaterialApp(home: MyApp()));
}

Future<void> _initializeHERESDK() async {
  // Needs to be called before accessing SDKOptions to load necessary libraries.
  SdkContext.init(IsolateOrigin.main);

  // Set your credentials for the HERE SDK.
  String accessKeyId = "YOUR_ACCESS_KEY_ID";
  String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
  AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
  SDKOptions sdkOptions = SDKOptions.withAuthenticationMode(authenticationMode);

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
  late SearchEngine? _searchEngine;
  late final AppLifecycleListener _listener;

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
      MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
      _hereMapController!.camera.lookAtPointWithMeasure(HERE.GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);
      _startExample();
    });
  }

  _startExample() {
    _showDialog("Tap on Map Content",
        "This app shows how to pick vehicle restrictions and embedded markers on the map, such as subway stations and ATMs.");

    _enableVehicleRestrictionsOnMap();

    try {
      // Allows to search online.
      _searchEngine = SearchEngine();
    } on InstantiationException {
      throw ("Initialization of SearchEngine failed.");
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
    Point2D originInPixels = Point2D(touchPoint.x, touchPoint.y);
    Size2D sizeInPixels = Size2D(50, 50);
    Rectangle2D rectangle = Rectangle2D(originInPixels, sizeInPixels);

    // Creates a list of map content type from which the results will be picked.
    // The content type values can be mapContent, mapItems and customLayerData.
    List<MapSceneMapPickFilterContentType> contentTypesToPickFrom = [];

    // mapContent is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
    // mapItems is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
    // Currently we need map content so adding the mapContent filter.
    contentTypesToPickFrom.add(MapSceneMapPickFilterContentType.mapContent);
    MapSceneMapPickFilter filter = MapSceneMapPickFilter(contentTypesToPickFrom);
    _hereMapController?.pick(filter, rectangle, (pickMapResult) {
      if (pickMapResult == null) {
        // Pick operation failed.
        return;
      }

      PickMapContentResult? pickMapContentResult = pickMapResult.mapContent;
      if (pickMapContentResult == null) {
        // Pick operation failed.
        return;
      }
      _handlePickedCartoPOIs(pickMapContentResult.pickedPlaces);
      _handlePickedTrafficIncidents(pickMapContentResult.trafficIncidents);
      _handlePickedVehicleRestrictions(pickMapContentResult.vehicleRestrictions);
    });
  }

  void _handlePickedCartoPOIs(List<PickedPlace> cartoPOIList) {
    int listSize = cartoPOIList.length;
    if (listSize == 0) {
      return;
    }

    PickedPlace topmostPickedPlace = cartoPOIList.first;
    var name = topmostPickedPlace.name;
    var lat = topmostPickedPlace.coordinates.latitude;
    var lon = topmostPickedPlace.coordinates.longitude;
    _showDialog("Carto POI picked", "Name: $name. Location: $lat, $lon. See log for more place details.");

    // Now you can use the SearchEngine (via PickedPlace)
    // (via PickedPlace or placeCategoryId) to retrieve the Place object containing more details.
    // Below we use the placeCategoryId.
    _fetchCartoPOIDetails(topmostPickedPlace);
  }

  void _fetchCartoPOIDetails(HERE.PickedPlace pickedPlace) {
    // Set null to get the results in their local language.
    LanguageCode? languageCode;
    _searchEngine!.searchByPickedPlace(pickedPlace, languageCode, (SearchError? searchError, Place? place) async {
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

    PickVehicleRestrictionsResult topmostVehicleRestriction = vehicleRestrictions.first;
    var lat = topmostVehicleRestriction.coordinates.latitude;
    var lon = topmostVehicleRestriction.coordinates.longitude;
    _showDialog("Vehicle restriction picked", " Location: $lat, $lon.");
  }

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onDetach: () =>
      // Sometimes Flutter may not reliably call dispose(),
      // therefore it is recommended to dispose the HERE SDK
      // also when the AppLifecycleListener is detached.
      // See more details: https://github.com/flutter/flutter/issues/40940
      { print('AppLifecycleListener detached.'), _disposeHERESDK() },
    );
  }

  @override
  void dispose() {
    _disposeHERESDK();
    super.dispose();
  }

  void _disposeHERESDK() async {
    // Free HERE SDK resources before the application shuts down.
    await SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    _listener.dispose();
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
