/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

import 'MapItemsExample.dart';

void main() {
  SdkContext.init(IsolateOrigin.main);
  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  MapItemsExample _mapItemsExample;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HERE SDK - Map Items Example'),
      ),
      drawer: Drawer(
        child: ListView(children: _buildDrawerList(context)),
      ),
      body: Stack(
        children: [
          HereMap(onMapCreated: _onMapCreated),
        ],
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError error) {
      if (error == null) {
        _mapItemsExample = MapItemsExample(_showDialog, hereMapController);
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void _anchoredMapMarkersButtonClicked() {
    _mapItemsExample.showAnchoredMapMarkers();
  }

  void _centeredMapMarkersButtonClicked() {
    _mapItemsExample.showCenteredMapMarkers();
  }

  void _locationIndicatorPedestrianButtonClicked() {
    _mapItemsExample.showLocationIndicatorPedestrian();
  }

  void _locationIndicatorNavigationButtonClicked() {
    _mapItemsExample.showLocationIndicatorNavigation();
  }

  void _locationIndicatorActiveInactiveButtonClicked() {
    _mapItemsExample.toggleActiveStateForLocationIndicator();
  }

  void _flatMapMarkersButtonClicked() {
    _mapItemsExample.showFlatMapMarkers();
  }

  void _mapMarkers3DButtonClicked() {
    _mapItemsExample.showMapMarkers3D();
  }

  void _clearButtonClicked() {
    _mapItemsExample.clearMap();
  }

  // A helper method to add a button on top of the HERE map.
  Align button(String buttonLabel, Function callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          primary: Colors.lightBlueAccent,
          onPrimary: Colors.white,
        ),
        onPressed: () => callbackFunction(),
        child: Text(buttonLabel, style: TextStyle(fontSize: 20)),
      ),
    );
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

  // A helper method to build drawer list.
  List<Widget> _buildDrawerList(BuildContext context) {
    List<Widget> children = [];

    DrawerHeader header = DrawerHeader(
      child: Column(
        children: [
          Text(
            'HERE SDK - Map Items Example',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        color: Colors.blue,
      ),
    );
    children.add(header);

    // Add MapMarker section.
    var mapMarkerTile = _buildMapMarkerExpansionTile(context);
    children.add(mapMarkerTile);

    // Add LocationIndicator section.
    var locationIndicatorTile = _buildLocationIndicatorExpansionTile(context);
    children.add(locationIndicatorTile);

    // Add section to clear the map.
    var clearTile = _buildClearTile(context);
    children.add(clearTile);

    return children;
  }

  Widget _buildMapMarkerExpansionTile(BuildContext context) {
    return ExpansionTile(
      title: Text("MapMarker"),
      children: [
        ListTile(
          title: Text('Anchored (2D)'),
          onTap: () {
            Navigator.pop(context);
            _anchoredMapMarkersButtonClicked();
          },
        ),
        ListTile(
          title: Text('Centered (2D)'),
          onTap: () {
            Navigator.pop(context);
            _centeredMapMarkersButtonClicked();
          },
        ),
        ListTile(
          title: Text('Flat'),
          onTap: () {
            Navigator.pop(context);
            _flatMapMarkersButtonClicked();
          },
        ),
        ListTile(
          title: Text('3D OBJ'),
          onTap: () {
            Navigator.pop(context);
            _mapMarkers3DButtonClicked();
          },
        )
      ],
      initiallyExpanded: true,
    );
  }

  Widget _buildLocationIndicatorExpansionTile(BuildContext context) {
    return ExpansionTile(
      title: Text("LocationIndicator"),
      children: [
        ListTile(
            title: Text('Location (Ped)'),
            onTap: () {
              Navigator.pop(context);
              _locationIndicatorPedestrianButtonClicked();
            }),
        ListTile(
            title: Text('Location (Nav)'),
            onTap: () {
              Navigator.pop(context);
              _locationIndicatorNavigationButtonClicked();
            }),
        ListTile(
            title: Text('Location Active/Inactive'),
            onTap: () {
              Navigator.pop(context);
              _locationIndicatorActiveInactiveButtonClicked();
            }),
      ],
      initiallyExpanded: true,
    );
  }

  Widget _buildClearTile(BuildContext context) {
    return ListTile(
        title: Text('Clear'),
        onTap: () {
          Navigator.pop(context);
          _clearButtonClicked();
        });
  }
}
