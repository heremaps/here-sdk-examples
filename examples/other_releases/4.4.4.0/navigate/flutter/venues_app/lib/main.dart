/*
 * Copyright (C) 2020 HERE Europe B.V.
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
import 'package:venues/geometry_info.dart';
import 'package:venues/settings_page.dart';
import 'package:venues/venue_engine_widget.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/venue.dart';

void main() {
  SdkContext.init(IsolateOrigin.main);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HERE SDK for Flutter - Venues',
      initialRoute: '/',
      routes: {
        '/': (context) => MainPage(),
        '/settings': (context) => SettingsPage(),
      },
    );
  }
}

class MainPage extends StatelessWidget {
  final VenueEngineState _venueEngineState = VenueEngineState();
  final GeometryInfoState _geometryInfoState = GeometryInfoState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HERE SDK for Flutter - Venues'),
      ),
      resizeToAvoidBottomPadding: false,
      body: Column(children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 150,
              padding: EdgeInsets.only(left: 8, right: 8),
              // Widget for opening venue by provided ID.
              child: TextField(
                  decoration: InputDecoration(
                      border: InputBorder.none, hintText: 'Enter a venue ID'),
                  onSubmitted: (text) {
                    try {
                      // Try to parse a venue id.
                      int venueId = int.parse(text);
                      // Select a venue by id.
                      _venueEngineState.selectVenue(venueId);
                    } on FormatException catch (_) {
                      print("Venue ID should be a number!");
                    }
                  }),
            ),
            Container(
              margin: EdgeInsets.all(4),
              width: kMinInteractiveDimension,
              child: FlatButton(
                color: Colors.white,
                padding: EdgeInsets.zero,
                child: Icon(Icons.search,
                    color: Colors.black, size: kMinInteractiveDimension),
                onPressed: () {
                  _venueEngineState.getVenuesControllerState().setOpen(false);
                  final venueSearchState =
                      _venueEngineState.getVenueSearchState();
                  venueSearchState.setOpen(!venueSearchState.isOpen());
                },
              ),
            ),
            Container(
              margin: EdgeInsets.all(4),
              width: kMinInteractiveDimension,
              child: FlatButton(
                color: Colors.white,
                padding: EdgeInsets.zero,
                child: Icon(Icons.edit,
                    color: Colors.black, size: kMinInteractiveDimension),
                onPressed: () {
                  _venueEngineState.getVenueSearchState().setOpen(false);
                  final venuesState =
                      _venueEngineState.getVenuesControllerState();
                  venuesState.setOpen(!venuesState.isOpen());
                },
              ),
            ),
            Container(
              margin: EdgeInsets.all(4),
              width: kMinInteractiveDimension,
              child: FlatButton(
                color: Colors.white,
                padding: EdgeInsets.zero,
                child: Icon(Icons.settings,
                    color: Colors.black, size: kMinInteractiveDimension),
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
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay,
        (MapError error) {
      if (error != null) {
        print('Map scene not loaded. MapError: ${error.toString()}');
        return;
      }

      const double distanceToEarthInMeters = 500;
      hereMapController.camera.lookAtPointWithDistance(
          GeoCoordinates(52.530932, 13.384915), distanceToEarthInMeters);

      // Hide the extruded building layer, so that it does not overlap
      // with the venues.
      hereMapController.mapScene.setLayerState(
          MapSceneLayers.extrudedBuildings, MapSceneLayerState.hidden);
      // Create a venue engine object. Once the initialization is done,
      // a callback will be called.
      var venueEngine = VenueEngine.make(_onVenueEngineCreated);
      _venueEngineState.set(hereMapController, venueEngine, _geometryInfoState);
    });
  }

  _onVenueEngineCreated() {
    _venueEngineState.onVenueEngineCreated();
  }
}
