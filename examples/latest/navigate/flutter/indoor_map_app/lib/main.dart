/*
 * Copyright (C) 2020-2022 HERE Europe B.V.
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
import 'package:here_sdk/core.errors.dart';
import 'package:indoor_map_app/geometry_info.dart';
import 'package:indoor_map_app/settings_page.dart';
import 'package:indoor_map_app/venue_engine_widget.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/venue.dart';
import 'dart:convert';
import 'events.dart';

void main() {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  _initializeHERESDK();

  runApp(MyApp());
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

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HERE SDK for Flutter - Indoor Map',
      initialRoute: '/',
      routes: {
        '/': (context) => MainPage(),
        '/settings': (context) => SettingsPage(),
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final VenueEngineState _venueEngineState = VenueEngineState();
  final GeometryInfoState _geometryInfoState = GeometryInfoState();
  late String _venueIdAsString = "";
  late String _selectedVenue = "Venue Id";
  List _venueList = ["Venue Id"];
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HERE SDK for Flutter - Indoor Map'),
      ),
      resizeToAvoidBottomInset: false,
      body: Column(children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 5, right: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ValueListenableBuilder<List>(
                    builder: (BuildContext context, List value, Widget? child) {
                      _venueList = value;
                      return DropdownButton(
                        hint: Text("MapList"),
                        value: _selectedVenue,
                        items: _venueList.map((item) {
                          return DropdownMenuItem(
                            child: Text(item),
                            value: item,
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedVenue = "$value";
                            _venueIdAsString = _selectedVenue;
                            _isPressed = false;
                            mapLoading.isMapLoading.value = false;
                          });
                        },
                      );
                    },
                    valueListenable: listEventHandler.updatedList,
                    // The child parameter is most helpful if the child is
                    // expensive to build and does not depend on the value from
                    // the notifier.
                  ),
                ],
              ),
            ),
            Container(
                margin: EdgeInsets.all(4),
                width: 100,
                child: ValueListenableBuilder<bool>(
                  builder: (BuildContext context, bool value, Widget? child) {
                    if(value) {
                      _isPressed = false;
                    }
                    return ElevatedButton(
                      onPressed: mapLoading.isMapLoading.value ? null: () async {
                        if(_isPressed) {
                          setState(() => _isPressed = false);
                        }
                        else {
                          setState(() => _isPressed = true);
                        }

                        try {
                          // Try to parse a venue id.
                          int venueId = int.parse(_venueIdAsString);
                          // Select a venue by id.
                          _venueEngineState.selectVenue(venueId);
                        } on FormatException catch (_) {
                          print("Venue ID should be a number!");
                        }
                      },
                      child: Text(_isPressed ? 'Loading...' : 'Go'),
                    );
                  },
                  valueListenable: mapLoading.isMapLoading,
                  // The child parameter is most helpful if the child is
                  // expensive to build and does not depend on the value from
                  // the notifier.
                ),
            ),
            Container(
              margin: EdgeInsets.all(4),
              width: kMinInteractiveDimension,
              child: TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero
                ),
                child: Icon(Icons.search, color: Colors.black, size: kMinInteractiveDimension),
                onPressed: () {
                  final venueSearchState = _venueEngineState.getVenueSearchState();
                  venueSearchState.setOpen(!venueSearchState.isOpen());
                },
              ),
            ),
            Container(
              margin: EdgeInsets.all(4),
              width: kMinInteractiveDimension,
              child: TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero
                ),
                child: Icon(Icons.settings, color: Colors.black, size: kMinInteractiveDimension),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            )
          ],
        ),
        Expanded(
          child: Stack(children: <Widget>[
            // Add a HERE map.
            HereMap(onMapCreated: _onMapCreated),
            // Add a venue engine widget, which helps to control venues
            // on the map.
            VenueEngineWidget(state: _venueEngineState),
          ]),
        ),
        // Add a geometry info widget, to show information about geometry.
        GeometryInfo(state: _geometryInfoState)
      ]),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    // Load a scene from the HERE SDK to render the map with a map scheme.
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) {
      if (error != null) {
        print('Map scene not loaded. MapError: ${error.toString()}');
        return;
      }

      const double distanceToEarthInMeters = 500;
      MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
      hereMapController.camera.lookAtPointWithMeasure(GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

      // Hide the extruded building layer, so that it does not overlap
      // with the venues.
      hereMapController.mapScene.disableFeatures([MapFeatures.extrudedBuildings]);

      // Create a venue engine object. Once the initialization is done,
      // a callback will be called.
      var venueEngine;
      try {
        venueEngine = VenueEngine(_onVenueEngineCreated);
        _venueEngineState.set(hereMapController, venueEngine, _geometryInfoState);
      } on InstantiationException catch(e){
        print('error caught: $e');
      }
    });
  }

  _onVenueEngineCreated() {
    _venueEngineState.onVenueEngineCreated();
  }
}
