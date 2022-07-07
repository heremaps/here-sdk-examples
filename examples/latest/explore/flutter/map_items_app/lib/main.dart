/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/mapview.dart';
import 'package:map_items_app/MenuSectionExpansionTile.dart';

import 'MapItemsExample.dart';
import 'MapObjectsExample.dart';
import 'MapViewPinsExample.dart';

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
  MapItemsExample? _mapItemsExample;
  MapObjectsExample? _mapObjectsExample;
  MapViewPinsExample? _mapViewPinsExample;

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
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) {
      if (error == null) {
        _mapItemsExample = MapItemsExample(_showDialog, hereMapController);
        _mapObjectsExample = MapObjectsExample(hereMapController);
        _mapViewPinsExample = MapViewPinsExample(hereMapController);
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void _anchoredMapMarkersButtonClicked() {
    _mapItemsExample?.showAnchoredMapMarkers();
  }

  void _centeredMapMarkersButtonClicked() {
    _mapItemsExample?.showCenteredMapMarkers();
  }

  void _mapMarkerClusterButtonClicked() {
    _mapItemsExample?.showMapMarkerCluster();
  }

  void _locationIndicatorPedestrianButtonClicked() {
    _mapItemsExample?.showLocationIndicatorPedestrian();
  }

  void _locationIndicatorNavigationButtonClicked() {
    _mapItemsExample?.showLocationIndicatorNavigation();
  }

  void _locationIndicatorActiveInactiveButtonClicked() {
    _mapItemsExample?.toggleActiveStateForLocationIndicator();
  }

  void _flatMapMarkersButtonClicked() {
    _mapItemsExample?.showFlatMapMarker();
  }

  void _2DTextureButtonClicked() {
    _mapItemsExample?.show2DTexture();
  }

  void _mapMarkers3DButtonClicked() {
    _mapItemsExample?.showMapMarkers3D();
  }

  void _mapObjectPolylineButtonClicked() {
    _mapObjectsExample?.showMapPolyline();
  }

  void _mapObjectPolygonButtonClicked() {
    _mapObjectsExample?.showMapPolygon();
  }

  void _mapObjectArrowButtonClicked() {
    _mapObjectsExample?.showMapArrow();
  }

  void _mapObjectCircleButtonClicked() {
    _mapObjectsExample?.showMapCircle();
  }

  void _addDefaultMapViewPinButtonClicked() {
    _mapViewPinsExample?.showDefaultMapViewPin();
  }

  void _addAnchoredMapViewPinButtonClicked() {
    _mapViewPinsExample?.showAnchoredMapViewPin();
  }

  void _clearButtonClicked() {
    _mapItemsExample?.clearMap();
    _mapObjectsExample?.clearMap();
    _mapViewPinsExample?.clearMap();
  }

  // A helper method to build a drawer list.
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

    // Add MapObject section.
    var mapObjectTile = _buildMapObjectExpansionTile(context);
    children.add(mapObjectTile);

    // Add MapViewPins section.
    var mapViewPinsTile = _buildMapViewPinsExpansionTile(context);
    children.add(mapViewPinsTile);

    // Add section to clear the map.
    var clearTile = _buildClearTile(context);
    children.add(clearTile);

    return children;
  }

  // Build the menu entries for the MapMarker section.
  Widget _buildMapMarkerExpansionTile(BuildContext context) {
    final List<MenuSectionItem> menuItems = [
      MenuSectionItem("Anchored (2D)", _anchoredMapMarkersButtonClicked),
      MenuSectionItem("Centered (2D)", _centeredMapMarkersButtonClicked),
      MenuSectionItem("MapMarkerCluster", _mapMarkerClusterButtonClicked),
      MenuSectionItem("Flat MapMarker", _flatMapMarkersButtonClicked),
      MenuSectionItem("2DTexture", _2DTextureButtonClicked),
      MenuSectionItem("3D OBJ", _mapMarkers3DButtonClicked),
    ];

    return MenuSectionExpansionTile("MapMarker", menuItems);
  }

  // Build the menu entries for the LocationIndicator section.
  Widget _buildLocationIndicatorExpansionTile(BuildContext context) {
    final List<MenuSectionItem> menuItems = [
      MenuSectionItem("Location (Ped)", _locationIndicatorPedestrianButtonClicked),
      MenuSectionItem("Location (Nav)", _locationIndicatorNavigationButtonClicked),
      MenuSectionItem("Location Active/Inactive", _locationIndicatorActiveInactiveButtonClicked),
    ];

    return MenuSectionExpansionTile("LocationIndicator", menuItems);
  }

  // Build the menu entries for the MapObject section.
  Widget _buildMapObjectExpansionTile(BuildContext context) {
    final List<MenuSectionItem> menuItems = [
      MenuSectionItem("Polyline", _mapObjectPolylineButtonClicked),
      MenuSectionItem("Polygon", _mapObjectPolygonButtonClicked),
      MenuSectionItem("Arrow", _mapObjectArrowButtonClicked),
      MenuSectionItem("Circle", _mapObjectCircleButtonClicked),
    ];

    return MenuSectionExpansionTile("MapObject", menuItems);
  }

  // Build the menu entries for the MapViewPins section.
  Widget _buildMapViewPinsExpansionTile(BuildContext context) {
    final List<MenuSectionItem> menuItems = [
      MenuSectionItem("Default", _addDefaultMapViewPinButtonClicked),
      MenuSectionItem("Anchored", _addAnchoredMapViewPinButtonClicked),
    ];

    return MenuSectionExpansionTile("MapViewPins", menuItems);
  }

  // Build the menu entry for the clear section.
  Widget _buildClearTile(BuildContext context) {
    return ListTile(
        title: Text('Clear'),
        onTap: () {
          Navigator.pop(context);
          _clearButtonClicked();
        });
  }

  @override
  void dispose() {
    // Free HERE SDK resources before the application shuts down.
    SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    super.dispose();
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
}
