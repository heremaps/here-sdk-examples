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

import 'package:camera_keyframe_tracks_app/helper/MenuSectionExpansionTile.dart';
import 'package:camera_keyframe_tracks_app/CameraKeyframeTracksExample.dart';
import 'package:camera_keyframe_tracks_app/RouteAnimationExample.dart';
import 'package:camera_keyframe_tracks_app/helper/RouteCalculator.dart';
import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';

void main() {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  _initializeHERESDK();

  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(const MyApp());
}

void _initializeHERESDK() async {
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
  late final AppLifecycleListener _listener;

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
        // Users of the Navigate Edition can enable textured landmarks:
        // hereMapController.mapScene.enableFeatures({MapFeatures.landmarks: MapFeatureModes.landmarksTextured});
        hereMapController.camera.lookAtPoint(GeoCoordinates(40.7133, -74.0112));
        _cameraKeyframeTracksExample = CameraKeyframeTracksExample(hereMapController);
        _routeAnimationExample = RouteAnimationExample(hereMapController);
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void _startAnimationToRouteButtonClicked() {
      _routeAnimationExample.animateToRoute();
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

    // Add animate to route section.
    var animateToRouteTile = _buildAnimateToRouteExpansionTile(context);
    children.add(animateToRouteTile);

    // Add Trip to NYC section.
    var tripToNYCTile = _buildTripToNYCExpansionTile(context);
    children.add(tripToNYCTile);

    return children;
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
}
