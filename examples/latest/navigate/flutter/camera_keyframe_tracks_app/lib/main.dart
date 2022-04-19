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

import 'package:camera_keyframe_tracks_app/MenuSectionExpansionTile.dart';
import 'package:camera_keyframe_tracks_app/animations/CameraKeyframeTracksExample.dart';
import 'package:camera_keyframe_tracks_app/animations/RouteAnimationExample.dart';
import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart' as routes;

void main() {
  SdkContext.init(IsolateOrigin.main);
  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CameraKeyframeTracks Example App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CameraKeyframeTracksApp(title: 'HERE SDK - CameraKeyframeTracks Example'),
    );
  }
}

class CameraKeyframeTracksApp extends StatefulWidget {
  const CameraKeyframeTracksApp({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<CameraKeyframeTracksApp> createState() => _CameraKeyframeTracksAppState();
}

class _CameraKeyframeTracksAppState extends State<CameraKeyframeTracksApp> {
  late CameraKeyframeTracksExample _cameraKeyframeTracksExample;
  late RouteAnimationExample _routeAnimationExample;
  late routes.Route? route;

  @override
  void dispose() {
    // Free HERE SDK resources before the application shuts down.
    SdkContext.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 14.0),
        ),
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
        hereMapController.mapScene.setLayerVisibility(MapSceneLayers.landmarks, VisibilityState.visible);

        double distanceInMeters = 5000;
        hereMapController.camera
            .lookAtPointWithDistance(GeoCoordinates(40.7116777285189, -74.01248494562448), distanceInMeters);

        _cameraKeyframeTracksExample = CameraKeyframeTracksExample(hereMapController);
        _routeAnimationExample = RouteAnimationExample(_showDialog, hereMapController);
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void _addRouteButtonClicked() {
    route = _routeAnimationExample.calculateRoute();
  }

  void _clearMapButtonClicked() {
    _routeAnimationExample.clearRoute();
  }

  void _startAnimationAlongRouteButtonClicked() {
    route = _routeAnimationExample.calculateRoute();
    if (route != null) {
      _routeAnimationExample.animateRoute(route);
    } else {
      _showDialog("Route Empty: ", "First find a route to animate.");
    }
  }

  void _stopAnimationAlongRouteButtonClicked() {
    _routeAnimationExample.stopRouteAnimation();
  }

  void _startAnimationToRouteButtonClicked() {
    route = _routeAnimationExample.calculateRoute();
    if (route != null) {
      _routeAnimationExample.animateToRoute(route);
    } else {
      _showDialog("Route Empty: ", "First find a route to animate.");
    }
  }

  void _stopAnimationToRouteButtonClicked() {
    _routeAnimationExample.stopRouteAnimation();
  }

  void _startTripToNYCButtonClicked() {
    _cameraKeyframeTracksExample.startTripToNYC();
  }

  void _stopTripToNYCButtonClicked() {
    _cameraKeyframeTracksExample.stopTripToNYCAnimation();
  }

  // A helper method to build a drawer list.
  List<Widget> _buildDrawerList(BuildContext context) {
    List<Widget> children = [];

    DrawerHeader header = DrawerHeader(
      child: Column(
        children: const [
          Text(
            'HERE SDK - CameraKeyframeTracks Animations',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
            ),
          ),
        ],
      ),
      decoration: const BoxDecoration(
        color: Colors.blue,
      ),
    );
    children.add(header);

    // Add create route section.
    var createRouteTile = _buildCreateRouteExpansionTile(context);
    children.add(createRouteTile);

    // Add animate along section.
    var animationAlongRouteTile = _buildAnimateAlongRouteExpansionTile(context);
    children.add(animationAlongRouteTile);

    // Add animate to route section.
    var animateToRouteTile = _buildAnimateToRouteExpansionTile(context);
    children.add(animateToRouteTile);

    // Add Trip to NYC section.
    var tripToNYCTile = _buildTripToNYCExpansionTile(context);
    children.add(tripToNYCTile);

    return children;
  }

  // Build the menu entries for the create route section.
  Widget _buildCreateRouteExpansionTile(BuildContext context) {
    final List<MenuSectionItem> menuItems = [
      MenuSectionItem("Add a route", _addRouteButtonClicked),
      MenuSectionItem("Clear Map", _clearMapButtonClicked),
    ];

    return MenuSectionExpansionTile("Create route", menuItems);
  }

  // Build the menu entries for the animate along route section.
  Widget _buildAnimateAlongRouteExpansionTile(BuildContext context) {
    final List<MenuSectionItem> menuItems = [
      MenuSectionItem("Start Animation", _startAnimationAlongRouteButtonClicked),
      MenuSectionItem("Stop Animation", _stopAnimationAlongRouteButtonClicked),
    ];

    return MenuSectionExpansionTile("Animate along route", menuItems);
  }

  // Build the menu entries for the animate to route section.
  Widget _buildAnimateToRouteExpansionTile(BuildContext context) {
    final List<MenuSectionItem> menuItems = [
      MenuSectionItem("Start Animation", _startAnimationToRouteButtonClicked),
      MenuSectionItem("Stop Animation", _stopAnimationToRouteButtonClicked),
    ];

    return MenuSectionExpansionTile("Animate to route", menuItems);
  }

  // Build the menu entries for the trip to NYC section.
  Widget _buildTripToNYCExpansionTile(BuildContext context) {
    final List<MenuSectionItem> menuItems = [
      MenuSectionItem("Start trip to NYC", _startTripToNYCButtonClicked),
      MenuSectionItem("Stop trip to NYC", _stopTripToNYCButtonClicked),
    ];

    return MenuSectionExpansionTile("Trip to NYC", menuItems);
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
